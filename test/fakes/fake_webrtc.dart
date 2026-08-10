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

/// Returned by [FakePeerConnection.addTrack]; the service discards it on the
/// attach paths (encoder tuning goes through `getSenders()`, which the fake
/// keeps empty so `configureVideoSenders`/`preferH264Codec` no-op).
class FakeRtpSender extends RTCRtpSender {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeRtpSender: ${invocation.memberName}');
}

class FakePeerConnection extends RTCPeerConnection {
  bool closed = false;

  /// Streams handed to [addTrack], in order — lets a redial test prove the
  /// old call's stream never landed on the new call's PC.
  final List<MediaStream> addedStreams = [];
  final List<MediaStreamTrack> addedTracks = [];

  @override
  RTCSignalingState? get signalingState =>
      RTCSignalingState.RTCSignalingStateStable;

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
          [Map<String, dynamic>? constraints]) async =>
      RTCSessionDescription('v=0 fake-offer', 'offer');

  @override
  Future<RTCSessionDescription> createAnswer(
          [Map<String, dynamic>? constraints]) async =>
      RTCSessionDescription('v=0 fake-answer', 'answer');

  @override
  Future<void> setLocalDescription(RTCSessionDescription description) async {}

  @override
  Future<void> setRemoteDescription(RTCSessionDescription description) async {}

  @override
  Future<RTCSessionDescription?> getLocalDescription() async => null;

  @override
  Future<RTCSessionDescription?> getRemoteDescription() async => null;

  @override
  Future<void> addCandidate(RTCIceCandidate candidate) async {}

  @override
  Future<RTCRtpSender> addTrack(MediaStreamTrack track,
      [MediaStream? stream]) async {
    if (closed) {
      throw StateError('addTrack on closed PC');
    }
    addedTracks.add(track);
    if (stream != null) addedStreams.add(stream);
    return FakeRtpSender();
  }

  @override
  Future<List<RTCRtpSender>> getSenders() async => const [];

  @override
  Future<List<RTCRtpReceiver>> getReceivers() async => const [];

  @override
  Future<List<RTCRtpTransceiver>> getTransceivers() async => const [];

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
