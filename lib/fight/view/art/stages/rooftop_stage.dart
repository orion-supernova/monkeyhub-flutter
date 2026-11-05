// Stage 0, the rooftop: cached layer Pictures with parallax plus live neon / lights.
// Ported from the style lab's drawBGStatic / drawBGLive.
import 'dart:math' as math;
import 'dart:ui';

import '../art_common.dart';
import '../camera.dart';
import '../glow.dart';
import '../kai_poses.dart';
import '../kai_rig.dart';

const double _gyl = 338; // lab ground line
const double _x0 = -450, _x1 = 2050; // lab x range of the layer pictures

class _Bld {
  final double x, w, h, y;
  final bool ant;
  _Bld(this.x, this.w, this.h, this.y, this.ant);
}

List<_Bld> _skyline(int seed, double minH, double maxH, double y0) {
  final r = SRand(seed);
  final out = <_Bld>[];
  var x = _x0;
  while (x < _x1) {
    final w = 26 + r.next() * 48, h = minH + r.next() * (maxH - minH);
    r.next();
    final ant = r.next() < .25;
    out.add(_Bld(x, w, h, y0 - h, ant));
    x += w + r.next() * 6;
  }
  return out;
}

class _LookCache {
  Picture? far, mid, near;
  Picture? sky;
  Size skySize = Size.zero;
}

class RooftopStage {
  final Map<FightLook, _LookCache> _c = {};
  final Paint _p = Paint();
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  /// Frees the cached pictures of looks that are not [keep].
  void trim(FightLook keep) {
    for (final e in _c.entries.toList()) {
      if (e.key != keep) {
        e.value.far?.dispose();
        e.value.mid?.dispose();
        e.value.near?.dispose();
        e.value.sky?.dispose();
        _c.remove(e.key);
      }
    }
  }

  /// Frees every cached picture (another stage took over).
  void release() {
    for (final e in _c.values) {
      e.far?.dispose();
      e.mid?.dispose();
      e.near?.dispose();
      e.sky?.dispose();
    }
    _c.clear();
  }

  void paint(Canvas c, Size size, FightCamera cam, FightLook look, int frame) {
    trim(look);
    final lc = _c.putIfAbsent(look, _LookCache.new);
    if (lc.sky == null || lc.skySize != size) {
      lc.sky?.dispose();
      lc.sky = _buildSky(size, look);
      lc.skySize = size;
    }
    lc.far ??= _record((g) => _drawFar(g, look));
    lc.mid ??= _record((g) => _drawMid(g, look));
    lc.near ??= _record((g) => _drawNear(g, look));

    final cx = (size.width / 2 - cam.originX) / cam.scale; // world x at screen centre
    // sky: tiny parallax
    final shift = ((cx - 600) * -.04 * cam.scale).clamp(-36.0, 36.0);
    c.save();
    c.translate(shift - 40, 0);
    c.drawPicture(lc.sky!);
    c.restore();

    final refZ = size.height / 640;
    void layer(Picture pic, double par, double zf) {
      final z = math.max(size.width / 1200, lerpD(refZ, cam.scale, zf));
      final cp = cx * par + (1 - par) * 600;
      c.save();
      c.translate(size.width / 2 - cp * z, cam.groundY);
      c.scale(z);
      c.drawPicture(pic);
      c.restore();
    }

    layer(lc.far!, .22, .35);
    layer(lc.mid!, .5, .65);
    _live(c, size, cam, look, frame, cx, refZ);
    layer(lc.near!, .92, 1);
    _floor(c, size, cam, look, frame);
  }

  Picture _record(void Function(Canvas) draw) {
    final rec = PictureRecorder();
    final g = Canvas(rec);
    g.scale(kFx);
    g.translate(0, -_gyl);
    draw(g);
    return rec.endRecording();
  }

  // ------------------------------------------------------------ sky (screen space)

