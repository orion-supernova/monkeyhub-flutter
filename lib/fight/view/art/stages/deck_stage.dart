// Stage 5, Moonlit Deck: the deck of a ship at night. Rolling sea with a moon
// path, a waving flag, swinging lanterns and drifting clouds.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../art_common.dart';
import '../glow.dart';
import 'stage_base.dart';

class DeckStage extends StageScene {
  final ParticleField _spark = ParticleField(181, 30);

  @override
  FloorSpec get floorSpec => const FloorSpec(
    top: Color(0xFF6B4A3A),
    bottom: Color(0xFF241714),
    line: Color(0x40140C0A),
    lineFlat: Color(0xFF3B2A22),
    rim: Color(0x30B8D0FF),
    planks: true,
  );

  double _seaY(double h) => h * .6;

  @override
  void drawSky(Canvas g, double w, double h, FightLook look) {
    final su = h / 400, sea = _seaY(h);
    ramp(g, Rect.fromLTWH(-40, 0, w + 80, sea), const [(0, 0xFF050b24), (.45, 0xFF0d1f4a), (.8, 0xFF1c3f78), (1, 0xFF3a6aa6)], look);
    // the sea: darker, banded
    ramp(g, Rect.fromLTWH(-40, sea, w + 80, h - sea), const [(0, 0xFF1d416f), (.4, 0xFF0f2a52), (1, 0xFF081733)], look, bands: 5);
    final r = SRand(191);
    for (var i = 0; i < 60; i++) {
      final x = r.next() * w - 40, y = r.next() * sea * .8, big = r.next() < .15;
      g.drawRect(Rect.fromLTWH(x, y, big ? 2 * su : su, big ? 2 * su : su), p..shader = null..color = const Color(0xCCDCE8FF));
    }
    final mx = w * .3 - 40, my = h * .26, mr = 40 * su;
    if (look == FightLook.painted) {
      g.drawRect(Rect.fromLTWH(-40, 0, w + 80, h), p..color = const Color(0xFFFFFFFF)..shader = Gradient.radial(Offset(mx, my), mr * 6, const [Color(0x88DCE8FF), Color(0x30A0C0F0), Color(0x00A0C0F0)], const [.1, .4, 1]));
      p.shader = null;
    } else {
      g.drawCircle(Offset(mx, my), mr * 1.5, p..color = const Color(0x28DCE8FF));
    }
    g.drawCircle(Offset(mx, my), mr, p..shader = null..color = const Color(0xFFF2F4E4));
    for (final (dx, dy, rr) in const [(-.3, -.15, .2), (.25, .2, .26), (.1, -.4, .12), (-.2, .35, .14)]) {
      g.drawCircle(Offset(mx + dx * mr, my + dy * mr), rr * mr, p..color = const Color(0xFFD6DAC6));
    }
    if (look == FightLook.cartoon) halftone(g, Rect.fromLTWH(-40, 0, w + 80, sea * .5), 0x22);
    // moon path on the water, in soft strips
    for (var i = 0; i < 9; i++) {
      final wy = sea + 4 * su + i * 11 * su, ww = (30 + i * 12) * su;
      g.drawRect(Rect.fromCenter(center: Offset(mx, wy), width: ww, height: 3 * su), p..color = look == FightLook.painted ? Color.fromRGBO(220, 232, 255, .35 - i * .025) : const Color(0x55DCE8FF));
    }
  }

