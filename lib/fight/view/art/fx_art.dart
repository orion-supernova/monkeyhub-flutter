// Combat effects, ported from the style lab's drawFX. All drawing is centred on
// (0,0) in "lab units"; the caller translates/scales to the world position.
import 'dart:math' as math;
import 'dart:ui';

import 'art_common.dart';
import 'quality.dart';
import 'glow.dart';

class FxPainter {
  final Paint _f = Paint()..isAntiAlias = true;
  final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _plus = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  void _fillInk(Canvas c, Path p, Color fill, FightLook look, {double ink = 2.4}) {
    c.drawPath(p, _f..shader = null..color = fill);
    if (look == FightLook.cartoon) {
      c.drawPath(p, _s..shader = null..strokeWidth = ink..color = kInk);
    }
  }

  /// Hit spark. [kind]: 0 normal, 1 big, 2 block, 3 armor/gray.
  void spark(Canvas c, FightLook look, int age, int seed, {bool big = false, int kind = 0}) {
    final d = big ? 16 : 11;
    if (age > d) return;
    final k = age / d;
    final r0 = SRand(seed);
    if (look == FightLook.painted) {
      final tint = kind == 2 ? const Color(0xFF8fd8ff) : (kind == 3 ? const Color(0xFFcfcfe0) : const Color(0xFFffd278));
      final r = (big ? 70 : 46) * (.5 + k * .8);
      drawGlow(c, Offset.zero, r * 1.3, withA(tint, .9 * (1 - k)));
      drawGlow(c, Offset.zero, r * .55, Color.fromRGBO(255, 255, 255, 1 - k));
      final n = (big ? 16 : 10) >> fightQuality.value.index; // fewer when the governor steps down
      for (var i = 0; i < n; i++) {
        final a = r0.next() * math.pi * 2, sp = (big ? 60 : 40) * (.5 + r0.next()), dd = sp * math.sqrt(k) + 6;
        _plus
          ..strokeWidth = (1 - k) * 3 + .5
          ..color = Color.fromRGBO(255, 230, 170, 1 - k);
        c.drawLine(Offset(math.cos(a) * dd * .55, math.sin(a) * dd * .55), Offset(math.cos(a) * dd, math.sin(a) * dd), _plus);
      }
      return;
    }
    final r = (big ? 54 : 34) * (k < .3 ? k / .3 : 1 - (k - .3) * .9);
    final col = kind == 2 ? const Color(0xFF8fd8ff) : (kind == 3 ? const Color(0xFFd8d8e6) : const Color(0xFFffe14d));
    _fillInk(c, starPath(0, 0, r, r * .42, big ? 9 : 7, (seed % 7).toDouble()), col, look);
    c.drawPath(starPath(0, 0, r * .55, r * .2, big ? 9 : 7, (seed % 7) + .3), _f..color = const Color(0xFFFFFFFF));
    if (big && look == FightLook.cartoon) {
      _s
        ..strokeWidth = 2.4
        ..color = kInk;
      for (var i = 0, n = 10 >> fightQuality.value.index; i < n; i++) {
        final a = r0.next() * math.pi * 2, d0 = 30 + k * 40, d1 = d0 + 18 + r0.next() * 20;
        c.drawLine(Offset(math.cos(a) * d0, math.sin(a) * d0), Offset(math.cos(a) * d1, math.sin(a) * d1), _s);
      }
    }
  }

