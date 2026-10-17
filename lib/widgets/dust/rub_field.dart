import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../theme/perf_tier.dart';
import 'dust_kit.dart';
import 'spoiler_dust.dart';

/// What [RubField] needs to know about the hole a finger is rubbing: the
/// discs it has laid, how wide its brush is, how clear any spot is, and,
/// while it heals, the wind and the range its front sweeps.
///
/// A picture's rub (`media_spoiler.dart`) and a line of text's wipe
/// (`spoiler_veil.dart`) keep their holes differently; each answers this.
abstract interface class RubHole {
  int get discs;
  double discX(int j);
  double discY(int j);
  double discR(int j);

  /// The brush's radius: where the rim is when no disc is near the finger.
  double get rimRadius;

  /// How clear the hole is at ([x], [y]), 0..1.
  double clearedAt(double x, double y);

  bool get healing;
  Offset get healWind;
  double get healPMin;
  double get healPadding;
  double get healSpan;
}

/// The rub's living dust: what the text spoiler does under a finger, kept
/// alive on its own rather than in the field it rubs.
///
/// A picture's ambient field ([SpoilerDust]) is closed form, a function of
/// the clock with no state, which is what lets a chat of sealed pictures cost
/// one table. It cannot carry a grain that was thrown. A line of text's field
/// can, but its motes belong to their line and die the moment they leave it,
/// so a wipe there only parts the dust. This is the stepped half, made with
/// the rub and alive only while it has something to move:
///
/// * **While the finger is down** (moving or not) grains boil off the rim of
///   the hole around it, are thrown outward by the fingertip's draught (the
///   text's: an acceleration, scattered rather than radial, with turbulence
///   that keeps changing) and carried off on a curling wind, fading over a
///   life of their own. The hole's edge is that dust, not a feather.
/// * **When it heals** (if asked to, [prepareHeal]), the text's heal: each
///   grain gets a home inside the hole and a moment keyed to when the healing
///   front reaches it, and arrives on the front's wind from a little upwind,
///   landing as its kick dies away.
///
/// Fixed buffers, nothing allocated per step; one `drawRawAtlas` to paint.
class RubField {
  RubField(
    this.area,
    this.dpr, {
    double emitRate = defaultEmitRate,
    this.inkRgb = 0xFFFFFF,
    this.edgeFade = 0,
    this.rimMin = 0.72,
    this.rimSpan = 0.5,
    this.discShare = 0.4,
    int? grains,
  })  : capacity = grains != null ? Perf.particles(grains) : capacityFor(dpr),
        // Scaled with the capacity, so a low-tier phone's field is as full,
        // just of fewer grains.
        emitRate = Perf.particles(emitRate.round()).toDouble() {
    x = Float32List(capacity);
    y = Float32List(capacity);
    vx = Float32List(capacity);
    vy = Float32List(capacity);
    kx = Float32List(capacity);
    ky = Float32List(capacity);
    age = Float32List(capacity);
    life = Float32List(capacity);
    grain = Float32List(capacity);
    peak = Float32List(capacity);
    rnd = Float32List(capacity);
    homeX = Float32List(capacity);
    homeY = Float32List(capacity);
    upwind = Float32List(capacity);
    stagger = Float32List(capacity);
    state = Uint8List(capacity);
    sparkle = Uint8List(capacity);
    transforms = Float32List(capacity * 4);
    spriteRects = Float32List(capacity * 4);
    colors = Int32List(capacity);
    final px = DustSprite.pxFor(dpr).toDouble();
    for (var k = 0; k < capacity; k++) {
      spriteRects[k * 4 + 2] = px;
      spriteRects[k * 4 + 3] = px;
    }
    final floor = SpoilerGrain.floorFor(dpr);
    for (var i = 0; i < capacity; i++) {
      rnd[i] = _rand.nextDouble();
      if (SpoilerGrain.pick(_rand, floor, grain, peak, i)) sparkle[i] = 1;
    }
  }

  /// Where a grain may be: one that leaves this (and a few px) is gone.
  final Rect area;
  final double dpr;

  /// Grains boiled off per second under a finger.
  final double emitRate;

