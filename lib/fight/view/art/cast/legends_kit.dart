// Shared drawing + animation helpers for the LEGENDS family (UNIT-7, KAGE,
// EMBER, GOLEM): rounded polygons, additive glows, flames, pose makers, strike
// timelines and a small world-space context for move effects.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../glow.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, jointRig, poseFor;
import '../roster_poses.dart' show rigScale;

// ------------------------------------------------------------------ paints

final Paint _fp = Paint()..isAntiAlias = true;
final Paint _sp = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;
final Paint _pl = Paint()
  ..isAntiAlias = true
  ..blendMode = BlendMode.plus;
final Paint _pls = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..blendMode = BlendMode.plus;

void fillC(Canvas c, Path p, Color col) => c.drawPath(p, _fp..shader = null..color = col);
void strokeC(Canvas c, Path p, double w, Color col) => c.drawPath(p, _sp..shader = null..strokeWidth = w..color = col);
void lineC(Canvas c, Offset a, Offset b, double w, Color col) => c.drawLine(a, b, _sp..shader = null..strokeWidth = w..color = col);
void dotC(Canvas c, Offset o, double r, Color col) => c.drawCircle(o, r, _fp..shader = null..color = col);
void ringC(Canvas c, Offset o, double r, double w, Color col) => c.drawCircle(o, r, _sp..shader = null..strokeWidth = w..color = col);
void plusFill(Canvas c, Path p, Color col) => c.drawPath(p, _pl..shader = null..color = col);
void plusLine(Canvas c, Offset a, Offset b, double w, Color col) => c.drawLine(a, b, _pls..strokeWidth = w..color = col);
void plusDot(Canvas c, Offset o, double r, Color col) => c.drawCircle(o, r, _pl..shader = null..color = col);
void plusRing(Canvas c, Offset o, double r, double w, Color col) => c.drawCircle(o, r, _pls..strokeWidth = w..color = col);
void plusStroke(Canvas c, Path p, double w, Color col) => c.drawPath(p, _pls..strokeWidth = w..color = col);

void gradFill(Canvas c, Path p, Offset a, Offset b, List<Color> cols, [List<double>? stops]) {
  c.drawPath(
      p,
      _fp
        ..color = const Color(0xFFFFFFFF)
        ..shader = Gradient.linear(a, b, cols, stops));
  _fp.shader = null;
}

void gradStroke(Canvas c, Path p, double w, Offset a, Offset b, List<Color> cols) {
  c.drawPath(
      p,
      _sp
        ..strokeWidth = w
        ..color = const Color(0xFFFFFFFF)
        ..shader = Gradient.linear(a, b, cols));
  _sp.shader = null;
}

/// Clips to [clip] around [f] (draws nothing when the path is empty).
void clipped(Canvas c, Path clip, void Function() f) {
  c.save();
  c.clipPath(clip);
  f();
  c.restore();
}

// ------------------------------------------------------------------ geometry

Offset rotO(Offset o, double a) {
  final cs = math.cos(a), sn = math.sin(a);
  return Offset(o.dx * cs - o.dy * sn, o.dx * sn + o.dy * cs);
}

Offset polar(double a, double r) => Offset(math.cos(a) * r, math.sin(a) * r);

/// A polygon with every corner rounded by up to [r].
Path roundPoly(List<Offset> pts, double r) {
  final n = pts.length;
  final p = Path();
  for (var i = 0; i < n; i++) {
    final a = pts[(i + n - 1) % n], b = pts[i], c = pts[(i + 1) % n];
    final ab = a - b, cb = c - b;
    final la = ab.distance, lc = cb.distance;
    if (la == 0 || lc == 0) continue;
    final ra = math.min(r, la / 2), rc = math.min(r, lc / 2);
    final p1 = b + ab / la * ra, p2 = b + cb / lc * rc;
    if (i == 0) {
      p.moveTo(p1.dx, p1.dy);
    } else {
      p.lineTo(p1.dx, p1.dy);
    }
    p.quadraticBezierTo(b.dx, b.dy, p2.dx, p2.dy);
  }
  p.close();
  return p;
}

