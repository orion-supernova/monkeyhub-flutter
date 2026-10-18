import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_models.dart';
import 'call_service.dart';
import 'group_call_service.dart';

/// What the call's Picture in Picture window shows: one remote picture, or
/// a name card while that picture is off.
@immutable
class CallPipSpec {
  const CallPipSpec({
    required this.title,
    this.stream,
    this.trackId,
    this.videoOff = true,
    this.screen = false,
  });

  /// Whose picture it is: the peer, the presenter, or the room.
  final String title;

  /// The stream the picture comes from, for Flutter's own PiP stage on
  /// Android. Never sent over the channel.
  final MediaStream? stream;

  /// The remote video track the native side renders (iOS reads it out of
  /// flutter_webrtc by this id). Null while there is no picture to show.
  final String? trackId;

  /// The picture is off (or not here yet): show the name card.
  final bool videoOff;

  /// The picture is a shared screen: shown whole (fit), never cropped the
  /// way a face is (fill).
  final bool screen;

  Map<String, Object?> toArgs() => {
        'title': title,
        'trackId': trackId,
        'videoOff': videoOff || trackId == null,
        'fit': screen,
      };

  /// Everything the native side draws from. Two specs with the same
  /// signature are the same window, whatever object they came from.
  String get signature =>
      '$title|$trackId|${videoOff || trackId == null}|$screen';

  @override
  bool operator ==(Object other) =>
      other is CallPipSpec &&
      other.signature == signature &&
      identical(other.stream, stream);

  @override
  int get hashCode => Object.hash(signature, stream);

  @override
  String toString() => 'CallPipSpec($signature)';
}

String? _firstVideoTrackId(MediaStream? s) {
  final v = s?.getVideoTracks();
  return (v == null || v.isEmpty) ? null : v.first.id;
}

/// The 1:1 call's window, or null when the call should have none.
///
/// A video call keeps a window armed for as long as any picture is on the
/// call, ours included: on iOS the camera may only run in the background
/// while a video-call PiP is up, so a peer who switched their own camera
/// off still gets ours. A voice call has no window (CallKit's green pill is
/// its in-call indicator). While this device presents its screen the
/// drawing board owns PiP instead (DrawPip.swift).
@visibleForTesting
CallPipSpec? pipSpecForCall({
  required CallSession? session,
  required bool localCamActive,
  required bool localScreenSharing,
  required MediaStream? remoteStream,
  required MediaStream? remoteScreenStream,
}) {
  final s = session;
  if (s == null || s.status != CallStatus.active) return null;
  if (localScreenSharing) return null;
  final peer = s.peerState;
  final screenId = peer.screenSharing ? _firstVideoTrackId(remoteScreenStream) : null;
  if (screenId != null) {
    return CallPipSpec(
      title: s.peerName,
      stream: remoteScreenStream,
      trackId: screenId,
      videoOff: false,
      screen: true,
    );
  }
  final camId = _firstVideoTrackId(remoteStream);
  final remoteVideo = camId != null && !peer.videoOff;
  if (!remoteVideo && !localCamActive) return null;
  return CallPipSpec(
    title: s.peerName,
    stream: remoteStream,
    trackId: camId,
    videoOff: !remoteVideo,
  );
}

/// The group call's window: whoever presents, else the first face with a
/// picture, else a card with the room's name — same arming rule as
/// [pipSpecForCall].
@visibleForTesting
CallPipSpec? pipSpecForGroup({
  required bool inCall,
  required bool localCamActive,
  required bool localScreenSharing,
  required Iterable<GroupPeer> peers,
  required String? roomName,
}) {
  if (!inCall || localScreenSharing) return null;
  GroupPeer? face;
  String? faceId;
  for (final p in peers) {
    final id = p.mediaState.screenSharing ? _firstVideoTrackId(p.screenStream) : null;
    if (id != null) {
      return CallPipSpec(
        title: p.name,
        stream: p.screenStream,
        trackId: id,
        videoOff: false,
        screen: true,
      );
    }
    if (face == null && !p.mediaState.videoOff) {
      final cam = _firstVideoTrackId(p.remoteStream);
      if (cam != null) {
        face = p;
        faceId = cam;
      }
    }
  }
  if (face != null) {
    return CallPipSpec(
      title: face.name,
      stream: face.remoteStream,
      trackId: faceId,
      videoOff: false,
    );
  }
  if (!localCamActive) return null;
  final name = (roomName != null && roomName.isNotEmpty)
      ? roomName
      : (peers.isEmpty ? '' : peers.first.name);
  return CallPipSpec(title: name);
}

