import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/convex_client.dart';
import '../backend/group_call_api.dart';
import 'call_config.dart';
import 'call_media.dart';
import 'call_models.dart';
import 'call_recovery.dart';

/// Per-peer video bitrate cap for a mesh call: every phone runs one encoder
/// per remote peer, so the budget shrinks as the call grows.
int meshVideoBitrate(int remotePeerCount) {
  if (remotePeerCount <= 1) return 1200000;
  if (remotePeerCount == 2) return 900000;
  if (remotePeerCount == 3) return 700000;
  return 500000;
}

/// One remote participant's connection state inside the mesh.
class GroupPeer {
  GroupPeer({required this.userId, required this.name, this.avatarStorageId});

  final String userId;
  String name;
  String? avatarStorageId;

  RTCPeerConnection? pc;
  MediaStream? remoteStream;
  int remoteStreamTick = 0;
  bool remoteDescSet = false;
  final List<RTCIceCandidate> pendingRemoteIce = [];
  final List<RTCIceCandidate> iceOut = [];
  Timer? iceFlushTimer;

  // Recovery state — same policy as the 1:1 path (call_recovery.dart).
  int generation = 0;
  Timer? restartTimer;
  int restartAttempt = 0;
  DateTime? outageStart;
  bool reconnecting = false;

  PeerMediaState mediaState = const PeerMediaState();
  bool connected = false;
}

/// Mesh group-call manager: one [RTCPeerConnection] per remote participant,
/// pair-addressed signaling over Convex (`groupCalls:*`), deterministic
/// offerer per pair (lower userId offers — no glare by construction).
///
/// Backend is roster + signaling only; media stays P2P with the same
/// STUN/TURN fallback as 1:1 calls. Capacity is capped server-side at 6.
class GroupCallService extends ChangeNotifier {
  GroupCallService({required this.api});

  static GroupCallService? _instance;
  static GroupCallService get instance => _instance!;
  static GroupCallService? get maybeInstance => _instance;
  static GroupCallService ensure(GroupCallApi api) =>
      _instance ??= GroupCallService(api: api);

  final GroupCallApi api;

  String? _userId;
  String? get userId => _userId;
  String? _deviceId;

  // ── live call state ──
  String? _groupCallId;
  String? get groupCallId => _groupCallId;
  String? _roomId;
  String? get roomId => _roomId;
  CallMediaKind _mediaKind = CallMediaKind.audio;
  CallMediaKind get mediaKind => _mediaKind;
  bool get inCall => _groupCallId != null;
  bool _ending = false;

  MediaStream? _localStream;
  MediaStream? get localStream => _localStream;
  bool localMuted = false;
  bool localVideoOff = false;
  bool speakerOn = true;

  /// Remote participants that are `joined` per the roster, keyed by userId.
  final Map<String, GroupPeer> _peers = {};
  Map<String, GroupPeer> get peers => UnmodifiableMapView(_peers);

  /// Raw roster rows (joined + invited) for the call screen's tiles.
  List<Map<String, dynamic>> rosterRows = const [];

  Subscription? _rosterSub;
  Subscription? _signalsSub;
  Subscription? _inviteSub;
  Timer? _heartbeat;

  /// Freshest ring-worthy invite (null when none) — the app overlay watches
  /// this to show the incoming group-call UI.
  Map<String, dynamic>? pendingInvite;

  // FIFO signal queue — same delivery discipline as SignalingSubscriber:
  // one drain loop, dispatch strictly in server order, consume in batches.
  final LinkedHashSet<String> _dispatched = LinkedHashSet<String>();
  final List<Map<String, dynamic>> _queue = [];
  bool _draining = false;

  void attach({required String userId, String? deviceId}) {
    if (_userId == userId && _signalsSub != null) return;
    _userId = userId;
    _deviceId = deviceId;
    _resubscribe();
  }

  /// Re-establish the per-user subscriptions after a socket reconnect.
  void resubscribe() => _resubscribe();

