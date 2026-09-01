enum CallMediaKind { audio, video }

/// User-selectable video call resolution ceiling. `auto` is today's
/// long-standing default verbatim (720p ideal/max, WebRTC's own bandwidth
/// adaptation via `MAINTAIN_FRAMERATE` degradation) — picking a higher tier
/// raises the ceiling `getCallUserMedia`/`configureVideoSenders` negotiate
/// against; it does not disable adaptation under real congestion.
enum VideoQualityTier { auto, hd1080, uhd4k }

extension VideoQualityTierWire on VideoQualityTier {
  String get wire => switch (this) {
        VideoQualityTier.auto => 'auto',
        VideoQualityTier.hd1080 => 'hd1080',
        VideoQualityTier.uhd4k => 'uhd4k',
      };

  static VideoQualityTier parse(String? s) => switch (s) {
        'hd1080' => VideoQualityTier.hd1080,
        'uhd4k' => VideoQualityTier.uhd4k,
        _ => VideoQualityTier.auto,
      };
}

extension CallMediaKindWire on CallMediaKind {
  String get wire => this == CallMediaKind.audio ? 'audio' : 'video';
  static CallMediaKind parse(String? s) =>
      s == 'video' ? CallMediaKind.video : CallMediaKind.audio;
}

/// Local UI state. The backend `calls.status` plus the local PeerConnection
/// state collapse into this — what the call_screen reads.
///
/// `switching` is used during a multi-device handoff:
///   - on the peer who's already in the call, while it tears down its
///     old PC and waits for the new device's offer (brief overlay).
///   - on the new device taking the call, while it negotiates the
///     fresh PC.
/// `handedOff` is a terminal state for the *old* device after a handoff
/// (treated like `ended` but suppresses error toasts).
enum CallStatus {
  idle,
  outgoingRinging,
  incomingRinging,
  connecting,
  active,
  switching,
  handedOff,
  ended,
  failed,
}

/// What the remote end has told us about its media tracks. Used to overlay a
/// muted-mic / video-off icon on the peer tile without re-negotiating — and,
/// since screen sharing arrived, to tell the peer's two video streams apart.
///
/// A peer can send up to two video tracks on one link: its camera and its
/// screen. Both arrive through the same `onTrack`, and neither track says
/// which it is — the stream ids are minted by the platform and are random on
/// web. So the sender names them here: [camStreamId] is the id of the stream
/// its camera rides in, [screenStreamId] the one its screen does. The
/// `state` signal carrying them is always sent BEFORE the offer that adds the
/// stream, and signals drain in order, so the receiver knows the id before
/// the track lands. [screenSharing] is the flag the UI reads; the id alone
/// would not say whether the share is currently live.
class PeerMediaState {
  const PeerMediaState({
    this.audioMuted = false,
    this.videoOff = false,
    this.screenSharing = false,
    this.camStreamId,
    this.screenStreamId,
  });
  final bool audioMuted;
  final bool videoOff;
  final bool screenSharing;
  final String? camStreamId;
  final String? screenStreamId;

  PeerMediaState copyWith({
    bool? audioMuted,
    bool? videoOff,
    bool? screenSharing,
    String? camStreamId,
    String? screenStreamId,
  }) =>
      PeerMediaState(
        audioMuted: audioMuted ?? this.audioMuted,
        videoOff: videoOff ?? this.videoOff,
        screenSharing: screenSharing ?? this.screenSharing,
        camStreamId: camStreamId ?? this.camStreamId,
        screenStreamId: screenStreamId ?? this.screenStreamId,
      );

  Map<String, dynamic> toJson() => {
        'audioMuted': audioMuted,
        'videoOff': videoOff,
        'screenSharing': screenSharing,
        if (camStreamId != null) 'camStreamId': camStreamId,
        if (screenStreamId != null) 'screenStreamId': screenStreamId,
      };

  /// Tolerant of the two-field payload older builds still send: a missing
  /// key reads as "not sharing, no ids".
  static PeerMediaState fromJson(Map<String, dynamic> j) => PeerMediaState(
        audioMuted: (j['audioMuted'] as bool?) ?? false,
        videoOff: (j['videoOff'] as bool?) ?? false,
        screenSharing: (j['screenSharing'] as bool?) ?? false,
        camStreamId: j['camStreamId'] as String?,
        screenStreamId: j['screenStreamId'] as String?,
      );
}

/// Snapshot of an active call exposed to the UI layer.
class CallSession {
  CallSession({
    required this.callId,
    required this.roomId,
    required this.peerUserId,
    required this.peerName,
    required this.mediaKind,
    required this.isCaller,
    required this.status,
    this.peerAvatarStorageId,
    this.peerState = const PeerMediaState(),
    this.localMuted = false,
    this.localVideoOff = false,
    this.localScreenSharing = false,
    this.speakerOn = true,
    this.startedAt,
    this.connectedAt,
    this.errorMessage,
    this.peerDeviceId,
    this.reconnecting = false,
  });

  final String callId;
  final String roomId;
  final String peerUserId;
  final String peerName;

  /// Convex storage id of the peer's avatar image, when known — carried in
  /// the invite payload and/or resolved via profile lookup. Lets the call
  /// screens render a real avatar instead of an initial letter.
  final String? peerAvatarStorageId;
  final CallMediaKind mediaKind;
  final bool isCaller;
  final CallStatus status;
  final PeerMediaState peerState;
  final bool localMuted;
  final bool localVideoOff;

  /// Whether THIS device is sending its screen on the call. The share's
  /// stream lives on the service (`CallService.screenStream`); this is the
  /// flag the screen reads and the `state` signal carries.
  final bool localScreenSharing;
  final bool speakerOn;
  final DateTime? startedAt;
  final DateTime? connectedAt;
  final String? errorMessage;

  /// True while an ICE restart is recovering the media path after a network
  /// change/outage. The call stays on screen with a "reconnecting" chip.
  final bool reconnecting;
  /// Which device of the peer currently holds the call. Tracked so our
  /// outgoing signals (ICE, state, etc.) can be targeted post-handoff
  /// and siblings of the peer ignore them. Updated when an incoming
  /// signal carries `fromDeviceId`.
  final String? peerDeviceId;

  CallSession copyWith({
    CallStatus? status,
    String? peerName,
    String? peerAvatarStorageId,
    PeerMediaState? peerState,
    bool? localMuted,
    bool? localVideoOff,
    bool? localScreenSharing,
    bool? speakerOn,
    DateTime? connectedAt,
    String? errorMessage,
    String? peerDeviceId,
    bool? reconnecting,
  }) {
    return CallSession(
      callId: callId,
      roomId: roomId,
      peerUserId: peerUserId,
      peerName: peerName ?? this.peerName,
      peerAvatarStorageId: peerAvatarStorageId ?? this.peerAvatarStorageId,
      mediaKind: mediaKind,
      isCaller: isCaller,
      status: status ?? this.status,
      peerState: peerState ?? this.peerState,
      localMuted: localMuted ?? this.localMuted,
      localVideoOff: localVideoOff ?? this.localVideoOff,
      localScreenSharing: localScreenSharing ?? this.localScreenSharing,
      speakerOn: speakerOn ?? this.speakerOn,
      startedAt: startedAt,
      connectedAt: connectedAt ?? this.connectedAt,
      errorMessage: errorMessage,
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
      reconnecting: reconnecting ?? this.reconnecting,
    );
  }
}
