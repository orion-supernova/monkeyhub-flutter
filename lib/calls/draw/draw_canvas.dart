import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../theme/motion.dart';
import '../../widgets/dust/dust_kit.dart';
import 'draw_model.dart';

/// Where a video of [video] pixels lands inside [box] under `contain`.
///
/// This is the same arithmetic `RTCVideoView` does for its texture, spelled
/// out so the drawing layer can sit on exactly the pixels the frame covers:
/// a stroke is a fraction of the frame, and a fraction of the letterbox
/// would land on the wrong thing for anyone whose window is a different
/// shape from the presenter's screen. An unknown video size (0×0, before
/// the first frame) takes the whole box.
Rect fittedVideoRect(Size video, Size box) {
  if (video.width <= 0 || video.height <= 0 || box.isEmpty) {
    return Offset.zero & box;
  }
  final dest = applyBoxFit(BoxFit.contain, video, box).destination;
  return Alignment.center.inscribe(dest, Offset.zero & box);
}

/// A shared screen with the drawing over it.
///
/// The renderer is a `ValueNotifier` of the frame's size and rotation, so a
/// presenter turning their phone re-fits the canvas on the same frame the
/// video re-fits itself.
class ShareSurface extends StatelessWidget {
  const ShareSurface({
    super.key,
    required this.renderer,
    required this.model,
    required this.armed,
    required this.inkColor,
    this.mirror = false,
  });

  final RTCVideoRenderer renderer;
  final DrawModel model;

  /// Whether this viewer's finger draws. Off, the surface takes no hits.
  final bool armed;