/// A box along a bone: half-width [w0] at [a], [w1] at [b], corners rounded by [r].
Path segBox(Offset a, Offset b, double w0, double w1, double r) {
  final d = b - a;
  final l = d.distance;
  if (l == 0) return Path();
  final n = Offset(-d.dy / l, d.dx / l);
  return roundPoly([a + n * w0, b + n * w1, b - n * w1, a - n * w0], r);
}

Rect segRect(Offset a, Offset b, double m) =>
    Rect.fromLTRB(math.min(a.dx, b.dx) - m, math.min(a.dy, b.dy) - m, math.max(a.dx, b.dx) + m, math.max(a.dy, b.dy) + m);

Path ovalP(double x, double y, double rx, double ry, [double rot = 0]) {
  final p = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2));
  if (rot == 0) return p.shift(Offset(x, y));
  final cs = math.cos(rot), sn = math.sin(rot);
  return p.transform(Float64List.fromList([cs, sn, 0, 0, -sn, cs, 0, 0, 0, 0, 1, 0, x, y, 0, 1]));
}

/// A wavy tapered tube along [pts] (half-widths [w0] -> [w1]).
Path tube(List<Offset> pts, double w0, double w1) {
  final l = <Offset>[], r = <Offset>[];
  final n = pts.length;
  for (var i = 0; i < n; i++) {
    final a = pts[math.max(0, i - 1)], b = pts[math.min(n - 1, i + 1)];
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    var ln = math.sqrt(dx * dx + dy * dy);
    if (ln == 0) ln = 1;
    final w = lerpD(w0, w1, i / (n - 1));
    l.add(Offset(pts[i].dx - dy / ln * w, pts[i].dy + dx / ln * w));
    r.add(Offset(pts[i].dx + dy / ln * w, pts[i].dy - dx / ln * w));
  }
  final p = Path()..moveTo(l[0].dx, l[0].dy);
  for (var i = 1; i < n; i++) {
    p.lineTo(l[i].dx, l[i].dy);
  }
  for (var i = n - 1; i >= 0; i--) {
    p.lineTo(r[i].dx, r[i].dy);
  }
  p.close();
  return p;
}

List<Offset> cubic(Offset p0, Offset p1, Offset p2, Offset p3, int n) {
  final o = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final t = i / n, u = 1 - t;
    o.add(Offset(u * u * u * p0.dx + 3 * u * u * t * p1.dx + 3 * u * t * t * p2.dx + t * t * t * p3.dx,
        u * u * u * p0.dy + 3 * u * u * t * p1.dy + 3 * u * t * t * p2.dy + t * t * t * p3.dy));
  }
  return o;
}

Rect boundsOf(List<Offset> pts, [double pad = 4]) {
  var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
  for (final p in pts) {
    x0 = math.min(x0, p.dx);
    y0 = math.min(y0, p.dy);
    x1 = math.max(x1, p.dx);
    y1 = math.max(y1, p.dy);
  }
  return Rect.fromLTRB(x0 - pad, y0 - pad, x1 + pad, y1 + pad);
}

/// Foot rotation shared by all four: flat on the ground, tilted in the air.
double footAngle(Joints j, KPose p, bool back) {
  final an = back ? j.bAn : j.fAn;
  final shin = back ? p.bs : p.fs, off = back ? p.bfa : p.ffa;
  final planted = an.dy >= j.maxAn - 2.5 && p.tuck < .3 && p.ry < 1;
  return planted ? 0 : -shin + off;
}

// ------------------------------------------------------------------ flames

Path flameShape(double len, double wid, double ph, double wob) {
  final tipY = math.sin(ph) * wid * .5 * wob;
  final p = Path()..moveTo(0, -wid);
  p.cubicTo(len * .3, -wid * 1.2, len * .68, -wid * .6 + math.sin(ph + 1) * wid * .25 * wob, len, tipY);
  p.cubicTo(len * .7, wid * .6 + math.sin(ph + 2) * wid * .25 * wob, len * .3, wid * 1.2, 0, wid);
  p.close();
  return p;
}

