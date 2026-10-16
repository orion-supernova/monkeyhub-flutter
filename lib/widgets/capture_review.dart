import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../composer/capture_compose.dart';
import '../composer/capture_recorder.dart';
import '../keyboard/focusable_tap.dart';
import '../screens/room_items.dart' show formatClockDuration;
import '../theme/app_theme.dart';
import 'capture_glyphs.dart';

/// A paused recording under review: the segments so far, the trim window over
/// them, and a player that plays only what is inside it.
///
/// Telegram's pause: the strip turns into the recording itself, a waveform
/// for a voice note or a filmstrip for a video note, with handles at both
/// ends to cut the start and the end, and a play button to hear (or, in the
/// big circle, watch) the cut before it goes.
///
/// Positions are fractions of [total], the segments laid end to end, which
/// is the timeline `composeCapture` trims on.
class CaptureReviewController extends ChangeNotifier {
  CaptureReviewController({required this.segments, required this.video})
      : total = totalDuration(segments);

  final List<CaptureSegment> segments;
  final bool video;
  final Duration total;

  /// The trim window, 0..1 of [total].
  double start = 0;
  double end = 1;

  /// The playhead, 0..1 of [total].
  double position = 0;
  bool playing = false;

  /// The video note's frames, once decoded; empty until then (and for voice).
  List<Uint8List> frames = const [];

  /// The voice note's bars, 0..1.
  late final List<double> bars = video ? const [] : waveform(segments, 48);

  AudioPlayer? _audio;
  VideoPlayerController? _videoPlayer;
  int _videoIndex = 0;
  StreamSubscription<Duration>? _positionSub;
  Timer? _videoTick;
  bool _disposed = false;

  /// The smallest window the handles can be squeezed to.
  double get minSpan => total.inMilliseconds <= 0 ? 1 : math.min(1.0, 1000 / total.inMilliseconds);

  Duration get trimStart => total * start;
  Duration get trimEnd => total * end;
  Duration get trimmedLength => total * (end - start);

  /// Whether the handles moved off the ends at all.
  bool get trimmed => start > 0.001 || end < 0.999;

  /// The video player on screen for a video note's review, or null.
  VideoPlayerController? get videoPlayer => _videoPlayer;

  Future<void> load() async {
    if (video) {
      try {
        final f = await filmstrip(segments, count: 10, height: 64);
        if (_disposed) return;
        frames = f;
        notifyListeners();
      } catch (e) {
        debugPrint('CaptureReview.filmstrip: $e');
      }
      await _openVideo(0);
    }
  }

  // ─────────────────────────────── timeline ───────────────────────────────

  /// Which segment [at] (0..1 of the whole) falls in, and where inside it.
  ({int index, Duration offset}) _locate(double at) {
    var remaining = total * at.clamp(0.0, 1.0);
    for (var i = 0; i < segments.length; i++) {
      final d = segments[i].duration;
      if (remaining < d || i == segments.length - 1) {
        return (index: i, offset: remaining < d ? remaining : d);
      }
      remaining -= d;
    }
    return (index: 0, offset: Duration.zero);
  }

