import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'dust/dust_kit.dart';

/// Telegram's disintegration: the child turns to dust and blows away.
///
/// Set [active] and the child's last picture is taken (its own repaint
/// boundary, rastered at the screen's pixel ratio), the child itself is
/// replaced by an empty box of its size, and the picture is cut into a grid
/// of tiny blocks — one particle per block, a few thousand at most. A wave
/// crosses the picture along [sweep]; each block lets go as the wave reaches
/// it (a little early or late, so the front is ragged rather than ruled),
/// shrinks to a mote of its own colour, and drifts back against the wave and
/// upward on a little turbulence, fading as it goes. Blocks the wave has not
/// reached yet still tile the picture exactly, so the unreached part reads
/// as the child itself to the last.
///
/// The child may move while it burns — the video note's focus flies its
/// circle home as it goes — and the blocks still waiting ride along with it,
/// scaled to its current size, while the ones already let go stay where they
/// were released: the dust is left behind in the air, as on Telegram.
///
/// Drawing: the motes are painted in the ROOT overlay, above the composer,
/// the app bar and the bubble's own clip, because dust that lifts out of a
/// bubble must not be cut off at the edge of the transcript's scroll view or
/// the bubble's rounded rect. The painter reads where the child's box is on
/// every frame (after layout, so in step with any flight or scroll) and
/// places the field there. Where there is no overlay (a bare test harness)
/// it paints in place, unclipped, over the box. Either way: one
/// `drawRawAtlas` over the capture per frame through [DustAtlas], the
/// positions a closed form of the time — nothing integrated, so a dropped
/// frame lands where a smooth one would have — into flat buffers sized once.
///
/// Fully transparent blocks are dropped: [shape] culls them up front
/// (a circle's corners), and the capture's alpha, read back off the GPU,
/// culls the rest a frame or two in (the gaps of a waveform, round text).
///
/// Reduced motion ([MediaQuery.disableAnimationsOf]): a short cross-fade to
/// [beneath], and no capture at all.
class DustDissolve extends StatefulWidget {
  const DustDissolve({
    super.key,
    required this.child,
    this.active = false,
    this.onDone,
    this.beneath,
    this.shape,
    this.sweep = const Offset(1, 0),
    this.duration = defaultDuration,
    this.seed = 0,
  });

  final Widget child;

  /// False to true starts the dissolve; true to false puts the child back.
  final bool active;

  /// The dust has settled (or the fade has finished). The child stays hidden
  /// until [active] goes false again.
  final VoidCallback? onDone;

  /// What the dissolve uncovers, laid under the child at the child's size
  /// and faded in as the dust lifts. Built only while dissolving.
  final Widget? beneath;

  /// The child's outline, when it is not a full rectangle: blocks outside it
  /// are never made. `CircleBorder()` for a video note.
  final ShapeBorder? shape;

  /// The way the wave travels across the picture. The dust drifts the other
  /// way.
  final Offset sweep;

  final Duration duration;

  /// Seeds the per-block randomness, so one message always comes apart the
  /// same way.
  final int seed;

  static const Duration defaultDuration = Duration(milliseconds: 1100);

  /// Blocks per picture, at most. A bigger child gets bigger blocks rather
  /// than more of them — a 360pt circle costs what a voice pill does.
  static const int maxParticles = 7000;

  /// The quick fade that stands in under reduced motion.
  static const Duration calmDuration = Duration(milliseconds: 200);

  @override
  State<DustDissolve> createState() => _DustDissolveState();
}

enum _Phase { idle, pending, dust, fade, done }

