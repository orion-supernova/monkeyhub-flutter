import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/call_api.dart';
import '../backend/convex_client.dart';
import '../backend/signaling_status.dart';
import '../data/settings_store.dart';
import '../media/file_url_cache.dart';
import 'call_config.dart';
import 'camera_health.dart';
import 'call_media.dart';
import 'call_models.dart';
import 'call_permissions.dart';
import 'call_recovery.dart';
import 'call_stats_monitor.dart';
import 'draw/draw_channel.dart';
import 'draw/draw_mirror.dart';
import 'draw/draw_model.dart';
import 'native_call_handler.dart';
import 'renegotiation.dart';
import 'screen_share.dart';

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
class CallService extends ChangeNotifier implements CallOptionsController {
  CallService({required this.api, SignalingStatus? signaling})
      : _signaling = signaling ?? SignalingStatus.instance {
    _routeSub = callAudioRouteChanges.listen(handleCallAudioRoute);
    _seenUpEdges = _signaling.upEdges;
    _seenNetworkEpoch = _signaling.networkEpoch;
    _signaling.addListener(_onSignalingStatus);
  }

  /// Transport health published by `ConnectionHealth`. See [SignalingStatus].
  final SignalingStatus _signaling;
  int _seenUpEdges = 0;
  int _seenNetworkEpoch = 0;

  /// When the peer last sent us any signal for the live call. Held against
  /// [kPeerAliveWindow] by [shouldAbandonRestart]: a peer still talking to us
  /// is a call worth keeping.
  DateTime? _lastPeerSignalAt;

  static CallService? _instance;
  static CallService get instance => _instance!;

  /// Null-safe variant for callers that can run before [ensure] (e.g. the
  /// fallback-card bridge draining events during early app init).
  static CallService? get maybeInstance => _instance;
  static CallService ensure(CallApi api) =>
      _instance ??= CallService(api: api);

  final CallApi api;

  /// Seam for tests: the function behind [_attachLocalMedia]'s acquisition.
  /// Production value is [getCallUserMedia]; tests inject a Completer-gated
  /// fake to reproduce the cancel-during-acquisition races deterministically.
  @visibleForTesting
  Future<MediaStream> Function(CallMediaKind kind, {VideoQualityTier tier})
      getUserMediaFn = getCallUserMedia;

  /// Seam for tests: the flutter_webrtc factory behind
  /// [_createPeerConnection].
  @visibleForTesting
  Future<RTCPeerConnection> Function(
    Map<String, dynamic> configuration,
    Map<String, dynamic> constraints,
  ) createPcFn = createPeerConnection;

  /// Seam for tests: the Darwin mic belt [_disposePc] runs last.
  /// Production value is [stopDarwinMicCapture].
  @visibleForTesting
  Future<void> Function() stopMicCaptureFn = stopDarwinMicCapture;

  /// Cap on any single platform call inside [_disposePc]. Each release step
  /// is bounded on its own so one wedged channel round-trip cannot hold the
  /// steps after it hostage — the peer connection closes, and the mic belt
  /// runs, no matter what the capturer stop did.
  @visibleForTesting
  Duration disposeStepTimeout = const Duration(seconds: 3);

  /// Cap on how long a terminal backend notify (cancel/end/reject) may run.
  /// Local teardown — the mic release — no longer waits on it at all; this
  /// only bounds how long [endCall]/[reject] linger afterwards.
  @visibleForTesting
  Duration terminalNotifyTimeout = const Duration(seconds: 5);

  /// Delay before the single fire-and-forget retry of a failed terminal
  /// notify. The backend's stuck-call GC converges regardless; the retry
  /// just shortens the peer's wait after a transient blip.
  @visibleForTesting
  Duration terminalNotifyRetryDelay = const Duration(seconds: 2);

  /// How long [_teardown] holds the terminal session so the UI can render
  /// "ended" before the screen pops itself.
  @visibleForTesting
  Duration teardownUiHold = const Duration(milliseconds: 400);

  /// Cap on the native end-call round-trip inside [_teardown] — it runs
  /// before WebRTC teardown (so a racing CallKit `didActivate` has nothing
  /// left to re-activate) but a wedged platform channel must never hold up
  /// the mic release behind it.
  @visibleForTesting
  Duration endNativeTimeout = const Duration(seconds: 2);

  /// How often a ringing incoming session asks the backend whether the
  /// call still rings — see [_armRingWatch].
  @visibleForTesting
  Duration ringWatchInterval = const Duration(seconds: 4);

  /// The longest this device rings for one call, whatever it hears. The
  /// backend gives up at 30s; this is that plus room for a slow invite.
  @visibleForTesting
  Duration ringCeiling = const Duration(seconds: 45);

  /// Base cadence of the in-call heartbeat ([_startHeartbeat]) and the
  /// random extra added to every beat. Both peers start beating the instant
  /// their PC connects — the same instant, to within a round-trip — and on
  /// a fixed period they stayed phase-locked for the whole call: every beat
  /// landed as two writes to the same `calls` row inside one OCC window,
  /// and the backend retried one of them on EVERY cycle (`calls.js:heartbeat`
  /// "Optimistic concurrency control failed", three a minute per call).
  /// Per-beat jitter breaks the lock. `gcStuckActive` tolerates 3 minutes
  /// of silence, so the worst-case gap here (interval + jitter) is nowhere
  /// near it.
  @visibleForTesting
  Duration heartbeatInterval = const Duration(seconds: 20);
  @visibleForTesting
  Duration heartbeatJitter = const Duration(seconds: 4);

  /// Source of the jitter; seedable so a test can pin the schedule.
  @visibleForTesting
  math.Random heartbeatRng = math.Random();

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
        _reconcileRinging(call);
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

  // ───────── ring dismissal ─────────
  //
  // Call signals are per USER, not per device: the first of my devices to
  // drain a `cancel` marks it consumed, and the row drops out of every
  // sibling's `signalsForUser` before a slower sibling (a Mac with no push
  // token, a Galaxy whose socket was throttled) ever reads it. On 2026-10-11
  // that left a MacBook and a Galaxy ringing for a call the iPhone had
  // already dismissed. The `activeCallForUser` watch is a query every device
  // holds on its own, so a ring this device saw it show and then saw it stop
  // showing is over, whoever consumed the signal.

  /// The call the watch last showed ringing for me as the callee.
  String? _serverRingingCallId;

  void _reconcileRinging(Map<String, dynamic>? call) {
    final id = call?['_id']?.toString();
    final status = call?['status'] as String?;
    final me = _userId;
    final ringingForMe = id != null &&
        status == 'ringing' &&
        me != null &&
        call?['calleeId']?.toString() == me;
    final prev = _serverRingingCallId;
    _serverRingingCallId = ringingForMe ? id : null;
    if (prev == null || prev == _serverRingingCallId) return;
    final answered = id == prev && status == 'active';
    // Answered right here: the accept owns what happens next.
    if (answered && call?['acceptingDeviceId'] == _deviceId) return;
    unawaited(_dismissDeadRing(prev, answeredElsewhere: answered));
  }

  /// Stop this device ringing for [callId], which the backend no longer
  /// rings: cancelled, missed, declined, or answered on another device.
  Future<void> _dismissDeadRing(
    String callId, {
    required bool answeredElsewhere,
  }) async {
    // An accept already on the wire decides for itself: its `not-ringing`
    // answer tears down, and a won accept is no ring to dismiss.
    if (_acceptingCallId == callId) return;
    final s = _session;
    if (s != null && s.callId == callId) {
      if (s.status != CallStatus.incomingRinging) return;
      debugPrint(
        'CallService: ring over server-side, dismissing callId=$callId '
        'answeredElsewhere=$answeredElsewhere',
      );
      // Clears a native accept latched for this dead call too: no offer
      // will ever come, and the accept watchdog would otherwise hold an
      // empty call screen up for its full 20s.
      await _teardown(
        CallStatus.ended,
        errorMessage: answeredElsewhere ? null : 'Missed call',
      );
      return;
    }
    // No session: a card the push raised on its own, or one a session
    // outlived. Same named dismissal the no-session `taken` path uses.
    if (_latchedAcceptCallId == callId) clearNativeAccept();
    await NativeCallHandler.instance.endNative(callId);
    _ackNativeDismissed(callId);
  }

  Future<void> _dropLatchedAcceptIfDead(String callId) async {
    final me = _userId;
    if (me == null) return;
    String? status;
    try {
      status = await api
          .getCallStatus(callId: callId, userId: me)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return; // Unknown: the accept watchdog still arbitrates.
    }
    if (status == 'ringing') return;
    final s = _session;
    if (s == null || s.callId != callId) return;
    if (s.status != CallStatus.incomingRinging || _pc != null) return;
    await _dismissDeadRing(callId, answeredElsewhere: status == 'active');
  }

  /// The belt to [_reconcileRinging], for an incoming session the watch
  /// never showed ringing (it attached late, or the socket stalled): asks
  /// the backend directly every [ringWatchInterval], and past
  /// [ringCeiling] stops ringing whatever the answer. Nothing else bounds
  /// a desktop ring, whose only dismissal is the realtime signal.
  Timer? _ringWatch;

  void _armRingWatch(String callId) {
    _ringWatch?.cancel();
    late final Timer timer;
    timer = Timer.periodic(ringWatchInterval, (t) async {
      bool stillMine() {
        final s = _session;
        return s != null &&
            s.callId == callId &&
            s.status == CallStatus.incomingRinging &&
            _acceptingCallId != callId;
      }

      if (!stillMine()) {
        // Past ringing, or a different call now: nothing left to watch.
        // An accept in flight is the one wait worth keeping alive.
        if (_acceptingCallId != callId) {
          timer.cancel();
          if (identical(_ringWatch, timer)) _ringWatch = null;
        }
        return;
      }
      if (ringWatchInterval * t.tick >= ringCeiling) {
        debugPrint('CallService: ring ceiling reached, callId=$callId');
        timer.cancel();
        await _teardown(CallStatus.ended, errorMessage: 'Missed call');
        return;
      }
      final me = _userId;
      if (me == null) return;
      String? status;
      try {
        status = await api
            .getCallStatus(callId: callId, userId: me)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        return; // Offline: the next tick, or the ceiling, decides.
      }
      if (status == 'ringing' || !stillMine()) return;
      await _dismissDeadRing(callId, answeredElsewhere: status == 'active');
    });
    _ringWatch = timer;
  }

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

  /// The outgoing call between the tap and its backend row: everything the
  /// call screen shows except a callId, which the reservation round trip
  /// supplies. Set so the screen slides up on the tap instead of a network
  /// trip later; display only. Nothing that routes signals or talks to the
  /// native layer reads it. Cleared in the same notify that sets [session],
  /// or on its own when the reservation fails or the caller hangs up first.
  CallSession? _dialing;
  CallSession? get dialing => _dialing;

  /// Completes once the call screen that went up for the dial has finished
  /// sliding in. Set by the overlay that pushes it; display only.
  ///
  /// [initiate] holds the native setup (CallKit's outgoing call, the audio
  /// session, the camera and mic, the peer connection) until then. That work
  /// runs on the platform thread, which on iOS is the thread that presents
  /// Flutter's frames, so starting it mid-slide froze the slide. The wait is
  /// at most what is left of the route's transition (500 ms for iOS's
  /// Cupertino route), and usually nothing: the backend round trip before
  /// it is longer.
  Future<void>? screenSettled;

  /// A callee's `ringing` report that beat [initiate]'s own response here
  /// (the push and its report can outrun the mutation's reply on a slow
  /// box). Applied when the session for that callId is created.
  String? _earlyRingingCallId;

  /// Whether this process is in the foreground, for the callee's ringing
  /// report: a foregrounded app has its ringer up (CallKit or in-app),
  /// a backgrounded one leaves the report to the native push handler.
  @visibleForTesting
  bool Function() appInForegroundFn = () {
    final st = WidgetsBinding.instance.lifecycleState;
    return st == null || st == AppLifecycleState.resumed;
  };

  RTCPeerConnection? _pc;

  /// Bumped whenever a PeerConnection is created or disposed. Callbacks and
  /// timers capture the value at install time and no-op once it has moved
  /// on, so a replaced PC (handoff, redial, duplicate offer) can never act
  /// on its successor's call.
  int _pcGeneration = 0;

