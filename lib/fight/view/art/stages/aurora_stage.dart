// Stage 3, Aurora Shrine: a snowy mountain shrine at night. Northern-light
// curtains, twinkling stars, falling snow and lantern glow.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../art_common.dart';
import '../glow.dart';
import 'stage_base.dart';

class AuroraStage extends StageScene {
  final ParticleField _snow = ParticleField(81, 44), _flake = ParticleField(82, 20), _rays = ParticleField(83, 40);
  Shader? _bandA, _bandB;
  Size _bandSize = Size.zero;

  @override
  FloorSpec get floorSpec => const FloorSpec(
    top: Color(0xFF4b4a63),
    bottom: Color(0xFF14131f),
    line: Color(0x30B8D4FF),
    lineFlat: Color(0xFF282638),
    rim: Color(0x3A9FD4FF),
    planks: true,
  );

  @override
  void drawSky(Canvas g, double w, double h, FightLook look) {
    final su = h / 400, bot = h * .8;
    ramp(g, Rect.fromLTWH(-40, 0, w + 80, bot), const [(0, 0xFF030a1e), (.4, 0xFF0a1f3e), (.72, 0xFF16456a), (1, 0xFF5a9cc0)], look);
    g.drawRect(Rect.fromLTWH(-40, bot, w + 80, h - bot), p..shader = null..color = const Color(0xFF5a9cc0));
    if (look == FightLook.cartoon) halftone(g, Rect.fromLTWH(-40, 0, w + 80, bot * .4), 0x26);
    final r = SRand(91);
    for (var i = 0; i < 90; i++) {
      final x = r.next() * w - 40, y = r.next() * h * .52;
      final big = r.next() < .16;
      g.drawRect(Rect.fromLTWH(x, y, big ? 2 * su : su, big ? 2 * su : su), p..color = big ? const Color(0xFFFFFFFF) : const Color(0xAAD8ECFF));
    }
    // the moon
    final mx = w * .17 - 40, my = h * .2, mr = 26 * su;
    if (look == FightLook.painted) {
      g.drawCircle(Offset(mx, my), mr * 5, p..color = const Color(0xFFFFFFFF)..shader = Gradient.radial(Offset(mx, my), mr * 5, const [Color(0x66CFE8FF), Color(0x00CFE8FF)]));
      p.shader = null;
    }
    g.drawCircle(Offset(mx, my), mr, p..shader = null..color = const Color(0xFFEAF4FF));
    g.drawCircle(Offset(mx - mr * .3, my - mr * .1), mr * .22, p..color = const Color(0xFFCFE0F2));
    g.drawCircle(Offset(mx + mr * .35, my + mr * .3), mr * .16, p..color = const Color(0xFFCFE0F2));
  }

  void _ensureBands(Size size) {
    if (_bandSize == size) return;
    _bandSize = size;
    final h = size.height;
    _bandA = Gradient.linear(Offset(0, h * .08), Offset(0, h * .5), const [Color(0x00FFFFFF), Color(0x907DFFC0), Color(0xAA3FE0B0), Color(0x00209090)], const [0, .25, .6, 1]);
    _bandB = Gradient.linear(Offset(0, h * .12), Offset(0, h * .52), const [Color(0x00FFFFFF), Color(0x70C080FF), Color(0x6070A0FF), Color(0x00209090)], const [0, .3, .65, 1]);
  }

  /// One curtain: top edge wanders as a sum of two travelling sines; the
  /// bottom edge hangs a wavering distance below it.
  Path _curtain(double w, double h, double y0, double amp, double len, double ph, double fq, int t) {
    final path = Path();
    const n = 22;
    double top(double u) => y0 + amp * (math.sin(u * fq + ph + t * .011) + .55 * math.sin(u * fq * 2.3 + ph * 1.7 - t * .017));
    for (var i = 0; i <= n; i++) {
      final u = i / n * w;
      final yy = top(i / n * 6.28);
      i == 0 ? path.moveTo(u, yy) : path.lineTo(u, yy);
    }
    for (var i = n; i >= 0; i--) {
      final u = i / n * w;
      final yy = top(i / n * 6.28) + len * (.65 + .35 * math.sin(i * .9 + ph + t * .02));
      path.lineTo(u, yy);
    }
    path.close();
    return path;
  }