class _DustDissolveState extends State<DustDissolve>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this);

  /// The beneath layer: in under the first half of the dust.
  late final Animation<double> _reveal = CurvedAnimation(
    parent: _clock,
    curve: const Interval(0.08, 0.6, curve: Curves.easeOut),
  );

  final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'dust:boundary');
  final GlobalKey _boxKey = GlobalKey(debugLabel: 'dust:box');
  final GlobalKey _canvasKey = GlobalKey(debugLabel: 'dust:canvas');
  final OverlayPortalController _portal = OverlayPortalController();

  _Phase _phase = _Phase.idle;
  _DustField? _field;
  Size? _size;

  /// Bumped on every start and reset, so a late post-frame callback or
  /// readback for an earlier run lands on nothing.
  int _run = 0;

  @override
  void didUpdateWidget(covariant DustDissolve old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) _reset();
  }

  @override
  void dispose() {
    _run++;
    _clock.dispose();
    _field?.image.dispose();
    _field = null;
    super.dispose();
  }

  void _reset() {
    _run++;
    _clock.stop();
    _clock.value = 0;
    // Called from didUpdateWidget, inside a build: the portal may not be
    // hidden here. Its builder already draws nothing outside the dust phase,
    // so it comes down after the frame.
    final run = _run;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted && run == _run && _portal.isShowing) _portal.hide();
    });
    _releaseField();
    _phase = _Phase.idle;
    _size = null;
  }

  /// Frees the capture after the frame that last painted it.
  void _releaseField() {
    final field = _field;
    _field = null;
    if (field == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      field.image.dispose();
    });
  }

  /// Called from build: the frame being built is the one that paints the
  /// child for the last time, so the capture waits for its end.
  void _start(BuildContext context) {
    _phase = _Phase.pending;
    final calm = MediaQuery.disableAnimationsOf(context);
    final run = ++_run;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || run != _run) return;
      if (calm) {
        _fade();
      } else {
        _capture(run);
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _fade() {
    setState(() => _phase = _Phase.fade);
    _clock.duration = DustDissolve.calmDuration;
    final run = _run;
    _clock.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted && run == _run) _finish();
    });
  }

  void _capture(int run) {
    final boundary = _boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.attached ||
        !boundary.hasSize ||
        boundary.size.isEmpty) {
      _fade();
      return;
    }
    final size = boundary.size;
    final dpr = View.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final pixelRatio = math.min(dpr, 3.0);
    ui.Image image;
    try {
      image = boundary.toImageSync(pixelRatio: pixelRatio);
    } catch (e) {
      debugPrint('DustDissolve: capture failed: $e');
      _fade();
      return;
    }
    final field = _DustField(
      image: image,
      pixelRatio: pixelRatio,
      size: size,
      outline: widget.shape?.getOuterPath(Offset.zero & size),
      sweep: widget.sweep,
      seed: widget.seed,
      seconds: widget.duration.inMicroseconds / 1e6,
    );
    setState(() {
      _field = field;
      _size = size;
      _phase = _Phase.dust;
    });
    if (_hasOverlay) _portal.show();
    _clock.duration = widget.duration;
    _clock.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted && run == _run) _finish();
    });
    // The capture's alpha, for the blocks the shape could not rule out. A
    // frame or two late is fine: until then they draw nothing anyway.
    image.toByteData(format: ui.ImageByteFormat.rawRgba).then((data) {
      if (data != null && run == _run && identical(_field, field)) {
        field.cullTransparent(data);
      }
    }, onError: (Object _) {});
  }

  void _finish() {
    if (_phase == _Phase.done) return;
    if (_portal.isShowing) _portal.hide();
    _releaseField();
    setState(() => _phase = _Phase.done);
    widget.onDone?.call();
  }

  bool get _hasOverlay =>
      Overlay.maybeOf(context, rootOverlay: true) != null;

  @override
  Widget build(BuildContext context) {
    if (widget.active && _phase == _Phase.idle) _start(context);

    final Widget body;
    switch (_phase) {
      case _Phase.idle:
      case _Phase.pending:
        body = RepaintBoundary(key: _boundaryKey, child: widget.child);
      case _Phase.fade:
        body = FadeTransition(
          opacity: ReverseAnimation(_clock),
          child: RepaintBoundary(key: _boundaryKey, child: widget.child),
        );
      case _Phase.dust:
      case _Phase.done:
        // Holds the child's place. Under tight constraints (the focus's
        // circle mid-flight) the parent's size wins, which is what lets the
        // waiting blocks follow the flight.
        body = SizedBox.fromSize(size: _size);
    }

    final beneath = widget.beneath;
    final layered = KeyedSubtree(
      key: _boxKey,
      child: beneath == null || _phase == _Phase.idle
          ? body
          : Stack(
              // The child laid out exactly as it was without the layer under
              // it: a loosened constraint would shrink a childless box to
              // nothing and leave the capture empty.
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: FadeTransition(
                    opacity: _phase == _Phase.fade ? _clock : _reveal,
                    child: beneath,
                  ),
                ),
                body,
              ],
            ),
    );

    final field = _field;
    if (field == null || _phase != _Phase.dust) {
      // The portal stays in the tree so its element is stable across phases.
      return _hasOverlay
          ? OverlayPortal(
              controller: _portal,
              overlayLocation: OverlayChildLocation.rootOverlay,
              overlayChildBuilder: (_) => const SizedBox.shrink(),
              child: layered,
            )
          : layered;
    }

    final canvas = IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          child: CustomPaint(
            key: _canvasKey,
            painter: _DustPainter(
              field: field,
              clock: _clock,
              boxKey: _boxKey,
              canvasKey: _canvasKey,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    if (!_hasOverlay) {
      return Stack(
        clipBehavior: Clip.none,
        children: [layered, Positioned.fill(child: canvas)],
      );
    }
    return OverlayPortal(
      controller: _portal,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (_) => Positioned.fill(child: canvas),
      child: layered,
    );
  }
}