  /// The dust's colour, as `0xRRGGBB`: white over a picture, the ink over
  /// text.
  int inkRgb;

  /// How far inside [area]'s edge a grain starts fading out, in px. Zero
  /// for a picture, whose edge is a clip that hides the cut anyway; over
  /// text the edge is open bubble, where a grain winking out would show.
  final double edgeFade;

  /// Where on a rim a grain is born, as a share of the rim's radius: from
  /// [rimMin] to [rimMin] + [rimSpan]. And how often it is born on one of
  /// the hole's recent discs rather than round the fingertip itself.
  final double rimMin;
  final double rimSpan;
  final double discShare;

  /// Grains this field can hold. At the shared rate a held finger keeps
  /// about 1100 alive, so this is that and a heal's worth of headroom.
  /// Lower on a lower-density screen, which is where the older, slower
  /// devices are: fewer grains on fewer pixels read the same. Buffers are
  /// made once at this size and reused for the field's life.
  final int capacity;

  static int capacityFor(double dpr) =>
      Perf.particles(dpr < 2.5 ? 1400 : 1800);

  /// A picture's rate, for its brush. One shared setting for pictures and
  /// text alike, set halfway between the text's old wipe (which threw only
  /// the motes already there, so barely boiled) and the picture's first
  /// boil (2600/s, which was the loudest the dust had been).
  static const double defaultEmitRate = 1500;

  /// The draught's reach and push, between the text field's (34) and the
  /// picture's first boil (52); its strength is the text field's.
  static const double kickDecay = 3.5;
  static const double draughtRadius = 44;
  static const double draughtAccel = 2600;

  /// How hard a grain is thrown off the rim, px/s: a floor and a spread.
  static const double throwMin = 45;
  static const double throwSpread = 130;

  /// A boiled grain's life, s: a floor and a spread.
  static const double boilLifeMin = 0.4;
  static const double boilLifeSpread = 0.65;

  /// How much brighter and bigger a boiled grain is than the resting dust:
  /// it is what the eye follows off the finger.
  static const double boilBrightness = 1.6;
  static const double boilSize = 1.15;

  /// The curling wind the thrown grains ride: [DustFlow]'s divergence-free
  /// field, slowly drifting, at this many px/s at its strongest gust.
  static const double gust = 55;
  static const double gustScale = 160;

  final math.Random _rand = math.Random(0xD057);
  late final Float32List x, y, vx, vy, kx, ky, age, life, grain, peak, rnd;
  late final Float32List homeX, homeY, upwind, stagger;

  /// 0 dead, 1 alive, 2 waiting on the healing front.
  late final Uint8List state, sparkle;

  /// Boiled off the rim (rather than blown in by a heal): drawn brighter and
  /// a touch bigger, since it is what the eye follows off the finger.
  late final Uint8List _boiled = Uint8List(capacity);
  late final Float32List transforms, spriteRects;
  late final Int32List colors;
  int alive = 0;
  int _cursor = 0;
  double _carry = 0;
  int _busy = 0;

  /// Anything alive or still to arrive.
  bool get busy => _busy > 0;

  Offset _healWind = const Offset(1, 0);

  /// A free slot, or -1. Round-robin, so a long rub recycles the oldest
  /// grains' slots first rather than scanning from zero every birth.
  int _free() {
    for (var n = 0; n < capacity; n++) {
      final i = _cursor;
      _cursor = (_cursor + 1) % capacity;
      if (state[i] == 0) return i;
    }
    return -1;
  }

  void _launch(int i, {required double minLife, required double spanLife}) {
    final heading = _rand.nextDouble();
    final speed = SpoilerGrain.speed(_rand);
    vx[i] = DustTrig.cos(heading) * speed;
    vy[i] = DustTrig.sin(heading) * speed;
    life[i] = minLife + _rand.nextDouble() * spanLife;
    age[i] = 0;
    state[i] = 1;
  }

