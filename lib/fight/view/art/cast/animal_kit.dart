// Shared drawing helpers for the ANIMALS family (RYOKO, BAO, VEX, GALE): a thin
// pen over RigPainter for flat marks, variable-width tubes, the three-line
// claw slash and the world-space frame used by the move effects.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../glow.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, jointRig;
import '../roster_poses.dart' show rigScale;

export '../roster_rig.dart' show pathOf, ellP, tubePath, bez, bbOf;

/// Flat (non-shaded) drawing on top of RigPainter's canvas and look.
class Pen {
  Pen(this.r);
  RigPainter r;

  Canvas get c => r.c;
  bool get sil => r.sil != null;
  bool get cel => r.cel;
  bool get paint => r.paint;
  bool get pix => r.pix;

  final Paint _f = Paint()..isAntiAlias = true;
  final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  void flat(Path p, Color col) => c.drawPath(p, _f..shader = null..color = col);
  void circ(double x, double y, double rad, Color col) => c.drawCircle(Offset(x, y), rad, _f..shader = null..color = col);
  void ink(Path p, double w, [Color col = kInk]) => c.drawPath(p, _s..shader = null..strokeWidth = w..color = col);
  void line(Offset a, Offset b, double w, Color col) => c.drawLine(a, b, _s..shader = null..strokeWidth = w..color = col);

  /// Fills [marks] clipped to [clip] (stripes, patches). Skipped in silhouettes.
  void clipped(Path clip, Path marks, Color col) {
    if (sil) return;
    c.save();
    c.clipPath(clip);
    flat(marks, col);
    c.restore();
  }

  /// Ink-line colour for fine detail that must read on both light and dark fur.
  Color get fine => paint ? const Color(0x73100618) : kInk;
}

/// A tube along [pts] whose half-width at 0..1 is [w].
Path tubeFn(List<Offset> pts, double Function(double t) w) {
  final l = <Offset>[], rr = <Offset>[];
  final n = pts.length;
  for (var i = 0; i < n; i++) {
    final a = pts[math.max(0, i - 1)], b = pts[math.min(n - 1, i + 1)];
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    var ln = math.sqrt(dx * dx + dy * dy);
    if (ln == 0) ln = 1;
    final ww = w(i / (n - 1));
    l.add(Offset(pts[i].dx - dy / ln * ww, pts[i].dy + dx / ln * ww));
    rr.add(Offset(pts[i].dx + dy / ln * ww, pts[i].dy - dx / ln * ww));
  }
  final p = Path()..moveTo(l[0].dx, l[0].dy);
  for (var i = 1; i < n; i++) {
    p.lineTo(l[i].dx, l[i].dy);
  }
  for (var i = n - 1; i >= 0; i--) {
    p.lineTo(rr[i].dx, rr[i].dy);
  }
  p.close();
  return p;
}

/// Point and direction along a polyline at fraction [t].
(Offset, double) along(List<Offset> pts, double t) {
  final f = clamp01(t) * (pts.length - 1);
  final i = math.min(pts.length - 2, f.floor());
  final u = f - i;
  final a = pts[i], b = pts[i + 1];
  return (Offset(a.dx + (b.dx - a.dx) * u, a.dy + (b.dy - a.dy) * u), math.atan2(b.dy - a.dy, b.dx - a.dx));
}

/// Short bars across a tube (rings, stripes) at the given fractions, [w] half-length.
Path crossBars(List<Offset> pts, List<double> ts, double w, double thick) {
  final p = Path();
  for (final t in ts) {
    final (o, a) = along(pts, t);
    final nx = -math.sin(a), ny = math.cos(a);
    final tx = math.cos(a) * thick * .5, ty = math.sin(a) * thick * .5;
    p.moveTo(o.dx + nx * w - tx, o.dy + ny * w - ty);
    p.lineTo(o.dx + nx * w + tx, o.dy + ny * w + ty);
    p.lineTo(o.dx - nx * w + tx, o.dy - ny * w + ty);
    p.lineTo(o.dx - nx * w - tx, o.dy - ny * w - ty);
    p.close();
  }
  return p;
}