/// The picture cut into blocks, and where each of them is at a given time.
///
/// Home positions are in the child's own coordinates, at the size it was
/// captured; [fill] maps them through wherever the child's box is now.
/// Released motes are in the canvas's coordinates, from the point they let go.
class _DustField {
  _DustField({
    required this.image,
    required this.pixelRatio,
    required Size size,
    required Path? outline,
    required Offset sweep,
    required int seed,
    required this.seconds,
  }) : width = size.width {
    final w = size.width;
    final h = size.height;
    step = math.max(_minStep, math.sqrt(w * h / DustDissolve.maxParticles));
    final cols = (w / step).ceil();
    final rows = (h / step).ceil();
    final stepPx = step * pixelRatio;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();

    // The wave's direction, and the span of the picture along it.
    var sx = sweep.dx, sy = sweep.dy;
    final sl = math.sqrt(sx * sx + sy * sy);
    if (sl < 1e-6) {
      sx = 1;
      sy = 0;
    } else {
      sx /= sl;
      sy /= sl;
    }
    final corners = [0.0, w * sx, h * sy, w * sx + h * sy];
    final pMin = corners.reduce(math.min);
    final pSpan = math.max(1e-3, corners.reduce(math.max) - pMin);

    final rand = math.Random(seed);
    final cap = cols * rows;
    final hxL = Float32List(cap), hyL = Float32List(cap);
    final srcL = Float32List(cap * 4);
    final projL = Float32List(cap);
    var n = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cx = (c + 0.5) * step;
        final cy = (r + 0.5) * step;
        if (outline != null &&
            !outline.contains(Offset(math.min(cx, w - 0.5), math.min(cy, h - 0.5)))) {
          continue;
        }
        hxL[n] = cx;
        hyL[n] = cy;
        projL[n] = (cx * sx + cy * sy - pMin) / pSpan;
        final o = n * 4;
        srcL[o] = math.min(c * stepPx, imgW);
        srcL[o + 1] = math.min(r * stepPx, imgH);
        srcL[o + 2] = math.min((c + 1) * stepPx, imgW);
        srcL[o + 3] = math.min((r + 1) * stepPx, imgH);
        n++;
      }
    }
    count = n;
    hx = hxL;
    hy = hyL;
    src = srcL;
    delay = Float32List(n);
    life = Float32List(n);
    vx = Float32List(n);
    vy = Float32List(n);
    amp = Float32List(n);
    freq = Float32List(n);
    phase = Float32List(n);
    dust = Float32List(n);
    x0 = Float32List(n);
    y0 = Float32List(n);
    released = Uint8List(n);
    dead = Uint8List(n);
    transforms = Float32List(n * 4);
    spriteRects = Float32List(n * 4);
    colors = Int32List(n);

    final cxm = w / 2, cym = h / 2;
    for (var i = 0; i < n; i++) {
      // When the wave reaches it, give or take: the front is a band of
      // speckle, not a ruled line.
      final d = projL[i] * _sweepSpan + rand.nextDouble() * _jitter;
      delay[i] = d;
      life[i] = math.min(_lifeMin + _lifeRange * rand.nextDouble(), 1 - d);
      // Blown back against the wave and lifted, spread a little outward
      // from the middle. Skewed toward slow: most motes linger near where
      // they let go, a few streak off — a cloud, not a ring.
      final v = rand.nextDouble();
      final back = 50 + 170 * v * v;
      final lift = 40 + 80 * rand.nextDouble();
      var ox = hx[i] - cxm, oy = hy[i] - cym;
      final ol = math.sqrt(ox * ox + oy * oy);
      if (ol > 0.5) {
        ox /= ol;
        oy /= ol;
      } else {
        ox = 0;
        oy = 0;
      }
      final out = 20 + 60 * rand.nextDouble();
      vx[i] = -sx * back + ox * out + (rand.nextDouble() - 0.5) * 30;
      vy[i] = -sy * back + oy * out - lift + (rand.nextDouble() - 0.5) * 30;
      amp[i] = 3 + 9 * rand.nextDouble();
      freq[i] = 0.9 + 1.4 * rand.nextDouble();
      phase[i] = rand.nextDouble();
      dust[i] = 1.0 + 1.0 * rand.nextDouble();
    }
  }

  final ui.Image image;
  final double pixelRatio;
  final double seconds;

  /// The child's width at capture, against which its current width gives
  /// the scale the waiting blocks are drawn at.
  final double width;

  /// A block's side, in logical pixels.
  late final double step;
  late final int count;

  late final Float32List hx, hy, src;
  late final Float32List delay, life, vx, vy, amp, freq, phase, dust;
  late final Float32List x0, y0;
  late final Uint8List released, dead;

  late final Float32List transforms, spriteRects;
  late final Int32List colors;
  int alive = 0;

  /// The finest grain: a block under about a logical pixel and a half buys
  /// nothing but more motes than the eye can separate.
  static const double _minStep = 1.5;

  /// The timeline, as fractions of the run: the wave crosses in the first
  /// [_sweepSpan], each block lets go up to [_jitter] off it, and lives
  /// [_lifeMin] to [_lifeMin] + [_lifeRange] after — clipped to the end.
  static const double _sweepSpan = 0.55;
  static const double _jitter = 0.08;
  static const double _lifeMin = 0.3;
  static const double _lifeRange = 0.08;

  /// Drops the blocks that are clear in the capture (any of four samples
  /// inside the block with alpha above the threshold keeps it).
  void cullTransparent(ByteData data) {
    final iw = image.width, ih = image.height;
    if (data.lengthInBytes < iw * ih * 4) return;
    final sp = step * pixelRatio;
    for (var i = 0; i < count; i++) {
      final left = (hx[i] - step / 2) * pixelRatio;
      final top = (hy[i] - step / 2) * pixelRatio;
      var keep = false;
      for (var k = 0; k < 4 && !keep; k++) {
        final px = (left + sp * (k.isEven ? 0.3 : 0.7)).toInt().clamp(0, iw - 1);
        final py = (top + sp * (k < 2 ? 0.3 : 0.7)).toInt().clamp(0, ih - 1);
        if (data.getUint8((py * iw + px) * 4 + 3) > 6) keep = true;
      }
      if (!keep) dead[i] = 1;
    }
  }

  /// Fills the render buffers for time [t] (0..1 of the run), with the
  /// child's box at [origin] and scaled by [scale] in canvas coordinates.
  void fill(double t, double ox, double oy, double scale) {
    final sp = step * pixelRatio;
    var k = 0;
    for (var i = 0; i < count; i++) {
      if (dead[i] != 0) continue;
      final u = (t - delay[i]) / life[i];
      if (u >= 1) continue;
      double x, y, size, a;
      if (u <= 0) {
        // Waiting: part of the picture, riding with the box.
        x = ox + hx[i] * scale;
        y = oy + hy[i] * scale;
        size = step * scale;
        a = 1;
      } else {
        if (released[i] == 0) {
          released[i] = 1;
          x0[i] = ox + hx[i] * scale;
          y0[i] = oy + hy[i] * scale;
        }
        final age = (t - delay[i]) * seconds;
        // Drag on the launch, a steady lift, and an eddy of its own that
        // grows in over the first quarter second.
        final e = (1 - math.exp(-1.8 * age)) / 1.8;
        final swirl = amp[i] * math.min(1.0, age * 4);
        final turns = freq[i] * age + phase[i];
        x = x0[i] + vx[i] * e + swirl * DustTrig.sin(turns);
        y = y0[i] + vy[i] * e - 90 * age * age +
            swirl * DustTrig.cos(turns * 1.3);
        // From its block to a mote in a tenth of a second, then smaller
        // still as it fades.
        final block = step * scale;
        final shrink = dustSmooth(age / 0.1);
        size = (block + (dust[i] - block) * shrink) * (1 - 0.45 * u);
        final f = 1 - u;
        a = f * f * (1.6 - 0.6 * f);
        if (a < 0.02) continue;
      }
      final sc = size / sp;
      final o = k * 4;
      transforms[o] = sc;
      transforms[o + 1] = 0;
      transforms[o + 2] = x - size / 2;
      transforms[o + 3] = y - size / 2;
      final so = i * 4;
      spriteRects[o] = src[so];
      spriteRects[o + 1] = src[so + 1];
      spriteRects[o + 2] = src[so + 2];
      spriteRects[o + 3] = src[so + 3];
      colors[k] = ((a * 255).round() << 24) | 0xFFFFFF;
      k++;
    }
    alive = k;
  }
}

