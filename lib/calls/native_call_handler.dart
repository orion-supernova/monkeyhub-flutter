import 'dart:async' show unawaited;
import 'dart:convert' show utf8;
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart' show md5;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'call_models.dart';
import 'call_permissions.dart';
import 'call_service.dart';
import 'group_call_service.dart';

/// Bridges flutter_callkit_incoming (native iOS CallKit / Android
/// ConnectionService) into [CallService]. Single global subscription
/// installed at app start — events are coarse enough that we don't need
/// per-call wiring.
///
/// Event flow:
///   VoIP push lands → AppDelegate.swift (iOS) or the package's FCM hook
///   (Android) shows the native incoming UI → user taps accept/decline →
///   the package emits an event here → we call into CallService.
class NativeCallHandler {
  NativeCallHandler._();
  static final NativeCallHandler instance = NativeCallHandler._();

  bool _started = false;

  // CallKit (iOS) force-unwraps `UUID(uuidString: data.uuid)` in
  // CallManager.swift:26 — passing anything that isn't a proper RFC-4122
  // UUID crashes the app. Our Convex callIds are not UUIDs, so we derive one
  // and reuse it across lifecycle events (start → connected → end).
  //
  // The derivation is DETERMINISTIC and byte-for-byte identical to Kotlin's
  // `UUID.nameUUIDFromBytes(callId.toByteArray(UTF_8))` in
  // CallFcmService.uuidForCallId. That matters: on Android a card can be
  // raised by CallFcmService (background/killed) and later driven from Dart.
  // With independently minted random ids the two sides disagreed, so
  // `setCallConnected` addressed a call the plugin had never heard of and
  // silently no-opped — leaving the card stuck in its "incoming" state, still
  // armed with the delete/timeout intent that ends the call.
  final Map<String, String> _uuidByCallId = {};

  // When we ourselves dismiss a card (driven by WebRTC teardown), the package
  // fires ACTION_CALL_ENDED back at us. `_endNamedCall` drops that echo by
  // checking the session's status — "endCall() is idempotent" was never quite
  // true, because `_teardown` holds the session for 400ms after going
  // terminal, leaving a window where the echo fired a second `calls:end`.

  // iOS Simulator's CallKit is unreliable: it fires CXEndCallAction
  // spuriously right after CXStartCallAction, which our listener used to
  // interpret as "user ended the call" and cancel the outgoing call before
  // the callee could accept. Skipping CallKit on simulator avoids that —
  // the in-app call UI is sufficient for dev testing.
  //
  // Detection: env vars like SIMULATOR_DEVICE_NAME aren't exposed to the
  // Flutter runtime inside simulator app processes. But the resolved
  // executable always lives under `.../CoreSimulator/Devices/...` on
  // simulator and `.../var/containers/Bundle/Application/...` on real
  // hardware, so the path substring is reliable.
  late final bool _isIosSimulator = _detectIosSimulator();

  /// Whether this device rings via the in-app fallback screen instead of
  /// CallKit (simulator CallKit is unreliable — see _detectIosSimulator).
  /// Read by `_CallOverlay` to decide whether IncomingCallScreen may show.
  bool get isIosSimulator => _isIosSimulator;

