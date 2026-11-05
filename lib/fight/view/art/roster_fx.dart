// Effects and props for the roster (MOJO's banana peel, TANK's shockwave, NYX's
// shard / pool / puff / eclipse), ported from the roster lab's drawRosterFX,
// drawPeel and drawMoonShard. Everything draws around (0,0) in lab units; the
// caller translates / scales to the world position.
import 'dart:math' as math;
import 'dart:ui';

import 'art_common.dart';
import 'glow.dart';
import 'kai_rig.dart';
import 'roster_rig.dart';

class RosterFx {
  final RigPainter _rp = RigPainter();
  final Paint _f = Paint()..isAntiAlias = true;
  final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _plus = Paint()
    ..isAntiAlias = true
    ..blendMode = BlendMode.plus;

  static final Path _shard17 = shardPath(17), _shard11 = shardPath(11);

  void _begin(Canvas c, FightLook look) {
    _rp.c = c;
    _rp.look = look;
    _rp.sil = null;
  }

  // ---------------------------------------------------------------- MOJO

  /// Banana peel lying on the ground at the origin. [age] frames since placed,
  /// [alt] swaps to the alternate (player 2) tint.
  void peel(Canvas c, FightLook look, int age, {bool armed = true}) {
    _begin(c, look);
    final sq = age < 6 ? 1 - math.sin(age / 6 * math.pi) * .3 : 1.0;
    c.save();
    c.translate(0, -4);
    c.scale(1 / sq, sq);
    c.scale(1.35, 1.35);
    _rp.fill(mojoPeelPath, armed ? const Color(0xFFFFD23A) : const Color(0xFFE7C04A), const Rect.fromLTRB(-13, -9, 13, 4),
        lw: 1.8, shade: const Color(0xFFD99A1A), noHT: true);
    _rp.fill(ellP(0, -8.5, 1.6, 1.2), const Color(0xFF6B4A1A), const Rect.fromLTRB(-2, -10, 2, -7), noHT: true, lw: 1);
    c.restore();
    if (age < 14 && look != FightLook.pixel) {
      for (var i = 0; i < 4; i++) {
        final a = -math.pi / 2 + (i - 1.5) * .5, d = 8 + age * 1.6;
        c.drawCircle(Offset(math.cos(a) * d, -6 + math.sin(a) * d), 2 * (1 - age / 14) + .5, _f..shader = null..color = const Color(0xFFFFF6C0));
      }
    }
  }

  // ---------------------------------------------------------------- TANK

  /// Ground shockwave from the origin. [fwd] / [back] are how far (in lab
  /// units) it travels in front of and behind him.
  void quake(Canvas c, FightLook look, int age, int seed, {double fwd = 200, double back = 70}) {
    const d = 34;
    if (age > d || age < 0) return;
    final k = age / d;
    final r0 = SRand(seed);
    for (final dir in const [-1, 1]) {
      final range = dir > 0 ? fwd : back;
      final x = dir * (10 + k * range), h = (26 * (1 - k) + 4) * (dir > 0 ? 1 : .7);
      final wave = Path()
        ..moveTo(x - dir * 28, 0)
        ..quadraticBezierTo(x - dir * 8, -h, x, -h * .4)
        ..quadraticBezierTo(x + dir * 6, -h * .1, x + dir * 14, 0)
        ..close();
      if (look == FightLook.painted) {
        c.drawPath(wave, _plus..shader = null..style = PaintingStyle.fill..color = Color.fromRGBO(255, 200, 140, .55 * (1 - k)));
      } else {
        c.drawPath(wave, _f..shader = null..color = k < .6 ? const Color(0xFFD9CFE3) : const Color(0xFFA99CBC));
        if (look == FightLook.cartoon) c.drawPath(wave, _s..shader = null..strokeWidth = 2..color = kInk);
      }
      for (var i = 0; i < 4; i++) {
        final rx = dir * (20 + r0.next() * (range - 60) * k);
        final ry = -4 - math.sin(math.min(1.0, k * 2 + r0.next() * .3) * math.pi) * (14 + r0.next() * 30);
        final s = 2 + r0.next() * 3;
        final rect = Rect.fromLTWH(rx - s / 2, ry - s / 2, s, s);
        c.drawRect(rect, _f..shader = null..color = look == FightLook.painted ? const Color(0xE6786490) : const Color(0xFF4A3560));
        if (look == FightLook.cartoon) c.drawRect(rect, _s..strokeWidth = 1..color = kInk);
      }
    }
    if (age < 20) {
      final path = Path();
      for (var i = 0; i < 5; i++) {
        final a = (i - 2) * .32;
        path.moveTo(0, 1);
        path.lineTo(math.sin(a) * 40 * math.min(1.0, age / 6), 4 + math.cos(a) * 6);
      }
      c.drawPath(path, _s..shader = null..strokeWidth = 2..color = look == FightLook.painted ? const Color(0x99140A1E) : kInk);
    }
  }

