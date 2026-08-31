import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Recording fakes for the WebRTC boundary, injected through
/// `CallService.getUserMediaFn` / `createPcFn` (and the GroupCallService
/// equivalents). They record exactly what teardown correctness depends on —
/// which tracks were stopped, which streams were disposed, what a PC saw —
/// so the cancel/redial races become deterministic assertions instead of
/// device-only repros.
///
/// Built by extending the webrtc_interface abstract classes (whose callback
/// hooks are plain nullable fields, inherited for free) with a throwing
/// [noSuchMethod] so any member a test path newly touches fails loudly
/// instead of silently misbehaving.
///
/// Since renegotiation arrived the peer connection also models the little
/// of unified-plan that the slot logic depends on: transceivers, the
/// `addTrack` reuse rule (a free same-kind transceiver that has never sent
/// is taken over rather than a new one minted), the signaling state that
/// `setLocalDescription`/`setRemoteDescription` move through, and data
/// channels. Nothing here parses SDP — the descriptions are still tokens.

class FakeMediaStreamTrack extends MediaStreamTrack {
  FakeMediaStreamTrack({required String kind, String? id, this.throwOnStop})
      : _kind = kind,
        _id = id ?? 'fake-$kind-track';

  final String _kind;
  final String _id;

  /// When set, `stop()` throws this — reproducing the Android-OEM throwing
  /// video track that used to abort the whole release loop (L7).
  final Object? throwOnStop;

  bool stopped = false;
  bool _enabled = true;

  @override
  String? get id => _id;

  @override
  String? get kind => _kind;

  @override
  String? get label => _id;

  @override
  bool get enabled => _enabled;

  @override
  set enabled(bool b) => _enabled = b;

  @override
  bool? get muted => false;

  @override
  Future<void> stop() async {
    final t = throwOnStop;
    if (t != null) throw t;
    stopped = true;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeMediaStreamTrack: ${invocation.memberName}');
}

class FakeMediaStream extends MediaStream {
  FakeMediaStream(List<FakeMediaStreamTrack> tracks, {String? id})
      : _tracks = List.of(tracks),
        super(id ?? 'fake-stream', 'local');

  final List<FakeMediaStreamTrack> _tracks;
  bool disposed = false;

  /// Every audio track stopped AND the stream disposed — the exact condition
  /// under which iOS drops the orange mic indicator.
  bool get micReleased =>
      disposed &&
      _tracks.where((t) => t.kind == 'audio').every((t) => t.stopped);

  @override
  bool? get active => !disposed;

  @override
  List<MediaStreamTrack> getTracks() => List.unmodifiable(_tracks);

  @override
  List<MediaStreamTrack> getAudioTracks() =>
      _tracks.where((t) => t.kind == 'audio').toList();

  @override
  List<MediaStreamTrack> getVideoTracks() =>
      _tracks.where((t) => t.kind == 'video').toList();

  @override
  Future<void> addTrack(MediaStreamTrack track, {bool addToNative = true}) async {
    _tracks.add(track as FakeMediaStreamTrack);
  }

  @override
  Future<void> removeTrack(MediaStreamTrack track,
      {bool removeFromNative = true}) async {
    _tracks.remove(track);
  }

  @override
  Future<void> getMediaTracks() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeMediaStream: ${invocation.memberName}');
}

/// The sending half of a transceiver. `replaceTrack` is what the slot model
/// uses to switch a camera or a screen on and off without renegotiating, so
/// every call is kept.
class FakeRtpSender extends RTCRtpSender {
  FakeRtpSender({MediaStreamTrack? track, String? id})
      : _track = track,
        _id = id ?? 'fake-sender-${_seq++}';

  static int _seq = 0;
  final String _id;
  MediaStreamTrack? _track;

  /// Whether this sender has ever carried a track — unified-plan's
  /// "has been used to send", which is what stops `addTrack` from reusing it.
  bool everSent = false;

  /// Every track handed to [replaceTrack], nulls included, in order.
  final List<MediaStreamTrack?> replaced = [];

  final RTCRtpParameters _params = RTCRtpParameters();

  @override
  MediaStreamTrack? get track => _track;

  @override
  String get senderId => _id;

  @override
  bool get ownsTrack => _track != null;

  @override
  RTCRtpParameters get parameters => _params;

  @override
  Future<bool> setParameters(RTCRtpParameters parameters) async => true;

  @override
  Future<void> replaceTrack(MediaStreamTrack? track) async {
    replaced.add(track);
    _track = track;
    if (track != null) everSent = true;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeRtpSender: ${invocation.memberName}');
}

class FakeRtpReceiver extends RTCRtpReceiver {
  FakeRtpReceiver({required String kind, String? id})
      : _track = FakeMediaStreamTrack(kind: kind, id: id ?? 'fake-recv-$kind-${_seq++}');

  static int _seq = 0;
  final FakeMediaStreamTrack _track;