  Picture _buildSky(Size size, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    final rec = PictureRecorder();
    final g = Canvas(rec);
    final w = size.width + 80, h = size.height;
    g.translate(40, 0);
    final su = h / 400;
    final bot = h * .80;
    const stops = [
      [0.0, 0xFF140c2b], [.32, 0xFF3b1f5e], [.55, 0xFF8a2f6a], [.72, 0xFFe2575a], [.85, 0xFFff9a5c], [1.0, 0xFFffc77a]
    ];
    Color at(double t) {
      var col = Color(stops[0][1] as int);
      for (var j = 1; j < stops.length; j++) {
        if (t >= (stops[j - 1][0] as double)) {
          col = mixC(Color(stops[j - 1][1] as int), Color(stops[j][1] as int),
              math.min(1, (t - (stops[j - 1][0] as double)) / ((stops[j][0] as double) - (stops[j - 1][0] as double))));
        }
      }
      return col;
    }

    if (cel) {
      const bands = 7;
      for (var i = 0; i < bands; i++) {
        g.drawRect(Rect.fromLTWH(-40, bot * i / bands, w + 80, bot / bands + 1), _p..shader = null..color = at(i / (bands - 1)));
      }
      final ht = halftoneShader();
      if (ht != null) {
        g.drawRect(Rect.fromLTWH(-40, 0, w + 80, bot * .45), _p..shader = ht..color = const Color(0x2E000000));
        _p.shader = null;
      }
    } else {
      g.drawRect(
          Rect.fromLTWH(-40, 0, w + 80, bot + 2),
          _p
            ..shader = Gradient.linear(Offset.zero, Offset(0, bot), [for (final s in stops) Color(s[1] as int)],
                [for (final s in stops) s[0] as double]));
      _p.shader = null;
    }
    // below the sky gradient (hidden by the skyline mostly): fill with horizon colour
    g.drawRect(Rect.fromLTWH(-40, bot, w + 80, h - bot), _p..color = const Color(0xFFffc77a));
    final r = SRand(5);
    _p.color = const Color(0xCCFFF0DC);
    for (var i = 0; i < 60; i++) {
      final x = r.next() * w - 40, y = r.next() * h * .3, sz = r.next() < .2 ? 2.0 * su : su;
      g.drawRect(Rect.fromLTWH(x, y, sz, sz), _p);
    }
    // sun
    final sx = w * .6 - 40, sy = h * .62, sr = 80 * su;
    if (paint) {
      g.drawRect(
          Rect.fromLTWH(-40, 0, w + 80, h),
          _p
            ..shader = Gradient.radial(Offset(sx, sy), 260 * su, const [Color(0xBFFFDC96), Color(0x47FF8C6E), Color(0x00FF7878)], const [.04, .3, 1]));
      _p.shader = null;
      g.drawCircle(
          Offset(sx, sy),
          sr,
          _p
            ..shader = Gradient.linear(Offset(0, sy - sr), Offset(0, sy + sr), const [Color(0xFFfff1b8), Color(0xFFff7e5f)]));
      _p.shader = null;
    } else {
      g.drawCircle(Offset(sx, sy), sr, _p..color = const Color(0xFFffe08a));
      g.save();
      g.clipRect(Rect.fromLTWH(sx - sr - 2, sy, sr * 2 + 4, sr + 2));
      g.drawCircle(Offset(sx, sy), sr, _p..color = const Color(0xFFff9f6b));
      g.restore();
      for (var i = 0; i < 6; i++) {
        final y = sy + (8 + i * 11) * su;
        g.drawRect(Rect.fromLTWH(sx - sr, y, sr * 2, (2 + i * 1.1) * su),
            _p..color = mixC(const Color(0xFFe2575a), const Color(0xFFff9a5c), i / 6));
      }
    }
    // clouds
    const clouds = [
      [120.0, 120.0, 150.0, 14.0], [300.0, 92.0, 110.0, 10.0], [560.0, 150.0, 130.0, 12.0], [40.0, 190.0, 120.0, 9.0], [420.0, 200.0, 160.0, 10.0]
    ];
    final sxk = w / 640;
    for (final cl in clouds) {
      final x = cl[0] * sxk - 40 + 100 * sxk * (cl[0] > 300 ? 1 : 0), y = cl[1] * su * .8 + h * .06, cw = cl[2] * su * 1.3, ch = cl[3] * su;
      if (paint) {
        final bp = _p
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..shader = Gradient.linear(Offset(0, y - ch), Offset(0, y + ch), const [Color(0xA6FFBEAA), Color(0x80963C6E)]);
        g.drawOval(Rect.fromCenter(center: Offset(x, y), width: cw, height: ch * 2), bp);
        g.drawOval(Rect.fromCenter(center: Offset(x - cw * .2, y - ch * .6), width: cw / 2, height: ch * 1.8), bp);
        _p
          ..maskFilter = null
          ..shader = null;
      } else {
        g.drawOval(Rect.fromCenter(center: Offset(x, y), width: cw, height: ch * 2), _p..color = const Color(0xFFff9f8c));
        g.drawOval(Rect.fromCenter(center: Offset(x - cw * .18, y - ch * .55), width: cw / 2, height: ch * 1.5), _p..color = const Color(0xFFffc4a8));
        g.drawRect(Rect.fromLTWH(x - cw / 2, y + ch * .35, cw, ch * .65), _p..color = const Color(0xFFc9567a));
      }
    }
    return rec.endRecording();
  }