/// Wedge-shaped stripes (tiger / tail): thin triangles pointing from the edge
/// at ([x], [y]) toward ([x]+[dx], [y]+[dy]).
void wedge(Path p, double x, double y, double dx, double dy, double base) {
  final len = math.sqrt(dx * dx + dy * dy);
  final nx = -dy / len * base * .5, ny = dx / len * base * .5;
  p.moveTo(x + nx, y + ny);
  p.lineTo(x + dx, y + dy);
  p.lineTo(x - nx, y - ny);
  p.close();
}

// ------------------------------------------------------------------ move effects

/// World-space frame of one fighter: screen origin at the ground contact,
/// scaled by the rig, mirrored by facing (the same transform the fighter itself
/// is drawn under). [rigPos] turns a rig-space point into a screen point.
class FxFrame {
  FxFrame(this.cam, this.s, this.player) {
    final f = s.p[player];
    id = s.chars[player].id;
    rs = rigScale(id);
    face = f.face;
    origin = cam.toScreen(f.x / unitsPerPx, f.y / unitsPerPx);
    k = cam.scale * rs;
  }
  final FightCamera cam;
  final FightState s;
  final int player;
  late final int id;
  late final double rs, k;
  late final int face;
  late final Offset origin;

  Fighter get f => s.p[player];
  CharacterDef get def => s.chars[player];
  MoveDef? get move {
    if (f.state != St.move || f.moveId < 0 || f.moveId >= def.moves.length) return null;
    return def.moves[f.moveId];
  }

  RigDims get dims => dimsFor(id);

  Offset toScreen(Offset rig) => Offset(origin.dx + rig.dx * k * face, origin.dy + rig.dy * k);

  /// Applies the rig transform so drawing is in rig units (x forward).
  void enter(Canvas c) {
    c.translate(origin.dx, origin.dy);
    c.scale(k * face, k);
  }

  Offset joint(KPose p, Jt jt) => jointRig(p, jt, dims);

  /// Centre of a hit window in rig units (box x is forward of the fighter).
  Offset boxCentre(HitWindow w) =>
      Offset((w.box.x + w.box.w / 2) / unitsPerPx / rs, -(w.box.y + w.box.h / 2) / unitsPerPx / rs);
}

/// Three parallel claw slashes centred on the origin at [angle] (rig space, y
/// down, +x forward). [age] 0..1 over the effect; [len] is the long axis.
void slash3(Canvas c, FightLook look, double angle, double len, double age,
    {Color col = const Color(0xFFFFF4DC), Color glow = const Color(0xFFFFB347), double gap = 7, double wide = 4.4}) {
  if (age < 0 || age > 1) return;
  final e = math.min(1.0, age / .3), fade = 1 - clamp01((age - .35) / .65);
  if (fade <= 0) return;
  final painted = look == FightLook.painted;
  c.save();
  c.rotate(angle);
  for (var i = -1; i <= 1; i++) {
    final L = len * (i == 0 ? 1.0 : .84) * .5;
    final w = wide * fade * (i == 0 ? 1.15 : 1.0) + .6;
    final x0 = -L, x1 = -L + 2 * L * e;
    final bow = L * .22;
    final y = i * gap;
    final p = Path()
      ..moveTo(x0, y + bow * .6)
      ..quadraticBezierTo((x0 + x1) / 2, y - bow - w, x1, y + bow * .2)
      ..quadraticBezierTo((x0 + x1) / 2, y - bow + w, x0, y + bow * .6)
      ..close();
    if (painted) {
      c.drawPath(
          p,
          Paint()
            ..isAntiAlias = true
            ..blendMode = BlendMode.plus
            ..color = withA(col, .9 * fade));
      drawGlow(c, Offset((x0 + x1) / 2, y), L * .7, withA(glow, .25 * fade));
    } else {
      c.drawPath(
          p,
          Paint()
            ..isAntiAlias = true
            ..color = withA(col, fade));
      if (look == FightLook.cartoon) {
        c.drawPath(
            p,
            Paint()
              ..isAntiAlias = true
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = withA(kInk, fade));
      }
    }
  }
  c.restore();
}

