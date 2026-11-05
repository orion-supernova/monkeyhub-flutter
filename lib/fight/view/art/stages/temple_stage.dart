// Stage 1, Moss Temple: a jungle ruin at dusk. Waterfall, a humming rune arch,
// fireflies and drifting leaves over cached layers.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../art_common.dart';
import '../glow.dart';
import 'stage_base.dart';

class TempleStage extends StageScene {
  final ParticleField _flies = ParticleField(31, 26), _leaves = ParticleField(32, 10), _fall = ParticleField(33, 16);

  static const double _fx = 262, _fw = 68, _top = -560; // waterfall column
  static const double _ax = 840; // rune arch centre

  @override
  FloorSpec get floorSpec => const FloorSpec(
    top: Color(0xFF3f4d3a),
    bottom: Color(0xFF121a17),
    line: Color(0x2EC8E8A0),
    lineFlat: Color(0xFF1f2a22),
    rim: Color(0x38F2B865),
  );

  // ------------------------------------------------------------------ sky

  @override
  void drawSky(Canvas g, double w, double h, FightLook look) {
    final su = h / 400, bot = h * .8;
    ramp(
      g,
      Rect.fromLTWH(-40, 0, w + 80, bot),
      const [(0, 0xFF07191f), (.34, 0xFF11393d), (.58, 0xFF2d6a57), (.8, 0xFFb99b58), (1, 0xFFf4b867)],
      look,
    );
    g.drawRect(Rect.fromLTWH(-40, bot, w + 80, h - bot), p..shader = null..color = const Color(0xFFf4b867));
    if (look == FightLook.cartoon) halftone(g, Rect.fromLTWH(-40, 0, w + 80, bot * .4));
    final r = SRand(41);
    p.color = const Color(0xCCFFF6DC);
    for (var i = 0; i < 42; i++) {
      final x = r.next() * w - 40, y = r.next() * h * .34, sz = r.next() < .2 ? 2.0 * su : su;
      g.drawRect(Rect.fromLTWH(x, y, sz, sz), p);
    }
    // the low sun behind the ridges
    final sx = w * .6 - 40, sy = h * .5, sr = 62 * su;
    if (look == FightLook.painted) {
      g.drawRect(
        Rect.fromLTWH(-40, 0, w + 80, h),
        p..color = const Color(0xFFFFFFFF)..shader = Gradient.radial(Offset(sx, sy), 250 * su, const [Color(0xBFFFE0A0), Color(0x4AFFB060), Color(0x00FF9040)], const [.05, .32, 1]),
      );
      p.shader = null;
      g.drawCircle(Offset(sx, sy), sr, p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(Offset(0, sy - sr), Offset(0, sy + sr), const [Color(0xFFFFF4C8), Color(0xFFFFC070)]));
      p.shader = null;
    } else {
      g.drawCircle(Offset(sx, sy), sr * 1.35, p..color = const Color(0x40FFE6A0));
      g.drawCircle(Offset(sx, sy), sr, p..color = const Color(0xFFFFE6A0));
    }
  }

  @override
  void liveSky(StageCtx x) {
    final c = x.c, w = x.size.width, h = x.size.height, su = x.su;
    final cloud = x.paint ? const Color(0x4D5FA894) : const Color(0xFF2f7566);
    for (var i = 0; i < 4; i++) {
      final u = (i * .31 + x.t * (.00005 + i * .000012)) % 1.3 - .15;
      final cw = (190 + i * 40) * su;
      c.drawOval(Rect.fromCenter(center: Offset(u * w, h * (.1 + .09 * i)), width: cw, height: (11 + i * 2) * su), p..shader = null..color = cloud);
    }
  }

  // ---------------------------------------------------------------- layers

