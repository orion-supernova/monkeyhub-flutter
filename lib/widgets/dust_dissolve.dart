import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Material, MaterialType, Theme;
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
/// crosses the picture along [sweep] on a noise-bent edge; patches of blocks
/// break off as tumbling chunks that crumble a beat later, the rest as loose
/// grit, and everything is picked up by a curl-noise wind that swirls it back
/// against the wave and upward while it shrinks to motes of its own colour
/// and thins out over a lingering tail (see [_DustField]). Blocks the wave
/// has not reached yet still tile the picture exactly, so the unreached part
/// reads as the child itself to the last.
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
    this.particles = maxParticles,
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

  /// This dissolve's share of the particle budget, at most [maxParticles].
  /// Several rows dissolving together split one budget between them (see
  /// `MessageDeletions`), so ten deletes cost what one does.
  final int particles;

  /// The whole run, the tail included. Telegram's burn is about two seconds
  /// end to end; this is a touch quicker, most of it the cloud thinning out.
  static const Duration defaultDuration = Duration(milliseconds: 1700);

  /// By when, of a [defaultDuration] run, the front has crossed and nearly
  /// every block has let go: what is left is dust in the air, so a row can
  /// start closing up under it.
  static const Duration waveDuration = Duration(milliseconds: 640);

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

  /// The beneath layer: in while the front crosses.
  late final Animation<double> _reveal = CurvedAnimation(
    parent: _clock,
    curve: const Interval(0.05, 0.45, curve: Curves.easeOut),
  );

  final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'dust:boundary');
  final GlobalKey _boxKey = GlobalKey(debugLabel: 'dust:box');
  final GlobalKey _canvasKey = GlobalKey(debugLabel: 'dust:canvas');

  /// The motes' canvas in the root overlay, while the dust flies. An entry
  /// rather than an `OverlayPortal`: nothing about the widget tree changes
  /// when the dust starts, and a portal in every transcript row tripped the
  /// semantics tree whenever a row was reparented.
  OverlayEntry? _entry;

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

  /// Out of the tree for this frame at least, and this frame still paints:
  /// the canvas, which lives elsewhere, must not go looking for the box.
  @override
  void deactivate() {
    _field?.retired = true;
    super.deactivate();
  }

  /// Moved, not removed (a reparented row).
  @override
  void activate() {
    super.activate();
    _field?.retired = false;
  }

  @override
  void dispose() {
    _run++;
    _dropEntry();
    _clock.dispose();
    _field?.image.dispose();
    _field = null;
    super.dispose();
  }

  void _reset() {
    _run++;
    _clock.stop();
    _clock.value = 0;
    _dropEntry();
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
    final atlas = _DustField.ember(image);
    final field = _DustField(
      image: atlas.image,
      hotDx: atlas.dx,
      hotDy: atlas.dy,
      sourceWidth: image.width,
      sourceHeight: image.height,
      pixelRatio: pixelRatio,
      size: size,
      outline: widget.shape?.getOuterPath(Offset.zero & size),
      sweep: widget.sweep,
      seed: widget.seed,
      seconds: widget.duration.inMicroseconds / 1e6,
      particles: widget.particles.clamp(64, DustDissolve.maxParticles),
      liftDark: Theme.of(context).brightness == Brightness.dark,
    );
    setState(() {
      _field = field;
      _size = size;
      _phase = _Phase.dust;
    });
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null) {
      _entry = OverlayEntry(builder: _buildCanvas);
      overlay.insert(_entry!);
    }
    _clock.duration = widget.duration;
    _clock.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted && run == _run) _finish();
    });
    // The capture's alpha, for the blocks the shape could not rule out. A
    // frame or two late is fine: until then they draw nothing anyway.
    // Read off the plain capture, not the doubled atlas: half the bytes. The
    // capture itself is let go once read, when the atlas holds a copy of it.
    final own = !identical(atlas.image, image);
    image.toByteData(format: ui.ImageByteFormat.rawRgba).then((data) {
      if (own) image.dispose();
      if (data != null && run == _run && identical(_field, field)) {
        field.cullTransparent(data);
      }
    }, onError: (Object _) {
      if (own) image.dispose();
    });
  }

  void _finish() {
    if (_phase == _Phase.done) return;
    _dropEntry();
    _releaseField();
    setState(() => _phase = _Phase.done);
    widget.onDone?.call();
  }

  /// Safe from anywhere, a build included: the overlay defers its own
  /// rebuild past the frame.
  void _dropEntry() {
    final entry = _entry;
    _entry = null;
    // The entry leaves the overlay after this frame, and may paint once more
    // first — over a box that is no longer in the tree.
    _field?.retired = true;
    if (entry == null) return;
    entry.remove();
    entry.dispose();
  }

  Widget _buildCanvas(BuildContext _) {
    final field = _field;
    if (field == null || _phase != _Phase.dust) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
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
      ),
    );
  }

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

    // In the overlay, the motes are the entry's; here, only the box.
    if (_entry != null || _field == null || _phase != _Phase.dust) {
      return layered;
    }
    // No overlay (a bare harness): the motes paint in place, unclipped.
    return Stack(
      clipBehavior: Clip.none,
      children: [layered, Positioned.fill(child: _buildCanvas(context))],
    );
  }
}

