import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/call_api.dart';
import '../backend/convex_client.dart';
import '../data/settings_store.dart';
import 'call_config.dart';
import 'call_media.dart';
import 'call_models.dart';
import 'call_permissions.dart';
import 'call_recovery.dart';
import 'call_stats_monitor.dart';
import 'native_call_handler.dart';

/// Single-call peer-to-peer WebRTC manager.
///
/// One [CallService] instance per app, owning at most one active [CallSession]
/// and its [RTCPeerConnection]. Mirrors the [ChangeNotifier] convention used
/// across the app — UI listens via `addListener` and reads [session],
/// [localStream], [remoteStream].
///
/// Signaling rides on Convex via `CallApi.subscribeCallSignals`; that
/// subscription is wired by `SignalingSubscriber` which delivers signals into
/// [handleRemoteSignal].
class CallService extends ChangeNotifier {
  CallService({required this.api});

  static CallService? _instance;
  static CallService get instance => _instance!;

  /// Null-safe variant for callers that can run before [ensure] (e.g. the
  /// fallback-card bridge draining events during early app init).
  static CallService? get maybeInstance => _instance;
  static CallService ensure(CallApi api) =>
      _instance ??= CallService(api: api);

  final CallApi api;

  /// Real mobile hardware, where flutter_webrtc's native `Helper` audio APIs
  /// (setSpeakerphoneOn, switchCamera) exist. On web/desktop those channels
  /// have no implementation and throw MissingPluginException — the browser/OS
  /// manages audio routing itself, so we simply skip them there.
  static bool get _isMobile =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  String? _userId;
  String? get userId => _userId;
  String? _deviceId;
  String? get deviceId => _deviceId;
  void attach({
    required String userId,
    required String displayName,
    String? deviceId,
  }) {
    _userId = userId;
    _deviceId = deviceId;
    // displayName is reserved for future use (eg sending it as part of the
    // call invite payload). Not consumed yet — the backend resolves names
    // server-side when pushing the call notification.

    // Warm the ICE config so the first call doesn't pay the action cold-start.
    // TURN creds are valid for 1 hour and we re-fetch at 50 min.
    unawaited(_iceServers());

    _watchActiveCall(userId);
  }

  // ───────── cross-device active-call watch ─────────
  //
  // The single source of truth for "is there a call on ANOTHER of my devices?".
  // Both [ActiveCallPill] (to render "Move here") and [CallButton] (to disable
  // while busy) read [activeCallElsewhere] / [busyElsewhere] from here instead
  // of each maintaining their own subscription and predicate.
  Subscription? _activeCallSub;
  String? _activeCallWatchUserId;
  Map<String, dynamic>? _activeCallRaw;

  // Every callId this device has ever held a local session for. A just-ended
  // call is excluded from [activeCallElsewhere] via this set, so the "Move
  // here" pill can't flash during the ~400ms window where [_teardown] has
  // already cleared [_session] but the `activeCallForUser` subscription hasn't
  // yet reported the call as ended. callIds are unique, so this never needs
  // clearing mid-session (only on logout, via [detachWatch]).
  final Set<String> _localCallIds = {};
  void _rememberLocalCall(String callId) {
    if (callId.isNotEmpty) _localCallIds.add(callId);
  }

  // `resubscribeWatch()` used to live here, to re-register this watch after a
  // socket reconnect. Removed: both transports replay their own query set, and
  // `ConvexBackend`'s SubscriptionRegistry covers a forced rebuild — this
  // subscription goes through it like every other one.

  void _watchActiveCall(String userId) {
    if (_activeCallWatchUserId == userId && _activeCallSub != null) return;
    _activeCallSub?.cancel();
    _activeCallSub = null;
    _activeCallWatchUserId = userId;
    _activeCallRaw = null;
    // Fire-and-forget; the callback drives state.
    api
        .subscribeActiveCall(
      userId: userId,
      onCall: (call) {
        _activeCallRaw = call;
        notifyListeners();
      },
      onError: (e) => debugPrint('CallService active-call watch error: $e'),
    )
        .then((s) {
      // Guard against a re-subscribe (new userId) that raced ahead of us.
      if (_activeCallWatchUserId != userId) {
        s.cancel();
        return;
      }
      _activeCallSub = s;
    });
  }

  /// The active call on ANOTHER of my devices, if any — else null. Excludes
  /// calls this device is or was part of (live session or a remembered local
  /// callId), so a call I just ended never resurfaces here.
  Map<String, dynamic>? get activeCallElsewhere {
    final c = _activeCallRaw;
    if (c == null || c['status'] != 'active') return null;
    final acc = c['acceptingDeviceId'] as String?;
    if (acc == null || acc == _deviceId) return null;
    final id = c['_id']?.toString() ?? '';
    if (id.isEmpty || id == _session?.callId || _localCallIds.contains(id)) {
      return null;
    }
    return c;
  }

  /// True when a call is active on another of my devices.
  bool get busyElsewhere => activeCallElsewhere != null;

  /// Stop watching and drop all cross-device state — call on logout.
  void detachWatch() {
    _activeCallSub?.cancel();
    _activeCallSub = null;
    _activeCallWatchUserId = null;
    _activeCallRaw = null;
    _localCallIds.clear();
    notifyListeners();
  }

  // ───────── active call state ─────────
  CallSession? _session;
  CallSession? get session => _session;

  RTCPeerConnection? _pc;

  /// Bumped whenever a PeerConnection is created or disposed. Callbacks and
  /// timers capture the value at install time and no-op once it has moved
  /// on, so a replaced PC (handoff, redial, duplicate offer) can never act
  /// on its successor's call.
  int _pcGeneration = 0;

  /// Owned backstop for the disconnected/closed grace window — cancelled on
  /// teardown and invalidated by generation, unlike the old anonymous Timer.
  Timer? _disconnectTimer;

  // ICE-restart recovery state — see [_scheduleIceRestart].
  Timer? _restartTimer;
  int _restartAttempt = 0;
  DateTime? _outageStart;

  /// Wall-clock ms of the last applied peer `state` signal (mute/video-off).
  /// Convex delivers `state` signals in server-insert order, not send order —
  /// a rapid mute→unmute can have its two `sendCallSignal` mutations land out
  /// of order, so without this a stale "muted" row applied after a newer
  /// "unmuted" one would freeze the peer's UI on muted forever, even though
  /// the actual track (applied synchronously, in real call order, on both
  /// ends) is unmuted. Each device's own clock only moves forward across its
  /// own successive sends, so comparing a peer's timestamps against each
  /// other is safe regardless of clock skew between devices. See
  /// [_onRemoteState].
  int? _lastPeerStateTs;

  /// Pings the backend every 20s while the call is active so
  /// `calls:gcStuckActive` can distinguish a genuinely abandoned call from
  /// one that's just running long. Started once the PC first connects,
  /// cancelled in [_teardown]/[_disposePc]. See [_startHeartbeat].
  Timer? _heartbeatTimer;

  /// Live connection-quality readout for the active call — null between
  /// calls and until the first stats poll lands. The call UI listens via
  /// ValueListenableBuilder so quality updates don't rebuild the screen.
  final ValueNotifier<CallQualitySnapshot?> callQuality = ValueNotifier(null);
  CallStatsMonitor? _stats;

  MediaStream? _localStream;
  MediaStream? _remoteStream;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Increments every time a remote track is delivered. Consumers use this to
  /// detect "same stream reference, new track inside it" — the audio track
  /// usually arrives one tick before the video track, so a reference-equality
  /// check alone misses the video and the remote renderer stays black.
  int _remoteStreamTick = 0;
  int get remoteStreamTick => _remoteStreamTick;

  /// Increments whenever [switchVideoQuality] swaps a new video track onto
  /// the existing [_localStream] object in place (replaceTrack +
  /// addTrack/removeTrack) — the stream reference itself never changes, so a
  /// reference-equality check in the renderer sync would miss the swap and
  /// leave the local renderer bound to the now-stopped old track forever.
  /// Same class of problem [_remoteStreamTick] solves for the remote side.
  int _localStreamTick = 0;
  int get localStreamTick => _localStreamTick;

  /// Set when the user accepted the incoming call via the native CallKit /
  /// ConnectionService UI. Consumed in two places:
  ///   - `_CallOverlay` skips pushing `IncomingCallScreen` and routes
  ///     directly to `CallScreen` so the user doesn't see the in-app
  ///     ringer flash when foregrounding after a CallKit accept.
  ///   - `_onRemoteOffer` auto-fires `acceptIncoming()` if the offer
  ///     arrives AFTER the CallKit tap (rare race: user accepts CallKit
  ///     while the realtime signal is still in flight).
  /// Reset by `_teardown` along with the rest of the session state.
  bool _acceptedNatively = false;
  bool get acceptedNatively => _acceptedNatively;

