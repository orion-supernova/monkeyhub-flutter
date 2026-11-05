// Idle stances and helpers for the roster rigs (MOJO, TANK, NYX), from the
// roster lab's MOJO_IDLE / TANK_IDLE / NYX_IDLE.
import 'dart:math' as math;

import 'art_common.dart';
import 'kai_poses.dart';
import 'kai_rig.dart';
import 'cast/registry.dart';

final KPose mojoIdle = KPose.from(pIdle,
    lean: .32, head: -.2, fu: .55, ff: 2.2, bu: .25, bf: 2.55, ft: .8, fs: -.15, bt: -.05, bs: -.8, sa: -1.8);
final KPose tankIdle = KPose.from(pIdle,
    lean: .24, head: .05, fu: .95, ff: 1.75, bu: .75, bf: 1.9, ft: .6, fs: -.08, bt: -.3, bs: -.45);
/// NYX floats: `ry` 16 above the ground, open glowing hands.
final KPose nyxIdle = KPose.from(pIdle,
    ry: 16, lean: .06, head: -.04, fu: .75, ff: 1.85, bu: .35, bf: 2.25, ft: .25, fs: .12, bt: -.12, bs: .02, open: 1);

KPose idleFor(int id) {
  switch (id) {
    case 1: return mojoIdle;
    case 2: return tankIdle;
    case 3: return nyxIdle;
    default:
      final cast = castArt[id];
      if (cast == null) return pIdle;
      return cast.floats ? KPose.from(cast.idle, ry: cast.idle.ry + cast.floatHeight) : cast.idle;
  }
}

/// World px per raw rig unit for a character (KAI: [kRig]).
double rigScale(int id) => kRig * dimsFor(id).cs / csScale;

/// The breathing idle at engine/portrait frame [frame] (the lab's curPose).
KPose rosterIdle(int id, double frame) {
  final I = idleFor(id);
  final b = math.sin(frame * .07);
  return KPose.from(I,
      lean: I.lean + b * .025, fu: I.fu + b * .05, bu: I.bu + b * .04, ff: I.ff - b * .04,
      ry: id == 3 ? I.ry + b * 4 : I.ry);
}

/// MOJO carries the staff along her front forearm when the arm is out, and
/// upright when the arm is up or at rest (matches the lab's per-move values).
double autoStaff(double ff) {
  final aim = math.pi / 2 - ff;
  final held = -1.8 - (ff - 2.2) * .75;
  return lerpD(aim, held, smooth((ff - 1.9) / .3));
}

/// A KAI-derived pose re-based onto character [id]: the staff follows the arm
/// (MOJO), and NYX keeps floating. [sa] forces the staff angle.
KPose rebase(int id, KPose k, {double? sa}) {
  switch (id) {
    case 1:
      return KPose.from(k, sa: sa ?? autoStaff(k.ff));
    case 3:
      return k.tuck < .5 && k.spin == 0 ? KPose.from(k, ry: k.ry + 16) : k;
    default:
      final cast = castArt[id];
      if (cast == null) return k;
      final r = cast.rebase(k);
      return cast.floats && r.tuck < .5 && r.spin == 0 ? KPose.from(r, ry: r.ry + cast.floatHeight) : r;
  }
}

/// Centre height of the standing character, for the rotated airborne poses.
double standCentre(int id) {
  if (id == 0) return standCentreHeight;
  final p = idleFor(id);
  final j = fk(p, dimsFor(id));
  return -(pelvisY(p, j) + j.c.dy);
}

/// The heavy-attack flourish a portrait plays when its card is "ready":
/// (wind-up, strike, guard) for character [id] (KAI: the caller's own).
(KPose, KPose, KPose) readyPoses(int id) {
  final I = idleFor(id);
  switch (id) {
    case 1:
      return (
        KPose.from(I, fu: 2.6, ff: 3.0, bu: 2.4, bf: 2.9, lean: -.05, sa: -2.4, rx: -4),
        KPose.from(I, fu: 1.0, ff: 1.3, bu: .9, bf: 1.4, lean: .55, sa: .75, rx: 14),
        KPose.from(I, fu: 1.1, ff: 2.0, bu: .9, bf: 2.4, lean: .3, sa: -1.2),
      );
    case 2:
      return (
        KPose.from(I, fu: 2.8, ff: 3.0, bu: 2.7, bf: 3.0, lean: -.12, rx: -4),
        KPose.from(I, fu: 1.3, ff: 1.0, bu: 1.2, bf: .95, lean: .6, rx: 12),
        KPose.from(I, fu: 1.25, ff: 2.3, bu: 1.15, bf: 2.4, baf: 1, lean: .2),
      );
    case 3:
      return (
        KPose.from(I, fu: -.2, ff: .6, lean: -.12, rx: -4, bu: 1.0, bf: 1.6),
        KPose.from(I, fu: 1.6, ff: 1.5, bu: 1.2, bf: 1.0, lean: .32, rx: 16),
        KPose.from(I, fu: 1.2, ff: 2.95, bu: 1.1, bf: 2.55, baf: 1, lean: -.06, open: 0),
      );
    default:
      final custom = castArt[id]?.readyPoses();
      if (custom != null) return custom;
      return (
        KPose.from(I, bu: .05, bf: 2.95, lean: 0, rx: -3, fu: .6, ff: 2.4, baf: 1),
        KPose.from(I, bu: 1.55, bf: 1.6, lean: .42, rx: 12, fu: .22, ff: 2.95, baf: 1),
        KPose.from(I, fu: 1.15, ff: 2.95, bu: .95, bf: 3.05, baf: 1, lean: .08),
      );
  }
}