/// An animated flame from the origin out along +x. Cartoon: flat layers with
/// ink; painted: additive glow and soft layers; pixel: flat layers.
void drawFlame(Canvas c, FightLook look, double len, double wid, int frame, int seed,
    {Color outer = const Color(0xFFFF4B1F),
    Color mid = const Color(0xFFFFA81F),
    Color core = const Color(0xFFFFF1A8),
    double alpha = 1,
    double ink = 1.8}) {
  if (len < 1 || alpha <= 0) return;
  final ph = frame * .9 + seed * 1.7;
  final big = flameShape(len, wid, ph, 1);
  final m = flameShape(len * .72, wid * .62, ph + .8, 1);
  final k = flameShape(len * .42, wid * .3, ph + 1.6, .6);
  if (look == FightLook.painted) {
    drawGlow(c, Offset(len * .38, 0), math.max(len, wid * 3) * .95, withA(mid, .6 * alpha));
    c.drawPath(big, _pl..shader = null..color = withA(outer, .75 * alpha));
    c.drawPath(m, _pl..color = withA(mid, .8 * alpha));
    c.drawPath(k, _pl..color = withA(core, .9 * alpha));
    return;
  }
  fillC(c, big, withA(outer, alpha));
  fillC(c, m, withA(mid, alpha));
  fillC(c, k, withA(core, alpha));
  if (look == FightLook.cartoon) strokeC(c, big, ink, withA(kInk, alpha));
}

/// Rising smoke / dust puffs: [n] circles drifting up from the origin.
void puffs(Canvas c, FightLook look, int age, int seed, int n, double spread, double rise, Color col,
    {double r0 = 3, double grow = 7, int life = 22}) {
  if (age < 0 || age > life) return;
  final k = age / life;
  final r = SRand(seed);
  for (var i = 0; i < n; i++) {
    final a = r.next() * math.pi * 2, d = r.next() * spread * math.sqrt(k + .1);
    final x = math.cos(a) * d, y = math.sin(a) * d * .55 - k * rise * (.5 + r.next() * .5);
    final rad = r0 + grow * k * (.6 + r.next() * .6);
    final al = (1 - k) * (look == FightLook.painted ? .5 : .9);
    dotC(c, Offset(x, y), rad, withA(col, al));
    if (look == FightLook.cartoon && k < .6) ringC(c, Offset(x, y), rad, 1.2, withA(kInk, (1 - k) * .8));
  }
}

/// Star burst / flash used for muzzle flashes and impacts.
void flash(Canvas c, FightLook look, double r, Color col, double a, {int pts = 8, double rot = 0}) {
  if (r < .5 || a <= 0) return;
  if (look == FightLook.painted) {
    drawGlow(c, Offset.zero, r * 2.2, withA(col, a * .85));
    drawGlow(c, Offset.zero, r, withA(const Color(0xFFFFFFFF), a));
    return;
  }
  final st = starPath(0, 0, r, r * .42, pts, rot);
  fillC(c, st, withA(col, a));
  fillC(c, starPath(0, 0, r * .55, r * .22, pts, rot + .2), withA(const Color(0xFFFFFFFF), a));
  if (look == FightLook.cartoon) strokeC(c, st, 1.8, withA(kInk, a));
}

// ------------------------------------------------------------------ poses

/// Pose maker: `q(fu: 1.5)` = [base] with those channels replaced.
class Pq {
  const Pq(this.base);
  final KPose base;
  KPose call({
    double? rx, double? ry, double? lean, double? head, double? fu, double? ff, double? bu, double? bf,
    double? ft, double? fs, double? bt, double? bs, double? ffa, double? bfa, double? spin, double? tuck,
    double? baf, double? blf, double? open, double? sa, double? al, double? sx,
  }) =>
      KPose.from(base,
          rx: rx, ry: ry, lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, ft: ft, fs: fs, bt: bt, bs: bs,
          ffa: ffa, bfa: bfa, spin: spin, tuck: tuck, baf: baf, blf: blf, open: open, sa: sa, al: al, sx: sx);
}

int mx(int a, int b) => a > b ? a : b;
int rd(num v) => v.round();

/// Strictly increasing frames, so a short move never folds its key list back.
List<Key> mono(List<Key> ks) {
  final out = <Key>[];
  for (final k in ks) {
    final f = out.isEmpty ? k.f : (k.f > out.last.f ? k.f : out.last.f + 1);
    out.add(Key(f, k.p, k.ease));
  }
  return out;
}

