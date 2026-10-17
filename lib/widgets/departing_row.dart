import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'dust/dust_kit.dart';
import 'message_departures.dart';

/// How a Chamber of Secrets message leaves the screen.
///
/// The row that drew the bubble is replaced by this one, the same height,
/// holding the bubble's last picture cut into grains a couple of pixels
/// across. What follows is one continuous piece of physics rather than a
/// sequence of beats, because the beats overlap — which is what makes it
/// look like something happening rather than something scheduled:
///
///  * **Blast.** A ragged hole opens from a point near the bubble's centre
///    and races outward along a noise-bent edge. Where it passes, the
///    picture breaks: irregular shards tumble off whole and crumble a beat
///    later, the rest goes as loose grit, all of it shrinking to motes and
///    caught by a curl-noise wind that makes the cloud curl round itself
///    instead of flying apart in straight lines.
///  * **Hurricane.** Under the cloud a vacuum spins up: a point sink at the
///    drain with a vortex round the axis. Each mote is caught at its own
///    moment and follows the air at its own pace, and when it actually
///    arrives it docks into a tall spinning column standing on the drain —
///    so the column builds up as the motes come in, not all at once. The
///    column is a rope, not a cylinder: its axis sways, its walls breathe,
///    and its motes glitter as they turn.
///  * **Drawn off.** Before the column is finished, a nozzle off to the
///    side — right for your own message, left for anybody else's — starts
///    taking it from the top: a suction front descends the column, and
///    every mote it passes lets go and rides one arc, up the axis and over
///    into the nozzle, spiralling round it while the wind frays the stream
///    into a plume. Motes still arriving dock below the front and feed the
///    stream; a mote that docks where the front has already been is taken at
///    once.
///
/// Only once the last mote is gone does the row's height close, so nothing
/// below moves until there is nothing left to watch.
///
/// It is the bubble's actual pixels that fly: one `drawRawAtlas` per frame
/// over the capture, with a source rect per grain. Nothing is read back and
/// nothing is allocated per frame — every grain lives in flat buffers sized
/// once, and the painter repaints on a notifier the ticker bumps, so no
/// widget rebuilds while it runs. On a dark ground the motes are drawn from
/// a lifted copy of the capture, so dust from a dark bubble still reads.
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

  /// Grains per bubble, at most. A wide bubble gets bigger grains rather
  /// than more of them.
  static const int maxTiles = MessageDepartures.maxTiles;

  @override
  State<DepartingRow> createState() => _DepartingRowState();
}