  @override
  void liveSky(StageCtx x) {
    _ensureBands(x.size);
    final c = x.c, w = x.size.width, h = x.size.height, su = x.su;
    final t = x.t;
    // twinkle: a few bright stars blink
    final nt = x.count(10);
    if (nt > 0) {
      final pts = _rays.points(nt, 0, w, h * .45);
      s
        ..strokeWidth = 2.4 * su
        ..color = Color.fromRGBO(255, 255, 255, .5 + .5 * math.sin(t * .09));
      c.drawRawPoints(PointMode.points, Float32List.sublistView(pts, 0, nt * 2), s);
    }
    // curtains
    final amp = h * .03, len = h * .24;
    final a = _curtain(w, h, h * .2, amp, len, 0, 5.2, t), b = _curtain(w, h, h * .26, amp * 1.2, len * .9, 2.1, 4.1, t);
    if (x.paint) {
      c.drawPath(b, p..color = const Color(0xFFFFFFFF)..shader = _bandB);
      c.drawPath(a, p..color = const Color(0xFFFFFFFF)..shader = _bandA);
      p.shader = null;
    } else {
      c.drawPath(b, p..shader = null..color = const Color(0x5574A0FF));
      c.drawPath(a, p..color = x.cel ? const Color(0x667DFFC0) : const Color(0x887DFFC0));
      c.drawPath(a, s..strokeWidth = 1.6 * su..color = const Color(0x669CFFD8));
    }
    // rays: thin light lines standing on the curtain (painted only)
    final nr = x.paint ? x.count(28) : 0;
    if (nr > 0) {
      for (var i = 0; i < nr; i++) {
        final u = (i + .5) / nr, k = u * 6.28 * 5.2;
        final top = h * .2 + amp * (math.sin(k + t * .011) + .55 * math.sin(k * 2.3 - t * .017));
        final px = u * w;
        _rays.lines[i * 4] = px;
        _rays.lines[i * 4 + 1] = top + len * .08;
        _rays.lines[i * 4 + 2] = px + 2 * su;
        _rays.lines[i * 4 + 3] = top + len * (.4 + .25 * math.sin(i * 1.3 + t * .02));
      }
      s
        ..strokeWidth = 1.3 * su
        ..strokeCap = StrokeCap.butt
        ..color = const Color(0x1ED8FFF0);
      c.drawRawPoints(PointMode.lines, Float32List.sublistView(_rays.lines, 0, nr * 4), s);
      s.strokeCap = StrokeCap.round;
    }
  }