  // ------------------------------------------------------------ layers (lab coords)

  void _drawFar(Canvas g, FightLook look) {
    final paint = look == FightLook.painted;
    for (final b in _skyline(3, 40, 110, _gyl - 58)) {
      g.drawRect(Rect.fromLTWH(b.x, b.y, b.w, b.h + 60), _p..color = paint ? const Color(0xEB542660) : const Color(0xFF56286a));
      if (b.ant) g.drawRect(Rect.fromLTWH(b.x + b.w / 2 - 1, b.y - 18, 2, 18), _p);
    }
    if (paint) {
      g.drawRect(
          Rect.fromLTWH(_x0, _gyl - 160, _x1 - _x0, 110),
          _p
            ..shader = Gradient.linear(Offset(0, _gyl - 160), Offset(0, _gyl - 50), const [Color(0x00FF8C78), Color(0x59FF9678)]));
      _p.shader = null;
    }
  }

  void _drawMid(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    final wr = SRand(21);
    for (final b in _skyline(9, 60, 150, _gyl - 52)) {
      g.drawRect(Rect.fromLTWH(b.x, b.y, b.w, b.h + 60), _p..color = paint ? const Color(0xFF2a1640) : const Color(0xFF2c1842));
      if (cel) g.drawRect(Rect.fromLTWH(b.x, b.y, 4, b.h + 60), _p..color = const Color(0xFF3b2156));
      for (var wy = b.y + 8; wy < _gyl - 60; wy += 11) {
        for (var wx = b.x + 5; wx < b.x + b.w - 6; wx += 9) {
          final r = wr.next();
          if (r < .22) {
            final col = r < .06 ? const Color(0xFF7ff3ff) : const Color(0xFFffd27a);
            if (paint) g.drawRect(Rect.fromLTWH(wx - 2, wy - 2, 8, 10), _p..color = withA(col, .22));
            g.drawRect(Rect.fromLTWH(wx, wy, 4, 6), _p..color = col);
          }
        }
      }
    }
    // the neon sign's building
    g.drawRect(const Rect.fromLTWH(_nx - 52, _ny - 70, 104, 400), _p..color = paint ? const Color(0xFF241338) : const Color(0xFF281640));
    if (cel) {
      _s
        ..strokeWidth = 2.2
        ..color = kInk;
      g.drawRect(const Rect.fromLTWH(_nx - 52, _ny - 70, 104, 400), _s);
    }
  }

