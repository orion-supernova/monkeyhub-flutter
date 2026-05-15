import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/chat_api.dart';
import 'call_models.dart';
import 'native_call_handler.dart';

/// Single-call peer-to-peer WebRTC manager.
///
/// One [CallService] instance per app, owning at most one active [CallSession]
/// and its [RTCPeerConnection]. Mirrors the [ChangeNotifier] convention used
/// across the app — UI listens via `addListener` and reads [session],
/// [localStream], [remoteStream].
///
/// Signaling rides on Convex via `ChatApi.subscribeCallSignals`; that
/// subscription is wired by `SignalingSubscriber` which delivers signals into
/// [handleRemoteSignal].
class CallService extends ChangeNotifier {
  CallService({required this.api});

  static CallService? _instance;
  static CallService get instance => _instance!;
  static CallService ensure(ChatApi api) =>
      _instance ??= CallService(api: api);

  final ChatApi api;

  String? _userId;
  String? get userId => _userId;
  void attach({required String userId, required String displayName}) {
    _userId = userId;
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
    if (_acceptedNatively) return;
    _acceptedNatively = true;
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

    // The PC was prepared in [_onRemoteOffer] (already has remote desc set).
    // Re-creating it here would discard that setup → createAnswer would fail
    // because the fresh PC has no remote description.
    final pc = _pc;
    if (pc == null) {
      await endCall(errorMessage: 'Lost the offer — try again');
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

      await api.acceptCall(callId: s.callId, userId: me);
      await api.sendCallSignal(
        callId: s.callId,
        fromUserId: me,
        toUserId: s.peerUserId,
        kind: 'answer',
        payload: jsonEncode({'sdp': answer.sdp, 'type': answer.type}),
      );

      _session = s.copyWith(status: CallStatus.connecting);
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
      await api.rejectCall(callId: s.callId, userId: me);
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
    final newOn = !s.speakerOn;
    try {
      await Helper.setSpeakerphoneOn(newOn);
    } catch (e) {
      debugPrint('setSpeakerphoneOn failed: $e');
    }
    _session = s.copyWith(speakerOn: newOn);
    notifyListeners();
  }

  // ───────── inbound signaling ─────────

  /// Called by [SignalingSubscriber] for every fresh inbound signal.
  Future<void> handleRemoteSignal(Map<String, dynamic> signal) async {
    final me = _userId;
    if (me == null) return;
    final kind = signal['kind'] as String?;
    final fromUserId = signal['fromUserId']?.toString();
    final callId = signal['callId']?.toString();
    final payload = (signal['payload'] as String?) ?? '{}';
    if (kind == null || fromUserId == null || callId == null) return;

    // Offer → start an incoming call (only if I'm currently idle).
    if (kind == 'offer') {
      if (_session != null) {
        // Already in a call — auto-reject the new one as busy.
        try {
          await api.rejectCall(callId: callId, userId: me);
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
      await _flushPendingLocalIce();
      incomingTick.value = incomingTick.value + 1;
      // Race recovery: if the user tapped Accept on CallKit BEFORE the
      // offer arrived (acceptIncoming would have early-returned because
      // there was no session yet), auto-fire it now. Fire-and-forget —
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
    // On Android the audio output default is the earpiece. Route to speaker
    // for video calls so it behaves like a typical phone app.
    if (Platform.isAndroid && kind == CallMediaKind.video) {
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (_) {}
    }
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
        kind: 'state',
        payload: jsonEncode({
          'audioMuted': s.localMuted,
          'videoOff': s.localVideoOff,
        }),
      );
    } catch (_) {}
  }

  Future<void> _teardown(CallStatus terminal, {String? errorMessage}) async {
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
      _acceptedNatively = false;
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
    incomingTick.dispose();
    _disposePc();
    super.dispose();
  }
}
