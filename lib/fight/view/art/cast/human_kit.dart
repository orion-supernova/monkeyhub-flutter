// Shared pieces for the human fighters (LUZ, DEX, HANA, BOOM): key-list
// helpers (the poser's own are private), the foot rotation rule, an arm with
// optional sleeve / tape / glove, fists and open hands, and the "live idle"
// trick: the shared idle only breathes, so a fighter that wants a rocking
// ginga or a stomping stance re-poses itself from `frame` while the pose is
// recognisably the idle.
import 'dart:math' as math;
import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../kai_rig.dart';
import '../poser.dart' show Key, jointRig, poseFor;
import '../roster_poses.dart' show rigScale;

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

/// Wind-up through startup, full extension on the first active frame, hold,
/// ease back (the poser's `_strike`).
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
  return mono(keys);
}

double boxFront(MoveDef m) {
  var r = 0.0;
  for (final w in m.windows) {
    final f = (w.box.x + w.box.w) / unitsPerPx;
    if (f > r) r = f;
  }
  return r;
}

/// [x] with its rx set so the striking joint reaches the front of the hitbox.
KPose lunged(MoveDef m, int id, KPose x, Jt eff, {double max = 46}) {
  final front = boxFront(m);
  if (front <= 0) return x;
  final base = KPose.from(x, rx: 0);
  final reach = jointRig(base, eff, dimsFor(id)).dx * rigScale(id);
  final need = (front - 6 - reach).clamp(0.0, max);
  return KPose.from(x, rx: need / rigScale(id));
}

/// Foot rotation for a leg: flat while planted, along the shin otherwise.
double footRot(Joints j, KPose p, bool back) {
  final an = back ? j.bAn : j.fAn;
  final shin = back ? p.bs : p.fs, off = back ? p.bfa : p.ffa;
  final planted = an.dy >= j.maxAn - 2.5 && p.tuck < .3 && p.ry < 1;
  return planted ? 0 : -shin + off;
}

/// True while [p] is the shared breathing idle of [idle] (so a fighter can add
/// its own live motion without touching walking, attacking or hurt poses).
bool isIdleLike(KPose p, KPose idle) =>
    (p.ft - idle.ft).abs() < .001 &&
    (p.bt - idle.bt).abs() < .001 &&
    (p.fs - idle.fs).abs() < .001 &&
    (p.bs - idle.bs).abs() < .001 &&
    (p.ry - idle.ry).abs() < .001 &&
    (p.rx - idle.rx).abs() < .001 &&
    p.spin == 0 &&
    p.tuck == 0 &&
    (p.sa - idle.sa).abs() < .001;

Path footPath() => Path()
  ..moveTo(-7, -8)
  ..cubicTo(-3, -11, 4, -10, 6, -5)
  ..cubicTo(11, -3, 17, 0, 21, 5)
  ..cubicTo(23, 8, 21, 10, 17, 10)
  ..lineTo(-6, 10)
  ..cubicTo(-10, 10, -10, 2, -7, -8)
  ..close();

/// How an arm is dressed.
class ArmStyle {
  final Color skin, tape;
  final Color? sleeve, glove;
  /// Fraction of the upper arm the sleeve covers (1 = down to the elbow).
  final double sleeveFrac;
  /// Overall thickness multiplier.
  final double girth;
  /// Scale of an open hand (BOOM's palms are huge).
  final double palm;
  final bool taped;
  const ArmStyle({
    required this.skin,
    required this.tape,
    this.sleeve,
    this.glove,
    this.sleeveFrac = 1,
    this.girth = 1,
    this.palm = 1,
    this.taped = true,
  });
}

final Path _fistP = rrPath(-2, -7, 15, 14, 5.5), _fistWrapP = rrPath(-3, -7.5, 7, 15, 2.5);

/// A fist at [wr] pointing along el->wr.
void kitFist(RigPainter r, Offset wr, Offset el, Color skin, Color? wrap, bool back, {double scale = 1}) {
  final c = r.c;
  final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
  c.save();
  c.translate(wr.dx, wr.dy);
  c.rotate(ang);
  if (scale != 1) c.scale(scale, scale);
  r.fill(_fistP, back ? dk(skin, .3) : skin, const Rect.fromLTRB(-2, -7, 13, 7), lw: 2.2);
  if (wrap != null) r.fill(_fistWrapP, back ? dk(wrap, .3) : wrap, const Rect.fromLTRB(-3, -7, 4, 7), noHT: true, lw: 2);
  r.detail((p) => p..moveTo(9, -6)..lineTo(9, 6), w: 1.1);
  c.restore();
}