  @override
  void liveSky(StageCtx x) {
    final c = x.c, w = x.size.width, h = x.size.height, su = x.su, t = x.t, sea = _seaY(h);
    // clouds lit from the moon
    for (var i = 0; i < 3; i++) {
      final u = (i * .4 + t * (.00004 + i * .000015)) % 1.4 - .2;
      final cw = (240 + i * 50) * su, cy = h * (.12 + .11 * i);
      c.drawOval(Rect.fromCenter(center: Offset(u * w, cy), width: cw, height: 17 * su), p..shader = null..color = x.paint ? const Color(0x60203A70) : const Color(0xFF152a5a));
      c.drawOval(Rect.fromCenter(center: Offset(u * w - cw * .1, cy - 4 * su), width: cw * .6, height: 8 * su), p..color = x.paint ? const Color(0x302A4A8A) : const Color(0xFF244274));
    }
    // waves: pale crests sliding across the sea
    final nw = x.count(11);
    for (var i = 0; i < nw; i++) {
      final yy = sea + (6 + i * 9.5) * su;
      final off = math.sin(t * .02 + i * 2.1) * 22 * su;
      c.drawOval(Rect.fromCenter(center: Offset((((i * .29) % 1.0) * 1.1 - .05) * w + off, yy), width: (70 + (i % 4) * 36) * su, height: 2.2 * su), p..shader = null..color = const Color(0x40B8D0FF));
    }
    // glitter on the moon path
    final n = x.count(30);
    if (n > 0) {
      final mx = w * .3;
      final pts = _spark.points(n, t, 90 * su, h - sea - 10 * su, vx: .0004, vy: 0, wob: 10 * su, wf: .06, x0: mx - 45 * su, y0: sea + 8 * su);
      s
        ..strokeWidth = 2.2 * su
        ..color = Color.fromRGBO(235, 242, 255, .5 + .35 * math.sin(t * .1));
      c.drawRawPoints(PointMode.points, n == 30 ? pts : Float32List.sublistView(pts, 0, n * 2), s);
    }
  }

  void _ship(Canvas g, double x, double y, double sc, FightLook look) {
    g.save();
    g.translate(x, y);
    g.scale(sc);
    final dark = const Color(0xFF0f1d3e);
    g.drawPath(Path()..moveTo(-60, 0)..lineTo(60, 0)..lineTo(46, 16)..lineTo(-48, 16)..close(), p..shader = null..color = dark);
    g.drawRect(const Rect.fromLTWH(-2, -80, 4, 80), p);
    g.drawPath(Path()..moveTo(-30, -74)..lineTo(30, -74)..lineTo(24, -20)..lineTo(-24, -20)..close(), p);
    g.drawRect(const Rect.fromLTWH(-48, -50, 2.5, 50), p);
    g.drawPath(Path()..moveTo(-52, -46)..lineTo(-22, -46)..lineTo(-24, -12)..lineTo(-50, -12)..close(), p);
    g.restore();
  }

