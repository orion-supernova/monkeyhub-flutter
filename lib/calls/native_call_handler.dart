import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import 'call_models.dart';
import 'call_permissions.dart';
import 'call_service.dart';

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
  // UUID crashes the app. Our Convex callIds are not UUIDs, so we mint a
  // UUIDv4 the first time we see each callId and reuse it across lifecycle
  // events (start → connected → end).
  final Map<String, String> _uuidByCallId = {};
  final Random _random = Random.secure();

  // When we ourselves call `FlutterCallkitIncoming.endAllCalls()` (driven
  // by WebRTC teardown), the package fires ACTION_CALL_ENDED back. We
  // rely on CallService.endCall() being idempotent — calling it again
  // after teardown is a no-op, so we don't need to dedup the echo.

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

  String _uuidFor(String callId) =>
      _uuidByCallId.putIfAbsent(callId, _mintUuidV4);

  String _mintUuidV4() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
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
    FlutterCallkitIncoming.onEvent.listen(_onEvent);
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
        // Ghost guard: a CallKit card can outlive its call (the caller
        // cancelled or the ring timed out while the app was locked/killed).
        // If Dart has no session for it, confirm with the backend that the
        // call is still live BEFORE latching the accept — a latched accept
        // for a dead call waits forever for an offer that can never come.
        if (service.session == null) {
          final callId = _callIdFromParams(callKitParams);
          if (callId != null && await _isCallLive(callId) == false) {
            debugPrint(
              'NativeCallHandler: stale CallKit accept callId=$callId — clearing',
            );
            await endAllNative();
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
        service.markAcceptedNatively();
        try {
          await service.acceptIncoming();
        } catch (e) {
          // The backend call may already be terminal (caller cancelled or it
          // timed out) — accept throws NOT_RINGING. Clear the stuck native
          // card instead of leaving a dead ringer on screen.
          debugPrint('NativeCallHandler: acceptIncoming failed: $e');
          service.clearNativeAccept();
          await endAllNative();
        }
        break;
      case CallEventActionCallDecline(:final callKitParams):
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
          // already terminal), then make sure nothing native lingers.
          final callId = _callIdFromParams(callKitParams);
          final me = service.userId;
          if (callId != null && me != null) {
            try {
              await service.api.rejectCall(
                callId: callId,
                userId: me,
                acceptingDeviceId: service.deviceId,
              );
            } catch (_) {}
          }
          service.clearNativeAccept();
          await endAllNative();
        }
        break;
      case CallEventActionCallEnded() || CallEventActionCallTimeout():
        // service.endCall() is idempotent — if this is the echo of our
        // own endNative() call, the session is already null and this is
        // a harmless no-op.
        await service.endCall();
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
        }
        break;
      case CallEventActionCallToggleHold():
        // Not implemented — we don't expose hold yet.
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
      _uuidByCallId[callId] = uuid;
    }
  }

  void _captureNativeUuid(dynamic body) {
    if (body is! Map) return;
    final uuid = body['id']?.toString();
    final extra = body['extra'];
    final callId = extra is Map ? extra['callId']?.toString() : null;
    if (uuid != null && uuid.isNotEmpty && callId != null && callId.isNotEmpty) {
      _uuidByCallId[callId] = uuid;
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
        service.markAcceptedNatively();
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
      await endAllNative();
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
      await endAllNative();
      return;
    }
    service.markAcceptedNatively();
    try {
      await service.acceptIncoming();
    } catch (e) {
      debugPrint('NativeCallHandler: fallback accept failed: $e');
      service.clearNativeAccept();
      await endAllNative();
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
    await endAllNative();
  }

  /// `extra.callId` from a plugin event (the Convex callId that iOS /
  /// Android stashed when showing the native UI), or null.
  String? _callIdFromParams(CallKitParams params) {
    final callId = params.extra?['callId']?.toString();
    return (callId != null && callId.isNotEmpty) ? callId : null;
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
  }) async {
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
        extra: {'callId': callId},
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

  /// Dismiss whichever native UI is currently showing. We use
  /// `endAllCalls()` instead of targeting by UUID because PushKit-driven
  /// incoming calls have their UUID minted in AppDelegate.swift and Dart
  /// never sees it — so a UUID-targeted dismiss would miss those.
  /// We only ever have one active call at a time, so clearing everything
  /// is the right behavior.
  Future<void> endNative(String callId) async {
    if (!_nativeCallUi) return;
    _uuidByCallId.remove(callId);
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('NativeCallHandler.endNative failed: $e');
    }
    await _endIosFallbackCalls();
  }

  /// End ONLY the native card whose `extra.callId` matches — safe while a
  /// different call is live on this device (busy scenario: dismissing the
  /// second card must not kill the active call's native session, which
  /// endAllCalls would).
  Future<void> endNativeByCallId(String callId) async {
    if (!_nativeCallUi) return;
    _uuidByCallId.remove(callId);
    try {
      final active = (await FlutterCallkitIncoming.activeCalls()) as List<dynamic>;
      for (final c in active) {
        if (c is Map &&
            ((c['extra'] as Map?)?['callId']?.toString() == callId)) {
          final uuid = c['id']?.toString();
          if (uuid != null && uuid.isNotEmpty) {
            await FlutterCallkitIncoming.endCall(uuid);
          }
        }
      }
    } catch (e) {
      debugPrint('NativeCallHandler.endNativeByCallId failed: $e');
    }
  }

  /// [endNative] without a callId — for clearing ghost/stale cards where
  /// Dart never had a session.
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