  // ---------------------------------------------------------------- NYX

  /// Her shard travelling in +x. [age] frames since it spawned.
  void moonShard(Canvas c, FightLook look, int age) {
    final rot = -.5 + math.sin(age * .15) * .15;
    final paint = look == FightLook.painted;
    for (var i = 4; i >= 1; i--) {
      if (!paint && i > 2) continue;
      c.save();
      c.translate(-i * 13.0, math.sin((age - i * 3) * .2) * 3);
      c.rotate(rot);
      final p = shardPath(15.0 - i * 2);
      if (paint) {
        c.drawPath(p, _plus..shader = null..style = PaintingStyle.fill..color = Color.fromRGBO(196, 139, 255, .28 * (1 - i / 5)));
      } else {
        c.drawPath(p, _f..shader = null..color = const Color(0xFF7A3CC8));
      }
      c.restore();
    }
    c.save();
    c.rotate(rot);
    if (paint) {
      drawGlow(c, Offset.zero, 34, const Color(0xE6DCFAFF));
      drawGlow(c, Offset.zero, 22, const Color(0x8CC48BFF));
      drawGlow(c, Offset.zero, 18, const Color(0x669FF3FF));
    }
    c.drawPath(_shard17, _f..shader = null..color = paint ? const Color(0xFFF2EAFF) : const Color(0xFFC48BFF));
    if (!paint) c.drawPath(_shard11, _f..color = const Color(0xFF9FF3FF));
    if (look == FightLook.cartoon) c.drawPath(_shard17, _s..shader = null..strokeWidth = 2.4..color = kInk);
    c.restore();
  }

  /// Her shard breaking on contact / spawn flash.
  void moonBurst(Canvas c, FightLook look, int age, int seed, {double size = 1}) {
    const d = 20;
    if (age > d || age < 0) return;
    final k = age / d;
    final paint = look == FightLook.painted;
    final r0 = SRand(seed);
    c.drawCircle(
        Offset.zero,
        (14 + k * 50) * size,
        paint
            ? (_plus..shader = null..style = PaintingStyle.stroke..strokeWidth = (1 - k) * 6 + 1..color = Color.fromRGBO(196, 139, 255, 1 - k))
            : (_s..shader = null..strokeWidth = (1 - k) * 6 + 1..color = const Color(0xFFC48BFF)));
    _plus.style = PaintingStyle.fill;
    for (var i = 0; i < 7; i++) {
      final a = r0.next() * math.pi * 2, dd = (10 + k * 60) * size;
      c.save();
      c.translate(math.cos(a) * dd, math.sin(a) * dd);
      c.rotate(a);
      c.scale(size);
      final p = nyxMoonPath(5);
      c.drawPath(p, paint ? (_plus..color = Color.fromRGBO(220, 250, 255, 1 - k)) : (_f..shader = null..color = const Color(0xFF9FF3FF)));
      c.restore();
    }
  }