  @override
  void drawFar(Canvas g, FightLook look) {
    // island with a lighthouse and a far ship on the horizon
    shape(g, ridgePath(201, 120, 520, -90, 60, 80, step: 10, freq: 2), const Color(0xFF14284e), look, ink: 2);
    _ship(g, 1120, -58, 1.1, look);
    _ship(g, 700, -50, .6, look);
    // low sea haze
    if (look == FightLook.painted) {
      g.drawRect(const Rect.fromLTRB(kWx0, -90, kWx1, 20), p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, -90), const Offset(0, 20), const [Color(0x00A0C0F0), Color(0x4CA0C0F0)]));
      p.shader = null;
    }
  }

  @override
  void drawMid(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon;
    final wood = const Color(0xFF3B2A24);
    // masts
    for (final (mx, mw, top) in const [(900.0, 16.0, -520.0), (1420.0, 12.0, -420.0), (260.0, 12.0, -450.0)]) {
      shape(g, Path()..addRect(Rect.fromLTWH(mx - mw / 2, top, mw, -top + 10)), wood, look, lowC: const Color(0xFF1E1512), bounds: Rect.fromLTRB(0, top, 0, 10), ink: 2.2);
    }
    // sails with a belly
    for (final (mx, sw, sy, sh) in const [(900.0, 200.0, -490.0, 130.0), (900.0, 250.0, -330.0, 150.0), (1420.0, 170.0, -390.0, 120.0), (260.0, 170.0, -420.0, 120.0)]) {
      final sail = Path()
        ..moveTo(mx - sw / 2, sy)
        ..lineTo(mx + sw / 2, sy)
        ..quadraticBezierTo(mx + sw / 2 + 10, sy + sh * .5, mx + sw / 2 - 12, sy + sh)
        ..quadraticBezierTo(mx, sy + sh + 24, mx - sw / 2 + 12, sy + sh)
        ..quadraticBezierTo(mx - sw / 2 - 10, sy + sh * .5, mx - sw / 2, sy)
        ..close();
      shape(g, sail, const Color(0xFF52668F), look, lowC: const Color(0xFF33436B), bounds: Rect.fromLTRB(0, sy, 0, sy + sh + 24), ink: 2.4);
      // seams
      s
        ..strokeWidth = 1.4
        ..color = cel ? kInk : const Color(0x40101830);
      for (var k = 1; k < 4; k++) {
        final xx = mx - sw / 2 + k * sw / 4;
        g.drawLine(Offset(xx, sy + 3), Offset(xx, sy + sh + 8), s);
      }
      g.drawRect(Rect.fromLTWH(mx - sw / 2 - 8, sy - 5, sw + 16, 7), p..shader = null..color = wood);
    }
    // rigging down to the rail
    s
      ..strokeWidth = 1.6
      ..color = const Color(0xFF120D0C);
    for (final (mx, dx) in const [(900.0, -330.0), (900.0, 320.0), (1420.0, -240.0), (260.0, 250.0)]) {
      g.drawLine(Offset(mx, -420), Offset(mx + dx, -60), s);
      g.drawLine(Offset(mx, -320), Offset(mx + dx * .6, -60), s);
    }
    // crow's nest
    g.drawRect(const Rect.fromLTWH(880, -540, 40, 18), p..color = wood);
  }

  void _lantern(Canvas g, double x, double y, double len, double ang, StageCtx k) {
    final px = x + math.sin(ang) * len, py = y + math.cos(ang) * len;
    s
      ..strokeWidth = 1.6
      ..color = const Color(0xFF120D0C);
    g.drawRect(Rect.fromLTWH(x - 26, y - 4, 52, 6), p..shader = null..color = const Color(0xFF3B2A24));
    g.drawLine(Offset(x, y), Offset(px, py - 9), s);
    if (k.paint) drawGlow(g, Offset(px, py), 46, const Color(0x88FFB04F));
    g.drawRect(Rect.fromCenter(center: Offset(px, py), width: 14, height: 18), p..shader = null..color = const Color(0xFF2B1D16));
    g.drawRect(Rect.fromCenter(center: Offset(px, py), width: 9, height: 12), p..color = const Color(0xFFFFC866));
    if (k.cel) g.drawRect(Rect.fromCenter(center: Offset(px, py), width: 14, height: 18), s..strokeWidth = 1.6..color = kInk);
  }

  @override
  void drawNear(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    // the rail along the back of the deck
    const rail = Rect.fromLTRB(kWx0, -66, kWx1, 0);
    if (paint) {
      g.drawRect(rail, p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, -66), const Offset(0, 0), const [Color(0xFF5B3F32), Color(0xFF2A1A16)]));
      p.shader = null;
    } else {
      g.drawRect(rail, p..shader = null..color = const Color(0xFF4A3329));
    }
    g.drawRect(const Rect.fromLTRB(kWx0, -76, kWx1, -62), p..shader = null..color = const Color(0xFF7A5642));
    if (cel) {
      s
        ..strokeWidth = 2.4
        ..color = kInk;
      g.drawLine(const Offset(kWx0, -76), const Offset(kWx1, -76), s);
      g.drawLine(const Offset(kWx0, -62), const Offset(kWx1, -62), s);
      s.strokeWidth = 1.5;
      for (var x = kWx0; x < kWx1; x += 46) {
        g.drawLine(Offset(x, -62), Offset(x, 0), s);
      }
    } else {
      s
        ..strokeWidth = 2
        ..color = const Color(0x55120A08);
      for (var x = kWx0; x < kWx1; x += 46) {
        g.drawLine(Offset(x, -62), Offset(x, 0), s);
      }
    }
    // barrels and crates
    for (final bx in const [210.0, 1010.0]) {
      for (var i = 0; i < 2; i++) {
        final cx = bx + i * 54;
        final barrel = Path()
          ..moveTo(cx - 20, 0)
          ..quadraticBezierTo(cx - 27, -26, cx - 20, -52)
          ..lineTo(cx + 20, -52)
          ..quadraticBezierTo(cx + 27, -26, cx + 20, 0)
          ..close();
        shape(g, barrel, const Color(0xFF7A4F34), look, lowC: const Color(0xFF3F2618), bounds: Rect.fromLTRB(0, -52, 0, 0), ink: 2.4);
        for (final hy in const [-40.0, -12.0]) {
          g.drawRect(Rect.fromLTWH(cx - 25, hy, 50, 5), p..shader = null..color = const Color(0xFF2B2B38));
        }
      }
      shape(g, Path()..addRect(Rect.fromLTWH(bx + 4, -102, 46, 46)), const Color(0xFF8A6244), look, lowC: const Color(0xFF4A3022), bounds: Rect.fromLTRB(0, -102, 0, -56), ink: 2.4);
      s
        ..strokeWidth = 2
        ..color = const Color(0xFF3B2618);
      g.drawLine(Offset(bx + 4, -102), Offset(bx + 50, -56), s);
      g.drawLine(Offset(bx + 50, -102), Offset(bx + 4, -56), s);
    }
    // cannon
    const cx = 1330.0;
    g.drawRect(const Rect.fromLTWH(cx - 42, -34, 84, 26), p..shader = null..color = const Color(0xFF5B3F32));
    if (cel) g.drawRect(const Rect.fromLTWH(cx - 42, -34, 84, 26), s..strokeWidth = 2.2..color = kInk);
    shape(g, Path()..moveTo(cx - 50, -48)..lineTo(cx + 60, -58)..lineTo(cx + 60, -34)..lineTo(cx - 50, -30)..close(), const Color(0xFF2C3446), look, ink: 2.4);
    g.drawCircle(const Offset(cx - 22, -4), 18, p..shader = null..color = const Color(0xFF4A3329));
    g.drawCircle(const Offset(cx + 26, -4), 18, p);
    if (cel) {
      g.drawCircle(const Offset(cx - 22, -4), 18, s..strokeWidth = 2.2..color = kInk);
      g.drawCircle(const Offset(cx + 26, -4), 18, s);
    }
    // coiled rope
    for (var i = 0; i < 3; i++) {
      g.drawOval(Rect.fromCenter(center: Offset(560, -6 - i * 5), width: 60 - i * 6, height: 14), s..strokeWidth = 4..color = const Color(0xFFA8895E));
    }
  }

  @override
  void liveMid(StageCtx x) {
    final t = x.t;
    x.inLayer(parallax[1], zoom[1], (g) {
      // the flag on the main mast
      const fx = 900.0, fy = -566.0;
      final flag = Path()..moveTo(fx + 2, fy);
      const n = 8;
      for (var i = 1; i <= n; i++) {
        final u = i / n;
        flag.lineTo(fx + 2 + u * 74, fy + math.sin(t * .13 - u * 5) * 6 * u);
      }
      for (var i = n; i >= 0; i--) {
        final u = i / n;
        flag.lineTo(fx + 2 + u * 74, fy + 40 + math.sin(t * .13 - u * 5) * 6 * u);
      }
      flag.close();
      g.drawPath(flag, p..shader = null..color = const Color(0xFF0B0A12));
      if (x.cel) g.drawPath(flag, s..strokeWidth = 2..color = kInk);
      final sy = fy + 20 + math.sin(t * .13 - 1.7) * 2;
      g.drawCircle(Offset(fx + 36, sy - 3), 8, p..color = const Color(0xFFE8E4D4));
      g.drawRect(Rect.fromLTWH(fx + 31, sy + 3, 10, 5), p);
      s
        ..strokeWidth = 2.4
        ..color = const Color(0xFFE8E4D4);
      g.drawLine(Offset(fx + 22, sy + 8), Offset(fx + 50, sy - 8), s);
      g.drawLine(Offset(fx + 50, sy + 8), Offset(fx + 22, sy - 8), s);
    });
  }

  @override
  void liveFront(StageCtx x) {
    final t = x.t;
    x.inLayer(parallax[2], zoom[2], (g) {
      for (var i = 0; i < 3; i++) {
        final lx = const [330.0, 800.0, 1210.0][i];
        final ang = x.motion == 0 ? 0.0 : math.sin(t * .045 + i * 2.2) * .16;
        _lantern(g, lx, -300, 120 + i * 14.0, ang, x);
      }
    });
  }
}