  @override
  void drawFar(Canvas g, FightLook look) {
    final paint = look == FightLook.painted;
    shape(g, ridgePath(11, kWx0, kWx1, -190, 120, 70), const Color(0xFF1f5550), look,
        lowC: const Color(0xFF1b4742), bounds: const Rect.fromLTRB(0, -330, 0, 70));
    // the pyramid temple
    const px = 770.0;
    var by = -150.0;
    for (final (tw, th) in const [(250.0, 26.0), (196.0, 26.0), (144.0, 26.0), (96.0, 26.0)]) {
      g.drawRect(Rect.fromLTWH(px - tw / 2, by - th, tw, th + 2), p..shader = null..color = const Color(0xFF2b6259));
      g.drawRect(Rect.fromLTWH(px - tw / 2, by - th, 4, th + 2), p..color = const Color(0x80F2B865));
      by -= th;
    }
    g.drawRect(Rect.fromLTWH(px - 22, by - 30, 44, 30), p..color = const Color(0xFF2b6259));
    g.drawRect(Rect.fromLTWH(px - 6, by - 20, 12, 20), p..color = const Color(0xFFffc060));
    g.drawRect(Rect.fromLTWH(px - 28, by - 36, 56, 7), p..color = const Color(0xFF25564e));
    // light shafts from the canopy
    final a = paint ? 0x22 : 0x16;
    for (final sx in const [180.0, 560.0, 1100.0]) {
      g.drawPath(
        Path()..moveTo(sx, -560)..lineTo(sx + 70, -560)..lineTo(sx + 190, -90)..lineTo(sx + 60, -90)..close(),
        p..color = Color.fromARGB(a, 255, 230, 160),
      );
    }
    shape(g, ridgePath(23, kWx0, kWx1, -118, 78, 70, step: 7, freq: 2.6), const Color(0xFF153f3e), look,
        lowC: const Color(0xFF123836), bounds: const Rect.fromLTRB(0, -200, 0, 70));
    // ground mist
    if (paint) {
      g.drawRect(
        const Rect.fromLTRB(kWx0, -170, kWx1, 20),
        p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, -170), const Offset(0, 20), const [Color(0x00BFE8C0), Color(0x70BFE8C0)]),
      );
      p.shader = null;
    } else {
      g.drawRect(const Rect.fromLTRB(kWx0, -60, kWx1, 20), p..color = const Color(0x40BFE8C0));
    }
  }

  @override
  void drawMid(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    final trunk = paint ? const Color(0xFF1f4638) : const Color(0xFF214538);
    // trunks with flared roots
    for (final (tx, tw) in const [(-300.0, 80.0), (30.0, 62.0), (480.0, 76.0), (1130.0, 66.0), (1400.0, 84.0), (1640.0, 70.0)]) {
      final path = Path()
        ..moveTo(tx - tw / 2, -620)
        ..lineTo(tx + tw / 2, -620)
        ..lineTo(tx + tw / 2 - 4, -60)
        ..quadraticBezierTo(tx + tw / 2 + 4, -14, tx + tw / 2 + 40, 6)
        ..lineTo(tx - tw / 2 - 40, 6)
        ..quadraticBezierTo(tx - tw / 2 - 4, -14, tx - tw / 2 + 4, -60)
        ..close();
      shape(g, path, trunk, look, lowC: const Color(0xFF12281f), bounds: Rect.fromLTRB(0, -620, 0, 6), ink: 2.2);
      p.color = const Color(0xFF3a6e54);
      g.drawRect(Rect.fromLTWH(tx - tw / 2 + 7, -620, 7, 560), p);
      p.color = const Color(0x40F2B865);
      g.drawRect(Rect.fromLTWH(tx + tw / 2 - 6, -620, 5, 560), p);
      if (cel) {
        s
          ..strokeWidth = 1.6
          ..color = kInk;
        for (var k = 1; k < 3; k++) {
          g.drawLine(Offset(tx - tw / 2 + k * tw / 3, -560), Offset(tx - tw / 2 + k * tw / 3 + 3, -90), s);
        }
      }
    }
    // the canopy overhead: overlapping leaf masses with lit rims
    final cr = SRand(79);
    for (var pass = 0; pass < 2; pass++) {
      for (var cx = kWx0; cx < kWx1; cx += 70 + cr.next() * 50) {
        final rr = 52 + cr.next() * 46, cy = -500 - cr.next() * 30 + pass * 22;
        g.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rr * 2.2, height: rr * 1.35), p..shader = null..color = pass == 0 ? const Color(0xFF16372e) : const Color(0xFF0f2a24));
        if (cel) g.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rr * 2.2, height: rr * 1.35), s..strokeWidth = 2..color = kInk);
      }
    }
    for (var cx = kWx0 + 30; cx < kWx1; cx += 90 + cr.next() * 70) {
      g.drawOval(Rect.fromCenter(center: Offset(cx, -470), width: 56, height: 18), p..shader = null..color = const Color(0xFF3b7a52));
    }
    // hanging vines
    final vr = SRand(77);
    s
      ..strokeWidth = 3
      ..color = const Color(0xFF2f7a46);
    for (var i = 0; i < 16; i++) {
      final vx = kWx0 + 60 + i * 140 + vr.next() * 60, len = 70 + vr.next() * 150, sw = (vr.next() - .5) * 40;
      final path = Path()..moveTo(vx, -470)..quadraticBezierTo(vx + sw, -470 + len * .6, vx + sw * .4, -470 + len);
      g.drawPath(path, s);
      p.shader = null;
      p.color = const Color(0xFF3f9a58);
      g.drawCircle(Offset(vx + sw * .4, -470 + len), 4.5, p);
    }
    // waterfall: a jagged cliff, two falling sheets (the streaks are live), foam, pool
    final cliff = Path()
      ..moveTo(_fx - 110, 20)
      ..lineTo(_fx - 100, -430)
      ..lineTo(_fx - 70, -470)
      ..lineTo(_fx - 30, -440)
      ..lineTo(_fx - 10, _top)
      ..lineTo(_fx + _fw + 10, _top)
      ..lineTo(_fx + _fw + 40, -430)
      ..lineTo(_fx + _fw + 80, -470)
      ..lineTo(_fx + _fw + 112, -420)
      ..lineTo(_fx + _fw + 100, 20)
      ..close();
    shape(g, cliff, const Color(0xFF2b5449), look, lowC: const Color(0xFF16302c), bounds: const Rect.fromLTRB(0, -470, 0, 20), ink: 2.4);
    p.color = const Color(0xFF3f7566);
    for (final (ly, lw) in const [(-400.0, 80.0), (-300.0, 96.0), (-210.0, 70.0), (-120.0, 90.0)]) {
      g.drawRect(Rect.fromLTWH(_fx - 104, ly, lw, 12), p);
      g.drawRect(Rect.fromLTWH(_fx + _fw + 104 - lw, ly + 44, lw, 12), p);
    }
    final upper = Rect.fromLTRB(_fx + 14, _top, _fx + _fw - 14, -250);
    final lower = Rect.fromLTRB(_fx - 4, -240, _fx + _fw + 4, -10);
    for (final sheet in [upper, lower]) {
      if (paint) {
        g.drawRect(sheet, p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(Offset(0, sheet.top), Offset(0, sheet.bottom), const [Color(0xDDD9F6F0), Color(0xFFA6E0D8)]));
        p.shader = null;
      } else {
        g.drawRect(sheet, p..shader = null..color = const Color(0xFFBFEAE2));
        if (cel) {
          s
            ..strokeWidth = 2
            ..color = kInk;
          g.drawRect(sheet, s);
        }
      }
    }
    // the ledge between the sheets and foam at both landings
    g.drawRect(const Rect.fromLTWH(_fx - 24, -252, _fw + 48, 14), p..shader = null..color = const Color(0xFF3f7566));
    if (cel) g.drawRect(const Rect.fromLTWH(_fx - 24, -252, _fw + 48, 14), s..strokeWidth = 2..color = kInk);
    for (final (fy, fw) in const [(-250.0, 40.0), (-12.0, 100.0)]) {
      g.drawOval(Rect.fromCenter(center: Offset(_fx + _fw / 2, fy), width: fw + 30, height: fy < -100 ? 8 : 16), p..shader = null..color = paint ? const Color(0xB0F2FFFC) : const Color(0xFFF2FFFC));
    }
    g.drawOval(const Rect.fromLTWH(_fx - 80, -24, _fw + 160, 28), p..color = paint ? const Color(0xFF3f9c98) : const Color(0xFF3a9490));
    g.drawOval(const Rect.fromLTWH(_fx - 40, -20, _fw + 80, 16), p..color = const Color(0xFF63c0b8));
    // rune arch
    final stone = paint ? const Color(0xFF34503f) : const Color(0xFF38564a);
    for (final dx in const [-64.0, 36.0]) {
      final pil = Path()..addRect(Rect.fromLTWH(_ax + dx, -270, 28, 270));
      shape(g, pil, stone, look, lowC: const Color(0xFF1d3128), bounds: const Rect.fromLTRB(0, -270, 0, 0), ink: 2.2);
      g.drawRect(Rect.fromLTWH(_ax + dx - 4, -278, 36, 12), p..color = const Color(0xFF4f7a4c));
    }
    shape(g, Path()..addRect(Rect.fromLTWH(_ax - 78, -312, 156, 34)), stone, look, lowC: const Color(0xFF1d3128), bounds: const Rect.fromLTRB(0, -312, 0, -278), ink: 2.2);
    g.drawRect(Rect.fromLTWH(_ax - 82, -320, 164, 9), p..color = const Color(0xFF58874f));
    s
      ..strokeWidth = 3
      ..color = const Color(0xFFffb347);
    g.drawCircle(const Offset(_ax - 14, -140), 34, s);
    g.drawLine(const Offset(_ax - 14, -174), const Offset(_ax - 14, -106), s);
    // a broken column on the right
    shape(g, Path()..moveTo(1160, 0)..lineTo(1160, -150)..lineTo(1176, -168)..lineTo(1190, -140)..lineTo(1204, -176)..lineTo(1216, -150)..lineTo(1216, 0)..close(),
        stone, look, lowC: const Color(0xFF1d3128), bounds: const Rect.fromLTRB(0, -176, 0, 0), ink: 2.2);
  }

  @override
  void drawNear(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    const top = -60.0;
    final wall = const Rect.fromLTRB(kWx0, top, kWx1, 0);
    if (paint) {
      g.drawRect(wall, p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, top), const Offset(0, 0), const [Color(0xFF3d5c4a), Color(0xFF1b2d25)]));
      p.shader = null;
    } else {
      g.drawRect(wall, p..color = const Color(0xFF304c40));
    }
    g.drawRect(const Rect.fromLTRB(kWx0, top - 8, kWx1, top + 2), p..color = paint ? const Color(0xFF5e8a50) : const Color(0xFF4f7a46));
    if (cel) {
      s
        ..strokeWidth = 2.4
        ..color = kInk;
      g.drawLine(const Offset(kWx0, top - 8), const Offset(kWx1, top - 8), s);
      g.drawLine(const Offset(kWx0, top + 2), const Offset(kWx1, top + 2), s);
      s.strokeWidth = 1.4;
      for (var x = kWx0; x < kWx1; x += 74) {
        g.drawLine(Offset(x, top + 2), Offset(x, 0), s);
      }
    }
    // moss tufts
    final r = SRand(5);
    p.color = const Color(0xFF63964f);
    for (var x = kWx0 + 10; x < kWx1; x += 28 + r.next() * 40) {
      final rr = 5 + r.next() * 7;
      g.drawOval(Rect.fromCenter(center: Offset(x, top - 8), width: rr * 2.6, height: rr * 1.4), p);
    }
    // guardian idols
    for (final ix in const [190.0, 1010.0]) {
      final base = Path()..addRect(Rect.fromLTWH(ix - 34, top - 40, 68, 32));
      shape(g, base, const Color(0xFF3b574b), look, lowC: const Color(0xFF223a30), bounds: Rect.fromLTRB(0, top - 40, 0, top - 8), ink: 2.4);
      final head = Path()
        ..moveTo(ix - 28, top - 40)
        ..lineTo(ix - 32, top - 92)
        ..lineTo(ix - 18, top - 112)
        ..lineTo(ix + 18, top - 112)
        ..lineTo(ix + 32, top - 92)
        ..lineTo(ix + 28, top - 40)
        ..close();
      shape(g, head, const Color(0xFF446556), look, lowC: const Color(0xFF29443a), bounds: Rect.fromLTRB(0, top - 112, 0, top - 40), ink: 2.4);
      p.color = const Color(0xFF1b2d25);
      g.drawRect(Rect.fromLTWH(ix - 15, top - 66, 30, 7), p);
      for (final ex in const [-15.0, 7.0]) {
        g.drawRect(Rect.fromLTWH(ix + ex, top - 88, 9, 7), p..color = const Color(0xFFffb347));
      }
      if (paint) g.drawCircle(Offset(ix, top - 84), 34, p..color = const Color(0xFFFFFFFF)..shader = Gradient.radial(Offset(ix, top - 84), 34, const [Color(0x40FFB347), Color(0x00FFB347)]));
      p.shader = null;
    }
    // ferns
    for (final fx in const [90.0, 600.0, 1290.0, 1560.0]) {
      for (var k = -3; k <= 3; k++) {
        final ang = k * .34, len = 66 - k.abs() * 6.0;
        final tip = Offset(fx + math.sin(ang) * len, top + 8 - math.cos(ang) * len);
        final leaf = Path()
          ..moveTo(fx - 4, top + 12)
          ..quadraticBezierTo(fx + (tip.dx - fx) * .35 - 11, top + 8 - (len * .55), tip.dx, tip.dy)
          ..quadraticBezierTo(fx + (tip.dx - fx) * .35 + 11, top + 8 - (len * .5), fx + 4, top + 12)
          ..close();
        shape(g, leaf, Color.lerp(const Color(0xFF1d5a30), const Color(0xFF2f8a48), (k + 3) / 6)!, look, ink: 1.6);
      }
    }
  }

  // ------------------------------------------------------------------ live

  @override
  void liveMid(StageCtx x) {
    final f = x.t;
    x.inLayer(parallax[1], zoom[1], (g) {
      // falling water
      final n = x.count(16);
      if (n > 0) {
        s
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.butt
          ..color = x.paint ? const Color(0x99FFFFFF) : const Color(0xCCF2FFFC);
        g.drawRawPoints(PointMode.lines, _fall.streaks(n, f, _fw - 10, -_top - 40, 0, .011, 0, 26, x0: _fx + 5, y0: _top), s);
        s.strokeCap = StrokeCap.round;
      }
      // mist at the pool
      final pulse = x.t == 0 ? .5 : .5 + .5 * math.sin(f * .04);
      for (var i = 0; i < 3; i++) {
        g.drawOval(
          Rect.fromCenter(center: Offset(_fx + _fw / 2 + (i - 1) * 46, -26 - i % 2 * 10), width: 84 + pulse * 18, height: 26),
          p..shader = null..color = Color.fromRGBO(220, 255, 245, .22 + .08 * pulse),
        );
      }
      // the rune ring breathes
      if (x.paint) {
        final a = .22 + .16 * (x.t == 0 ? .5 : .5 + .5 * math.sin(f * .05));
        drawGlow(g, const Offset(_ax - 14, -140), 70, Color.fromRGBO(255, 170, 70, a));
      }
    });
  }

  @override
  void liveFront(StageCtx x) {
    final c = x.c, w = x.size.width, su = x.su, gy = x.gy;
    final f = x.t;
    final nf = x.count(26);
    if (nf > 0) {
      final top = x.size.height * .3;
      final pts = _flies.points(nf, f, w, gy - top - 20 * su, vx: .00004, vy: -.00006, wob: 16 * su, wf: .035, y0: top);
      s
        ..strokeWidth = (x.paint ? 3.4 : 4) * su
        ..color = x.cel ? const Color(0xFFE9FF8A) : const Color(0xFFD8FF7A);
      c.drawRawPoints(PointMode.points, nf == 26 ? pts : Float32List.sublistView(pts, 0, nf * 2), s);
      if (x.paint) {
        for (var i = 0; i < nf; i += 3) {
          final tw = .5 + .5 * math.sin(f * .07 + _flies.phase(i) * 3);
          drawGlow(c, Offset(pts[i * 2], pts[i * 2 + 1]), 18 * su, Color.fromRGBO(220, 255, 120, .55 * tw));
        }
      }
    }
    final nl = x.count(10);
    if (nl > 0) {
      final pts = _leaves.points(nl, f, w, gy, vx: -.0004, vy: .0009, wob: 26 * su, wf: .04);
      s
        ..strokeWidth = 3.2 * su
        ..color = const Color(0xFF7fbf5a);
      c.drawRawPoints(PointMode.points, nl == 10 ? pts : Float32List.sublistView(pts, 0, nl * 2), s);
    }
  }
}
