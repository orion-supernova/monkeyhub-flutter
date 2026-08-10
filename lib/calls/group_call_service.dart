import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/convex_client.dart';
import '../backend/group_call_api.dart';
import '../data/settings_store.dart';
import 'call_config.dart';
import 'call_media.dart';
import 'call_models.dart';
import 'call_permissions.dart';
import 'call_recovery.dart';
import 'native_call_handler.dart';

/// Per-peer video bitrate cap for a mesh call: every phone runs one encoder
/// per remote peer, so the budget shrinks as the call grows. [baseline] is
/// the solo-call cap — the selected [VideoQualityTier]'s
/// `videoQualityPresets[tier].maxBitrate` — and the same ratios this used to
/// hardcode (900k/700k/500k against a 1200k baseline) apply proportionally,
/// so picking a higher tier still tapers the same way as group size grows.
int meshVideoBitrate(int remotePeerCount, {int baseline = 1200000}) {
  if (remotePeerCount <= 1) return baseline;
  if (remotePeerCount == 2) return (baseline * 0.75).round();
  if (remotePeerCount == 3) return (baseline * 7 / 12).round();
  return (baseline * 5 / 12).round();
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

  /// Full from-scratch link rebuilds consumed after recovery exhaustion.
  /// Capped: past the cap the link stays down and the roster reap (or the
  /// peer coming back) decides its fate — an unbounded rebuild loop would
  /// otherwise churn PCs forever without ever ending the call or releasing
  /// anything. Reset on a successful (re)connect.
  int rebuildCount = 0;

  PeerMediaState mediaState = const PeerMediaState();
  bool connected = false;

  /// Wall-clock ms of the last applied `state` signal from this peer —
  /// guards against an out-of-order delivery clobbering a newer state with
  /// a stale one. See [CallService._onRemoteState] for the identical 1:1
  /// rationale; the mesh needs its own copy per-peer since each link
  /// receives its own `state` stream.
  int? lastStateTs;
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

  /// Seam for tests — same shape as `CallService.getUserMediaFn`.
  @visibleForTesting
  Future<MediaStream> Function(CallMediaKind kind, {VideoQualityTier tier})
      getUserMediaFn = getCallUserMedia;

  /// Seam for tests — same shape as `CallService.createPcFn`.
  @visibleForTesting
  Future<RTCPeerConnection> Function(
    Map<String, dynamic> configuration,
    Map<String, dynamic> constraints,
  ) createPcFn = createPeerConnection;

  /// Cap on the `groupCalls:leave` mutation after local teardown already
  /// released the mic. Injectable so tests don't sit through real seconds.
  @visibleForTesting
  Duration leaveNotifyTimeout = const Duration(seconds: 5);

  /// Heartbeat cadence/deadline — injectable for fakeAsync tests. 15s beat
  /// against the server's 45s stale window (3 missed beats).
  @visibleForTesting
  Duration heartbeatInterval = const Duration(seconds: 15);
  @visibleForTesting
  Duration heartbeatTimeout = const Duration(seconds: 10);

  /// Same pattern as `CallService._mediaEpoch`: bumped at every acquisition
  /// start and first thing in [leaveCall], so a getUserMedia future
  /// resolving after the call ended stops its own (otherwise ownerless)
  /// stream instead of holding the mic forever.
  int _mediaEpoch = 0;

  /// Consecutive failed heartbeats. The roster subscription is this
  /// service's ONLY teardown trigger for a call that ends elsewhere — if
  /// that subscription silently dies, nothing would ever call [leaveCall].
  /// Four straight missed beats (~1min, past the server's 45s reap window)
  /// mean we're unreachable or already reaped: self-eject.
  int _missedHeartbeats = 0;

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

  /// Set first thing in [dispose]. [leaveCall] can be mid-`await` (its own
  /// API call, a track's `stop()`) when a widget-tree teardown disposes this
  /// service out from under it; without this guard its trailing
  /// `notifyListeners()` would fire after `super.dispose()` already ran and
  /// throw "used after being disposed."
  bool _disposed = false;

  /// Read once at [_enterCall] and held for the call's duration — mirrors
  /// how the 1:1 [CallService] path fetches it fresh per call rather than
  /// mid-call, since the encoder cap below is per-peer-link, not global.
  VideoQualityTier _videoTier = VideoQualityTier.auto;

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

  // `resubscribe()` used to live here, called on every socket reconnect.
  // Removed: both transports replay their own query set, and `ConvexBackend`'s
  // SubscriptionRegistry covers a forced rebuild. These two go through it like
  // every other subscription.

  /// Bumped on every [_resubscribe]. Two overlapping calls each land a handle
  /// in the same two fields, so without this the loser was orphaned live with
  /// nothing left to cancel it. Same shape as the guard in [_enterCall].
  int _subGen = 0;

  void _resubscribe() {
    final me = _userId;
    if (me == null) return;
    final gen = ++_subGen;
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
        .then((s) {
      if (gen != _subGen || _userId != me) {
        s.cancel();
        return;
      }
      _signalsSub = s;
    }));
    unawaited(api
        .subscribePendingInvite(
          userId: me,
          onInvite: (inv) {
            pendingInvite = inv;
            notifyListeners();
          },
          onError: (e) => debugPrint('GroupCallService invite error: $e'),
        )
        .then((s) {
      if (gen != _subGen || _userId != me) {
        s.cancel();
        return;
      }
      _inviteSub = s;
    }));
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
    // The single choke point both start and join funnel through, so one gate
    // covers every way into a mesh call. Group calls never touch the callkit
    // bridge — no native UI, no foreground service — so this is not the crash
    // guard the 1:1 path needs; it is here so a missing grant produces the same
    // clear refusal instead of a raw getUserMedia throw below.
    if (!await CallPermissions.ensure(kind)) return;
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
      speakerOn = kind == CallMediaKind.video;
      await applyIosCallAudioConfig(kind, speakerOn: speakerOn);
      _videoTier = SettingsStore.instance.videoQualityTier;
      final epoch = ++_mediaEpoch;
      final stream = await getUserMediaFn(kind, tier: _videoTier);
      if (epoch != _mediaEpoch || _groupCallId != groupCallId) {
        // [leaveCall] ran while getUserMedia was still in flight. The call
        // is over; nothing else will ever see this stream — stop it here or
        // the mic stays hot with no owner, and skip the rest of the setup
        // (heartbeat, roster) that would resurrect a dead call.
        await stopAndDisposeStream(stream);
        return;
      }
      _localStream = stream;
      await applyCallAudioRoute(speaker: speakerOn);
    } catch (e, st) {
      debugPrint('GroupCallService: getUserMedia failed: $e\n$st');
      await leaveCall();
      rethrow;
    }

    _missedHeartbeats = 0;
    _heartbeat?.cancel();
    // Keeps the room banner honest within ~a minute of an app dying — and,
    // since the roster subscription is the only other thing that can end
    // this call locally, doubles as the dead-subscription watchdog: a
    // server that says we're not in the call (or four straight failures to
    // reach it) means the call is over whether or not the roster ever
    // manages to tell us.
    _heartbeat = Timer.periodic(heartbeatInterval, (_) async {
      final id = _groupCallId;
      if (id == null) return;
      try {
        final status = await api
            .heartbeat(groupCallId: id, userId: me)
            .timeout(heartbeatTimeout);
        _missedHeartbeats = 0;
        if (status == 'not-in-call') {
          debugPrint('GroupCallService: server says not-in-call — ejecting');
          unawaited(leaveCall());
        }
      } catch (_) {
        _missedHeartbeats++;
        if (_missedHeartbeats >= 4) {
          debugPrint('GroupCallService: 4 heartbeats failed — self-ejecting');
          _missedHeartbeats = 0;
          unawaited(leaveCall());
        }
      }
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
  ///
  /// Local teardown — the mic release — never waits on the network. The
  /// `leave` mutation is kicked off first (it hits the wire before any
  /// possible rejoin, preserving server-side ordering) but is awaited only
  /// at the end, bounded; if it never lands, our stopped heartbeat gets us
  /// reaped server-side within ~45s anyway.
  Future<void> leaveCall() async {
    if (_ending) return;
    _ending = true;
    // Kill any in-flight acquisition FIRST — a getUserMedia resolving after
    // this point must see the epoch moved on and stop its own stream.
    _mediaEpoch++;
    final me = _userId;
    final id = _groupCallId;
    final notify = (me != null && id != null)
        ? () async {
            try {
              await api
                  .leave(groupCallId: id, userId: me)
                  .timeout(leaveNotifyTimeout);
            } catch (e) {
              debugPrint('GroupCallService.leave notify failed: $e');
            }
          }()
        : Future<void>.value();
    _heartbeat?.cancel();
    _heartbeat = null;
    _rosterSub?.cancel();
    _rosterSub = null;
    for (final peer in _peers.values) {
      _disposePeerLink(peer);
    }
    _peers.clear();
    rosterRows = const [];
    final ls = _localStream;
    _localStream = null;
    if (ls != null) {
      // Per-track stop with individual guards — see [stopAndDisposeStream].
      await stopAndDisposeStream(ls);
    }
    _groupCallId = null;
    _roomId = null;
    _ending = false;
    if (!_disposed) notifyListeners();
    // Belt for iOS: with no plugin/CallKit card alive (group calls never
    // raise one) this releases the audio session WebRTC activated.
    unawaited(NativeCallHandler.instance.deactivateIosAudioSession());
    await notify;
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
    final bitrate = meshVideoBitrate(
      _peers.length,
      baseline: videoQualityPresets[_videoTier]!.maxBitrate,
    );
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
      await configureVideoSenders(
        pc,
        maxBitrate: meshVideoBitrate(
          _peers.length,
          baseline: videoQualityPresets[_videoTier]!.maxBitrate,
        ),
      );
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
    final pc = await createPcFn({
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
    peer.rebuildCount = 0;
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
      // Rebuild the link from scratch — with a fresh recovery budget
      // (_disposePeerLink resets restartAttempt/outageStart; preserving
      // them made every later rebuild abandon on its FIRST failure,
      // producing an unbounded instant-churn loop). Capped: past the cap
      // the link stays down and the heartbeat GC removes the peer from the
      // roster within ~90s, which tears this down for good. Deliberately
      // NOT leaveCall() — one unreachable peer must not end my call with
      // everyone else.
      peer.rebuildCount++;
      _disposePeerLink(peer, keepIdentity: true);
      if (peer.rebuildCount > 2) {
        debugPrint(
            'GroupCallService: giving up on ${peer.userId} after '
            '${peer.rebuildCount - 1} rebuilds — leaving link down');
        return;
      }
      debugPrint(
          'GroupCallService: rebuilding link to ${peer.userId} after failed '
          'recovery (rebuild ${peer.rebuildCount})');
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
        final ts = (parsed['ts'] as num?)?.toInt();
        if (ts != null && peer.lastStateTs != null && ts < peer.lastStateTs!) {
          break;
        }
        if (ts != null) peer.lastStateTs = ts;
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
    // A fresh link always deserves a fresh recovery budget — carrying the
    // spent one across a rebuild made the next failure abandon instantly.
    // [keepIdentity] preserves only who the peer is (name/avatar) and the
    // rebuild cap that spans link lifetimes.
    peer.restartAttempt = 0;
    peer.outageStart = null;
    if (!keepIdentity) {
      peer.rebuildCount = 0;
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
    final ts = DateTime.now().millisecondsSinceEpoch;
    for (final peer in _peers.values) {
      await _sendTo(peer, 'state', {
        'audioMuted': localMuted,
        'videoOff': localVideoOff,
        'ts': ts,
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
    _disposed = true;
    _heartbeat?.cancel();
    _rosterSub?.cancel();
    _signalsSub?.cancel();
    _inviteSub?.cancel();
    for (final peer in _peers.values) {
      _disposePeerLink(peer);
    }
    _peers.clear();
    // Unlike `leaveCall()`, this used to never touch `_localStream` — a call
    // torn down via provider/widget-tree disposal without going through
    // `leaveCall()` first left the mic (and camera) held open, the OS
    // mic-in-use indicator included. `dispose()` can't be `async`, so this
    // mirrors `_disposePeerLink`'s fire-and-forget `unawaited(...)` style.
    final ls = _localStream;
    if (ls != null) {
      for (final t in ls.getTracks()) {
        unawaited(t.stop().catchError((_) {}));
      }
      unawaited(ls.dispose().catchError((_) {}));
    }
    _localStream = null;
    super.dispose();
  }
}
