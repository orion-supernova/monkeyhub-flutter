enum CallMediaKind { audio, video }

extension CallMediaKindWire on CallMediaKind {
  String get wire => this == CallMediaKind.audio ? 'audio' : 'video';
  static CallMediaKind parse(String? s) =>
      s == 'video' ? CallMediaKind.video : CallMediaKind.audio;
}

/// Local UI state. The backend `calls.status` plus the local PeerConnection
/// state collapse into this — what the call_screen reads.
enum CallStatus {
  idle,
  outgoingRinging,
  incomingRinging,
  connecting,
  active,
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
    this.peerState = const PeerMediaState(),
    this.localMuted = false,
    this.localVideoOff = false,
    this.speakerOn = true,
    this.startedAt,
    this.connectedAt,
    this.errorMessage,
  });

  final String callId;
  final String roomId;
  final String peerUserId;
  final String peerName;
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

  CallSession copyWith({
    CallStatus? status,
    PeerMediaState? peerState,
    bool? localMuted,
    bool? localVideoOff,
    bool? speakerOn,
    DateTime? connectedAt,
    String? errorMessage,
  }) {
    return CallSession(
      callId: callId,
      roomId: roomId,
      peerUserId: peerUserId,
      peerName: peerName,
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
    );
  }
}
