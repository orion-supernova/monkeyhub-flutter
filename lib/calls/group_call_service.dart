import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

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
import 'draw/draw_channel.dart';
import 'draw/draw_model.dart';
import 'native_call_handler.dart';
import 'renegotiation.dart';
import 'screen_share.dart';

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

  /// The peer's screen, while it is sharing one — the second video stream
  /// on this link. Told apart from the camera by the ids the peer names in
  /// its `state` signal (see [PeerMediaState]); until that signal has
  /// arrived a stream is filed under [streamsById] and sorted later.
  MediaStream? screenStream;
  int screenStreamTick = 0;

  /// Every stream `onTrack` has ever delivered on this link, by id — the
  /// pool [remoteStream] and [screenStream] are picked from whenever the
  /// peer's `state` names its streams.
  final Map<String, MediaStream> streamsById = {};

  /// Ids the peer has ever named as its screen. A share that ended leaves
  /// its stream in the pool with a video track still in it; without this
  /// the camera fallback would pick it up and the call would stay a video
  /// call of a frozen screen.
  final Set<String> screenStreamIds = {};

  /// Our two outbound video slots on this link — camera and screen — each
  /// negotiated once, then switched on and off with `replaceTrack`. See
  /// `renegotiation.dart` for why a slot is never torn down.
  RTCRtpSender? camSender;
  RTCRtpSender? screenSender;

  /// Offer/answer bookkeeping for this link.
  final LinkNegotiation negotiation = LinkNegotiation();

  /// The drawing channel over a shared screen, opened by the offerer before
  /// its first offer so it rides the initial SDP. Both ends draw on it.
  RTCDataChannel? drawChannel;
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

  /// Whether this process drives a native call card (CallKit /
  /// ConnectionService) for a group invite — real iOS and Android only; web
  /// and desktop ring in-app and have no card to end. Gates
  /// [_endNativeCard]. A seam, so a test host can exercise that path.
  @visibleForTesting
  bool nativeCardsEnabled =
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Ends the native card for a group call id. Seam for tests; the real one
  /// resolves the card through the plugin's own records and the derived id
  /// both ring paths compute from the groupCallId.
  @visibleForTesting
  Future<void> Function(String groupCallId) endNativeCardFn =
      (id) => NativeCallHandler.instance.endNativeByCallId(id);

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

  /// The call a `joinCall` is in flight for — the window in which the invite
  /// leaving the subscription must not be read as the call going away.
  String? get joiningGroupCallId => _joiningGroupCallId;
  String? _roomId;
  String? get roomId => _roomId;
  CallMediaKind _mediaKind = CallMediaKind.audio;
  CallMediaKind get mediaKind => _mediaKind;
  bool get inCall => _groupCallId != null;

  /// Whether [attach] has run, i.e. whether this service knows who it is.
  ///
  /// Read by the native ringer: a card answered from a killed app fires its
  /// accept while auth is still being restored, and every mutation below needs
  /// a userId that does not exist yet. See
  /// `NativeCallHandler._attachedGroupService`.
  bool get isAttached => _userId != null;
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

  /// Bumped when a track is swapped inside [localStream] in place — a
  /// camera coming on in a voice call — since the reference does not change
  /// and a renderer keyed on it would keep showing the old track.
  int localStreamTick = 0;

  /// The screen this device is sharing, while it is. Its own stream, so the
  /// peers can tell it from the camera by id (see
  /// [PeerMediaState.screenStreamId]); created once per call and kept across
  /// shares, because the slot it rides in is negotiated once per link and
  /// the id in that negotiation has to keep meaning this.
  MediaStream? _screenStream;
  MediaStream? get screenStream => _screenStream;
  int localScreenStreamTick = 0;
  bool localScreenSharing = false;

  /// True from the moment a share was asked for until the platform is
  /// actually sending it — on iOS, until the broadcast the system picker
  /// offered has started. The tray shows it as "Starting…" with the control
  /// disabled; a share that never starts is rolled back and this goes false
  /// again. See [startScreenShare].
  bool screenSharePending = false;

  /// When this device joined the call — what the call screen's timer counts
  /// from.
  DateTime? joinedAt;

  /// Bumped when a minimised call wants its screen back — the in-call pill's
  /// "return". The overlay that pushes the call screen listens.
  final ValueNotifier<int> reopenTick = ValueNotifier<int>(0);

  /// Whether this device is drawing over the shared screen right now — the
  /// pen on the call screen and on the in-call pill are one switch. Only
  /// meaningful while a screen is shared; cleared with the share.
  final ValueNotifier<bool> drawArmed = ValueNotifier<bool>(false);

  /// The strokes drawn over a shared screen — everyone's, ours included —
  /// and the per-link channels they travel on. One model for the call: a
  /// stroke is a stroke whoever is presenting.
  final DrawModel drawModel = DrawModel();
  late final DrawChannels _draw = DrawChannels(model: drawModel);

  /// Seams for tests — the platform calls behind the live controls.
  @visibleForTesting
  Future<MediaStream> Function({ScreenShareSource? source}) getDisplayMediaFn =
      ScreenShare.capture;
  @visibleForTesting
  Future<MediaStreamTrack> Function(VideoQualityTier tier) getVideoTrackFn =
      getCallVideoOnlyTrack;
  @visibleForTesting
  Future<MediaStream> Function(String label) createLocalStreamFn =
      createLocalMediaStream;
  @visibleForTesting
  Future<bool> Function(CallMediaKind kind) ensurePermissionsFn =
      CallPermissions.ensure;
  @visibleForTesting
  Future<void> Function(RTCPeerConnection pc) preferCodecFn = preferH264Codec;

  MediaStreamTrack? get _camTrack {
    final v = _localStream?.getVideoTracks();
    return (v == null || v.isEmpty) ? null : v.first;
  }

  MediaStreamTrack? get _screenTrack {
    final v = _screenStream?.getVideoTracks();
    return (v == null || v.isEmpty) ? null : v.first;
  }

  /// Whether this device is sending its camera right now.
  bool get localCamActive => _camTrack != null && !localVideoOff;

  /// Whether ANY video is on the call — ours or a peer's, camera or screen.
  ///
  /// The call screen picks its layout on this. A voice call with nothing to
  /// look at stays a voice call; the moment someone's camera comes on it is
  /// a video call for everyone, and when the last one goes off it is a
  /// voice call again. A peer counts only once its video track has actually
  /// landed — its `videoOff: false` alone would switch the screen to a grid
  /// of empty tiles while the frames are still on their way.
  bool get hasAnyVideo {
    if (localCamActive || localScreenSharing) return true;
    for (final p in _peers.values) {
      if (p.mediaState.screenSharing && p.screenStream != null) return true;
      final rs = p.remoteStream;
      if (!p.mediaState.videoOff &&
          rs != null &&
          rs.getVideoTracks().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// The peer presenting a screen, if any. One presenter at a time — the
  /// share control is disabled while this is non-null.
  GroupPeer? get presentingPeer {
    for (final p in _peers.values) {
      if (p.mediaState.screenSharing) return p;
    }
    return null;
  }

  /// How many video sections a link to us must carry for what we send.
  int get _activeVideoSlots =>
      (_camTrack != null ? 1 : 0) + (_screenTrack != null ? 1 : 0);

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

  /// The invite whose native card this device may be showing right now: the
  /// last non-null `groupCallId` the subscription delivered, held until the
  /// subscription drops or replaces it. See [_onInviteGone].
  String? _ringingInviteId;

  /// The call [joinCall] is in the middle of entering. Set BEFORE the join
  /// mutation is awaited, because the subscription drops the invite the
  /// instant the server marks us joined — routinely before [_enterCall] has
  /// set [_groupCallId] — and that drop must not read as "the call went
  /// away" and end the card the user just answered.
  String? _joiningGroupCallId;

  /// The room this call is in, for the in-call screen's title. Seeded from
  /// the invite when joining from one, then kept current by the roster —
  /// which is also where a call started from inside the room learns it.
  String? _roomName;
  String? get roomName => _roomName;
  String? _roomAvatarStorageId;
  String? get roomAvatarStorageId => _roomAvatarStorageId;

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
            final prev = _ringingInviteId;
            final next = inv?['groupCallId']?.toString();
            pendingInvite = inv;
            _ringingInviteId = next;
            if (prev != null && prev != next) _onInviteGone(prev);
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
    _joiningGroupCallId = groupCallId;
    try {
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
    } finally {
      _joiningGroupCallId = null;
    }
  }

  Future<void> _enterCall(
    String groupCallId, {
    required String roomId,
    required CallMediaKind kind,
  }) async {
    if (_groupCallId == groupCallId) return;
    // The single choke point both start and join funnel through, so one gate
    // covers every way into a mesh call. A group card answered natively has
    // already been through the plugin's foreground-service gate — decided at
    // ring time in `NativeCallHandler.showIncoming` — so this is not the
    // crash guard the 1:1 path needs; it is here so a missing grant produces
    // the same clear refusal instead of a raw getUserMedia throw below.
    if (!await CallPermissions.ensure(kind)) return;
    final me = _userId!;
    _groupCallId = groupCallId;
    _roomId = roomId;
    _mediaKind = kind;
    _ending = false;
    localMuted = false;
    localVideoOff = kind != CallMediaKind.video;
    localScreenSharing = false;
    joinedAt = DateTime.now();
    // The room's name for the in-call screen: off the invite when this is
    // the call it offered, otherwise the roster fills it in on its first
    // frame.
    final inv = pendingInvite;
    if (inv?['groupCallId']?.toString() == groupCallId) {
      _roomName = inv?['roomName']?.toString();
      _roomAvatarStorageId = inv?['roomAvatarStorageId'] as String?;
    } else {
      _roomName = null;
      _roomAvatarStorageId = null;
    }
    // The card for this invite is now the call. When the subscription drops
    // the invite in a moment it must not be mistaken for the call going away.
    if (_ringingInviteId == groupCallId) _ringingInviteId = null;
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
    drawModel.clearAll();
    drawArmed.value = false;
    final ss = _screenStream;
    _screenStream = null;
    // A share still waiting on its broadcast returns false from that wait
    // and disposes what it captured; nothing else holds the capture.
    ScreenShare.cancelStartWait();
    if (localScreenSharing) {
      localScreenSharing = false;
      ScreenShare.onPlatformStop = null;
      unawaited(ScreenShare.release());
    }
    if (ss != null) await stopAndDisposeStream(ss);
    final ls = _localStream;
    _localStream = null;
    if (ls != null) {
      // Per-track stop with individual guards — see [stopAndDisposeStream].
      await stopAndDisposeStream(ls);
    }
    _groupCallId = null;
    _roomId = null;
    _roomName = null;
    _roomAvatarStorageId = null;
    _ending = false;
    if (!_disposed) notifyListeners();
    // A card answered natively IS the call to CallKit / ConnectionService:
    // an "ongoing" session that stays up until told otherwise, and nothing
    // else ever tells it — a `left` participant is never a `group_taken`
    // target. No ack: no push is coming for this device. A no-op for a
    // starter, who never had a card.
    if (id != null) _endNativeCard(id, ack: false);
    // Darwin mic belt — see [stopDarwinMicCapture]. Never while a 1:1 call
    // is live in this process: the two paths share one audio-device module.
    // Fire-and-forget, after the state reset above: nothing here waits on a
    // platform channel, and a session that is over must read as over now.
    if (!NativeCallHandler.dmCallActiveProbe()) {
      unawaited(stopDarwinMicCapture());
    }
    // Belt for iOS: releases the audio session WebRTC activated once no
    // card is alive — repeated, because the card list it is gated on
    // empties a beat after `endCall` returns.
    unawaited(NativeCallHandler.instance.deactivateIosAudioSessionSettled());
    await notify;
  }

  Future<void> declineInvite() async {
    final inv = pendingInvite;
    if (inv == null) return;
    await declineInviteById(inv['groupCallId'].toString());
  }

  /// Decline a specific invite, whether or not it is the one this process is
  /// holding in [pendingInvite].
  ///
  /// The native ringer needs this: a card raised by the push itself, in a
  /// process that was launched by that push, is answered or refused before
  /// any subscription has delivered the invite it belongs to — so there is
  /// frequently no `pendingInvite` to read the id out of. The id comes off
  /// the card instead (`NativeCallHandler._groupCallIdFromParams`).
  Future<void> declineInviteById(String groupCallId) async {
    final me = _userId;
    if (me == null) return;
    // Only clear the held invite if it is the one being declined — a stale
    // card for an older call must not silence the ringer for a live one.
    if (pendingInvite?['groupCallId']?.toString() == groupCallId) {
      pendingInvite = null;
      notifyListeners();
    }
    // The in-app Dismiss button would otherwise leave the native card
    // standing (Android raises one beside the in-app ringer). When CallKit
    // itself was what declined this is a no-op; the ack is what keeps the
    // grace-delayed push off this device either way. Cleared from
    // [_ringingInviteId] first so the subscription's follow-up drop does not
    // end and ack the same card a second time.
    if (_ringingInviteId == groupCallId) _ringingInviteId = null;
    _endNativeCard(groupCallId, ack: true);
    try {
      await api.decline(
        groupCallId: groupCallId,
        userId: me,
        deviceId: _deviceId,
      );
    } catch (_) {}
  }

  /// The invite left `pendingInviteForUser` — joined on another device,
  /// declined there, the call ended, or the ring window closed — and its
  /// native card is still up. This is the one moment a LIVE app can take the
  /// card down itself; the backend's `group_taken` push is only the backstop
  /// for a killed process, and is delayed by `TAKEN_PUSH_GRACE_MS` precisely
  /// so this can happen first and ack. Not when the invite left because WE
  /// answered it: the card is the call now.
  void _onInviteGone(String groupCallId) {
    if (groupCallId == _groupCallId || groupCallId == _joiningGroupCallId) {
      return;
    }
    _endNativeCard(groupCallId, ack: true);
  }

  /// A native card for [groupCallId] that has no invite behind it any more
  /// — found by `NativeCallHandler.replayColdStartCalls` on a resume, after
  /// the invite was answered elsewhere, declined, ended or rang out while
  /// this process was not listening. Ended like [_onInviteGone] ends one,
  /// ack included; never a decline, because nobody declined anything.
  Future<void> dismissStaleCard(String groupCallId) async {
    if (_ringingInviteId == groupCallId) _ringingInviteId = null;
    if (pendingInvite?['groupCallId']?.toString() == groupCallId) {
      pendingInvite = null;
      notifyListeners();
    }
    _endNativeCard(groupCallId, ack: true);
  }

  /// End the native card for [groupCallId] and, with [ack], tell the backend
  /// so the grace-delayed `group_taken` skips this device. No ack on failure:
  /// the card may still be up, and that push is then the one thing left that
  /// can clear it — the rule `CallService._teardown` follows.
  void _endNativeCard(String groupCallId, {required bool ack}) {
    if (!nativeCardsEnabled) return;
    unawaited(endNativeCardFn(groupCallId).then((_) {
      if (ack) _ackNativeDismissed(groupCallId);
    }).catchError((Object e) {
      debugPrint('GroupCallService: end native card failed: $e');
    }));
  }

  /// `groupCalls:ackNativeDismissed`, fire-and-forget. Nothing here can be
  /// worth blocking on: if it never lands the push arrives after its grace
  /// and ends a card that is already gone, which is the status quo ante.
  void _ackNativeDismissed(String groupCallId) {
    final me = _userId;
    final dev = _deviceId;
    if (me == null || dev == null) return;
    try {
      unawaited(api
          .ackNativeDismissed(groupCallId: groupCallId, userId: me, deviceId: dev)
          .catchError((Object e) {
        debugPrint('GroupCallService: ackNativeDismissed failed: $e');
      }));
    } catch (e) {
      debugPrint('GroupCallService: ackNativeDismissed threw: $e');
    }
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
    _roomName = roster['roomName']?.toString() ?? _roomName;
    _roomAvatarStorageId =
        (roster['roomAvatarStorageId'] as String?) ?? _roomAvatarStorageId;
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
        unawaited(configureVideoSenders(pc, maxBitrate: bitrate)
            .then((_) => _retuneScreenSender(peer)));
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
      peer.negotiation.reset();
      final ls = _localStream;
      if (ls != null) {
        for (final track in ls.getTracks()) {
          final sender = await pc.addTrack(track, ls);
          if (track.kind == 'video') peer.camSender = sender;
        }
      }
      // A screen already being shared rides the first offer too.
      await _ensureLocalSlots(peer, pc);
      await _tuneSenders(peer, pc);
      // Our mute/video/share state — and the ids that tell our streams
      // apart — BEFORE the offer that carries them, so the newcomer can file
      // each track as it lands.
      await _sendTo(peer, 'state', _stateJson());
      if (_iOffer(peer.userId)) {
        peer.negotiation.begin();
        final offer = await pc.createOffer({
          'offerToReceiveAudio': true,
          // Always, voice call or not. The section costs nothing while
          // nobody sends on it, and it is what lets a camera come on later
          // as a direction change instead of a new m-line.
          'offerToReceiveVideo': true,
        });
        await pc.setLocalDescription(offer);
        await _sendTo(peer, 'offer', {
          'sdp': offer.sdp,
          'type': offer.type,
          'mediaKind': _mediaKind.wire,
        });
      }
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
      for (final s in event.streams) {
        peer.streamsById[s.id] = s;
      }
      if (event.streams.isNotEmpty) {
        _classifyPeerStreams(peer, arrived: event.streams);
      }
      notifyListeners();
    };

    // The drawing channel is created by the offerer BEFORE its first offer,
    // so the `m=application` section is in the SDP the link is built on and
    // no later negotiation is needed for it. The answerer receives it.
    if (_iOffer(peer.userId)) {
      try {
        final ch = await pc.createDataChannel(
          DrawChannels.label,
          DrawChannels.init(),
        );
        _attachDrawChannel(peer, gen, ch);
      } catch (e) {
        debugPrint('GroupCallService: createDataChannel failed: $e');
      }
    } else {
      pc.onDataChannel = (ch) {
        if (gen != peer.generation) return;
        if (ch.label == DrawChannels.label) _attachDrawChannel(peer, gen, ch);
      };
    }

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
        // An offer like any other: a re-offer sent on top of it would
        // answer a section list the peer never saw.
        peer.negotiation.begin();
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
      case 'restart-offer':
      case 'reoffer':
        // Only the designated offerer sends offers; as the answerer we may
        // need to build our side of the link first.
        if (_iOffer(from)) return; // never valid — drop
        await _applyRemoteOffer(peer, parsed, kind: kind);
        break;
      case 'answer':
      case 'restart-answer':
      case 'reanswer':
        final pc = peer.pc;
        if (pc == null) return;
        if (pc.signalingState !=
            RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
          return;
        }
        // A `reanswer` names the offer it answers; one for an offer an ICE
        // restart has since overtaken would be applied against the wrong
        // local description.
        if (kind == 'reanswer' &&
            !peer.negotiation.accepts((parsed['seq'] as num?)?.toInt())) {
          return;
        }
        final sdp = parsed['sdp'] as String?;
        final type = parsed['type'] as String?;
        if (sdp == null || type == null) return;
        await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
        peer.remoteDescSet = true;
        _drainPeerIce(peer);
        _finishNegotiation(peer);
        break;
      case 'renegotiate':
        // The answering side wants to send something new and cannot offer;
        // re-offer with room for it.
        if (!_iOffer(from)) return;
        final wanted = (parsed['videoSlots'] as num?)?.toInt() ?? 0;
        peer.negotiation.wantedVideoSlots =
            math.max(peer.negotiation.wantedVideoSlots, wanted);
        unawaited(_renegotiate(peer));
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
        // The state names the peer's streams; anything that landed before
        // it did is sorted now, and a share that ended lets go of its
        // stream.
        _classifyPeerStreams(peer);
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

  /// Applies an offer from the designated offerer — the first one, an ICE
  /// restart's, or a re-offer — on the live link, and answers it.
  Future<void> _applyRemoteOffer(
    GroupPeer peer,
    Map<String, dynamic> parsed, {
    required String kind,
  }) async {
    final sdp = parsed['sdp'] as String?;
    final type = parsed['type'] as String?;
    if (sdp == null || type == null) return;
    var pc = peer.pc;
    if (pc == null) {
      // A re-offer presumes a link; without one there is nothing to apply
      // it to, and the offerer's restart path rebuilds from scratch.
      if (kind == 'reoffer') return;
      // Build the answering side of the link (no offer from us).
      await _ensureLink(peer);
      pc = peer.pc;
      if (pc == null) return;
    }
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    peer.remoteDescSet = true;
    _drainPeerIce(peer);
    // A slot that came on while this offer was in the air attaches now, to
    // whichever offered section is free, and rides the answer.
    await _ensureLocalSlots(peer, pc);
    await _tuneSenders(peer, pc);
    final answer = await pc.createAnswer({});
    await pc.setLocalDescription(answer);
    final reply = switch (kind) {
      'restart-offer' => 'restart-answer',
      'reoffer' => 'reanswer',
      _ => 'answer',
    };
    await _sendTo(peer, reply, {
      'sdp': answer.sdp,
      'type': answer.type,
      if (kind == 'reoffer') 'seq': parsed['seq'],
    });
    // A track of ours still without a section — more slots than the offer
    // had room for — needs another round.
    if (await hasUnassociatedVideoSender(pc)) {
      await _requestRenegotiation(peer);
    }
  }

  // ───────── renegotiation (see renegotiation.dart) ─────────

  /// Offerer only: re-offer the link with every active slot of ours and
  /// enough receive sections for the peer's. Serialised per link — a change
  /// while an offer is out is remembered and sent once the answer lands.
  Future<void> _renegotiate(GroupPeer peer) async {
    final pc = peer.pc;
    if (pc == null || !inCall || !_iOffer(peer.userId)) return;
    final neg = peer.negotiation;
    if (neg.inFlight) {
      neg.dirty = true;
      return;
    }
    final gen = peer.generation;
    final seq = neg.begin();
    try {
      await _ensureLocalSlots(peer, pc);
      await ensureRecvVideoSlots(pc, neg.wantedVideoSlots);
      await _tuneSenders(peer, pc);
      // No legacy receive hints: the transceivers say what this offer is.
      final offer = await pc.createOffer({});
      if (gen != peer.generation || !identical(peer.pc, pc)) return;
      await pc.setLocalDescription(offer);
      await _sendTo(peer, 'reoffer', {
        'sdp': offer.sdp,
        'type': offer.type,
        'seq': seq,
      });
    } catch (e, st) {
      debugPrint('GroupCallService._renegotiate(${peer.userId}): $e\n$st');
      neg.inFlight = false;
    }
  }

  void _finishNegotiation(GroupPeer peer) {
    if (peer.negotiation.finish()) unawaited(_renegotiate(peer));
  }

  /// Answerer only: ask the offerer for a round with room for our slots.
  Future<void> _requestRenegotiation(GroupPeer peer) => _sendTo(
        peer,
        'renegotiate',
        {
          'videoSlots': _activeVideoSlots,
          'ts': DateTime.now().millisecondsSinceEpoch,
        },
      );

  /// A slot of ours just became active: get it onto this link.
  Future<void> _activateSlots(GroupPeer peer) async {
    final pc = peer.pc;
    // No link yet: [_ensureLink] carries every active slot when it builds.
    if (pc == null) return;
    if (_iOffer(peer.userId)) {
      await _renegotiate(peer);
    } else {
      // Added now, before any offer: unified plan parks the track on a
      // section of its own and associates it with the next offer's.
      await _ensureLocalSlots(peer, pc);
      await _requestRenegotiation(peer);
    }
  }

  /// Adds a sender for every active slot that has none on this link.
  Future<void> _ensureLocalSlots(GroupPeer peer, RTCPeerConnection pc) async {
    final cam = _camTrack;
    final ls = _localStream;
    if (cam != null && ls != null && peer.camSender == null) {
      peer.camSender = await pc.addTrack(cam, ls);
    }
    final screen = _screenTrack;
    final ss = _screenStream;
    if (screen != null && ss != null && peer.screenSender == null) {
      peer.screenSender = await pc.addTrack(screen, ss);
    }
  }

  Future<void> _tuneSenders(GroupPeer peer, RTCPeerConnection pc) async {
    await configureVideoSenders(
      pc,
      maxBitrate: meshVideoBitrate(
        _peers.length,
        baseline: videoQualityPresets[_videoTier]!.maxBitrate,
      ),
    );
    await _retuneScreenSender(peer);
    await preferCodecFn(pc);
  }

  /// After every camera pass — [configureVideoSenders] tunes EVERY video
  /// sender for a face, and a screen wants the opposite trade.
  Future<void> _retuneScreenSender(GroupPeer peer) async {
    final sender = peer.screenSender;
    if (sender == null) return;
    await configureScreenSender(sender, remotePeerCount: _peers.length);
  }

  /// Files the streams a link has delivered as the peer's camera and
  /// screen, by the ids its `state` names. Before that state arrives the
  /// stream carrying audio is taken for the camera — the only stream a
  /// link had until screens existed — and everything is re-sorted when the
  /// ids land. [arrived] are the streams a track just landed in; a renderer
  /// bound to one of them has to rebind to see the new track.
  void _classifyPeerStreams(
    GroupPeer peer, {
    Iterable<MediaStream> arrived = const [],
  }) {
    final st = peer.mediaState;
    final pool = peer.streamsById;
    MediaStream? screen;
    final sid = st.screenStreamId;
    if (sid != null) peer.screenStreamIds.add(sid);
    if (st.screenSharing && sid != null) screen = pool[sid];
    MediaStream? cam;
    final cid = st.camStreamId;
    if (cid != null) cam = pool[cid];
    bool neverScreen(MediaStream s) =>
        !identical(s, screen) && !peer.screenStreamIds.contains(s.id);
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
    cam ??= peer.remoteStream;
    var camChanged = !identical(cam, peer.remoteStream);
    var screenChanged = !identical(screen, peer.screenStream);
    peer.remoteStream = cam;
    peer.screenStream = screen;
    for (final s in arrived) {
      if (identical(s, screen)) {
        screenChanged = true;
      } else if (identical(s, cam)) {
        camChanged = true;
      }
    }
    if (camChanged) peer.remoteStreamTick++;
    if (screenChanged) peer.screenStreamTick++;
  }

  void _attachDrawChannel(GroupPeer peer, int gen, RTCDataChannel ch) {
    if (gen != peer.generation) return;
    peer.drawChannel = ch;
    _draw.attach(peer.userId, ch);
  }

  Map<String, dynamic> _stateJson() => {
        ...PeerMediaState(
          audioMuted: localMuted,
          videoOff: localVideoOff,
          screenSharing: localScreenSharing,
          camStreamId: _localStream?.id,
          screenStreamId: _screenStream?.id,
        ).toJson(),
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

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
    peer.screenStream = null;
    peer.streamsById.clear();
    peer.screenStreamIds.clear();
    peer.camSender = null;
    peer.screenSender = null;
    peer.negotiation.reset();
    final ch = peer.drawChannel;
    peer.drawChannel = null;
    if (ch != null) {
      _draw.detach(peer.userId);
      unawaited(ch.close().catchError((_) {}));
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

  /// Camera on/off.
  ///
  /// In a video call the camera stays acquired and its track is gated, as
  /// it always was. In a VOICE call there is no camera track at all until
  /// the user asks for one: turning it on acquires the camera, adds the
  /// track to the local stream and negotiates a slot for it on every link;
  /// turning it off hands the slots an empty track and releases the camera
  /// (its light goes out), and the next "on" swaps a fresh track into the
  /// slots that already exist — no signaling. The loudspeaker comes on with
  /// the camera: someone looking at a screen is not holding it to an ear.
  Future<void> toggleVideo() async {
    final ls = _localStream;
    if (ls == null) return;
    if (_mediaKind == CallMediaKind.video) {
      localVideoOff = !localVideoOff;
      for (final t in ls.getVideoTracks()) {
        t.enabled = !localVideoOff;
      }
      notifyListeners();
      await _broadcastState();
      return;
    }
    if (localVideoOff) {
      await _cameraOn(ls);
    } else {
      await _cameraOff(ls);
    }
  }

  Future<void> _cameraOn(MediaStream ls) async {
    if (!await ensurePermissionsFn(CallMediaKind.video)) return;
    final id = _groupCallId;
    final MediaStreamTrack track;
    try {
      track = await getVideoTrackFn(_videoTier);
    } catch (e) {
      debugPrint('GroupCallService._cameraOn: $e');
      return;
    }
    if (_groupCallId != id || _localStream != ls) {
      // The call ended while the camera was warming up.
      try {
        await track.stop();
      } catch (_) {}
      return;
    }
    await ls.addTrack(track);
    localVideoOff = false;
    localStreamTick++;
    if (!speakerOn) {
      speakerOn = true;
      await applyIosCallAudioConfig(CallMediaKind.video, speakerOn: true);
      await applyCallAudioRoute(speaker: true);
    }
    notifyListeners();
    await _broadcastState();
    for (final peer in _peers.values.toList(growable: false)) {
      final sender = peer.camSender;
      if (sender != null) {
        try {
          await sender.replaceTrack(track);
        } catch (e) {
          debugPrint('GroupCallService._cameraOn replaceTrack: $e');
        }
      } else {
        await _activateSlots(peer);
      }
    }
  }

  Future<void> _cameraOff(MediaStream ls) async {
    localVideoOff = true;
    notifyListeners();
    await _broadcastState();
    for (final peer in _peers.values) {
      final sender = peer.camSender;
      if (sender != null) {
        try {
          await sender.replaceTrack(null);
        } catch (e) {
          debugPrint('GroupCallService._cameraOff replaceTrack: $e');
        }
      }
    }
    for (final t in ls.getVideoTracks()) {
      await ls.removeTrack(t);
      try {
        await t.stop();
      } catch (e) {
        debugPrint('GroupCallService._cameraOff stop: $e');
      }
    }
    localStreamTick++;
    notifyListeners();
  }

  /// Share this device's screen with everyone on the call.
  ///
  /// One presenter at a time; a second is refused here and the control is
  /// disabled while [presentingPeer] is set. The capture's track is moved
  /// into [_screenStream] — one stream per call, named after us — so the id
  /// the peers learn from `state` stays the id the slot was negotiated
  /// with, share after share. Throws what the capture threw (permission,
  /// a picker dismissed) so the screen can say so; a denied consent is
  /// swallowed as "nothing happened".
  Future<void> startScreenShare({
    ScreenShareSource? source,
    ({String title, String body, String stop})? notification,
  }) async {
    if (!inCall || localScreenSharing || presentingPeer != null) return;
    if (screenSharePending) return;
    final id = _groupCallId;
    final me = _userId;
    if (id == null || me == null) return;
    screenSharePending = true;
    notifyListeners();
    try {
      await ScreenShare.prepare(
        notificationTitle: notification?.title ?? 'Sharing your screen',
        notificationBody: notification?.body ?? '',
        notificationStop: notification?.stop ?? 'Stop',
      );
      final captured = await getDisplayMediaFn(source: source);
      // iOS: the picker is up and nothing is captured yet. Wait for the
      // broadcast to actually start before anyone hears about it — a share
      // announced now would put every peer on a black stage while the user
      // reads a countdown, and leave them there for good if the sheet was
      // dismissed instead. See [ScreenShare.needsStartHandshake].
      if (ScreenShare.needsStartHandshake) {
        final started = await ScreenShare.awaitPlatformStart(
          timeout: startHandshakeTimeout,
        );
        if (!started || _groupCallId != id) {
          debugPrint('GroupCallService.startScreenShare: the broadcast never '
              'started — rolled back');
          await stopAndDisposeStream(captured);
          await ScreenShare.release();
          return;
        }
      }
      final tracks = captured.getVideoTracks();
      if (tracks.isEmpty || _groupCallId != id) {
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
      // The system's own "stop sharing" (iOS, macOS, web) ends the track.
      track.onEnded = () => unawaited(stopScreenShare());
      ScreenShare.onPlatformStop = () => unawaited(stopScreenShare());
      localScreenSharing = true;
      localScreenStreamTick++;
      notifyListeners();
      await _broadcastState();
      for (final peer in _peers.values.toList(growable: false)) {
        final sender = peer.screenSender;
        if (sender != null) {
          try {
            await sender.replaceTrack(track);
            await _retuneScreenSender(peer);
          } catch (e) {
            debugPrint('GroupCallService.startScreenShare replaceTrack: $e');
          }
        } else {
          await _activateSlots(peer);
        }
      }
    } on ScreenShareDeniedException {
      await ScreenShare.release();
    } catch (e, st) {
      debugPrint('GroupCallService.startScreenShare: $e\n$st');
      await ScreenShare.release();
      rethrow;
    } finally {
      screenSharePending = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// How long a share may sit between the picker appearing and the platform
  /// saying it is on the air (iOS only — see [ScreenShare.needsStartHandshake]).
  /// Long enough to read the sheet and sit through the countdown; a dismissed
  /// sheet is only ever known by this running out.
  @visibleForTesting
  Duration startHandshakeTimeout = const Duration(seconds: 45);

  /// End our share. The slots keep their senders, empty, for the next one.
  Future<void> stopScreenShare() async {
    if (!localScreenSharing) return;
    localScreenSharing = false;
    ScreenShare.onPlatformStop = null;
    // The drawings were about this screen; they go with it, for everyone.
    drawModel.clearAll();
    drawModel.flush();
    drawArmed.value = false;
    notifyListeners();
    // The flag first: a peer still drawing the last frame reads "not
    // sharing" before its picture freezes.
    await _broadcastState();
    for (final peer in _peers.values) {
      final sender = peer.screenSender;
      if (sender != null) {
        try {
          await sender.replaceTrack(null);
        } catch (e) {
          debugPrint('GroupCallService.stopScreenShare replaceTrack: $e');
        }
      }
    }
    final ss = _screenStream;
    if (ss != null) {
      for (final t in ss.getVideoTracks()) {
        await ss.removeTrack(t);
        try {
          await t.stop();
        } catch (e) {
          debugPrint('GroupCallService.stopScreenShare stop: $e');
        }
      }
    }
    localScreenStreamTick++;
    await ScreenShare.release();
    if (!_disposed) notifyListeners();
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

  /// Re-assert this call's audio route after CallKit activated the session.
  ///
  /// New with the native ringer, and not optional. A group call on iOS is now
  /// a real CallKit call, which means the plugin re-runs its own
  /// `configureAudioSession` at ring and at answer — with mode `.default` and
  /// no `defaultToSpeaker`, clobbering whatever [_enterCall] set. Before the
  /// ringer existed nothing else touched the session, so nothing had to be
  /// re-asserted; now the plugin is the last writer unless this runs.
  ///
  /// The 1:1 twin is `CallService.onNativeAudioSessionActivated`, which the
  /// same plugin event reaches first — and which returns early when there is
  /// no 1:1 session, which is exactly when this one applies.
  Future<void> onNativeAudioSessionActivated() async {
    if (!inCall) return;
    await applyIosCallAudioConfig(_mediaKind, speakerOn: speakerOn);
    await applyCallAudioRoute(speaker: speakerOn);
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    // Rewrite the iOS audio CATEGORY/MODE first, not just the route — mirrors
    // the 1:1 [CallService.toggleSpeaker]. `defaultToSpeaker` lives in
    // flutter_webrtc's process-wide RTCAudioSessionConfiguration singleton and
    // `setSpeakerphoneOn` only overrides the current output port without
    // clearing that bit, so a group call switched to the earpiece snapped back
    // to the loudspeaker on the next session reconfigure. And the `videoChat`
    // mode force-sets `defaultToSpeaker` on its own (see
    // [applyIosCallAudioConfig]), so for a group VIDEO call this rewrite is
    // what lets the earpiece be reached at all. No-op off iOS.
    await applyIosCallAudioConfig(_mediaKind, speakerOn: speakerOn);
    await applyCallAudioRoute(speaker: speakerOn);
    notifyListeners();
  }

  Future<void> _broadcastState() async {
    final state = _stateJson();
    for (final peer in _peers.values.toList(growable: false)) {
      await _sendTo(peer, 'state', state);
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
    final ss = _screenStream;
    if (ss != null) {
      for (final t in ss.getTracks()) {
        unawaited(t.stop().catchError((_) {}));
      }
      unawaited(ss.dispose().catchError((_) {}));
    }
    _screenStream = null;
    if (localScreenSharing) {
      localScreenSharing = false;
      unawaited(ScreenShare.release());
    }
    reopenTick.dispose();
    _draw.dispose();
    drawArmed.dispose();
    drawModel.dispose();
    super.dispose();
  }
}