  /// The call the latch was set for, when the caller knew it. Lets the
  /// watchdog dismiss precisely that card instead of every card on the device.
  String? _latchedAcceptCallId;

  void markAcceptedNatively({String? callId}) {
    _latchedAcceptCallId = callId ?? _latchedAcceptCallId ?? _session?.callId;
    _armAcceptWatchdog();
    if (_acceptedNatively) return;
    _acceptedNatively = true;
    notifyListeners();
  }

  /// Watchdog armed whenever a native accept is latched. If the latch was
  /// set for a dead call (caller cancelled / ring timed out while the app
  /// was locked or killed), no offer will ever hydrate the session —
  /// `sendSignal` refuses signals for terminal calls — so without this the
  /// app sits frozen on a call that can never connect, and the stale latch
  /// poisons the NEXT call's routing (`_CallOverlay` skips the ringer).
  Timer? _acceptWatchdog;

  void _armAcceptWatchdog() {
    _acceptWatchdog?.cancel();
    _acceptWatchdog = Timer(const Duration(seconds: 10), () async {
      if (!_acceptedNatively) return;
      final s = _session;
      final stuck =
          _pc == null || s == null || s.status == CallStatus.incomingRinging;
      if (!stuck) return;
      debugPrint(
        'CallService: accept watchdog tripped — no offer arrived, '
        'treating call as dead (callId=${s?.callId})',
      );
      if (s != null) {
        await _teardown(CallStatus.failed, errorMessage: 'Call unavailable');
      } else {
        // No session of ours, so there is nothing here to tear down — and
        // crucially nothing to justify `endAllCalls()`. That is a
        // process-wide, call-agnostic sledgehammer: it broadcasts ENDED to
        // every isolate in the process, which is exactly how a stray isolate
        // used to hang up a call it knew nothing about. Dismiss only the card
        // we latched on, and only if we know which one it was.
        final latched = _latchedAcceptCallId;
        clearNativeAccept();
        if (latched != null) {
          unawaited(NativeCallHandler.instance.endNativeByCallId(latched));
        }
      }
    });
  }

  /// Reset the CallKit-accept latch without a session teardown — used when
  /// a native accept turns out to target a call with no Dart session (a
  /// ghost CallKit card), where `_teardown` would never run.
  void clearNativeAccept() {
    _acceptWatchdog?.cancel();
    _acceptWatchdog = null;
    _latchedAcceptCallId = null;
    if (!_acceptedNatively) return;
    _acceptedNatively = false;
    notifyListeners();
  }

  /// ICE candidates received before [_pc.setRemoteDescription] has resolved.
  /// We queue them up and replay once the remote description is set.
  final List<RTCIceCandidate> _pendingRemoteIce = [];
  bool _remoteDescSet = false;

  /// Outbound ICE candidates coalesce here for ~120ms (or 8 entries) and
  /// ship as one `ice-batch` signal — a gathering burst would otherwise
  /// cost one Convex mutation per candidate. Doubles as the pre-session
  /// buffer: candidates queued before [_session] exists stay here until
  /// [_flushPendingLocalIce] runs.
  final List<RTCIceCandidate> _iceOutBuffer = [];
  Timer? _iceFlushTimer;

  /// Cached `getIceConfig` response — TURN creds expire in 60min so we
  /// refresh after 50min. Cached across calls (within one session).
  List<Map<String, dynamic>>? _cachedIceServers;
  DateTime? _cachedIceServersAt;