  /// One grain off the rim around [at]: on the brush's edge, or on the edge
  /// of one of the discs the finger has already laid near it, thrown out.
  void _emit(Offset at, RubHole rub) {
    final i = _free();
    if (i < 0) return;
    double cx = at.dx, cy = at.dy, r = rub.rimRadius;
    if (rub.discs > 0 && _rand.nextDouble() < discShare) {
      // A disc near the finger: the most recent few, so the boil follows
      // the stroke rather than flickering over the whole hole.
      final j = rub.discs - 1 - _rand.nextInt(math.min(rub.discs, 24));
      cx = rub.discX(j);
      cy = rub.discY(j);
      r = rub.discR(j);
    }
    final a = _rand.nextDouble();
    final ex = DustTrig.cos(a), ey = DustTrig.sin(a);
    final d = r * (rimMin + _rand.nextDouble() * rimSpan);
    x[i] = cx + ex * d;
    y[i] = cy + ey * d;
    _launch(i, minLife: boilLifeMin, spanLife: boilLifeSpread);
    _boiled[i] = 1;
    // Thrown off the rim: outward, scattered, at a pace that carries it a
    // thumb's width before the drift has it.
    final v = throwMin + _rand.nextDouble() * throwSpread;
    kx[i] = (ex + (_rand.nextDouble() - 0.5) * 0.9) * v;
    ky[i] = (ey + (_rand.nextDouble() - 0.5) * 0.9) * v;
  }

  /// Sets the dust up to blow back into the hole on its heal's wind, as many
  /// grains as the hole's area holds at [density] (grains per square px).
  void prepareHeal(RubHole rub, math.Random rand, {required double density}) {
    _healWind = rub.healWind;
    if (rub.discs == 0) return;
    // As many as the hole's area holds at the cover's density, and a few
    // more: it is what the eye watches arrive.
    var area = 0.0;
    var maxR = 0.0;
    for (var j = 0; j < rub.discs; j++) {
      final r = rub.discR(j);
      area += r * r * math.pi;
      maxR = math.max(maxR, r);
    }
    final want = math.min(capacity * 0.8, area * 0.55 * density * 1.4);
    final w = rub.healWind;
    final bounds = this.area;
    for (var n = 0; n < want; n++) {
      final i = _free();
      if (i < 0) break;
      // A point inside a disc, the bigger discs proportionally likelier.
      var j = rand.nextInt(rub.discs);
      for (var tries = 0; tries < 4; tries++) {
        if (rand.nextDouble() * maxR <= rub.discR(j)) break;
        j = rand.nextInt(rub.discs);
      }
      final ang = rand.nextDouble();
      final rr = math.sqrt(rand.nextDouble()) * rub.discR(j);
      final hx = rub.discX(j) + DustTrig.cos(ang) * rr;
      final hy = rub.discY(j) + DustTrig.sin(ang) * rr;
      if (hx < bounds.left ||
          hy < bounds.top ||
          hx > bounds.right ||
          hy > bounds.bottom) {
        continue;
      }
      homeX[i] = hx;
      homeY[i] = hy;
      final p = hx * w.dx + hy * w.dy;
      final whenFrontPasses =
          (p - (rub.healPMin - rub.healPadding)) / rub.healSpan;
      // A little BEFORE the front passes: the dust is what closes the hole,
      // so it has to be there first.
      stagger[i] =
          (whenFrontPasses - 0.05 - rand.nextDouble() * 0.1).clamp(0.0, 0.97);
      upwind[i] = 16 + rand.nextDouble() * 30;
      state[i] = 2;
    }
  }

  /// The dust a reveal's wavefront sweeps up between radii [from] and [to]
  /// around [center], [n] grains of it: thrown outward off the front and
  /// gone in a fraction of a second, as the text field's motes ahead of its
  /// front are.
  void burst(Offset center, double from, double to, int n) {
    final bounds = area;
    for (var k = 0; k < n; k++) {
      final i = _free();
      if (i < 0) return;
      final a = _rand.nextDouble();
      final ex = DustTrig.cos(a), ey = DustTrig.sin(a);
      final r = from + (to - from) * _rand.nextDouble();
      final px = center.dx + ex * r, py = center.dy + ey * r;
      if (px < bounds.left ||
          py < bounds.top ||
          px > bounds.right ||
          py > bounds.bottom) {
        continue;
      }
      x[i] = px;
      y[i] = py;
      _launch(i, minLife: 0.12, spanLife: 0.18);
      _boiled[i] = 0;
      // Outward, knocked off the line by a slant of its own: the text
      // field's 1400 out and 600 across, as a kick.
      final v = 120 + _rand.nextDouble() * 200;
      final slant = (_rand.nextDouble() - 0.5) * 0.9;
      kx[i] = (ex - ey * slant) * v;
      ky[i] = (ey + ex * slant) * v;
    }
  }

