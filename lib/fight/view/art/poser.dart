// Maps engine state (Fighter.state + sf + move data) to a KAI rig pose.
// Key frames are timed from the MoveDef: wind-up through startup, full
// extension on the first active frame, hold through active, ease back through
// recovery.
import 'dart:math' as math;
import 'dart:ui';

import '../../core/core.dart';
import 'art_common.dart';
import 'kai_poses.dart';
import 'kai_rig.dart';

const double _tau = math.pi * 2;

class Key {
  final int f;
  final KPose p;
  final int ease; // 0 smooth, 1 out, 2 linear
  const Key(this.f, this.p, [this.ease = 0]);
}

KPose evalKeys(List<Key> ks, double t) {
  if (t <= ks.first.f) return ks.first.p;
  if (t >= ks.last.f) return ks.last.p;
  var i = 0;
  while (i < ks.length - 2 && t >= ks[i + 1].f) {
    i++;
  }
  final a = ks[i], b = ks[i + 1];
  var u = b.f == a.f ? 1.0 : clamp01((t - a.f) / (b.f - a.f));
  u = b.ease == 1 ? easeOut(u) : (b.ease == 2 ? u : smooth(u));
  return KPose.lerp(a.p, b.p, u);
}

/// Rig-space position (ground contact = origin, y up negative) of a joint.
Offset jointRig(KPose p, Jt jt) {
  final j = fk(p);
  final o = spinPoint(p, j, j.at(jt));
  return Offset(p.rx + o.dx, pelvisY(p, j) + o.dy);
}

/// Animation recipe for one MoveDef.
class MoveAnim {
  final List<Key> keys;
  final Jt? smear; // joint that leaves the swoosh
  final int smearA, smearB;
  final bool storm;
  const MoveAnim(this.keys, {this.smear, this.smearA = 0, this.smearB = 0, this.storm = false});
}

final Map<MoveDef, MoveAnim> _cache = {};

double _boxFront(MoveDef m) {
  var r = 0.0;
  for (final w in m.windows) {
    final f = (w.box.x + w.box.w) / unitsPerPx;
    if (f > r) r = f;
  }
  return r;
}

/// [x] with its rx set so the striking joint reaches the front of the hitbox.
KPose _lunge(MoveDef m, KPose x, Jt eff, {double max = 46}) {
  final front = _boxFront(m);
  if (front <= 0) return x;
  final base = KPose.from(x, rx: 0);
  final reach = jointRig(base, eff).dx * kRig;
  final need = (front - 6 - reach).clamp(0.0, max);
  return KPose.from(x, rx: need / kRig);
}

int _mx(int a, int b) => a > b ? a : b;
int _r(num v) => v.round();

List<Key> _strike(MoveDef m, KPose wind, KPose ext, {KPose? hold, KPose? rec, KPose? end, double windAt = .5, double recAt = .35, KPose? w2}) {
  final s = m.startup, a = m.active, r = m.recovery, t = m.total;
  final fw = _mx(1, _r(s * windAt)).clamp(1, s > 1 ? s - 1 : 1);
  final keys = <Key>[Key(0, pIdle), Key(fw, wind)];
  if (w2 != null && s > 3) keys.add(Key(_mx(fw + 1, s - 1), w2));
  keys.add(Key(s, ext, 1));
  keys.add(Key(s + (a > 0 ? a : 1), hold ?? ext));
  final fr = s + a + _mx(1, _r(r * recAt));
  if (rec != null && fr < t) keys.add(Key(fr, rec));
  keys.add(Key(_mx(t, keys.last.f + 1), end ?? pIdle));
  return keys;
}

