// Stage 4, Canyon Noon: a sunbaked desert canyon. Heat shimmer, drifting hot
// air balloons and clouds, a rolling tumbleweed and dust on the wind.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../art_common.dart';
import 'stage_base.dart';

class CanyonStage extends StageScene {
  final ParticleField _dust = ParticleField(141, 26);

  @override
  FloorSpec get floorSpec => const FloorSpec(
    top: Color(0xFFA9774F),
    bottom: Color(0xFF4F3226),
    line: Color(0x30FFE0B0),
    lineFlat: Color(0xFF7D5640),
    rim: Color(0x40FFE2B0),
    perspective: false,
  );

  @override
  void drawSky(Canvas g, double w, double h, FightLook look) {
    final su = h / 400, bot = h * .8;
    ramp(g, Rect.fromLTWH(-40, 0, w + 80, bot), const [(0, 0xFF3d82c6), (.45, 0xFF73bde8), (.8, 0xFFbfe4f0), (1, 0xFFf6e6bc)], look);
    g.drawRect(Rect.fromLTWH(-40, bot, w + 80, h - bot), p..shader = null..color = const Color(0xFFf6e6bc));
    final sx = w * .78 - 40, sy = h * .15;
    if (look == FightLook.painted) {
      g.drawRect(
        Rect.fromLTWH(-40, 0, w + 80, h),
        p..color = const Color(0xFFFFFFFF)..shader = Gradient.radial(Offset(sx, sy), 300 * su, const [Color(0xCCFFFFFF), Color(0x44FFF4D0), Color(0x00FFF4D0)], const [.03, .3, 1]),
      );
      p.shader = null;
    } else {
      g.drawCircle(Offset(sx, sy), 58 * su, p..color = const Color(0x30FFFFFF));
      g.drawCircle(Offset(sx, sy), 42 * su, p..color = const Color(0x40FFFFFF));
    }
    g.drawCircle(Offset(sx, sy), 26 * su, p..shader = null..color = const Color(0xFFFFFBE8));
    if (look == FightLook.cartoon) halftone(g, Rect.fromLTWH(-40, 0, w + 80, bot * .35), 0x1C);
  }