  Future<List<Map<String, dynamic>>> _iceServers() async {
    final cached = _cachedIceServers;
    final at = _cachedIceServersAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 50)) {
      return cached;
    }
    final me = _userId;
    if (me == null) return const [];
    try {
      final fresh = await api.getIceConfig(me);
      _cachedIceServers = fresh;
      _cachedIceServersAt = DateTime.now();
      return fresh;
    } catch (e) {
      debugPrint('CallService._iceServers fetch failed: $e');
      // Last-resort fallback so the call still has a chance via STUN.
      return const [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ];
    }
  }

  /// Stream-event callback for the UI: pushed whenever an incoming call
  /// arrives. The overlay listens to this to navigate to the IncomingCallScreen.
  final ValueNotifier<int> incomingTick = ValueNotifier(0);

  // ───────── public API ─────────

  bool get inCall =>
      _session != null && _session!.status != CallStatus.idle &&
      _session!.status != CallStatus.ended &&
      _session!.status != CallStatus.failed;

  /// Caller path. Starts an outgoing call to [peerUserId].
  Future<void> initiate({
    required String peerUserId,
    required String peerName,
    required String roomId,
    required CallMediaKind kind,
  }) async {
    final me = _userId;
    if (me == null) throw StateError('CallService not attached');
    if (inCall) throw StateError('Already in a call');

    // Grants first, before anything observable exists. The native outgoing-call
    // UI below starts a foreground service typed microphone (and camera, for
    // video), which on Android 14 throws SecurityException out of the plugin's
    // service and kills the process if the grant is missing. CallPermissions
    // explains the refusal itself, so bailing silently here is correct.
    if (!await CallPermissions.ensure(kind)) return;

    try {
      // 1. Reserve the call row first so we have a callId for every signal
      //    that follows. ICE starts gathering the moment setLocalDescription
      //    resolves, and onIceCandidate needs the callId to route — so the
      //    session must be alive before any of that fires.
      final callId = await api.initiateCall(
        callerId: me,
        calleeId: peerUserId,
        roomId: roomId,
        type: kind.wire,
      );
      _rememberLocalCall(callId);
      _session = CallSession(
        callId: callId,
        roomId: roomId,
        peerUserId: peerUserId,
        peerName: peerName,
        mediaKind: kind,
        isCaller: true,
        status: CallStatus.outgoingRinging,
        startedAt: DateTime.now(),
        localVideoOff: kind == CallMediaKind.audio,
        // Loudspeaker for video, earpiece for voice — matches the route
        // applied when media attaches; avoids a wrong icon while ringing.
        speakerOn: kind == CallMediaKind.video,
      );
      notifyListeners();
      // Surface the native "outgoing call" affordance (green pill on iOS,
      // Recents entry, Bluetooth routing). Fire-and-forget — failure here
      // doesn't block the WebRTC handshake.
      //
      // This runs BEFORE [_attachLocalMedia] on purpose, even though on Android
      // it starts a foreground service typed microphone/camera. Two reasons it
      // is safe: the CallPermissions gate above has already established the
      // grants that type requires, and `initiate` is only ever reached from a
      // foreground tap, so the while-in-use start restriction is satisfied too.
      // Deliberately NOT moved after media attach: the plugin re-runs its own
      // audio-session config, which would then land after
      // `applyIosCallAudioConfig` and clobber the iOS call route (see the
      // flutter_webrtc pin note in pubspec.yaml).
      unawaited(NativeCallHandler.instance.showOutgoing(
        callId: callId,
        peerName: peerName,
        kind: kind,
      ));
      // Flush any candidates buffered before the session existed (no-op in
      // the happy path because PC isn't created yet, but harmless).
      await _flushPendingLocalIce();

      // 2. Now create the PC + media. Any ICE candidates produced here will
      //    see [_session] populated and ship via signaling immediately.
      _pc = await _createPeerConnection();
      await _attachLocalMedia(kind);

      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': kind == CallMediaKind.video,
      });
      await _pc!.setLocalDescription(offer);
      debugPrint(
        'CallService.initiate: offer sent kind=${kind.wire} '
        'sdpLen=${offer.sdp?.length ?? 0}',
      );

      // 3. Hand the offer to the callee. ICE candidates already in flight
      //    arrive in createdAt order, so the offer wins the race even though
      //    it's sent last here.
      await api.sendCallSignal(
        callId: callId,
        fromUserId: me,
        toUserId: peerUserId,
        fromDeviceId: _deviceId,
        kind: 'offer',
        payload: jsonEncode({
          'sdp': offer.sdp,
          'type': offer.type,
          // The callee's media kind must match the caller's exactly — if it
          // doesn't, the callee skips getUserMedia for video and the call
          // silently collapses to voice. Sniffing m=video from the SDP isn't
          // reliable under unified-plan (recvonly/inactive sections still
          // contain that token), so we carry the kind in-band.
          'mediaKind': kind.wire,
        }),
      );
    } catch (e, st) {
      debugPrint('CallService.initiate failed: $e\n$st');
      await _disposePc();
      _session = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Callee path. Accept the currently-ringing incoming call.
  Future<void> acceptIncoming() async {
    final me = _userId;
    final s = _session;
    if (me == null || s == null) return;
    if (s.status != CallStatus.incomingRinging) return;

    final pc = _pc;
    if (pc == null) {
      // The invite arrived but the WebRTC offer hasn't yet. Latch the
      // intent — `_onRemoteOffer`'s existing race-recovery (line ~445)
      // will auto-fire `acceptIncoming()` the moment the offer lands and
      // the PC is set up. This is the same flag CallKit uses when the
      // user taps Accept before the offer signal arrives.
      markAcceptedNatively(callId: s.callId);
      return;
    }

    try {
      await _attachLocalMedia(s.mediaKind);

      final answer = await pc.createAnswer({});
      await pc.setLocalDescription(answer);
      debugPrint(
        'CallService.acceptIncoming: answer sent kind=${s.mediaKind.wire} '
        'sdpLen=${answer.sdp?.length ?? 0}',
      );

      await api.acceptCall(
        callId: s.callId,
        userId: me,
        acceptingDeviceId: _deviceId,
      );
      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        kind: 'answer',
        payload: jsonEncode({'sdp': answer.sdp, 'type': answer.type}),
      );

      _session = s.copyWith(status: CallStatus.connecting);
      _acceptWatchdog?.cancel();
      notifyListeners();
    } catch (e, st) {
      debugPrint('CallService.acceptIncoming failed: $e\n$st');
      await endCall(errorMessage: 'Could not start call');
    }
  }

  Future<void> reject() async {
    final me = _userId;
    final s = _session;
    if (me == null || s == null) return;
    try {
      await api.rejectCall(
        callId: s.callId,
        userId: me,
        acceptingDeviceId: _deviceId,
      );
    } catch (_) {}
    await _teardown(CallStatus.ended);
  }

  /// End the call from either side. If still ringing as the caller, this
  /// sends a `cancel`; otherwise a normal `end`.
  Future<void> endCall({String? errorMessage}) async {
    final me = _userId;
    final s = _session;
    if (me == null || s == null) return;
    try {
      if (s.status == CallStatus.outgoingRinging && s.isCaller) {
        await api.cancelCall(callId: s.callId, userId: me);
      } else {
        await api.endCall(callId: s.callId, userId: me);
      }
    } catch (_) {}
    await _teardown(
      errorMessage != null ? CallStatus.failed : CallStatus.ended,
      errorMessage: errorMessage,
    );
  }

  // ───────── live controls ─────────

  Future<void> toggleMute() async {
    final ls = _localStream;
    final s = _session;
    if (ls == null || s == null) return;
    final newMuted = !s.localMuted;
    for (final t in ls.getAudioTracks()) {
      t.enabled = !newMuted;
    }
    _session = s.copyWith(localMuted: newMuted);
    notifyListeners();
    await _sendState();
  }

  Future<void> toggleVideo() async {
    final ls = _localStream;
    final s = _session;
    if (ls == null || s == null) return;
    if (s.mediaKind == CallMediaKind.audio) return; // no-op on voice calls
    final newOff = !s.localVideoOff;
    for (final t in ls.getVideoTracks()) {
      t.enabled = !newOff;
    }
    _session = s.copyWith(localVideoOff: newOff);
    notifyListeners();
    await _sendState();
  }

  Future<void> switchCamera() async {
    final ls = _localStream;
    if (ls == null) return;
    final tracks = ls.getVideoTracks();
    if (tracks.isEmpty) return;
    if (!_isMobile) return; // Helper.switchCamera is a mobile-only channel.
    try {
      await Helper.switchCamera(tracks.first);
    } catch (e) {
      debugPrint('switchCamera failed: $e');
    }
  }

  /// Guards [switchVideoQuality] against overlapping calls — two taps in
  /// quick succession would otherwise both read the same old track before
  /// either finished swapping it in, leaking a camera resource that no
  /// longer corresponds to what's being sent.
  bool _switchingVideoQuality = false;

  /// Live resolution/bitrate switch — persists the choice, then (if a video
  /// call is actually in progress) re-acquires the camera at the new tier
  /// and swaps it onto the existing sender via `replaceTrack`. No SDP
  /// renegotiation: the sender/transceiver stays put, only its track and
  /// encoder params change.
  Future<void> switchVideoQuality(VideoQualityTier tier) async {
    await SettingsStore.instance.setVideoQualityTier(tier);
    final s = _session;
    final pc = _pc;
    final oldStream = _localStream;
    if (s == null ||
        pc == null ||
        oldStream == null ||
        s.mediaKind == CallMediaKind.audio ||
        _switchingVideoQuality) {
      return;
    }
    final oldVideoTracks = oldStream.getVideoTracks();
    if (oldVideoTracks.isEmpty) return;
    final oldTrack = oldVideoTracks.first;
    _switchingVideoQuality = true;
    try {
      final newTrack = await getCallVideoOnlyTrack(tier);
      newTrack.enabled = !s.localVideoOff;
      final senders = await pc.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          await sender.replaceTrack(newTrack);
        }
      }
      // Add the new track before removing the old one, and never let a
      // throwing stop() skip the swap — otherwise a track that fails to
      // stop (seen on some Android OEMs, see GroupCallService.leaveCall)
      // would leave the stream with zero video tracks and every later
      // switch attempt silently no-oping on the empty-tracks guard above.
      oldStream.addTrack(newTrack);
      oldStream.removeTrack(oldTrack);
      try {
        await oldTrack.stop();
      } catch (e) {
        debugPrint('switchVideoQuality: old track stop failed: $e');
      }
      await configureVideoSenders(
        pc,
        maxBitrate: videoQualityPresets[tier]!.maxBitrate,
      );
      _localStreamTick++;
      notifyListeners();
    } catch (e) {
      debugPrint('switchVideoQuality($tier) failed: $e');
    } finally {
      _switchingVideoQuality = false;
    }
  }

  Future<void> toggleSpeaker() async {
    final s = _session;
    if (s == null) return;
    final next = !s.speakerOn;
    // Rewrite the CATEGORY first, not just the route. `defaultToSpeaker`
    // lives on flutter_webrtc's process-wide shared AVAudioSession config,
    // and `setSpeakerphoneOn` only overrides the current output port without
    // clearing that bit — so switching to the earpiece while the bit was
    // still set held only until the next thing reconfigured the session
    // from it, then snapped back to the loudspeaker.
    await _applyIosAudioConfig(s.mediaKind, speakerOn: next);
    await _applyAudioRoute(speaker: next);
  }

  /// Sets the audio output route (loudspeaker vs earpiece) and keeps the
  /// session's [speakerOn] flag in sync so the UI matches reality.
  ///
  /// Applied with the per-kind default when local media attaches (video →
  /// loudspeaker, voice → earpiece) on BOTH platforms, then re-asserted once
  /// the call connects — iOS only honors the route after its CallKit audio
  /// session goes active, so the attach-time call alone doesn't stick.
  Future<void> _applyAudioRoute({required bool speaker}) async {
    if (_isMobile) {
      // Web/desktop have no earpiece/loudspeaker switch — the browser/OS owns
      // output routing — and Helper.setSpeakerphoneOn throws there. Still keep
      // the speakerOn flag in sync below so the UI toggle stays coherent.
      try {
        await Helper.setSpeakerphoneOn(speaker);
      } catch (e) {
        debugPrint('setSpeakerphoneOn($speaker) failed: $e');
      }
    }
    final s = _session;
    if (s != null && s.speakerOn != speaker) {
      _session = s.copyWith(speakerOn: speaker);
      notifyListeners();
    }
  }

  /// CallKit activated the AVAudioSession (flutter_callkit_incoming's
  /// `actionCallToggleAudioSession` event, bridged by NativeCallHandler).
  /// Two problems converge exactly here:
  ///   1. The callkit plugin re-runs its own configureAudioSession at every
  ///      activation AND once more ~1200ms after answer — playAndRecord
  ///      with mode .default and no .defaultToSpeaker — clobbering any
  ///      route/category we set earlier. So re-assert ours now AND once
  ///      again after its delayed pass.
  ///   2. flutter_webrtc's mic unit may have started BEFORE activation
  ///      (it has no CallKit coordination), in which case it captures
  ///      silence until the track is re-primed — the mute→unmute "fix"
  ///      users discovered, done here programmatically.
  Future<void> onNativeAudioSessionActivated() async {
    final s = _session;
    if (s == null || !inCall) return;
    await _applyIosAudioConfig(s.mediaKind, speakerOn: s.speakerOn);
    await _applyAudioRoute(speaker: s.speakerOn);
    _reprimeLocalAudio();
    Future.delayed(const Duration(milliseconds: 1500), () {
      final s2 = _session;
      if (s2 == null || !inCall) return;
      unawaited(_applyIosAudioConfig(s2.mediaKind, speakerOn: s2.speakerOn));
      unawaited(_applyAudioRoute(speaker: s2.speakerOn));
    });
  }

  /// Re-assert the chosen output route a few times after connect.
  ///
  /// The callkit plugin re-runs its own `configureAudioSession` when CallKit
  /// activates the session AND once more ~1200ms after answer — both with
  /// mode `.default` and no `defaultToSpeaker`, clobbering whatever route we
  /// set. [onNativeAudioSessionActivated] is supposed to be our hook for
  /// exactly that, but its
  /// `ACTION_CALL_TOGGLE_AUDIO_SESSION` event never survives the plugin's
  /// own parser (see NativeCallHandler.start) — so on iOS it simply never
  /// fires, and the plugin's config was the last writer for the rest of the
  /// call. That is why a video call stayed pinned to the loudspeaker no
  /// matter what the toggle said.
  ///
  /// Cheap enough to just do unconditionally: three no-op-if-unchanged
  /// route writes bracketing the plugin's known clobber points, rather than
  /// waiting to be told about an activation we can't hear.
  void _scheduleAudioRouteReasserts() {
    for (final ms in const [400, 1500, 3000]) {
      Timer(Duration(milliseconds: ms), () {
        final s = _session;
        if (s == null || !inCall) return;
        if (s.status != CallStatus.active) return;
        unawaited(_applyIosAudioConfig(s.mediaKind, speakerOn: s.speakerOn));
        unawaited(_applyAudioRoute(speaker: s.speakerOn));
      });
    }
  }

  /// Cycle the local audio tracks' enabled flag to restart WebRTC's audio
  /// unit against the (now active) session. Ends in the user's actual mute
  /// state, so it's safe to call any time mid-call.
  void _reprimeLocalAudio() {
    final ls = _localStream;
    if (ls == null) return;
    final muted = _session?.localMuted ?? false;
    for (final t in ls.getAudioTracks()) {
      t.enabled = false;
      t.enabled = !muted;
    }
  }

  /// See [applyIosCallAudioConfig] — shared with the group-call mesh.
  Future<void> _applyIosAudioConfig(
    CallMediaKind kind, {
    required bool speakerOn,
  }) =>
      applyIosCallAudioConfig(kind, speakerOn: speakerOn);

  // ───────── inbound signaling ─────────

  /// Called by [SignalingSubscriber] for every fresh inbound signal.
  /// A session-creating signal (invite, or offer with no session) is only
  /// honored within 45s of its server-side creation — comfortably past the
  /// 30s ring timeout. Older rows are stale re-deliveries (typically the
  /// signaling subscription replaying unconsumed rows after an app restart)
  /// whose call is already terminal.
  static const _staleSignalMs = 45 * 1000;

  bool _isStaleSignal(Map<String, dynamic> signal) {
    final createdAt = (signal['createdAt'] as num?)?.toInt();
    if (createdAt == null) return false;
    return DateTime.now().millisecondsSinceEpoch - createdAt > _staleSignalMs;
  }

  Future<void> handleRemoteSignal(Map<String, dynamic> signal) async {
    final me = _userId;
    if (me == null) return;
    final kind = signal['kind'] as String?;
    final fromUserId = signal['fromUserId']?.toString();
    final fromDeviceId = signal['fromDeviceId'] as String?;
    final callId = signal['callId']?.toString();
    final payload = (signal['payload'] as String?) ?? '{}';
    if (kind == null || fromUserId == null || callId == null) return;

    // Track the peer's holding device so our outgoing signals (ICE in
    // particular) can route back precisely after a peer-side handoff.
    // Only update when the signal is from the peer (not from one of my
    // own devices during handoff bookkeeping).
    if (fromDeviceId != null && fromUserId != me) {
      final s = _session;
      if (s != null && s.callId == callId && s.peerDeviceId != fromDeviceId) {
        _session = s.copyWith(peerDeviceId: fromDeviceId);
        notifyListeners();
      }
    }

    // Invite → open the IncomingCallScreen IMMEDIATELY, before the caller
    // has finished its WebRTC offer. The session lives without a PC until
    // the offer arrives and `_onRemoteOffer` hydrates it.
    if (kind == 'invite') {
      // Freshness gate: the backend rings for 30s, so any invite older than
      // that (server-stamped createdAt) is a stale row re-delivered after an
      // app restart — its call is terminal and must not re-ring as a ghost.
      if (_isStaleSignal(signal)) {
        debugPrint('CallService: dropping stale invite callId=$callId');
        return;
      }
      final cur = _session;
      if (cur != null &&
          cur.status == CallStatus.outgoingRinging &&
          cur.peerUserId == fromUserId) {
        // Mutual-call glare: we're outgoing-ringing to the exact peer who
        // is now calling us. Deterministic tiebreak so exactly one call
        // survives — the winner keeps its outgoing and ignores this invite
        // (the loser cancels it server-side); the loser cancels its own
        // outgoing and rings for the winner's call instead.
        if (winsGlare(myUserId: me, peerUserId: fromUserId)) {
          unawaited(NativeCallHandler.instance.endNativeByCallId(callId));
          return;
        }
        try {
          await api.cancelCall(callId: cur.callId, userId: me);
        } catch (_) {}
        await _teardown(CallStatus.ended);
        // Fall through: ring for the winner's invite below.
      } else if (cur != null) {
        // Already in a call — auto-reject as busy. The reject mutation
        // will broadcast `taken` so the caller learns immediately. The
        // `taken` push excludes THIS device (it's the rejecting one), so
        // dismiss the second call's native card ourselves — targeted, so
        // the active call's native session survives.
        try {
          await api.rejectCall(
            callId: callId,
            userId: me,
            acceptingDeviceId: _deviceId,
          );
        } catch (_) {}
        unawaited(NativeCallHandler.instance.endNativeByCallId(callId));
        return;
      }
      _onRemoteInvite(
        callId: callId,
        fromUserId: fromUserId,
        payload: payload,
      );
      return;
    }

    // Taken → another of MY devices accepted or rejected this call. Drop
    // the incoming UI on this device unless this is the device that
    // actually accepted (byDeviceId == ours, or status already advanced
    // past incomingRinging).
    if (kind == 'taken') {
      await _onRemoteTaken(callId: callId, payload: payload);
      return;
    }

    // Handoff signals — see addendum design notes.
    if (kind == 'handoff-takeover') {
      // I'm the old accepting device. The mutation already targeted this
      // signal at my deviceId (via targetDeviceId), so we only get here
      // when it's truly meant for us. Tear down quietly — no error toast.
      await _onHandoffTakeover(callId: callId);
      return;
    }
    if (kind == 'handoff-prepare') {
      // I'm the peer. The sibling-device callee is taking over. Close my
      // existing PC and wait for the new device's offer.
      await _onHandoffPrepare(callId: callId);
      return;
    }
    if (kind == 'handoff-offer') {
      // I'm the peer in switching state. Apply the new offer and answer.
      await _onHandoffOffer(callId: callId, payload: payload, peerDeviceId: fromDeviceId);
      return;
    }
    if (kind == 'handoff-answer') {
      // I'm the new accepting device. Finish the renegotiation.
      await _onHandoffAnswer(callId: callId, payload: payload);
      return;
    }

    // Offer → either hydrate the invite-created session OR start a fresh
    // one if no invite was delivered (older caller / delivery race).
    if (kind == 'offer') {
      // Same freshness gate as `invite`, but only for the session-CREATING
      // path — an offer hydrating an already-ringing session is fine.
      if (_session == null && _isStaleSignal(signal)) {
        debugPrint('CallService: dropping stale offer callId=$callId');
        return;
      }
      final s = _session;
      if (s != null && s.callId != callId) {
        // Some other call's offer landed while we're already on this one —
        // busy-reject without disturbing our session (targeted native
        // dismiss for the same reason as the invite busy branch).
        try {
          await api.rejectCall(
            callId: callId,
            userId: me,
            acceptingDeviceId: _deviceId,
          );
        } catch (_) {}
        unawaited(NativeCallHandler.instance.endNativeByCallId(callId));
        return;
      }
      await _onRemoteOffer(callId: callId, fromUserId: fromUserId, payload: payload);
      return;
    }

    // For all other signals the callId must match my current session.
    final s = _session;
    if (s == null || s.callId != callId) return;

    switch (kind) {
      case 'answer':
        await _onRemoteAnswer(payload);
        break;
      case 'ice':
        await _onRemoteIce(payload);
        break;
      case 'ice-batch':
        await _onRemoteIceBatch(payload);
        break;
      case 'state':
        _onRemoteState(payload);
        break;
      case 'restart-request':
        // Peer detected the outage first; only the caller role re-offers.
        // Force past the connected-check — the outage may be asymmetric
        // (peer broken while our side still reads Connected).
        if (s.isCaller) {
          _scheduleIceRestart(_pcGeneration, immediate: true, force: true);
        }
        break;
      case 'restart-offer':
        await _onRestartOffer(payload);
        break;
      case 'restart-answer':
        await _onRestartAnswer(payload);
        break;
      case 'bye':
        await _teardown(CallStatus.ended);
        break;
      case 'reject':
        await _teardown(CallStatus.ended, errorMessage: 'Declined');
        break;
      case 'cancel':
        await _teardown(CallStatus.ended, errorMessage: 'Missed call');
        break;
    }
  }

  /// Opens the in-app IncomingCallScreen the moment the backend writes the
  /// `invite` row — no waiting on the caller's getUserMedia + offer.
  /// The session is created without a PC; `_onRemoteOffer` hydrates it
  /// when the offer arrives. If the user taps Accept before the offer
  /// lands, `acceptIncoming` sets `_acceptedNatively` and `_onRemoteOffer`
  /// auto-fires it once the PC is ready.
  void _onRemoteInvite({
    required String callId,
    required String fromUserId,
    required String payload,
  }) {
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final callerName = (parsed['callerName'] as String?) ?? 'Calling…';
      final type = parsed['type'] as String?;
      final roomId = (parsed['roomId'] as String?) ?? '';
      final avatarStorageId = parsed['callerAvatarStorageId'] as String?;
      final avatarUrl = parsed['callerAvatarUrl'] as String?;
      final mediaKind = CallMediaKindWire.parse(type);

      // NB: deliberately NOT calling _rememberLocalCall here. Merely ringing
      // isn't "holding" the call — if it's answered on another of my devices,
      // this device must be able to show the "Move here" pill (which
      // activeCallElsewhere suppresses for callIds in _localCallIds). Only real
      // participation (initiate as caller / handoffToHere) records the call, so
      // the caller-hangup pill flash stays suppressed.
      _session = CallSession(
        callId: callId,
        roomId: roomId,
        peerUserId: fromUserId,
        peerName: callerName,
        peerAvatarStorageId: avatarStorageId,
        mediaKind: mediaKind,
        isCaller: false,
        status: CallStatus.incomingRinging,
        startedAt: DateTime.now(),
        localVideoOff: mediaKind != CallMediaKind.video,
        speakerOn: mediaKind == CallMediaKind.video,
      );
      notifyListeners();
      incomingTick.value = incomingTick.value + 1;
      // Android foreground: FCM's service only rings for background/killed,
      // so surface the native full-screen ringer from here (WhatsApp model
      // — the receiver never sees an in-app ringer). No-op on iOS (PushKit
      // shows CallKit) and deduped against an existing card for this call.
      unawaited(NativeCallHandler.instance.showIncoming(
        callId: callId,
        callerName: callerName,
        kind: mediaKind,
        avatarUrl: avatarUrl,
      ));
      debugPrint(
        'CallService._onRemoteInvite: opened incoming UI '
        'callId=$callId kind=${mediaKind.wire}',
      );
    } catch (e, st) {
      debugPrint('CallService._onRemoteInvite failed: $e\n$st');
    }
  }

  /// A sibling device accepted/rejected this call. Tear down the local
  /// incoming ringer (and any CallKit UI from PushKit) unless WE are that
  /// device. We ignore the echo by comparing `byDeviceId` to our own;
  /// additionally, any session whose status has advanced past
  /// `incomingRinging` means we already accepted ourselves, so leave it
  /// alone.
  Future<void> _onRemoteTaken({
    required String callId,
    required String payload,
  }) async {
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final byDeviceId = parsed['byDeviceId'] as String?;
      if (byDeviceId != null &&
          _deviceId != null &&
          byDeviceId == _deviceId) {
        return; // own echo
      }
      final s = _session;
      if (s == null || s.callId != callId) {
        // No active session for this call — still dismiss any native UI
        // (e.g. CallKit from a PushKit invite that landed before the
        // subscription delivered the invite signal).
        await NativeCallHandler.instance.endNative(callId);
        return;
      }
      if (s.status != CallStatus.incomingRinging || _acceptedNatively) {
        // We're the accepting device; nothing to dismiss.
        return;
      }
      debugPrint(
        'CallService._onRemoteTaken: dismissing incoming session '
        'callId=$callId byDeviceId=${byDeviceId ?? "(unknown)"}',
      );
      await _teardown(CallStatus.ended);
    } catch (e, st) {
      debugPrint('CallService._onRemoteTaken failed: $e\n$st');
    }
  }

  // ───────── handoff ─────────

  /// Move the active call from whichever device holds it onto THIS
  /// device. Initiator-side flow: tell the backend, set up a local
  /// session, build a fresh PC, and send a `handoff-offer` to the peer.
  /// The peer renegotiates via `_onHandoffPrepare` / `_onHandoffOffer`;
  /// the old device tears down via `_onHandoffTakeover`.
  ///
  /// [activeCall] is the snapshot from `subscribeActiveCall` — must
  /// be `status: 'active'` and not already on this device.
  Future<void> handoffToHere(Map<String, dynamic> activeCall) async {
    final me = _userId;
    final myDevice = _deviceId;
    if (me == null || myDevice == null) return;
    if (_session != null) {
      throw StateError('Cannot handoff while a local call is active');
    }
    final callId = activeCall['_id']?.toString() ?? activeCall['callId']?.toString();
    final callerId = activeCall['callerId']?.toString();
    final calleeId = activeCall['calleeId']?.toString();
    final roomId = activeCall['roomId']?.toString() ?? '';
    final type = activeCall['type'] as String?;
    final peerName = (activeCall['peerName'] as String?) ?? 'Calling…';
    if (callId == null || callerId == null || calleeId == null) {
      throw StateError('Invalid active call payload');
    }
    final iAmCaller = callerId == me;
    final peerUserId = iAmCaller ? calleeId : callerId;
    final mediaKind = CallMediaKindWire.parse(type);

    // Taking over a call captures media on THIS device, so this device needs
    // the grants — the one that had the call before proves nothing about this
    // one. Bail before any session exists; CallPermissions shows the refusal.
    if (!await CallPermissions.ensure(mediaKind)) return;

    _rememberLocalCall(callId);
    _session = CallSession(
      callId: callId,
      roomId: roomId,
      peerUserId: peerUserId,
      peerName: peerName,
      mediaKind: mediaKind,
      isCaller: iAmCaller,
      status: CallStatus.switching,
      startedAt: DateTime.now(),
      localVideoOff: mediaKind != CallMediaKind.video,
      speakerOn: mediaKind == CallMediaKind.video,
    );
    notifyListeners();

    try {
      // 1. Tell the backend so it can write handoff-takeover and
      //    handoff-prepare signals. The mutation also flips
      //    `calls.acceptingDeviceId` so the pill updates everywhere.
      await api.handoffCall(
        callId: callId,
        userId: me,
        newDeviceId: myDevice,
      );

      // 2. Spin up a fresh PC + media on this device.
      _pc = await _createPeerConnection();
      await _attachLocalMedia(mediaKind);
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': mediaKind == CallMediaKind.video,
      });
      await _pc!.setLocalDescription(offer);

      // 3. Ship the offer to the peer. Once they answer, ICE candidates
      //    will already be in flight (onIceCandidate fires immediately
      //    after setLocalDescription).
      await api.sendCallSignal(
        callId: callId,
        fromUserId: me,
        toUserId: peerUserId,
        fromDeviceId: myDevice,
        kind: 'handoff-offer',
        payload: jsonEncode({
          'sdp': offer.sdp,
          'type': offer.type,
          'mediaKind': mediaKind.wire,
        }),
      );

      // 4. Watchdog: if the peer never answers, give up after 8s and
      //    surface a friendly error rather than hanging in `switching`.
      _armHandoffWatchdog(callId);
    } catch (e, st) {
      debugPrint('CallService.handoffToHere failed: $e\n$st');
      await _teardown(CallStatus.failed, errorMessage: 'Switch failed');
    }
  }

  Timer? _handoffWatchdog;
  void _armHandoffWatchdog(String callId) {
    _handoffWatchdog?.cancel();
    _handoffWatchdog = Timer(const Duration(seconds: 8), () async {
      final s = _session;
      if (s == null || s.callId != callId) return;
      if (s.status == CallStatus.switching) {
        debugPrint('CallService: handoff watchdog tripped');
        await _teardown(CallStatus.failed, errorMessage: 'Switch failed');
      }
    });
  }

  Future<void> _onHandoffTakeover({required String callId}) async {
    final s = _session;
    if (s == null || s.callId != callId) return;
    debugPrint('CallService._onHandoffTakeover: this device is being replaced');
    _session = s.copyWith(status: CallStatus.handedOff);
    notifyListeners();
    // Drop the PC without sending bye/end — the call is still alive on
    // the new device. NativeCallHandler clears any lingering CallKit UI.
    unawaited(NativeCallHandler.instance.endNative(callId));
    await _teardown(CallStatus.handedOff);
  }

  Future<void> _onHandoffPrepare({required String callId}) async {
    final s = _session;
    if (s == null || s.callId != callId) return;
    debugPrint('CallService._onHandoffPrepare: peer is switching device');
    // Drop the PC but KEEP the session (and the local stream) — we'll
    // hydrate against the incoming offer shortly. `_disposePc` would
    // also dispose the local stream, so do a narrower teardown.
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    _remoteDescSet = false;
    _pendingRemoteIce.clear();
    _remoteStream = null;
    _session = s.copyWith(status: CallStatus.switching);
    notifyListeners();
  }

  Future<void> _onHandoffOffer({
    required String callId,
    required String payload,
    String? peerDeviceId,
  }) async {
    final me = _userId;
    final s = _session;
    if (me == null || s == null || s.callId != callId) return;
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final sdp = parsed['sdp'] as String?;
      final type = parsed['type'] as String?;
      if (sdp == null || type == null) return;

      _pc = await _createPeerConnection();
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteDescSet = true;
      _drainPendingIce();

      // If we still have the local stream from the previous PC, re-add
      // its tracks; otherwise getUserMedia fresh.
      final existingLocal = _localStream;
      if (existingLocal != null && existingLocal.getTracks().isNotEmpty) {
        for (final t in existingLocal.getTracks()) {
          await _pc!.addTrack(t, existingLocal);
        }
      } else {
        await _attachLocalMedia(s.mediaKind);
      }

      final answer = await _pc!.createAnswer({});
      await _pc!.setLocalDescription(answer);
      await api.sendCallSignal(
        callId: callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        kind: 'handoff-answer',
        payload: jsonEncode({'sdp': answer.sdp, 'type': answer.type}),
      );

      _session = s.copyWith(
        status: CallStatus.connecting,
        peerDeviceId: peerDeviceId ?? s.peerDeviceId,
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('CallService._onHandoffOffer failed: $e\n$st');
      await _teardown(CallStatus.failed, errorMessage: 'Switch failed');
    }
  }

  Future<void> _onHandoffAnswer({
    required String callId,
    required String payload,
  }) async {
    final pc = _pc;
    final s = _session;
    if (pc == null || s == null || s.callId != callId) return;
    _handoffWatchdog?.cancel();
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final sdp = parsed['sdp'] as String?;
      final type = parsed['type'] as String?;
      if (sdp == null || type == null) return;
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteDescSet = true;
      _drainPendingIce();
      _session = s.copyWith(status: CallStatus.connecting);
      notifyListeners();
    } catch (e, st) {
      debugPrint('CallService._onHandoffAnswer failed: $e\n$st');
      await _teardown(CallStatus.failed, errorMessage: 'Switch failed');
    }
  }

  Future<void> _onRemoteOffer({
    required String callId,
    required String fromUserId,
    required String payload,
  }) async {
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final sdp = parsed['sdp'] as String?;
      final type = parsed['type'] as String?;
      if (sdp == null || type == null) return;

      _pc = await _createPeerConnection();
      await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteDescSet = true;
      _drainPendingIce();

      // Trust the caller's explicit kind in the payload. Fall back to an SDP
      // sniff only for offers from older clients that don't carry it — the
      // sniff catches the common case but mis-fires on unified-plan offers
      // that include an inactive/recvonly m=video section.
      final kindHint = parsed['mediaKind'] as String?;
      final mediaKind = kindHint != null
          ? CallMediaKindWire.parse(kindHint)
          : (sdp.contains('m=video')
              ? CallMediaKind.video
              : CallMediaKind.audio);
      final isVideo = mediaKind == CallMediaKind.video;
      debugPrint(
        'CallService._onRemoteOffer: applied kindHint=${kindHint ?? "(none)"} '
        'resolved=${mediaKind.wire} sdpLen=${sdp.length}',
      );

      // Hydrate an invite-created session in-place rather than blowing it
      // away — that session may already carry a peer name resolved by the
      // IncomingCallScreen, and bumping `incomingTick` again would
      // re-push the screen.
      final existing = _session;
      if (existing != null && existing.callId == callId) {
        _session = existing.copyWith(
          localVideoOff: !isVideo,
        );
        notifyListeners();
      } else {
        _session = CallSession(
          callId: callId,
          roomId: '', // not strictly needed for callee UI
          peerUserId: fromUserId,
          peerName: 'Calling…', // enriched via _CallOverlay profile lookup
          mediaKind: mediaKind,
          isCaller: false,
          status: CallStatus.incomingRinging,
          startedAt: DateTime.now(),
          localVideoOff: !isVideo,
          speakerOn: isVideo,
        );
        notifyListeners();
        incomingTick.value = incomingTick.value + 1;
      }
      await _flushPendingLocalIce();
      // Race recovery: if the user tapped Accept on CallKit (or on the
      // in-app invite UI) BEFORE the offer arrived (acceptIncoming
      // would have latched `_acceptedNatively` and returned early
      // because `_pc` was null), auto-fire it now. Fire-and-forget —
      // acceptIncoming notifies its own state transitions.
      if (_acceptedNatively) {
        unawaited(acceptIncoming());
      }
    } catch (e, st) {
      debugPrint('CallService._onRemoteOffer failed: $e\n$st');
      await _disposePc();
      _session = null;
      notifyListeners();
    }
  }

  Future<void> _onRemoteAnswer(String payload) async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final sdp = parsed['sdp'] as String?;
      final type = parsed['type'] as String?;
      if (sdp == null || type == null) return;
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteDescSet = true;
      _drainPendingIce();
      debugPrint(
        'CallService._onRemoteAnswer: applied signalingState=${pc.signalingState} '
        'sdpLen=${sdp.length}',
      );
      final s = _session;
      if (s != null && s.status == CallStatus.outgoingRinging) {
        _session = s.copyWith(status: CallStatus.connecting);
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('CallService._onRemoteAnswer failed: $e\n$st');
    }
  }

  Future<void> _onRemoteIce(String payload) async {
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      await _addRemoteCandidate(parsed);
    } catch (e) {
      debugPrint('CallService._onRemoteIce failed: $e');
    }
  }

  Future<void> _onRemoteIceBatch(String payload) async {
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final list = (parsed['candidates'] as List?) ?? const [];
      for (final e in list) {
        await _addRemoteCandidate((e as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('CallService._onRemoteIceBatch failed: $e');
    }
  }

  Future<void> _addRemoteCandidate(Map<String, dynamic> parsed) async {
    final raw = parsed['candidate'] as String? ?? '';
    // With LAN disabled, drop the peer's host candidates (incl.
    // mDNS-obfuscated `.local` ones) — probing them is what triggers
    // iOS's Local Network permission prompt.
    if (!kAllowLanCandidates &&
        (RegExp(r'\btyp\s+host\b').hasMatch(raw) || raw.contains('.local'))) {
      debugPrint('CallService: dropping remote host candidate');
      return;
    }
    final cand = RTCIceCandidate(
      parsed['candidate'] as String?,
      parsed['sdpMid'] as String?,
      (parsed['sdpMLineIndex'] as num?)?.toInt(),
    );
    if (_pc != null && _remoteDescSet) {
      await _pc!.addCandidate(cand);
    } else {
      _pendingRemoteIce.add(cand);
    }
  }

  void _onRemoteState(String payload) {
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      // Reject an out-of-order delivery: a signal older than the last one we
      // actually applied. Absent `ts` (shouldn't happen post-rollout, but
      // cheap to keep) fails open rather than getting stuck never applying.
      final ts = (parsed['ts'] as num?)?.toInt();
      if (ts != null && _lastPeerStateTs != null && ts < _lastPeerStateTs!) {
        return;
      }
      if (ts != null) _lastPeerStateTs = ts;
      final next = PeerMediaState.fromJson(parsed);
      final s = _session;
      if (s != null) {
        _session = s.copyWith(peerState: next);
        notifyListeners();
      }
    } catch (_) {}
  }

  void _drainPendingIce() {
    if (_pc == null) return;
    for (final c in _pendingRemoteIce) {
      _pc!.addCandidate(c);
    }
    _pendingRemoteIce.clear();
  }

  void _queueLocalIce(RTCIceCandidate cand) {
    _iceOutBuffer.add(cand);
    if (_iceOutBuffer.length >= 8) {
      unawaited(_flushPendingLocalIce());
      return;
    }
    _iceFlushTimer ??= Timer(const Duration(milliseconds: 120), () {
      _iceFlushTimer = null;
      unawaited(_flushPendingLocalIce());
    });
  }

  Future<void> _flushPendingLocalIce() async {
    _iceFlushTimer?.cancel();
    _iceFlushTimer = null;
    if (_iceOutBuffer.isEmpty) return;
    final s = _session;
    final me = _userId;
    // No session yet — keep buffering; initiate/_onRemoteOffer re-flush
    // once it exists.
    if (s == null || me == null) return;
    final batch = List<RTCIceCandidate>.of(_iceOutBuffer);
    _iceOutBuffer.clear();
    try {
      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        // Target the peer's specific device when known (post-handoff) so
        // siblings of the peer don't waste cycles parsing irrelevant
        // candidates. Pre-handoff this is null → broadcast as today.
        targetDeviceId: s.peerDeviceId,
        kind: 'ice-batch',
        payload: jsonEncode({
          'candidates': [
            for (final c in batch)
              {
                'candidate': c.candidate,
                'sdpMid': c.sdpMid,
                'sdpMLineIndex': c.sdpMLineIndex,
              },
          ],
        }),
      );
    } catch (e) {
      debugPrint('ice-batch send failed: $e');
    }
  }

  // ───────── helpers ─────────

  /// Patch the peer's display identity on the live session — called once
  /// the profile (name + avatar) resolves, e.g. `_CallOverlay`'s
  /// getProfile enrichment. Safe no-op when nothing changed.
  void updatePeerIdentity({String? peerName, String? avatarStorageId}) {
    final s = _session;
    if (s == null) return;
    final sameName = peerName == null || peerName == s.peerName;
    final sameAvatar =
        avatarStorageId == null || avatarStorageId == s.peerAvatarStorageId;
    if (sameName && sameAvatar) return;
    _session = s.copyWith(
      peerName: peerName,
      peerAvatarStorageId: avatarStorageId,
    );
    notifyListeners();
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    // Replacing a live PC (duplicate offer, handoff, redial) must release
    // its camera/encoder and invalidate its callbacks and timers first.
    final old = _pc;
    if (old != null) {
      _pc = null;
      try {
        await old.close();
      } catch (_) {}
    }
    _pcGeneration++;
    final gen = _pcGeneration;
    _disconnectTimer?.cancel();
    _restartTimer?.cancel();
    _restartAttempt = 0;
    _outageStart = null;
    final servers = await _iceServers();
    final config = {
      'iceServers': servers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'iceCandidatePoolSize': 2,
      // Full ICE — host > srflx > relay by priority, so TURN carries media
      // only when no direct path exists. Host (LAN) probing triggers iOS's
      // Local Network prompt; kAllowLanCandidates=false filters those out
      // instead of forcing relay for everything.
    };
    final pc = await createPeerConnection(config, {});

    pc.onIceCandidate = (cand) async {
      if (gen != _pcGeneration) return;
      if (cand.candidate == null) return;
      final typ = _candidateType(cand.candidate);
      if (!kAllowLanCandidates && typ == 'host') {
        debugPrint('CallService.onIceCandidate: dropping host candidate');
        return;
      }
      debugPrint('CallService.onIceCandidate: queueing ($typ)');
      _queueLocalIce(cand);
    };

    // NOTE: iOS Simulator's RTCMTLVideoView does not paint received video
    // frames (flutter-webrtc#1420 / #1535). Tracks arrive, connection reaches
    // Connected, but the remote view stays black. This is a plugin/renderer
    // limitation — test video on two physical devices, not the simulator.
    pc.onTrack = (event) {
      if (gen != _pcGeneration) return;
      final kind = event.track.kind;
      final streamIds = event.streams.map((s) => s.id).join(',');
      debugPrint('CallService.onTrack: kind=$kind streams=[$streamIds]');
      // Only advance the tick when we got a real stream to bind. If streams
      // is empty (no msid on the track) the renderer would otherwise rebind
      // to null and stay black.
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        _remoteStreamTick++;
      }
      notifyListeners();
    };

    pc.onIceConnectionState = (state) {
      if (gen != _pcGeneration) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _scheduleIceRestart(gen, immediate: true);
      } else if (state ==
              RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _noteConnectionRestored();
      }
    };

    pc.onConnectionState = (state) async {
      if (gen != _pcGeneration) return;
      debugPrint('RTC connection state: $state');
      final s = _session;
      if (s == null) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _noteConnectionRestored();
        final cur = _session;
        if (cur == null) return;
        _session = cur.copyWith(
          status: CallStatus.active,
          // Keep the original connect time across ICE-restart recoveries so
          // the elapsed timer doesn't reset mid-call.
          connectedAt: cur.connectedAt ?? DateTime.now(),
        );
        notifyListeners();
        unawaited(NativeCallHandler.instance.markConnected(cur.callId));
        // Re-assert the output route now the iOS audio session is live,
        // and re-prime the mic in case its unit started before the
        // CallKit session activated (silent-capture race).
        unawaited(_applyAudioRoute(speaker: cur.speakerOn));
        _reprimeLocalAudio();
        _scheduleAudioRouteReasserts();
        // Start (or restart, post-handoff) stats polling against this PC.
        _stats?.dispose();
        _stats = CallStatsMonitor(pc: pc, target: callQuality)..start();
        _startHeartbeat(cur.callId);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        // A network flip (Wi-Fi↔LTE) lands here — recover via ICE restart;
        // teardown happens only once recovery is exhausted.
        _scheduleIceRestart(gen, immediate: true);
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _scheduleIceRestart(gen);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        // Closed never recovers and has no restart path. Grace window so a
        // handoff's deliberate close (which swaps in a new PC) isn't killed.
        _disconnectTimer?.cancel();
        _disconnectTimer = Timer(const Duration(seconds: 15), () async {
          if (gen != _pcGeneration) return;
          final pc2 = _pc;
          if (pc2 == null) return;
          final st = pc2.connectionState;
          if (st == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
              st == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
            await _teardown(CallStatus.failed,
                errorMessage: 'Connection lost');
          }
        });
      }
    };

    return pc;
  }

  /// Recovery succeeded (or the outage cleared on its own) — reset the
  /// restart machinery and drop the "reconnecting" chip.
  void _noteConnectionRestored() {
    _restartTimer?.cancel();
    _disconnectTimer?.cancel();
    _restartAttempt = 0;
    _outageStart = null;
    final s = _session;
    if (s != null && s.reconnecting) {
      _session = s.copyWith(reconnecting: false);
      notifyListeners();
      // Re-assert my current mute/video state. `_sendState()` swallows send
      // failures with no retry, so a toggle sent right as the outage began
      // could have been silently dropped — nothing else re-sends it once the
      // link is back, leaving the peer's icon stuck on whatever it last
      // successfully received.
      unawaited(_sendState());
    }
  }

  /// Entry point of the recovery path — called on ICE/connection failure or
  /// disconnect (and on a peer's `restart-request`). Debounces, tracks the
  /// outage window, and drives [_attemptIceRestart]; gives up via
  /// [_teardown] when [shouldAbandonRestart] says so.
  void _scheduleIceRestart(int gen, {bool immediate = false, bool force = false}) {
    final s = _session;
    if (s == null) return;
    if (s.status != CallStatus.active && s.status != CallStatus.connecting) {
      return;
    }
    _outageStart ??= DateTime.now();
    if (!s.reconnecting) {
      _session = s.copyWith(reconnecting: true);
      notifyListeners();
    }
    if (_restartTimer?.isActive ?? false) return;
    _restartTimer = Timer(
      immediate ? Duration.zero : const Duration(seconds: 2),
      () => _attemptIceRestart(gen, force: force),
    );
  }

  Future<void> _attemptIceRestart(int gen, {bool force = false}) async {
    if (gen != _pcGeneration) return;
    final s = _session;
    final pc = _pc;
    final me = _userId;
    if (s == null || pc == null || me == null) return;
    if (!force &&
        pc.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _noteConnectionRestored();
      return;
    }
    if (shouldAbandonRestart(
      outageStart: _outageStart,
      now: DateTime.now(),
      attemptsSoFar: _restartAttempt,
    )) {
      await _teardown(CallStatus.failed, errorMessage: 'Connection lost');
      return;
    }
    _restartAttempt++;
    debugPrint(
      'CallService: ICE restart attempt $_restartAttempt '
      '(caller=${s.isCaller})',
    );
    try {
      if (s.isCaller) {
        await pc.restartIce();
        // restartIce() flags the next offer natively; pass iceRestart too so
        // the intent survives platform quirks.
        final offer = await pc.createOffer({'iceRestart': true});
        await pc.setLocalDescription(offer);
        await api.sendCallSignal(
          callId: s.callId,
          fromUserId: me,
          toUserId: s.peerUserId,
          fromDeviceId: _deviceId,
          targetDeviceId: s.peerDeviceId,
          kind: 'restart-offer',
          payload: jsonEncode({'sdp': offer.sdp, 'type': offer.type}),
        );
      } else {
        // Only the caller role re-offers (single deterministic restarter —
        // restart offers can never glare). Ask it to.
        await api.sendCallSignal(
          callId: s.callId,
          fromUserId: me,
          toUserId: s.peerUserId,
          fromDeviceId: _deviceId,
          targetDeviceId: s.peerDeviceId,
          kind: 'restart-request',
          payload: '{}',
        );
      }
    } catch (e) {
      debugPrint('CallService._attemptIceRestart failed: $e');
    }
    final delay = nextRestartDelay(_restartAttempt);
    // A null delay means the schedule is spent — run one last pass that
    // trips shouldAbandonRestart and tears down.
    _restartTimer = Timer(
      delay ?? const Duration(seconds: 8),
      () => _attemptIceRestart(gen),
    );
  }

  /// Peer's restart offer (caller role sent it after an outage). Applying
  /// it re-runs ICE on the existing PC — [_remoteDescSet] stays true and
  /// fresh candidates flow through the normal `ice` path.
  Future<void> _onRestartOffer(String payload) async {
    final me = _userId;
    final s = _session;
    final pc = _pc;
    if (me == null || s == null || pc == null) return;
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final sdp = parsed['sdp'] as String?;
      final type = parsed['type'] as String?;
      if (sdp == null || type == null) return;
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      final answer = await pc.createAnswer({});
      await pc.setLocalDescription(answer);
      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        targetDeviceId: s.peerDeviceId,
        kind: 'restart-answer',
        payload: jsonEncode({'sdp': answer.sdp, 'type': answer.type}),
      );
    } catch (e, st) {
      debugPrint('CallService._onRestartOffer failed: $e\n$st');
    }
  }

  Future<void> _onRestartAnswer(String payload) async {
    final pc = _pc;
    if (pc == null) return;
    // Only valid while our restart offer is pending — a stale answer after
    // we've moved on (new offer, recovered, handoff) is dropped.
    if (pc.signalingState !=
        RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      return;
    }
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      final sdp = parsed['sdp'] as String?;
      final type = parsed['type'] as String?;
      if (sdp == null || type == null) return;
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    } catch (e, st) {
      debugPrint('CallService._onRestartAnswer failed: $e\n$st');
    }
  }

  Future<void> _attachLocalMedia(CallMediaKind kind) async {
    // Classify the audio session before getUserMedia starts the mic unit.
    // `_session` is already set by the caller (initiate/acceptIncoming/etc)
    // with the correct per-kind default (loudspeaker for video, earpiece for
    // voice) — fall back to that same default if it's somehow unset yet.
    final speakerOn = _session?.speakerOn ?? (kind == CallMediaKind.video);
    await _applyIosAudioConfig(kind, speakerOn: speakerOn);
    final tier = SettingsStore.instance.videoQualityTier;
    _localStream = await getCallUserMedia(kind, tier: tier);
    final localKinds =
        _localStream!.getTracks().map((t) => t.kind).join(',');
    debugPrint(
      'CallService._attachLocalMedia: requested=${kind.wire} '
      'tier=${tier.wire} got=[$localKinds]',
    );
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    await configureVideoSenders(
      _pc!,
      maxBitrate: videoQualityPresets[tier]!.maxBitrate,
    );
    await preferH264Codec(_pc!);
    // Default output route: loudspeaker for video, earpiece for voice — on
    // both platforms. iOS won't latch this until its audio session is active,
    // so onConnectionState (connected) re-asserts it.
    await _applyAudioRoute(speaker: speakerOn);
    // Nothing else notifies between `outgoingRinging`/`connecting` being set
    // and the peer answering, so without this, listeners gating on
    // [localStream] (the call screen's local-camera preview, the caller
    // ringback tone) wouldn't see it become non-null until some unrelated
    // later change happened to fire.
    notifyListeners();
  }

  /// Pulls the `typ` token out of an ICE candidate SDP line:
  /// `candidate:… 1 udp 2122260223 192.168.x.x 54321 typ host …`
  /// Returns `host` / `srflx` / `prflx` / `relay` (or `?` if missing).
  /// Used only for log readability.
  String _candidateType(String? candidate) {
    if (candidate == null) return '?';
    final m = RegExp(r'\btyp\s+(\w+)').firstMatch(candidate);
    return m?.group(1) ?? '?';
  }

  Future<void> _sendState() async {
    final me = _userId;
    final s = _session;
    if (me == null || s == null) return;
    try {
      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        targetDeviceId: s.peerDeviceId,
        kind: 'state',
        payload: jsonEncode({
          'audioMuted': s.localMuted,
          'videoOff': s.localVideoOff,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  /// Idempotent — cancels any prior timer first, so an ICE-restart
  /// reconnect (which re-enters the `Connected` branch) just restarts the
  /// interval against the same callId rather than stacking timers.
  void _startHeartbeat(String callId) {
    _heartbeatTimer?.cancel();
    final me = _userId;
    if (me == null) return;
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(api.heartbeat(callId: callId, userId: me).catchError((e) {
        debugPrint('CallService heartbeat failed: $e');
      }));
    });
  }

  Future<void> _teardown(CallStatus terminal, {String? errorMessage}) async {
    _acceptWatchdog?.cancel();
    _acceptWatchdog = null;
    _handoffWatchdog?.cancel();
    _handoffWatchdog = null;
    _restartTimer?.cancel();
    _disconnectTimer?.cancel();
    _restartAttempt = 0;
    _outageStart = null;
    // Reset the native-accept latch SYNCHRONOUSLY — leaving it set through
    // the delayed null-out below opens a 400ms window where a new incoming
    // call would be mis-routed straight to CallScreen.
    _acceptedNatively = false;
    _latchedAcceptCallId = null;
    final s = _session;
    if (s != null) {
      _session = s.copyWith(status: terminal, errorMessage: errorMessage);
      notifyListeners();
      unawaited(NativeCallHandler.instance.endNative(s.callId));
    }
    await _disposePc();
    // Hold the terminal state for a moment so the UI can render "ended" /
    // toast the error before the screen pops itself.
    final endedCallId = s?.callId;
    Future.delayed(const Duration(milliseconds: 400), () {
      // A new call may have started inside this window — leave it alone.
      final now = _session;
      if (now != null && now.callId != endedCallId) return;
      _session = null;
      _remoteStream = null;
      _remoteStreamTick = 0;
      notifyListeners();
    });
  }

  Future<void> _disposePc() async {
    // Invalidate every callback/timer captured against the dying PC.
    _pcGeneration++;
    _disconnectTimer?.cancel();
    _restartTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _stats?.dispose();
    _stats = null;
    _remoteDescSet = false;
    _pendingRemoteIce.clear();
    _iceFlushTimer?.cancel();
    _iceFlushTimer = null;
    _iceOutBuffer.clear();
    try {
      final ls = _localStream;
      if (ls != null) {
        for (final t in ls.getTracks()) {
          await t.stop();
        }
        await ls.dispose();
      }
    } catch (_) {}
    _localStream = null;
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
  }

  @override
  void dispose() {
    _acceptWatchdog?.cancel();
    _handoffWatchdog?.cancel();
    _disconnectTimer?.cancel();
    _restartTimer?.cancel();
    _activeCallSub?.cancel();
    _activeCallSub = null;
    incomingTick.dispose();
    _disposePc();
    callQuality.dispose();
    super.dispose();
  }
}