  /// Same pattern as [_pcGeneration], for media acquisition: bumped at every
  /// [_attachLocalMedia] start and in [_disposePc]. A getUserMedia future
  /// that resolves after its epoch moved on belongs to a call that no longer
  /// exists (canceled mid-acquire, or replaced by an instant redial) — the
  /// resolver stops the orphaned stream on the spot and aborts, because
  /// nothing else will ever see it.
  int _mediaEpoch = 0;

  /// Owned backstop for the disconnected/closed grace window — cancelled on
  /// teardown and invalidated by generation, unlike the old anonymous Timer.
  Timer? _disconnectTimer;

  // ICE-restart recovery state — see [_scheduleIceRestart].
  Timer? _restartTimer;
  int _restartAttempt = 0;
  DateTime? _outageStart;
  DateTime? _lastRestartAt;

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

  /// The live peer connection, for read-only stats (the call screen's voice
  /// level). Null between calls.
  RTCPeerConnection? get peerConnection => _pc;

  /// The screen this device is sharing, while it is. One stream per call,
  /// kept across shares, so the id the peer learns from `state` stays the
  /// id its slot was negotiated with — see [GroupCallService.screenStream]
  /// for the longer version of why.
  MediaStream? _screenStream;
  MediaStream? get screenStream => _screenStream;
  int localScreenStreamTick = 0;
  bool _localScreenSharing = false;
  bool get localScreenSharing => _localScreenSharing;

  /// True from the moment a share was asked for until the platform is
  /// actually sending it — on iOS, until the broadcast the system picker
  /// offered has started. See the group service's field of the same name.
  bool _screenSharePending = false;
  bool get screenSharePending => _screenSharePending;

  /// The peer's screen, while it shares one — told from its camera by the
  /// ids its `state` names (see [PeerMediaState]); until that state lands a
  /// stream waits in [_remoteStreamsById].
  MediaStream? _remoteScreenStream;
  MediaStream? get remoteScreenStream => _remoteScreenStream;
  int _remoteScreenStreamTick = 0;
  int get remoteScreenStreamTick => _remoteScreenStreamTick;
  final Map<String, MediaStream> _remoteStreamsById = {};

  /// Ids the peer has ever named as its screen — see
  /// [GroupPeer.screenStreamIds].
  final Set<String> _remoteScreenStreamIds = {};

  /// Our two outbound video slots — camera and screen — each negotiated
  /// once and then switched with `replaceTrack`, and the link's offer/answer
  /// bookkeeping. See `renegotiation.dart`. The caller is the offerer.
  RTCRtpSender? _camSender;
  RTCRtpSender? _screenSender;
  final LinkNegotiation _negotiation = LinkNegotiation();

  /// The drawing channel over a shared screen: opened by the caller before
  /// its offer so it rides the initial SDP, received by the callee.
  RTCDataChannel? _drawChannel;
  static const String _peerKey = 'peer';
  final DrawModel drawModel = DrawModel();
  late final DrawChannels _draw = DrawChannels(model: drawModel);

  /// The drawing, shown outside the app while we share and the app is out
  /// of sight — Android's overlay, iOS's Picture in Picture board.
  late final DrawMirror drawMirror = DrawMirror(model: drawModel, channels: _draw);

  /// Bumped when a minimised call wants its screen back — the in-call
  /// pill's "return". The overlay that pushes the call screen listens.
  final ValueNotifier<int> reopenTick = ValueNotifier<int>(0);

  /// Whether this call's audio session is live, so a tone played into it is
  /// heard: the caller's ringback waits on it. On an iPhone a CallKit call's
  /// session belongs to the system until `didActivate`, and Apple's contract
  /// is that audio starts there; a ringback started before it could play
  /// into a session that was not yet the call's. Everywhere else the
  /// session is live once local media is. [callAudioLiveFallback] covers an
  /// activation event that never arrives.
  bool get callAudioLive => _callAudioLive;
  bool _callAudioLive = false;
  Timer? _callAudioLiveTimer;

  @visibleForTesting
  Duration callAudioLiveFallback = const Duration(milliseconds: 1500);

  /// Bumped on every native activation of the call's session, so a tone
  /// already playing can restart in the session it now has.
  final ValueNotifier<int> callAudioActivations = ValueNotifier<int>(0);

  bool get _systemOwnsCallAudio =>
      !kIsWeb && Platform.isIOS && !NativeCallHandler.instance.isIosSimulator;

  void _markCallAudioLive() {
    _callAudioLiveTimer?.cancel();
    _callAudioLiveTimer = null;
    if (_callAudioLive) return;
    _callAudioLive = true;
    notifyListeners();
  }

  void _resetCallAudioLive() {
    _callAudioLiveTimer?.cancel();
    _callAudioLiveTimer = null;
    _callAudioLive = false;
  }

  /// Whether this device is drawing over the shared screen right now — the
  /// pen on the call screen and on the in-call pill are one switch. Only
  /// meaningful while a screen is shared; cleared with the share.
  final ValueNotifier<bool> drawArmed = ValueNotifier<bool>(false);

  /// Seams for tests — the platform calls behind the live controls.
  @visibleForTesting
  Future<MediaStream> Function({ScreenShareSource? source}) getDisplayMediaFn =
      ScreenShare.capture;
  @visibleForTesting
  late Future<MediaStreamTrack> Function(VideoQualityTier tier)
      getVideoTrackFn =
      (tier) => getCallVideoOnlyTrack(tier, back: _camFacingBack);
  @visibleForTesting
  Future<MediaStream> Function(String label) createLocalStreamFn =
      createLocalMediaStream;
  @visibleForTesting
  Future<bool> Function(CallMediaKind kind) ensurePermissionsFn =
      CallPermissions.ensure;
  @visibleForTesting
  Future<void> Function(RTCPeerConnection pc) preferCodecFn = preferH264Codec;
  @visibleForTesting
  Future<bool?> Function(
    CallMediaKind kind, {
    required bool speakerOn,
    required bool headsetWins,
    String? callId,
  }) applyCallAudioFn = applyCallAudioResolved;

  MediaStreamTrack? get _camTrack {
    final v = _localStream?.getVideoTracks();
    return (v == null || v.isEmpty) ? null : v.first;
  }

  MediaStreamTrack? get _screenTrack {
    final v = _screenStream?.getVideoTracks();
    return (v == null || v.isEmpty) ? null : v.first;
  }

  /// Whether this device is sending its camera right now.
  bool get localCamActive =>
      _camTrack != null && !(_session?.localVideoOff ?? true);

  /// Whether ANY video is on the call — ours or the peer's, camera or
  /// screen. The call screen picks its layout on this; see
  /// [GroupCallService.hasAnyVideo].
  bool get hasAnyVideo {
    if (localCamActive || _localScreenSharing) return true;
    final s = _session;
    if (s == null) return false;
    if (s.peerState.screenSharing && _remoteScreenStream != null) return true;
    final rs = _remoteStream;
    return !s.peerState.videoOff &&
        rs != null &&
        rs.getVideoTracks().isNotEmpty;
  }

  int get _activeVideoSlots =>
      (_camTrack != null ? 1 : 0) + (_screenTrack != null ? 1 : 0);

  /// Test-only: seed a stream as if an acquisition had just landed — for
  /// exercising the no-session cleanup branch of [endCall] without
  /// choreographing the full race that produces it.
  @visibleForTesting
  void debugSetLocalStreamForTest(MediaStream? stream) {
    _localStream = stream;
  }

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

