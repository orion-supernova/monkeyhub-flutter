// Shared drawing + animation helpers for the MONKEY family (BRUNO, SAGE, RAZZ,
// PIP). The painters here follow roster_rig.dart's recipe (shaped Paths per
// part, drawn through RigPainter.fill / limb / detail so cartoon, painted and
// pixel all work); the animation helpers are the poser's private `_strike`,
// `_lunge` and `_mono` re-expressed on the public Key / MoveAnim / jointRig.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, jointRig;
import '../roster_poses.dart' show rigScale;
import '../roster_rig.dart' show bbOf, tubePath;

export '../poser.dart' show Key, MoveAnim;
export '../roster_rig.dart' show bez, bbOf, ellP, pathOf, tubePath;

// ------------------------------------------------------------------ painting

/// Plain drawing on top of a [RigPainter] (flat fills, dots, ink strokes),
/// one per RigPainter.
class Ink {
  Ink(this.r);
  final RigPainter r;
  static final Expando<Ink> _by = Expando<Ink>('monkeyInk');
  static Ink of(RigPainter r) => _by[r] ??= Ink(r);

  final Paint _f = Paint()..isAntiAlias = true;
  final Paint _s = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Canvas get c => r.c;
  bool get cel => r.cel;
  bool get paint => r.paint;
  bool get pix => r.pix;
  bool get sil => r.sil != null;

  /// A flat colour fill (never in silhouettes).
  void flat(Path p, Color col) {
    if (sil) return;
    c.drawPath(p, _f..shader = null..color = col);
  }

  void dot(double x, double y, double rad, Color col) {
    if (sil) return;
    c.drawCircle(Offset(x, y), rad, _f..shader = null..color = col);
  }

  /// Cartoon ink around [p].
  void ink(Path p, double w, [Color col = kInk]) {
    if (!cel || sil) return;
    c.drawPath(p, _s..shader = null..strokeWidth = w..color = col);
  }

  /// A stroked line / path in any look.
  void stroke(Path p, double w, Color col) {
    if (sil) return;
    c.drawPath(p, _s..shader = null..strokeWidth = w..color = col);
  }

  void line(Offset a, Offset b, double w, Color col) {
    if (sil) return;
    c.drawLine(a, b, _s..shader = null..strokeWidth = w..color = col);
  }

  /// A filled tapered tube along [pts].
  void tube(List<Offset> pts, double w0, double w1, Color col,
      {Color? shade, double lw = 2, bool noHT = true}) {
    r.fill(tubePath(pts, w0, w1), col, bbOf(pts, math.max(w0, w1) + 2), shade: shade, lw: lw, noHT: noHT);
  }

  /// A closed-fist hand at [wr], pointing along el->wr. [w]/[h] are the fist
  /// size, [col] the fur / skin, [knuckle] the finger side.
  void fist(Offset wr, Offset el, Color col, {double w = 14, double h = 13, Color? knuckle, bool back = false}) {
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    final kc = knuckle ?? col;
    r.fill(rrPath(-2, -h / 2, w, h, h * .42), back ? dk(kc, .3) : kc, Rect.fromLTRB(-2, -h / 2, w - 2, h / 2), lw: 2);
    r.fill(rrPath(-3, -h / 2, w * .42, h, h * .2), back ? dk(col, .3) : col, Rect.fromLTRB(-3, -h / 2, w * .4, h / 2),
        lw: 1.8, noHT: true);
    final x1 = w * .55, x2 = w * .8;
    r.detail((pa) => pa
      ..moveTo(x1, -h / 2 + 1)
      ..lineTo(x1, h / 2 - 1)
      ..moveTo(x2, -h / 2 + 1.5)
      ..lineTo(x2, -h / 6), w: 1);
    c.restore();
  }

  /// An open hand (long fingers) at [wr], pointing along el->wr.
  void openHand(Offset wr, Offset el, Color col, {double s = 1, bool back = false, double spread = 1}) {
    final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
    final hc = back ? dk(col, .3) : col;
    c.save();
    c.translate(wr.dx, wr.dy);
    c.rotate(ang);
    c.scale(s, s);
    for (var i = 0; i < 4; i++) {
      final yy = (i - 1.5) * 3.2 * spread;
      r.limb(Offset(3, yy * .5), Offset(13 + (i == 1 || i == 2 ? 2 : 0), yy * 1.4 - 1.4), 2.3, 1.7, hc,
          lw: 1.4, noHT: true);
    }
    r.limb(const Offset(1, 3.5), Offset(8, 8.5 * spread), 2.5, 1.9, hc, lw: 1.4, noHT: true);
    r.fill(rrPath(-1, -6, 10, 12, 4.5), hc, const Rect.fromLTRB(-1, -6, 9, 6), lw: 1.7, noHT: true);
    c.restore();
  }
}