class _DustPainter extends CustomPainter {
  _DustPainter({
    required this.field,
    required this.clock,
    required this.boxKey,
    required this.canvasKey,
  }) : super(repaint: clock);

  final _DustField field;
  final Animation<double> clock;
  final GlobalKey boxKey;
  final GlobalKey canvasKey;

  @override
  void paint(Canvas canvas, Size size) {
    // Where the child's box is now, in this canvas's coordinates. Read here,
    // after this frame's layout, so the waiting blocks never trail a flight
    // or a scroll by a frame.
    final box = boxKey.currentContext?.findRenderObject();
    final self = canvasKey.currentContext?.findRenderObject();
    if (box is! RenderBox ||
        self is! RenderBox ||
        !box.attached ||
        !self.attached ||
        !box.hasSize) {
      return;
    }
    final Offset origin, edge;
    try {
      origin = self.globalToLocal(box.localToGlobal(Offset.zero));
      edge = self.globalToLocal(box.localToGlobal(Offset(box.size.width, 0)));
    } catch (_) {
      return;
    }
    final scale = field.width > 0 ? (edge - origin).distance / field.width : 1.0;
    field.fill(clock.value, origin.dx, origin.dy, scale);
    DustAtlas.draw(
      canvas,
      sprite: null,
      atlas: field.image,
      transforms: field.transforms,
      spriteRects: field.spriteRects,
      colors: field.colors,
      alive: field.alive,
    );
  }

  @override
  bool shouldRepaint(_DustPainter old) => !identical(old.field, field);

  /// Decoration only: the transcript under the dust stays tappable.
  @override
  bool hitTest(Offset position) => false;
}