  /// A growing crescent between her hands while a shard charges. [k] 0..1.
  void moonCharge(Canvas c, FightLook look, double k, int frame) {
    final paint = look == FightLook.painted;
    final r = 4 + k * 10;
    if (paint) {
      drawGlow(c, Offset.zero, r * 2.6, Color.fromRGBO(160, 240, 255, .55));
    }
    c.save();
    c.rotate(-.5 + frame * .05);
    final p = nyxMoonPath(r);
    c.drawPath(p, _f..shader = null..color = const Color(0xFF9FF3FF));
    if (look == FightLook.cartoon) c.drawPath(p, _s..shader = null..strokeWidth = 1.6..color = kInk);
    c.restore();
    final r0 = SRand(31);
    for (var i = 0; i < 6; i++) {
      final a = r0.next() * math.pi * 2 + frame * .06;
      final d = (1 - ((frame * .05 + r0.next()) % 1)) * 30;
      final x = math.cos(a) * d, y = math.sin(a) * d;
      if (paint) {
        c.drawCircle(Offset(x, y), 1.6, _f..shader = null..color = const Color(0xE6C48BFF));
      } else {
        c.drawRect(Rect.fromLTWH(x - 1.8, y - 1.8, 3.6, 3.6), _f..shader = null..color = const Color(0xFFC48BFF));
      }
    }
  }

