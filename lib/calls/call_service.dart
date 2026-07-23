import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/call_api.dart';
import 'call_models.dart';
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
  }

  // ───────── active call state ─────────
  CallSession? _session;
  CallSession? get session => _session;

  RTCPeerConnection? _pc;
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
  void markAcceptedNatively() {
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
        clearNativeAccept();
        unawaited(NativeCallHandler.instance.endAllNative());
      }
    });
  }

  /// Reset the CallKit-accept latch without a session teardown — used when
  /// a native accept turns out to target a call with no Dart session (a
  /// ghost CallKit card), where `_teardown` would never run.
  void clearNativeAccept() {
    _acceptWatchdog?.cancel();
    _acceptWatchdog = null;
    if (!_acceptedNatively) return;
    _acceptedNatively = false;
    notifyListeners();
  }

  /// ICE candidates received before [_pc.setRemoteDescription] has resolved.
  /// We queue them up and replay once the remote description is set.
  final List<RTCIceCandidate> _pendingRemoteIce = [];
  bool _remoteDescSet = false;

  /// Local ICE candidates the PC produced before the [_session] was set up.
  /// They're flushed onto the wire as soon as the session is ready.
  final List<RTCIceCandidate> _pendingLocalIce = [];

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
      markAcceptedNatively();
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
    try {
      await Helper.switchCamera(tracks.first);
    } catch (e) {
      debugPrint('switchCamera failed: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    final s = _session;
    if (s == null) return;
    await _applyAudioRoute(speaker: !s.speakerOn);
  }

  /// Sets the audio output route (loudspeaker vs earpiece) and keeps the
  /// session's [speakerOn] flag in sync so the UI matches reality.
  ///
  /// Applied with the per-kind default when local media attaches (video →
  /// loudspeaker, voice → earpiece) on BOTH platforms, then re-asserted once
  /// the call connects — iOS only honors the route after its CallKit audio
  /// session goes active, so the attach-time call alone doesn't stick.
  Future<void> _applyAudioRoute({required bool speaker}) async {
    try {
      await Helper.setSpeakerphoneOn(speaker);
    } catch (e) {
      debugPrint('setSpeakerphoneOn($speaker) failed: $e');
    }
    final s = _session;
    if (s != null && s.speakerOn != speaker) {
      _session = s.copyWith(speakerOn: speaker);
      notifyListeners();
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
      if (_session != null) {
        // Already in a call — auto-reject as busy. The reject mutation
        // will broadcast `taken` so the caller learns immediately.
        try {
          await api.rejectCall(
            callId: callId,
            userId: me,
            acceptingDeviceId: _deviceId,
          );
        } catch (_) {}
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
        // busy-reject without disturbing our session.
        try {
          await api.rejectCall(
            callId: callId,
            userId: me,
            acceptingDeviceId: _deviceId,
          );
        } catch (_) {}
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
      case 'state':
        _onRemoteState(payload);
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
      final mediaKind = CallMediaKindWire.parse(type);

      _session = CallSession(
        callId: callId,
        roomId: roomId,
        peerUserId: fromUserId,
        peerName: callerName,
        mediaKind: mediaKind,
        isCaller: false,
        status: CallStatus.incomingRinging,
        startedAt: DateTime.now(),
        localVideoOff: mediaKind != CallMediaKind.video,
      );
      notifyListeners();
      incomingTick.value = incomingTick.value + 1;
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
          peerName: 'Calling…', // overwritten by IncomingCallScreen via profile lookup
          mediaKind: mediaKind,
          isCaller: false,
          status: CallStatus.incomingRinging,
          startedAt: DateTime.now(),
          localVideoOff: !isVideo,
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
    } catch (e) {
      debugPrint('CallService._onRemoteIce failed: $e');
    }
  }

  void _onRemoteState(String payload) {
    try {
      final parsed = jsonDecode(payload) as Map<String, dynamic>;
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

  Future<void> _sendLocalIce(CallSession s, RTCIceCandidate cand) async {
    try {
      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: _userId!,
        toUserId: s.peerUserId,
        fromDeviceId: _deviceId,
        // Target the peer's specific device when known (post-handoff) so
        // siblings of the peer don't waste cycles parsing irrelevant
        // candidates. Pre-handoff this is null → broadcast as today.
        targetDeviceId: s.peerDeviceId,
        kind: 'ice',
        payload: jsonEncode({
          'candidate': cand.candidate,
          'sdpMid': cand.sdpMid,
          'sdpMLineIndex': cand.sdpMLineIndex,
        }),
      );
    } catch (e) {
      debugPrint('onIceCandidate send failed: $e');
    }
  }

  Future<void> _flushPendingLocalIce() async {
    if (_pendingLocalIce.isEmpty) return;
    final s = _session;
    if (s == null) return;
    final pending = List<RTCIceCandidate>.of(_pendingLocalIce);
    _pendingLocalIce.clear();
    for (final c in pending) {
      await _sendLocalIce(s, c);
    }
  }

  // ───────── helpers ─────────

  /// Updates [peerName] on the active incoming session — used by the
  /// IncomingCallScreen once it resolves the caller's display name from the
  /// repo cache.
  void updatePeerDisplayName(String peerName) {
    final s = _session;
    if (s == null) return;
    _session = CallSession(
      callId: s.callId,
      roomId: s.roomId,
      peerUserId: s.peerUserId,
      peerName: peerName,
      mediaKind: s.mediaKind,
      isCaller: s.isCaller,
      status: s.status,
      peerState: s.peerState,
      localMuted: s.localMuted,
      localVideoOff: s.localVideoOff,
      speakerOn: s.speakerOn,
      startedAt: s.startedAt,
      connectedAt: s.connectedAt,
      errorMessage: s.errorMessage,
    );
    notifyListeners();
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final servers = await _iceServers();
    final config = {
      'iceServers': servers,
      'sdpSemantics': 'unified-plan',
    };
    final pc = await createPeerConnection(config, {});

    pc.onIceCandidate = (cand) async {
      if (cand.candidate == null) return;
      final s = _session;
      final typ = _candidateType(cand.candidate);
      // Defensive buffer: if a candidate fires before _session is set
      // (shouldn't happen with current ordering, but guards future regressions),
      // park it and flush when the session arrives.
      if (s == null) {
        debugPrint('CallService.onIceCandidate: buffered ($typ) — no session yet');
        _pendingLocalIce.add(cand);
        return;
      }
      debugPrint('CallService.onIceCandidate: sending ($typ)');
      await _sendLocalIce(s, cand);
    };

    // NOTE: iOS Simulator's RTCMTLVideoView does not paint received video
    // frames (flutter-webrtc#1420 / #1535). Tracks arrive, connection reaches
    // Connected, but the remote view stays black. This is a plugin/renderer
    // limitation — test video on two physical devices, not the simulator.
    pc.onTrack = (event) {
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

    pc.onConnectionState = (state) async {
      debugPrint('RTC connection state: $state');
      final s = _session;
      if (s == null) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _session = s.copyWith(
          status: CallStatus.active,
          connectedAt: DateTime.now(),
        );
        notifyListeners();
        unawaited(NativeCallHandler.instance.markConnected(s.callId));
        // Re-assert the output route now the iOS audio session is live.
        unawaited(_applyAudioRoute(speaker: s.speakerOn));
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        await _teardown(CallStatus.failed, errorMessage: 'Connection lost');
      } else if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        // Allow brief disconnects; only kill if we don't recover within 15s.
        Timer(const Duration(seconds: 15), () async {
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

  Future<void> _attachLocalMedia(CallMediaKind kind) async {
    final constraints = <String, dynamic>{
      'audio': true,
      if (kind == CallMediaKind.video)
        'video': {
          'mandatory': {
            'minWidth': 640,
            'minHeight': 480,
            'minFrameRate': 24,
          },
          'facingMode': 'user',
          'optional': [],
        }
      else
        'video': false,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
    final localKinds =
        _localStream!.getTracks().map((t) => t.kind).join(',');
    debugPrint(
      'CallService._attachLocalMedia: requested=${kind.wire} '
      'got=[$localKinds]',
    );
    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }
    // Default output route: loudspeaker for video, earpiece for voice — on
    // both platforms. iOS won't latch this until its audio session is active,
    // so onConnectionState (connected) re-asserts it.
    await _applyAudioRoute(speaker: kind == CallMediaKind.video);
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
        }),
      );
    } catch (_) {}
  }

  Future<void> _teardown(CallStatus terminal, {String? errorMessage}) async {
    _acceptWatchdog?.cancel();
    _acceptWatchdog = null;
    // Reset the native-accept latch SYNCHRONOUSLY — leaving it set through
    // the delayed null-out below opens a 400ms window where a new incoming
    // call would be mis-routed straight to CallScreen.
    _acceptedNatively = false;
    final s = _session;
    if (s != null) {
      _session = s.copyWith(status: terminal, errorMessage: errorMessage);
      notifyListeners();
      unawaited(NativeCallHandler.instance.endNative(s.callId));
    }
    await _disposePc();
    // Hold the terminal state for a moment so the UI can render "ended" /
    // toast the error before the screen pops itself.
    Future.delayed(const Duration(milliseconds: 400), () {
      _session = null;
      _remoteStream = null;
      _remoteStreamTick = 0;
      notifyListeners();
    });
  }

  Future<void> _disposePc() async {
    _remoteDescSet = false;
    _pendingRemoteIce.clear();
    _pendingLocalIce.clear();
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
    incomingTick.dispose();
    _disposePc();
    super.dispose();
  }
}