/// The picture cut into blocks, and where each of them is at a given time.
///
/// Home positions are in the child's own coordinates, at the size it was
/// captured; [fill] maps them through wherever the child's box is now.
/// Released motes are in the canvas's coordinates, from the point they let go.
///
/// What makes it organic rather than a sprinkler:
///
/// * The front is a noise-warped edge: each block's release time is its place
///   along [sweep], bent by a smooth field across the picture, so the burn
///   eats in as fingers and bays rather than a ruled line, plus a little
///   speckle so the edge frays.
/// * Clumps: the blocks are grouped into small irregular patches (a grid
///   warped by the same noise). About half the patches let go as one chunk —
///   same instant, shared launch, tumbling about their own middle, still
///   full-size — and crumble a beat later into dust, each grain going its own
///   way from there. The rest go straight to dust.
/// * Wind: once loose, every grain rides [DustFlow], a curl-noise table that
///   drifts over time, so the dust swirls in streams instead of all sliding
///   the same way. That part is integrated (the only part that is); the
///   launch, drag, lift and crumble are a closed form of the time.
/// * Grains tumble (the atlas transform carries a rotation), come in a spread
///   of sizes and lifetimes, and flash hot as they let go — the atlas holds a
///   brightened copy of the capture beside the plain one, and an igniting
///   grain flickers between the two.
class _DustField {
  _DustField({
    required this.image,
    required this.hotDx,
    required this.hotDy,
    required this.sourceWidth,
    required this.sourceHeight,
    this.liftDark = false,
    required this.pixelRatio,
    required Size size,
    required Path? outline,
    required Offset sweep,
    required int seed,
    required this.seconds,
    required int particles,
  }) : width = size.width {
    DustFlow.warm();
    final w = size.width;
    final h = size.height;
    step = math.max(_minStep, math.sqrt(w * h / particles));
    final cols = (w / step).ceil();
    final rows = (h / step).ceil();
    final stepPx = step * pixelRatio;
    final imgW = sourceWidth.toDouble();
    final imgH = sourceHeight.toDouble();

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
    // Where in the noise this picture sits: a different patch per seed.
    final nu = rand.nextDouble(), nv = rand.nextDouble();
    final big = math.max(w, h);

    final cap = cols * rows;
    final hxL = Float32List(cap), hyL = Float32List(cap);
    final srcL = Float32List(cap * 4);
    final keyL = Int32List(cap);
    // Clump size: a few blocks across, never under ~4.5pt so a chunk reads
    // as a chunk, never over ~11pt so it still reads as grit.
    final clump = (step * 3.2).clamp(4.5, 11.0);
    final clumpCols = (w / clump).ceil() + 4;
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
        final o = n * 4;
        srcL[o] = math.min(c * stepPx, imgW);
        srcL[o + 1] = math.min(r * stepPx, imgH);
        srcL[o + 2] = math.min((c + 1) * stepPx, imgW);
        srcL[o + 3] = math.min((r + 1) * stepPx, imgH);
        // Its patch: the clump grid, pushed around by the wind field so the
        // patches come out as blobs, not squares.
        DustFlow.sample(cx / 37 + nu, cy / 37 + nv);
        final gx = ((cx + DustFlow.x * clump * 0.9) / clump).floor() + 2;
        final gy = ((cy + DustFlow.y * clump * 0.9) / clump).floor() + 2;
        keyL[n] = gy * clumpCols + gx;
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
    hold = Float32List(n);
    spin = Float32List(n);
    gust = Float32List(n);
    dust = Float32List(n);
    relX = Float32List(n);
    relY = Float32List(n);
    cvx = Float32List(n);
    cvy = Float32List(n);
    x0 = Float32List(n);
    y0 = Float32List(n);
    fx = Float32List(n);
    fy = Float32List(n);
    released = Uint8List(n);
    dead = Uint8List(n);
    lift = Uint8List(n);
    transforms = Float32List(n * 4);
    spriteRects = Float32List(n * 4);
    colors = Int32List(n);

    // The patches' middles, for the chunks to tumble about.
    final index = <int, int>{};
    final sumX = <double>[], sumY = <double>[], members = <int>[];
    final clumpOf = Int32List(n);
    for (var i = 0; i < n; i++) {
      final id = index.putIfAbsent(keyL[i], () {
        sumX.add(0);
        sumY.add(0);
        members.add(0);
        return members.length - 1;
      });
      clumpOf[i] = id;
      sumX[id] += hx[i];
      sumY[id] += hy[i];
      members[id]++;
    }
    final clumps = members.length;
    final midX = Float32List(clumps), midY = Float32List(clumps);
    final cDelay = Float32List(clumps), cHold = Float32List(clumps);
    final cVx = Float32List(clumps), cVy = Float32List(clumps);
    final cSpin = Float32List(clumps);
    final cxm = w / 2, cym = h / 2;
    final run = seconds;

    // The front: place along the sweep, bent by a coarse field (about one
    // period across the picture, so two or three fingers), in seconds.
    double front(double x, double y) {
      final p = (x * sx + y * sy - pMin) / pSpan;
      DustFlow.sample(x / big * 0.9 + nu + 0.5, y / big * 0.9 + nv + 0.5);
      final bend = 0.5 + 0.5 * DustFlow.x;
      return (p * _sweepSpan + bend * _warp) * run;
    }

    // A launch: blown back against the wave and lifted, spread outward from
    // the middle. Skewed toward slow — most of it hangs where it let go, a
    // few streaks reach out — a cloud, not a ring.
    void launch(double x, double y, double kick, List<double> out) {
      final v = rand.nextDouble();
      final back = 35 + 160 * v * v * kick;
      final lift = 20 + 55 * rand.nextDouble();
      var ox = x - cxm, oy = y - cym;
      final ol = math.sqrt(ox * ox + oy * oy);
      if (ol > 0.5) {
        ox /= ol;
        oy /= ol;
      } else {
        ox = 0;
        oy = 0;
      }
      final spread = 15 + 55 * rand.nextDouble();
      out[0] = -sx * back + ox * spread + (rand.nextDouble() - 0.5) * 40;
      out[1] = -sy * back + oy * spread - lift + (rand.nextDouble() - 0.5) * 40;
    }

    final tmp = <double>[0, 0];
    for (var c = 0; c < clumps; c++) {
      final mx = sumX[c] / members[c], my = sumY[c] / members[c];
      midX[c] = mx;
      midY[c] = my;
      // About half the patches hold together for a beat: the bigger the
      // patch, the likelier.
      final cohesive = members[c] >= 3 && rand.nextDouble() < _chunkShare;
      cHold[c] = cohesive ? 0.07 + 0.15 * rand.nextDouble() : 0;
      cDelay[c] = front(mx, my) + rand.nextDouble() * _jitter * run;
      launch(mx, my, 1.3, tmp);
      cVx[c] = tmp[0];
      cVy[c] = tmp[1];
      final s = rand.nextDouble();
      cSpin[c] = (s < 0.5 ? -1 : 1) * (1.5 + 5.5 * rand.nextDouble());
    }

    for (var i = 0; i < n; i++) {
      final c = clumpOf[i];
      final hl = cHold[c];
      hold[i] = hl;
      if (hl > 0) {
        // A chunk: one instant, one launch, one tumble; when it crumbles its
        // grains carry on from the chunk's drift, each a little off it.
        delay[i] = cDelay[c];
        relX[i] = hx[i] - midX[c];
        relY[i] = hy[i] - midY[c];
        cvx[i] = cVx[c];
        cvy[i] = cVy[c];
        vx[i] = cVx[c] + (rand.nextDouble() - 0.5) * 70;
        vy[i] = cVy[c] + (rand.nextDouble() - 0.5) * 70;
        spin[i] = cSpin[c];
      } else {
        // Loose grit: its own instant, frayed off the front.
        delay[i] = front(hx[i], hy[i]) + rand.nextDouble() * _jitter * run;
        launch(hx[i], hy[i], 1, tmp);
        vx[i] = tmp[0];
        vy[i] = tmp[1];
        final s = rand.nextDouble();
        spin[i] = (s < 0.5 ? -1 : 1) * (2 + 9 * rand.nextDouble());
      }
      // Lives, skewed long: most of the cloud thins out together, a share
      // of it hangs on into the tail.
      final l = rand.nextDouble();
      life[i] = math.min(hl + 0.6 + 0.55 * l * l, run - delay[i]);
      if (life[i] < 0.05) life[i] = 0.05;
      // How hard the wind takes it: light grains swirl, heavy ones less so.
      gust[i] = 70 + 110 * rand.nextDouble();
      // Mostly fine dust, a few coarse flecks.
      final d = rand.nextDouble();
      dust[i] = 1.1 + 1.6 * d * d * d + 0.4 * rand.nextDouble();
    }
  }

