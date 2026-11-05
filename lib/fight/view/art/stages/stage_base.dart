// Shared machinery for the layered stages: cached layer Pictures with
// parallax, a cached sky, a perspective floor and a few allocation-free helpers
// for ambient motion. A stage only supplies drawing hooks.
//
// World coordinates for the layer pictures: x in world px (the fight runs over
// 0..1200, the pictures cover [kWx0, kWx1]), y = 0 on the floor line, negative
// up. No clips, layers or blurs anywhere: softness comes from gradients.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../art_common.dart';
import '../camera.dart';
import '../kai_poses.dart' show kFx;
import '../kai_rig.dart' show halftoneShader;
import '../quality.dart';

const double kWx0 = -500, kWx1 = 1700;

/// Per-frame facts handed to the live hooks.
class StageCtx {
  late Canvas c;
  late Size size;
  late FightCamera cam;
  late FightLook look;
  int frame = 0;
  double cx = 600, refZ = 1;

  /// Screen units: 1 at 400 px tall (so ambient bits scale with the view).
  double su = 1;

  /// 1 full, .5 reduced, 0 minimal: scales ambient particle counts.
  double motion = 1;

  /// The frame ambient motion runs on: frozen at the minimal quality level.
  int get t => motion == 0 ? 0 : frame;

  bool get cel => look == FightLook.cartoon;
  bool get paint => look == FightLook.painted;
  double get gy => cam.groundY;

  /// Screen px per layer px for a layer at zoom factor [zf].
  double layerZ(double zf) => math.max(size.width / 1200, lerpD(refZ, cam.scale, zf));

  /// Screen x of layer x [wx] for a layer with parallax [par].
  double layerX(double par, double zf, double wx) {
    final cp = cx * par + (1 - par) * 600;
    return size.width / 2 + (wx - cp) * layerZ(zf);
  }

  /// Runs [draw] with the canvas in that layer's world space (y = 0 on the
  /// floor line, scaled like the layer picture).
  void inLayer(double par, double zf, void Function(Canvas g) draw) {
    final z = layerZ(zf);
    final cp = cx * par + (1 - par) * 600;
    c.save();
    c.translate(size.width / 2 - cp * z, cam.groundY);
    c.scale(z);
    draw(c);
    c.restore();
  }

  int count(int n) => (n * motion).round();
}

/// Deterministic drifting points, positions computed per frame into a reused
/// buffer (no allocation, no state).
class ParticleField {
  ParticleField(int seed, this.n) {
    final r = SRand(seed);
    for (var i = 0; i < n; i++) {
      _x[i] = r.next();
      _y[i] = r.next();
      _spd[i] = .6 + r.next() * .8;
      _ph[i] = r.next() * 6.2832;
    }
  }

  final int n;
  late final Float32List _x = Float32List(n), _y = Float32List(n), _spd = Float32List(n), _ph = Float32List(n);
  late final Float32List pts = Float32List(n * 2);
  late final Float32List lines = Float32List(n * 4);

  /// Fills [pts] with [count] points in a [w] x [h] box moving by ([vx], [vy])
  /// box-lengths per frame, with a sideways wobble of [wob] px at [wf] rad/frame.
  Float32List points(int count, int frame, double w, double h, {double vx = 0, double vy = 0, double wob = 0, double wf = .03, double x0 = 0, double y0 = 0}) {
    for (var i = 0; i < count; i++) {
      var u = _x[i] + vx * frame * _spd[i];
      var v = _y[i] + vy * frame * _spd[i];
      u -= u.floorToDouble();
      v -= v.floorToDouble();
      pts[i * 2] = x0 + u * w + (wob == 0 ? 0 : math.sin(_ph[i] + frame * wf * _spd[i]) * wob);
      pts[i * 2 + 1] = y0 + v * h + (wob == 0 ? 0 : math.cos(_ph[i] * 1.7 + frame * wf * .8) * wob * .6);
    }
    return pts;
  }