/// Keeps the platform's Picture in Picture window in step with the call.
///
/// iOS: a video-call PiP (`CallPip.swift`) armed to start by itself as the
/// app leaves the screen, FaceTime's shape. It is also what keeps the
/// camera running for the peer: iOS interrupts every capture session of an
/// app that leaves the screen unless that app shows a video-call PiP and
/// its session opted into multitasking camera access (flutter_webrtc patch
/// W4). Without it the peer's picture of us froze the instant we went home.
///
/// Android: the activity enters PiP on its own as the user leaves
/// (`MainActivity`), and while it is in PiP [inPip] is true and the app
/// shows [spec]'s picture full-bleed instead of its screens.
///
/// Rebuilds are deduped on [CallPipSpec.signature]: both services notify on
/// every stats tick and roster fire, and the native side only hears about
/// what changes what it draws.
class CallPip {
  CallPip._();

  static final CallPip instance = CallPip._();

  static const MethodChannel _channel = MethodChannel('monkeyhub/call_pip');

  /// The window the call wants right now (null: none).
  final ValueNotifier<CallPipSpec?> spec = ValueNotifier<CallPipSpec?>(null);

  /// Android: the activity is in Picture in Picture mode right now.
  final ValueNotifier<bool> inPip = ValueNotifier<bool>(false);

  CallService? _call;
  GroupCallService? _group;
  String? _sentSignature;
  bool _handlerSet = false;

  @visibleForTesting
  bool supportedOverride = false;

  bool get _supported =>
      supportedOverride || (!kIsWeb && (Platform.isIOS || Platform.isAndroid));

  /// Starts following both call stacks. Idempotent.
  void attach({required CallService call, required GroupCallService group}) {
    if (!_supported) return;
    if (!identical(_call, call)) {
      _call?.removeListener(_sync);
      _call = call..addListener(_sync);
    }
    if (!identical(_group, group)) {
      _group?.removeListener(_sync);
      _group = group..addListener(_sync);
    }
    if (!_handlerSet) {
      _handlerSet = true;
      _channel.setMethodCallHandler(_onNative);
    }
    _sync();
  }

  Future<Object?> _onNative(MethodCall call) async {
    if (call.method == 'pipModeChanged') {
      inPip.value = call.arguments == true;
    }
    return null;
  }

  void _sync() {
    final call = _call;
    final group = _group;
    CallPipSpec? next;
    if (call != null && call.inCall) {
      next = pipSpecForCall(
        session: call.session,
        localCamActive: call.localCamActive,
        localScreenSharing: call.localScreenSharing,
        remoteStream: call.remoteStream,
        remoteScreenStream: call.remoteScreenStream,
      );
    } else if (group != null && group.inCall) {
      next = pipSpecForGroup(
        inCall: true,
        localCamActive: group.localCamActive,
        localScreenSharing: group.localScreenSharing,
        peers: group.peers.values,
        roomName: group.roomName,
      );
    }
    if (spec.value != next) spec.value = next;
    final sig = next?.signature;
    if (sig == _sentSignature) return;
    final wasArmed = _sentSignature != null;
    _sentSignature = sig;
    if (next == null) {
      _invoke('disarm', null);
    } else {
      _invoke(wasArmed ? 'update' : 'arm', next.toArgs());
    }
  }

  void _invoke(String method, Object? args) {
    unawaited(_channel.invokeMethod<void>(method, args).catchError((Object e) {
      debugPrint('CallPip.$method: $e');
    }));
  }

  @visibleForTesting
  void debugReset() {
    _call?.removeListener(_sync);
    _group?.removeListener(_sync);
    _call = null;
    _group = null;
    _sentSignature = null;
    spec.value = null;
    inPip.value = false;
  }
}