MoveAnim _build(MoveDef m, CharacterDef def) {
  final s = m.startup, a = m.active, r = m.recovery, t = m.total;
  switch (m.name) {
    case 'standLight':
      final x = _lunge(m, pJabX, Jt.fHa);
      return MoveAnim(_strike(m, pJabW, x, hold: KPose.from(x, fu: 1.45, ff: 1.6)), smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
    case 'standLight2':
      final x = _lunge(m, pCrossX, Jt.bHa);
      return MoveAnim(_strike(m, pCrossW, x, hold: KPose.from(x, bu: 1.45, bf: 1.6)), smear: Jt.bHa, smearA: s - 2, smearB: s + a + 1);
    case 'standHeavy':
      final x = _lunge(m, pHvyX, Jt.bHa);
      return MoveAnim(_strike(m, pHvyW, x, hold: KPose.from(x, bu: 1.5), windAt: .45), smear: Jt.bHa, smearA: s - 3, smearB: s + a + 2);
    case 'standFinisher':
      final x = _lunge(m, pKickX, Jt.bAn);
      return MoveAnim(_strike(m, pKickC, x, hold: KPose.from(x, bt: 2.25, bs: 2.05), rec: KPose.from(pKickC, rx: 6), recAt: .4, windAt: .55),
          smear: Jt.bAn, smearA: s - 4, smearB: s + a + 2);
    case 'crouchLight':
      final x = _lunge(m, pCrouchPunchX, Jt.fHa);
      return MoveAnim(_strike(m, pCrouchPunchW, x, end: pCrouch), smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
    case 'crouchHeavy':
      final x = _lunge(m, pSweepX, Jt.fAn, max: 30);
      return MoveAnim(_strike(m, pSweepW, x, rec: pCrouch, windAt: .6, recAt: .5), smear: Jt.fAn, smearA: s - 3, smearB: s + a + 2);
    case 'jumpLight':
      final x = _lunge(m, pJKickX, Jt.fAn, max: 24);
      return MoveAnim(_strike(m, pJKickW, x, end: pDesc), smear: Jt.fAn, smearA: s - 2, smearB: s + a);
    case 'jumpHeavy':
      final x = _lunge(m, pJHeavyX, Jt.fAn, max: 24);
      return MoveAnim(_strike(m, pJHeavyW, x, end: pDesc, windAt: .6), smear: Jt.fAn, smearA: s - 3, smearB: s + a);
    case 'fwdHeavy':
      final x = _lunge(m, pOverX, Jt.fHa);
      return MoveAnim(_strike(m, pOverW, x, windAt: .8, w2: KPose.from(pOverW, lean: -.2, fu: 3.1, ff: 3.2), recAt: .4),
          smear: Jt.fHa, smearA: s - 3, smearB: s + a + 2);
    case 'throw':
      final x = _lunge(m, pGrabX, Jt.fHa, max: 20);
      final tossAt = s + a + 8;
      return MoveAnim([
        Key(0, pIdle),
        Key(_mx(1, s - 2), pGrabW),
        Key(s, x, 1),
        Key(s + a + 6, x),
        Key(tossAt, pToss, 1),
        Key(tossAt + 8, pToss),
        Key(_mx(t, tossAt + 9), pIdle),
      ]);
    case 'surgePalm':
      final sp = m.projectiles.isNotEmpty ? m.projectiles.first.frame : s - 1;
      final x = _lunge(m, pSrgX, Jt.fHa, max: 18);
      return MoveAnim([
        Key(0, pIdle),
        Key(_mx(1, _r(sp * .25)), KPose.from(pCrouch, ry: 6)),
        Key(_mx(2, _r(sp * .55)), pSrgG),
        Key(_mx(3, sp - 2), KPose.from(pSrgG, fu: -.6, bu: -.7)),
        Key(sp, x, 1),
        Key(sp + _r((t - sp) * .45), KPose.from(x, lean: .3)),
        Key(_mx(t, sp + 4), pIdle),
      ]);
    case 'cometKnee':
      final lift = m.steps.where((e) => e.vy != null).map((e) => e.frame).fold<int>(s - 4, (p, e) => e);
      final x = pKneeX;
      return MoveAnim([
        Key(0, pIdle),
        Key(_mx(1, lift - 2), pKneeW),
        Key(_mx(2, lift + 1), KPose.from(pKneeW, lean: .35, ft: 1.4, fs: -.1), 1),
        Key(s, x, 1),
        Key(s + a, x),
        Key(_mx(t, s + a + 1), pKneeLand),
      ], smear: Jt.fKn, smearA: s - 3, smearB: s + a);
    case 'slideStep':
      return MoveAnim([
        Key(0, pIdle),
        Key(_mx(1, _r(s * .5)), pSlideW),
        Key(s, pSlideX, 1),
        Key(s + a, pSlideX),
        Key(s + a + _r(r * .55), KPose.from(pSlideW, lean: .3)),
        Key(_mx(t, s + a + _r(r * .55) + 1), pIdle),
      ], smear: Jt.fAn, smearA: s - 2, smearB: s + a);
    case 'risingHeel':
      final x = pHeelX;
      return MoveAnim([
        Key(0, pIdle),
        Key(_mx(1, s - 2), pHeelW),
        Key(s, KPose.from(x, spin: -.2), 1),
        Key(s + _r(a * .5), KPose.from(x, spin: -math.pi), 2),
        Key(s + a, KPose.from(x, spin: -_tau + .3, tuck: .7, ft: 1.3, fs: .6), 2),
        Key(_mx(t, s + a + 1), KPose.from(pDesc, spin: -_tau)),
      ], smear: Jt.fAn, smearA: s - 1, smearB: s + a);
    case 'hundredStorm':
      return MoveAnim([Key(0, pIdle), Key(t, pIdle)], storm: true);
  }
  return _generic(m);
}

MoveAnim _generic(MoveDef m) {
  final s = m.startup, a = m.active;
  if (m.cls != MoveClass.normal && m.projectiles.isNotEmpty) {
    final sp = m.projectiles.first.frame;
    final x = _lunge(m, pSrgX, Jt.fHa, max: 18);
    return MoveAnim([
      Key(0, pIdle),
      Key(_mx(1, _r(sp * .5)), pSrgG),
      Key(sp, x, 1),
      Key(sp + _r((m.total - sp) * .45), x),
      Key(_mx(m.total, sp + 2), pIdle),
    ]);
  }
  var lowest = 99999.0, any = false;
  for (final w in m.windows) {
    any = true;
    final mid = (w.box.y + w.box.h / 2);
    if (mid < lowest) lowest = mid.toDouble();
  }
  if (any && lowest < 5000) {
    final x = _lunge(m, pSweepX, Jt.fAn, max: 30);
    return MoveAnim(_strike(m, pSweepW, x, rec: pCrouch, windAt: .6), smear: Jt.fAn, smearA: s - 3, smearB: s + a + 2);
  }
  if (m.airborne) {
    final x = _lunge(m, pJKickX, Jt.fAn, max: 24);
    return MoveAnim(_strike(m, pJKickW, x, end: pDesc), smear: Jt.fAn, smearA: s - 2, smearB: s + a);
  }
  if (m.damage >= 55 || m.cls != MoveClass.normal) {
    final x = _lunge(m, pHvyX, Jt.bHa);
    return MoveAnim(_strike(m, pHvyW, x, hold: KPose.from(x, bu: 1.5)), smear: Jt.bHa, smearA: s - 3, smearB: s + a + 2);
  }
  final x = _lunge(m, pJabX, Jt.fHa);
  return MoveAnim(_strike(m, pJabW, x), smear: Jt.fHa, smearA: s - 2, smearB: s + a + 1);
}

MoveAnim animFor(MoveDef m, CharacterDef def) => _cache.putIfAbsent(m, () => _build(m, def));

/// Rapid-fire alternating punches with a heavy final blow.
KPose _stormPose(MoveDef m, int sf) {
  final s = m.startup, t = m.total;
  final ws = m.windows;
  if (sf < s) {
    final u = clamp01(sf / math.max(1, s));
    return KPose.lerp(pIdle, KPose.from(pDashW, lean: .5), smooth(u));
  }
  var k = 0;
  for (var i = 0; i < ws.length; i++) {
    if (ws[i].start <= sf) k = i;
  }
  final lastEnd = ws.isEmpty ? s : ws.last.end;
  if (sf >= lastEnd) {
    final u = clamp01((sf - lastEnd) / math.max(1, t - lastEnd));
    return KPose.lerp(_lungedHvy(m), pIdle, smooth(u));
  }
  if (k == ws.length - 1) return _lungedHvy(m);
  final gap = ws.length > 1 ? ws[1].start - ws[0].start : 3;
  final sub = clamp01((sf - ws[k].start) / math.max(1, gap));
  final front = k.isEven;
  final ext = 1 - sub * .75; // this arm retracts
  final other = sub * .45; // the other arm loads up
  final fw = front ? ext : other, bw = front ? other : ext;
  return KPose.from(pJabX,
      fu: lerpD(.45, 1.5, fw), ff: lerpD(2.65, 1.57, fw),
      bu: lerpD(.3, 1.5, bw), bf: lerpD(2.8, 1.57, bw),
      baf: bw > .3 ? 1 : 0, lean: .3 + (front ? 0 : .06), head: -.08,
      ft: .75, fs: .1, bt: -.5, bs: -.7, rx: 10 + (front ? 0 : 6));
}

KPose _lungedHvy(MoveDef m) => KPose.from(pHvyX, rx: 18);

// ------------------------------------------------------------------ public

/// Pose for [player] at the state's current frame.
KPose poseFor(FightState s, int player) => poseAtSf(s, player, s.p[player].sf);

KPose poseAtSf(FightState s, int player, int sf) {
  final f = s.p[player];
  final def = s.chars[player];
  final breathe = math.sin(s.frame * .07);
  switch (f.state) {
    case St.idle:
      return KPose.from(pIdle,
          lean: pIdle.lean + breathe * .025, fu: pIdle.fu + breathe * .05, bu: pIdle.bu + breathe * .04, ff: pIdle.ff - breathe * .04);
    case St.walk:
      final ph = (f.x / unitsPerPx) * f.face * .095;
      final w = math.sin(ph);
      return KPose.from(pIdle,
          ft: .5 + w * .32, bt: -.18 - w * .32, fs: .02 + math.max(0, -w) * .3, bs: -.5 + math.max(0, w) * .3,
          fu: .45 - w * .12, bu: .3 + w * .12);
    case St.crouch:
      return KPose.from(pCrouch, lean: pCrouch.lean + breathe * .02, fu: pCrouch.fu + breathe * .04);
    case St.prejump:
      return KPose.lerp(pIdle, pSquat, smooth((sf + 1) / math.max(1, def.prejump)));
    case St.jump:
      final v = def.jumpVy == 0 ? 0.0 : f.vy / def.jumpVy;
      final w = clamp01((1 - v) / 2);
      return evalKeys(_jumpKeys, w * 100);
    case St.landing:
      final u = clamp01(sf / math.max(1, f.landLag));
      return KPose.lerp(pLand, pIdle, smooth(u));
    case St.dash:
      final w = math.sin(sf * .85);
      final u = easeOut(sf / 4);
      return KPose.lerp(pIdle, KPose.from(pDashW,
          ft: .45 + .8 * w, bt: .45 - .8 * w, fs: -.2 - .9 * math.max(0, -w), bs: -.2 - .9 * math.max(0, w),
          fu: .9 + .5 * w, bu: .9 - .5 * w, ff: 1.9, bf: 1.9), u);
    case St.backdash:
      final u = easeOut(sf / 4);
      return KPose.lerp(pIdle, pBackdash, u);
    case St.roll:
      return _rollPose(f, sf);
    case St.move:
      if (f.moveId < 0 || f.moveId >= def.moves.length) return pIdle;
      final m = def.moves[f.moveId];
      final anim = animFor(m, def);
      if (anim.storm) return _stormPose(m, sf);
      return evalKeys(anim.keys, sf.toDouble());
    case St.hitstun:
      final u = clamp01(f.stun / 10) * (.7 + .3 * clamp01(f.stun / 20));
      final jit = f.stop > 0 ? (s.frame.isEven ? 1.6 : -1.6) : 0.0;
      return KPose.from(KPose.lerp(pIdle, pHitX, smooth(u)), rx: pHitX.rx * u + jit);
    case St.blockstun:
      final base = f.crouchBlock ? pCrouchGuard : pGuard;
      final jit = f.stop > 0 ? (s.frame.isEven ? 1.2 : -1.2) : -2.5 * clamp01(f.stun / 8);
      return KPose.from(base, rx: jit);
    case St.techd:
      return KPose.lerp(pIdle, pStagger, smooth(clamp01(f.stun / 8)));
    case St.airstun:
      return _airPose(s, f);
    case St.down:
      return pLie;
    case St.ko:
      return pKoLie;
    case St.getup:
      final u = clamp01(sf / (f.quickRise ? 8 : 14));
      return evalKeysU(u);
    case St.grabbed:
      return KPose.from(pGrabbed, rx: pGrabbed.rx + math.sin(s.frame * .5) * 1.2);
  }
  return pIdle;
}

KPose evalKeysU(double u) {
  if (u < .45) return KPose.lerp(pLie, KPose.from(pCrouch, lean: .6), smooth(u / .45));
  return KPose.lerp(KPose.from(pCrouch, lean: .6), pIdle, smooth((u - .45) / .55));
}

final List<Key> _jumpKeys = [
  Key(0, pTakeoff),
  Key(28, pAir, 1),
  Key(52, pAir),
  Key(78, pDesc),
  Key(100, KPose.from(pDesc, ft: .3, fs: .05, bt: .0, bs: -.1)),
];

KPose _rollPose(Fighter f, int sf) {
  final fwd = f.jumpDir == f.face;
  final sg = fwd ? 1.0 : -1.0;
  // Engine roll is 34 frames: crouch, tuck + spin, recover.
  final spinEnd = KPose.from(pTuck, spin: sg * _tau);
  return evalKeys([
    Key(0, pIdle),
    Key(3, pCrouch),
    Key(5, pTuck),
    Key(18, spinEnd, 2),
    Key(23, KPose.from(pCrouch, spin: sg * _tau)),
    Key(34, KPose.from(pIdle, spin: sg * _tau)),
  ], sf.toDouble());
}

KPose _airPose(FightState s, Fighter f) {
  final vy = f.vy.toDouble();
  final a = (.5 - vy / 2400).clamp(.12, 1.0);
  final spin = -a * math.pi / 2;
  final cH = 13 + (standCentreHeight - 13) * math.pow(math.cos(spin), 2);
  final fl = s.frame * .35;
  return KPose.from(pAirHit,
      spin: spin, ry: cH - 42,
      fu: -.3 + math.sin(fl) * .5, ff: .6 + math.sin(fl + 1) * .6, bu: -.7 + math.cos(fl) * .5, bf: .2 + math.cos(fl + 2) * .6,
      ft: .5 + math.sin(fl + 2) * .3, bt: 1.0 + math.cos(fl) * .3);
}