  /// Sets [n] grains up to arrive over the whole [area] on a wind front, as
  /// the text field's gather does: each with a home, a moment keyed to when
  /// the front ([wind], sweeping from [pMin] − [pad] across [span]) reaches
  /// it, a little before, and a run-up from upwind.
  void prepareGather(
    math.Random rand, {
    required Offset wind,
    required double pMin,
    required double pad,
    required double span,
    required int n,
  }) {
    _healWind = wind;
    final bounds = area;
    for (var k = 0; k < n; k++) {
      final i = _free();
      if (i < 0) break;
      final hx = bounds.left + rand.nextDouble() * bounds.width;
      final hy = bounds.top + rand.nextDouble() * bounds.height;
      homeX[i] = hx;
      homeY[i] = hy;
      final p = hx * wind.dx + hy * wind.dy;
      final whenFrontPasses = (p - (pMin - pad)) / span;
      stagger[i] =
          (whenFrontPasses - 0.06 - rand.nextDouble() * 0.12).clamp(0.0, 0.97);
      upwind[i] = 25 + rand.nextDouble() * 40;
      state[i] = 2;
    }
  }

  /// Whatever has not arrived yet arrives now.
  void endHeal() {
    for (var i = 0; i < capacity; i++) {
      if (state[i] == 2) _arrive(i, _healWind);
    }
  }

  /// Blown in from upwind, carrying a kick that lands it on its home as the
  /// kick dies: the text field's arrival.
  void _arrive(int i, Offset w) {
    _boiled[i] = 0;
    x[i] = homeX[i] - w.dx * upwind[i];
    y[i] = homeY[i] - w.dy * upwind[i];
    _launch(i, minLife: 0.7, spanLife: 1.1);
    final v = upwind[i] * kickDecay;
    final scatter = (rnd[i] - 0.5) * 40;
    kx[i] = w.dx * v - w.dy * scatter;
    ky[i] = w.dy * v + w.dx * scatter;
  }

