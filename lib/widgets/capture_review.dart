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

  /// The voice note's bars, 0..1, scaled to the recording's own loudest
  /// moment: quiet speech is most of what anyone records, and drawn raw it
  /// was a flat row of dots.
  late final List<double> bars = video ? const [] : _normalized(waveform(segments, 56));

  static List<double> _normalized(List<double> raw) {
    final peak = raw.fold<double>(0, math.max);
    if (peak < 0.02) return [for (final _ in raw) 0.12];
    return [for (final v in raw) math.max(0.12, math.sqrt(v / peak))];
  }

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
      // The first few frames of a take are dark while the camera settles its
      // exposure; the still the circle rests on is a beat in.
      await _videoPlayer?.seekTo(_stillOffset(0));
    }
  }

  /// Where the resting still sits inside a part: a third of a second in, or
  /// the middle of a very short part.
  Duration _stillOffset(int index) {
    final d = segments[index].duration;
    const settle = Duration(milliseconds: 320);
    return d > settle * 2 ? settle : d ~/ 2;
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

  /// Returns whether [v] had to be clamped (the handle hit its limit).
  bool setStart(double v) {
    final clamped = v.clamp(0.0, end - minSpan);
    start = clamped;
    position = start;
    _preview(start);
    notifyListeners();
    return clamped != v;
  }

  bool setEnd(double v) {
    final clamped = v.clamp(start + minSpan, 1.0);
    end = clamped;
    position = start;
    _preview(end);
    notifyListeners();
    return clamped != v;
  }

  /// A video note shows the frame under the handle while it is dragged, the
  /// way a video editor does. One seek in flight at a time; the latest wins.
  double? _previewAt;
  bool _previewing = false;

  void _preview(double at) {
    if (!video || playing) return;
    _previewAt = at;
    if (_previewing) return;
    _previewing = true;
    () async {
      while (_previewAt != null && !_disposed) {
        final next = _previewAt!;
        _previewAt = null;
        await _seekVideo(next);
      }
      _previewing = false;
    }();
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
  /// What the finger has: -1 the start handle, 1 the end handle, 2 the
  /// playhead (a touch away from both handles scrubs), 0 nothing.
  int _grab = 0;

  /// Where on the grabbed handle the finger landed, so the handle stays
  /// under the same spot of the finger instead of jumping to its centre.
  double _grabOffset = 0;
  bool _atLimit = false;

  CaptureReviewController get _c => widget.controller;

  static const _handle = 10.0;

  /// How close to a handle (either side) a touch has to land to take it.
  static const _reach = 24.0;

  double _xOf(double f, double w) => _handle + f * (w - _handle * 2);
  double _fOf(double x, double w) => ((x - _handle) / (w - _handle * 2)).clamp(0.0, 1.0);

  void _down(double x, double w) {
    final ds = (x - _xOf(_c.start, w)).abs();
    final de = (x - _xOf(_c.end, w)).abs();
    if (ds <= _reach || de <= _reach) {
      // Overlapping reach (a tiny window): the nearer one, and the end one
      // when a finger is past the middle of them.
      _grab = ds < de || (ds == de && x < _xOf(_c.start, w)) ? -1 : 1;
      _grabOffset = x - _xOf(_grab < 0 ? _c.start : _c.end, w);
      HapticFeedback.selectionClick();
    } else {
      _grab = 2;
      unawaited(_c.seekTo(_fOf(x, w)));
    }
    _atLimit = false;
    if (_c.playing && _grab != 2) unawaited(_c.pause());
    setState(() {});
  }

  void _move(double x, double w) {
    if (_grab == 2) {
      unawaited(_c.seekTo(_fOf(x, w)));
      return;
    }
    if (_grab == 0) return;
    final f = _fOf(x - _grabOffset, w);
    final limited = _grab < 0 ? _c.setStart(f) : _c.setEnd(f);
    // A tick each time a handle runs into its stop, not every frame on it.
    if (limited && !_atLimit) HapticFeedback.selectionClick();
    _atLimit = limited;
  }

  void _up() {
    _grab = 0;
    setState(() {});
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
                    onHorizontalDragDown: (d) => _down(d.localPosition.dx, w),
                    onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, w),
                    onHorizontalDragEnd: (_) => _up(),
                    onHorizontalDragCancel: _up,
                    onTapUp: (d) {
                      _up();
                      unawaited(_c.seekTo(_fOf(d.localPosition.dx, w)));
                    },
                    child: SizedBox(
                      height: 32,
                      // In front of the frames, not behind them: the handles,
                      // the cut veil and the playhead have to sit on the
                      // filmstrip, which otherwise covered every one of them.
                      child: CustomPaint(
                        foregroundPainter: _TrackPainter(
                          bars: _c.bars,
                          frames: _c.frames.length,
                          start: _c.start,
                          end: _c.end,
                          position: _c.position,
                          playing: _c.playing,
                          ink: theme.accent,
                          handle: Colors.white,
                          grabbed: _grab == 2 ? 0 : _grab,
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
      // As many bars as fit the track, resampled from the recording's: a
      // fixed count with a minimum width ran past the end handle on a narrow
      // strip.
      const gap = 2.0;
      const want = 2.5;
      final n = math.max(1, ((w + gap) / (want + gap)).floor());
      final barW = (w - gap * (n - 1)) / n;
      for (var i = 0; i < n; i++) {
        final f = (i + 0.5) / n;
        final v = bars[math.min(bars.length - 1, (f * bars.length).floor())];
        final bh = 4 + (size.height - 12) * v;
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