  @override
  void drawFar(Canvas g, FightLook look) {
    final paint = look == FightLook.painted;
    final r = SRand(101);
    var x = kWx0 - 80;
    while (x < kWx1 + 80) {
      final w = 200 + r.next() * 140, hgt = 190 + r.next() * 150, lean = (r.next() - .5) * w * .2;
      final px = x + w / 2 + lean;
      final body = Path()..moveTo(x, 20)..lineTo(px - w * .1, -hgt * .72)..lineTo(px, -hgt)..lineTo(px + w * .12, -hgt * .7)..lineTo(x + w, 20)..close();
      shape(g, body, const Color(0xFF2d5070), look, lowC: const Color(0xFF1c3552), bounds: Rect.fromLTRB(0, -hgt, 0, 20), ink: 2.2);
      // shadowed face
      g.drawPath(Path()..moveTo(px, -hgt)..lineTo(px + w * .12, -hgt * .7)..lineTo(x + w, 20)..lineTo(px + w * .08, 20)..close(), p..shader = null..color = const Color(0x401C3552));
      // snow cap with a ragged edge
      final cap = Path()
        ..moveTo(px - w * .1, -hgt * .72)
        ..lineTo(px, -hgt)
        ..lineTo(px + w * .12, -hgt * .7)
        ..lineTo(px + w * .07, -hgt * .6)
        ..lineTo(px + w * .02, -hgt * .67)
        ..lineTo(px - w * .03, -hgt * .56)
        ..lineTo(px - w * .08, -hgt * .64)
        ..close();
      g.drawPath(cap, p..color = paint ? const Color(0xFFDCEEFA) : const Color(0xFFCFE6F5));
      x += w * (.55 + r.next() * .25);
    }
    // haze at the foot
    if (paint) {
      g.drawRect(const Rect.fromLTRB(kWx0, -170, kWx1, 20), p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, -170), const Offset(0, 20), const [Color(0x00A0D0F0), Color(0x88A0D0F0)]));
      p.shader = null;
    } else {
      g.drawRect(const Rect.fromLTRB(kWx0, -50, kWx1, 20), p..color = const Color(0x40A0D0F0));
    }
  }

  void _pine(Canvas g, double x, double base, double h, FightLook look, Color col) {
    final w = h * .42;
    final tree = Path();
    const tiers = 4;
    tree.moveTo(x, base - h);
    for (var i = 0; i < tiers; i++) {
      final y = base - h + (i + 1) * h / tiers * .95, hw = w * (.35 + .65 * (i + 1) / tiers);
      tree.lineTo(x + hw, y);
      tree.lineTo(x + hw * .45, y);
    }
    tree.lineTo(x + w * .08, base);
    tree.lineTo(x - w * .08, base);
    for (var i = tiers - 1; i >= 0; i--) {
      final y = base - h + (i + 1) * h / tiers * .95, hw = w * (.35 + .65 * (i + 1) / tiers);
      tree.lineTo(x - hw * .45, y);
      tree.lineTo(x - hw, y);
    }
    tree.close();
    shape(g, tree, col, look, ink: 1.8);
    // snow on the tips
    g.drawPath(Path()..moveTo(x, base - h)..lineTo(x + w * .2, base - h + h * .26)..lineTo(x - w * .2, base - h + h * .26)..close(), p..shader = null..color = const Color(0xFFBFD8EA));
  }

  @override
  void drawMid(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    // snowy rolling hill the shrine stands on
    shape(g, ridgePath(111, kWx0, kWx1, -76, 54, 70, step: 14), const Color(0xFF8fb6d2), look, lowC: const Color(0xFF4d7396), bounds: const Rect.fromLTRB(0, -140, 0, 70), ink: 2.2);
    // the pine forest
    final r = SRand(121);
    for (var x = kWx0 + 20; x < kWx1; x += 34 + r.next() * 40) {
      if (x > 690 && x < 980) continue; // clearing for the shrine
      _pine(g, x, -60 + r.next() * 24, 100 + r.next() * 110, look, r.next() < .5 ? const Color(0xFF0f2b40) : const Color(0xFF123349));
    }
    // the shrine hall
    const sx = 835.0, by = -92.0;
    final hall = Rect.fromLTWH(sx - 64, by - 62, 128, 62);
    shape(g, Path()..addRect(hall), const Color(0xFF5b2f40), look, lowC: const Color(0xFF3a1c2c), bounds: hall, ink: 2.4);
    for (final wx in const [-42.0, -8.0, 26.0]) {
      g.drawRect(Rect.fromLTWH(sx + wx, by - 48, 22, 32), p..shader = null..color = const Color(0xFFFFC66B));
      if (paint) g.drawRect(Rect.fromLTWH(sx + wx - 4, by - 52, 30, 40), p..color = const Color(0x30FFC66B));
      if (cel) g.drawRect(Rect.fromLTWH(sx + wx, by - 48, 22, 32), s..strokeWidth = 1.8..color = kInk);
    }
    for (final (rw, ry, rh) in const [(110.0, -62.0, 34.0), (78.0, -108.0, 30.0), (46.0, -148.0, 26.0)]) {
      final y = by + ry;
      final roof = Path()
        ..moveTo(sx - rw - 14, y + 4)
        ..quadraticBezierTo(sx - rw * .55, y + 2, sx - rw * .3, y - rh)
        ..lineTo(sx + rw * .3, y - rh)
        ..quadraticBezierTo(sx + rw * .55, y + 2, sx + rw + 14, y + 4)
        ..quadraticBezierTo(sx, y + 12, sx - rw - 14, y + 4)
        ..close();
      shape(g, roof, const Color(0xFF1d2c48), look, ink: 2.2);
      g.drawPath(
        Path()..moveTo(sx - rw * .32, y - rh)..lineTo(sx + rw * .32, y - rh)..lineTo(sx + rw * .4, y - rh + 8)..lineTo(sx - rw * .4, y - rh + 8)..close(),
        p..shader = null..color = const Color(0xFFDCEEFA),
      );
    }
    g.drawRect(Rect.fromLTWH(sx - 2, by - 200, 4, 22), p..color = const Color(0xFF1d2c48));
    // stone steps
    g.drawRect(Rect.fromLTWH(sx - 52, by, 104, 12), p..color = const Color(0xFF6a7f98));
    g.drawRect(Rect.fromLTWH(sx - 70, by + 12, 140, 12), p..color = const Color(0xFF5a6f88));
  }

  @override
  void drawNear(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    // snow bank along the floor line
    shape(g, ridgePath(131, kWx0, kWx1, -34, 22, 4, step: 10, freq: 1.4), const Color(0xFF86a8c6), look, lowC: const Color(0xFF3f5f80), bounds: const Rect.fromLTRB(0, -60, 0, 4), ink: 2.4);
    // torii, a little smaller than life so it frames rather than blocks
    const tx = 300.0;
    g.save();
    g.translate(tx, 0);
    g.scale(.8);
    g.translate(-tx, 0);
    for (final dx in const [-84.0, 84.0]) {
      final col = Path()..addRect(Rect.fromLTWH(tx + dx - 13, -300, 26, 300));
      shape(g, col, const Color(0xFF8a3140), look, lowC: const Color(0xFF4a1c2c), bounds: const Rect.fromLTRB(0, -300, 0, 0), ink: 2.4);
      g.drawRect(Rect.fromLTWH(tx + dx - 17, -22, 34, 22), p..shader = null..color = const Color(0xFF1c2438));
    }
    final beam = Path()
      ..moveTo(tx - 150, -306)
      ..quadraticBezierTo(tx, -296, tx + 150, -306)
      ..lineTo(tx + 140, -330)
      ..quadraticBezierTo(tx, -318, tx - 140, -330)
      ..close();
    shape(g, beam, const Color(0xFF1d2438), look, ink: 2.4);
    g.drawPath(Path()..moveTo(tx - 138, -330)..quadraticBezierTo(tx, -318, tx + 138, -330)..lineTo(tx + 132, -338)..quadraticBezierTo(tx, -326, tx - 132, -338)..close(), p..shader = null..color = const Color(0xFFDCEEFA));
    shape(g, Path()..addRect(Rect.fromLTWH(tx - 104, -268, 208, 16)), const Color(0xFF8a3140), look, ink: 2.2);
    g.restore();
    // stone lanterns
    for (final lx in const [120.0, 640.0, 1090.0, 1380.0]) {
      final ped = Path()..addRect(Rect.fromLTWH(lx - 10, -92, 20, 62));
      shape(g, ped, const Color(0xFF6c7f98), look, lowC: const Color(0xFF3a4a62), bounds: const Rect.fromLTRB(0, -92, 0, -30), ink: 2.2);
      shape(g, Path()..addRect(Rect.fromLTWH(lx - 24, -132, 48, 40)), const Color(0xFF7a8ea6), look, lowC: const Color(0xFF43546c), bounds: const Rect.fromLTRB(0, -132, 0, -92), ink: 2.2);
      g.drawRect(Rect.fromLTWH(lx - 12, -124, 24, 24), p..shader = null..color = const Color(0xFFFFC66B));
      if (cel) g.drawRect(Rect.fromLTWH(lx - 12, -124, 24, 24), s..strokeWidth = 1.8..color = kInk);
      final cap = Path()..moveTo(lx - 34, -132)..lineTo(lx, -160)..lineTo(lx + 34, -132)..close();
      shape(g, cap, const Color(0xFF55688a), look, ink: 2.2);
      g.drawPath(Path()..moveTo(lx - 22, -144)..lineTo(lx, -160)..lineTo(lx + 22, -144)..lineTo(lx + 14, -140)..lineTo(lx, -146)..lineTo(lx - 14, -140)..close(), p..color = const Color(0xFFDCEEFA));
      g.drawCircle(Offset(lx, -166), 5, p..color = const Color(0xFF55688a));
      g.drawOval(Rect.fromCenter(center: Offset(lx, -28), width: 64, height: 12), p..color = const Color(0xFF86a8c6));
    }
    if (paint) {
      // soft drifts on top of the bank
      g.drawRect(const Rect.fromLTRB(kWx0, -34, kWx1, -26), p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(const Offset(0, -34), const Offset(0, -26), const [Color(0x40FFFFFF), Color(0x00FFFFFF)]));
      p.shader = null;
    }
  }

  @override
  void liveMid(StageCtx x) {
    if (!x.paint) return;
    final a = x.t == 0 ? .5 : .5 + .5 * math.sin(x.t * .09);
    x.inLayer(parallax[1], zoom[1], (g) {
      drawGlow(g, const Offset(835, -130), 110, Color.fromRGBO(255, 190, 100, .22 + .1 * a));
    });
    x.inLayer(parallax[2], zoom[2], (g) {
      for (var i = 0; i < 4; i++) {
        final lx = const [120.0, 640.0, 1090.0, 1380.0][i];
        final fl = x.t == 0 ? .5 : .5 + .5 * math.sin(x.t * .13 + i * 2.3);
        drawGlow(g, Offset(lx, -112), 48, Color.fromRGBO(255, 190, 100, .38 + .16 * fl));
      }
    });
  }

  @override
  void liveFront(StageCtx x) {
    final c = x.c, w = x.size.width, h = x.size.height, su = x.su, gy = x.gy;
    final f = x.t;
    final n1 = x.count(44);
    if (n1 > 0) {
      final pts = _snow.points(n1, f, w + 60 * su, gy * 1.02, vx: -.00045, vy: .0042, wob: 9 * su, wf: .03, x0: -30 * su);
      s
        ..strokeWidth = 2.6 * su
        ..color = const Color(0xFFEAF4FF);
      c.drawRawPoints(PointMode.points, n1 == 44 ? pts : Float32List.sublistView(pts, 0, n1 * 2), s);
    }
    final n2 = x.count(20);
    if (n2 > 0) {
      final pts = _flake.points(n2, f, w + 60 * su, h, vx: -.0007, vy: .0068, wob: 14 * su, wf: .045, x0: -30 * su);
      s
        ..strokeWidth = 4 * su
        ..color = x.paint ? const Color(0xCCFFFFFF) : const Color(0xFFFFFFFF);
      c.drawRawPoints(PointMode.points, n2 == 20 ? pts : Float32List.sublistView(pts, 0, n2 * 2), s);
    }
  }
}