  /// Streaks: the same motion, each point drawn as a segment of ([dx], [dy]).
  Float32List streaks(int count, int frame, double w, double h, double vx, double vy, double dx, double dy, {double x0 = 0, double y0 = 0}) {
    for (var i = 0; i < count; i++) {
      var u = _x[i] + vx * frame * _spd[i];
      var v = _y[i] + vy * frame * _spd[i];
      u -= u.floorToDouble();
      v -= v.floorToDouble();
      final x = x0 + u * w, y = y0 + v * h, k = .7 + _spd[i] * .3;
      lines[i * 4] = x;
      lines[i * 4 + 1] = y;
      lines[i * 4 + 2] = x + dx * k;
      lines[i * 4 + 3] = y + dy * k;
    }
    return lines;
  }

  double phase(int i) => _ph[i];
  double unit(int i) => _x[i];
}

class FloorSpec {
  const FloorSpec({
    required this.top,
    required this.bottom,
    required this.line,
    required this.lineFlat,
    this.rim = const Color(0x00000000),
    this.planks = false,
    this.perspective = true,
  });

  /// Painted gradient ends, and the flat fill of the cartoon / pixel looks.
  final Color top, bottom;

  /// Seam colour in the painted look / in the flat looks.
  final Color line, lineFlat;

  /// Soft light along the floor line in the painted look.
  final Color rim;

  /// Horizontal boards with staggered joints instead of perspective tiles.
  final bool planks;
  final bool perspective;
}

class _LookCache {
  Picture? far, mid, near, sky;
  Size skySize = Size.zero;
  Shader? floorShader;
  double floorGy = -1, floorH = -1;
  Shader? rimShader;

  void dispose() {
    far?.dispose();
    mid?.dispose();
    near?.dispose();
    sky?.dispose();
  }
}

abstract class StageScene {
  final Map<FightLook, _LookCache> _c = {};
  final Paint p = Paint();
  final Paint s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final StageCtx x = StageCtx();

  // ---- hooks -------------------------------------------------------------

  /// Screen-space backdrop: [g] is translated by (40, 0); [w] = width + 80,
  /// [h] = height. Fill the whole thing (down to the floor line and below).
  void drawSky(Canvas g, double w, double h, FightLook look);

  /// Layer pictures (world coords, floor line at y = 0).
  void drawFar(Canvas g, FightLook look) {}
  void drawMid(Canvas g, FightLook look) {}
  void drawNear(Canvas g, FightLook look) {}

  /// Ambient motion, in draw order: over the sky; over the mid layer; over
  /// everything but the fighters.
  void liveSky(StageCtx x) {}
  void liveMid(StageCtx x) {}
  void liveFront(StageCtx x) {}

  /// Extra floor decoration (reflections, puddles, drifting things).
  void liveFloor(StageCtx x) {}

  FloorSpec get floorSpec;

  /// Layer parallax and zoom factors: far, mid, near.
  List<double> get parallax => const [.22, .5, .92];
  List<double> get zoom => const [.35, .65, 1];

  // ---- machinery -----------------------------------------------------------

  void trim(FightLook keep) {
    for (final e in _c.entries.toList()) {
      if (e.key != keep) {
        e.value.dispose();
        _c.remove(e.key);
      }
    }
  }

  void release() {
    for (final e in _c.values) {
      e.dispose();
    }
    _c.clear();
  }

  Picture _record(void Function(Canvas) draw) {
    final rec = PictureRecorder();
    draw(Canvas(rec));
    return rec.endRecording();
  }