  /// This viewer's own stroke colour.
  final Color inkColor;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ValueListenableBuilder<RTCVideoValue>(
        valueListenable: renderer,
        builder: (context, v, _) {
          final rotated = v.rotation == 90 || v.rotation == 270;
          final video = rotated ? Size(v.height, v.width) : Size(v.width, v.height);
          final rect = fittedVideoRect(video, constraints.biggest);
          return Stack(
            fit: StackFit.expand,
            children: [
              RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                mirror: mirror,
              ),
              Positioned.fromRect(
                rect: rect,
                child: DrawCanvas(
                  model: model,
                  armed: armed,
                  inkColor: inkColor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The strokes, the finger that draws them, and the dust they become.
///
/// Fills its box, which must be the frame the strokes are fractions of. Three
/// layers, cheapest first: a stroke painter that repaints only when the model
/// says so (a new point, a stroke crossing into its dissolve); a dust painter
/// on its own ticker, alive only while motes are; and a `Listener` that is
/// there only while [armed], so an unarmed canvas takes no hits at all and
/// the video's own gestures stay its own.
///
/// Under calm motion there is no dust and no ticker: a stroke's time comes
/// and it fades on the model's own clock.
class DrawCanvas extends StatefulWidget {
  const DrawCanvas({
    super.key,
    required this.model,
    required this.armed,
    required this.inkColor,
    this.strokeWidth = 0.008,
  });

  final DrawModel model;
  final bool armed;
  final Color inkColor;

  /// Stroke width as a fraction of the frame width.
  final double strokeWidth;

  @override
  State<DrawCanvas> createState() => _DrawCanvasState();
}

class _DrawCanvasState extends State<DrawCanvas>
    with TickerProviderStateMixin {
  /// Motes per stroke, and in total. A scribble across the whole screen
  /// is a few thousand points; sampling every few pixels keeps it a haze
  /// rather than a second copy of the line.
  static const int motesPerStroke = 600;
  static const int moteCapacity = 4000;
  static const double moteSpacing = 4;

  DustMotes? _motes;
  Ticker? _ticker;
  Duration? _lastTick;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  /// Strokes already turned to dust, by key, so the model notifying twice
  /// during one dissolve does not spawn twice.
  final Set<String> _dusted = {};

  Size _size = Size.zero;
  double _dpr = 2;
  bool _calm = false;
  int? _pointer;
  int? _stroke;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_onModel);
  }

  @override
  void didUpdateWidget(DrawCanvas old) {
    super.didUpdateWidget(old);
    if (!identical(old.model, widget.model)) {
      old.model.removeListener(_onModel);
      widget.model.addListener(_onModel);
      _dusted.clear();
      _motes?.clear();
    }
  }

  @override
  void dispose() {
    widget.model.removeListener(_onModel);
    _ticker?.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ dust

  void _onModel() {
    if (!mounted || _calm) return;
    final model = widget.model;
    final now = model.clock();
    final present = <String>{};
    var spawned = false;
    for (final s in model.strokes) {
      present.add(s.key);
      if (_dusted.contains(s.key)) continue;
      if (model.dissolveT(s, now) <= 0) continue;
      _dusted.add(s.key);
      _spawnDust(s);
      spawned = true;
    }
    _dusted.retainWhere(present.contains);
    if (spawned) _ensureTicker();
  }

  /// Samples the stroke every [moteSpacing] logical px and throws a mote
  /// off each sample along the line's normal — a line blowing away sideways,
  /// not a line evaporating in place.
  void _spawnDust(DrawStroke s) {
    if (_size.isEmpty || s.length == 0) return;
    final motes = _motes ??= DustMotes(
      capacity: moteCapacity,
      dpr: _dpr,
      seed: s.key.hashCode,
    );
    final w = _size.width;
    final h = _size.height;
    final rand = math.Random(s.key.hashCode);
    final argb = s.color.toARGB32();

    // Total length first, so a long scribble widens its spacing rather
    // than blowing the per-stroke budget on its first quarter.
    var total = 0.0;
    for (var i = 1; i < s.length; i++) {
      final dx = (s.x(i) - s.x(i - 1)) * w;
      final dy = (s.y(i) - s.y(i - 1)) * h;
      total += math.sqrt(dx * dx + dy * dy);
    }
    final spacing = math.max(moteSpacing, total / motesPerStroke);

    void emit(double px, double py, double nx, double ny) {
      final side = rand.nextBool() ? 1.0 : -1.0;
      final speed = 30 + rand.nextDouble() * 50;
      final jx = (rand.nextDouble() - 0.5) * 30;
      final jy = (rand.nextDouble() - 0.5) * 30;
      motes.spawn(
        x: px,
        y: py,
        vx: nx * side * speed + jx,
        vy: ny * side * speed + jy,
        life: 0.45 + rand.nextDouble() * 0.2,
        size: 1.1 + rand.nextDouble() * 1.1,
        argb: argb,
        peak: 0.7 + rand.nextDouble() * 0.3,
      );
    }

    if (s.length == 1) {
      emit(s.x(0) * w, s.y(0) * h, 0, -1);
      return;
    }
    var carry = 0.0;
    for (var i = 1; i < s.length; i++) {
      final ax = s.x(i - 1) * w;
      final ay = s.y(i - 1) * h;
      final bx = s.x(i) * w;
      final by = s.y(i) * h;
      final dx = bx - ax;
      final dy = by - ay;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 0.001) continue;
      final nx = -dy / len;
      final ny = dx / len;
      var d = carry;
      while (d <= len) {
        final t = d / len;
        emit(ax + dx * t, ay + dy * t, nx, ny);
        d += spacing;
      }
      carry = d - len;
    }
  }

  void _ensureTicker() {
    if (_calm) return;
    final t = _ticker ??= createTicker(_onTick);
    if (!t.isActive) {
      _lastTick = null;
      t.start();
    }
  }

  void _onTick(Duration elapsed) {
    final motes = _motes;
    if (motes == null) {
      _ticker?.stop();
      return;
    }
    final dt = dustFrameDt(_lastTick, elapsed);
    _lastTick = elapsed;
    motes.step(dt, drag: 2.5);
    _frame.value++;
    if (motes.living == 0) {
      _ticker?.stop();
      _lastTick = null;
    }
  }

  // ----------------------------------------------------------------- input

  Offset _norm(Offset local) => Offset(
        _size.width <= 0 ? 0 : (local.dx / _size.width).clamp(0.0, 1.0),
        _size.height <= 0 ? 0 : (local.dy / _size.height).clamp(0.0, 1.0),
      );

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _stroke = widget.model.beginLocal(
      _norm(e.localPosition),
      color: widget.inkColor,
      width: widget.strokeWidth,
    );
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final id = _stroke;
    if (id == null) return;
    widget.model.appendLocal(id, _norm(e.localPosition));
  }

  void _up(int pointer) {
    if (pointer != _pointer) return;
    final id = _stroke;
    _pointer = null;
    _stroke = null;
    if (id != null) widget.model.endLocal(id);
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    _dpr = MediaQuery.devicePixelRatioOf(context);
    if (motion.calm != _calm) {
      _calm = motion.calm;
      if (_calm) {
        _ticker?.dispose();
        _ticker = null;
        _lastTick = null;
        _motes = null;
        _dusted.clear();
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final paint = RepaintBoundary(
          child: CustomPaint(
            painter: _StrokePainter(model: widget.model),
            foregroundPainter: _calm
                ? null
                : _DustPainter(motes: () => _motes, dpr: _dpr, repaint: _frame),
            child: const SizedBox.expand(),
          ),
        );
        if (!widget.armed) return IgnorePointer(child: paint);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: (e) => _up(e.pointer),
          onPointerCancel: (e) => _up(e.pointer),
          child: paint,
        );
      },
    );
  }

  /// Whether the dust ticker is running. For tests.
  @visibleForTesting
  bool get debugTicking => _ticker?.isActive ?? false;

  /// Living motes. For tests.
  @visibleForTesting
  int get debugMotes => _motes?.living ?? 0;
}

/// Every live stroke, sharp or fading. Repaints on the model.
class _StrokePainter extends CustomPainter {
  _StrokePainter({required this.model}) : super(repaint: model);

  final DrawModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final strokes = model.strokes;
    if (strokes.isEmpty) return;
    final now = model.clock();
    for (final s in strokes) {
      if (s.length == 0) continue;
      final t = model.dissolveT(s, now);
      // The line is gone well before the dust is: the last of it has to
      // read as dust already in the air, not a line that is also fading.
      final opacity = 1 - Curves.easeIn.transform((t / 0.4).clamp(0.0, 1.0));
      if (opacity <= 0.01) continue;
      final path = _pathFor(s, size);
      final w = math.max(1.0, s.width * size.width);
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color.withValues(alpha: 0.35 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  /// The stroke's path in this frame's pixels, rebuilt only when a point
  /// arrived or the frame changed shape. Midpoints between quadratics, so
  /// a fast finger leaves a curve rather than a polyline.
  Path _pathFor(DrawStroke s, Size size) {
    final cached = s.path;
    if (cached != null &&
        s.pathLength == s.length &&
        s.pathWidth == size.width &&
        s.pathHeight == size.height) {
      return cached;
    }
    final w = size.width;
    final h = size.height;
    final path = Path();
    final n = s.length;
    path.moveTo(s.x(0) * w, s.y(0) * h);
    if (n == 1) {
      path.lineTo(s.x(0) * w, s.y(0) * h);
    } else if (n == 2) {
      path.lineTo(s.x(1) * w, s.y(1) * h);
    } else {
      for (var i = 1; i < n - 1; i++) {
        final cx = s.x(i) * w;
        final cy = s.y(i) * h;
        final mx = (cx + s.x(i + 1) * w) / 2;
        final my = (cy + s.y(i + 1) * h) / 2;
        path.quadraticBezierTo(cx, cy, mx, my);
      }
      path.lineTo(s.x(n - 1) * w, s.y(n - 1) * h);
    }
    s.path = path;
    s.pathLength = n;
    s.pathWidth = w;
    s.pathHeight = h;
    return path;
  }

  @override
  bool shouldRepaint(_StrokePainter old) => !identical(old.model, model);

  @override
  bool hitTest(Offset position) => false;
}

/// The dust, on its own layer and its own ticker.
class _DustPainter extends CustomPainter {
  _DustPainter({
    required this.motes,
    required this.dpr,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final DustMotes? Function() motes;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final m = motes();
    if (m == null || m.alive == 0) return;
    DustAtlas.draw(
      canvas,
      sprite: DustSprite.forDpr(dpr),
      transforms: m.transforms,
      spriteRects: m.spriteRects,
      colors: m.colors,
      alive: m.alive,
      points: m.points,
    );
  }

  @override
  bool shouldRepaint(_DustPainter old) => old.dpr != dpr;

  @override
  bool hitTest(Offset position) => false;
}