  @override
  MediaStreamTrack? get track => _track;

  @override
  String get receiverId => _track.id!;

  @override
  RTCRtpParameters get parameters => RTCRtpParameters();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeRtpReceiver: ${invocation.memberName}');
}

class FakeRtpTransceiver extends RTCRtpTransceiver {
  FakeRtpTransceiver({
    required this.kind,
    MediaStreamTrack? track,
    TransceiverDirection direction = TransceiverDirection.SendRecv,
    String? mid,
  })  : _sender = FakeRtpSender(track: track),
        _receiver = FakeRtpReceiver(kind: kind),
        _direction = direction,
        _mid = mid ?? '${_seq++}' {
    if (track != null) _sender.everSent = true;
  }

  static int _seq = 0;
  final String kind;
  final FakeRtpSender _sender;
  final FakeRtpReceiver _receiver;
  final String _mid;
  TransceiverDirection _direction;
  bool stopped = false;

  @override
  FakeRtpSender get sender => _sender;

  @override
  FakeRtpReceiver get receiver => _receiver;

  @override
  String get mid => _mid;

  @override
  Future<TransceiverDirection> getDirection() async => _direction;

  @override
  Future<void> setDirection(TransceiverDirection direction) async {
    _direction = direction;
  }

  @override
  TransceiverDirection get currentDirection => _direction;

  @override
  Future<void> setCodecPreferences(List<RTCRtpCodecCapability> codecs) async {}

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeRtpTransceiver: ${invocation.memberName}');
}

/// A data channel that keeps what was sent and lets a test deliver bytes as
/// if the peer had sent them.
class FakeDataChannel extends RTCDataChannel {
  FakeDataChannel({required this.channelLabel, this.channelId});

  final String channelLabel;
  final int? channelId;
  RTCDataChannelState _state = RTCDataChannelState.RTCDataChannelOpen;

  /// Every message handed to [send], in order.
  final List<RTCDataChannelMessage> sent = [];

  /// Bytes of the binary messages in [sent] — what the wire actually carried.
  List<Uint8List> get sentBinary =>
      [for (final m in sent) if (m.isBinary) m.binary];

  /// A message from the far end.
  void emit(Uint8List bytes) =>
      onMessage?.call(RTCDataChannelMessage.fromBinary(bytes));

  /// Moves the channel through [state] and tells the listener.
  void setState(RTCDataChannelState state) {
    _state = state;
    onDataChannelState?.call(state);
  }

  @override
  RTCDataChannelState? get state => _state;

  @override
  int? get id => channelId;

  @override
  String? get label => channelLabel;

  @override
  int? get bufferedAmount => 0;

  @override
  Future<void> send(RTCDataChannelMessage message) async {
    if (_state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('send on a channel that is $_state');
    }
    sent.add(message);
  }

  @override
  Future<void> close() async {
    _state = RTCDataChannelState.RTCDataChannelClosed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeDataChannel: ${invocation.memberName}');
}

class FakePeerConnection extends RTCPeerConnection {
  bool closed = false;

  /// Streams handed to [addTrack], in order — lets a redial test prove the
  /// old call's stream never landed on the new call's PC.
  final List<MediaStream> addedStreams = [];
  final List<MediaStreamTrack> addedTracks = [];

  /// Every transceiver on the connection, in creation order — the ones
  /// [addTrack] minted or took over, the ones [addTransceiver] added, and the
  /// ones a test planted with [plantRemoteTransceiver] to stand for an m-line
  /// the far end offered.
  final List<FakeRtpTransceiver> fakeTransceivers = [];

  /// Constraints of every `createOffer`, in order, so a test can prove the
  /// initial offer asks to receive video.
  final List<Map<String, dynamic>?> offerConstraints = [];

  /// Every description set, local then remote, in order.
  final List<RTCSessionDescription> localDescriptions = [];
  final List<RTCSessionDescription> remoteDescriptions = [];

  /// Channels this side created.
  final List<FakeDataChannel> dataChannels = [];

  /// What [getStats] hands back. A test sets it to shape audio levels.
  List<StatsReport> stats = const [];

  RTCSignalingState _signaling = RTCSignalingState.RTCSignalingStateStable;

  /// Whether a remote description has been applied — the fake's stand-in
  /// for "an offer/answer exchange has completed", which the answerer-side
  /// slot logic keys off.
  bool get remoteDescriptionSet => remoteDescriptions.isNotEmpty;

  /// Plants a video/audio transceiver as if the far end's offer created it:
  /// no local track, never sent — exactly the free slot `addTrack` reuses.
  FakeRtpTransceiver plantRemoteTransceiver(String kind) {
    final t = FakeRtpTransceiver(
      kind: kind,
      direction: TransceiverDirection.RecvOnly,
    );
    fakeTransceivers.add(t);
    return t;
  }

  @override
  RTCSignalingState? get signalingState => _signaling;