  double _fractionOf(int index, Duration offset) {
    if (total.inMicroseconds <= 0) return 0;
    var before = Duration.zero;
    for (var i = 0; i < index && i < segments.length; i++) {
      before += segments[i].duration;
    }
    return ((before + offset).inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
  }

  // ──────────────────────────────── trim ──────────────────────────────────

  void setStart(double v) {
    start = v.clamp(0.0, end - minSpan);
    if (position < start) position = start;
    notifyListeners();
  }

  void setEnd(double v) {
    end = v.clamp(start + minSpan, 1.0);
    if (position > end) position = start;
    notifyListeners();
  }

  // ────────────────────────────── playback ────────────────────────────────

  Future<void> toggle() => playing ? pause() : play();

  Future<void> play() async {
    if (position >= end - 0.005 || position < start) position = start;
    playing = true;
    notifyListeners();
    if (video) {
      await _seekVideo(position);
      await _videoPlayer?.play();
      _videoTick?.cancel();
      _videoTick = Timer.periodic(const Duration(milliseconds: 33), (_) => _onVideoTick());
    } else {
      final a = _audio ??= AudioPlayer();
      try {
        if (a.audioSource == null) {
          await a.setAudioSources([for (final s in segments) AudioSource.file(s.path)]);
        }
        final at = _locate(position);
        await a.seek(at.offset, index: at.index);
        _positionSub ??= a.positionStream.listen((_) => _onAudioTick());
        unawaited(a.play());
      } catch (e) {
        debugPrint('CaptureReview.play: $e');
        playing = false;
        notifyListeners();
      }
    }
  }

  Future<void> pause() async {
    playing = false;
    _videoTick?.cancel();
    notifyListeners();
    await _audio?.pause();
    await _videoPlayer?.pause();
  }

  /// Jumps the playhead (a tap on the track).
  Future<void> seekTo(double at) async {
    position = at.clamp(start, end);
    notifyListeners();
    if (video) {
      await _seekVideo(position);
    } else if (_audio?.audioSource != null) {
      final l = _locate(position);
      await _audio!.seek(l.offset, index: l.index);
    }
  }

  void _onAudioTick() {
    final a = _audio;
    if (a == null || !playing || _disposed) return;
    position = _fractionOf(a.currentIndex ?? 0, a.position);
    if (position >= end || a.processingState == ProcessingState.completed) {
      position = start;
      unawaited(pause());
      return;
    }
    notifyListeners();
  }

  Future<void> _openVideo(int index) async {
    if (_disposed || index >= segments.length) return;
    final old = _videoPlayer;
    final c = VideoPlayerController.file(File(segments[index].path));
    try {
      await c.initialize();
    } catch (e) {
      debugPrint('CaptureReview.video: $e');
      await c.dispose();
      return;
    }
    if (_disposed) {
      await c.dispose();
      return;
    }
    _videoPlayer = c;
    _videoIndex = index;
    notifyListeners();
    await old?.dispose();
  }

  Future<void> _seekVideo(double at) async {
    final l = _locate(at);
    if (l.index != _videoIndex || _videoPlayer == null) await _openVideo(l.index);
    await _videoPlayer?.seekTo(l.offset);
  }

  void _onVideoTick() {
    final c = _videoPlayer;
    if (c == null || !playing || _disposed) return;
    final v = c.value;
    position = _fractionOf(_videoIndex, v.position);
    final segmentDone = v.isInitialized && v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 40);
    if (position >= end) {
      position = start;
      unawaited(pause().then((_) => _seekVideo(start)));
      return;
    }
    if (segmentDone && _videoIndex < segments.length - 1) {
      unawaited(_openVideo(_videoIndex + 1).then((_) => _videoPlayer?.play()));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _videoTick?.cancel();
    unawaited(_positionSub?.cancel());
    unawaited(_audio?.dispose());
    unawaited(_videoPlayer?.dispose());
    super.dispose();
  }
}

/// The strip a paused recording turns into: play, the recording drawn as
/// bars (voice) or frames (video), trim handles at both ends with the cut
/// parts dimmed, a playhead, and the length of what will be sent.
///
/// Dragging a handle ticks as it grabs and again when it hits the shortest
/// window it allows; a tap on the track moves the playhead there.
class CaptureReviewStrip extends StatefulWidget {
  const CaptureReviewStrip({
    super.key,
    required this.controller,
    required this.theme,
    required this.playLabel,
    required this.pauseLabel,
  });

  final CaptureReviewController controller;
  final AppTheme theme;
  final String playLabel;
  final String pauseLabel;

  @override
  State<CaptureReviewStrip> createState() => _CaptureReviewStripState();
}

class _CaptureReviewStripState extends State<CaptureReviewStrip> {
  /// Which handle the finger has: -1 start, 1 end, 0 none.
  int _grab = 0;
  bool _atLimit = false;

  CaptureReviewController get _c => widget.controller;

  static const _handle = 10.0;