  /// Advances every grain by [dt] and fills the render buffers. [emitFrom]
  /// is where the finger is while it should boil; [heal] how far the hole's
  /// heal has run, 0..1.
  void step(
    double dt, {
    required double time,
    required Offset? touch,
    required Offset? emitFrom,
    required RubHole? rub,
    required double heal,
  }) {
    if (emitFrom != null && rub != null) {
      _carry += emitRate * dt;
      while (_carry >= 1) {
        _carry -= 1;
        _emit(emitFrom, rub);
      }
    } else {
      _carry = 0;
    }
    final decay = math.exp(-kickDecay * dt);
    final tx = touch?.dx ?? 0, ty = touch?.dy ?? 0;
    final healing = rub != null && rub.healing;
    final l = area.left, t = area.top, r = area.right, b = area.bottom;
    final ink = inkRgb;
    final fade = edgeFade;
    var k = 0;
    var busy = 0;
    for (var i = 0; i < capacity; i++) {
      final st = state[i];
      if (st == 0) continue;
      busy++;
      if (st == 2) {
        if (!healing || heal < stagger[i]) continue;
        _arrive(i, _healWind);
      }
      var px = x[i], py = y[i];
      var ax = 0.0, ay = 0.0;
      if (touch != null) {
        // The draught, as the text field's: thrown, then coasting.
        final reach = draughtRadius * (0.6 + 0.8 * rnd[i]);
        final dx = px - tx, dy = py - ty;
        final d2 = dx * dx + dy * dy;
        if (d2 < reach * reach) {
          final d = math.sqrt(d2);
          final f = (1 - d / reach) * (1 - d / reach);
          var ex = d > 0.001 ? dx / d : 0.0;
          var ey = d > 0.001 ? dy / d : -1.0;
          ex += DustTrig.sin(rnd[i] * 0.9 + 0.25) * 0.9;
          ey += DustTrig.sin(rnd[i] * 0.9) * 0.9;
          final el = math.sqrt(ex * ex + ey * ey);
          if (el > 0.001) {
            ex /= el;
            ey /= el;
          }
          ax += ex * draughtAccel * f;
          ay += ey * draughtAccel * f;
          ax += DustTrig.sin(time * 0.43 + rnd[i] * 13) * draughtAccel * f * 0.5;
          ay += DustTrig.sin(time * 0.49 + rnd[i] * 17) * draughtAccel * f * 0.5;
        }
      }
      // The wind: curling gusts over the slow current every grain rides.
      DustFlow.sample(px / gustScale + time * 0.05, py / gustScale - time * 0.04);
      final fx = SpoilerGrain.flowX(px, py, time) + DustFlow.x * gust;
      final fy = SpoilerGrain.flowY(px, py, time) + DustFlow.y * gust;
      kx[i] = kx[i] * decay + ax * dt;
      ky[i] = ky[i] * decay + ay * dt;
      px += (vx[i] + fx + kx[i]) * dt;
      py += (vy[i] + fy + ky[i]) * dt;
      age[i] += dt;
      if (age[i] >= life[i] ||
          px < l - 4 ||
          py < t - 4 ||
          px > r + 4 ||
          py > b + 4) {
        state[i] = 0;
        busy--;
        continue;
      }
      x[i] = px;
      y[i] = py;
      final u = age[i] / life[i];
      // Quick in (it is thrown, not born in place), long out.
      final boiled = _boiled[i] == 1;
      var a = peak[i] * (boiled ? boilBrightness : 1.35);
      if (a > 1) a = 1;
      if (u < 0.12) a *= dustSmooth(u / 0.12);
      if (u > 0.45) a *= 1 - dustSmooth((u - 0.45) / 0.55);
      if (sparkle[i] == 1) a *= SpoilerGrain.twinkle(time, rnd[i]);
      // Over the open hole a grain is thinner, as dust over a window is: a
      // trace of it is what keeps the rim from reading as a cut.
      if (rub != null) {
        final open = rub.clearedAt(px, py) * (healing ? 1 - heal : 1);
        a *= 1 - 0.6 * open;
      }
      if (fade > 0) {
        final e = math.min(
          math.min(px - l, r - px),
          math.min(py - t, b - py),
        );
        if (e < fade) a *= e <= 0 ? 0 : dustSmooth(e / fade);
      }
      if (a < 0.02) continue;
      final s = boiled ? grain[i] * boilSize : grain[i];
      final sc = s / DustSprite.pxFor(dpr);
      final o = k * 4;
      transforms[o] = sc;
      transforms[o + 1] = 0;
      transforms[o + 2] = px - s / 2;
      transforms[o + 3] = py - s / 2;
      colors[k] = ((a * 255).round() << 24) | ink;
      k++;
    }
    alive = k;
    _busy = busy;
  }

  /// One `drawRawAtlas` for every grain alive.
  void paint(Canvas canvas) {
    if (alive == 0) return;
    DustAtlas.draw(
      canvas,
      sprite: DustSprite.forDpr(dpr),
      transforms: transforms,
      spriteRects: spriteRects,
      colors: colors,
      alive: alive,
    );
  }
}

/// Paints a [RubField] on [repaint]: decoration only, never hit.
class RubFieldPainter extends CustomPainter {
  RubFieldPainter({
    required this.field,
    required Listenable repaint,
    required this.dpr,
  }) : super(repaint: repaint);

  final RubField field;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) => field.paint(canvas);

  @override
  bool shouldRepaint(RubFieldPainter old) =>
      !identical(old.field, field) || old.dpr != dpr;

  @override
  bool hitTest(Offset position) => false;
}
