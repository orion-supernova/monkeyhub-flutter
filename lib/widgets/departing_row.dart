import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'dust/dust_kit.dart';
import 'message_departures.dart';

/// How a Chamber of Secrets message leaves the screen.
///
/// The row that drew the bubble is replaced by this one, the same height,
/// holding the bubble's last picture cut into tiles. What follows is one
/// continuous piece of physics rather than a sequence of beats, because the
/// beats overlap — which is what makes it look like something happening
/// rather than something scheduled:
///
///  * **Blast.** The tiles blow apart from the bubble's centre, spinning,
///    and drift — light drag, no hurry.
///  * **Hurricane.** Under them a vacuum spins up: a point sink at the
///    drain with a vortex round the axis. Each tile is caught at its own
///    moment and follows the air at its own pace, and when it actually
///    arrives it docks into a tall spinning column standing on the drain —
///    so the column builds up as the tiles come in, not all at once.
///  * **Drawn off.** Before the column is finished, a nozzle off to the
///    side — right for your own message, left for anybody else's — starts
///    taking it from the top: a suction front descends the column, and
///    every tile it passes lets go and rides one path, straight up the axis
///    and hard over into the nozzle, a reverse L, spiralling round that
///    line. Tiles still arriving dock below the front and feed the tube;
///    a tile that docks where the front has already been is taken at once.
///
/// Only once the last mote is gone does the row's height close, so nothing
/// below moves until there is nothing left to watch.
///
/// It is the bubble's actual pixels that fly: one `drawRawAtlas` per frame
/// over the capture, with a source rect per tile. Nothing is read back and
/// nothing is allocated per frame — every tile lives in flat buffers sized
/// once, and the painter repaints on a notifier the ticker bumps, so no
/// widget rebuilds while it runs.
///
/// Calm motion — or a capture with no picture — collapses the row at once
/// and draws nothing, per the [MotionScope] contract: no ticker is ever made.
class DepartingRow extends StatefulWidget {
  const DepartingRow({
    super.key,
    required this.capture,
    required this.calm,
    required this.onDone,
  });

  final DepartureCapture capture;

  /// Resolved by the owner — `MotionScope.of(context).calm` — rather than
  /// read here, so a test can pin either path.
  final bool calm;

  /// The exit has finished (or was skipped); the ghost can leave the list.
  final VoidCallback onDone;

  /// The flight is one continuous simulation — see [_TileField.step] for
  /// the timeline — but it still reads as three beats, and these are their
  /// rough lengths: the blast drifting, the vacuum winding the cloud into
  /// the column, the column being drawn off. Only their sum is load-bearing.
  static const Duration burst = Duration(milliseconds: 450);
  static const Duration gather = Duration(milliseconds: 850);
  static const Duration vortex = Duration(milliseconds: 2500);
  static const Duration collapse = Duration(milliseconds: 200);

  static Duration get total => burst + gather + vortex + collapse;

  /// Tiles per bubble, at most. A wide bubble gets bigger tiles rather than
  /// more of them.
  static const int maxTiles = 2500;

  @override
  State<DepartingRow> createState() => _DepartingRowState();
}