  @override
  RTCPeerConnectionState? get connectionState => closed
      ? RTCPeerConnectionState.RTCPeerConnectionStateClosed
      : RTCPeerConnectionState.RTCPeerConnectionStateNew;

  @override
  RTCIceConnectionState? get iceConnectionState =>
      RTCIceConnectionState.RTCIceConnectionStateNew;

  @override
  RTCIceGatheringState? get iceGatheringState =>
      RTCIceGatheringState.RTCIceGatheringStateNew;

  @override
  Future<RTCSessionDescription> createOffer(
      [Map<String, dynamic>? constraints]) async {
    offerConstraints.add(constraints);
    return RTCSessionDescription('v=0 fake-offer', 'offer');
  }

  @override
  Future<RTCSessionDescription> createAnswer(
          [Map<String, dynamic>? constraints]) async =>
      RTCSessionDescription('v=0 fake-answer', 'answer');

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {
    localDescriptions.add(description);
    _signaling = description.type == 'offer'
        ? RTCSignalingState.RTCSignalingStateHaveLocalOffer
        : RTCSignalingState.RTCSignalingStateStable;
  }

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    remoteDescriptions.add(description);
    _signaling = description.type == 'offer'
        ? RTCSignalingState.RTCSignalingStateHaveRemoteOffer
        : RTCSignalingState.RTCSignalingStateStable;
  }

  @override
  Future<RTCSessionDescription?> getLocalDescription() async =>
      localDescriptions.isEmpty ? null : localDescriptions.last;

  @override
  Future<RTCSessionDescription?> getRemoteDescription() async =>
      remoteDescriptions.isEmpty ? null : remoteDescriptions.last;

  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {}

  /// Unified-plan `addTrack`: reuse a same-kind transceiver whose sender is
  /// empty and has never sent, else mint one.
  @override
  Future<RTCRtpSender> addTrack(MediaStreamTrack track,
      [MediaStream? stream]) async {
    if (closed) {
      throw StateError('addTrack on closed PC');
    }
    addedTracks.add(track);
    if (stream != null) addedStreams.add(stream);
    for (final t in fakeTransceivers) {
      if (t.kind == track.kind &&
          !t.stopped &&
          t.sender.track == null &&
          !t.sender.everSent) {
        t.sender._track = track;
        t.sender.everSent = true;
        if (t.currentDirection == TransceiverDirection.RecvOnly) {
          t._direction = TransceiverDirection.SendRecv;
        } else if (t.currentDirection == TransceiverDirection.Inactive) {
          t._direction = TransceiverDirection.SendOnly;
        }
        return t.sender;
      }
    }
    final t = FakeRtpTransceiver(kind: track.kind!, track: track);
    fakeTransceivers.add(t);
    return t.sender;
  }

  @override
  Future<bool> removeTrack(RTCRtpSender sender) async {
    (sender as FakeRtpSender)._track = null;
    return true;
  }

  @override
  Future<RTCRtpTransceiver> addTransceiver({
    MediaStreamTrack? track,
    RTCRtpMediaType? kind,
    RTCRtpTransceiverInit? init,
  }) async {
    final k = track?.kind ??
        (kind == RTCRtpMediaType.RTCRtpMediaTypeAudio ? 'audio' : 'video');
    final t = FakeRtpTransceiver(
      kind: k,
      track: track,
      direction: init?.direction ?? TransceiverDirection.SendRecv,
    );
    fakeTransceivers.add(t);
    return t;
  }

  @override
  Future<List<RTCRtpSender>> getSenders() async =>
      [for (final t in fakeTransceivers) t.sender];

  @override
  Future<List<RTCRtpReceiver>> getReceivers() async =>
      [for (final t in fakeTransceivers) t.receiver];

  @override
  Future<List<RTCRtpTransceiver>> getTransceivers() async =>
      List.of(fakeTransceivers);

  @override
  Future<RTCDataChannel> createDataChannel(
      String label, RTCDataChannelInit dataChannelDict) async {
    if (closed) {
      throw StateError('createDataChannel on closed PC');
    }
    final ch = FakeDataChannel(channelLabel: label, channelId: dataChannels.length);
    dataChannels.add(ch);
    return ch;
  }

  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async => stats;

  @override
  Future<void> restartIce() async {}

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<void> dispose() async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakePeerConnection: ${invocation.memberName}');
}

/// A renderer that never touches the plugin's texture channel: the video
/// views draw nothing, the screens' binding and disposal logic runs as it
/// would on a device.
class FakeVideoRenderer extends RTCVideoRenderer {
  MediaStream? _src;
  bool initialized = false;
  bool disposed = false;

  /// Every stream bound, nulls included, in order.
  final List<MediaStream?> bound = [];

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  int? get textureId => null;

  @override
  bool get renderVideo => false;

  @override
  MediaStream? get srcObject => _src;

  @override
  set srcObject(MediaStream? stream) {
    _src = stream;
    bound.add(stream);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    super.dispose();
  }
}