  void _resubscribe() {
    final me = _userId;
    if (me == null) return;
    _signalsSub?.cancel();
    _signalsSub = null;
    _inviteSub?.cancel();
    _inviteSub = null;
    unawaited(api
        .subscribeSignals(
          userId: me,
          onSignals: _onSignals,
          onError: (e) => debugPrint('GroupCallService signals error: $e'),
        )
        .then((s) => _signalsSub = s));
    unawaited(api
        .subscribePendingInvite(
          userId: me,
          onInvite: (inv) {
            pendingInvite = inv;
            notifyListeners();
          },
          onError: (e) => debugPrint('GroupCallService invite error: $e'),
        )
        .then((s) => _inviteSub = s));
  }

  // ───────── lifecycle ─────────

  /// Start (or converge onto) the call in [roomId]. `inviteeIds == null`
  /// invites the whole room.
  Future<void> startCall({
    required String roomId,
    required CallMediaKind kind,
    List<String>? inviteeIds,
  }) async {
    final me = _userId;
    if (me == null) throw StateError('GroupCallService not attached');
    if (inCall) throw StateError('Already in a group call');
    final res = await api.start(
      roomId: roomId,
      userId: me,
      type: kind.wire,
      deviceId: _deviceId,
      inviteeIds: inviteeIds,
    );
    // Converged onto an existing call: honor ITS media kind via join.
    if (res.existing) {
      await joinCall(res.groupCallId);
      return;
    }
    await _enterCall(res.groupCallId, roomId: roomId, kind: kind);
  }

  Future<void> joinCall(String groupCallId) async {
    final me = _userId;
    if (me == null) throw StateError('GroupCallService not attached');
    if (inCall && _groupCallId != groupCallId) {
      throw StateError('Already in a group call');
    }
    final res = await api.join(
      groupCallId: groupCallId,
      userId: me,
      deviceId: _deviceId,
    );
    await _enterCall(
      groupCallId,
      roomId: res.roomId,
      kind: CallMediaKindWire.parse(res.type),
    );
  }