  void _drag(double dx, double width) {
    if (_grab == 0 || width <= 0) return;
    final delta = dx / width;
    final before = _grab < 0 ? _c.start : _c.end;
    if (_grab < 0) {
      _c.setStart(_c.start + delta);
    } else {
      _c.setEnd(_c.end + delta);
    }
    final after = _grab < 0 ? _c.start : _c.end;
    final limit = (after - before).abs() < delta.abs() * 0.5;
    if (limit && !_atLimit) HapticFeedback.selectionClick();
    _atLimit = limit;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Container(
        height: 40,
        padding: const EdgeInsets.only(left: 4, right: 12),
        decoration: ShapeDecoration(
          color: theme.accent.withValues(alpha: 0.16),
          shape: const StadiumBorder(),
        ),
        child: Row(
          children: [
            FocusableTap(
              onTap: () => unawaited(_c.toggle()),
              semanticLabel: _c.playing ? widget.pauseLabel : widget.playLabel,
              shape: FocusRingShape.circle,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  unawaited(_c.toggle());
                },
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
                  child: _c.playing
                      ? PauseGlyph(color: theme.accentInk, size: 16)
                      : _PlayTriangle(color: theme.accentInk),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (d) {
                      final x = d.localPosition.dx / w;
                      _grab = (x - _c.start).abs() <= (x - _c.end).abs() ? -1 : 1;
                      _atLimit = false;
                      HapticFeedback.selectionClick();
                      if (_c.playing) unawaited(_c.pause());
                    },
                    onHorizontalDragUpdate: (d) => _drag(d.delta.dx, w),
                    onHorizontalDragEnd: (_) {
                      _grab = 0;
                      unawaited(_c.seekTo(_c.start));
                    },
                    onTapUp: (d) => unawaited(_c.seekTo(d.localPosition.dx / w)),
                    child: SizedBox(
                      height: 32,
                      child: CustomPaint(
                        painter: _TrackPainter(
                          bars: _c.bars,
                          frames: _c.frames.length,
                          start: _c.start,
                          end: _c.end,
                          position: _c.position,
                          playing: _c.playing,
                          ink: theme.accent,
                          handle: Colors.white,
                          grabbed: _grab,
                        ),
                        child: _c.video && _c.frames.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(horizontal: _handle),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Row(
                                    children: [
                                      for (final f in _c.frames)
                                        Expanded(
                                          child: Image.memory(f, fit: BoxFit.cover, height: 32, gaplessPlayback: true),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatClockDuration(_c.trimmedLength),
              style: theme.body.copyWith(
                fontSize: 14,
                color: theme.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayTriangle extends StatelessWidget {
  const _PlayTriangle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(14, 14),
        painter: _PlayPainter(color),
      );
}

class _PlayPainter extends CustomPainter {
  const _PlayPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.22, h * 0.1)
      ..lineTo(w * 0.92, h * 0.5)
      ..lineTo(w * 0.22, h * 0.9)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_PlayPainter old) => old.color != color;
}

/// The track under the frames, or the bars themselves for a voice note: the
/// cut parts dimmed, white handles at the window's ends (the one in the
/// finger's grip a touch wider), and the playhead.
class _TrackPainter extends CustomPainter {
  const _TrackPainter({
    required this.bars,
    required this.frames,
    required this.start,
    required this.end,
    required this.position,
    required this.playing,
    required this.ink,
    required this.handle,
    required this.grabbed,
  });

  final List<double> bars;
  final int frames;
  final double start;
  final double end;
  final double position;
  final bool playing;
  final Color ink;
  final Color handle;
  final int grabbed;

  static const _h = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _h * 2;
    if (w <= 0) return;
    double x(double f) => _h + f * w;

    if (bars.isNotEmpty) {
      final gap = 2.0;
      final barW = math.max(1.5, (w - gap * (bars.length - 1)) / bars.length);
      for (var i = 0; i < bars.length; i++) {
        final f = (i + 0.5) / bars.length;
        final bh = 4 + (size.height - 12) * bars[i];
        final inside = f >= start && f <= end;
        final played = f <= position && inside;
        final paint = Paint()
          ..color = inside ? (played ? ink : ink.withValues(alpha: 0.55)) : ink.withValues(alpha: 0.18);
        final bx = _h + i * (barW + gap);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, (size.height - bh) / 2, barW, bh),
            Radius.circular(barW / 2),
          ),
          paint,
        );
      }
    }

    // The cut parts, veiled (over the frames, for a video note).
    final veil = Paint()..color = const Color(0x99000000);
    if (frames > 0) {
      if (start > 0) canvas.drawRect(Rect.fromLTRB(_h, 0, x(start), size.height), veil);
      if (end < 1) canvas.drawRect(Rect.fromLTRB(x(end), 0, size.width - _h, size.height), veil);
    }

    // The window's frame and its two handles.
    final frame = Paint()
      ..color = handle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final window = Rect.fromLTRB(x(start), 1, x(end), size.height - 1);
    canvas.drawRRect(RRect.fromRectAndRadius(window, const Radius.circular(6)), frame);
    void grip(double cx, bool held) {
      final hw = held ? 9.0 : 7.0;
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, size.height / 2), width: hw, height: size.height),
        const Radius.circular(4),
      );
      canvas.drawRRect(r, Paint()..color = handle);
      canvas.drawLine(
        Offset(cx, size.height * 0.35),
        Offset(cx, size.height * 0.65),
        Paint()
          ..color = const Color(0x66000000)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    grip(x(start), grabbed < 0);
    grip(x(end), grabbed > 0);

    // The playhead, only once there is something to follow.
    if (playing || (position > start + 0.002 && position < end)) {
      final px = x(position);
      canvas.drawLine(
        Offset(px, 3),
        Offset(px, size.height - 3),
        Paint()
          ..color = handle
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.bars != bars ||
      old.frames != frames ||
      old.start != start ||
      old.end != end ||
      old.position != position ||
      old.playing != playing ||
      old.ink != ink ||
      old.grabbed != grabbed;
}