  /// The capture, with a brightened copy of itself beside it when there is
  /// room: the embers' palette. Too big a picture (a full-screen photo) gets
  /// no copy and no flash, rather than a texture past what a GPU will take.
  static ({ui.Image image, double dx, double dy}) ember(ui.Image capture) {
    final w = capture.width, h = capture.height;
    if (w * h > _emberMaxPixels) return (image: capture, dx: -1, dy: -1);
    // Beside it along the short side, so the atlas stays squarish.
    final below = w >= h;
    final dx = below ? 0.0 : w.toDouble();
    final dy = below ? h.toDouble() : 0.0;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(capture, Offset.zero, Paint());
      canvas.drawImage(
        capture,
        Offset(dx, dy),
        Paint()..colorFilter = const ColorFilter.matrix(_hot),
      );
      final picture = recorder.endRecording();
      final image = picture.toImageSync(
        below ? w : w * 2,
        below ? h * 2 : h,
      );
      picture.dispose();
      return (image: image, dx: dx, dy: dy);
    } catch (_) {
      return (image: capture, dx: -1, dy: -1);
    }
  }

  /// Hot: brighter, and with its blacks raised to a soft cool grey, so one
  /// copy serves both a grain catching (a flicker of it as it lets go) and a
  /// dark grain that must still read on a dark ground (all of it, once loose).
  static const List<double> _hot = [
    1.1, 0, 0, 0, 60, //
    0, 1.1, 0, 0, 57, //
    0, 0, 1.1, 0, 68, //
    0, 0, 0, 1, 0,
  ];

  static const int _emberMaxPixels = 1600000;

  /// The atlas: the capture, plus its hot copy when [hotDx] is not negative.
  final ui.Image image;
  final double hotDx, hotDy;
  final int sourceWidth, sourceHeight;

  /// On a dark ground, dust from dark pixels would vanish into it: such
  /// grains are drawn from the lifted copy once they let go (see [lift]).
  final bool liftDark;
  final double pixelRatio;

  /// The run's length, in seconds.
  final double seconds;

  /// The child's width at capture, against which its current width gives
  /// the scale the waiting blocks are drawn at.
  final double width;

  /// A block's side, in logical pixels.
  late final double step;
  late final int count;

  late final Float32List hx, hy, src;

  /// Per grain, in seconds and logical pixels: when it lets go, how long it
  /// lives, its own launch, how long its chunk holds (0: loose), its tumble
  /// (rad/s), how hard the wind takes it, and the mote it ends as.
  late final Float32List delay, life, vx, vy, hold, spin, gust, dust;

  /// A chunk member's place in its chunk, and the chunk's launch.
  late final Float32List relX, relY, cvx, cvy;

  /// Where it let go (canvas), and how far the wind has carried it since.
  late final Float32List x0, y0, fx, fy;
  late final Uint8List released, dead;

  /// Grains from dark pixels (under about a fifth of full luminance), found
  /// in the same readback as the clear ones when [liftDark]. Bright and
  /// coloured grains are left exactly as they are.
  late final Uint8List lift;

  late final Float32List transforms, spriteRects;
  late final Int32List colors;
  int alive = 0;

  /// The last time [fill] ran, in seconds into the run: the wind's step.
  double _last = 0;

  /// Its dissolve has finished or gone: draw nothing more.
  bool retired = false;

  /// The finest grain: a block under about a logical pixel and a half buys
  /// nothing but more motes than the eye can separate.
  static const double _minStep = 1.5;

  /// The front, as fractions of the run: the wave crosses in [_sweepSpan],
  /// bent by up to [_warp] and frayed by up to [_jitter] more. The last block
  /// lets go by about 0.42 of the run; the rest is the cloud thinning out.
  static const double _sweepSpan = 0.30;
  static const double _warp = 0.08;
  static const double _jitter = 0.04;

  /// The share of patches that come away as chunks.
  static const double _chunkShare = 0.4;

  /// The wind's scale: one period of [DustFlow] spans this many logical
  /// pixels, so its eddies are a few dozen across.
  static const double _windPeriod = 170;

  /// Drops the blocks that are clear in the capture (any of four samples
  /// inside the block with alpha above the threshold keeps it). [data] is
  /// the plain capture, [sourceWidth] by [sourceHeight].
  void cullTransparent(ByteData data) {
    final iw = sourceWidth, ih = sourceHeight;
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
      if (!keep) {
        dead[i] = 1;
        continue;
      }
      if (!liftDark) continue;
      // Its middle's luminance, alpha taken out.
      final cx = (hx[i] * pixelRatio).toInt().clamp(0, iw - 1);
      final cy = (hy[i] * pixelRatio).toInt().clamp(0, ih - 1);
      final o = (cy * iw + cx) * 4;
      final al = data.getUint8(o + 3);
      if (al < 24) continue;
      final y = 0.2126 * data.getUint8(o) +
          0.7152 * data.getUint8(o + 1) +
          0.0722 * data.getUint8(o + 2);
      if (y < 0.2 * al) lift[i] = 1;
    }
  }

  /// Fills the render buffers for time [t] (0..1 of the run), with the
  /// child's box at [origin] and scaled by [scale] in canvas coordinates.
  void fill(double t, double ox, double oy, double scale) {
    final now = t * seconds;
    // The wind's step: what has passed since the last frame, clamped so a
    // stall does not fling the dust.
    var dt = now - _last;
    if (dt < 0) dt = 0;
    if (dt > 1 / 30) dt = 1 / 30;
    _last = now;
    final frame = (now * 36).toInt();
    final hot = hotDx >= 0;
    final sp = step * pixelRatio;
    final half = sp / 2;
    final block = step * scale;
    // The wind field slides as it goes, so the streams shift under the dust.
    final du = now * 0.11, dv = -now * 0.07;
    var k = 0;
    for (var i = 0; i < count; i++) {
      if (dead[i] != 0) continue;
      final age = now - delay[i];
      final lf = life[i];
      if (age >= lf) continue;
      double x, y, size, a, rot = 0;
      var lit = false;
      if (age <= 0) {
        // Waiting: part of the picture, riding with the box.
        x = ox + hx[i] * scale;
        y = oy + hy[i] * scale;
        size = block;
        a = 1;
      } else {
        if (released[i] == 0) {
          released[i] = 1;
          x0[i] = ox + hx[i] * scale;
          y0[i] = oy + hy[i] * scale;
          relX[i] *= scale;
          relY[i] *= scale;
        }
        final u = age / lf;
        // Picked up, not shot: the wind takes a grain gently and then
        // carries it (speed ramps from 0 to its own over about a quarter
        // second), so the freshly loosed part hangs as a speckled ghost of
        // the picture before it streams off. Plus a lift that grows.
        final e = age * age / (age + 0.22);
        final rise = 55 * age * age;
        final hl = hold[i];
        final turns = spin[i] * age * (1 / (2 * math.pi));
        rot = turns;
        double crumble;
        if (hl > 0) {
          // A chunk until it holds no longer, then grains: the chunk's path
          // (its drift plus the tumble of this grain about its middle)
          // hands over to the grain's own over a fifth of a second.
          final c = DustTrig.cos(turns), s = DustTrig.sin(turns);
          final rx = relX[i], ry = relY[i];
          final chX = x0[i] - rx + cvx[i] * e + (rx * c - ry * s);
          final chY = y0[i] - ry + cvy[i] * e + (rx * s + ry * c) - rise;
          final ownX = x0[i] + vx[i] * e;
          final ownY = y0[i] + vy[i] * e - rise;
          crumble = dustSmooth((age - hl) / 0.2);
          x = chX + (ownX - chX) * crumble;
          y = chY + (ownY - chY) * crumble;
        } else {
          crumble = 1;
          x = x0[i] + vx[i] * e;
          y = y0[i] + vy[i] * e - rise;
        }
        // The wind: in once the grain is loose, stronger as it thins.
        final windAge = age - hl;
        if (windAge > 0 && dt > 0) {
          final px = x + fx[i], py = y + fy[i];
          DustFlow.sample(px / _windPeriod + du, py / _windPeriod + dv);
          final ramp = windAge < 0.3 ? windAge / 0.3 : 1.0;
          final g = gust[i] * ramp * (0.6 + 0.9 * u) * dt;
          fx[i] += DustFlow.x * g;
          fy[i] += DustFlow.y * g;
        }
        x += fx[i];
        y += fy[i];
        // From its block to a mote: a loose grain over a third of a second,
        // a chunk's once it crumbles; smaller still as it fades.
        final shrink = hl > 0 ? crumble : dustSmooth(age / 0.32);
        size = (block + (dust[i] - block) * shrink) * (1 - 0.25 * u);
        // Opaque for the first third, then a long thinning; a grain in the
        // tail twinkles now and then as it turns.
        if (u < 0.4) {
          a = 1;
        } else {
          final f = 1 - (u - 0.4) / 0.6;
          a = f * (1.25 - 0.25 * f);
          if (u > 0.5 && dustHash(i, frame) < 0.18) a *= 0.45;
        }
        if (a < 0.02) continue;
        // Catching: a flicker of the hot copy as it lets go, dying off over
        // a quarter second; the odd ember later on.
        if (hot) {
          final h = dustHash(i + 7919, frame);
          lit = lift[i] != 0 ||
              (age < 0.15 ? h < 0.35 * (1 - age / 0.15) : h < 0.012 * a);
        }
      }
      final sc = size / sp;
      final o = k * 4;
      if (rot == 0) {
        transforms[o] = sc;
        transforms[o + 1] = 0;
        transforms[o + 2] = x - size / 2;
        transforms[o + 3] = y - size / 2;
      } else {
        // Rotated about the sprite's middle.
        final scos = sc * DustTrig.cos(rot), ssin = sc * DustTrig.sin(rot);
        transforms[o] = scos;
        transforms[o + 1] = ssin;
        transforms[o + 2] = x - scos * half + ssin * half;
        transforms[o + 3] = y - ssin * half - scos * half;
      }
      final so = i * 4;
      if (lit) {
        spriteRects[o] = src[so] + hotDx;
        spriteRects[o + 1] = src[so + 1] + hotDy;
        spriteRects[o + 2] = src[so + 2] + hotDx;
        spriteRects[o + 3] = src[so + 3] + hotDy;
      } else {
        spriteRects[o] = src[so];
        spriteRects[o + 1] = src[so + 1];
        spriteRects[o + 2] = src[so + 2];
        spriteRects[o + 3] = src[so + 3];
      }
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
    if (field.retired) return;
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