double boxFront(MoveDef m) {
  var r = 0.0;
  for (final w in m.windows) {
    final f = (w.box.x + w.box.w) / unitsPerPx;
    if (f > r) r = f;
  }
  return r;
}

/// [x] with rx set so the striking joint [eff] reaches the front of the hitbox.
KPose lunge(int id, MoveDef m, KPose x, Jt eff, {double max = 46}) {
  final front = boxFront(m);
  if (front <= 0) return x;
  final base = KPose.from(x, rx: 0);
  final reach = jointRig(base, eff, dimsFor(id)).dx * rigScale(id);
  final need = (front - 6 - reach).clamp(0.0, max);
  return KPose.from(x, rx: need / rigScale(id));
}

/// Wind-up through startup, full extension on the first active frame, hold
/// through active, ease back through recovery (the poser's own recipe).
List<Key> strike(MoveDef m, KPose idle, KPose wind, KPose ext,
    {KPose? hold, KPose? rec, KPose? end, double windAt = .5, double recAt = .35, KPose? w2}) {
  final s = m.startup, a = m.active, r = m.recovery, t = m.total;
  final fw = mx(1, rd(s * windAt)).clamp(1, s > 1 ? s - 1 : 1);
  final keys = <Key>[Key(0, idle), Key(fw, wind)];
  if (w2 != null && s > 3) keys.add(Key(mx(fw + 1, s - 1), w2));
  keys.add(Key(s, ext, 1));
  keys.add(Key(s + (a > 0 ? a : 1), hold ?? ext));
  final fr = s + a + mx(1, rd(r * recAt));
  if (rec != null && fr < t) keys.add(Key(fr, rec));
  keys.add(Key(mx(t, keys.last.f + 1), end ?? idle));
  return mono(keys);
}

// ------------------------------------------------------------------ world fx

/// Where a fighter is on screen, with helpers to place effects on its joints.
class FxCtx {
  FxCtx(this.cam, this.s, this.pl)
      : f = s.p[pl],
        def = s.chars[pl],
        id = s.chars[pl].id {
    rs = rigScale(id);
    dims = dimsFor(id);
  }
  final FightCamera cam;
  final FightState s;
  final int pl, id;
  final Fighter f;
  final CharacterDef def;
  late final double rs;
  late final RigDims dims;
  late final KPose pose = poseFor(s, pl);

  int get face => f.face;

  /// Screen px per rig unit.
  double get u => cam.scale * rs;

  /// Screen px per world px.
  double get k => cam.scale;

  MoveDef? get move => f.state == St.move && f.moveId >= 0 && f.moveId < def.moves.length ? def.moves[f.moveId] : null;
  int get sf => f.sf;

  Offset rig(Offset r) => cam.toScreen(f.x / unitsPerPx + face * r.dx * rs, f.y / unitsPerPx - r.dy * rs);
  Offset joint(Jt j) => rig(jointRig(pose, j, dims));

  /// A point fixed to the torso (rotated by the lean), rig units from the pelvis.
  Offset torso(Offset n) {
    final pel = jointRig(pose, Jt.pel, dims);
    return rig(pel + rotO(n, pose.lean));
  }

  /// [from] (a screen point) moved by a rig-unit delta.
  Offset off(Offset from, Offset rigDelta) => Offset(from.dx + face * rigDelta.dx * u, from.dy + rigDelta.dy * u);

  Offset world(double fwd, double up) => cam.toScreen(f.x / unitsPerPx + face * fwd, f.y / unitsPerPx + up);

  /// Run [draw] with the canvas at [o], +x = the fighter's forward, 1 unit =
  /// [scale] screen px.
  void at(Canvas c, Offset o, double scale, void Function() draw, {double rot = 0}) {
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(face * scale, scale);
    if (rot != 0) c.rotate(rot);
    draw();
    c.restore();
  }
}

Color mixA(Color a, Color b, double t) => mixC(a, b, t);

/// Soft ground shadow-less impact ring used by slams.
void groundRing(Canvas c, FightLook look, double r, double w, Color col, double a) {
  if (a <= 0) return;
  final rect = Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * .35);
  if (look == FightLook.painted) {
    c.drawOval(rect, _pls..strokeWidth = w..color = withA(col, a));
  } else {
    c.drawOval(rect, _sp..shader = null..strokeWidth = w..color = withA(col, a));
  }
}