  void _drawNear(Canvas g, FightLook look) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    const wy = _gyl - 62;
    final wallRect = const Rect.fromLTRB(_x0, wy, _x1, _gyl);
    if (paint) {
      g.drawRect(wallRect, _p..shader = Gradient.linear(const Offset(0, wy), const Offset(0, _gyl), const [Color(0xFF4a2c5c), Color(0xFF24152f)]));
      _p.shader = null;
    } else {
      g.drawRect(wallRect, _p..color = const Color(0xFF3b2550));
    }
    g.drawRect(const Rect.fromLTRB(_x0, wy - 6, _x1, wy + 2), _p..color = paint ? const Color(0xFF6a4176) : const Color(0xFF5a3a70));
    if (cel) {
      _s
        ..strokeWidth = 2.5
        ..color = kInk;
      g.drawLine(const Offset(_x0, wy - 6), const Offset(_x1, wy - 6), _s);
      g.drawLine(const Offset(_x0, wy + 2), const Offset(_x1, wy + 2), _s);
      _s.strokeWidth = 1.4;
      for (var x = _x0; x < _x1; x += 64) {
        g.drawLine(Offset(x, wy + 2), Offset(x, _gyl), _s);
      }
    }
    // graffiti stripes (a few, spread along the wall)
    for (final gx in const [380.0, 1020.0, 1560.0]) {
      g.drawRect(Rect.fromLTWH(gx, wy + 18, 170, 10), _p..color = paint ? const Color(0x593fd2c7) : const Color(0xFF2e8f88));
      g.drawRect(Rect.fromLTWH(gx + 30, wy + 30, 110, 6), _p..color = paint ? const Color(0x59ff4f7e) : const Color(0xFFb8365e));
    }
    // water tower
    const tx = 330.0, ty = _gyl - 190;
    final dark = paint ? const Color(0xFF1e1029) : const Color(0xFF1c1029);
    _p.color = dark;
    for (final lx in const [-26.0, -8.0, 10.0, 26.0]) {
      g.drawRect(Rect.fromLTWH(tx + lx - 2, ty + 70, 4, 90), _p);
    }
    g.drawRect(const Rect.fromLTWH(tx - 30, ty + 100, 60, 3), _p);
    g.drawRect(const Rect.fromLTWH(tx - 30, ty + 128, 60, 3), _p);
    final tank = RRect.fromRectAndRadius(const Rect.fromLTWH(tx - 36, ty + 10, 72, 62), const Radius.circular(6));
    g.drawRRect(tank, _p);
    g.drawPath(Path()..moveTo(tx - 40, ty + 12)..lineTo(tx, ty - 16)..lineTo(tx + 40, ty + 12)..close(), _p);
    if (cel) {
      _s
        ..strokeWidth = 2.2
        ..color = kInk;
      g.drawRRect(tank, _s);
      g.drawRect(const Rect.fromLTWH(tx + 30, ty + 12, 4, 58), _p..color = const Color(0xFFff9a5c));
    }
    if (paint) {
      g.drawRect(const Rect.fromLTWH(tx + 31, ty + 12, 5, 58), _p..color = const Color(0x8CFFAA78));
      g.drawRect(const Rect.fromLTWH(tx + 20, ty - 6, 16, 3), _p);
    }
    // AC unit(s)
    for (final ax in const [1180.0, 1700.0]) {
      final ac = RRect.fromRectAndRadius(Rect.fromLTWH(ax, _gyl - 46, 62, 40), const Radius.circular(4));
      g.drawRRect(ac, _p..color = paint ? const Color(0xFF3a2a48) : const Color(0xFF4a3560));
      if (cel) {
        _s
          ..strokeWidth = 2.2
          ..color = kInk;
        g.drawRRect(ac, _s);
      }
      g.drawCircle(Offset(ax + 40, _gyl - 26), 13, _p..color = paint ? const Color(0xFF241a30) : const Color(0xFF2c2038));
    }
  }

  // ------------------------------------------------------------ live parts

  static const double _nx = 1230, _ny = _gyl - 176;

  void _live(Canvas c, Size size, FightCamera cam, FightLook look, int frame, double cx, double refZ) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    final on = (frame % 170 < 4) ? 0.0 : 1.0;
    // neon sign sits on the mid layer
    final z = math.max(size.width / 1200, lerpD(refZ, cam.scale, .65));
    final cp = cx * .5 + .5 * 600;
    c.save();
    c.translate(size.width / 2 - cp * z, cam.groundY);
    c.scale(z * kFx);
    c.translate(0, -_gyl);
    _p
      ..shader = null
      ..color = paint ? const Color(0xD9140A1E) : const Color(0xFF1a0f26);
    c.drawRect(Rect.fromLTWH(_nx - 36, _ny - 34, 72, 68), _p);
    void neon(Color col, void Function(Path) draw, double w) {
      final p = Path();
      draw(p);
      if (paint) {
        if (on > 0) drawGlow(c, Offset(_nx, _ny), 52, withA(col, .55));
        _s
          ..strokeWidth = w
          ..color = on > 0 ? lt(col, .45) : dk(col, .5);
        c.drawPath(p, _s);
      } else {
        if (cel) {
          _s
            ..strokeWidth = w + 3
            ..color = kInk;
          c.drawPath(p, _s);
        }
        _s
          ..strokeWidth = w
          ..color = on > 0 ? col : dk(col, .5);
        c.drawPath(p, _s);
      }
    }

    neon(const Color(0xFFff4f9a), (p) => p.addRRect(RRect.fromLTRBR(_nx - 28, _ny - 26, _nx + 28, _ny + 26, const Radius.circular(10))), 3);
    neon(const Color(0xFF4ff3ff), (p) {
      p
        ..moveTo(_nx - 12, _ny + 12)
        ..lineTo(_nx - 12, _ny - 6)
        ..quadraticBezierTo(_nx - 12, _ny - 14, _nx - 4, _ny - 14)
        ..lineTo(_nx + 8, _ny - 14)
        ..quadraticBezierTo(_nx + 14, _ny - 14, _nx + 14, _ny - 6)
        ..lineTo(_nx + 14, _ny + 4)
        ..quadraticBezierTo(_nx + 14, _ny + 12, _nx + 4, _ny + 12)
        ..close()
        ..moveTo(_nx - 4, _ny - 14)
        ..lineTo(_nx - 4, _ny - 4)
        ..moveTo(_nx + 5, _ny - 14)
        ..lineTo(_nx + 5, _ny - 4);
    }, 2.6);
    c.restore();

    // string lights across the top (screen space)
    final su = size.height / 400, w = size.width;
    final p = Path();
    double ly(double t) => (70 - t * 18 + math.sin(t * math.pi) * 46) * su;
    for (var i = 0; i <= 64; i++) {
      final t = i / 64;
      i == 0 ? p.moveTo(t * w, ly(t)) : p.lineTo(t * w, ly(t));
    }
    _s
      ..strokeWidth = 1.5 * su.clamp(.8, 2.0)
      ..color = paint ? const Color(0xCC140A1E) : const Color(0xFF1a0f26);
    c.drawPath(p, _s);
    final count = (w / (29 * su)).floor().clamp(10, 60);
    for (var i = 0; i < count; i++) {
      final t = (i + .5) / count;
      final x = t * w, y = ly(t) + 5 * su;
      final tw = .6 + .4 * math.sin(frame * .05 + i * 1.7);
      final col = i % 3 == 0 ? const Color(0xFFff7ab0) : (i % 3 == 1 ? const Color(0xFFffd27a) : const Color(0xFF7ff3ff));
      if (paint) {
        drawGlow(c, Offset(x, y), 14 * su * tw, withA(col, .7 * tw));
        c.drawCircle(Offset(x, y), 2.6 * su, _p..color = col);
      } else {
        c.drawCircle(Offset(x, y), 3 * su, _p..color = tw > .55 ? col : dk(col, .35));
        if (cel) {
          _s
            ..strokeWidth = 1.2 * su.clamp(.8, 2.0)
            ..color = kInk;
          c.drawCircle(Offset(x, y), 3 * su, _s);
        }
      }
    }
  }

  void _floor(Canvas c, Size size, FightCamera cam, FightLook look, int frame) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    final gy = cam.groundY, h = size.height, fh = h - gy;
    if (fh <= 0) return;
    final uf = cam.scale * kFx;
    final vpx = cam.originX + 600 * cam.scale;
    final rect = Rect.fromLTRB(0, gy, size.width, h);
    if (paint) {
      c.drawRect(rect, _p..shader = Gradient.linear(Offset(0, gy), Offset(0, h), const [Color(0xFF3a2647), Color(0xFF140c1c)]));
      _p.shader = null;
    } else {
      c.drawRect(rect, _p..color = const Color(0xFF2e1e3c));
    }
    _s
      ..strokeWidth = (cel ? 2 : 1.5) * math.max(1.0, uf)
      ..color = paint ? const Color(0x1FFFB48C) : const Color(0xFF22152e);
    for (var i = -16; i <= 16; i++) {
      c.drawLine(Offset(vpx + i * 34 * uf, gy), Offset(vpx + i * 34 * uf + i * 76 * fh / 62, h), _s);
    }
    for (final fr in const [.22, .55, 1.0]) {
      c.drawLine(Offset(0, gy + fh * fr), Offset(size.width, gy + fh * fr), _s);
    }
    if (cel) {
      _s
        ..strokeWidth = 2.5 * math.max(1.0, uf)
        ..color = kInk;
      c.drawLine(Offset(0, gy), Offset(size.width, gy), _s);
    }
    if (paint) {
      c.drawRect(Rect.fromLTWH(0, gy, size.width, 30 * uf), _p..shader = Gradient.linear(Offset(0, gy), Offset(0, gy + 30 * uf), const [Color(0x2EFFAA82), Color(0x00FFAA82)]));
      _p.shader = null;
      // neon reflections on the floor
      final on = (frame % 170 < 4) ? 0.0 : 1.0;
      final cx = (size.width / 2 - cam.originX) / cam.scale;
      final z = math.max(size.width / 1200, lerpD(size.height / 640, cam.scale, .65));
      final sxn = size.width / 2 + (_nx * kFx - (cx * .5 + 300)) * z;
      drawGlow(c, Offset(sxn, gy + fh * .4), 60 * uf * 1.3, Color.fromRGBO(255, 79, 154, .35 * on));
      drawGlow(c, Offset(sxn, gy + fh * .45), 40 * uf * 1.3, Color.fromRGBO(79, 243, 255, .28 * on));
    }
  }
}