/// An expanding ring (dust, shock, spirit) on the ground plane at the origin.
void groundRing(Canvas c, FightLook look, double k, double radius, Color col, {double squash = .28, double thick = 5}) {
  if (k < 0 || k > 1) return;
  final r = radius * easeOut(k), a = 1 - k;
  final rect = Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2 * squash);
  if (look == FightLook.painted) {
    c.drawOval(
        rect,
        Paint()
          ..isAntiAlias = true
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick * a + 1
          ..color = withA(col, .8 * a));
  } else {
    c.drawOval(
        rect,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = thick * a + 1
          ..color = withA(col, a));
    if (look == FightLook.cartoon) {
      c.drawOval(
          rect.inflate(thick * a * .5 + 1),
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color = withA(kInk, a * .8));
    }
  }
}

/// A KAI-derived KPose is "in the air" when both feet-angle offsets of the
/// generic jump poses are set (see kai_poses: pTakeoff / pAir / pDesc).
bool jumpish(KPose p) => p.ffa >= .22 && p.bfa >= .22;

// ------------------------------------------------------------------ animation helpers

int mx(int a, int b) => a > b ? a : b;
int rnd(num v) => v.round();

/// Strictly increasing frames, so a short move never folds its key list back.
List<Key> mono(List<Key> ks) {
  final out = <Key>[];
  for (final k in ks) {
    final f = out.isEmpty ? k.f : (k.f > out.last.f ? k.f : out.last.f + 1);
    out.add(Key(f, k.p, k.ease));
  }
  return out;
}

/// [x] with its rx set so the striking joint [eff] reaches the front of the
/// move's hitbox (the same recipe the starters use).
KPose lunge(MoveDef m, KPose x, Jt eff, RigDims dims, {double max = 46}) {
  var front = 0.0;
  for (final w in m.windows) {
    final f = (w.box.x + w.box.w) / unitsPerPx;
    if (f > front) front = f;
  }
  if (front <= 0) return x;
  final rs = rigScale(dims.kind);
  final reach = jointRig(KPose.from(x, rx: 0), eff, dims).dx * rs;
  final need = (front - 6 - reach).clamp(0.0, max);
  return KPose.from(x, rx: need / rs);
}

/// Wind-up through startup, full extension on the first active frame, hold
/// through active, ease back through recovery.
List<Key> strike(MoveDef m, KPose idle, KPose wind, KPose ext,
    {KPose? hold, KPose? rec, KPose? end, double windAt = .5, double recAt = .35, KPose? w2}) {
  final s = m.startup, a = m.active, r = m.recovery, t = m.total;
  final fw = mx(1, rnd(s * windAt)).clamp(1, s > 1 ? s - 1 : 1);
  final keys = <Key>[Key(0, idle), Key(fw, wind)];
  if (w2 != null && s > 3) keys.add(Key(mx(fw + 1, s - 1), w2));
  keys.add(Key(s, ext, 1));
  keys.add(Key(s + (a > 0 ? a : 1), hold ?? ext));
  final fr = s + a + mx(1, rnd(r * recAt));
  if (rec != null && fr < t) keys.add(Key(fr, rec));
  keys.add(Key(mx(t, keys.last.f + 1), end ?? idle));
  return keys;
}

/// Thin wedge stripes across a limb from [a] to [b] at fractions [ts], alternating sides.
Path limbStripes(Offset a, Offset b, double r1, double r2, List<double> ts, {double len = .8, double base = 3.2, bool both = false}) {
  final p = Path();
  final dx = b.dx - a.dx, dy = b.dy - a.dy;
  final L = math.sqrt(dx * dx + dy * dy);
  if (L < 1e-3) return p;
  final nx = -dy / L, ny = dx / L;
  var side = 1.0;
  for (final t in ts) {
    final q = lerpO(a, b, t), r = lerpD(r1, r2, t);
    wedge(p, q.dx + nx * r * side * 1.15, q.dy + ny * r * side * 1.15, -nx * r * side * len * 1.6, -ny * r * side * len * 1.6, base);
    if (both) wedge(p, q.dx - nx * r * side * 1.15, q.dy - ny * r * side * 1.15, nx * r * side * len * 1.6, ny * r * side * len * 1.6, base);
    side = -side;
  }
  return p;
}