  /// Whether the native call UI (flutter_callkit_incoming) is available and
  /// should be driven. Only real iOS/Android hardware has it — web and desktop
  /// have no plugin implementation (calling `endAllCalls`, `startCall`, etc.
  /// there throws MissingPluginException), and the iOS simulator's CallKit is
  /// unreliable. Those platforms use the in-app IncomingCallScreen instead.
  bool get _nativeCallUi =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS) && !_isIosSimulator;

  static bool _detectIosSimulator() {
    // kIsWeb first: it's a const, so Platform.* (dart:io) is never touched on
    // web, where evaluating it throws.
    if (kIsWeb || !Platform.isIOS) return false;
    return Platform.resolvedExecutable.contains('/CoreSimulator/');
  }

  /// The native id for [callId] — the one a native path already used, if we
  /// captured it, otherwise the deterministic derivation both sides compute.
  String _uuidFor(String callId) =>
      _uuidByCallId.putIfAbsent(callId, () => derivedUuid(callId));

  /// Dart port of `java.util.UUID.nameUUIDFromBytes` — MD5 of the name, with
  /// the version-3 and IETF-variant bits patched in. Keep in step with
  /// CallFcmService.uuidForCallId; the two MUST agree, which is what
  /// test/call_native_uuid_test.dart pins.
  @visibleForTesting
  static String derivedUuid(String callId) {
    final b = md5.convert(utf8.encode(callId)).bytes.toList();
    b[6] = (b[6] & 0x0f) | 0x30; // version 3 (name-based, MD5)
    b[8] = (b[8] & 0x3f) | 0x80; // IETF variant
    String h(int i, int j) => b
        .sublist(i, j)
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
  }

  void start() {
    if (kIsWeb) return; // flutter_callkit_incoming has no web implementation.
    if (_started) return;
    _started = true;
    // `onError` is not optional here. flutter_callkit_incoming 3.1.3 parses
    // every native event through a single `map(_receiveCallEvent)` that
    // THROWS on anything it doesn't like — and it throws on every
    // ACTION_CALL_TOGGLE_AUDIO_SESSION iOS sends us, because it demands a
    // `body.isActive` that isn't in the payload (see the plugin's
    // `_receiveCallEvent`; the message even misreports it as "id is null").
    // Without a handler those land as uncaught zone errors — noise in every
    // call's logs, and one `cancelOnError` default away from silently
    // killing this subscription and with it every accept/decline/end event.
    // The dropped audio-session event itself is compensated for in
    // CallService's post-connect route re-asserts, which no longer wait to
    // be told the session went active.
    FlutterCallkitIncoming.onEvent.listen(
      _onEvent,
      onError: (Object e) =>
          debugPrint('NativeCallHandler: dropped malformed callkit event: $e'),
      cancelOnError: false,
    );
  }

  Future<void> _onEvent(CallEvent? event) async {
    if (event == null) return;
    // CallKit on simulator is unreliable and we don't show its UI there —
    // ignore any stray events it fires to avoid hijacking the in-app flow.
    if (!_nativeCallUi) return;
    final service = CallService.instance;
    debugPrint('NativeCallHandler: ${event.eventName}');
    // 3.x replaced the `Event` enum + untyped `body` map with a sealed
    // CallEvent hierarchy, so this matches on the variant and destructures
    // the payload instead of string-keying into a map.
    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        _captureNativeUuidFromParams(callKitParams);
        // Before anything that reaches for a 1:1 session: a group card has
        // none, has never had one, and every guard below would read its
        // absence as "ghost card" and dismiss the call the user just
        // answered.
        final acceptedGroupId = _groupCallIdFromParams(callKitParams);
        if (acceptedGroupId != null) {
          await _acceptGroupCall(acceptedGroupId);
          break;
        }
        final acceptedCallId = _callIdFromParams(callKitParams);
        // Ghost guard: a CallKit card can outlive its call (the caller
        // cancelled or the ring timed out while the app was locked/killed).
        // If Dart has no session for it, confirm with the backend that the
        // call is still live BEFORE latching the accept — a latched accept
        // for a dead call waits forever for an offer that can never come.
        if (service.session == null) {
          if (acceptedCallId != null &&
              await _isCallLive(acceptedCallId) == false) {
            debugPrint(
              'NativeCallHandler: stale CallKit accept '
              'callId=$acceptedCallId — clearing',
            );
            await endNativeByCallId(acceptedCallId);
            break;
          }
        }
        // Flag the service BEFORE awaiting acceptIncoming so:
        //   1. `_CallOverlay` skips the in-app IncomingCallScreen and
        //      routes the user straight to CallScreen.
        //   2. If the offer signal hasn't arrived yet (rare race when
        //      CallKit fires faster than the Convex realtime subscription),
        //      `_onRemoteOffer` will auto-fire acceptIncoming later.
        // The accept watchdog inside markAcceptedNatively covers the case
        // where the liveness probe couldn't run (offline) and no offer ever
        // arrives.
        service.markAcceptedNatively(callId: acceptedCallId);
        try {
          await service.acceptIncoming();
        } catch (e) {
          // The backend call may already be terminal (caller cancelled or it
          // timed out) — accept throws NOT_RINGING. Clear the stuck native
          // card instead of leaving a dead ringer on screen.
          debugPrint('NativeCallHandler: acceptIncoming failed: $e');
          service.clearNativeAccept();
          if (acceptedCallId != null) {
            await endNativeByCallId(acceptedCallId);
          }
        }
        break;
      case CallEventActionCallDecline(:final callKitParams):
        // Same reason as the accept above: none of the 1:1 reasoning below
        // applies to a card that never had a `calls` row behind it, and its
        // "no session" branch would fire a `calls:reject` for an id that is
        // not a call id.
        final declinedGroupId = _groupCallIdFromParams(callKitParams);
        if (declinedGroupId != null) {
          await _declineGroupCall(declinedGroupId);
          break;
        }
        final declinedCallId = _callIdFromParams(callKitParams);
        final current = service.session;
        if (current != null &&
            declinedCallId != null &&
            declinedCallId != current.callId) {
          // Declining a SECOND incoming card while another call is live
          // (busy scenario) — reject that call on the backend only; the
          // active call's session and native UI must stay untouched.
          final me = service.userId;
          if (me != null) {
            try {
              await service.api.rejectCall(
                callId: declinedCallId,
                userId: me,
                acceptingDeviceId: service.deviceId,
              );
            } catch (_) {}
          }
          break;
        }
        if (current != null) {
          await service.reject();
        } else {
          // Ghost card: no Dart session to reject through — service.reject()
          // would silently no-op, leaving backend state and the accept latch
          // untouched. Best-effort backend reject (harmless if the call is
          // already terminal), then dismiss that card — and only that card.
          final me = service.userId;
          if (declinedCallId != null && me != null) {
            try {
              await service.api.rejectCall(
                callId: declinedCallId,
                userId: me,
                acceptingDeviceId: service.deviceId,
              );
            } catch (_) {}
          }
          service.clearNativeAccept();
          if (declinedCallId != null) {
            await endNativeByCallId(declinedCallId);
          } else {
            // Identity-less decline and no session to protect — nothing can
            // be running that a blanket clear would harm.
            await endAllNative();
          }
        }
        break;
      case CallEventActionCallEnded(:final callKitParams):
        // A group card ended without being answered — swiped away, or ended
        // from the system UI. That is a decline, and it must not reach
        // `_endNamedCall`, which arbitrates a 1:1 session this card has no
        // relationship to and would hang up a live DM call standing beside
        // it.
        final endedGroupId = _groupCallIdFromParams(callKitParams);
        if (endedGroupId != null) {
          await _declineGroupCall(endedGroupId);
          break;
        }
        await _endNamedCall(
          service,
          _callIdFromParams(callKitParams),
          event.eventName,
        );
        break;
      case CallEventActionCallTimeout(:final id):
        // A group card that rang itself out. This event carries only the
        // native id — no `extra`, so no `groupCallId` to read — so the id has
        // to be recognised by deriving it back. Getting it wrong is not
        // harmless: an unrecognised timeout falls through to `_endNamedCall`,
        // which with a null callId and a RINGING session hangs that session
        // up. So a group card ringing out beside an incoming DM call would
        // have cancelled the DM call. See [_knownGroupCallIds] for why the
        // held invite is not a sufficient source on its own.
        final ringingGroupId = _groupCallForUuid(id) ??
            _matchingHeldInvite(id);
        if (ringingGroupId != null) {
          await _declineGroupCall(ringingGroupId);
          break;
        }
        // A timeout is only ever meaningful while the call is still RINGING.
        // Past that it is spurious, and there are two ways to get one: the
        // plugin wires the incoming notification's `deleteIntent` to the
        // timeout intent (so swiping the leftover card after answering fires
        // one), and a card whose `setCallConnected` didn't land keeps counting
        // down to its own 60s auto-timeout. Both used to hang up a healthy
        // call.
        final live = service.session;
        if (live != null &&
            live.status != CallStatus.incomingRinging &&
            live.status != CallStatus.outgoingRinging) {
          debugPrint('NativeCallHandler: ignoring timeout for $id — '
              'call ${live.callId} is ${live.status.name}');
          break;
        }
        await _endNamedCall(
          service,
          _callIdForUuid(id, live?.callId),
          event.eventName,
        );
        break;
      case CallEventActionCallToggleMute():
        await service.toggleMute();
        break;
      case CallEventActionCallToggleAudioSession(:final isActive):
        // CallKit activated/deactivated the AVAudioSession. On activation
        // the callkit plugin re-runs its own audio-session config which
        // clobbers our route, and the WebRTC mic unit may have started too
        // early to capture — CallService re-asserts both.
        if (isActive) {
          unawaited(service.onNativeAudioSessionActivated());
          // And the group call, which now raises real CallKit cards of its
          // own and so gets this event too. The 1:1 handler above returns
          // early when there is no 1:1 session — which is precisely the case
          // where this one has work to do.
          unawaited(
            GroupCallService.maybeInstance?.onNativeAudioSessionActivated() ??
                Future<void>.value(),
          );
        }
        break;
      case CallEventActionCallToggleHold():
        // Not implemented — we don't expose hold yet.
        break;
      case CallEventActionCallProviderDidReset():
        // CallKit died under us: the system already tore down every card,
        // so nothing native is left to protect — but the WebRTC session
        // (and the mic) would live on headless without a full teardown.
        // endCall also notifies the backend; no-op without a session.
        debugPrint('NativeCallHandler: CallKit provider reset — ending call');
        service.clearNativeAccept();
        await service.endCall();
        break;
      default:
        // Ignore the lifecycle bookkeeping events (start, callback, etc.).
        break;
    }
  }

  /// Incoming calls shown by native code (AppDelegate.swift on iOS,
  /// CallFcmService.kt on Android) mint their UUID natively — Dart never
  /// sees it unless we lift it off the accept event. Capturing it here lets
  /// [markConnected] target the right native call so the system timer runs.
  /// [CallKitParams] flavour of [_captureNativeUuid], for the sealed 3.x
  /// events. The map version stays because `activeCalls()` still hands back
  /// raw maps, which is what [replayColdStartCalls] reads.
  void _captureNativeUuidFromParams(CallKitParams params) {
    final uuid = params.id;
    final callId = params.extra?['callId']?.toString();
    if (uuid.isNotEmpty && callId != null && callId.isNotEmpty) {
      _rememberUuid(callId, uuid);
    }
  }

  void _captureNativeUuid(dynamic body) {
    if (body is! Map) return;
    final uuid = body['id']?.toString();
    final extra = body['extra'];
    final callId = extra is Map ? extra['callId']?.toString() : null;
    if (uuid != null && uuid.isNotEmpty && callId != null && callId.isNotEmpty) {
      _rememberUuid(callId, uuid);
    }
  }

  /// Insert with a size cap. Entries are consumed by [endNativeByCallId]
  /// (which removes on use), but a call that ends through any native-first
  /// path never gets that removal — unbounded growth over a long-lived
  /// process, and stale mappings shadowing nothing useful. Eight is far
  /// beyond any plausible set of concurrently-relevant calls; insertion
  /// order (LinkedHashMap) makes `keys.first` the oldest.
  void _rememberUuid(String callId, String uuid) {
    _uuidByCallId.remove(callId);
    _uuidByCallId[callId] = uuid;
    while (_uuidByCallId.length > 8) {
      _uuidByCallId.remove(_uuidByCallId.keys.first);
    }
  }

  /// Reconcile persisted native call state with backend truth after a
  /// (re)start. Called once per session right after the signaling
  /// subscription starts. Two jobs:
  ///
  ///   1. Replay a native accept that happened while no Dart was running
  ///      (killed-app flow: the plugin shows the call UI, the user taps
  ///      Accept, the plugin persists the call and launches the app — but
  ///      the accept EVENT fired before this isolate existed).
  ///   2. Clear ghost cards: calls the plugin still tracks whose backend
  ///      call went terminal while the app was dead. Previously iOS was
  ///      excluded from this entirely, which is exactly how stale ghost
  ///      ringers survived an app restart there.
  Future<void> replayColdStartCalls() async {
    if (kIsWeb) return; // no CallKit on web — nothing to replay.
    final service = CallService.instance;
    await _drainPendingFallbackEvents();
    List<dynamic> calls;
    try {
      calls = (await FlutterCallkitIncoming.activeCalls()) as List<dynamic>;
    } catch (e) {
      debugPrint('NativeCallHandler.replayColdStartCalls: $e');
      return;
    }

    // Backend truth: my live ringing/active call, if any. Distinguish "no
    // live call" from "couldn't ask" (offline) — when unreachable, stay
    // lenient and keep the old replay behavior rather than killing a
    // possibly-valid ring; the accept watchdog covers a wrong guess.
    Map<String, dynamic>? live;
    var backendReachable = false;
    final me = service.userId;
    if (me != null) {
      try {
        live = await service.api
            .getActiveCallOnce(userId: me)
            .timeout(const Duration(seconds: 4));
        backendReachable = true;
      } catch (e) {
        debugPrint(
            'NativeCallHandler.replayColdStartCalls: status fetch failed: $e');
      }
    }
    final liveId = live?['_id']?.toString();

    if (calls.isEmpty) {
      // Nothing native persisted — but a stale accept latch from a previous
      // run could still poison routing. Clear it if no call is live.
      if (backendReachable && live == null) service.clearNativeAccept();
      return;
    }

    var handled = false;
    for (final c in calls) {
      if (c is! Map) continue;
      // Android persists `isAccepted`; iOS reports `accepted`.
      final accepted = c['isAccepted'] == true || c['accepted'] == true;
      final extra = c['extra'];
      final callId = extra is Map ? extra['callId']?.toString() : null;
      final matchesLive = callId != null && callId == liveId;

      if (accepted && (matchesLive || !backendReachable)) {
        _captureNativeUuid(c);
        debugPrint('NativeCallHandler: replaying cold-start accept '
            'for ${c['extra']}');
        service.markAcceptedNatively(callId: callId);
        try {
          await service.acceptIncoming();
          handled = true;
        } catch (e) {
          // Call already terminal (cancelled / timed out while we booted).
          debugPrint('NativeCallHandler: cold-start accept failed: $e');
          service.clearNativeAccept();
        }
        break; // Only ever one live call at a time.
      }
      if (!accepted && matchesLive && live?['status'] == 'ringing') {
        // Genuinely still-ringing card — leave it up; the signaling
        // subscription delivers the invite/offer momentarily.
        handled = true;
        break;
      }
    }
    if (!handled && !service.inCall) {
      // Stale card(s) with nothing behind them — clear so the user isn't
      // left staring at (or answering) a dead ringer after reopening.
      //
      // Card by card, never `endAllCalls()`. This runs on EVERY session
      // attach, off a 4-second-timeout backend read, and `activeCalls()` on
      // Android only reports the last call — far too weak a basis for a
      // process-wide clear that broadcasts ENDED into every isolate.
      final stale = calls
          .whereType<Map>()
          .map((c) {
            final extra = c['extra'];
            return extra is Map ? extra['callId']?.toString() : null;
          })
          .whereType<String>()
          .toSet();
      for (final id in stale) {
        await endNativeByCallId(id);
      }
      if (stale.isEmpty) await endAllNative();
      if (backendReachable && live == null) service.clearNativeAccept();
    }
  }

  /// Bridged from AppDelegate's fallback CXProvider: the plugin wasn't
  /// registered when the invite push arrived, so the card the user answered
  /// lives on a provider the plugin doesn't know about. Runs the same
  /// validation + latch flow as a normal CallKit accept; the signaling
  /// subscription hydrates the session and auto-fires the accept.
  Future<void> handleFallbackAnswer(String callId) async {
    final service = CallService.maybeInstance;
    if (service == null) return;
    if (service.session == null && await _isCallLive(callId) == false) {
      debugPrint(
          'NativeCallHandler: fallback answer for dead call $callId — clearing');
      await endNativeByCallId(callId);
      return;
    }
    service.markAcceptedNatively(callId: callId);
    try {
      await service.acceptIncoming();
    } catch (e) {
      debugPrint('NativeCallHandler: fallback accept failed: $e');
      service.clearNativeAccept();
      await endNativeByCallId(callId);
    }
  }

  /// Fallback-card counterpart of [Event.actionCallDecline].
  Future<void> handleFallbackDecline(String callId) async {
    final service = CallService.maybeInstance;
    if (service == null) return;
    if (service.session != null && service.session!.callId == callId) {
      await service.reject();
      return;
    }
    final me = service.userId;
    if (me != null) {
      try {
        await service.api.rejectCall(
          callId: callId,
          userId: me,
          acceptingDeviceId: service.deviceId,
        );
      } catch (_) {}
    }
    service.clearNativeAccept();
    await endNativeByCallId(callId);
  }

  /// Hand a native end/timeout to [CallService] only when it names the call we
  /// are actually running. A native card can outlive its call, a sibling
  /// device's card can be ended independently, and — on Android — a second
  /// isolate can broadcast into ours (see MainActivity's engine cache), so an
  /// unqualified `endCall()` here is a loaded gun.
  ///
  /// A null [callId] means the event carried no identity at all (e.g. the
  /// Hang up button on the ongoing-call notification). That still ends the
  /// live call — refusing would break the one control the user has left.
  Future<void> _endNamedCall(
    CallService service,
    String? callId,
    String eventName,
  ) async {
    final live = service.session;
    if (live == null) {
      // Nothing of ours to end. Drop any accept latch so a dead call can't
      // poison the routing of the next one.
      service.clearNativeAccept();
      return;
    }
    if (callId != null && callId != live.callId) {
      debugPrint('NativeCallHandler: ignoring $eventName for $callId — '
          'live call is ${live.callId}');
      return;
    }
    // Our own teardown dismisses the card, and the plugin echoes that back as
    // an ENDED event. `_teardown` keeps the session around for 400ms so the UI
    // can animate out, so without this the echo re-enters endCall() and fires
    // a second `calls:end` at the backend.
    if (live.status == CallStatus.ended ||
        live.status == CallStatus.failed ||
        live.status == CallStatus.handedOff) {
      return;
    }
    await service.endCall();
  }

  /// Reverse of [_uuidFor], for the events that carry only the native id.
  /// Checks the captured map first (a natively-minted iOS UUID is only ever
  /// knowable that way), then the deterministic derivation of [liveCallId].
  String? _callIdForUuid(String uuid, String? liveCallId) {
    for (final e in _uuidByCallId.entries) {
      if (e.value == uuid) return e.key;
    }
    if (liveCallId != null && derivedUuid(liveCallId) == uuid) {
      return liveCallId;
    }
    return null;
  }

  /// `extra.callId` from a plugin event (the Convex callId that iOS /
  /// Android stashed when showing the native UI), or null.
  String? _callIdFromParams(CallKitParams params) {
    final callId = params.extra?['callId']?.toString();
    return (callId != null && callId.isNotEmpty) ? callId : null;
  }

  /// Group calls this process has seen a card for, newest last.
  ///
  /// Exists for one event: `CallEventActionCallTimeout`, which carries the
  /// native id and nothing else — no `extra`, so no `groupCallId`. Without a
  /// way to recognise a group card's id, that event falls through to
  /// `_endNamedCall`, which with a null callId and a RINGING session hangs it
  /// up: a group card ringing itself out beside an incoming DM call would
  /// cancel the DM call.
  ///
  /// The obvious source is `GroupCallService.pendingInvite`, and it is not
  /// enough on its own — the invite stops being offered at exactly the moment
  /// the card times out (both are INVITE_RING_WINDOW_MS), so the two race and
  /// the guard would sometimes read null. This remembers the id past that
  /// point.
  ///
  /// Bounded: a device left running for weeks must not accumulate these, and
  /// eight is far more group calls than can be ringing at once.
  static const int _groupMemory = 8;
  final _knownGroupCallIds = <String>[];

  void _rememberGroupCall(String groupCallId) {
    _knownGroupCallIds.remove(groupCallId);
    _knownGroupCallIds.add(groupCallId);
    if (_knownGroupCallIds.length > _groupMemory) {
      _knownGroupCallIds.removeAt(0);
    }
  }

  /// The group call whose card carries [uuid], if this process knows of one.
  String? _groupCallForUuid(String uuid) {
    for (final id in _knownGroupCallIds) {
      if (derivedUuid(id) == uuid) return id;
    }
    return null;
  }

  /// The invite currently in hand, if its card is the one [uuid] names.
  ///
  /// The second source, and the one that covers a card this process never
  /// raised: on iOS the card comes from PushKit, and if the overlay has not
  /// run yet — a cold launch, an invite that arrived before the widget tree
  /// did — [_knownGroupCallIds] is empty while the subscription's invite is
  /// not.
  String? _matchingHeldInvite(String uuid) {
    final held =
        GroupCallService.maybeInstance?.pendingInvite?['groupCallId']?.toString();
    if (held == null || held.isEmpty) return null;
    return derivedUuid(held) == uuid ? held : null;
  }

  /// The group call this card belongs to, or null for an ordinary 1:1 one.
  ///
  /// The two are answered by completely different code — `joinCall` against
  /// `groupCalls`, versus `acceptIncoming` against `calls` — and the plugin
  /// hands us one undifferentiated "the user pressed answer". The key's mere
  /// PRESENCE is the discriminant, written by CallFcmService.handleInvite on
  /// Android and by the PushKit handler on iOS; a 1:1 invite omits it rather
  /// than sending an empty one, so a typo on either side reads as "1:1" and
  /// is caught by the group call simply not connecting, not by a group call
  /// being accepted as a DM.
  String? _groupCallIdFromParams(CallKitParams params) {
    final id = params.extra?['groupCallId']?.toString();
    return (id != null && id.isNotEmpty) ? id : null;
  }

  /// Answer a group call from its native card.
  ///
  /// Deliberately narrower than the 1:1 accept beside it. A group call has no
  /// offer to wait for and no "accepted natively" latch to set: joining is a
  /// single mutation, after which `_GroupCallOverlay` sees `inCall` flip and
  /// pushes the call screen — the same path the in-app ringer's Join button
  /// takes. What it shares is the ghost guard: a card can outlive its call
  /// (everyone left while the phone was locked), and `joinCall` throwing
  /// CALL_ENDED must take the card down rather than leave it ringing.
  Future<void> _acceptGroupCall(String groupCallId) async {
    final group = await _attachedGroupService();
    if (group == null) {
      // Nothing to join through — signed out, or the wait below ran out.
      // Leaving the card up would ring at a call the user cannot reach.
      debugPrint('NativeCallHandler: group accept with no GroupCallService');
      await endNativeByCallId(groupCallId);
      return;
    }
    try {
      await group.joinCall(groupCallId);
      // Stops the card counting down to its own 60s auto-timeout, which the
      // plugin would otherwise fire mid-call and treat as a hang-up. The 1:1
      // path does this from CallService once media is up; a group call has no
      // single peer to be "connected" to, so joining IS the moment.
      await markConnected(groupCallId);
    } catch (e) {
      debugPrint('NativeCallHandler: group joinCall failed: $e');
      await endNativeByCallId(groupCallId);
    }
  }

  /// [GroupCallService], once it knows who it is.
  ///
  /// Answering from a killed app is the ordinary case for a push-raised card,
  /// not the edge one: the tap launches the process, and this event can reach
  /// us while auth is still being restored — before `attach` has given the
  /// service a userId to join as. Failing then would dismiss the card the user
  /// just tapped, which reads as the app refusing the call.
  ///
  /// Bounded rather than indefinite: past a few seconds the honest answer is
  /// that this device cannot join, and a ringing card that never becomes a
  /// call is worse than one that stops.
  Future<GroupCallService?> _attachedGroupService() async {
    const step = Duration(milliseconds: 250);
    const limit = Duration(seconds: 12);
    for (var waited = Duration.zero; waited < limit; waited += step) {
      final g = GroupCallService.maybeInstance;
      if (g != null && g.isAttached) return g;
      await Future<void>.delayed(step);
    }
    return null;
  }

  /// Decline a group call from its native card. Best-effort: the card is
  /// coming down either way, and a failed decline costs the starter a roster
  /// row that says "invited" until the call ends.
  Future<void> _declineGroupCall(String groupCallId) async {
    final group = GroupCallService.maybeInstance;
    if (group == null) return;
    try {
      await group.declineInviteById(groupCallId);
    } catch (e) {
      debugPrint('NativeCallHandler: group decline failed: $e');
    }
  }

  /// Backend liveness probe for a call. Returns false only on a definitive
  /// "not live" answer; null means "couldn't determine" (offline, timeout,
  /// not signed in) — callers should stay lenient then and let the accept
  /// watchdog arbitrate.
  Future<bool?> _isCallLive(String callId) async {
    final service = CallService.maybeInstance;
    final userId = service?.userId;
    if (service == null || userId == null) return null;
    try {
      final status = await service.api
          .getCallStatus(callId: callId, userId: userId)
          .timeout(const Duration(seconds: 3));
      return status == 'ringing' || status == 'active';
    } catch (e) {
      debugPrint('NativeCallHandler._isCallLive: $e');
      return null;
    }
  }

  /// Show the system "outgoing call" affordance (iOS green call indicator,
  /// Recents entry, Bluetooth/AirPods audio routing). Called by
  /// [CallService.initiate] right before sending the offer signal.
  Future<void> showOutgoing({
    required String callId,
    required String peerName,
    required CallMediaKind kind,
  }) async {
    if (!_nativeCallUi) return;
    final params = CallKitParams(
      id: _uuidFor(callId),
      nameCaller: peerName,
      handle: peerName,
      type: kind == CallMediaKind.video ? 1 : 0,
      extra: {'callId': callId},
      // Belt and braces. `CallService.initiate` already gates on
      // CallPermissions.ensure, but a grant can be revoked between that check
      // and here, and the cost of being wrong is the process rather than a
      // notification. Ignored on iOS. See showIncoming for the full rationale.
      callingNotification: NotificationParams(
        showNotification: await CallPermissions.granted(kind),
      ),
      ios: IOSParams(
        handleType: 'generic',
        supportsVideo: kind == CallMediaKind.video,
        // Proper session mode instead of the plugin's `.default`: enables
        // call-grade processing and biases video calls to the speaker.
        audioSessionMode:
            kind == CallMediaKind.video ? 'videoChat' : 'voiceChat',
      ),
    );
    try {
      await FlutterCallkitIncoming.startCall(params);
    } catch (e) {
      debugPrint('NativeCallHandler.showOutgoing failed: $e');
    }
  }

  /// Show the native incoming ringer from Dart — Android foreground path.
  /// (iOS foreground gets the CallKit ring from the VoIP push; Android's
  /// FCM service only shows the UI for background/killed, so a foreground
  /// invite would otherwise fall back to the in-app screen the WhatsApp
  /// model avoids.) Dedupes against a card CallFcmService may already
  /// have shown for the same call.
  Future<void> showIncoming({
    required String callId,
    required String callerName,
    required CallMediaKind kind,
    String? avatarUrl,
    /// Set for a GROUP invite, where [callId] is the groupCallId. Rides into
    /// the card's `extra` as the discriminant the accept path reads — see
    /// [_groupCallIdFromParams]. The push-raised twin of this card
    /// (CallFcmService.handleInvite) writes the identical key, and both
    /// derive the same native id from the same string, so the two are one
    /// card to the plugin rather than two.
    String? groupCallId,
  }) async {
    // Before the platform guard, deliberately. On iOS this whole method is a
    // no-op — the PushKit card is already up — but the overlay still calls it
    // for every invite, and this is the one place Dart is told a group card
    // exists at all. See [_rememberGroupCall].
    if (groupCallId != null) _rememberGroupCall(groupCallId);
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final active = (await FlutterCallkitIncoming.activeCalls()) as List<dynamic>;
      final already = active.any((c) =>
          c is Map &&
          ((c['extra'] as Map?)?['callId']?.toString() == callId));
      if (already) return;
      await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
        id: _uuidFor(callId),
        nameCaller: callerName,
        appName: 'MonkeyHub',
        avatar: avatarUrl,
        handle: callerName,
        type: kind == CallMediaKind.video ? 1 : 0,
        duration: 60000,
        extra: {'callId': callId, 'groupCallId': ?groupCallId},
        // Decided HERE, at ring time, because this is the last moment we get a
        // say. When the user taps Accept, the plugin's own broadcast receiver
        // starts a foreground service typed microphone/camera before any Dart
        // of ours runs — and on Android 14 that throws SecurityException out of
        // Service.onStartCommand and kills the process if the grant is missing.
        // The flag rides along with the persisted call data and is replayed on
        // accept, so setting it false here is what makes an ungranted answer
        // survivable (in-app UI only, no foreground service). The Kotlin ring
        // path does the same in CallFcmService.handleInvite.
        callingNotification: NotificationParams(
          showNotification: await CallPermissions.granted(kind),
        ),
        android: const AndroidParams(isShowFullLockedScreen: true),
      ));
    } catch (e) {
      debugPrint('NativeCallHandler.showIncoming failed: $e');
    }
  }

  /// Dismiss the native UI for a call we were running. Named call, named
  /// dismissal — [endNativeByCallId] resolves a PushKit-minted id through the
  /// plugin's own records and clears AppDelegate's fallback provider too, so
  /// there is nothing the old blanket `endAllCalls()` reached that this misses.
  Future<void> endNative(String callId) => endNativeByCallId(callId);

  /// End ONLY the native card for [callId] — safe while a different call is
  /// live on this device (busy scenario: dismissing the second card must not
  /// kill the active call's native session, which endAllCalls would).
  ///
  /// This is the default way to clear a card. `endAllCalls()` is reserved for
  /// the cases where we genuinely cannot name what we're clearing, because it
  /// broadcasts ENDED to every isolate in the process — which on Android is
  /// how a stray isolate once hung up a healthy call.
  Future<void> endNativeByCallId(String callId) async {
    if (!_nativeCallUi) return;
    final known = _uuidByCallId.remove(callId);
    // One retry after a short delay before giving up — this is the same
    // call a stuck-call push relies on to clear an orphaned CallKit/
    // ConnectionService card, so a single transient failure (a busy plugin
    // channel, a momentary platform-call race) shouldn't leave it stranded.
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        // Prefer the plugin's own record so a natively-minted id (iOS
        // PushKit) is matched exactly.
        var ended = false;
        final active =
            (await FlutterCallkitIncoming.activeCalls()) as List<dynamic>;
        for (final c in active) {
          if (c is Map &&
              ((c['extra'] as Map?)?['callId']?.toString() == callId)) {
            final uuid = c['id']?.toString();
            if (uuid != null && uuid.isNotEmpty) {
              await FlutterCallkitIncoming.endCall(uuid);
              ended = true;
            }
          }
        }
        if (!ended) {
          if (known != null) {
            // `known` is never a blind guess: it's either the UUID we
            // ourselves handed to FlutterCallkitIncoming.startCall
            // (showOutgoing/showIncoming, via _uuidFor) or one captured off
            // a genuine CallEventActionCallAccept event
            // (_captureNativeUuidFromParams). Safe to hand back to the
            // plugin on either platform even though activeCalls() didn't
            // report it — e.g. a card the plugin's own list has already
            // dropped, or Android's activeCalls() only reporting the last
            // call.
            await FlutterCallkitIncoming.endCall(known);
          } else if (Platform.isAndroid) {
            // No UUID we ourselves issued. Android can still reliably
            // derive one — both ring paths derive the id from the callId —
            // but the equivalent guess on iOS risks handing CallKit a UUID
            // it has never issued, so iOS stays excluded here.
            await FlutterCallkitIncoming.endCall(derivedUuid(callId));
          }
        }
        break;
      } catch (e) {
        if (attempt == 2) {
          debugPrint(
            'NativeCallHandler.endNativeByCallId failed after retry: $e',
          );
          break;
        }
        debugPrint('NativeCallHandler.endNativeByCallId failed, retrying: $e');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    // AppDelegate's last-resort ringer lives on a CXProvider the plugin can't
    // see, and it holds at most one card, so there is nothing finer to target.
    await _endIosFallbackCalls();
  }

  /// Last resort: clear every card, for the paths where the event carried no
  /// identity at all so there is nothing to target. Prefer
  /// [endNativeByCallId] — this broadcasts ENDED process-wide.
  Future<void> endAllNative() async {
    if (!_nativeCallUi) return;
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('NativeCallHandler.endAllNative failed: $e');
    }
    await _endIosFallbackCalls();
  }

  // AppDelegate's last-resort fallback ringer lives on a CXProvider the
  // flutter_callkit_incoming plugin doesn't know about, so the plugin's
  // endAllCalls can't dismiss it — ask AppDelegate directly.
  static const MethodChannel _voipChannel = MethodChannel('monkeyhub/voip');

  Future<void> _endIosFallbackCalls() async {
    if (kIsWeb || !Platform.isIOS) return;
    try {
      await _voipChannel.invokeMethod('endFallbackCalls');
    } catch (_) {}
  }

  /// True while a GROUP call is live. Wired at bootstrap (app.dart) —
  /// [NativeCallHandler] cannot import GroupCallService (import cycle), yet
  /// [deactivateIosAudioSession] MUST know about it: group calls raise no
  /// CallKit card, so AppDelegate's own no-op-while-any-card-alive guard is
  /// blind to them, and a 1:1 ring canceled DURING a group call would
  /// otherwise deactivate the session under the group call's live audio.
  static bool Function() groupCallActiveProbe = () => false;

  /// True while a 1:1 call is live — the mirror of [groupCallActiveProbe],
  /// for the group path's mic belt (see [stopDarwinMicCapture]): the two
  /// services share one audio-device module, so neither may stop its
  /// capture while the other is mid-call. Wired at bootstrap (app.dart).
  static bool Function() dmCallActiveProbe = () => false;

  /// Belt for the stale-mic bug: ask AppDelegate to `setActive(false)` the
  /// AVAudioSession, which it does only when NO call UI (plugin card or
  /// fallback-provider card) is still alive. The callkit plugin activates
  /// the session on every dial/answer/ring and historically nothing
  /// deactivated it — flutter_webrtc's own deactivation is gated on
  /// conditions the cancel path can never satisfy (see the vendored
  /// plugin's PATCHES.md). Called after every local teardown; harmless
  /// no-op mid-call, on Android/web/desktop, and on an app whose native
  /// side predates the handler (the error is swallowed).
  Future<void> deactivateIosAudioSession() async {
    if (kIsWeb || !Platform.isIOS) return;
    if (groupCallActiveProbe()) return;
    try {
      await _voipChannel.invokeMethod('deactivateAudioSession');
    } catch (_) {}
  }

  /// [deactivateIosAudioSession], repeated over the seconds after a
  /// teardown. The native guard reads the callkit plugin's own call list,
  /// and that list empties INSIDE the `CXEndCallAction` handler — which
  /// CallKit delivers a beat after `endCall` returns — so a single belt
  /// fired straight after teardown routinely found the card still listed
  /// and no-op'd; nothing then deactivated a session WebRTC re-activated
  /// while its audio unit wound down, and the orange dot outlived the call.
  /// Every pass is a no-op mid-call (any card alive, or a group call), so a
  /// call that starts inside the window is untouched.
  Future<void> deactivateIosAudioSessionSettled() async {
    if (kIsWeb || !Platform.isIOS) return;
    for (final gap in const [0, 500, 1000, 1500]) {
      if (gap > 0) await Future.delayed(Duration(milliseconds: gap));
      await deactivateIosAudioSession();
    }
  }

  /// Pull fallback-card answer/decline actions that fired before any Dart
  /// handler existed (cold background launch — AppDelegate queues them).
  /// Also flips AppDelegate to direct delivery for future ones. Runs at the
  /// top of [replayColdStartCalls]; idempotent (the native queue empties).
  Future<void> _drainPendingFallbackEvents() async {
    if (kIsWeb || !Platform.isIOS || _isIosSimulator) return;
    List<dynamic> events;
    try {
      events =
          await _voipChannel.invokeListMethod<dynamic>('takePendingEvents') ??
              const [];
    } catch (e) {
      debugPrint('NativeCallHandler._drainPendingFallbackEvents: $e');
      return;
    }
    for (final e in events) {
      if (e is! Map) continue;
      final callId = e['callId']?.toString();
      if (callId == null || callId.isEmpty) continue;
      switch (e['method']) {
        case 'onFallbackAnswer':
          await handleFallbackAnswer(callId);
          break;
        case 'onFallbackDecline':
          await handleFallbackDecline(callId);
          break;
      }
    }
  }

  /// AppDelegate's fallback CXProvider was reset by the system — same
  /// contract as the plugin's `ACTION_CALL_PROVIDER_DID_RESET`: every
  /// native card is gone, so any live Dart call must fully tear down.
  Future<void> handleProviderReset() async {
    final service = CallService.maybeInstance;
    if (service == null) return;
    debugPrint('NativeCallHandler: fallback provider reset — ending call');
    service.clearNativeAccept();
    await service.endCall();
  }

  /// Mirror the WebRTC "active" state to CallKit so the system call timer
  /// starts ticking and the audio session is correctly classified.
  Future<void> markConnected(String callId) async {
    if (!_nativeCallUi) return;
    final uuid = _uuidByCallId[callId];
    if (uuid == null) return;
    try {
      await FlutterCallkitIncoming.setCallConnected(uuid);
    } catch (e) {
      debugPrint('NativeCallHandler.markConnected failed: $e');
    }
  }
}