  /// Shadow pool on the ground, [age] frames old of [life], drawn at lab size
  /// (rx 72 at full growth).
  void pool(Canvas c, FightLook look, int age, int life, int frame, int seed) {
    final grow = math.min(1.0, age / 12), fade = life - age < 24 ? math.max(0.0, (life - age) / 24) : 1.0;
    final rx = 72 * grow, ry = 12 * grow;
    if (rx < 1) return;
    final r0 = SRand(seed);
    if (look == FightLook.painted) {
      final rect = Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2.8);
      c.drawOval(
          rect,
          _f
            ..color = const Color(0xFFFFFFFF)
            ..shader = Gradient.radial(Offset.zero, rx, [
              Color.fromRGBO(10, 4, 26, .95 * fade),
              Color.fromRGBO(40, 16, 90, .8 * fade),
              const Color(0x00C48BFF),
            ], const [0, .75, 1]));
      _f.shader = null;
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 1.84, height: ry * 2.4),
          _plus..shader = null..style = PaintingStyle.stroke..strokeWidth = 2..color = Color.fromRGBO(196, 139, 255, .55 * fade));
    } else {
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), _f..shader = null..color = withA(const Color(0xFF120A28), fade));
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), _s..shader = null..strokeWidth = 2.5..color = withA(const Color(0xFFC48BFF), fade));
      if (look == FightLook.cartoon) {
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2 + 4, height: ry * 2 + 4), _s..strokeWidth = 1.4..color = withA(kInk, fade));
      }
    }
    for (var i = 0; i < 6; i++) {
      final t = (frame * .015 + i / 6) % 1.0;
      final x = (r0.next() - .5) * rx * 1.6 + math.sin(t * 6 + i) * 4, y = -t * 46;
      final col = look == FightLook.painted ? Color.fromRGBO(196, 139, 255, (1 - t) * .8 * fade) : withA(const Color(0xFFC48BFF), fade);
      c.drawCircle(Offset(x, y), (1 - t) * 3 + .5, _f..shader = null..color = col);
    }
  }

  /// Teleport smoke around the origin.
  void puff(Canvas c, FightLook look, int age, int seed) {
    const d = 22;
    if (age > d || age < 0) return;
    final k = age / d;
    final r0 = SRand(seed);
    for (var i = 0; i < 16; i++) {
      final a = r0.next() * math.pi * 2, dd = (10 + r0.next() * 40) * math.sqrt(k);
      final x = math.cos(a) * dd, y = math.sin(a) * dd * .7 - k * 14, rad = (1 - k) * (3 + r0.next() * 4);
      final col = look == FightLook.painted
          ? (i % 3 != 0 ? Color.fromRGBO(60, 30, 120, .8 * (1 - k)) : Color.fromRGBO(196, 139, 255, .8 * (1 - k)))
          : (i % 3 != 0 ? const Color(0xFF2B2056) : const Color(0xFFC48BFF));
      c.drawCircle(Offset(x, y), math.max(.4, rad), _f..shader = null..color = col);
    }
  }

  /// Eclipse counter stance: a black sun with a burning corona. [k] grow-in
  /// 0..1, [out] fade 0..1.
  void eclipseHalo(Canvas c, FightLook look, double k, double out, int frame) {
    final r = 17 * k;
    if (r < .5 || out <= 0) return;
    if (look == FightLook.painted) {
      drawGlow(c, Offset.zero, r * 1.9, Color.fromRGBO(196, 139, 255, .75 * out));
      drawGlow(c, Offset.zero, r * 1.35, Color.fromRGBO(220, 250, 255, .6 * out));
    } else {
      final star = starPath(0, 0, r * 1.45, r * 1.08, 14, frame * .05);
      c.drawPath(star, _f..shader = null..color = withA(const Color(0xFF9FF3FF), out));
      if (look == FightLook.cartoon) c.drawPath(star, _s..shader = null..strokeWidth = 2..color = withA(kInk, out));
    }
    c.drawCircle(Offset.zero, r, _f..shader = null..color = withA(const Color(0xFF0A0618), out));
    if (look == FightLook.cartoon) c.drawCircle(Offset.zero, r, _s..shader = null..strokeWidth = 2..color = withA(const Color(0xFFC48BFF), out));
  }

  /// Total Eclipse: a dark sun over the field. [k] 0..1 grow-in, [pulse] 0..1.
  void darkSun(Canvas c, FightLook look, double k, double pulse, int frame) {
    final r = 34 * k * (1 + pulse * .06);
    if (r < 1) return;
    final paint = look == FightLook.painted;
    if (paint) {
      drawGlow(c, Offset.zero, r * 2.4, Color.fromRGBO(196, 139, 255, .7));
      drawGlow(c, Offset.zero, r * 1.6, Color.fromRGBO(220, 250, 255, .55));
    } else {
      final star = starPath(0, 0, r * 1.5, r * 1.12, 18, frame * .04);
      c.drawPath(star, _f..shader = null..color = const Color(0xFF9FF3FF));
      if (look == FightLook.cartoon) c.drawPath(star, _s..shader = null..strokeWidth = 2.4..color = kInk);
    }
    c.drawCircle(Offset.zero, r, _f..shader = null..color = const Color(0xFF05020F));
    if (look == FightLook.cartoon) c.drawCircle(Offset.zero, r, _s..shader = null..strokeWidth = 2.4..color = const Color(0xFFC48BFF));
    // Corona flares.
    final r0 = SRand(9);
    for (var i = 0; i < 10; i++) {
      final a = r0.next() * math.pi * 2 + frame * .02, len = r * (.35 + r0.next() * .45) * (1 + pulse * .2);
      final p0 = Offset(math.cos(a) * r * 1.05, math.sin(a) * r * 1.05), p1 = Offset(math.cos(a) * (r + len), math.sin(a) * (r + len));
      if (paint) {
        c.drawLine(p0, p1, _plus..shader = null..style = PaintingStyle.stroke..strokeWidth = 2.4..color = const Color(0xCCDCFAFF));
      } else {
        c.drawLine(p0, p1, _s..shader = null..strokeWidth = 2.6..color = const Color(0xFFC48BFF));
      }
    }
  }

  /// A moon-blade slash across the origin at [angle]; [age] 0..9.
  void slash(Canvas c, FightLook look, int age, double angle, double len) {
    const d = 9;
    if (age > d || age < 0) return;
    final k = age / d, e = math.min(1.0, age / 3);
    c.save();
    c.rotate(angle);
    final w = (1 - k) * 7 + 1;
    final p = Path()
      ..moveTo(-len * e, 0)
      ..quadraticBezierTo(0, -w * 2, len * e, 0)
      ..quadraticBezierTo(0, w * 2, -len * e, 0)
      ..close();
    if (look == FightLook.painted) {
      c.drawPath(p, _plus..shader = null..style = PaintingStyle.fill..color = Color.fromRGBO(220, 250, 255, .9 * (1 - k)));
      drawGlow(c, Offset.zero, len * .5, Color.fromRGBO(196, 139, 255, .5 * (1 - k)));
    } else {
      c.drawPath(p, _f..shader = null..color = const Color(0xFFF2EAFF));
      if (look == FightLook.cartoon) c.drawPath(p, _s..shader = null..strokeWidth = 2..color = kInk);
    }
    c.restore();
  }
}
