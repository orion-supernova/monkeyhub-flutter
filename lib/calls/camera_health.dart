import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Whether a camera that is meant to be on is actually capturing — the one
/// question the call screens' camera button could not answer.
///
/// A camera track can exist, be enabled and sit on a sender while nothing
/// comes out of it: iOS never starts (or stops) an `AVCaptureSession` while
/// the app is in the background, which is exactly where a video call
/// answered from CallKit's lock screen acquires its camera; another app or
/// the system can take the camera mid-call; an orphaned capture session can
/// steal it back. The flag and the track both said "on", the button said
/// "on", and the picture was black on both ends. Frames are the truth, so
/// this reads them.
enum CameraHealth { unknown, capturing, stalled }

/// Restarts a stalled camera gets in the foreground before the call turns
/// it off for real.
const int kMaxCameraRestarts = 2;

/// How many frames the camera has delivered so far, from a sender-scoped
/// stats report: the `media-source` count (what the capturer handed the
/// track), or else the encoder's count off `outbound-rtp`. Null when the
/// report carries neither — before the send stream exists — which reads as
/// "can't tell", never as a stall.
int? cameraFramesFrom(List<StatsReport> reports) {
  int? source;
  int? encoded;
  for (final r in reports) {
    final v = r.values;
    if (v['kind'] != 'video' && v['mediaType'] != 'video') continue;
    if (r.type == 'media-source') {
      final f = v['frames'];
      if (f is num) source = (source ?? 0) + f.toInt();
    } else if (r.type == 'outbound-rtp') {
      final f = v['framesEncoded'] ?? v['framesSent'];
      if (f is num) encoded = (encoded ?? 0) + f.toInt();
    }
  }
  return source ?? encoded;
}

/// Turns successive frame counts into a verdict. A count that did not move
/// for [stallSamples] samples in a row is a stall; one that moved is a
/// capturing camera; a count that went BACKWARDS is a new track (the
/// camera was restarted) and starts over.
class CameraStallDetector {
  CameraStallDetector({this.stallSamples = 2});

  final int stallSamples;
  int? _last;
  int _flat = 0;

  CameraHealth sample(int? frames, {int? threshold}) {
    if (frames == null) return CameraHealth.unknown;
    final last = _last;
    _last = frames;
    if (last == null || frames < last) {
      _flat = 0;
      return CameraHealth.unknown;
    }
    if (frames > last) {
      _flat = 0;
      return CameraHealth.capturing;
    }
    _flat++;
    return _flat >= (threshold ?? stallSamples)
        ? CameraHealth.stalled
        : CameraHealth.unknown;
  }

  void reset() {
    _last = null;
    _flat = 0;
  }
}

/// Watches a live camera while a call has it on: a sender-scoped stats
/// read every [interval] (cheap, and only while the camera is meant to be
/// on), plus a quick two-sample check right after the app returns to the
/// foreground, where a camera iOS stopped in the background shows up
/// within a second instead of after two full intervals.
///
/// The owning service decides what a verdict means: a stall in the
/// foreground restarts the camera, one in the background tells the peer
/// the picture is paused, a capturing camera clears both.
class CameraWatch {
  CameraWatch({
    required this.readFrames,
    required this.onVerdict,
    this.interval = const Duration(seconds: 2),
    this.resumeWindow = const Duration(milliseconds: 1200),
    bool listenToLifecycle = true,
  }) : _listenToLifecycle = listenToLifecycle;

  /// The camera's frame count right now, or null when it can't be told.
  final Future<int?> Function() readFrames;
  final void Function(CameraHealth verdict) onVerdict;
  final Duration interval;
  final Duration resumeWindow;
  final bool _listenToLifecycle;

  final CameraStallDetector _detector = CameraStallDetector();
  Timer? _timer;
  Timer? _resumeTimer;
  AppLifecycleListener? _lifecycle;
  bool _reading = false;
  int _epoch = 0;

  bool get running => _timer != null;

  void start() {
    if (_timer != null) return;
    _detector.reset();
    _timer = Timer.periodic(interval, (_) => unawaited(_probe()));
    if (_listenToLifecycle) {
      try {
        _lifecycle ??= AppLifecycleListener(onResume: resumed);
      } catch (e) {
        // No binding (a plain unit test): the periodic read still runs.
        debugPrint('CameraWatch: no lifecycle listener: $e');
      }
    }
  }

  void stop() {
    _epoch++;
    _timer?.cancel();
    _timer = null;
    _resumeTimer?.cancel();
    _resumeTimer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    _detector.reset();
  }

  /// The camera behind the track changed (restarted, swapped): the old
  /// count means nothing to the new one.
  void rebase() => _detector.reset();

  /// The app came back to the foreground. Sample now and once more after
  /// [resumeWindow]; no movement in between is a stall on the spot.
  void resumed() {
    if (_timer == null) return;
    debugPrint('[CamWatch] resumed: probing the camera');
    _detector.reset();
    final epoch = _epoch;
    unawaited(_probe().then((_) {
      if (epoch != _epoch) return;
      _resumeTimer?.cancel();
      _resumeTimer = Timer(resumeWindow, () {
        _resumeTimer = null;
        unawaited(_probe(threshold: 1));
      });
    }));
  }

  Future<void> _probe({int? threshold}) async {
    if (_reading) return;
    _reading = true;
    final epoch = _epoch;
    int? frames;
    try {
      frames = await readFrames();
    } catch (e) {
      debugPrint('[CamWatch] stats read failed: $e');
    } finally {
      _reading = false;
    }
    if (epoch != _epoch) return;
    final verdict = _detector.sample(frames, threshold: threshold);
    if (verdict != CameraHealth.unknown) onVerdict(verdict);
  }

  @visibleForTesting
  Future<void> debugProbe({int? threshold}) => _probe(threshold: threshold);
}