/// Draws one arm: upper arm (optionally sleeved), forearm, wrist tape, hand.
/// [hand] overrides the default fist / open hand.
void kitArm(RigPainter r, Joints j, KPose p, bool back, ArmStyle s, {void Function(Offset wr, Offset el)? hand}) {
  final sh = back ? j.bSh : j.fSh, el = back ? j.bEl : j.fEl, wr = back ? j.bWr : j.fWr;
  final sk = back ? dk(s.skin, .3) : s.skin;
  final g = s.girth;
  r.limb(sh, el, 10.5 * g, 7 * g, sk, bulge: 3.4 * g);
  if (s.sleeve != null && s.sleeveFrac > 0) {
    r.limb(sh, lerpO(sh, el, s.sleeveFrac), 11.2 * g, lerpD(11.2, 7.6, s.sleeveFrac) * g, back ? dk(s.sleeve!, .3) : s.sleeve!,
        bulge: 2 * g, noHT: true, lw: 2);
  }
  r.limb(el, wr, 7.6 * g, 5.8 * g, sk, bulge: 2.2 * g);
  if (s.taped) {
    final w0 = lerpO(el, wr, .52);
    final tp = back ? dk(s.tape, .3) : s.tape;
    r.limb(w0, wr, 7.4 * g, 6.4 * g, tp, noHT: true);
    r.detail((pa) {
      final dx = wr.dx - el.dx, dy = wr.dy - el.dy;
      final L = math.sqrt(dx * dx + dy * dy);
      if (L == 0) return;
      final nx = -dy / L * 5.8 * g, ny = dx / L * 5.8 * g;
      for (var i = 1; i < 3; i++) {
        final q = lerpO(w0, wr, i / 3);
        pa.moveTo(q.dx + nx, q.dy + ny);
        pa.lineTo(q.dx - nx + dx / L * 2, q.dy - ny + dy / L * 2);
      }
    }, w: 1);
  }
  if (hand != null) {
    hand(wr, el);
  } else if (p.open > .5) {
    final c = r.c;
    if (s.palm != 1) {
      final ang = math.atan2(wr.dy - el.dy, wr.dx - el.dx);
      c.save();
      c.translate(wr.dx, wr.dy);
      c.rotate(ang);
      c.scale(s.palm, s.palm);
      r.openHand(Offset.zero, const Offset(-1, 0), back);
      c.restore();
    } else {
      r.openHand(wr, el, back);
    }
  } else {
    kitFist(r, wr, el, s.glove ?? s.skin, s.taped ? s.tape : null, back, scale: g > 1.1 ? 1.15 : 1);
  }
}

/// The neck, shared by every human.
void kitNeck(RigPainter r, Joints j, Color skin) {
  final neckTop = Offset(j.head.dx + math.sin(j.headA) * -12 - 2, j.head.dy + math.cos(j.headA) * 12);
  r.limb(j.neck, neckTop, 7.2, 6.6, dk(skin, .12));
}

/// A flowing ribbon / hair / cape-tail polyline: root at [a], hangs back and
/// down, sways with [t].
List<Offset> sway(Offset a, double len, double dirx, double diry, double t, double amp, {int n = 8}) {
  final out = <Offset>[];
  for (var i = 0; i <= n; i++) {
    final u = i / n;
    final w = math.sin(t - u * 3.2) * amp * u;
    out.add(Offset(a.dx + dirx * len * u - diry * w, a.dy + diry * len * u + dirx * w));
  }
  return out;
}

typedef PoseFn = KPose Function({
  double? rx, double? ry, double? lean, double? head, double? fu, double? ff, double? bu, double? bf,
  double? ft, double? fs, double? bt, double? bs, double? ffa, double? bfa, double? spin, double? tuck,
  double? baf, double? blf, double? open, double? sa, double? al, double? sx,
});

/// A pose builder over [base]: `q(lean: .4, fu: 1.5)`.
PoseFn poseOf(KPose base) => ({
      double? rx, double? ry, double? lean, double? head, double? fu, double? ff, double? bu, double? bf,
      double? ft, double? fs, double? bt, double? bs, double? ffa, double? bfa, double? spin, double? tuck,
      double? baf, double? blf, double? open, double? sa, double? al, double? sx,
    }) =>
        KPose.from(base,
            rx: rx, ry: ry, lean: lean, head: head, fu: fu, ff: ff, bu: bu, bf: bf, ft: ft, fs: fs, bt: bt, bs: bs,
            ffa: ffa, bfa: bfa, spin: spin, tuck: tuck, baf: baf, blf: blf, open: open, sa: sa, al: al, sx: sx);

/// Screen position of the rig-space point [o] (ground = origin) on fighter [i].
Offset screenOf(FightCamera cam, FightState s, int i, Offset o) {
  final f = s.p[i];
  final rs = rigScale(s.chars[i].id);
  return cam.toScreen(f.x / unitsPerPx + f.face * o.dx * rs, f.y / unitsPerPx - o.dy * rs);
}

/// Screen position of joint [jt] of fighter [i] right now.
Offset jointScreen(FightCamera cam, FightState s, int i, Jt jt) =>
    screenOf(cam, s, i, jointRig(poseFor(s, i), jt, dimsFor(s.chars[i].id)));