  void ring(Canvas c, FightLook look, int age, {double size = 1, Color? tint}) {
    const d = 14;
    if (age > d) return;
    final k = age / d, r = (14 + k * 58) * size;
    final rect = Rect.fromCenter(center: Offset.zero, width: r * 1.1, height: r * 2);
    if (look == FightLook.painted) {
      final col = tint ?? const Color(0xFFffdcaa);
      drawGlow(c, Offset.zero, r * 1.2, withA(col, .25 * (1 - k)));
      _plus
        ..strokeWidth = (1 - k) * 7 + 1
        ..color = withA(col, .9 * (1 - k));
      c.drawOval(rect, _plus);
      return;
    }
    _s
      ..strokeWidth = (1 - k) * 7 + 2
      ..color = const Color(0xFFFFFFFF);
    c.drawOval(rect, _s);
    if (look == FightLook.cartoon) {
      _s
        ..strokeWidth = 1.6
        ..color = kInk;
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: (r * .55 + (1 - k) * 4) * 2, height: (r + (1 - k) * 4) * 2), _s);
    }
  }

  void dust(Canvas c, FightLook look, int age, int seed) {
    const d = 24;
    if (age > d) return;
    final k = age / d;
    final r0 = SRand(seed);
    for (var i = 0; i < 7; i++) {
      final dir = i < 3 ? -1 : 1, sp = 10 + r0.next() * 28;
      final x = dir * sp * math.sqrt(k) * (1 + (i % 3) * .4);
      final y = -4 - r0.next() * 10 * k - k * 8;
      final r = (5 + r0.next() * 7) * (look == FightLook.painted ? 1 + k : (1 - k * .85));
      if (look == FightLook.painted) {
        drawGlow(c, Offset(x, y), r * 1.6, Color.fromRGBO(225, 200, 220, .45 * (1 - k)), additive: false);
      } else {
        c.drawCircle(Offset(x, y), math.max(.5, r), _f..shader = null..color = const Color(0xFFd9cfe3));
        if (look == FightLook.cartoon) {
          c.drawCircle(Offset(x, y), math.max(.5, r), _s..strokeWidth = 1.8..color = kInk);
        }
      }
    }
  }

  /// Projectile muzzle flash (burst = false) or impact burst.
  void flash(Canvas c, FightLook look, int age, int seed, {bool burst = false}) {
    final d = burst ? 20 : 10;
    if (age > d) return;
    final k = age / d;
    if (look == FightLook.painted) {
      final r = (burst ? 110 : 50) * (.4 + k);
      drawGlow(c, Offset.zero, r, Color.fromRGBO(120, 220, 255, .9 * (1 - k)));
      drawGlow(c, Offset.zero, r * .4, Color.fromRGBO(230, 252, 255, 1 - k));
      if (burst) {
        final r0 = SRand(seed);
        for (var i = 0; i < 18; i++) {
          final a = r0.next() * math.pi * 2, dd = 20 + k * 90 * (.5 + r0.next());
          _plus
            ..strokeWidth = 2.5 * (1 - k) + .5
            ..color = Color.fromRGBO(170, 240, 255, 1 - k);
          c.drawLine(Offset(math.cos(a) * dd * .7, math.sin(a) * dd * .7), Offset(math.cos(a) * dd, math.sin(a) * dd), _plus);
        }
      }
      return;
    }
    final r = (burst ? 52 : 24) * (k < .25 ? k / .25 : 1 - (k - .25));
    _fillInk(c, starPath(0, 0, r, r * .5, 10, (seed % 5).toDouble()), const Color(0xFF7fe8ff), look);
    c.drawPath(starPath(0, 0, r * .55, r * .3, 10, (seed % 5).toDouble()), _f..color = const Color(0xFFFFFFFF));
  }

  /// Surge Palm charge swirl around the hand; [k] 0..1 over the charge window.
  void charge(Canvas c, FightLook look, double k, int frame) {
    final r0 = SRand(77);
    if (look == FightLook.painted) {
      final r = 10 + k * 22;
      drawGlow(c, Offset.zero, r * 1.8, Color.fromRGBO(90, 200, 255, .8));
      drawGlow(c, Offset.zero, r * .8, Color.fromRGBO(230, 252, 255, .95));
    }
    for (var i = 0; i < 10; i++) {
      final a = r0.next() * math.pi * 2 + frame * .05;
      final d = (1 - ((frame * .06 + r0.next()) % 1)) * 44;
      final x = math.cos(a) * d, y = math.sin(a) * d;
      if (look == FightLook.painted) {
        c.drawCircle(Offset(x, y), 1.8, _f..shader = null..color = const Color(0xE6A0F0FF));
      } else {
        c.drawRect(Rect.fromLTWH(x - 2, y - 2, 4, 4), _f..shader = null..color = const Color(0xFF7fe8ff));
        if (look == FightLook.cartoon) c.drawRect(Rect.fromLTWH(x - 2, y - 2, 4, 4), _s..strokeWidth = 1..color = kInk);
      }
    }
    if (look != FightLook.painted) {
      c.drawCircle(Offset.zero, 5 + k * 9, _f..color = const Color(0xFFbff6ff));
      if (look == FightLook.cartoon) c.drawCircle(Offset.zero, 5 + k * 9, _s..strokeWidth = 2..color = kInk);
    }
  }

  /// Surge Palm projectile travelling in +x (caller mirrors for facing).
  void projectile(Canvas c, FightLook look, int age) {
    final wob = math.sin(age * .6) * 1.5;
    if (look == FightLook.painted) {
      for (var i = 1; i < 12; i++) {
        final tx = -i * 10.0, a = .6 * (1 - i / 12);
        drawGlow(c, Offset(tx, math.sin((age + i) * .7) * 2), (24 - i * 1.5) * 1.3, Color.fromRGBO(120, 220, 255, a));
      }
      drawGlow(c, Offset.zero, 52, const Color(0xE63CB4FF));
      drawGlow(c, Offset.zero, 26, const Color(0xFFEBFCFF));
      _plus
        ..strokeWidth = 2
        ..color = const Color(0xB3C8FAFF);
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: 17 + wob), age * .3, 2.2, false, _plus);
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: 13 - wob), -age * .4, 1.8, false, _plus);
      return;
    }
    for (var i = 0; i < 3; i++) {
      final ty = -8 + i * 8.0, len = 26 + ((age * 3 + i * 11) % 14);
      final s = RRect.fromLTRBR(-len - 6, ty - 2.5, -6, ty + 2.5, const Radius.circular(2.5));
      c.drawRRect(s, _f..shader = null..color = i == 1 ? const Color(0xFFbff6ff) : const Color(0xFF5fd8ff));
      if (look == FightLook.cartoon) c.drawRRect(s, _s..strokeWidth = 1.8..color = kInk);
    }
    _fillInk(c, starPath(0, 0, 21 + wob, 15, 12, age * .2), const Color(0xFF35c6ff), look, ink: 2.5);
    c.drawCircle(Offset.zero, 11, _f..color = const Color(0xFFbff6ff));
    c.drawCircle(const Offset(2, -1), 5.5, _f..color = const Color(0xFFFFFFFF));
  }

  /// Swoosh smear along [pts] (rig space, oldest first), [unit] converts lab widths.
  void smear(Canvas c, FightLook look, List<Offset> pts, double unit) {
    final n = pts.length;
    if (n < 3) return;
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i < n; i++) {
      final w = (math.pow(i / (n - 1), 1.4) * 15 + .5) * unit;
      final a = pts[math.max(0, i - 1)], b = pts[math.min(n - 1, i + 1)];
      final dx = b.dx - a.dx, dy = b.dy - a.dy;
      final l = math.sqrt(dx * dx + dy * dy);
      final L = l == 0 ? 1.0 : l;
      left.add(Offset(pts[i].dx - dy / L * w, pts[i].dy + dx / L * w));
      right.add(Offset(pts[i].dx + dy / L * w, pts[i].dy - dx / L * w));
    }
    final p = Path()..moveTo(left[0].dx, left[0].dy);
    for (var i = 1; i < n; i++) {
      p.lineTo(left[i].dx, left[i].dy);
    }
    for (var i = n - 1; i >= 0; i--) {
      p.lineTo(right[i].dx, right[i].dy);
    }
    p.close();
    if (look == FightLook.painted) {
      _f
        ..blendMode = BlendMode.plus
        ..shader = Gradient.linear(pts.first, pts.last, const [Color(0x00FFF0DC), Color(0xD9FFF0DC)]);
      c.drawPath(p, _f);
      _f
        ..blendMode = BlendMode.srcOver
        ..shader = null;
    } else {
      c.drawPath(p, _f..shader = null..color = const Color(0xFFfffdf6));
      if (look == FightLook.cartoon) c.drawPath(p, _s..strokeWidth = 2.2 * unit..color = kInk);
    }
  }
}