  void _balloon(Canvas c, double x, double y, double r, Color a, Color b, StageCtx k) {
    final stripe = k.cel ? kInk : const Color(0x00000000);
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * 1.7, height: r * 2.0), p..shader = null..color = a);
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * .9, height: r * 2.0), p..color = b);
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * .3, height: r * 2.0), p..color = a);
    if (k.cel) {
      c.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: r * 1.7, height: r * 2.0),
        s
          ..strokeWidth = 1.6 * k.su
          ..color = stripe,
      );
    }
    s
      ..strokeWidth = 1 * k.su
      ..color = const Color(0xFF5a3a28);
    c.drawLine(Offset(x - r * .45, y + r * .85), Offset(x - r * .2, y + r * 1.5), s);
    c.drawLine(Offset(x + r * .45, y + r * .85), Offset(x + r * .2, y + r * 1.5), s);
    c.drawRect(Rect.fromCenter(center: Offset(x, y + r * 1.65), width: r * .5, height: r * .35), p..color = const Color(0xFF7a4a30));
  }

  @override
  void liveSky(StageCtx x) {
    final c = x.c, w = x.size.width, h = x.size.height, su = x.su, t = x.t;
    final cloud = x.paint ? const Color(0xEEFFFFFF) : const Color(0xFFFFFFFF);
    final under = x.paint ? const Color(0x40A8C8E8) : const Color(0xFFD8ECF8);
    for (var i = 0; i < 4; i++) {
      final u = (i * .29 + t * (.00004 + i * .000012)) % 1.4 - .2;
      final cw = (170 + i * 50) * su, cy = h * (.1 + .08 * i + (i == 1 ? .06 : 0));
      c.drawOval(Rect.fromCenter(center: Offset(u * w, cy + 4 * su), width: cw, height: 13 * su), p..shader = null..color = under);
      c.drawOval(Rect.fromCenter(center: Offset(u * w, cy), width: cw, height: 15 * su), p..color = cloud);
      c.drawOval(Rect.fromCenter(center: Offset(u * w - cw * .14, cy - 7 * su), width: cw * .5, height: 16 * su), p..color = cloud);
    }
    // balloons, bobbing as they drift
    final b1 = (.18 + t * .000035) % 1.3 - .15, b2 = (.62 + t * .00002) % 1.3 - .15;
    final bob1 = x.motion == 0 ? 0.0 : math.sin(t * .02) * 3 * su, bob2 = x.motion == 0 ? 0.0 : math.sin(t * .017 + 2) * 3 * su;
    _balloon(c, b1 * w, h * .3 + bob1, 15 * su, const Color(0xFFE5483A), const Color(0xFFFFE08A), x);
    _balloon(c, b2 * w, h * .44 + bob2, 10 * su, const Color(0xFF2F9E9A), const Color(0xFFF4EBD0), x);
  }

  @override
  void drawFar(Canvas g, FightLook look) {
    final paint = look == FightLook.painted;
    final r = SRand(151);
    var x = kWx0 - 40;
    while (x < kWx1) {
      final w = 150 + r.next() * 150, hgt = 90 + r.next() * 110;
      final body = Path()
        ..moveTo(x, 40)
        ..lineTo(x + w * .08, -hgt * .5)
        ..lineTo(x + w * .14, -hgt * .52)
        ..lineTo(x + w * .2, -hgt)
        ..lineTo(x + w * .8, -hgt)
        ..lineTo(x + w * .86, -hgt * .55)
        ..lineTo(x + w * .93, -hgt * .5)
        ..lineTo(x + w, 40)
        ..close();
      shape(g, body, const Color(0xFFD7A48E), look, lowC: const Color(0xFFE6C0A0), bounds: Rect.fromLTRB(0, -hgt, 0, 40), ink: 2);
      // strata
      for (var k = 1; k < 4; k++) {
        g.drawRect(Rect.fromLTWH(x + w * (.1 - .02 * k), -hgt + k * hgt * .28, w * (.8 + .04 * k), 5), p..shader = null..color = const Color(0x30B0705A));
      }
      g.drawRect(Rect.fromLTWH(x + w * .2, -hgt, w * .6, 6), p..color = const Color(0xFFE8C4A4));
      x += w * (.65 + r.next() * .35);
    }
    // heat haze at the foot
    if (paint) {
      g.drawRect(const Rect.fromLTRB(kWx0, -120, kWx1, 20), p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, -120), const Offset(0, 20), const [Color(0x00FFF0D0), Color(0x88FFF0D0)]));
      p.shader = null;
    } else {
      g.drawRect(const Rect.fromLTRB(kWx0, -40, kWx1, 20), p..color = const Color(0x55FFF0D0));
    }
  }

  void _cliff(Canvas g, double x, double w, double h, bool left, FightLook look) {
    // a tall wall with ledges; its outer edge sticks up, the inner edge steps down
    final path = Path()..moveTo(x, 60);
    final dir = left ? 1.0 : -1.0;
    final ox = left ? x : x + w;
    path.moveTo(ox, 60);
    path.lineTo(ox, -h);
    var yy = -h;
    var xx = ox;
    for (var i = 0; i < 5; i++) {
      xx += dir * w * (.12 + i * .02);
      path.lineTo(xx, yy);
      yy += h * (.17 + (i % 2) * .05);
      path.lineTo(xx, yy);
    }
    path.lineTo(ox + dir * w, 60);
    path.close();
    shape(g, path, const Color(0xFFB4573A), look, lowC: const Color(0xFF8A3E2C), bounds: Rect.fromLTRB(0, -h, 0, 60), ink: 2.4);
    // strata bands
    final cols = const [Color(0x40FFC88A), Color(0x30662A22), Color(0x35E0885A)];
    var k = 0;
    for (var by = -h + 30; by < 20; by += 38 + (k % 3) * 8) {
      final bw = w * .9;
      g.drawRect(Rect.fromLTWH(left ? ox : ox - bw, by, bw, 12 + (k % 3) * 4), p..shader = null..color = cols[k % 3]);
      k++;
    }
  }

  @override
  void drawMid(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon;
    _cliff(g, -330, 260, 520, true, look);
    _cliff(g, 1270, 260, 480, false, look);
    // a natural arch
    const ax = 700.0;
    final arch = Path()
      ..moveTo(ax - 140, 40)
      ..lineTo(ax - 132, -150)
      ..quadraticBezierTo(ax - 120, -250, ax - 30, -262)
      ..quadraticBezierTo(ax + 40, -270, ax + 110, -246)
      ..quadraticBezierTo(ax + 150, -200, ax + 150, -140)
      ..lineTo(ax + 160, 40)
      ..lineTo(ax + 96, 40)
      ..lineTo(ax + 92, -150)
      ..quadraticBezierTo(ax + 86, -204, ax + 10, -206)
      ..quadraticBezierTo(ax - 62, -208, ax - 66, -140)
      ..lineTo(ax - 66, 40)
      ..close();
    shape(g, arch, const Color(0xFFC0623F), look, lowC: const Color(0xFF8A3E2C), bounds: const Rect.fromLTRB(0, -270, 0, 40), ink: 2.4);
    for (final (by, bh) in const [(-226.0, 10.0), (-190.0, 8.0), (-120.0, 12.0), (-60.0, 9.0)]) {
      g.drawRect(Rect.fromLTWH(ax - 128, by, 24, bh), p..shader = null..color = const Color(0x40662A22));
      g.drawRect(Rect.fromLTWH(ax + 104, by, 36, bh), p..color = const Color(0x40662A22));
    }
    // cacti
    for (final (cx, ch) in const [(250.0, 120.0), (470.0, 84.0), (1130.0, 108.0)]) {
      final trunk = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 9, -ch, 18, ch + 4), const Radius.circular(9));
      final armL = Path()..moveTo(cx - 9, -ch * .45)..lineTo(cx - 28, -ch * .45)..lineTo(cx - 28, -ch * .72);
      final armR = Path()..moveTo(cx + 9, -ch * .6)..lineTo(cx + 26, -ch * .6)..lineTo(cx + 26, -ch * .85);
      final green = look == FightLook.painted ? const Color(0xFF4F7F4A) : const Color(0xFF4A7A46);
      if (cel) {
        s
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..color = kInk;
        g.drawPath(armL, s);
        g.drawPath(armR, s);
        g.drawRRect(trunk.inflate(2.2), p..shader = null..color = kInk);
      }
      s
        ..strokeWidth = 12
        ..color = green;
      g.drawPath(armL, s);
      g.drawPath(armR, s);
      g.drawRRect(trunk, p..shader = null..color = green);
      g.drawRect(Rect.fromLTWH(cx - 1.5, -ch, 3, ch), p..color = const Color(0xFF3A6238));
    }
  }

  @override
  void drawNear(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    // low sandy rise with boulders
    shape(g, ridgePath(161, kWx0, kWx1, -30, 24, 4, step: 12, freq: 1.2), const Color(0xFFC89460), look, lowC: const Color(0xFF8E5E3E), bounds: const Rect.fromLTRB(0, -54, 0, 4), ink: 2.4);
    final r = SRand(171);
    for (var i = 0; i < 9; i++) {
      final bx = kWx0 + 80 + i * 250 + r.next() * 120, bw = 34 + r.next() * 40, bh = 20 + r.next() * 26;
      final rock = Path()
        ..moveTo(bx - bw / 2, 0)
        ..quadraticBezierTo(bx - bw / 2, -bh, bx - bw * .1, -bh)
        ..quadraticBezierTo(bx + bw / 2, -bh * .9, bx + bw / 2, 0)
        ..close();
      shape(g, rock, const Color(0xFF9A5A40), look, lowC: const Color(0xFF6E3C2C), bounds: Rect.fromLTRB(0, -bh, 0, 0), ink: 2.2);
    }
    // wooden fence in front of the rise
    final rail = const Color(0xFF6D4630);
    for (var x = kWx0; x < kWx1; x += 78) {
      g.drawRect(Rect.fromLTWH(x, -56, 7, 56), p..shader = null..color = rail);
      if (cel) g.drawRect(Rect.fromLTWH(x, -56, 7, 56), s..strokeWidth = 1.8..color = kInk);
    }
    for (final ry in const [-46.0]) {
      g.drawRect(Rect.fromLTRB(kWx0, ry, kWx1, ry + 7), p..color = const Color(0xFF7D5238));
      if (cel) g.drawRect(Rect.fromLTRB(kWx0, ry, kWx1, ry + 7), s..strokeWidth = 1.8..color = kInk);
    }
    if (paint) {
      g.drawRect(const Rect.fromLTRB(kWx0, -4, kWx1, 4), p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, -4), const Offset(0, 4), const [Color(0x00000000), Color(0x40000000)]));
      p.shader = null;
    }
    // dry grass tufts
    s
      ..strokeWidth = 2.2
      ..color = const Color(0xFF8A7A3E);
    for (var x = kWx0 + 40; x < kWx1; x += 120 + r.next() * 90) {
      for (var k = -2; k <= 2; k++) {
        g.drawLine(Offset(x, 0), Offset(x + k * 6, -16 - (3 - k.abs()) * 3), s);
      }
    }
  }

  @override
  void liveMid(StageCtx x) {
    // shimmer: thin pale lanes sliding along the horizon
    final n = x.count(8);
    final c = x.c, w = x.size.width, su = x.su, gy = x.gy;
    for (var i = 0; i < n; i++) {
      final yy = gy - (22 + i * 11) * su;
      final off = math.sin(x.t * .03 + i * 1.7) * 26 * su;
      c.drawOval(Rect.fromCenter(center: Offset(((i * .37) % 1.0) * w + off, yy), width: (120 + (i % 3) * 50) * su, height: 2.2 * su), p..shader = null..color = Color.fromRGBO(255, 245, 220, x.paint ? .2 : .32));
    }
  }

  @override
  void liveFloor(StageCtx x) {
    final c = x.c, w = x.size.width, su = x.su, gy = x.gy, fh = x.size.height - gy, t = x.t;
    if (fh <= 0) return;
    // tumbleweed
    final u = (t * .0016) % 1.25 - .12;
    final tx = u * w, ty = gy + fh * .56 - (x.motion == 0 ? 0.0 : (math.sin(t * .13).abs() * 16 * su));
    final tr = 15 * su, ang = t * .12;
    s
      ..strokeWidth = 1.7 * su
      ..color = const Color(0xFF6B4A2A);
    c.drawOval(Rect.fromCenter(center: Offset(tx, gy + fh * .56 + 6 * su), width: tr * 2, height: tr * .5), p..shader = null..color = const Color(0x30000000));
    for (var k = 0; k < 6; k++) {
      final a = ang + k * math.pi / 6 + k * .4;
      c.drawLine(Offset(tx - math.cos(a) * tr, ty - math.sin(a) * tr), Offset(tx + math.cos(a) * tr, ty + math.sin(a) * tr), s);
    }
    c.drawCircle(Offset(tx, ty), tr, s);
    c.drawCircle(Offset(tx, ty), tr * .55, s);
  }

  @override
  void liveFront(StageCtx x) {
    final n = x.count(26);
    if (n == 0) return;
    final w = x.size.width, su = x.su, gy = x.gy;
    final pts = _dust.points(n, x.t, w + 40 * su, gy * .55, vx: .0011, vy: .00005, wob: 5 * su, wf: .02, x0: -20 * su, y0: gy * .45);
    s
      ..strokeWidth = 2.6 * su
      ..color = x.paint ? const Color(0x80FFE9C0) : const Color(0xCCF6DFB0);
    x.c.drawRawPoints(PointMode.points, n == 26 ? pts : Float32List.sublistView(pts, 0, n * 2), s);
  }
}