// ------------------------------------------------------------------ animation

/// KPose builder anchored at a character's idle, with every channel optional.
typedef PoseQ = KPose Function({
  double? rx, double? ry, double? lean, double? head, double? fu, double? ff, double? bu, double? bf,
  double? ft, double? fs, double? bt, double? bs, double? ffa, double? bfa, double? spin, double? tuck,
  double? baf, double? blf, double? open, double? sa, double? al, double? sx,
});

PoseQ posing(KPose I) => ({
      double? rx, double? ry, double? lean, double? head, double? fu, double? ff, double? bu, double? bf,
      double? ft, double? fs, double? bt, double? bs, double? ffa, double? bfa, double? spin, double? tuck,
      double? baf, double? blf, double? open, double? sa, double? al, double? sx,
    }) =>
        KPose.from(I,
            rx: rx, ry: ry, lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, ft: ft, fs: fs, bt: bt, bs: bs,
            ffa: ffa, bfa: bfa, spin: spin, tuck: tuck, baf: baf, blf: blf, open: open, sa: sa, al: al, sx: sx);

int mx(int a, int b) => a > b ? a : b;
int rd(num v) => v.round();

double _boxFront(MoveDef m) {
  var r = 0.0;
  for (final w in m.windows) {
    final f = (w.box.x + w.box.w) / unitsPerPx;
    if (f > r) r = f;
  }
  return r;
}

/// [x] with its rx set so the striking joint [eff] reaches the front of the hitbox.
KPose lunge(int id, MoveDef m, KPose x, Jt eff, {double max = 46}) {
  final front = _boxFront(m);
  if (front <= 0) return x;
  final base = KPose.from(x, rx: 0);
  final sc = rigScale(id);
  final reach = jointRig(base, eff, dimsFor(id)).dx * sc;
  final need = (front - 6 - reach).clamp(0.0, max);
  return KPose.from(x, rx: need / sc);
}

/// Strictly increasing frames, so a short move never folds its key list back.
List<Key> mono(List<Key> ks) {
  final out = <Key>[];
  for (final k in ks) {
    final f = out.isEmpty ? k.f : (k.f > out.last.f ? k.f : out.last.f + 1);
    out.add(Key(f, k.p, k.ease));
  }
  return out;
}

/// Wind-up through startup, full extension on the first active frame, hold
/// through active, ease back through recovery.
List<Key> strike(MoveDef m, KPose wind, KPose ext, KPose idle,
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
  return keys;
}

/// Pose keys for a multi-hit move: [poses] cycle on each hit window start.
/// [pre] is the wind-up, [post] the pose the move settles into before [idle].
List<Key> multiHit(MoveDef m, KPose idle, KPose pre, List<KPose> poses, KPose post,
    {int preAt = -1, KPose? mid}) {
  final ws = m.windows;
  final s = m.startup, r = m.recovery, t = m.total;
  final keys = <Key>[Key(0, idle), Key(preAt > 0 ? preAt : mx(1, s ~/ 2), pre)];
  for (var k = 0; k < ws.length; k++) {
    keys.add(Key(ws[k].start, poses[k % poses.length], 1));
    if (mid != null && k < ws.length - 1) {
      final gap = ws[k + 1].start - ws[k].start;
      keys.add(Key(ws[k].start + mx(1, gap ~/ 2), KPose.lerp(poses[k % poses.length], mid, .5)));
    }
  }
  final tail = ws.isEmpty ? s + m.active : ws.last.end;
  keys.add(Key(tail + rd(r * .3), post));
  keys.add(Key(t, idle));
  return mono(keys);
}

// ------------------------------------------------------------------ geometry

Offset pt(double x, double y) => Offset(x, y);

/// A flat-bottomed wavy fur fringe along [a]->[b] hanging [len] below.
Path fringe(Offset a, Offset b, double len, int teeth, [double phase = 0]) {
  final p = Path()..moveTo(a.dx, a.dy);
  p.lineTo(b.dx, b.dy);
  for (var i = teeth; i >= 0; i--) {
    final t = i / teeth;
    final x = lerpD(a.dx, b.dx, t), y = lerpD(a.dy, b.dy, t);
    final tip = i.isEven ? len : len * .55;
    p.lineTo(x + math.sin(phase + i) * 1.2, y + tip);
  }
  p.close();
  return p;
}

/// 4-point sparkle star.
Path sparkle(double x, double y, double r) => Path()
  ..moveTo(x, y - r)
  ..quadraticBezierTo(x, y, x + r, y)
  ..quadraticBezierTo(x, y, x, y + r)
  ..quadraticBezierTo(x, y, x - r, y)
  ..quadraticBezierTo(x, y, x, y - r)
  ..close();
