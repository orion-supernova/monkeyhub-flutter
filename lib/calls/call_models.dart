enum CallMediaKind { audio, video }

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
/// muted-mic / video-off icon on the peer tile without re-negotiating.
class PeerMediaState {
  const PeerMediaState({this.audioMuted = false, this.videoOff = false});
  final bool audioMuted;
  final bool videoOff;

  PeerMediaState copyWith({bool? audioMuted, bool? videoOff}) =>
      PeerMediaState(
        audioMuted: audioMuted ?? this.audioMuted,
        videoOff: videoOff ?? this.videoOff,
      );

  Map<String, dynamic> toJson() => {
        'audioMuted': audioMuted,
        'videoOff': videoOff,
      };

  static PeerMediaState fromJson(Map<String, dynamic> j) => PeerMediaState(
        audioMuted: (j['audioMuted'] as bool?) ?? false,
        videoOff: (j['videoOff'] as bool?) ?? false,
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
      speakerOn: speakerOn ?? this.speakerOn,
      startedAt: startedAt,
      connectedAt: connectedAt ?? this.connectedAt,
      errorMessage: errorMessage,
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
      reconnecting: reconnecting ?? this.reconnecting,
    );
  }
}