class _DepartingRowState extends State<DepartingRow>
    with SingleTickerProviderStateMixin {
  /// The row's height factor: 1 for the whole flight, then 1 → 0.
  final ValueNotifier<double> _height = ValueNotifier<double>(1);

  /// The tiles are painted in the ROOT overlay, above the composer, the app
  /// bar and anything else a row in the list sits under — a bubble blowing
  /// apart over the transcript must not disappear behind the text field.
  /// The follower keeps the painting pinned to the row as the list scrolls,
  /// through a layer transform rather than a rebuild.
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();

  /// Bumped per tick; the tile painter repaints on it.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  _TileField? _field;
  Ticker? _ticker;
  Duration? _lastTick;
  Duration? _flightEnd;
  bool _done = false;

  bool get _instant => widget.calm || widget.capture.image == null;

  @override
  void initState() {
    super.initState();
    if (_instant) {
      _height.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }
    _field = _TileField(widget.capture);
    _portal.show();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _height.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  void _onTick(Duration elapsed) {
    final field = _field;
    if (field == null) return;
    final dt = dustFrameDt(_lastTick, elapsed);
    _lastTick = elapsed;

    final flight =
        DepartingRow.burst + DepartingRow.gather + DepartingRow.vortex;
    // The flight ends when the nozzle has everything — or at the deadline,
    // whichever is first.
    if (elapsed < flight && !field.allGone) {
      field.step(elapsed, dt);
      _frame.value++;
      return;
    }
    if (field.alive != 0) {
      field.alive = 0;
      _frame.value++;
    }
    // Anchor the collapse where the flight actually ended: early, if the
    // nozzle had everything before the deadline; at the deadline otherwise.
    final end = _flightEnd ??= (elapsed < flight ? elapsed : flight);
    final u = (elapsed - end).inMicroseconds /
        DepartingRow.collapse.inMicroseconds;
    if (u >= 1) {
      _height.value = 0;
      _ticker?.stop();
      _finish();
      return;
    }
    _height.value = 1 - Curves.easeInCubic.transform(u);
  }

  @override
  Widget build(BuildContext context) {
    final rowSize = widget.capture.rowSize;
    final field = _field;
    // The row itself holds only its height. Its top-left is the leader the
    // overlay painting follows — so it must span the row's full width: a
    // height-only box under an Align would sit at the row's centre and put
    // the whole picture half a row to the right.
    final body = CompositedTransformTarget(
      link: _link,
      child: SizedBox(width: double.infinity, height: rowSize.height),
    );
    final row = ValueListenableBuilder<double>(
      valueListenable: _height,
      child: body,
      builder: (context, h, child) => Align(
        alignment: Alignment.topCenter,
        heightFactor: h,
        child: child,
      ),
    );
    if (field == null) return row;
    return OverlayPortal(
      controller: _portal,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (context) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          child: IgnorePointer(
            child: SizedBox(
              width: rowSize.width,
              height: rowSize.height,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _TilePainter(field: field, repaint: _frame),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
      child: row,
    );
  }
}

/// The bubble cut into tiles, and where each of them is right now.
///
/// Positions are in the ROW's coordinates. Buffers are allocated once here
/// and mutated in place by [step], which also compacts the render buffers
/// so the painter is handed them straight. Every beat after the blast is a
/// closed form of the time, per tile — no integrator can drift, and a
/// dropped frame lands exactly where a smooth one would have.
class _TileField {
  _TileField(this.capture) : image = capture.image! {
    final size = capture.bubbleSize;
    final w = size.width;
    final h = size.height;
    // Bigger tiles on a bigger bubble, never more than the cap: a whole
    // paragraph coming apart should cost what a one-liner does.
    tile = math.max(5.0, math.sqrt(w * h / DepartingRow.maxTiles));
    final cols = (w / tile).ceil();
    final rows = (h / tile).ceil();
    final pr = capture.pixelRatio;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    tilePx = tile * pr;
    final origin = capture.bubbleInRow;
    centre = origin + Offset(w / 2, h / 2);
    side = capture.isMine ? 1 : -1;
    drain = centre - const Offset(0, 6);
    // A hurricane stands taller than the bubble it came from, and its mouth
    // is a good part of the bubble's width.
    funnelHeight = (h * 1.8).clamp(120.0, 220.0);
    funnelMouth = (w * 0.16).clamp(22.0, 44.0);
    // The corner the stream turns at, a little above the column's top, and
    // the nozzle it turns toward: off to the side at the corner's height,
    // so the stream leaves the row — and, for a bubble at the edge, the
    // screen — along the arm of the L.
    corner = drain - Offset(0, funnelHeight + 36);
    nozzle = Offset(drain.dx + side * 340, corner.dy);

    final rand = math.Random(capture.message.id.hashCode);
    final cap = cols * rows;
    final hxL = Float32List(cap), hyL = Float32List(cap);
    final srcL = Float32List(cap * 4);
    var n = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cx = math.min((c + 0.5) * tile, w - 0.5);
        final cy = math.min((r + 0.5) * tile, h - 0.5);
        if (!capture.outline.contains(Offset(cx, cy))) continue;
        hxL[n] = origin.dx + cx;
        hyL[n] = origin.dy + cy;
        final o = n * 4;
        srcL[o] = c * tilePx;
        srcL[o + 1] = r * tilePx;
        srcL[o + 2] = math.min((c + 1) * tilePx, imgW);
        srcL[o + 3] = math.min((r + 1) * tilePx, imgH);
        n++;
      }
    }
    count = n;
    hx = hxL;
    hy = hyL;
    src = srcL;
    x = Float32List(n);
    y = Float32List(n);
    vx = Float32List(n);
    vy = Float32List(n);
    rot = Float32List(n);
    rotV = Float32List(n);
    rnd = Float32List(n);
    th = Float32List(n);
    scale = Float32List(n);
    alpha = Float32List(n);
    lvl = Float32List(n);
    seatR = Float32List(n);
    leaveAt = Float32List(n);
    travel = Float32List(n);
    px0 = Float32List(n);
    py0 = Float32List(n);
    phi = Float32List(n);
    tPull = Float32List(n);
    tOff = Float32List(n);
    state = Uint8List(n);
    transforms = Float32List(n * 4);
    spriteRects = Float32List(n * 4);
    colors = Int32List(n);

    for (var i = 0; i < n; i++) {
      x[i] = hx[i];
      y[i] = hy[i];
      rnd[i] = rand.nextDouble();
      var dx = hx[i] - centre.dx;
      var dy = hy[i] - centre.dy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 0.5) {
        final a = rand.nextDouble();
        dx = DustTrig.cos(a);
        dy = DustTrig.sin(a);
      } else {
        dx /= d;
        dy /= d;
      }
      // Spread hard toward slow (rnd²): most tiles barely leave, a few fly
      // far. A blast whose tiles all travel the same distance is a ring,
      // and a ring is a shape, not an explosion.
      final v = rand.nextDouble();
      final speed = 60 + 340 * v * v;
      vx[i] = dx * speed + (rand.nextDouble() - 0.5) * 160;
      vy[i] = dy * speed + (rand.nextDouble() - 0.5) * 160;
      // Spin, in turns per second: ±6 rad/s.
      rotV[i] = (rand.nextDouble() * 2 - 1) * (6 / (2 * math.pi));
      // Its seat in the hurricane: how far up the column it will sit (0 the
      // foot, 1 the top — weighted upward, a twister is heavy at the mouth)
      // and how far out from the axis, between the inner and outer wall.
      final seat = math.pow(rand.nextDouble(), 0.7).toDouble();
      lvl[i] = seat;
      seatR[i] = _funnelRadius(seat) * (0.45 + 0.55 * rand.nextDouble());
      phi[i] = rand.nextDouble();
      // When the vacuum gets hold of it — every tile at its own moment, so
      // the cloud folds in ragged — a little jitter on when the front
      // takes it, and how long its ride to the nozzle takes, in seconds.
      tPull[i] = _vacuumFrom + 0.9 * math.pow(rand.nextDouble(), 1.4);
      leaveAt[i] = rand.nextDouble() * 0.05;
      travel[i] = 0.55 + 0.25 * rand.nextDouble();
      scale[i] = 1;
      alpha[i] = 1;
    }
    step(Duration.zero, 0);
  }

  final DepartureCapture capture;
  final ui.Image image;

  late final double tile;
  late final double tilePx;
  late final Offset centre;
  late final double side;
  late final int count;

  late final Float32List hx, hy, src;
  late final Float32List x, y, vx, vy, rot, rotV, rnd;
  late final Float32List th, scale, alpha;

  /// The hurricane: each tile's level up the column and its radius there,
  /// and its ride out: when it leaves (as a fraction of the last beat), how
  /// long the ride takes (likewise), where it left from, and the phase of
  /// the spiral it rides in.
  late final Float32List lvl, seatR;
  late final Float32List leaveAt, travel, px0, py0, phi;

  /// When the vacuum catches each tile, and when it left the column.
  late final Float32List tPull, tOff;

  /// 0 free (blast, then the air), 1 docked in the column, 2 riding the L,
  /// 3 gone.
  late final Uint8List state;

  /// Every tile has reached the nozzle.
  bool get allGone => _gone >= count;
  int _gone = 0;

  /// The drain: where the column stands, a touch above the bubble's centre.
  late final Offset drain;

  /// Where the stream turns, and where it is finally drawn to.
  late final Offset corner, nozzle;

  /// Radius of the rounding at the corner of the L.
  static const double _cornerR = 14;

  /// How tall the column stands over the drain, and how wide its mouth is.
  late final double funnelHeight, funnelMouth;

  /// Render buffers, compacted each step: the first [alive] entries are the
  /// tiles to draw.
  late final Float32List transforms, spriteRects;
  late final Int32List colors;
  int alive = 0;

  bool _spinPrimed = false;

  /// The timeline, in seconds. The vacuum starts spinning up while the
  /// blast is still drifting; the front starts down the column before it
  /// has finished forming. Overlaps on purpose.
  static const double _vacuumFrom = 0.35;
  static const double _vacuumFull = 1.25;
  static const double _frontFrom = 1.3;
  static const double _frontTo = 3.0;

  /// The dust a tile shrinks to, as a fraction of the tile: about two and a
  /// half logical pixels.
  double get _dustScale => 2.5 / tile;

  /// A cone, narrow at the foot: the column's radius at [level] (0..1).
  double _funnelRadius(double level) =>
      2.5 + (funnelMouth - 2.5) * math.pow(level, 1.5);

  /// The side view of a circle: how much of the orbit's depth shows as
  /// height. A twister seen from the ground is a stack of these ellipses.
  static const double _squash = 0.3;

  /// Advances every tile to [elapsed] and refills the render buffers.
  void step(Duration elapsed, double dt) {
    final t = elapsed.inMicroseconds / 1e6;
    if (!_spinPrimed) {
      _spinPrimed = true;
      // Each tile's angle round the axis starts where it sits in the
      // bubble, so its seat in the column is on its own side.
      for (var i = 0; i < count; i++) {
        th[i] = math.atan2(y[i] - drain.dy, x[i] - drain.dx) / (2 * math.pi);
      }
    }
    // The air winds up gently; the column stands up as it fills; the front
    // walks down the column from the top.
    final spin = dustSmooth((t - _vacuumFrom) / (_vacuumFull - _vacuumFrom));
    final grow = dustSmooth((t - 0.3) / 1.0);
    final front = 1 - ((t - _frontFrom) / (_frontTo - _frontFrom)).clamp(0.0, 1.0);
    final sucking = t >= _frontFrom;
    final dust = _dustScale;
    final cornerX = drain.dx;
    final cornerY = corner.dy;
    // The blast's own drag — light, so the cloud spreads before it is caught.
    final blastDrag = math.exp(-1.1 * dt);

    for (var i = 0; i < count; i++) {
      switch (state[i]) {
        case 3:
          continue;

        case 2:
          // ── Riding the L ──
          final p = ((t - tOff[i]) / travel[i]).clamp(0.0, 1.0);
          // Sucked, not carried: slow to let go, then away.
          final q = Curves.easeInQuad.transform(p);
          final l1 = math.max(1.0, py0[i] - cornerY);
          final l2 = (nozzle.dx - cornerX).abs();
          final d = q * (l1 + l2);
          double bx, by, tx, ty;
          if (d < l1 - _cornerR) {
            final f = d / l1;
            bx = px0[i] + (cornerX - px0[i]) * math.min(1.0, f * 3);
            by = py0[i] - d;
            tx = 0;
            ty = -1;
          } else if (d > l1 + _cornerR) {
            bx = cornerX + side * (d - l1);
            by = cornerY;
            tx = side;
            ty = 0;
          } else {
            final u = (d - (l1 - _cornerR)) / (2 * _cornerR);
            final mu = 1 - u;
            final ax0 = cornerX, ay0 = cornerY + _cornerR;
            final ax2 = cornerX + side * _cornerR, ay2 = cornerY;
            bx = mu * mu * ax0 + 2 * mu * u * cornerX + u * u * ax2;
            by = mu * mu * ay0 + 2 * mu * u * cornerY + u * u * ay2;
            tx = 2 * mu * (cornerX - ax0) + 2 * u * (ax2 - cornerX);
            ty = 2 * mu * (cornerY - ay0) + 2 * u * (ay2 - cornerY);
            final tl = math.sqrt(tx * tx + ty * ty);
            if (tl > 0.001) {
              tx /= tl;
              ty /= tl;
            }
          }
          // It keeps circling the line it rides, tighter and faster the
          // further along — the tube narrows into the nozzle.
          phi[i] += (3.0 + 3.0 * q) * dt;
          final helix = (seatR[i] * 0.8 + 5) * (1 - 0.8 * q);
          final across = helix * DustTrig.cos(phi[i]);
          final depth = helix * DustTrig.sin(phi[i]) * 0.45;
          x[i] = bx - ty * across;
          y[i] = by + tx * across + depth;
          scale[i] = dust * (1 - 0.4 * q);
          alpha[i] = p < 0.78 ? 1 : 1 - dustSmooth((p - 0.78) / 0.22);
          if (p >= 1) {
            state[i] = 3;
            _gone++;
          }
          continue;

        case 1:
          // ── Standing in the column ──
          final l = lvl[i];
          th[i] += (1.6 + 0.8 * rnd[i] + 0.8 * l) * dt;
          final r = seatR[i];
          x[i] = drain.dx + r * DustTrig.cos(th[i]);
          y[i] = drain.dy - funnelHeight * l * grow +
              r * DustTrig.sin(th[i]) * _squash;
          scale[i] = dust;
          alpha[i] = 1;
          // The front has reached its level: it lets go from wherever it
          // is on its ring.
          if (sucking && l >= front - leaveAt[i]) {
            state[i] = 2;
            px0[i] = x[i];
            py0[i] = y[i];
            phi[i] = th[i];
            tOff[i] = t;
          }
          continue;

        default:
          // ── Free: the blast, then the air ──
          //
          // Dust in moving air. The air is a point sink at the drain (slow
          // far out, fierce close in) with a vortex round the axis that is
          // strongest around where the blast left the cloud and weaker
          // inward — so the cloud shears into arms as it comes in — and a
          // slow eddy of its own for every tile. The tile's velocity RELAXES
          // toward the air's, at a rate that rises with the vacuum and is
          // its own: before the air moves it just drifts on what the blast
          // gave it. Worked out in the frame where the orbit is a circle
          // (the side view's squash undone) so the whirl never leaks
          // outward, and mapped back.
          final axisY = drain.dy - funnelHeight * lvl[i] * grow;
          final dx = x[i] - drain.dx;
          final dyS = (y[i] - axisY) / _squash;
          final r = math.sqrt(dx * dx + dyS * dyS) + 0.001;
          final ex = dx / r;
          final eyS = dyS / r;
          final sink = -(300 + 80000 / (r + 60)) * spin;
          final whirl = 1900 * r * 90 / (8100 + r * r) * spin;
          var ufx = ex * sink - eyS * whirl;
          var ufy = (eyS * sink + ex * whirl) * _squash;
          // Heights close on their own; the flattened frame makes the
          // sink's vertical share a weak one.
          ufy += (axisY - y[i]) * 2.5 * spin;
          ufx += 140 * spin * DustTrig.sin(t * 1.3 + rnd[i] * 13);
          ufy += 80 * spin * DustTrig.sin(t * 1.7 + rnd[i] * 7);
          // Caught: from its own moment on, the air gives way to the
          // velocity that carries it onto its seat — a moving one, the
          // column turning under it.
          final caught = dustSmooth((t - tPull[i]) / 1.0);
          final turn = (1.4 + 1.2 * spin) * (0.85 + 0.3 * rnd[i]);
          th[i] += turn * dt;
          double sx = 0, sy = 0;
          if (caught > 0) {
            final c = DustTrig.cos(th[i]);
            final sn = DustTrig.sin(th[i]);
            sx = drain.dx + seatR[i] * c;
            sy = axisY + seatR[i] * sn * _squash;
            // The seat is moving — the column turns under it — so the
            // velocity that carries the tile onto it includes the seat's
            // own; a tracker without that trails a moving seat forever and
            // never arrives.
            final w = turn * 2 * math.pi * seatR[i];
            final svx = -sn * w;
            final svy = c * w * _squash;
            ufx = ufx * (1 - caught) + ((sx - x[i]) * 7 + svx) * caught;
            ufy = ufy * (1 - caught) + ((sy - y[i]) * 7 + svy) * caught;
          }
          final rate = (1.0 + 11 * spin) * (0.6 + 0.6 * rnd[i]);
          final follow = 1 - math.exp(-rate * dt);
          vx[i] *= blastDrag;
          vy[i] *= blastDrag;
          vx[i] += (ufx - vx[i]) * follow;
          vy[i] += (ufy - vy[i]) * follow;
          x[i] += vx[i] * dt;
          y[i] += vy[i] * dt;
          rot[i] += rotV[i] * (1 - spin) * dt;
          // It shrinks to dust as it is taken, each in its own time.
          scale[i] = 1 - (1 - dust * 1.15) * caught;
          alpha[i] = 1;
          // Arrived: it docks, and the column is one tile taller. A tile
          // the air has held for long enough is seated regardless — the
          // column must not wait on a straggler.
          if (caught > 0.5) {
            final gx = sx - x[i];
            final gy = sy - y[i];
            if (gx * gx + gy * gy < 64 || t > tPull[i] + 1.8) {
              state[i] = 1;
            }
          }
      }
    }

    // Fill the render buffers.
    final pr = capture.pixelRatio;
    final ax = tilePx / 2;
    var k = 0;
    for (var i = 0; i < count; i++) {
      if (state[i] == 3) continue;
      final a = alpha[i];
      if (a < 0.02) continue;
      final sc = scale[i] / pr;
      final scos = sc * DustTrig.cos(rot[i]);
      final ssin = sc * DustTrig.sin(rot[i]);
      final o = k * 4;
      transforms[o] = scos;
      transforms[o + 1] = ssin;
      transforms[o + 2] = x[i] - scos * ax + ssin * ax;
      transforms[o + 3] = y[i] - ssin * ax - scos * ax;
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

/// Draws the tiles — one `drawRawAtlas` over the capture per frame.
class _TilePainter extends CustomPainter {
  _TilePainter({required this.field, required Listenable repaint})
      : super(repaint: repaint);

  final _TileField field;

  @override
  void paint(Canvas canvas, Size size) {
    final n = field.alive;
    if (n == 0) return;
    DustAtlas.draw(
      canvas,
      sprite: null,
      atlas: field.image,
      transforms: field.transforms,
      spriteRects: field.spriteRects,
      colors: field.colors,
      alive: n,
    );
  }

  @override
  bool shouldRepaint(_TilePainter old) => !identical(old.field, field);

  /// Decoration only: nothing under a departing row is tappable, and a
  /// painter that took hits would swallow the scroll.
  @override
  bool hitTest(Offset position) => false;
}