  void paint(Canvas c, Size size, FightCamera cam, FightLook look, int frame) {
    trim(look);
    final lc = _c.putIfAbsent(look, _LookCache.new);
    if (lc.sky == null || lc.skySize != size) {
      lc.sky?.dispose();
      lc.sky = _record((g) {
        g.translate(40, 0);
        drawSky(g, size.width + 80, size.height, look);
      });
      lc.skySize = size;
    }
    lc.far ??= _record((g) => drawFar(g, look));
    lc.mid ??= _record((g) => drawMid(g, look));
    lc.near ??= _record((g) => drawNear(g, look));

    final q = fightQuality.value;
    x
      ..c = c
      ..size = size
      ..cam = cam
      ..look = look
      ..frame = frame
      ..cx = (size.width / 2 - cam.originX) / cam.scale
      ..refZ = size.height / 640
      ..su = size.height / 400
      ..motion = q == FightQuality.full ? 1 : (q == FightQuality.reduced ? .5 : 0);

    final shift = ((x.cx - 600) * -.04 * cam.scale).clamp(-36.0, 36.0);
    c.save();
    c.translate(shift - 40, 0);
    c.drawPicture(lc.sky!);
    c.restore();
    liveSky(x);

    final par = parallax, zf = zoom;
    void layer(Picture pic, double pr, double z) {
      x.inLayer(pr, z, (g) => g.drawPicture(pic));
    }

    layer(lc.far!, par[0], zf[0]);
    layer(lc.mid!, par[1], zf[1]);
    liveMid(x);
    layer(lc.near!, par[2], zf[2]);
    _floor(c, size, cam, look, lc);
    liveFloor(x);
    liveFront(x);
  }

  void _floor(Canvas c, Size size, FightCamera cam, FightLook look, _LookCache lc) {
    final cel = look == FightLook.cartoon, paint = look == FightLook.painted;
    final spec = floorSpec;
    final gy = cam.groundY, h = size.height, fh = h - gy;
    if (fh <= 0) return;
    final uf = cam.scale * kFx;
    final rect = Rect.fromLTRB(0, gy, size.width, h);
    if (paint) {
      if (lc.floorShader == null || lc.floorGy != gy || lc.floorH != h) {
        lc.floorShader = Gradient.linear(Offset(0, gy), Offset(0, h), [spec.top, spec.bottom]);
        lc.rimShader = Gradient.linear(Offset(0, gy), Offset(0, gy + 34 * uf), [spec.rim, spec.rim.withValues(alpha: 0)]);
        lc.floorGy = gy;
        lc.floorH = h;
      }
      c.drawRect(rect, p..color = const Color(0xFFFFFFFF)..shader = lc.floorShader);
      p.shader = null;
    } else {
      c.drawRect(rect, p..color = mixC(spec.top, spec.bottom, .25)..shader = null);
    }
    final lw = (cel ? 2.0 : 1.5) * math.max(1.0, uf);
    s
      ..strokeWidth = lw
      ..color = paint ? spec.line : spec.lineFlat;
    if (spec.planks) {
      final rows = [.2, .46, .74, 1.0];
      for (final fr in rows) {
        c.drawLine(Offset(0, gy + fh * fr), Offset(size.width, gy + fh * fr), s);
      }
      // staggered butt joints, anchored in world x so they slide with the camera
      var prev = 0.0;
      for (var r = 0; r < rows.length; r++) {
        final y0 = gy + fh * prev, y1 = gy + fh * rows[r];
        final sp = (150 + r * 50) * cam.scale;
        final off = cam.originX + (r.isEven ? 0 : sp * .5);
        var xx = off % sp;
        if (xx > 0) xx -= sp;
        for (; xx < size.width; xx += sp) {
          c.drawLine(Offset(xx, y0), Offset(xx, y1), s);
        }
        prev = rows[r];
      }
    } else if (spec.perspective) {
      final vpx = cam.originX + 600 * cam.scale;
      for (var i = -16; i <= 16; i++) {
        c.drawLine(Offset(vpx + i * 34 * uf, gy), Offset(vpx + i * 34 * uf + i * 76 * fh / 62, h), s);
      }
      for (final fr in const [.22, .55, 1.0]) {
        c.drawLine(Offset(0, gy + fh * fr), Offset(size.width, gy + fh * fr), s);
      }
    }
    if (cel) {
      s
        ..strokeWidth = 2.5 * math.max(1.0, uf)
        ..color = kInk;
      c.drawLine(Offset(0, gy), Offset(size.width, gy), s);
    }
    if (paint) {
      c.drawRect(Rect.fromLTWH(0, gy, size.width, 34 * uf), p..color = const Color(0xFFFFFFFF)..shader = lc.rimShader);
      p.shader = null;
    }
  }