class _DepartingRowState extends State<DepartingRow>
    with SingleTickerProviderStateMixin {
  /// The row's height factor: 1 for the whole flight, then 1 → 0.
  final ValueNotifier<double> _height = ValueNotifier<double>(1);

  /// The grains are painted in the ROOT overlay, above the composer, the
  /// app bar and anything else a row in the list sits under — a bubble
  /// blowing apart over the transcript must not disappear behind the text
  /// field. The follower keeps the painting pinned to the row as the list
  /// scrolls, through a layer transform rather than a rebuild.
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();

  /// Bumped per tick; the grain painter repaints on it.
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
    _portal.show();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The field is cut here rather than in initState: whether the motes
    // need lifting off a dark ground is the theme's to say.
    if (_instant || _field != null) return;
    _field = _TileField(
      widget.capture,
      liftDark: Theme.of(context).brightness == Brightness.dark,
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _field?.dispose();
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

/// The bubble cut into grains, and where each of them is right now.
///
/// Positions are in the ROW's coordinates. Buffers are allocated once here
/// and mutated in place by [step], which also compacts the render buffers
/// so the painter is handed them straight. The column and the stream are
/// closed forms of the time, per grain; only the loose cloud integrates,
/// against a clamped frame time.
class _TileField {
  _TileField(this.capture, {required bool liftDark})
      : image = capture.image! {
    final size = capture.bubbleSize;
    final w = size.width;
    final h = size.height;
    // Bigger grains on a bigger bubble, never more than the cap: a whole
    // paragraph coming apart should cost what a one-liner does. Never under
    // two pixels, which the eye could not separate anyway.
    tile = math.max(
      2.0,
      math.sqrt(w * h / math.min(capture.tiles, DepartingRow.maxTiles)),
    );
    final cols = (w / tile).ceil();
    final rows = (h / tile).ceil();
    final pr = capture.pixelRatio;
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    tilePx = tile * pr;
    final origin = capture.bubbleInRow;
    side = capture.isMine ? 1 : -1;
    centre = origin + Offset(w / 2, h / 2);
    drain = centre - const Offset(0, 6);
    // A hurricane stands taller than the bubble it came from, and its mouth
    // is a good part of the bubble's width.
    funnelHeight = (h * 1.8).clamp(120.0, 220.0);
    funnelMouth = (w * 0.16).clamp(22.0, 44.0);
    // Where the stream arcs over, a little above the column's top, and the
    // nozzle it bends toward: off to the side at that height, so the stream
    // leaves the row — and, for a bubble at the edge, the screen — sideways.
    corner = drain - Offset(0, funnelHeight + 36);
    nozzle = Offset(drain.dx + side * 340, corner.dy);

    final rand = math.Random(capture.message.id.hashCode);
    _nu = rand.nextDouble();
    _nv = rand.nextDouble();
    _rope = rand.nextDouble();
    // The blast's heart: near the middle, never dead on it.
    blast = centre +
        Offset(
          (rand.nextDouble() - 0.5) * w * 0.3,
          (rand.nextDouble() - 0.5) * h * 0.3,
        );

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
    mote = Float32List(n);
    gust = Float32List(n);
    release = Float32List(n);
    lvl = Float32List(n);
    seatR = Float32List(n);
    leaveAt = Float32List(n);
    travel = Float32List(n);
    px0 = Float32List(n);
    py0 = Float32List(n);
    phi = Float32List(n);
    tPull = Float32List(n);
    tOff = Float32List(n);
    spread = Float32List(n);
    chunk = Int32List(n);
    relX = Float32List(n);
    relY = Float32List(n);
    state = Uint8List(n);
    transforms = Float32List(n * 4);
    spriteRects = Float32List(n * 4);
    colors = Int32List(n);

    // The radius the front has to cover, from the blast's heart to the
    // furthest corner.
    var reach = 1.0;
    for (final corner in [
      origin,
      origin + Offset(w, 0),
      origin + Offset(0, h),
      origin + Offset(w, h),
    ]) {
      reach = math.max(reach, (corner - blast).distance);
    }

    // The shards: seeds scattered over the bubble, every grain joining the
    // nearest one by a noise-warped distance, so a shard's edge wanders the
    // way a crack does rather than running along the grid. About sixty
    // grains to a shard; a bubble of a few hundred grains still breaks in
    // several pieces.
    final seeds = (n / 60).ceil().clamp(4, 120);
    final sx = Float32List(seeds), sy = Float32List(seeds);
    for (var s = 0; s < seeds; s++) {
      sx[s] = origin.dx + rand.nextDouble() * w;
      sy[s] = origin.dy + rand.nextDouble() * h;
    }
    final warp = math.max(6.0, math.sqrt(w * h / seeds) * 0.45);
    chunks = seeds;
    ccx = Float32List(seeds);
    ccy = Float32List(seeds);
    cvx = Float32List(seeds);
    cvy = Float32List(seeds);
    crot = Float32List(seeds);
    cspin = Float32List(seeds);
    cfree = Float32List(seeds);
    cfrom = Float32List(seeds);
    final members = Int32List(seeds);
    for (var i = 0; i < n; i++) {
      DustFlow.sample(hx[i] / 41 + _nu, hy[i] / 41 + _nv);
      final qx = hx[i] + DustFlow.x * warp;
      final qy = hy[i] + DustFlow.y * warp;
      var best = 0;
      var bestD = double.infinity;
      for (var s = 0; s < seeds; s++) {
        final dx = qx - sx[s], dy = qy - sy[s];
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = s;
        }
      }
      chunk[i] = best;
      ccx[best] += hx[i];
      ccy[best] += hy[i];
      members[best]++;
    }

    // The front: distance from the heart, bent by a coarse field so the
    // hole tears open in lobes, not as a growing circle.
    double front(double px, double py) {
      final d = (Offset(px, py) - blast).distance / reach;
      DustFlow.sample(px / 90 + _nv + 0.5, py / 90 + _nu + 0.5);
      return _blastSpan * math.pow(d, 0.85) + _blastBend * (DustFlow.x + 1);
    }

    for (var s = 0; s < seeds; s++) {
      final m = math.max(1, members[s]);
      ccx[s] /= m;
      ccy[s] /= m;
      // Two in five shards are not shards at all: their grains go one by
      // one, as grit. The rest hold together for a beat, tumbling.
      final loose = rand.nextDouble() < 0.4;
      cfrom[s] = front(ccx[s], ccy[s]);
      cfree[s] = loose ? 0 : 0.07 + 0.28 * rand.nextDouble();
      var dx = ccx[s] - blast.dx, dy = ccy[s] - blast.dy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 0.5) {
        dx = 0;
        dy = -1;
      } else {
        dx /= d;
        dy /= d;
      }
      final v = rand.nextDouble();
      final speed = 40 + 230 * v * v;
      cvx[s] = dx * speed + (rand.nextDouble() - 0.5) * 70;
      cvy[s] = dy * speed + (rand.nextDouble() - 0.5) * 70 - 25;
      // Rad/s, either way.
      cspin[s] = (rand.nextDouble() * 2 - 1) * 4.5;
    }

    for (var i = 0; i < n; i++) {
      x[i] = hx[i];
      y[i] = hy[i];
      rnd[i] = rand.nextDouble();
      final c = chunk[i];
      relX[i] = hx[i] - ccx[c];
      relY[i] = hy[i] - ccy[c];
      // A loose grain goes at its own place on the front, frayed a little;
      // a shard's grains go together, with their shard.
      release[i] = cfree[c] == 0
          ? front(hx[i], hy[i]) + rand.nextDouble() * 0.05
          : cfrom[c];
      // The mote it ends as, in logical pixels: most of them fine, a few
      // coarse — never bigger than the grain it was cut from.
      final m = 1.0 + 1.9 * math.pow(rand.nextDouble(), 1.6);
      mote[i] = math.min(1.0, m / tile);
      gust[i] = 50 + 120 * rand.nextDouble();
      rotV[i] = (rand.nextDouble() * 2 - 1) * 5;
      // Its seat in the hurricane: how far up the column it will sit (0 the
      // foot, 1 the top — weighted upward, a twister is heavy at the mouth)
      // and how far out from the axis, between the inner and outer wall.
      final seat = math.pow(rand.nextDouble(), 0.7).toDouble();
      lvl[i] = seat;
      seatR[i] = _funnelRadius(seat) * (0.45 + 0.55 * rand.nextDouble());
      phi[i] = rand.nextDouble();
      // When the vacuum gets hold of it — every mote at its own moment, so
      // the cloud folds in ragged, and never before it has had a moment of
      // its own in the air — a little jitter on when the front takes it,
      // and how long its ride to the nozzle takes, in seconds.
      tPull[i] = math.max(
        release[i] + 0.2,
        _vacuumFrom + 0.9 * math.pow(rand.nextDouble(), 1.4),
      );
      leaveAt[i] = rand.nextDouble() * 0.06;
      travel[i] = 0.55 + 0.25 * rand.nextDouble();
      spread[i] = (rand.nextDouble() - 0.5) * 2;
      scale[i] = 1;
      alpha[i] = 1;
    }

    // The lifted copy doubles the capture; past [_liftMaxPixels] (a tall
    // bubble, a big photo) the motes keep the capture's own ink instead of
    // asking a small phone for a texture that size.
    if (liftDark && image.width * image.height <= _liftMaxPixels) {
      final hot = _lift(image);
      if (hot != null) {
        lifted = hot;
        hotDx = image.width.toDouble();
      }
    }
    step(Duration.zero, 0);
  }

  final DepartureCapture capture;

  /// The capture, or — on a dark ground — the capture with a lifted copy
  /// beside it, [hotDx] device pixels to the right. Motes draw from the
  /// copy, the grains still at home from the original.
  final ui.Image image;
  ui.Image? lifted;
  double hotDx = -1;

  ui.Image get atlas => lifted ?? image;

  late final double tile;
  late final double tilePx;
  late final Offset centre, blast;
  late final double side;
  late final int count;

  /// Where the noise is read for this message: its own patch of the wind,
  /// and its own phase of the rope's sway.
  late final double _nu, _nv, _rope;

  late final Float32List hx, hy, src;
  late final Float32List x, y, vx, vy, rot, rotV, rnd;
  late final Float32List th, scale, alpha;

  /// Per grain: the mote it shrinks to (a share of the grain), how hard the
  /// wind takes it, and when the blast lets it go (seconds).
  late final Float32List mote, gust, release;

  /// The shards: each grain's shard and its place in it; each shard's
  /// centre, drift, angle, tumble, when it lets go and how long it holds.
  late final int chunks;
  late final Int32List chunk;
  late final Float32List relX, relY;
  late final Float32List ccx, ccy, cvx, cvy, crot, cspin, cfree, cfrom;

  /// The hurricane: each mote's level up the column and its radius there,
  /// and its ride out: when it leaves (as a fraction of the last beat), how
  /// long the ride takes (likewise), where it left from, the phase of the
  /// spiral it rides in, and where in the plume's width it lands.
  late final Float32List lvl, seatR;
  late final Float32List leaveAt, travel, px0, py0, phi, spread;

  /// When the vacuum catches each mote, and when it left the column.
  late final Float32List tPull, tOff;

  /// 0 at home, 1 in its shard, 2 loose in the air, 3 docked in the column,
  /// 4 riding the stream, 5 gone.
  late final Uint8List state;

  /// Every grain has reached the nozzle.
  bool get allGone => _gone >= count;
  int _gone = 0;

  /// The drain: where the column stands, a touch above the bubble's centre.
  late final Offset drain;

  /// Where the stream arcs over, and where it is finally drawn to.
  late final Offset corner, nozzle;

  /// How tall the column stands over the drain, and how wide its mouth is.
  late final double funnelHeight, funnelMouth;

  /// Render buffers, compacted each step: the first [alive] entries are the
  /// grains to draw.
  late final Float32List transforms, spriteRects;
  late final Int32List colors;
  int alive = 0;

  bool _spinPrimed = false;

  /// The blast, in seconds: how long the front takes to cross from the
  /// heart to the furthest corner, and how far the noise bends it.
  static const double _blastSpan = 0.42;
  static const double _blastBend = 0.035;

  /// The timeline, in seconds. The vacuum starts spinning up while the
  /// blast is still drifting; the front starts down the column before it
  /// has finished forming. Overlaps on purpose.
  static const double _vacuumFrom = 0.35;
  static const double _vacuumFull = 1.25;
  static const double _frontFrom = 1.3;
  static const double _frontTo = 3.0;

  /// A cone, narrow at the foot: the column's radius at [level] (0..1).
  double _funnelRadius(double level) =>
      2.5 + (funnelMouth - 2.5) * math.pow(level, 1.5);

  /// The side view of a circle: how much of the orbit's depth shows as
  /// height. A twister seen from the ground is a stack of these ellipses.
  static const double _squash = 0.3;

  /// The column's axis at [level], [t] seconds in: a rope, swaying more the
  /// higher it is, a wave climbing it.
  double _axisX(double level, double t) =>
      drain.dx +
      (2 + 15 * level * level) * DustTrig.sin(level * 0.8 - t * 0.45 + _rope);

  static const int _liftMaxPixels = 1600000;

  /// Lets go of the lifted copy.
  void dispose() {
    lifted?.dispose();
    lifted = null;
  }

  /// The capture beside a brighter copy of itself with its blacks raised to
  /// a soft cool grey, the copy [ui.Image.width] to the right. Null when it
  /// could not be made, in which case the motes keep the capture's own ink.
  static ui.Image? _lift(ui.Image capture) {
    try {
      final w = capture.width, h = capture.height;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(capture, Offset.zero, Paint());
      canvas.drawImage(
        capture,
        Offset(w.toDouble(), 0),
        Paint()..colorFilter = const ColorFilter.matrix(_hot),
      );
      final picture = recorder.endRecording();
      final image = picture.toImageSync(w * 2, h);
      picture.dispose();
      return image;
    } catch (_) {
      return null;
    }
  }

  static const List<double> _hot = [
    1.1, 0, 0, 0, 60, //
    0, 1.1, 0, 0, 57, //
    0, 0, 1.1, 0, 68, //
    0, 0, 0, 1, 0,
  ];

  /// Lets grain [i] go into the air at [t] with the velocity it was given.
  void _loose(int i, double t, double gx, double gy) {
    state[i] = 2;
    vx[i] = gx;
    vy[i] = gy;
    release[i] = t;
  }

  /// Advances every grain to [elapsed] and refills the render buffers.
  void step(Duration elapsed, double dt) {
    final t = elapsed.inMicroseconds / 1e6;
    if (!_spinPrimed) {
      _spinPrimed = true;
      // Each grain's angle round the axis starts where it sits in the
      // bubble, so its seat in the column is on its own side.
      for (var i = 0; i < count; i++) {
        th[i] = math.atan2(y[i] - drain.dy, x[i] - drain.dx) / (2 * math.pi);
      }
    }
    // The air winds up gently; the column stands up as it fills; the front
    // walks down the column from the top.
    final spin = dustSmooth((t - _vacuumFrom) / (_vacuumFull - _vacuumFrom));
    final grow = dustSmooth((t - 0.3) / 1.0);
    final front =
        1 - ((t - _frontFrom) / (_frontTo - _frontFrom)).clamp(0.0, 1.0);
    final sucking = t >= _frontFrom;
    // The blast's own drag — light, so the cloud spreads before it is caught.
    final blastDrag = math.exp(-1.2 * dt);
    final glint = (t * 22).floor();

    // The shards drift and tumble as wholes until they crumble.
    for (var s = 0; s < chunks; s++) {
      if (t < cfrom[s]) continue;
      DustFlow.sample(ccx[s] / 52 + _nu + t * 0.2, ccy[s] / 52 + _nv);
      cvx[s] = cvx[s] * blastDrag + DustFlow.x * 140 * dt;
      cvy[s] = cvy[s] * blastDrag + (DustFlow.y * 140 - 30) * dt;
      ccx[s] += cvx[s] * dt;
      ccy[s] += cvy[s] * dt;
      crot[s] += cspin[s] * dt;
    }

    for (var i = 0; i < count; i++) {
      switch (state[i]) {
        case 5:
          continue;

        case 0:
          // ── At home, until the front reaches it ──
          if (t < release[i]) continue;
          final c = chunk[i];
          if (cfree[c] > 0) {
            state[i] = 1;
          } else {
            var dx = hx[i] - blast.dx, dy = hy[i] - blast.dy;
            final d = math.sqrt(dx * dx + dy * dy) + 0.001;
            dx /= d;
            dy /= d;
            final v = rnd[i];
            final speed = 30 + 260 * v * v;
            _loose(
              i,
              t,
              dx * speed + spread[i] * 60,
              dy * speed + (rnd[(i * 7) % count] - 0.5) * 90 - 20,
            );
          }
          continue;

        case 1:
          // ── Riding its shard ──
          final c = chunk[i];
          final a = crot[c] / (2 * math.pi);
          final ca = DustTrig.cos(a), sa = DustTrig.sin(a);
          x[i] = ccx[c] + relX[i] * ca - relY[i] * sa;
          y[i] = ccy[c] + relX[i] * sa + relY[i] * ca;
          rot[i] = crot[c] / (2 * math.pi);
          scale[i] = 1;
          alpha[i] = 1;
          if (t >= cfrom[c] + cfree[c] * (0.85 + 0.3 * rnd[i])) {
            // It crumbles: each grain carries on from the shard's drift and
            // its own share of the tumble, a little off both.
            final w = cspin[c];
            final ox = x[i] - ccx[c], oy = y[i] - ccy[c];
            _loose(
              i,
              t,
              cvx[c] - oy * w + spread[i] * 35,
              cvy[c] + ox * w + (rnd[i] - 0.5) * 35,
            );
          }
          continue;

        case 4:
          // ── Riding the stream ──
          final p = ((t - tOff[i]) / travel[i]).clamp(0.0, 1.0);
          // Sucked, not carried: slow to let go, then away.
          final q = Curves.easeInQuad.transform(p);
          // One arc: up the axis from where it let go, over at the top, and
          // into the nozzle — a quadratic through the corner, so the bend is
          // a curve, not an elbow. Each mote lands somewhere in the mouth.
          final ax = px0[i], ay = py0[i];
          final cx = _axisX(1, tOff[i]), cy = corner.dy;
          final nx = nozzle.dx, ny = nozzle.dy + spread[i] * 26;
          final mu = 1 - q;
          final bx = mu * mu * ax + 2 * mu * q * cx + q * q * nx;
          final by = mu * mu * ay + 2 * mu * q * cy + q * q * ny;
          var tx = 2 * mu * (cx - ax) + 2 * q * (nx - cx);
          var ty = 2 * mu * (cy - ay) + 2 * q * (ny - cy);
          final tl = math.sqrt(tx * tx + ty * ty);
          if (tl > 0.001) {
            tx /= tl;
            ty /= tl;
          }
          // It keeps circling the line it rides, tighter and faster the
          // further along — and the wind frays the stream into a plume.
          phi[i] += (3.0 + 3.0 * q) * dt;
          final helix = (seatR[i] * 0.8 + 5) * (1 - 0.7 * q);
          final across = helix * DustTrig.cos(phi[i]);
          final depth = helix * DustTrig.sin(phi[i]) * 0.45;
          DustFlow.sample(bx / 64 + _nu + t * 0.3, by / 64 + _nv - t * 0.2);
          final fray = 30 * q * (0.5 + rnd[i]);
          x[i] = bx - ty * across + DustFlow.x * fray;
          y[i] = by + tx * across + depth + DustFlow.y * fray;
          scale[i] = mote[i] * (1 - 0.45 * q);
          final fade = 0.66 + 0.2 * rnd[i];
          alpha[i] = (p < fade ? 1 : 1 - dustSmooth((p - fade) / (1 - fade))) *
              (0.72 + 0.28 * dustHash(i, glint));
          if (p >= 1) {
            state[i] = 5;
            _gone++;
          }
          continue;

        case 3:
          // ── Standing in the column ──
          final l = lvl[i];
          th[i] += (1.6 + 0.8 * rnd[i] + 0.8 * l) * dt;
          // The wall breathes: each mote's radius swells and shrinks on a
          // wave that runs round the column.
          final r = seatR[i] *
              (1 + 0.22 * DustTrig.sin(th[i] * 3 + t * 0.6 + rnd[i]));
          x[i] = _axisX(l, t) + r * DustTrig.cos(th[i]);
          y[i] = drain.dy -
              funnelHeight * l * grow +
              r * DustTrig.sin(th[i]) * _squash +
              2.5 * DustTrig.sin(t * 0.9 + rnd[i] * 7);
          scale[i] = mote[i];
          // The far side of the turn is dimmer, and every mote glints.
          final near = 0.75 + 0.25 * DustTrig.sin(th[i]);
          alpha[i] = near * (0.7 + 0.3 * dustHash(i, glint));
          // The front has reached its level: it lets go from wherever it
          // is on its ring.
          if (sucking && l >= front - leaveAt[i]) {
            state[i] = 4;
            px0[i] = x[i];
            py0[i] = y[i];
            phi[i] = th[i];
            tOff[i] = t;
          }
          continue;

        default:
          // ── Loose: the blast, then the air ──
          //
          // Dust in moving air. The air is a point sink at the drain (slow
          // far out, fierce close in) with a vortex round the axis that is
          // strongest around where the blast left the cloud and weaker
          // inward — so the cloud shears into arms as it comes in — and a
          // curl-noise wind of its own, so the arms curl round each other
          // instead of running in parallel. The mote's velocity RELAXES
          // toward the air's, at a rate that rises with the vacuum and is
          // its own: before the air moves it rides the wind and what the
          // blast gave it. Worked out in the frame where the orbit is a
          // circle (the side view's squash undone) so the whirl never leaks
          // outward, and mapped back.
          final axisX = _axisX(lvl[i], t);
          final axisY = drain.dy - funnelHeight * lvl[i] * grow;
          final dx = x[i] - axisX;
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
          DustFlow.sample(
            x[i] / 46 + _nu + t * 0.21,
            y[i] / 46 + _nv - t * 0.13,
          );
          final g = gust[i] * (1.2 - 0.5 * spin);
          ufx += DustFlow.x * g;
          ufy += DustFlow.y * g - 18 * (1 - spin);
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
            sx = axisX + seatR[i] * c;
            sy = axisY + seatR[i] * sn * _squash;
            // The seat is moving — the column turns under it — so the
            // velocity that carries the mote onto it includes the seat's
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
          rot[i] += rotV[i] * (1 - spin) * dt / (2 * math.pi);
          // From grain to mote over its first third of a second loose.
          final shrink = dustSmooth((t - release[i]) / 0.32);
          scale[i] = 1 + (mote[i] - 1) * shrink;
          alpha[i] = 1 - 0.25 * shrink * dustHash(i, glint);
          // Arrived: it docks, and the column is one mote thicker. A mote
          // the air has held for long enough is seated regardless — the
          // column must not wait on a straggler.
          if (caught > 0.5) {
            final gx = sx - x[i];
            final gy = sy - y[i];
            if (gx * gx + gy * gy < 64 || t > tPull[i] + 1.8) {
              state[i] = 3;
            }
          }
      }
    }

    // Fill the render buffers.
    final pr = capture.pixelRatio;
    final half = tilePx / 2;
    final home = capture.bubbleInRow;
    var k = 0;
    for (var i = 0; i < count; i++) {
      final st = state[i];
      if (st == 5) continue;
      final a = st == 0 ? 1.0 : alpha[i];
      if (a < 0.02) continue;
      final o = k * 4;
      final so = i * 4;
      if (st == 0) {
        // Still part of the picture: exactly where it was, so the unbroken
        // part of the bubble reads as the bubble to the last.
        final s = 1 / pr;
        transforms[o] = s;
        transforms[o + 1] = 0;
        transforms[o + 2] = home.dx + src[so] * s;
        transforms[o + 3] = home.dy + src[so + 1] * s;
      } else {
        final sc = scale[i] / pr;
        final scos = sc * DustTrig.cos(rot[i]);
        final ssin = sc * DustTrig.sin(rot[i]);
        transforms[o] = scos;
        transforms[o + 1] = ssin;
        transforms[o + 2] = x[i] - scos * half + ssin * half;
        transforms[o + 3] = y[i] - ssin * half - scos * half;
      }
      // A mote (anything past its shard) draws from the lifted copy when
      // there is one.
      final hot = st >= 2 && hotDx >= 0 ? hotDx : 0.0;
      spriteRects[o] = src[so] + hot;
      spriteRects[o + 1] = src[so + 1];
      spriteRects[o + 2] = src[so + 2] + hot;
      spriteRects[o + 3] = src[so + 3];
      colors[k] = ((a * 255).round() << 24) | 0xFFFFFF;
      k++;
    }
    alive = k;
  }
}

/// Draws the grains — one `drawRawAtlas` over the capture per frame.
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
      atlas: field.atlas,
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