  /// Re-entrancy guard for [acceptIncoming], holding the callId currently
  /// being accepted (null when idle). A CallKit accept event and the
  /// resume-triggered `replayColdStartCalls` can both fire `acceptIncoming`
  /// for the same live session, and the `incomingRinging` status check inside
  /// stays true until the very last line — so two runs could otherwise race
  /// `createAnswer`/`acceptCall`, with one ending the other's (possibly
  /// already-active) call. Scoped to the callId, NOT a bare bool: if an accept
  /// for call A wedges on a dead socket and A is torn down, a fresh incoming
  /// call B must still be answerable — a bool would drop B until A's
  /// round-trip finally resolved. The finally only clears its own callId, so a
  /// late-resolving A can't wipe B's guard.
  String? _acceptingCallId;

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
    // 20s, not 10s: this only has to rescue a native accept whose OFFER never
    // arrives, and on a cold start (killed app woken by the VoIP push) the
    // offer can take many seconds to land — boot, keychain deviceId, auth, the
    // signaling subscription, then delivery. Ten seconds routinely expired
    // before a perfectly healthy offer arrived and false-killed the call as
    // "Call unavailable". [acceptIncoming] cancels this the moment it starts
    // real work, so a slow-but-progressing accept never reaches here.
    _acceptWatchdog = Timer(const Duration(seconds: 20), () async {
      if (!_acceptedNatively) return;
      final s = _session;
      // Stuck ONLY when no offer ever arrived (no PC) while still ringing, or
      // there is no session at all. A hydrated session with a live PC (offer
      // arrived, accept in flight) is NOT stuck — the old standalone
      // `status == incomingRinging` term fired even then, since acceptIncoming
      // keeps that status until its very last line, and tore down a healthy
      // in-progress accept.
      final stuck = s == null ||
          (_pc == null && s.status == CallStatus.incomingRinging);
      if (!stuck) return;
      debugPrint(
        'CallService: accept watchdog tripped — no offer arrived, '
        'treating call as dead (callId=${s?.callId})',
      );
      if (s != null) {
        // notifyBackend: the accept mutation never ran (no PC → the early
        // latch return), so the row still rings server-side; end it so the
        // caller learns now instead of at the 30s timeout.
        await _teardown(
          CallStatus.failed,
          errorMessage: 'Call unavailable',
          notifyBackend: true,
        );
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
      _dialing != null ||
      _session != null && _session!.status != CallStatus.idle &&
      _session!.status != CallStatus.ended &&
      _session!.status != CallStatus.failed;

  /// Caller path. Starts an outgoing call to [peerUserId].
  Future<void> initiate({
    required String peerUserId,
    required String peerName,
    required String roomId,
    required CallMediaKind kind,
    String? peerAvatarStorageId,
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

    final dial = CallSession(
      callId: '',
      roomId: roomId,
      peerUserId: peerUserId,
      peerName: peerName,
      // The face the caller just tapped beside: on screen from the first
      // frame of the slide, not swapped in after a profile round trip.
      peerAvatarStorageId: peerAvatarStorageId,
      mediaKind: kind,
      isCaller: true,
      status: CallStatus.outgoingRinging,
      startedAt: DateTime.now(),
      localVideoOff: kind == CallMediaKind.audio,
      speakerOn: kind == CallMediaKind.video,
    );
    screenSettled = null;
    _dialing = dial;
    notifyListeners();

    // 1. Reserve the call row first so we have a callId for every signal
    //    that follows. ICE starts gathering the moment setLocalDescription
    //    resolves, and onIceCandidate needs the callId to route — so the
    //    session must be alive before any of that fires. Outside the try:
    //    if the reservation itself fails there is nothing to clean up yet.
    final String callId;
    try {
      callId = await api.initiateCall(
        callerId: me,
        calleeId: peerUserId,
        roomId: roomId,
        type: kind.wire,
        callerDeviceId: _deviceId,
      );
    } catch (_) {
      if (identical(_dialing, dial)) {
        _dialing = null;
        notifyListeners();
      }
      rethrow;
    }
    if (!identical(_dialing, dial)) {
      // Hung up while the row was being reserved ([endCall] cleared the
      // dial). The callee's phone is about to ring for it, so cancel.
      unawaited(_notifyBackendTerminal(
        callId: callId,
        userId: me,
        preferCancel: true,
      ));
      return;
    }
    _dialing = null;
    try {
      _rememberLocalCall(callId);
      // The dial with its callId; [_dialing] -> [_session] in one notify, so
      // the call screen already up sees one continuous call. Loudspeaker for
      // video, earpiece for voice (set on the dial): matches the route
      // applied when media attaches; avoids a wrong icon while ringing.
      _session = CallSession(
        callId: callId,
        roomId: roomId,
        peerUserId: peerUserId,
        peerName: dial.peerName,
        peerAvatarStorageId: dial.peerAvatarStorageId,
        mediaKind: kind,
        isCaller: true,
        status: CallStatus.outgoingRinging,
        startedAt: dial.startedAt,
        localVideoOff: dial.localVideoOff,
        speakerOn: dial.speakerOn,
        peerRinging: _earlyRingingCallId == callId,
      );
      _earlyRingingCallId = null;
      notifyListeners();
      final settle = screenSettled;
      screenSettled = null;
      if (settle != null) {
        await settle.timeout(
          const Duration(milliseconds: 600),
          onTimeout: () {},
        );
        // Hung up while the screen was still settling: [endCall] already
        // cancelled the row and tore the session down.
        final cur = _session;
        if (cur == null ||
            cur.callId != callId ||
            cur.status != CallStatus.outgoingRinging) {
          return;
        }
      }
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
      await _openDrawChannel(_pc!);
      await _attachLocalMedia(kind);

      _negotiation.begin();
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': true,
        // Always, voice call or not: the section costs nothing while nobody
        // sends on it, and it lets a camera come on later as a direction
        // change rather than a new m-line.
        'offerToReceiveVideo': true,
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
      if (e is MediaSupersededException) {
        // A cancel (or instant redial) won the race mid-setup. Whoever
        // superseded us owns all live state now — including having already
        // dismissed the native card and notified the backend. Stand down
        // without touching anything.
        return;
      }
      debugPrint('CallService.initiate failed: $e\n$st');
      // The native outgoing card is already up and the backend row already
      // rings — a failure here (getUserMedia denied, PC construction, the
      // offer send) must kill BOTH, or the callee rings for a call that can
      // never connect while CallKit holds an active audio session forever.
      unawaited(NativeCallHandler.instance.endNative(callId));
      unawaited(_notifyBackendTerminal(
        callId: callId,
        userId: me,
        preferCancel: true,
      ));
      await _disposePc();
      if (_session?.callId == callId) {
        _session = null;
        notifyListeners();
      }
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
      // A missing offer is also what a DEAD call looks like: answering a
      // card that should already have stopped ringing put up a silent call
      // screen for the accept watchdog's full 20s. Ask now; a call that no
      // longer rings goes down at once instead.
      unawaited(_dropLatchedAcceptIfDead(s.callId));
      return;
    }

    // In-flight guard — see [_acceptingCallId]. A CallKit accept event and a
    // resume-triggered replay can both land here for the same live session;
    // block only a concurrent accept of the SAME call.
    if (_acceptingCallId == s.callId) return;
    _acceptingCallId = s.callId;
    // We have a real offer + PC and are proceeding, so the accept watchdog has
    // done its only job (rescue a native accept whose offer never came). Stop
    // it NOW: left armed it treats this healthy-but-slow accept — status stays
    // `incomingRinging` until the very last line below — as "stuck" at the 20s
    // mark and tears the call down as "Call unavailable" (the rings-but-can't-
    // answer report), and its `notifyBackend` end could kill a row that
    // `acceptCall` had just flipped to `active`.
    _acceptWatchdog?.cancel();
    _acceptWatchdog = null;
    try {
      // Claim the call on the backend FIRST, before the slower media/SDP work.
      // The server rings for only 30s; the old order paid getUserMedia +
      // createAnswer + setLocalDescription (0.5–3s) BEFORE this, so a tap late
      // in the ring window landed the accept AFTER expiry and came back
      // "not-ringing" — killing a call the user really did answer. Claiming
      // first shrinks that race to a single round-trip.
      final disposition = await api.acceptCall(
        callId: s.callId,
        userId: me,
        acceptingDeviceId: _deviceId,
      );
      if (disposition == 'not-ringing') {
        // The call was already settled elsewhere — timed out, cancelled, or a
        // sibling device took it — before our accept landed. Tear down LOCALLY
        // and DON'T notify the backend: a bare `endCall()` here fires
        // `calls:end`, which the backend honors even on an `active` row, so a
        // sibling that just won the accept would have its live call ended by
        // this loser. `_teardown` leaves the backend row alone.
        await _teardown(CallStatus.ended);
        return;
      }

      await _attachLocalMedia(s.mediaKind);
      final answer = await pc.createAnswer({});
      await pc.setLocalDescription(answer);
      debugPrint(
        'CallService.acceptIncoming: answer sent kind=${s.mediaKind.wire} '
        'sdpLen=${answer.sdp?.length ?? 0}',
      );

      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        kind: 'answer',
        payload: jsonEncode({'sdp': answer.sdp, 'type': answer.type}),
      );

      // Re-validate before promoting. The awaits above can outlive a teardown
      // (caller cancel auto-converted to end, a `bye`, the watchdog) plus the
      // 400ms terminal hold, and writing `connecting` onto a stale/terminal
      // session resurrects a zombie call — status connecting, PC disposed —
      // that then blocks every future call with "Already in a call" until a
      // manual hang-up.
      final cur = _session;
      if (cur == null ||
          cur.callId != s.callId ||
          cur.status == CallStatus.ended ||
          cur.status == CallStatus.failed ||
          cur.status == CallStatus.handedOff) {
        return;
      }
      _session = cur.copyWith(status: CallStatus.connecting);
      notifyListeners();
    } catch (e, st) {
      if (e is MediaSupersededException) {
        // The call ended (remote cancel/bye) while getUserMedia was still in
        // flight; the teardown that superseded us already cleaned up — and
        // the orphaned stream was stopped at the acquisition site.
        return;
      }
      debugPrint('CallService.acceptIncoming failed: $e\n$st');
      await endCall(errorMessage: 'Could not start call');
    } finally {
      // Clear only if it's still ours — a late-resolving wedged accept must
      // not wipe the guard a newer call's accept has since taken.
      if (_acceptingCallId == s.callId) _acceptingCallId = null;
    }
  }

  Future<void> reject() async {
    final me = _userId;
    final s = _session;
    if (me == null || s == null) return;
    if (s.status == CallStatus.ended || s.status == CallStatus.failed) return;
    // Same shape as [endCall]: kick the mutation off now, tear down locally
    // without waiting on it, then linger (bounded) only for the send. A late
    // reject needs no `end` fallback — being late means a cancel or a
    // sibling-device accept already resolved the row.
    final callId = s.callId;
    final notify = () async {
      try {
        await api
            .rejectCall(
              callId: callId,
              userId: me,
              acceptingDeviceId: _deviceId,
            )
            .timeout(terminalNotifyTimeout);
      } catch (e) {
        debugPrint('CallService.reject notify failed: $e');
      }
    }();
    await _teardown(CallStatus.ended);
    await notify;
  }

  /// End the call from either side. If still ringing as the caller, this
  /// sends a `cancel`; otherwise a normal `end`.
  ///
  /// Local teardown — the mic release — runs immediately and never waits on
  /// the network. The backend notify is kicked off first (so the peer's
  /// "call ended" latency doesn't regress), bounded by
  /// [terminalNotifyTimeout] and retried once; past that the server-side
  /// stuck-call GC is the backstop. The old shape awaited the bare mutation
  /// BEFORE teardown, so a wedged socket held the microphone hostage
  /// indefinitely — the iOS orange-dot-after-cancel bug.
  Future<void> endCall({String? errorMessage}) async {
    final me = _userId;
    final s = _session;
    if (s == null && _dialing != null) {
      // Hung up before the backend row exists: drop the dial, and
      // [initiate] cancels the row once the reservation lands.
      _dialing = null;
      notifyListeners();
      return;
    }
    if (me == null || s == null) {
      // Session already gone (e.g. cleared inside the terminal UI hold) but
      // an in-flight acquisition may have landed media since — never leave
      // straggler tracks behind.
      if (_localStream != null || _pc != null) await _disposePc();
      return;
    }
    if (s.status == CallStatus.ended || s.status == CallStatus.failed) {
      // Double-tap on the end button, or a native ENDED echo racing the
      // in-app one — the first pass owns the teardown.
      return;
    }
    final notify = _notifyBackendTerminal(
      callId: s.callId,
      userId: me,
      preferCancel: s.status == CallStatus.outgoingRinging && s.isCaller,
    );
    await _teardown(
      errorMessage != null ? CallStatus.failed : CallStatus.ended,
      errorMessage: errorMessage,
    );
    await notify;
  }

  /// Best-effort terminal notify: bounded, retried once, and never in the
  /// mic-release path. [preferCancel] picks `calls:cancel` (caller hanging
  /// up while still ringing). The accept/cancel race is resolved SERVER-
  /// side: a cancel that lost to an accept auto-converts to a full end and
  /// returns "ended" — no client fallback verb needed (and none would be
  /// safe against a pre-returns backend, whose `end` after a successful
  /// cancel would purge the callee's undelivered cancel signal). Backend
  /// deploys before the app build, per the protocol-change convention.
  /// Never throws.
  Future<void> _notifyBackendTerminal({
    required String callId,
    required String userId,
    required bool preferCancel,
  }) async {
    Future<void> attempt() async {
      if (preferCancel) {
        await api
            .cancelCall(callId: callId, userId: userId)
            .timeout(terminalNotifyTimeout);
        return;
      }
      await api
          .endCall(callId: callId, userId: userId)
          .timeout(terminalNotifyTimeout);
    }

    try {
      await attempt();
    } catch (e) {
      debugPrint('CallService: terminal notify failed ($e) — retrying once');
      unawaited(Future.delayed(terminalNotifyRetryDelay, () async {
        try {
          await attempt();
        } catch (e2) {
          // Give up — gcStuckRinging/gcStuckActive converge server-side.
          debugPrint('CallService: terminal notify retry failed: $e2');
        }
      }));
    }
  }

  // ───────── live controls ─────────

  /// The in-app mic button.
  Future<void> toggleMute() async {
    final s = _session;
    if (s == null) return;
    await setMuted(!s.localMuted);
  }

  /// Puts the mic in [muted]: the local audio tracks, the flag the button
  /// draws, and the peer's view of it. Idempotent, and the tracks are set
  /// every time, so a call with the flag and the tracks apart is brought
  /// back together by any request.
  ///
  /// [fromSystem] is CallKit's own mute (its call screen, an AirPods stem
  /// press, iOS syncing a new route): CallKit already holds that state, so
  /// it is not reported back. An in-app change is (see
  /// [NativeCallHandler.reportMuted]), so CallKit's mute and the AirPods'
  /// stay with the app's. CallKit's event used to be read as "toggle":
  /// one carrying the state the call already had flipped the mic, the
  /// button with it, and nothing ever told CallKit, so the two stayed
  /// apart for the rest of the call.
  Future<void> setMuted(bool muted, {bool fromSystem = false}) async {
    final ls = _localStream;
    final s = _session;
    if (ls == null || s == null) return;
    for (final t in ls.getAudioTracks()) {
      t.enabled = !muted;
    }
    if (s.localMuted == muted) return;
    _session = s.copyWith(localMuted: muted);
    notifyListeners();
    if (!fromSystem) {
      unawaited(NativeCallHandler.instance.reportMuted(s.callId, muted));
    }
    await _sendState();
  }

  /// Camera on/off, the same way in every call: "on" acquires the camera
  /// and puts its track on the camera slot (negotiating the slot the first
  /// time a voice call needs one), "off" empties the slot and releases the
  /// camera, light and all. A video call used to gate its track with
  /// `enabled` instead, which kept the camera running while "off" and gave
  /// the two kinds of call two answers to "is the camera on". See
  /// [GroupCallService.toggleVideo].
  ///
  /// The button answers on the tap ([cameraButtonOn] shows the wish while
  /// it is carried out). The work runs one step at a time through
  /// [_camSerial], so a second tap while the camera warms up changes the
  /// wish instead of acquiring a second camera: two capturers, one of them
  /// orphaned, was a camera that read "on" and sent nothing.
  Future<void> toggleVideo() async {
    if (_localStream == null || _session == null) return;
    _camWanted = !cameraButtonOn;
    notifyListeners();
    await _camSerial(_settleCamera);
  }

  /// What the camera button shows: the camera the user last asked for
  /// while that is still being carried out, else [localCamActive].
  bool get cameraButtonOn => _camWanted ?? localCamActive;

  /// The camera the user asked for, while [_settleCamera] works on it.
  bool? _camWanted;

  /// Camera work (on, off, restart, quality swap, flip) runs one at a time,
  /// in tap order.
  Future<void> _camQueue = Future<void>.value();

  /// The call the queue belongs to. Bumped at teardown with a fresh
  /// queue, so a step queued for the last call never runs in the next one,
  /// and the next call's camera never waits behind a step the last one
  /// left hanging.
  int _camGen = 0;

  /// Runs [op] after the camera work before it. Never throws: every caller
  /// is a tap or a timer with nobody to catch, and a failed step leaves
  /// the camera where the truth says it is.
  Future<void> _camSerial(Future<void> Function() op) {
    final gen = _camGen;
    final next = _camQueue.then((_) async {
      if (gen != _camGen) return;
      try {
        await op();
      } catch (e, st) {
        debugPrint('CallService camera step failed: $e\n$st');
      }
    });
    _camQueue = next;
    return next;
  }

  /// A new, empty camera queue for the next call. See [_camGen].
  void _resetCamQueue() {
    _camGen++;
    _camQueue = Future<void>.value();
  }

  /// Walks the camera to [_camWanted], re-reading the wish after every
  /// step, so taps made meanwhile are honoured in order and a burst of them
  /// costs at most one acquisition. A step that fails (no permission, no
  /// camera) drops the wish, and the button falls back to the truth.
  Future<void> _settleCamera() async {
    final gen = _camGen;
    try {
      while (gen == _camGen) {
        final want = _camWanted;
        final ls = _localStream;
        final s = _session;
        if (want == null || ls == null || s == null) return;
        if (want == localCamActive) return;
        final ok = want ? await _cameraOn(ls, s) : await _cameraOff(ls, s);
        if (!ok) return;
      }
    } finally {
      // A step that outlived its call leaves the next call's wish alone.
      if (gen == _camGen && _camWanted != null) {
        _camWanted = null;
        notifyListeners();
      }
    }
  }

  Future<bool> _cameraOn(MediaStream ls, CallSession s) async {
    if (!await ensurePermissionsFn(CallMediaKind.video)) return false;
    final MediaStreamTrack track;
    try {
      track = await getVideoTrackFn(SettingsStore.instance.videoQualityTier);
    } catch (e) {
      debugPrint('CallService._cameraOn: $e');
      return false;
    }
    if (_session?.callId != s.callId || _localStream != ls) {
      await discardCameraTrack(track);
      return false;
    }
    // Never two cameras in the stream: the preview and the sender would
    // each pick one, and only one would be the live one.
    for (final stale in ls.getVideoTracks()) {
      await releaseCameraTrack(ls, stale);
    }
    try {
      await ls.addTrack(track);
    } catch (e) {
      // A capturer the stream never took would run on with nobody to stop it.
      debugPrint('CallService._cameraOn addTrack: $e');
      await discardCameraTrack(track);
      return false;
    }
    _localStreamTick++;
    // Camera on moves the sound to the speaker. Flag first, route after,
    // through the one route writer: the old order awaited the route and
    // then wrote back a session copied from before those awaits, undoing
    // any toggle the user made in between.
    // A default, not a choice: a connected headset keeps the sound, as in
    // FaceTime. A speaker the user already chose stays chosen.
    final toSpeaker = !_session!.speakerOn;
    if (toSpeaker) _speakerChosenFor = null;
    _session = _session!.copyWith(localVideoOff: false, speakerOn: true);
    notifyListeners();
    if (toSpeaker) unawaited(_syncSpeakerRoute());
    final sender = _camSender;
    if (sender != null) {
      // Not awaited: a hanging send must not hold the camera queue.
      unawaited(_sendState());
      try {
        await sender.replaceTrack(track);
      } catch (e) {
        debugPrint('CallService._cameraOn replaceTrack: $e');
      }
    } else {
      // The new slot's offer names our camera stream: the state that tells
      // the peer which stream is the camera has to land before it.
      await _sendState();
      await _activateSlots();
    }
    return true;
  }

  Future<bool> _cameraOff(MediaStream ls, CallSession s) async {
    // An off camera is not a paused one.
    _camSuspended = false;
    _camRestarts = 0;
    _session = s.copyWith(localVideoOff: true);
    notifyListeners();
    // Privacy first: the picture stops leaving the phone on the tap, not
    // after the state signal has made the round trip through the backend
    // (seconds on a slow link, during which the peer still saw us). The
    // peer learns "off" right after; until then it sees a frozen frame.
    final sender = _camSender;
    if (sender != null) {
      try {
        await sender.replaceTrack(null);
      } catch (e) {
        debugPrint('CallService._cameraOff replaceTrack: $e');
      }
    }
    for (final t in ls.getVideoTracks()) {
      await releaseCameraTrack(ls, t);
    }
    _localStreamTick++;
    notifyListeners();
    // Never awaited inside the camera queue: a hanging send would hold
    // every camera tap behind it.
    unawaited(_sendState());
    return true;
  }

  // ───────── camera health ─────────

  /// Watches the frames of a camera that is on — see [CameraWatch].
  CameraWatch? _camWatch;

  /// The camera is meant to be on but is not capturing (iOS stopped it in
  /// the background, the system took it). The peer is told the picture is
  /// off meanwhile, so it shows our avatar, not a frozen frame; the button
  /// keeps the user's choice, and the camera comes back on its own.
  bool _camSuspended = false;
  bool get cameraSuspended => _camSuspended;

  /// Restarts tried for the current stall. Past [kMaxCameraRestarts] in
  /// the foreground the camera is turned off for real, so the button tells
  /// the truth instead of promising a picture that is not coming.
  int _camRestarts = 0;

  /// The rear camera is the one in use, so a restart or a quality switch
  /// brings back the camera the user flipped to.
  bool _camFacingBack = false;

  /// The back camera is the one going out. The self-view mirrors only the
  /// front one: a mirror is what a selfie looks like, but the world behind
  /// the phone mirrored reads as wrong (signs backwards), and the peer
  /// always gets it unmirrored.
  bool get localCamFacingBack => _camFacingBack;

  @visibleForTesting
  Duration cameraWatchInterval = const Duration(seconds: 2);
  @visibleForTesting
  bool cameraWatchLifecycle = true;
  @visibleForTesting
  CameraWatch? get debugCameraWatch => _camWatch;
  @visibleForTesting
  Future<bool> Function(MediaStreamTrack track) switchCameraFn =
      Helper.switchCamera;

  @override
  void notifyListeners() {
    _syncCameraWatch();
    super.notifyListeners();
  }

  /// Runs the watch exactly while a live call has the camera on.
  void _syncCameraWatch() {
    final s = _session;
    final watch = localCamActive &&
        _pc != null &&
        s != null &&
        s.status == CallStatus.active;
    if (watch) {
      (_camWatch ??= CameraWatch(
        readFrames: _readCamFrames,
        onVerdict: _onCameraVerdict,
        interval: cameraWatchInterval,
        listenToLifecycle: cameraWatchLifecycle,
      ))
          .start();
    } else if (_camWatch?.running ?? false) {
      _camWatch!.stop();
      _camSuspended = false;
      _camRestarts = 0;
    }
  }

  /// The camera's frames off the link, or "can't tell" while the link is
  /// not up: an encoder starved by a network blip counts flat like a dead
  /// camera, and the watch would restart, then kill, a working one. The
  /// group twin skips links that are not connected the same way.
  Future<int?> _readCamFrames() async {
    final pc = _pc;
    final t = _camTrack;
    if (pc == null || t == null) return null;
    final ice = pc.iceConnectionState;
    if (ice != RTCIceConnectionState.RTCIceConnectionStateConnected &&
        ice != RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      return null;
    }
    return cameraFramesFrom(await pc.getStats(t));
  }

  @visibleForTesting
  Future<int?> debugReadCamFrames() => _readCamFrames();

  @visibleForTesting
  void debugCameraVerdict(CameraHealth verdict) => _onCameraVerdict(verdict);

  void _onCameraVerdict(CameraHealth verdict) {
    if (!localCamActive) return;
    if (verdict == CameraHealth.capturing) {
      _camRestarts = 0;
      if (_camSuspended) {
        debugPrint('[CamWatch] 1:1 camera capturing again');
        _camSuspended = false;
        notifyListeners();
        unawaited(_sendState());
      }
      return;
    }
    final foreground = appInForegroundFn();
    if (!_camSuspended) {
      debugPrint('[CamWatch] 1:1 camera stalled (foreground=$foreground)');
      _camSuspended = true;
      notifyListeners();
      unawaited(_sendState());
    }
    if (!foreground) return;
    if (_camRestarts >= kMaxCameraRestarts) {
      debugPrint('[CamWatch] 1:1 camera did not come back, turning it off');
      _camWanted = false;
      notifyListeners();
      unawaited(_camSerial(_settleCamera));
      return;
    }
    _camRestarts++;
    unawaited(_camSerial(() async {
      if (!localCamActive) return;
      debugPrint('[CamWatch] 1:1 restarting the camera ($_camRestarts)');
      await _swapCameraTrack(SettingsStore.instance.videoQualityTier);
    }));
  }

  /// Re-acquires the camera at [tier] and swaps it onto the camera slot in
  /// place: `replaceTrack`, no renegotiation, the stream object kept (the
  /// tick tells the preview to rebind). Shared by the quality switch and
  /// the stall restart. Run through [_camSerial] only.
  Future<bool> _swapCameraTrack(VideoQualityTier tier) async {
    final s = _session;
    final ls = _localStream;
    final old = _camTrack;
    if (s == null || ls == null || old == null) return false;
    final MediaStreamTrack next;
    try {
      next = await getVideoTrackFn(tier);
    } catch (e) {
      debugPrint('CallService._swapCameraTrack: $e');
      return false;
    }
    if (_session?.callId != s.callId ||
        _localStream != ls ||
        _camTrack != old ||
        !localCamActive) {
      await discardCameraTrack(next);
      return false;
    }
    final sender = _camSender;
    if (sender != null) {
      try {
        await sender.replaceTrack(next);
      } catch (e) {
        debugPrint('CallService._swapCameraTrack replaceTrack: $e');
      }
    }
    // Add before release: the stream is never without a camera, so the
    // preview never binds to an empty one.
    try {
      await ls.addTrack(next);
    } catch (e) {
      // Put the old camera back on the slot and stop the new capturer, or
      // it runs on with nobody holding it.
      debugPrint('CallService._swapCameraTrack addTrack: $e');
      if (sender != null) {
        try {
          await sender.replaceTrack(old);
        } catch (_) {}
      }
      await discardCameraTrack(next);
      return false;
    }
    await releaseCameraTrack(ls, old);
    _camWatch?.rebase();
    _localStreamTick++;
    notifyListeners();
    return true;
  }

  /// Share this device's screen with the peer. One presenter at a time.
  /// See [GroupCallService.startScreenShare].
  Future<void> startScreenShare({
    ScreenShareSource? source,
    ({String title, String body, String stop})? notification,
    String drawBoardIdleText = 'Drawings appear here',
  }) async {
    final s = _session;
    final me = _userId;
    if (s == null || me == null || !inCall) return;
    if (_localScreenSharing || s.peerState.screenSharing) return;
    if (_screenSharePending) return;
    _screenSharePending = true;
    notifyListeners();
    try {
      await ScreenShare.prepare(
        notificationTitle: notification?.title ?? 'Sharing your screen',
        notificationBody: notification?.body ?? '',
        notificationStop: notification?.stop ?? 'Stop',
      );
      final captured = await getDisplayMediaFn(source: source);
      // iOS: the picker is up and nothing is captured yet — wait for the
      // broadcast itself before the peer hears about it. Same reasoning as
      // GroupCallService.startScreenShare.
      if (ScreenShare.needsStartHandshake) {
        final started = await ScreenShare.awaitPlatformStart(
          timeout: startHandshakeTimeout,
        );
        if (!started || _session?.callId != s.callId) {
          debugPrint('CallService.startScreenShare: the broadcast never '
              'started — rolled back');
          await stopAndDisposeStream(captured);
          await ScreenShare.release();
          return;
        }
      }
      final tracks = captured.getVideoTracks();
      if (tracks.isEmpty || _session?.callId != s.callId) {
        await stopAndDisposeStream(captured);
        await ScreenShare.release();
        return;
      }
      final track = tracks.first;
      final screen = _screenStream ??= await createLocalStreamFn('screen-$me');
      await screen.addTrack(track);
      // Detach before disposing the wrapper — see [getCallVideoOnlyTrack].
      await captured.removeTrack(track);
      await captured.dispose();
      track.onEnded = () => unawaited(stopScreenShare());
      ScreenShare.onPlatformStop = () => unawaited(stopScreenShare());
      _localScreenSharing = true;
      localScreenStreamTick++;
      _session = _session?.copyWith(localScreenSharing: true);
      notifyListeners();
      unawaited(drawMirror.start(trackId: track.id, idleText: drawBoardIdleText));
      await _sendState();
      final sender = _screenSender;
      if (sender != null) {
        try {
          await sender.replaceTrack(track);
          await _retuneScreenSender();
        } catch (e) {
          debugPrint('CallService.startScreenShare replaceTrack: $e');
        }
      } else {
        await _activateSlots();
      }
    } on ScreenShareDeniedException {
      await ScreenShare.release();
    } catch (e, st) {
      debugPrint('CallService.startScreenShare: $e\n$st');
      await ScreenShare.release();
      rethrow;
    } finally {
      _screenSharePending = false;
      notifyListeners();
    }
  }

  /// See `GroupCallService.startHandshakeTimeout`.
  @visibleForTesting
  Duration startHandshakeTimeout = const Duration(seconds: 45);

  /// End our share. The slot keeps its sender, empty, for the next one.
  Future<void> stopScreenShare() async {
    if (!_localScreenSharing) return;
    _localScreenSharing = false;
    ScreenShare.onPlatformStop = null;
    unawaited(drawMirror.stop());
    drawModel.clearAll();
    drawModel.flush();
    _session = _session?.copyWith(localScreenSharing: false);
    drawArmed.value = false;
    notifyListeners();
    await _sendState();
    final sender = _screenSender;
    if (sender != null) {
      try {
        await sender.replaceTrack(null);
      } catch (e) {
        debugPrint('CallService.stopScreenShare replaceTrack: $e');
      }
    }
    final ss = _screenStream;
    if (ss != null) {
      for (final t in ss.getVideoTracks()) {
        await ss.removeTrack(t);
        try {
          await t.stop();
        } catch (e) {
          debugPrint('CallService.stopScreenShare stop: $e');
        }
      }
    }
    localScreenStreamTick++;
    await ScreenShare.release();
    notifyListeners();
  }

  // ───────── renegotiation (see renegotiation.dart) ─────────

  /// Caller only: re-offer with every active slot of ours and enough
  /// receive sections for the peer's. Serialised — a change while an offer
  /// is out is remembered and sent once the answer lands.
  Future<void> _renegotiate() async {
    final pc = _pc;
    final s = _session;
    final me = _userId;
    if (pc == null || s == null || me == null || !s.isCaller) return;
    if (_negotiation.inFlight) {
      if (!_negotiation.stuck) {
        _negotiation.dirty = true;
        return;
      }
      // See LinkNegotiation.stuck: a round nobody will answer must not
      // hold this one hostage.
      debugPrint('CallService: round ${_negotiation.seq} never answered — '
          'starting a new one');
    }
    final gen = _pcGeneration;
    final seq = _negotiation.begin();
    try {
      await _ensureLocalSlots(pc);
      await ensureRecvVideoSlots(pc, _negotiation.wantedVideoSlots);
      await _tuneSenders(pc);
      final offer = await pc.createOffer({});
      if (gen != _pcGeneration || !identical(_pc, pc)) return;
      await pc.setLocalDescription(offer);
      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        targetDeviceId: s.peerDeviceId,
        kind: 'reoffer',
        payload: jsonEncode({'sdp': offer.sdp, 'type': offer.type, 'seq': seq}),
      );
    } catch (e, st) {
      debugPrint('CallService._renegotiate: $e\n$st');
      _negotiation.inFlight = false;
    }
  }

  void _finishNegotiation() {
    if (_negotiation.finish()) unawaited(_renegotiate());
  }

  /// Callee only: ask the caller for a round with room for our slots.
  Future<void> _requestRenegotiation() async {
    final s = _session;
    final me = _userId;
    if (s == null || me == null) return;
    try {
      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        targetDeviceId: s.peerDeviceId,
        kind: 'renegotiate',
        payload: jsonEncode({
          'videoSlots': _activeVideoSlots,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('CallService._requestRenegotiation: $e');
    }
  }

  /// A slot of ours just became active: get it onto the link.
  Future<void> _activateSlots() async {
    final pc = _pc;
    final s = _session;
    if (pc == null || s == null) return;
    if (s.isCaller) {
      await _renegotiate();
    } else {
      await _ensureLocalSlots(pc);
      await _requestRenegotiation();
    }
  }

  /// The peer's `reanswer` — only for the round in flight.
  Future<void> _onReanswer(String payload) async {
    final pc = _pc;
    if (pc == null) return;
    if (pc.signalingState !=
        RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      return;
    }
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      if (!_negotiation.accepts((parsed['seq'] as num?)?.toInt())) return;
      final sdp = parsed['sdp'] as String?;
      final type = parsed['type'] as String?;
      if (sdp == null || type == null) return;
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteDescSet = true;
      _drainPendingIce();
    } catch (e, st) {
      debugPrint('CallService._onReanswer failed: $e\n$st');
    }
    _finishNegotiation();
  }

  /// An offer on the LIVE link — an ICE restart's or a re-offer — applied
  /// in place and answered. [_remoteDescSet] stays true and fresh
  /// candidates flow through the normal `ice` path.
  Future<void> _applyOfferInPlace(
    String payload, {
    required String replyKind,
  }) async {
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
      // A slot that came on while the offer was in the air attaches now and
      // rides the answer.
      await _ensureLocalSlots(pc);
      await _tuneSenders(pc);
      final answer = await pc.createAnswer({});
      await pc.setLocalDescription(answer);
      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        targetDeviceId: s.peerDeviceId,
        kind: replyKind,
        payload: jsonEncode({
          'sdp': answer.sdp,
          'type': answer.type,
          // Echoed on both in-place answers. A restart offer from a build
          // that predates its `seq` carries none, and `null` here is what
          // [LinkNegotiation.accepts] reads as "always current".
          if (replyKind == 'reanswer' || replyKind == 'restart-answer')
            'seq': parsed['seq'],
        }),
      );
      if (await hasUnassociatedVideoSender(pc)) {
        await _requestRenegotiation();
      }
    } catch (e, st) {
      debugPrint('CallService._applyOfferInPlace($replyKind) failed: $e\n$st');
    }
  }

  /// Adds a sender for every active slot that has none on this link.
  Future<void> _ensureLocalSlots(RTCPeerConnection pc) async {
    final cam = _camTrack;
    final ls = _localStream;
    if (cam != null && ls != null && _camSender == null) {
      _camSender = await pc.addTrack(cam, ls);
    }
    final screen = _screenTrack;
    final ss = _screenStream;
    if (screen != null && ss != null && _screenSender == null) {
      _screenSender = await pc.addTrack(screen, ss);
    }
  }

  Future<void> _tuneSenders(RTCPeerConnection pc) async {
    await configureVideoSenders(
      pc,
      maxBitrate: videoQualityPresets[SettingsStore.instance.videoQualityTier]!
          .maxBitrate,
    );
    await _retuneScreenSender();
    await preferCodecFn(pc);
  }

  Future<void> _retuneScreenSender() async {
    final sender = _screenSender;
    if (sender == null) return;
    await configureScreenSender(sender);
  }

  /// Files the streams the link has delivered as the peer's camera and
  /// screen, by the ids its `state` names. See
  /// [GroupCallService._classifyPeerStreams].
  void _classifyRemoteStreams({Iterable<MediaStream> arrived = const []}) {
    final st = _session?.peerState ?? const PeerMediaState();
    final pool = _remoteStreamsById;
    MediaStream? screen;
    final sid = st.screenStreamId;
    if (sid != null) _remoteScreenStreamIds.add(sid);
    if (st.screenSharing && sid != null) screen = pool[sid];
    MediaStream? cam;
    final cid = st.camStreamId;
    if (cid != null) cam = pool[cid];
    bool neverScreen(MediaStream s) =>
        !identical(s, screen) && !_remoteScreenStreamIds.contains(s.id);
    if (cam == null) {
      for (final s in pool.values) {
        if (neverScreen(s) && s.getAudioTracks().isNotEmpty) {
          cam = s;
          break;
        }
      }
    }
    if (cam == null) {
      for (final s in pool.values) {
        if (neverScreen(s)) {
          cam = s;
          break;
        }
      }
    }
    cam ??= _remoteStream;
    var camChanged = !identical(cam, _remoteStream);
    var screenChanged = !identical(screen, _remoteScreenStream);
    _remoteStream = cam;
    _remoteScreenStream = screen;
    for (final s in arrived) {
      if (identical(s, screen)) {
        screenChanged = true;
      } else if (identical(s, cam)) {
        camChanged = true;
      }
    }
    if (camChanged) _remoteStreamTick++;
    if (screenChanged) _remoteScreenStreamTick++;
  }

  Future<void> _openDrawChannel(RTCPeerConnection pc) async {
    final gen = _pcGeneration;
    try {
      final ch = await pc.createDataChannel(
        DrawChannels.label,
        DrawChannels.init(),
      );
      _attachDrawChannel(gen, ch);
    } catch (e) {
      debugPrint('CallService: createDataChannel failed: $e');
    }
  }

  void _attachDrawChannel(int gen, RTCDataChannel ch) {
    if (gen != _pcGeneration) return;
    _drawChannel = ch;
    _draw.attach(_peerKey, ch);
  }

  /// Forgets everything about the link a PC carried: the peer's sorted
  /// streams, our slot senders, the round in flight, the draw channel.
  void _resetLinkState() {
    _remoteScreenStream = null;
    _remoteStreamsById.clear();
    _remoteScreenStreamIds.clear();
    _camSender = null;
    _screenSender = null;
    _negotiation.reset();
    final ch = _drawChannel;
    _drawChannel = null;
    if (ch != null) {
      _draw.detach(_peerKey);
      unawaited(ch.close().catchError((_) {}));
    }
  }

  /// Front/back. Serialized with the rest of the camera work, so a flip
  /// never lands on a track a restart is replacing, and bounded: the iOS
  /// plugin never answers a flip it has no capturer for.
  Future<void> switchCamera() => _camSerial(() async {
        final t = _camTrack;
        if (t == null || !localCamActive) return;
        if (!_isMobile) return; // Helper.switchCamera is a mobile-only channel.
        try {
          final front =
              await switchCameraFn(t).timeout(const Duration(seconds: 3));
          _camFacingBack = !front;
          notifyListeners();
        } catch (e) {
          debugPrint('switchCamera failed: $e');
        }
      });

  /// Live resolution/bitrate switch: persists the choice, then, if a
  /// camera is going out (a video call's, or one a voice call turned on),
  /// re-acquires it at the new tier and swaps it onto the camera slot with
  /// `replaceTrack` ([_swapCameraTrack]). No SDP renegotiation: the
  /// transceiver stays put, only its track and encoder params change. Runs
  /// through [_camSerial], which is also what keeps two quick switches from
  /// both reading the same old track.
  @override
  Future<void> switchVideoQuality(VideoQualityTier tier) async {
    await SettingsStore.instance.setVideoQualityTier(tier);
    if (_pc == null || !localCamActive) return;
    await _camSerial(() async {
      final pc = _pc;
      if (pc == null || !localCamActive) return;
      if (!await _swapCameraTrack(tier)) return;
      try {
        await configureVideoSenders(
          pc,
          maxBitrate: videoQualityPresets[tier]!.maxBitrate,
        );
      } catch (e) {
        debugPrint('switchVideoQuality($tier) failed: $e');
      }
    });
  }

  Future<void> toggleSpeaker() async {
    final s = _session;
    if (s == null) return;
    final next = !s.speakerOn;
    // The button answers on the tap. It used to wait out two platform
    // round trips (the category rewrite, then the route) before the flag
    // moved, so the icon lagged, and a second tap inside that window read
    // the OLD flag and asked for the same route again: two taps, one
    // change, and a button out of step with the sound.
    _session = s.copyWith(speakerOn: next);
    // An explicit choice: it beats a connected headset (see
    // [applyCallAudioResolved]) and survives every reassert.
    _speakerChosenFor = s.callId;
    _routeResyncs = 0;
    notifyListeners();
    await _syncSpeakerRoute();
  }

  /// The in-call route sheet's pick (see `CallAudioRouteSheet`): the
  /// loudspeaker, or not. An explicit choice, like [toggleSpeaker], but it
  /// re-applies even when the flag already reads [on]: moving between two
  /// routes off the speaker (AirPods to the phone) leaves the flag alone,
  /// and the native side still needs the pass that carries the pick.
  Future<void> selectSpeaker(bool on) async {
    final s = _session;
    if (s == null) return;
    if (s.speakerOn != on) _session = s.copyWith(speakerOn: on);
    _speakerChosenFor = s.callId;
    _routeResyncs = 0;
    notifyListeners();
    await _syncSpeakerRoute();
  }

  /// The call whose speaker side the user picked themselves, by the button
  /// or from the system's route controls. Keyed by callId so a new call
  /// starts from its kind's default without anyone resetting it.
  String? _speakerChosenFor;
  bool get _speakerUserChosen =>
      _speakerChosenFor != null && _speakerChosenFor == _session?.callId;

  /// Policy re-applies in a row that didn't bring the route to our side.
  /// Capped, so an output that refuses the override (a car, say) can't
  /// ping-pong with its own route-change echoes.
  int _routeResyncs = 0;
  StreamSubscription<CallAudioRoute>? _routeSub;

  /// The native side's report of where the sound really goes (iOS route
  /// changes: headphones in or out, AirPods, the CallKit or Control Center
  /// speaker button). The rules are [decideCallAudioRoute]'s; this keeps
  /// [CallSession.speakerOn], and so the speaker button, on the real side.
  @visibleForTesting
  void handleCallAudioRoute(CallAudioRoute route) {
    final s = _session;
    if (s == null || !inCall) return;
    // Only a call whose media is up owns the route. One still ringing here
    // (a call waiting while a group call holds the iOS session) has no
    // audio of its own: answering the group's route changes with a resync
    // of this call's default ping-ponged the speaker under the group.
    if (_localStream == null &&
        s.status != CallStatus.connecting &&
        s.status != CallStatus.active) {
      return;
    }
    // A write of ours is in flight; the route it reports back when it
    // lands settles the flag, and this report may predate it.
    if (_speakerRouting != null) return;
    final d = decideCallAudioRoute(
      speakerOn: s.speakerOn,
      cameraOn: localCamActive,
      route: route,
    );
    final adopt = d.speakerOn;
    if (adopt == null) {
      if (!d.resync) {
        _routeResyncs = 0;
        return;
      }
      if (++_routeResyncs > 2) return;
    } else {
      _routeResyncs = 0;
      _speakerChosenFor = d.userChosen ? s.callId : null;
      if (adopt != s.speakerOn) {
        debugPrint('CallService: route $route -> speaker=$adopt');
        _session = s.copyWith(speakerOn: adopt);
        notifyListeners();
      }
    }
    if (d.resync) unawaited(_syncSpeakerRoute());
  }

  /// The side the native layer actually applied, when a connected headset
  /// beat a default speaker: the flag follows, unless the user has moved
  /// it again since (their tap's own pass is already queued).
  void _adoptAppliedSpeaker(String? callId, bool want, bool? applied) {
    if (applied == null || applied == want || _speakerRouteDirty) return;
    final cur = _session;
    if (cur == null || cur.callId != callId || cur.speakerOn != want) return;
    debugPrint('CallService: headset kept the sound, speaker=$applied');
    _session = cur.copyWith(speakerOn: applied);
    notifyListeners();
  }

  /// Brings the platform route in line with [CallSession.speakerOn] — the
  /// one writer of it once a call is up. The flag is the truth and is read
  /// at apply time, never captured: a re-assert scheduled before a tap used
  /// to finish after it and write its stale side back, flag and route both,
  /// so the speaker flipped back on its own a second after the user chose.
  /// Requests run one at a time; one arriving mid-apply is folded into a
  /// single re-run, so a burst of taps lands as one change on the side the
  /// user stopped on.
  Future<void>? _speakerRouting;
  bool _speakerRouteDirty = false;

  Future<void> _syncSpeakerRoute() {
    _speakerRouteDirty = true;
    return _speakerRouting ??= () async {
      try {
        while (_speakerRouteDirty) {
          _speakerRouteDirty = false;
          final s = _session;
          if (s == null || !inCall) return;
          final want = s.speakerOn;
          // Category and route together, never the route alone:
          // `defaultToSpeaker` lives in WebRTC's process-wide session
          // config, and an override without it held only until the next
          // reconfiguration snapped back to the loudspeaker. See
          // [applyCallAudio].
          debugPrint('CallService: audio route speaker=$want');
          final applied = await applyCallAudioFn(
            s.mediaKind,
            speakerOn: want,
            headsetWins: !_speakerUserChosen,
            callId: s.callId,
          );
          _adoptAppliedSpeaker(s.callId, want, applied);
        }
      } finally {
        _speakerRouting = null;
      }
    }();
  }

  /// CallKit activated the AVAudioSession (flutter_callkit_incoming's
  /// `actionCallToggleAudioSession` event, bridged by NativeCallHandler).
  /// Two problems converge exactly here:
  ///   1. The callkit plugin re-runs its own configureAudioSession at every
  ///      activation AND once more ~1200ms after answer — playAndRecord
  ///      with mode .default and no .defaultToSpeaker — clobbering any
  ///      route/category we set earlier. So re-assert ours now AND once
  ///      again after its delayed pass. (Since vendored PATCH A the plugin
  ///      hands those passes to AppDelegate's CallAudioRouter, which writes
  ///      OUR config synchronously; these reasserts are now cheap belts.)
  ///   2. flutter_webrtc's mic unit may have started BEFORE activation
  ///      (it has no CallKit coordination), in which case it captures
  ///      silence until the track is re-primed — the mute→unmute "fix"
  ///      users discovered, done here programmatically.
  Future<void> onNativeAudioSessionActivated() async {
    if (_session == null || !inCall) return;
    _markCallAudioLive();
    callAudioActivations.value++;
    await _syncSpeakerRoute();
    _reprimeLocalAudio();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_session == null || !inCall) return;
      unawaited(_syncSpeakerRoute());
    });
  }

  /// Re-assert the chosen output route a few times after connect.
  ///
  /// The callkit plugin re-runs its own `configureAudioSession` when CallKit
  /// activates the session AND once more ~1200ms after answer — both with
  /// mode `.default` and no `defaultToSpeaker`, clobbering whatever route we
  /// set. [onNativeAudioSessionActivated] is the hook for exactly that;
  /// historically its `ACTION_CALL_TOGGLE_AUDIO_SESSION` event never
  /// survived the plugin's own parser (an `isActivate`/`isActive` key
  /// mismatch), so on iOS it never fired and the plugin's config was the
  /// last writer — a video call stayed pinned to the loudspeaker no matter
  /// what the toggle said. The vendored plugin fixes the parser (PATCH 5),
  /// so the hook fires now.
  ///
  /// These re-asserts stay anyway, deliberately: they are cheap
  /// no-op-if-unchanged route writes bracketing the plugin's known clobber
  /// points, and they keep working even if a future plugin bump regresses
  /// the event again.
  void _scheduleAudioRouteReasserts() {
    for (final ms in const [400, 1500, 3000]) {
      Timer(Duration(milliseconds: ms), () {
        final s = _session;
        if (s == null || !inCall) return;
        if (s.status != CallStatus.active) return;
        unawaited(_syncSpeakerRoute());
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

    // The callee's ringer is up. Arrives with no session only when it beat
    // [initiate]'s reply; held for the session that reply creates.
    if (kind == 'ringing') {
      final s = _session;
      if (s == null || s.callId != callId) {
        if (_dialing != null) _earlyRingingCallId = callId;
        return;
      }
      if (s.isCaller &&
          s.status == CallStatus.outgoingRinging &&
          !s.peerRinging) {
        _session = s.copyWith(peerRinging: true);
        notifyListeners();
      }
      return;
    }

    // Invite → open the IncomingCallScreen IMMEDIATELY, before the caller
    // has finished its WebRTC offer. The session lives without a PC until
    // the offer arrives and `_onRemoteOffer` hydrates it.
    if (kind == 'invite') {
      // Freshness gate: the backend rings for 30s, so any invite older than
      // that (server-stamped createdAt) is a stale row re-delivered after an
      // app restart — its call is terminal and must not re-ring as a ghost.
      // BUT never drop a signal for a call the user has already accepted
      // natively (`_latchedAcceptCallId`): the gate compares a server timestamp
      // to the DEVICE clock, so a device running >45s fast marks every fresh
      // invite/offer stale and never hydrates — the phone rings (native push
      // needs no gate) but Accept can never connect. An active accept latch is
      // proof this call is real regardless of what the clock says.
      if (_isStaleSignal(signal) && _latchedAcceptCallId != callId) {
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
          unawaited(NativeCallHandler.instance.endNative(callId));
          return;
        }
        // Bounded fire-and-forget: an unresponsive socket must not keep the
        // loser's mic hot or block ringing for the winner's invite.
        unawaited(_notifyBackendTerminal(
          callId: cur.callId,
          userId: me,
          preferCancel: true,
        ));
        await _teardown(CallStatus.ended);
        // Fall through: ring for the winner's invite below.
      } else if (cur != null && inCall) {
        // Already in a LIVE call — auto-reject as busy. Gated on [inCall],
        // not just non-null: `_teardown` holds a terminal session (status
        // ended/failed) for `teardownUiHold` so the UI can show it, and a
        // bare `cur != null` check here treated that leftover terminal
        // session as "busy" too — silently auto-rejecting (never ringing)
        // any call that arrived in that window. The reject mutation
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
        unawaited(NativeCallHandler.instance.endNative(callId));
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
      // path — an offer hydrating an already-ringing session is fine. Also
      // bypassed for a natively-accepted call (see the invite gate): this is
      // the exact signal a clock-skewed device needs to hydrate the call it
      // just accepted, and dropping it strands the accept forever.
      if (_session == null &&
          _isStaleSignal(signal) &&
          _latchedAcceptCallId != callId) {
        debugPrint('CallService: dropping stale offer callId=$callId');
        return;
      }
      final s = _session;
      if (s != null && s.callId != callId && inCall) {
        // Some other call's offer landed while we're already on this one —
        // busy-reject without disturbing our session (targeted native
        // dismiss for the same reason as the invite busy branch). Gated on
        // [inCall] for the same reason as the invite branch above: a
        // terminal leftover session must not busy-reject a fresh call.
        try {
          await api.rejectCall(
            callId: callId,
            userId: me,
            acceptingDeviceId: _deviceId,
          );
        } catch (_) {}
        unawaited(NativeCallHandler.instance.endNative(callId));
        return;
      }
      await _onRemoteOffer(callId: callId, fromUserId: fromUserId, payload: payload);
      return;
    }

    // For all other signals the callId must match my current session.
    final s = _session;
    if (s == null || s.callId != callId) {
      // Terminal signals for a call we hold no session for must still clear
      // any native UI raised for it — CallKit from the invite VoIP push can
      // outlive the session on a device whose subscription snapshot landed
      // after a fast cancel purged the `invite` row (so no session was ever
      // created here). Mirrors the no-session fallback `taken` already has.
      if (kind == 'bye' || kind == 'reject' || kind == 'cancel') {
        unawaited(NativeCallHandler.instance
            .endNative(callId)
            .then((_) => _ackNativeDismissed(callId)));
      }
      return;
    }

    // Any signal for the live call is proof the peer is alive and its
    // signaling works — see [shouldAbandonRestart]'s `lastPeerSignal`.
    _lastPeerSignalAt = DateTime.now();

    switch (kind) {
      case 'answer':
        await _onRemoteAnswer(payload);
        _finishNegotiation();
        break;
      case 'reoffer':
        await _applyOfferInPlace(payload, replyKind: 'reanswer');
        break;
      case 'reanswer':
        await _onReanswer(payload);
        break;
      case 'renegotiate':
        // The callee wants to send something new and cannot offer.
        if (s.isCaller) {
          try {
            final parsed = jsonDecode(payload) as Map<String, dynamic>;
            _negotiation.wantedVideoSlots = math.max(
              _negotiation.wantedVideoSlots,
              (parsed['videoSlots'] as num?)?.toInt() ?? 0,
            );
          } catch (_) {}
          unawaited(_renegotiate());
        }
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
          // Kick, not schedule: a backoff timer armed while our own
          // signaling was down must not make a peer that can reach us now
          // wait out the rest of it.
          _kickIceRestart(force: true);
        }
        break;
      case 'restart-offer':
        await _applyOfferInPlace(payload, replyKind: 'restart-answer');
        break;
      case 'restart-answer':
        // A stale answer (to a restart offer a later one superseded) must
        // neither be applied nor close the round that is actually in flight.
        if (await _onRestartAnswer(payload)) _finishNegotiation();
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
      // The ringer is up for as little as a second; without this the photo
      // waited on a `getFileUrl` round trip first and a quick answer on the
      // Mac never showed it.
      if (avatarStorageId != null && avatarUrl != null) {
        FileUrlCache.instance.seed(avatarStorageId, avatarUrl);
      }

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
      _armRingWatch(callId);
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
      _reportRinging(callId);
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
        _ackNativeDismissed(callId);
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

    // Whether `handoffCall` committed server-side decides what a failure
    // below means: before it, the call still lives happily on the old
    // device (ending it would hang up the peer's working call); after it,
    // the old device has already torn down and a failure strands the row.
    var handoffCommitted = false;
    try {
      // 1. Tell the backend so it can write handoff-takeover and
      //    handoff-prepare signals. The mutation also flips
      //    `calls.acceptingDeviceId` so the pill updates everywhere.
      await api.handoffCall(
        callId: callId,
        userId: me,
        newDeviceId: myDevice,
      );
      handoffCommitted = true;

      // 2. Spin up a fresh PC + media on this device.
      _pc = await _createPeerConnection();
      await _openDrawChannel(_pc!);
      await _attachLocalMedia(mediaKind);
      _negotiation.begin();
      final offer = await _pc!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
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
      if (e is MediaSupersededException) return;
      debugPrint('CallService.handoffToHere failed: $e\n$st');
      await _teardown(
        CallStatus.failed,
        errorMessage: 'Switch failed',
        notifyBackend: handoffCommitted,
      );
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
        // notifyBackend: the handoff already committed server-side (that is
        // what put us in `switching`), so with the takeover dead the row is
        // active with nobody on it — end it for everyone.
        await _teardown(
          CallStatus.failed,
          errorMessage: 'Switch failed',
          notifyBackend: true,
        );
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
    final dropped = _pc;
    try {
      await dropped?.close();
    } catch (_) {}
    // Android: closed is not gone. See [releasePeerConnection].
    if (dropped != null) releasePeerConnection(dropped);
    _pc = null;
    _remoteDescSet = false;
    _pendingRemoteIce.clear();
    _remoteStream = null;
    _resetLinkState();
    _session = s.copyWith(status: CallStatus.switching);
    notifyListeners();
    // The new device may die before ever sending `handoff-offer`. Without a
    // watchdog on THIS side too, we'd sit in `switching` holding a live
    // local stream (a hot mic) forever — the initiator's watchdog can't
    // help us, it only runs over there.
    _armHandoffWatchdog(callId);
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
          final sender = await _pc!.addTrack(t, existingLocal);
          if (t.kind == 'video') _camSender = sender;
        }
        await _ensureLocalSlots(_pc!);
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
      if (e is MediaSupersededException) return;
      debugPrint('CallService._onHandoffOffer failed: $e\n$st');
      await _teardown(
        CallStatus.failed,
        errorMessage: 'Switch failed',
        notifyBackend: true,
      );
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
      await _teardown(
        CallStatus.failed,
        errorMessage: 'Switch failed',
        notifyBackend: true,
      );
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
        _armRingWatch(callId);
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
        // The state names the peer's streams; anything that landed before
        // it is sorted now, and a share that ended lets go of its stream.
        _classifyRemoteStreams();
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
    final gen = _pcGeneration;
    final callId = s.callId;
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
      // Put them back and try again shortly. These are the candidates a
      // restart offer depends on: the offer goes out before gathering has
      // found anything, so on a network change the new interface's
      // candidates exist ONLY in these batches. Dropping a batch because
      // the signaling socket was mid-rebuild left the restart with nothing
      // to connect to, and the call failed on a network that worked.
      if (gen == _pcGeneration && _session?.callId == callId) {
        _iceOutBuffer.insertAll(0, batch);
        // Bounded: a link that cannot signal for long enough to gather this
        // many has newer candidates worth more than the oldest ones.
        const cap = 48;
        if (_iceOutBuffer.length > cap) {
          _iceOutBuffer.removeRange(0, _iceOutBuffer.length - cap);
        }
        _iceFlushTimer?.cancel();
        _iceFlushTimer = Timer(const Duration(seconds: 2), () {
          _iceFlushTimer = null;
          unawaited(_flushPendingLocalIce());
        });
      }
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
      releasePeerConnection(old);
    }
    _pcGeneration++;
    final gen = _pcGeneration;
    _resetLinkState();
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
      // See [kIceGatheringPolicy]: keep gathering when the phone changes
      // networks, so a Wi-Fi → cellular move can heal without a restart.
      'continualGatheringPolicy': kIceGatheringPolicy,
      // Full ICE — host > srflx > relay by priority, so TURN carries media
      // only when no direct path exists. Host (LAN) probing triggers iOS's
      // Local Network prompt; kAllowLanCandidates=false filters those out
      // instead of forcing relay for everything.
    };
    final pc = await createPcFn(config, {});

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
      for (final s in event.streams) {
        _remoteStreamsById[s.id] = s;
      }
      if (event.streams.isNotEmpty) {
        _classifyRemoteStreams(arrived: event.streams);
      }
      notifyListeners();
    };

    // The callee's end of the drawing channel the caller opened.
    pc.onDataChannel = (ch) {
      if (gen != _pcGeneration) return;
      if (ch.label == DrawChannels.label) _attachDrawChannel(gen, ch);
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
        unawaited(_syncSpeakerRoute());
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
            await _teardown(
              CallStatus.failed,
              errorMessage: 'Connection lost',
              notifyBackend: true,
            );
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

  /// Run a restart attempt NOW, discarding any backoff wait in progress.
  ///
  /// For moments that make a waiting timer stale: the peer asking us to
  /// re-offer, our signaling socket coming back, the device changing
  /// networks. The timer was armed for an attempt that, at the time, could
  /// not have been delivered.
  ///
  /// [proactive]: the link may still look healthy (a network change libwebrtc
  /// has not noticed yet). Restart without starting the outage clock or
  /// showing "reconnecting" — if the link really is broken, ICE will report
  /// `disconnected` and the ordinary path takes over with this restart
  /// already in flight.
  void _kickIceRestart({bool force = false, bool proactive = false}) {
    final s = _session;
    if (s == null) return;
    if (s.status != CallStatus.active && s.status != CallStatus.connecting) {
      return;
    }
    if (!proactive && !s.reconnecting && !force) return;
    if (!proactive) {
      _outageStart ??= DateTime.now();
      if (!s.reconnecting) {
        _session = s.copyWith(reconnecting: true);
        notifyListeners();
      }
    }
    _restartTimer?.cancel();
    final gen = _pcGeneration;
    _restartTimer = Timer(
      Duration.zero,
      () => _attemptIceRestart(gen, force: force || proactive),
    );
  }

  /// [SignalingStatus] moved: the transport came back, or the network
  /// changed. Cheap to run on every notification — it compares two counters.
  void _onSignalingStatus() {
    final up = _signaling.upEdges;
    final net = _signaling.networkEpoch;
    final cameUp = up != _seenUpEdges;
    final moved = net != _seenNetworkEpoch;
    _seenUpEdges = up;
    _seenNetworkEpoch = net;
    if (_pc == null || _session == null) return;
    if (moved) {
      // The phone is on a different network. The candidate pair carrying
      // media is bound to the old interface and is dead whether or not ICE
      // has said so yet (libwebrtc takes ~5s to call it `disconnected` and up
      // to 30s to call it `failed`). Restart now. The offer may race the
      // signaling socket's own rebuild and be lost — the up-edge below
      // re-sends it once the socket is verified back.
      debugPrint('CallService: network changed — proactive ICE restart');
      _kickIceRestart(proactive: true);
    } else if (cameUp && (_session?.reconnecting ?? false)) {
      debugPrint('CallService: signaling back — restarting ICE now');
      _kickIceRestart();
    }
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
    // A follow-up to a proactive restart that did not find the link healthy
    // is an outage like any other — and an outage needs a clock, or
    // [shouldAbandonRestart] could never end it.
    if (!force) _outageStart ??= DateTime.now();
    final now = DateTime.now();
    if (!force &&
        restartStillSettling(
          linkConnecting: pc.connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateConnecting,
          lastRestartAt: _lastRestartAt,
          now: now,
        )) {
      _restartTimer = Timer(
        const Duration(seconds: 2),
        () => _attemptIceRestart(gen),
      );
      return;
    }
    final outageStart = _outageStart;
    if (shouldAbandonRestart(
      outageStart: outageStart,
      now: now,
      attemptsSoFar: _restartAttempt,
      signalingDown: outageStart == null
          ? Duration.zero
          : _signaling.downtimeBetween(outageStart, now),
      lastPeerSignal: _lastPeerSignalAt,
    )) {
      await _teardown(
        CallStatus.failed,
        errorMessage: 'Connection lost',
        notifyBackend: true,
      );
      return;
    }
    _restartAttempt++;
    _lastRestartAt = now;
    debugPrint(
      'CallService: ICE restart attempt $_restartAttempt '
      '(caller=${s.isCaller})',
    );
    try {
      if (s.isCaller) {
        await pc.restartIce();
        // An offer like any other: a re-offer on top of it would answer a
        // section list the peer never saw.
        final seq = _negotiation.begin();
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
          // Tagged, so the answer can be matched to THIS offer. Restart
          // offers now repeat across a handover, and an attempt whose
          // mutation was queued behind a reconnecting socket can be
          // delivered after a newer one — its answer carries the old ICE
          // credentials, and applying it to the newer local offer breaks
          // the very restart that would have worked.
          payload: jsonEncode({
            'sdp': offer.sdp,
            'type': offer.type,
            'seq': seq,
          }),
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
    // The schedule never runs out; the outage budget in shouldAbandonRestart
    // is what ends recovery.
    _restartTimer = Timer(
      nextRestartDelay(_restartAttempt),
      () => _attemptIceRestart(gen),
    );
  }

  /// Applies a `restart-answer`. Returns whether it answered the round in
  /// flight — false for a stale or unusable one, which must not close that
  /// round.
  Future<bool> _onRestartAnswer(String payload) async {
    final pc = _pc;
    if (pc == null) return false;
    // Only valid while our restart offer is pending — a stale answer after
    // we've moved on (new offer, recovered, handoff) is dropped.
    if (pc.signalingState !=
        RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      // Nothing of ours is pending, so there is no round for this to hold
      // open either — same outcome as before this returned a value.
      return true;
    }
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
      if (!_negotiation.accepts((parsed['seq'] as num?)?.toInt())) {
        debugPrint('CallService: dropping stale restart-answer '
            '(seq ${parsed['seq']}, in flight ${_negotiation.seq})');
        return false;
      }
      final sdp = parsed['sdp'] as String?;
      final type = parsed['type'] as String?;
      if (sdp == null || type == null) return true;
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    } catch (e, st) {
      debugPrint('CallService._onRestartAnswer failed: $e\n$st');
    }
    return true;
  }

  Future<void> _attachLocalMedia(CallMediaKind kind) async {
    // The last call's late peer connection dispose stops Android's
    // AudioSwitch once the registry empties. Let it land now, before this
    // call's route and mic, never in the middle of them. See
    // [releasePeerConnection].
    await flushPeerConnectionReleases();
    // Classify the audio session before getUserMedia starts the mic unit.
    // `_session` is already set by the caller (initiate/acceptIncoming/etc)
    // with the correct per-kind default (loudspeaker for video, earpiece for
    // voice) — fall back to that same default if it's somehow unset yet.
    final speakerOn = _session?.speakerOn ?? (kind == CallMediaKind.video);
    final applied = await applyCallAudioFn(
      kind,
      speakerOn: speakerOn,
      headsetWins: !_speakerUserChosen,
      callId: _session?.callId,
    );
    _adoptAppliedSpeaker(_session?.callId, speakerOn, applied);
    // A redial or a handoff starts its own wait. An activation that already
    // came for THIS call (CallKit can activate before media is up) stands.
    final audioAlreadyLive = _callAudioLive;
    final tier = SettingsStore.instance.videoQualityTier;
    final epoch = ++_mediaEpoch;
    final stream = await getUserMediaFn(kind, tier: tier);
    if (epoch != _mediaEpoch || _pc == null) {
      // The call this acquisition belonged to ended mid-acquire (cancel) or
      // was replaced under us (instant redial). Nothing else will ever see
      // this stream — stop it NOW, or the mic stays hot with no owner.
      await stopAndDisposeStream(stream);
      throw MediaSupersededException();
    }
    _localStream = stream;
    final localKinds = stream.getTracks().map((t) => t.kind).join(',');
    final cur = _session;
    if (kind == CallMediaKind.video &&
        stream.getVideoTracks().isEmpty &&
        cur != null &&
        !cur.localVideoOff) {
      // A video call that got no camera: say so, on the button and to the
      // peer, rather than a camera "on" with nothing behind it.
      debugPrint('[CamWatch] video call acquired no camera; marked off');
      _session = cur.copyWith(localVideoOff: true);
    }
    debugPrint(
      'CallService._attachLocalMedia: requested=${kind.wire} '
      'tier=${tier.wire} got=[$localKinds]',
    );
    for (final track in stream.getTracks()) {
      final sender = await _pc!.addTrack(track, stream);
      if (track.kind == 'video') _camSender = sender;
    }
    // A screen already being shared (a handoff mid-share) rides along.
    await _ensureLocalSlots(_pc!);
    await _tuneSenders(_pc!);
    // Default output route: loudspeaker for video, earpiece for voice — on
    // both platforms. iOS won't latch this until its audio session is active,
    // so onConnectionState (connected) re-asserts it. Not awaited: the route
    // is the call's, not this setup's, and reads the flag when it runs.
    unawaited(_syncSpeakerRoute());
    if (!_systemOwnsCallAudio || audioAlreadyLive) {
      _callAudioLive = true;
    } else {
      _callAudioLiveTimer?.cancel();
      _callAudioLiveTimer = Timer(callAudioLiveFallback, () {
        _callAudioLiveTimer = null;
        if (inCall) _markCallAudioLive();
      });
    }
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
          ...PeerMediaState(
            audioMuted: s.localMuted,
            // A suspended camera is off as far as the peer can see.
            videoOff: s.localVideoOff || _camSuspended,
            videoPaused: !s.localVideoOff && _camSuspended,
            screenSharing: _localScreenSharing,
            camStreamId: _localStream?.id,
            screenStreamId: _screenStream?.id,
          ).toJson(),
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  /// Idempotent — cancels any prior timer first, so an ICE-restart
  /// reconnect (which re-enters the `Connected` branch) just restarts the
  /// interval against the same callId rather than stacking timers.
  ///
  /// The beat also LISTENS: a "not-in-call" answer means the backend
  /// already ended this call (peer end, cancel auto-convert, GC) and every
  /// terminal signal was missed — the dead-subscription case, where nothing
  /// else would ever release the mic. Same backstop the group service has.
  void _startHeartbeat(String callId) {
    _heartbeatTimer?.cancel();
    final me = _userId;
    if (me == null) return;
    // One-shot timers chained by hand rather than `Timer.periodic`, so the
    // delay is re-drawn for every beat (see [heartbeatJitter]). Cancelling
    // `_heartbeatTimer` — [_teardown], [_disposePc], or a fresh
    // [_startHeartbeat] on reconnect — drops the whole chain: the pending
    // timer is the only thing that would arm the next one.
    void beat() {
      _heartbeatTimer = Timer(
        heartbeatDelay(heartbeatInterval, heartbeatJitter, heartbeatRng),
        () {
          unawaited(() async {
            try {
              final res = await api.heartbeat(callId: callId, userId: me);
              if (res == 'not-in-call' &&
                  _session?.callId == callId &&
                  inCall) {
                debugPrint(
                  'CallService: heartbeat says not-in-call — tearing down',
                );
                await _teardown(CallStatus.ended);
              }
            } catch (e) {
              debugPrint('CallService heartbeat failed: $e');
            }
          }());
          beat();
        },
      );
    }

    beat();
  }

  /// After the native card for [callId] is gone from THIS device, say so:
  /// `calls:ackNativeDismissed`. Every terminal transition schedules a
  /// native `taken` push after a short grace so a card in a KILLED process
  /// still gets dismissed; a device that acks inside that grace is skipped.
  /// That matters on iOS, where a PushKit `taken` with no card left to end
  /// has to report a placeholder call — a one-second phantom "Call" that
  /// rings and vanishes. Best effort and fire-and-forget: a late or lost
  /// ack only means the push goes out the way it always did. Mobile only —
  /// nothing else shows a native card, and the backend never pushes to the
  /// simulator anyway.
  ///
  /// Only once the card is verifiably gone — see [NativeCallHandler.cardGone]
  /// for why having asked for the end is not enough.
  /// Tells the caller this device is ringing, so their screen moves from
  /// "calling" to "ringing" and the ringback starts. Only while in the
  /// foreground, where the ringer is certainly up: CallKit from the PushKit
  /// push, the native card [_onRemoteInvite] just raised on Android, or the
  /// in-app ringer on desktop and web. In the background the native push
  /// handler reports from the push itself. Fire-and-forget: a lost report
  /// costs the caller the ringback, never the call.
  void _reportRinging(String callId) {
    final me = _userId;
    if (me == null) return;
    if (_isMobile && !appInForegroundFn()) return;
    unawaited(() async {
      try {
        await api.markCallRinging(callId: callId, userId: me);
      } catch (e) {
        debugPrint('CallService: markCallRinging failed: $e');
      }
    }());
  }

  void _ackNativeDismissed(String callId) {
    final me = _userId;
    final dev = _deviceId;
    if (!_isMobile || me == null || dev == null) return;
    unawaited(() async {
      try {
        if (!await NativeCallHandler.instance.cardGone(callId)) {
          debugPrint('CallService: card for $callId still up — no dismissal '
              'ack, leaving it to the taken push');
          return;
        }
        await api.ackNativeDismissed(
            callId: callId, userId: me, deviceId: dev);
      } catch (e) {
        debugPrint('CallService: ackNativeDismissed failed: $e');
      }
    }());
  }

  /// Test seam for [_startHeartbeat]: the beat is otherwise only reachable
  /// by driving a PeerConnection to Connected, which drags stats polling and
  /// the native audio-route plugin into a unit test.
  @visibleForTesting
  void debugStartHeartbeat(String callId) => _startHeartbeat(callId);

  /// [interval] plus a uniformly random extra in `[0, jitter)` at
  /// millisecond resolution — every beat draws its own.
  @visibleForTesting
  static Duration heartbeatDelay(
    Duration interval,
    Duration jitter,
    math.Random rng,
  ) {
    final jitterMs = jitter.inMilliseconds;
    if (jitterMs <= 0) return interval;
    return interval + Duration(milliseconds: rng.nextInt(jitterMs));
  }

  /// [notifyBackend] is set ONLY by the locally-detected abandonment paths
  /// (ICE recovery exhausted, watchdogs) — the ones that used to leave the
  /// backend row `active` until the stuck-call GC noticed, keeping both
  /// users BUSY for minutes. Remote-initiated teardowns (bye/cancel/reject/
  /// taken) must never set it: the backend is already terminal and an echo
  /// would race other devices' signals.
  Future<void> _teardown(
    CallStatus terminal, {
    String? errorMessage,
    bool notifyBackend = false,
  }) async {
    _acceptWatchdog?.cancel();
    _acceptWatchdog = null;
    _ringWatch?.cancel();
    _ringWatch = null;
    _resetCallAudioLive();
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
      // Dismiss CallKit/ConnectionService BEFORE dropping WebRTC — the
      // CXEndCallAction must land while the plugin still owns a live call so
      // its end-of-call bookkeeping (incl. the vendored plugin's
      // audio-session deactivation) runs against reality, and so a CallKit
      // `didActivate` racing this teardown finds no call left to
      // re-activate the session for. Bounded: a wedged platform channel
      // must never hold the mic release behind it.
      try {
        await NativeCallHandler.instance
            .endNative(s.callId)
            .timeout(endNativeTimeout);
        _ackNativeDismissed(s.callId);
      } catch (e) {
        // No ack on failure: the card may still be up, and the backend's
        // `taken` push is the one thing left that can clear it.
        debugPrint('CallService._teardown: endNative failed: $e');
      }
    }
    if (notifyBackend && s != null) {
      final me = _userId;
      if (me != null) {
        unawaited(_notifyBackendTerminal(
          callId: s.callId,
          userId: me,
          preferCancel: false,
        ));
      }
    }
    // Hold the terminal state for a moment so the UI can render "ended" /
    // toast the error before the screen pops itself. Scheduled BEFORE the
    // media release below, not after it: the release is bounded now, but
    // the screen must never again sit on "Call ended" for as long as a
    // platform call takes to answer — and `_disposePc` captures what it
    // releases up front, so a call started once this fires is untouched.
    final endedCallId = s?.callId;
    Future.delayed(teardownUiHold, () {
      // A new call may have started inside this window — leave it alone.
      final now = _session;
      if (now != null && now.callId != endedCallId) return;
      _session = null;
      _remoteStream = null;
      _remoteStreamTick = 0;
      _remoteScreenStream = null;
      _remoteScreenStreamTick = 0;
      notifyListeners();
    });
    await _disposePc();
    // Belt to the plugin's deactivate-on-end: a no-op natively whenever any
    // call UI (plugin or fallback provider) is still alive — repeated over
    // the next seconds, because that card list empties a beat after
    // `endNative` returned. Named, so a pass landing after a redial applied
    // is ignored natively.
    unawaited(NativeCallHandler.instance
        .deactivateIosAudioSessionSettled(callId: endedCallId));
  }

  Future<void> _disposePc() async {
    // Invalidate every callback/timer captured against the dying PC — and
    // every in-flight media acquisition (see [_mediaEpoch]).
    _pcGeneration++;
    _mediaEpoch++;
    _disconnectTimer?.cancel();
    _restartTimer?.cancel();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _stats?.dispose();
    _stats = null;
    _camWatch?.stop();
    _camSuspended = false;
    _camRestarts = 0;
    _camWanted = null;
    _camFacingBack = false;
    _resetCamQueue();
    _remoteDescSet = false;
    _pendingRemoteIce.clear();
    _iceFlushTimer?.cancel();
    _iceFlushTimer = null;
    _iceOutBuffer.clear();
    // Capture and null out SYNCHRONOUSLY, before the first await: a fresh
    // call started while this one is still releasing (instant redial) must
    // never have ITS stream or peer connection closed by the tail of this.
    final ls = _localStream;
    _localStream = null;
    final ss = _screenStream;
    _screenStream = null;
    // A share still waiting on its broadcast returns false from that wait
    // and disposes what it captured; nothing else holds the capture.
    ScreenShare.cancelStartWait();
    if (_localScreenSharing) {
      _localScreenSharing = false;
      ScreenShare.onPlatformStop = null;
      unawaited(ScreenShare.release());
    }
    unawaited(drawMirror.stop());
    drawModel.clearAll();
    _resetLinkState();
    drawArmed.value = false;
    final pc = _pc;
    _pc = null;
    // Close the peer connection FIRST. On Darwin a track stop is only
    // `enabled = false`, so this close is the one release of the WebRTC
    // audio unit short of the belt below — it must not queue behind the
    // capturer stop, whose completion is what `stream.dispose()` waits on.
    if (pc != null) {
      try {
        await pc.close().timeout(disposeStepTimeout);
      } catch (e) {
        debugPrint('CallService._disposePc: close failed: $e');
      }
      // Android only, and after the screen has gone: the dispose is what
      // takes the phone out of call mode. See [releasePeerConnection].
      releasePeerConnection(pc);
    }
    // The Android route is one process-wide state. A 1:1 torn down while a
    // group call is live (a ring missed or declined mid-group) never owned
    // it: resetting it would hand the group's screen back to the system and
    // make its next re-assert a "first ask" again.
    if (!NativeCallHandler.groupCallActiveProbe()) {
      resetAndroidCallRoute();
    }
    if (ls != null) {
      // Per-track stop with individual guards — one throwing track (video,
      // typically, on some Android OEMs) must never skip the audio track's
      // stop or the dispose. That skip was a live mic with no owner.
      await stopAndDisposeStream(ls, stepTimeout: disposeStepTimeout);
    }
    if (ss != null) {
      await stopAndDisposeStream(ss, stepTimeout: disposeStepTimeout);
    }
    // Darwin mic belt — see [stopDarwinMicCapture]: on the module the
    // plugin now builds, the close above no longer stops recording. Never
    // while a group call is live in this process (shared module); that
    // path runs its own belt when it ends.
    if (!NativeCallHandler.groupCallActiveProbe()) {
      await stopMicCaptureFn();
    }
  }

  @override
  void dispose() {
    _routeSub?.cancel();
    _signaling.removeListener(_onSignalingStatus);
    _acceptWatchdog?.cancel();
    _ringWatch?.cancel();
    _callAudioLiveTimer?.cancel();
    _camWatch?.stop();
    callAudioActivations.dispose();
    _handoffWatchdog?.cancel();
    _disconnectTimer?.cancel();
    _restartTimer?.cancel();
    _activeCallSub?.cancel();
    _activeCallSub = null;
    incomingTick.dispose();
    _disposePc();
    callQuality.dispose();
    reopenTick.dispose();
    drawMirror.dispose();
    _draw.dispose();
    drawArmed.dispose();
    drawModel.dispose();
    super.dispose();
  }
}