  // ---- drawing helpers -------------------------------------------------------

  /// Halftone dots over [r] in the cartoon look (when the shader exists).
  void halftone(Canvas g, Rect r, [int alpha = 0x2E]) {
    final ht = halftoneShader();
    if (ht == null) return;
    g.drawRect(r, p..shader = ht..color = Color.fromARGB(alpha, 0, 0, 0));
    p.shader = null;
  }

  /// Vertical colour ramp drawn as flat bands (cartoon / pixel) or a smooth
  /// gradient (painted). [stops] = list of (t, 0xAARRGGBB).
  void ramp(Canvas g, Rect r, List<(double, int)> stops, FightLook look, {int bands = 7}) {
    Color at(double t) {
      var col = Color(stops[0].$2);
      for (var j = 1; j < stops.length; j++) {
        if (t >= stops[j - 1].$1) {
          col = mixC(Color(stops[j - 1].$2), Color(stops[j].$2), math.min(1, (t - stops[j - 1].$1) / (stops[j].$1 - stops[j - 1].$1)));
        }
      }
      return col;
    }

    if (look == FightLook.cartoon) {
      for (var i = 0; i < bands; i++) {
        final y0 = r.top + r.height * i / bands;
        g.drawRect(Rect.fromLTWH(r.left, y0, r.width, r.height / bands + 1), p..shader = null..color = at(i / (bands - 1)));
      }
    } else {
      g.drawRect(
        r,
        p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(r.topLeft, r.bottomLeft, [for (final e in stops) Color(e.$2)], [for (final e in stops) e.$1]),
      );
      p.shader = null;
    }
  }

  /// Fill [path] with [flat], or (painted) a vertical gradient flat -> [lowC]
  /// over [bounds]; the cartoon look adds an ink outline of width [ink].
  void shape(Canvas g, Path path, Color flat, FightLook look, {Color? lowC, Rect? bounds, double ink = 0}) {
    if (look == FightLook.painted && lowC != null && bounds != null) {
      g.drawPath(path, p..color = const Color(0xFFFFFFFF)..shader = Gradient.linear(bounds.topCenter, bounds.bottomCenter, [flat, lowC]));
      p.shader = null;
    } else {
      g.drawPath(path, p..shader = null..color = flat);
    }
    if (look == FightLook.cartoon && ink > 0) {
      g.drawPath(
        path,
        s
          ..strokeWidth = ink
          ..color = kInk,
      );
    }
  }

  void rect(Canvas g, Rect r, Color col, FightLook look, {double ink = 0}) {
    g.drawRect(r, p..shader = null..color = col);
    if (look == FightLook.cartoon && ink > 0) {
      g.drawRect(
        r,
        s
          ..strokeWidth = ink
          ..color = kInk,
      );
    }
  }
}

/// A smooth rolling silhouette from [x0] to [x1], closed down to [bottomY]:
/// a few summed sines (so it is cheap, repeatable and has no seams), [amp] tall
/// around [baseY], sampled every [step] px.
Path ridgePath(int seed, double x0, double x1, double baseY, double amp, double bottomY, {double step = 12, double freq = 1}) {
  final r = SRand(seed);
  final p1 = r.next() * 6.28, p2 = r.next() * 6.28, p3 = r.next() * 6.28;
  final f1 = (.0042 + r.next() * .002) * freq, f2 = (.011 + r.next() * .004) * freq, f3 = (.027 + r.next() * .01) * freq;
  double y(double x) => baseY - amp * (.5 + .3 * math.sin(x * f1 + p1) + .17 * math.sin(x * f2 + p2) + .08 * math.sin(x * f3 + p3));
  final p = Path()..moveTo(x0, bottomY)..lineTo(x0, y(x0));
  for (var xx = x0 + step; xx < x1; xx += step) {
    p.lineTo(xx, y(xx));
  }
  p..lineTo(x1, y(x1))..lineTo(x1, bottomY)..close();
  return p;
}
