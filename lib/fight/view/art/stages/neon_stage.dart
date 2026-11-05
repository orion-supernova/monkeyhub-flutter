// Stage 2, Neon Alley: a rainy night market. Flickering signs, swaying
// lanterns, rain and ripples on wet asphalt over cached layers.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../art_common.dart';
import '../glow.dart';
import 'stage_base.dart';

class _Sign {
  const _Sign(this.x, this.y, this.h, this.col, this.col2, this.seed);
  final double x, y, h; // world px, top-left of the tube frame
  final Color col, col2;
  final int seed; // flicker schedule
}

const _pink = Color(0xFFFF4FA0), _cyan = Color(0xFF4FF3FF), _yellow = Color(0xFFFFD84F), _violet = Color(0xFFB07AFF);
const _signs = [
  _Sign(128, -330, 120, _pink, _cyan, 3),
  _Sign(450, -310, 100, _cyan, _pink, 7),
  _Sign(676, -360, 130, _yellow, _pink, 5),
  _Sign(1080, -300, 110, _pink, _yellow, 11),
  _Sign(1300, -330, 100, _violet, _cyan, 13),
  _Sign(-120, -340, 110, _cyan, _yellow, 17),
];

const _blds = [
  (-420.0, 200.0, 330.0),
  (-160.0, 170.0, 400.0),
  (40.0, 190.0, 310.0),
  (260.0, 150.0, 380.0),
  (430.0, 180.0, 330.0),
  (640.0, 170.0, 420.0),
  (830.0, 200.0, 300.0),
  (1060.0, 160.0, 390.0),
  (1250.0, 190.0, 340.0),
  (1470.0, 180.0, 410.0),
];

class NeonStage extends StageScene {
  final ParticleField _rain = ParticleField(51, 60);
  final ParticleField _ripple = ParticleField(52, 9);

  @override
  FloorSpec get floorSpec => const FloorSpec(
    top: Color(0xFF2c2347),
    bottom: Color(0xFF0a0715),
    line: Color(0x1F8FA8FF),
    lineFlat: Color(0xFF1a1230),
    rim: Color(0x33FF4FA0),
  );

  /// Neon on / off for a sign at [frame]: mostly on, with short stutters.
  bool _on(_Sign sg, int frame) {
    final k = (frame + sg.seed * 41) % (190 + sg.seed * 9);
    return !(k < 3 || (k > 9 && k < 12));
  }

  @override
  void drawSky(Canvas g, double w, double h, FightLook look) {
    final su = h / 400, bot = h * .82;
    ramp(g, Rect.fromLTWH(-40, 0, w + 80, bot), const [(0, 0xFF06041a), (.4, 0xFF150a35), (.72, 0xFF3a1050), (1, 0xFF7c2068)], look);
    g.drawRect(Rect.fromLTWH(-40, bot, w + 80, h - bot), p..shader = null..color = const Color(0xFF7c2068));
    if (look == FightLook.cartoon) halftone(g, Rect.fromLTWH(-40, 0, w + 80, bot * .5));
    // a low smog glow behind the towers
    if (look == FightLook.painted) {
      g.drawRect(
        Rect.fromLTWH(-40, 0, w + 80, h),
        p..color = const Color(0xFFFFFFFF)..shader = Gradient.radial(Offset(w * .5 - 40, h * .66), 330 * su, const [Color(0x66FF4FA0), Color(0x22A040C0), Color(0x00000000)], const [0, .5, 1]),
      );
      p.shader = null;
    }
  }

  @override
  void liveSky(StageCtx x) {
    final c = x.c, w = x.size.width, h = x.size.height, su = x.su;
    final col = x.paint ? const Color(0x55401060) : const Color(0xFF2a0f48);
    for (var i = 0; i < 3; i++) {
      final u = (i * .43 + x.t * (.00006 + i * .00001)) % 1.4 - .2;
      c.drawOval(Rect.fromCenter(center: Offset(u * w, h * (.16 + .12 * i)), width: (260 + i * 60) * su, height: (16 + i * 3) * su), p..shader = null..color = col);
    }
  }