  Future<void> _enterCall(
    String groupCallId, {
    required String roomId,
    required CallMediaKind kind,
  }) async {
    if (_groupCallId == groupCallId) return;
    final me = _userId!;
    _groupCallId = groupCallId;
    _roomId = roomId;
    _mediaKind = kind;
    _ending = false;
    localMuted = false;
    localVideoOff = kind != CallMediaKind.video;
    pendingInvite = null;
    notifyListeners();

    try {
      await applyIosCallAudioConfig(kind);
      _localStream = await getCallUserMedia(kind);
      speakerOn = kind == CallMediaKind.video;
      await applyCallAudioRoute(speaker: speakerOn);
    } catch (e, st) {
      debugPrint('GroupCallService: getUserMedia failed: $e\n$st');
      await leaveCall();
      rethrow;
    }

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      final id = _groupCallId;
      if (id == null) return;
      unawaited(
        api.heartbeat(groupCallId: id, userId: me).catchError((_) {}),
      );
    });

    _rosterSub?.cancel();
    unawaited(api
        .subscribeRoster(
          groupCallId: groupCallId,
          userId: me,
          onRoster: _onRoster,
          onError: (e) => debugPrint('GroupCallService roster error: $e'),
        )
        .then((s) {
      if (_groupCallId != groupCallId) {
        s.cancel();
        return;
      }
      _rosterSub = s;
    }));
    notifyListeners();
  }

  /// Leave and clean up. Safe to call repeatedly.
  Future<void> leaveCall() async {
    if (_ending) return;
    _ending = true;
    final me = _userId;
    final id = _groupCallId;
    _heartbeat?.cancel();
    _heartbeat = null;
    _rosterSub?.cancel();
    _rosterSub = null;
    if (me != null && id != null) {
      try {
        await api.leave(groupCallId: id, userId: me);
      } catch (_) {}
    }
    for (final peer in _peers.values) {
      _disposePeerLink(peer);
    }
    _peers.clear();
    rosterRows = const [];
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
    _groupCallId = null;
    _roomId = null;
    _ending = false;
    notifyListeners();
  }

  Future<void> declineInvite() async {
    final me = _userId;
    final inv = pendingInvite;
    if (me == null || inv == null) return;
    pendingInvite = null;
    notifyListeners();
    try {
      await api.decline(
        groupCallId: inv['groupCallId'].toString(),
        userId: me,
      );
    } catch (_) {}
  }

  // ───────── roster-driven mesh membership ─────────

  void _onRoster(Map<String, dynamic>? roster) {
    final me = _userId;
    final id = _groupCallId;
    if (me == null || id == null || roster == null) return;
    if (roster['groupCallId']?.toString() != id) return;
    if (roster['status'] != 'active') {
      // Call ended (everyone else left, or GC reaped it).
      unawaited(leaveCall());
      return;
    }
    final parts = ((roster['participants'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList(growable: false);
    rosterRows = parts;

    final joined = <String, Map<String, dynamic>>{};
    for (final p in parts) {
      if (p['status'] == 'joined' && p['userId'].toString() != me) {
        joined[p['userId'].toString()] = p;
      }
    }

    // Peers that left → tear down their link.
    for (final gone
        in _peers.keys.where((k) => !joined.containsKey(k)).toList()) {
      final peer = _peers.remove(gone);
      if (peer != null) _disposePeerLink(peer);
    }
    // New peers → build a link (the designated offerer sends the offer).
    for (final entry in joined.entries) {
      final existing = _peers[entry.key];
      if (existing == null) {
        final peer = GroupPeer(
          userId: entry.key,
          name: entry.value['name']?.toString() ?? 'Someone',
          avatarStorageId: entry.value['avatarStorageId'] as String?,
        );
        _peers[entry.key] = peer;
        unawaited(_ensureLink(peer));
      } else {
        existing.name = entry.value['name']?.toString() ?? existing.name;
        existing.avatarStorageId =
            (entry.value['avatarStorageId'] as String?) ??
                existing.avatarStorageId;
      }
    }
    // Re-cap encoders for the new mesh size.
    final bitrate = meshVideoBitrate(_peers.length);
    for (final peer in _peers.values) {
      final pc = peer.pc;
      if (pc != null) {
        unawaited(configureVideoSenders(pc, maxBitrate: bitrate));
      }
    }
    notifyListeners();
  }

  /// Lower userId is the offerer for a pair — deterministic on both ends,
  /// so offers can never glare regardless of join order.
  bool _iOffer(String peerUserId) => _userId!.compareTo(peerUserId) < 0;

  Future<void> _ensureLink(GroupPeer peer) async {
    if (peer.pc != null) return;
    final id = _groupCallId;
    final me = _userId;
    if (id == null || me == null) return;
    peer.generation++;
    final gen = peer.generation;
    try {
      final pc = await _createPeerPc(peer, gen);
      if (gen != peer.generation || _groupCallId != id) {
        await pc.close();
        return;
      }
      peer.pc = pc;
      final ls = _localStream;
      if (ls != null) {
        for (final track in ls.getTracks()) {
          await pc.addTrack(track, ls);
        }
      }
      await configureVideoSenders(pc,
          maxBitrate: meshVideoBitrate(_peers.length));
      await preferH264Codec(pc);
      if (_iOffer(peer.userId)) {
        final offer = await pc.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': _mediaKind == CallMediaKind.video,
        });
        await pc.setLocalDescription(offer);
        await _sendTo(peer, 'offer', {
          'sdp': offer.sdp,
          'type': offer.type,
          'mediaKind': _mediaKind.wire,
        });
      }
      // Share our current mute/video state with the newcomer.
      await _sendTo(peer, 'state', {
        'audioMuted': localMuted,
        'videoOff': localVideoOff,
      });
    } catch (e, st) {
      debugPrint('GroupCallService._ensureLink(${peer.userId}): $e\n$st');
    }
  }

  Future<RTCPeerConnection> _createPeerPc(GroupPeer peer, int gen) async {
    final servers = await _iceServers();
    final pc = await createPeerConnection({
      'iceServers': servers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'iceCandidatePoolSize': 2,
    }, {});

    pc.onIceCandidate = (cand) {
      if (gen != peer.generation) return;
      if (cand.candidate == null) return;
      if (!kAllowLanCandidates &&
          (cand.candidate!.contains(RegExp(r'\btyp\s+host\b')))) {
        return;
      }
      _queuePeerIce(peer, cand);
    };

    pc.onTrack = (event) {
      if (gen != peer.generation) return;
      if (event.streams.isNotEmpty) {
        peer.remoteStream = event.streams.first;
        peer.remoteStreamTick++;
      }
      notifyListeners();
    };

    pc.onIceConnectionState = (state) {
      if (gen != peer.generation) return;
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _schedulePeerRestart(peer, gen, immediate: true);
      } else if (state ==
              RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _notePeerRestored(peer);
      }
    };

    pc.onConnectionState = (state) {
      if (gen != peer.generation) return;
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        peer.connected = true;
        _notePeerRestored(peer);
        notifyListeners();
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _schedulePeerRestart(peer, gen, immediate: true);
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _schedulePeerRestart(peer, gen);
      }
    };
    return pc;
  }

  // ───────── per-peer recovery (same policy as 1:1) ─────────

  void _notePeerRestored(GroupPeer peer) {
    peer.restartTimer?.cancel();
    peer.restartAttempt = 0;
    peer.outageStart = null;
    if (peer.reconnecting) {
      peer.reconnecting = false;
      notifyListeners();
    }
  }

  void _schedulePeerRestart(GroupPeer peer, int gen,
      {bool immediate = false, bool force = false}) {
    if (!inCall) return;
    peer.outageStart ??= DateTime.now();
    if (!peer.reconnecting) {
      peer.reconnecting = true;
      notifyListeners();
    }
    if (peer.restartTimer?.isActive ?? false) return;
    peer.restartTimer = Timer(
      immediate ? Duration.zero : const Duration(seconds: 2),
      () => _attemptPeerRestart(peer, gen, force: force),
    );
  }

  Future<void> _attemptPeerRestart(GroupPeer peer, int gen,
      {bool force = false}) async {
    if (gen != peer.generation || !inCall) return;
    final pc = peer.pc;
    if (pc == null) return;
    if (!force &&
        pc.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _notePeerRestored(peer);
      return;
    }
    if (shouldAbandonRestart(
      outageStart: peer.outageStart,
      now: DateTime.now(),
      attemptsSoFar: peer.restartAttempt,
    )) {
      // Rebuild the link from scratch once; if the peer is truly gone the
      // heartbeat GC removes them from the roster within ~90s and the
      // roster diff tears this link down for good.
      debugPrint(
          'GroupCallService: rebuilding link to ${peer.userId} after failed recovery');
      _disposePeerLink(peer, keepIdentity: true);
      unawaited(_ensureLink(peer));
      return;
    }
    peer.restartAttempt++;
    try {
      if (_iOffer(peer.userId)) {
        await pc.restartIce();
        final offer = await pc.createOffer({'iceRestart': true});
        await pc.setLocalDescription(offer);
        await _sendTo(peer, 'restart-offer', {
          'sdp': offer.sdp,
          'type': offer.type,
        });
      } else {
        await _sendTo(peer, 'restart-request', {});
      }
    } catch (e) {
      debugPrint('GroupCallService._attemptPeerRestart: $e');
    }
    final delay = nextRestartDelay(peer.restartAttempt);
    peer.restartTimer = Timer(
      delay ?? const Duration(seconds: 8),
      () => _attemptPeerRestart(peer, gen),
    );
  }

  // ───────── outbound signaling ─────────

  Future<void> _sendTo(
      GroupPeer peer, String kind, Map<String, dynamic> payload) async {
    final id = _groupCallId;
    final me = _userId;
    if (id == null || me == null) return;
    try {
      await api.sendSignal(
        groupCallId: id,
        fromUserId: me,
        toUserId: peer.userId,
        kind: kind,
        payload: jsonEncode(payload),
        fromDeviceId: _deviceId,
      );
    } catch (e) {
      debugPrint('GroupCallService._sendTo($kind): $e');
    }
  }

  void _queuePeerIce(GroupPeer peer, RTCIceCandidate cand) {
    peer.iceOut.add(cand);
    if (peer.iceOut.length >= 8) {
      unawaited(_flushPeerIce(peer));
      return;
    }
    peer.iceFlushTimer ??= Timer(const Duration(milliseconds: 120), () {
      peer.iceFlushTimer = null;
      unawaited(_flushPeerIce(peer));
    });
  }

  Future<void> _flushPeerIce(GroupPeer peer) async {
    peer.iceFlushTimer?.cancel();
    peer.iceFlushTimer = null;
    if (peer.iceOut.isEmpty) return;
    final batch = List<RTCIceCandidate>.of(peer.iceOut);
    peer.iceOut.clear();
    await _sendTo(peer, 'ice-batch', {
      'candidates': [
        for (final c in batch)
          {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          },
      ],
    });
  }

  // ───────── inbound signaling (FIFO drain) ─────────

  void _onSignals(List<Map<String, dynamic>> signals) {
    for (final sig in signals) {
      final id = sig['_id']?.toString();
      if (id == null || _dispatched.contains(id)) continue;
      _dispatched.add(id);
      while (_dispatched.length > 300) {
        _dispatched.remove(_dispatched.first);
      }
      _queue.add(sig);
    }
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final me = _userId;
        if (me == null) return;
        final ids = <String>[];
        while (_queue.isNotEmpty) {
          final sig = _queue.removeAt(0);
          final id = sig['_id']?.toString();
          try {
            await _handleSignal(sig);
          } catch (e, st) {
            debugPrint('GroupCallService dispatch failed: $e\n$st');
          }
          if (id != null) ids.add(id);
        }
        try {
          await api.consumeSignals(signalIds: ids, userId: me);
        } catch (e) {
          debugPrint('GroupCallService consume failed: $e');
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> sig) async {
    final id = _groupCallId;
    final kind = sig['kind'] as String?;
    final from = sig['fromUserId']?.toString();
    final callId = sig['groupCallId']?.toString();
    final payload = (sig['payload'] as String?) ?? '{}';
    if (kind == null || from == null || callId == null) return;
    // Signals for a call we're not in are stale — consume-and-drop.
    if (id == null || callId != id) return;
    final peer = _peers[from];
    if (peer == null) return; // roster hasn't caught up; offerer will retry ICE restart path
    final parsed = jsonDecode(payload) as Map<String, dynamic>;

    switch (kind) {
      case 'offer':
        // Only the designated offerer sends offers; as the answerer we may
        // need to build our side of the link first.
        if (_iOffer(from)) return; // never valid — drop
        await _answerOffer(peer, parsed);
        break;
      case 'restart-offer':
        if (_iOffer(from)) return;
        await _answerOffer(peer, parsed, restart: true);
        break;
      case 'answer':
      case 'restart-answer':
        final pc = peer.pc;
        if (pc == null) return;
        if (pc.signalingState !=
            RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          return;
        }
        final sdp = parsed['sdp'] as String?;
        final type = parsed['type'] as String?;
        if (sdp == null || type == null) return;
        await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
        peer.remoteDescSet = true;
        _drainPeerIce(peer);
        break;
      case 'ice-batch':
        final list = (parsed['candidates'] as List?) ?? const [];
        for (final e in list) {
          await _addPeerCandidate(peer, (e as Map).cast<String, dynamic>());
        }
        break;
      case 'state':
        peer.mediaState = PeerMediaState.fromJson(parsed);
        notifyListeners();
        break;
      case 'restart-request':
        if (_iOffer(from)) {
          _schedulePeerRestart(peer, peer.generation,
              immediate: true, force: true);
        }
        break;
    }
  }

  Future<void> _answerOffer(GroupPeer peer, Map<String, dynamic> parsed,
      {bool restart = false}) async {
    final sdp = parsed['sdp'] as String?;
    final type = parsed['type'] as String?;
    if (sdp == null || type == null) return;
    var pc = peer.pc;
    if (pc == null) {
      // Build the answering side of the link (no offer from us).
      await _ensureLink(peer);
      pc = peer.pc;
      if (pc == null) return;
    }
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    peer.remoteDescSet = true;
    _drainPeerIce(peer);
    final answer = await pc.createAnswer({});
    await pc.setLocalDescription(answer);
    await _sendTo(peer, restart ? 'restart-answer' : 'answer', {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  Future<void> _addPeerCandidate(
      GroupPeer peer, Map<String, dynamic> parsed) async {
    final raw = parsed['candidate'] as String? ?? '';
    if (!kAllowLanCandidates &&
        (RegExp(r'\btyp\s+host\b').hasMatch(raw) || raw.contains('.local'))) {
      return;
    }
    final cand = RTCIceCandidate(
      parsed['candidate'] as String?,
      parsed['sdpMid'] as String?,
      (parsed['sdpMLineIndex'] as num?)?.toInt(),
    );
    if (peer.pc != null && peer.remoteDescSet) {
      await peer.pc!.addCandidate(cand);
    } else {
      peer.pendingRemoteIce.add(cand);
    }
  }

  void _drainPeerIce(GroupPeer peer) {
    final pc = peer.pc;
    if (pc == null) return;
    for (final c in peer.pendingRemoteIce) {
      pc.addCandidate(c);
    }
    peer.pendingRemoteIce.clear();
  }

  void _disposePeerLink(GroupPeer peer, {bool keepIdentity = false}) {
    peer.generation++;
    peer.restartTimer?.cancel();
    peer.iceFlushTimer?.cancel();
    peer.iceFlushTimer = null;
    peer.iceOut.clear();
    peer.pendingRemoteIce.clear();
    peer.remoteDescSet = false;
    peer.connected = false;
    peer.reconnecting = false;
    if (!keepIdentity) {
      peer.restartAttempt = 0;
      peer.outageStart = null;
    }
    final pc = peer.pc;
    peer.pc = null;
    peer.remoteStream = null;
    if (pc != null) {
      unawaited(pc.close().catchError((_) {}));
    }
  }

  // ───────── live controls ─────────

  Future<void> toggleMute() async {
    final ls = _localStream;
    if (ls == null) return;
    localMuted = !localMuted;
    for (final t in ls.getAudioTracks()) {
      t.enabled = !localMuted;
    }
    notifyListeners();
    await _broadcastState();
  }

  Future<void> toggleVideo() async {
    final ls = _localStream;
    if (ls == null || _mediaKind != CallMediaKind.video) return;
    localVideoOff = !localVideoOff;
    for (final t in ls.getVideoTracks()) {
      t.enabled = !localVideoOff;
    }
    notifyListeners();
    await _broadcastState();
  }

  Future<void> switchCamera() async {
    final ls = _localStream;
    if (ls == null || !isMobileCallPlatform) return;
    final tracks = ls.getVideoTracks();
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
    } catch (e) {
      debugPrint('switchCamera failed: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    await applyCallAudioRoute(speaker: speakerOn);
    notifyListeners();
  }

  Future<void> _broadcastState() async {
    for (final peer in _peers.values) {
      await _sendTo(peer, 'state', {
        'audioMuted': localMuted,
        'videoOff': localVideoOff,
      });
    }
  }

  // ───────── ICE config (shared cache semantics with CallService) ─────────

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
      final fresh = await iceConfigFetcher(me);
      _cachedIceServers = fresh;
      _cachedIceServersAt = DateTime.now();
      return fresh;
    } catch (e) {
      debugPrint('GroupCallService._iceServers fetch failed: $e');
      return const [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ];
    }
  }

  /// Injected at wiring time — reuses `calls:getIceConfig` via [CallApi]
  /// so both call stacks mint the same TURN credentials.
  Future<List<Map<String, dynamic>>> Function(String userId)
      iceConfigFetcher = (_) async => const [
            {'urls': 'stun:stun.l.google.com:19302'},
            {'urls': 'stun:stun1.l.google.com:19302'},
          ];

  @override
  void dispose() {
    _heartbeat?.cancel();
    _rosterSub?.cancel();
    _signalsSub?.cancel();
    _inviteSub?.cancel();
    for (final peer in _peers.values) {
      _disposePeerLink(peer);
    }
    _peers.clear();
    super.dispose();
  }
}