  @override
  void drawFar(Canvas g, FightLook look) {
    final paint = look == FightLook.painted;
    final r = SRand(61);
    var x = kWx0;
    while (x < kWx1) {
      final w = 60 + r.next() * 60, hgt = 260 + r.next() * 260;
      g.drawRect(Rect.fromLTWH(x, -hgt, w, hgt + 70), p..shader = null..color = paint ? const Color(0xF0241450) : const Color(0xFF241450));
      // lit window rows
      for (var wy = -hgt + 14; wy < -40; wy += 14) {
        for (var wx = x + 7; wx < x + w - 8; wx += 11) {
          final q = r.next();
          if (q < .2) g.drawRect(Rect.fromLTWH(wx, wy, 5, 7), p..color = q < .07 ? const Color(0xFFFF6AB8) : (q < .14 ? const Color(0xFF5FE8FF) : const Color(0xFFFFC66B)));
        }
      }
      if (r.next() < .4) {
        g.drawRect(Rect.fromLTWH(x + w / 2 - 1.5, -hgt - 40, 3, 40), p..color = const Color(0xFF241450));
        g.drawRect(Rect.fromLTWH(x + w / 2 - 3, -hgt - 44, 6, 5), p..color = const Color(0xFFFF3B5C));
      }
      x += w + r.next() * 10;
    }
    if (paint) {
      g.drawRect(
        const Rect.fromLTRB(kWx0, -230, kWx1, 20),
        p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, -230), const Offset(0, 20), const [Color(0x00FF4FA0), Color(0x66FF4FA0)]),
      );
      p.shader = null;
    }
  }

  @override
  void drawMid(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    final r = SRand(71);
    var i = 0;
    for (final (bx, bw, bh) in _blds) {
      final face = i.isEven ? const Color(0xFF1b1236) : const Color(0xFF211548);
      shape(g, Path()..addRect(Rect.fromLTWH(bx, -bh, bw, bh + 70)), face, look,
          lowC: const Color(0xFF0f0a22), bounds: Rect.fromLTRB(0, -bh, 0, 70), ink: 2.4);
      if (cel) g.drawRect(Rect.fromLTWH(bx, -bh, 4, bh + 70), p..color = const Color(0xFF30206a));
      // windows
      for (var wy = -bh + 24; wy < -90; wy += 30) {
        for (var wx = bx + 46; wx < bx + bw - 14; wx += 26) {
          final q = r.next();
          if (q < .3) {
            final col = q < .08 ? const Color(0xFF5FE8FF) : const Color(0xFFFFC66B);
            if (paint) g.drawRect(Rect.fromLTWH(wx - 3, wy - 3, 16, 20), p..color = withA(col, .18));
            g.drawRect(Rect.fromLTWH(wx, wy, 10, 14), p..color = col);
          } else {
            g.drawRect(Rect.fromLTWH(wx, wy, 10, 14), p..color = const Color(0xFF120b28));
          }
        }
      }
      if (i % 3 == 1) {
        // fire escape
        s
          ..strokeWidth = 2.4
          ..color = const Color(0xFF0c0719);
        final fe = Path()..moveTo(bx + bw - 10, -bh * .72);
        for (var k = 0; k < 5; k++) {
          fe.lineTo(bx + bw - 54, -bh * .72 + 28 + k * 56);
          fe.lineTo(bx + bw - 10, -bh * .72 + 56 + k * 56);
        }
        g.drawPath(fe, s);
      }
      i++;
    }
    // neon sign frames, drawn lit; the flicker darkens them in liveMid
    for (final sg in _signs) {
      g.drawRRect(RRect.fromLTRBR(sg.x - 5, sg.y - 5, sg.x + 33, sg.y + sg.h + 5, const Radius.circular(8)), p..color = const Color(0xFF0c0719));
      _tube(g, sg, look, true);
    }
  }

  void _tube(Canvas g, _Sign sg, FightLook look, bool on) {
    final col = on ? sg.col : dk(sg.col, .62), col2 = on ? sg.col2 : dk(sg.col2, .62);
    final frame = RRect.fromLTRBR(sg.x, sg.y, sg.x + 28, sg.y + sg.h, const Radius.circular(6));
    if (look == FightLook.cartoon) {
      s
        ..strokeWidth = 6.5
        ..color = kInk;
      g.drawRRect(frame, s);
    }
    s
      ..strokeWidth = 3.4
      ..color = col;
    g.drawRRect(frame, s);
    s
      ..strokeWidth = 3
      ..color = col2;
    for (var k = 0; k < 3; k++) {
      final yy = sg.y + 18 + k * (sg.h - 36) / 2;
      g.drawLine(Offset(sg.x + 7, yy), Offset(sg.x + (k == 1 ? 14 : 21), yy), s);
    }
  }

  @override
  void drawNear(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    const top = -64.0;
    final shutter = const Rect.fromLTRB(kWx0, top, kWx1, 0);
    if (paint) {
      g.drawRect(shutter, p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, top), const Offset(0, 0), const [Color(0xFF38285c), Color(0xFF150e2a)]));
      p.shader = null;
    } else {
      g.drawRect(shutter, p..shader = null..color = const Color(0xFF2a1c4a));
    }
    // slats
    s
      ..strokeWidth = cel ? 1.6 : 1.2
      ..color = cel ? kInk : const Color(0xFF1a1030);
    for (var y = top + 10; y < 0; y += 11) {
      g.drawLine(Offset(kWx0, y), Offset(kWx1, y), s);
    }
    g.drawRect(const Rect.fromLTRB(kWx0, top - 5, kWx1, top + 1), p..shader = null..color = const Color(0xFF4FF3FF));
    if (cel) {
      s
        ..strokeWidth = 2.4
        ..color = kInk;
      g.drawLine(const Offset(kWx0, top - 5), const Offset(kWx1, top - 5), s);
    }
    // graffiti
    for (final gx in const [60.0, 700.0, 1360.0]) {
      g.drawRect(Rect.fromLTWH(gx, -44, 130, 8), p..color = paint ? const Color(0x66FF4FA0) : const Color(0xFFB8365E));
      g.drawRect(Rect.fromLTWH(gx + 26, -30, 80, 6), p..color = paint ? const Color(0x664FF3FF) : const Color(0xFF2E8F88));
    }
    // two food stalls
    for (final sx in const [330.0, 1130.0]) {
      const aw = 150.0;
      // glow of the stall inside
      g.drawRect(Rect.fromLTWH(sx - aw / 2 + 10, -150, aw - 20, 100), p..color = const Color(0xFF4a2a1c));
      if (paint) {
        g.drawRect(
          Rect.fromLTWH(sx - aw / 2 + 10, -150, aw - 20, 100),
          p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(Offset(0, -150), const Offset(0, -50), const [Color(0xFFFFB35C), Color(0xFF6a3a22)]),
        );
        p.shader = null;
      } else {
        g.drawRect(Rect.fromLTWH(sx - aw / 2 + 10, -150, aw - 20, 60), p..color = const Color(0xFFd88a42));
      }
      // counter
      shape(g, Path()..addRect(Rect.fromLTWH(sx - aw / 2, -52, aw, 52)), const Color(0xFF3a2830), look, lowC: const Color(0xFF1c1220), bounds: const Rect.fromLTRB(0, -52, 0, 0), ink: 2.4);
      // awning: alternating stripes
      for (var k = 0; k < 6; k++) {
        final ax = sx - aw / 2 - 8 + k * (aw + 16) / 6;
        final stripe = Path()
          ..moveTo(ax, -190)
          ..lineTo(ax + (aw + 16) / 6, -190)
          ..lineTo(ax + (aw + 16) / 6 + 3, -150)
          ..lineTo(ax - 3, -150)
          ..close();
        shape(g, stripe, k.isEven ? const Color(0xFFd8384e) : const Color(0xFFf0e2c8), look, ink: 1.8);
      }
      p.color = const Color(0xFF150e22);
      g.drawRect(Rect.fromLTWH(sx + 44, -214, 16, 28), p);
      g.drawRect(Rect.fromLTWH(sx - aw / 2 - 2, -150, 4, 150), p);
      g.drawRect(Rect.fromLTWH(sx + aw / 2 - 2, -150, 4, 150), p);
      // hanging lanterns
      for (final lx in const [-48.0, 0.0, 48.0]) {
        g.drawLine(Offset(sx + lx, -150), Offset(sx + lx, -134), s..strokeWidth = 1.6..color = const Color(0xFF150e22));
        g.drawOval(Rect.fromCenter(center: Offset(sx + lx, -124), width: 18, height: 22), p..color = const Color(0xFFff6a3c));
        if (cel) g.drawOval(Rect.fromCenter(center: Offset(sx + lx, -124), width: 18, height: 22), s..strokeWidth = 1.8..color = kInk);
      }
    }
  }

  // ------------------------------------------------------------------ live

  @override
  void liveMid(StageCtx x) {
    final f = x.t;
    x.inLayer(parallax[1], zoom[1], (g) {
      for (final sg in _signs) {
        final on = x.motion == 0 || _on(sg, f);
        if (!on) {
          g.drawRRect(RRect.fromLTRBR(sg.x - 5, sg.y - 5, sg.x + 33, sg.y + sg.h + 5, const Radius.circular(8)), p..shader = null..color = const Color(0xFF0c0719));
          _tube(g, sg, x.look, false);
        } else if (x.paint) {
          drawGlow(g, Offset(sg.x + 14, sg.y + sg.h / 2), 62, withA(sg.col, .55));
        }
      }
    });
  }

  @override
  void liveFront(StageCtx x) {
    final c = x.c, w = x.size.width, h = x.size.height, su = x.su, gy = x.gy;
    final f = x.t;
    // lanterns on a line across the top
    final path = Path();
    double ly(double t) => (46 - t * 12 + math.sin(t * math.pi) * 40) * su;
    for (var i = 0; i <= 40; i++) {
      final t = i / 40;
      i == 0 ? path.moveTo(t * w, ly(t)) : path.lineTo(t * w, ly(t));
    }
    s
      ..strokeWidth = 1.4 * su.clamp(.8, 2.0)
      ..color = x.paint ? const Color(0xCC0C0719) : const Color(0xFF150e22);
    c.drawPath(path, s);
    final count = (w / (96 * su)).floor().clamp(5, 16);
    for (var i = 0; i < count; i++) {
      final t = (i + .5) / count;
      final sway = x.motion == 0 ? 0.0 : math.sin(f * .035 + i * 1.9) * 3.2 * su;
      final lx = t * w + sway, lyy = ly(t) + 14 * su;
      final col = i % 3 == 0 ? const Color(0xFFFF4F6A) : (i % 3 == 1 ? const Color(0xFFFFB04F) : const Color(0xFFFF7A9A));
      if (x.paint) drawGlow(c, Offset(lx, lyy), 26 * su, withA(col, .5));
      c.drawLine(Offset(t * w, ly(t)), Offset(lx, lyy - 8 * su), s..strokeWidth = 1.2 * su.clamp(.8, 2.0));
      c.drawOval(Rect.fromCenter(center: Offset(lx, lyy), width: 11 * su, height: 14 * su), p..shader = null..color = col);
      if (x.cel) {
        c.drawOval(
          Rect.fromCenter(center: Offset(lx, lyy), width: 11 * su, height: 14 * su),
          s
            ..strokeWidth = 1.3 * su.clamp(.8, 2.0)
            ..color = kInk,
        );
      }
    }
    // steam over the stalls
    final ns = x.count(6);
    if (ns > 0) {
      x.inLayer(parallax[2], zoom[2], (g) {
        for (final sx in const [330.0, 1130.0]) {
          for (var i = 0; i < ns ~/ 2; i++) {
            final u = ((f * .006 + i * .34) % 1.0);
            g.drawOval(
              Rect.fromCenter(center: Offset(sx + 52 + math.sin(u * 7 + i) * 7, -226 - u * 80), width: 14 + u * 20, height: 10 + u * 10),
              p..shader = null..color = Color.fromRGBO(235, 225, 255, .22 * (1 - u)),
            );
          }
        }
      });
    }
    // rain
    final n = x.count(60);
    if (n > 0) {
      final ln = _rain.streaks(n, f, w + 40 * su, h, -.0045, .028, -5 * su, 20 * su, x0: -20 * su);
      s
        ..strokeWidth = (x.paint ? 1.1 : 1.5) * su.clamp(.7, 2.0)
        ..strokeCap = StrokeCap.butt
        ..color = x.paint ? const Color(0x77BFD8FF) : (x.cel ? const Color(0xAAB4D0FF) : const Color(0xAA9FC0FF));
      c.drawRawPoints(PointMode.lines, n == 60 ? ln : Float32List.sublistView(ln, 0, n * 4), s);
      s.strokeCap = StrokeCap.round;
    }
    // ripples on the wet floor
    final nr = x.count(9);
    final fh = h - gy;
    for (var i = 0; i < nr; i++) {
      final u = ((f * .011 + _ripple.unit(i) * 3) % 1.0);
      final rx = ((_ripple.phase(i) * 97.3) % 1.0) * w, ry = gy + fh * (.18 + (_ripple.unit(i) * 7.7 % 1.0) * .72);
      final rr = (4 + u * 16) * su * (.6 + (ry - gy) / fh * .7);
      c.drawOval(
        Rect.fromCenter(center: Offset(rx, ry), width: rr * 2, height: rr * .55),
        s
          ..strokeWidth = 1.2 * su.clamp(.7, 2.0)
          ..color = Color.fromRGBO(200, 220, 255, .55 * (1 - u)),
      );
    }
  }

  @override
  void liveFloor(StageCtx x) {
    final c = x.c, gy = x.gy, h = x.size.height, fh = h - gy;
    if (fh <= 0) return;
    final uf = x.cam.scale * 0.746;
    final f = x.t;
    // puddles anchored in the world, each mirroring a sign
    var k = 0;
    for (final (wx, row, col) in const [(150.0, .45, _pink), (470.0, .75, _cyan), (700.0, .32, _yellow), (1010.0, .66, _pink), (1290.0, .5, _violet)]) {
      final sx = x.cam.originX + wx * x.cam.scale, sy = gy + fh * row;
      final pw = 150 * uf, ph = 20 * uf * (.7 + row * .8);
      if (sx < -pw || sx > x.size.width + pw) {
        k++;
        continue;
      }
      c.drawOval(Rect.fromCenter(center: Offset(sx, sy), width: pw, height: ph), p..shader = null..color = x.paint ? const Color(0x401C1840) : const Color(0xFF1c1840));
      final sg = _signs[k % _signs.length];
      final lit = x.motion == 0 || _on(sg, f);
      if (lit) {
        if (x.paint) {
          drawGlow(c, Offset(sx, sy), pw * .5, withA(col, .42));
        } else {
          c.drawOval(Rect.fromCenter(center: Offset(sx, sy), width: pw * .5, height: ph * .45), p..color = withA(col, .85));
        }
      }
      k++;
    }
  }
}
