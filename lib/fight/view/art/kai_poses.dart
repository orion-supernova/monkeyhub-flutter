// Key poses for the KAI rig (style lab constants plus the poses the lab did not need).
import 'dart:math' as math;

import 'kai_rig.dart';

/// World px per raw rig unit (head top of the standing rig = ~175 px; the engine
/// stand hurtbox is 170 px).
const double kRig = 0.88;

/// Lab effect units to world px (lab drew the rig at 1.18x).
const double kFx = kRig / csScale;

const double _pi = math.pi;

final KPose pIdle = KPose();
final KPose pJabX = KPose.from(pIdle, fu: 1.5, ff: 1.57, lean: .26, head: -.1, ft: .6, fs: .05, bt: -.3, bs: -.55, rx: 6);
final KPose pJabW = KPose.from(pIdle, fu: .3, ff: 2.45, lean: .1);
final KPose pCrossW = KPose.from(pIdle, bu: .1, bf: 2.5, lean: .1, baf: 1);
final KPose pCrossX = KPose.from(pIdle,
    bu: 1.5, bf: 1.57, baf: 1, lean: .3, head: -.1, fu: .25, ff: 2.6, ft: .62, fs: .05, bt: -.35, bs: -.6, rx: 6);
final KPose pHvyW = KPose.from(pIdle, bu: .05, bf: 2.95, lean: 0, rx: -3, fu: .6, ff: 2.4, baf: 1);
final KPose pHvyX = KPose.from(pIdle,
    bu: 1.55, bf: 1.6, lean: .42, rx: 12, fu: .22, ff: 2.95, bt: -.45, bs: -.62, ft: .72, fs: .18, head: -.15, baf: 1);
final KPose pKickC = KPose.from(pIdle,
    bt: 1.3, bs: -.25, lean: -.05, ft: .06, fs: .02, fu: .8, ff: 2.2, bu: .5, bf: 2.2, blf: 1, rx: 4);
final KPose pKickX = KPose.from(pIdle,
    bt: 2.3, bs: 2.12, lean: -.6, head: .15, ft: -.06, fs: 0, fu: 1.25, ff: .9, bu: -.4, bf: .2, bfa: .5, blf: 1, rx: 10);
final KPose pSrgG = KPose.from(pIdle,
    fu: -.55, ff: .45, bu: -.65, bf: .55, lean: -.1, open: 1, ft: .75, fs: -.12, bt: -.35, bs: -.75, head: .05);
final KPose pSrgX = KPose.from(pIdle,
    fu: 1.5, ff: 1.55, bu: 1.35, bf: 1.5, lean: .32, open: 1, ft: .9, fs: .25, bt: -.6, bs: -.45, baf: 1);
final KPose pCrouch = KPose.from(pIdle, lean: .45, ft: 1.0, fs: -.35, bt: .25, bs: -.95, fu: .8, ff: 2.0, bu: .6, bf: 2.2);
final KPose pTuck = KPose.from(pIdle,
    lean: .6, head: .35, ft: 2.3, fs: -.35, bt: 2.1, bs: -.45, fu: 1.9, ff: .3, bu: 1.7, bf: .25, tuck: 1, ry: 12);
final KPose pSquat = KPose.from(pIdle, lean: .3, ft: .95, fs: -.35, bt: .2, bs: -.95, fu: .2, ff: 2.2, bu: .1, bf: 2.4);
final KPose pTakeoff = KPose.from(pIdle,
    lean: .05, ft: .1, fs: .05, bt: -.1, bs: -.15, fu: 2.6, ff: 2.9, bu: 2.4, bf: 2.8, ffa: .6, bfa: .6);
final KPose pAir = KPose.from(pIdle, lean: .2, ft: 1.8, fs: .3, bt: 1.3, bs: -.2, fu: 1.2, ff: 2.4, bu: 1, bf: 2.5, ffa: .4, bfa: .4);
final KPose pDesc = KPose.from(pIdle, lean: .12, ft: .6, fs: .1, bt: .1, bs: -.3, fu: .8, ff: 2.3, bu: .6, bf: 2.5, ffa: .3, bfa: .3);
final KPose pLand = KPose.from(pSquat, lean: .4, ft: 1.1, fs: -.4);

final KPose pGuard = KPose.from(pIdle, fu: 1.15, ff: 2.95, bu: .95, bf: 3.05, baf: 1, lean: .08, head: -.02, ft: .55, fs: .05, bt: -.25, bs: -.55);
final KPose pCrouchGuard = KPose.from(pCrouch, fu: 1.15, ff: 2.95, bu: .95, bf: 3.05, baf: 1);
final KPose pCrouchPunchX = KPose.from(pCrouch, fu: 1.4, ff: 1.5, lean: .5);
final KPose pCrouchPunchW = KPose.from(pCrouch, fu: .4, ff: 2.3);

final KPose pSweepW = KPose.from(pCrouch, lean: .5, fu: 0, ff: 1.4, bu: -.3, bf: 1.0);
final KPose pSweepX = KPose.from(pIdle,
    lean: .55, head: .05, ft: 1.45, fs: 1.55, bt: 2.3, bs: .5, fu: -.5, ff: .3, bu: -.9, bf: -.2);

final KPose pJKickW = KPose.from(pAir, ft: 2.2, fs: .1, bt: .9, bs: -.5);
final KPose pJKickX = KPose.from(pAir, lean: .12, ft: 1.35, fs: 1.5, bt: 1.7, bs: .1, fu: .3, ff: 2.4, bu: -.2, bf: 2.0);
final KPose pJHeavyW = KPose.from(pAir, lean: -.05, ft: 2.5, fs: .2, bt: 1.9, bs: -.3, fu: 2.2, ff: 2.6, bu: 1.6, bf: 2.4);
final KPose pJHeavyX = KPose.from(pAir,
    lean: .38, head: -.12, ft: 1.0, fs: .85, bt: 1.5, bs: .2, fu: .5, ff: 1.5, bu: -.5, bf: .3, ffa: .1, bfa: .2);

final KPose pOverW = KPose.from(pIdle, fu: 3.0, ff: 3.1, bu: 2.5, bf: 2.9, lean: -.12, head: .02, ft: .45, fs: -.05, bt: -.4, bs: -.7);
final KPose pOverX = KPose.from(pIdle,
    fu: 1.35, ff: 1.0, bu: .8, bf: .9, baf: 1, lean: .52, head: -.15, ft: .95, fs: .05, bt: -.55, bs: -.8, rx: 8);

final KPose pGrabX = KPose.from(pIdle,
    fu: 1.45, ff: 1.5, bu: 1.35, bf: 1.5, baf: 1, lean: .3, open: 1, ft: .7, fs: .1, bt: -.4, bs: -.6, rx: 6);
final KPose pGrabW = KPose.from(pIdle, fu: .6, ff: 1.8, bu: .5, bf: 1.9, baf: 1, lean: .2, open: 1);
final KPose pToss = KPose.from(pIdle,
    fu: 2.8, ff: 3.0, bu: 2.6, bf: 2.9, baf: 1, lean: -.08, open: 1, ft: .5, fs: .05, bt: -.4, bs: -.6, rx: 4);

final KPose pKneeW = KPose.from(pCrouch, lean: .5, fu: .5, ff: 2.0);
final KPose pKneeX = KPose.from(pIdle,
    ft: 2.0, fs: .2, bt: .5, bs: -.9, lean: .3, fu: 1.0, ff: 2.3, bu: -.2, bf: 1.2, head: -.1);
final KPose pKneeLand = KPose.from(pKneeX, ft: 1.2, fs: -.2, bt: .3);

final KPose pSlideW = KPose.from(pCrouch, lean: .6);
final KPose pSlideX = KPose.from(pIdle,
    lean: -.75, head: .35, ft: 1.5, fs: 1.55, bt: 2.4, bs: 1.0, fu: -.9, ff: -.3, bu: -1.1, bf: -.6);

final KPose pHeelW = KPose.from(pCrouch, lean: -.1, fu: .3, ff: 1.2);
final KPose pHeelX = KPose.from(pIdle,
    ft: 2.8, fs: 2.9, bt: 1.6, bs: .4, lean: -.35, head: .1, fu: 1.3, ff: 2.2, bu: .5, bf: 1.6, tuck: .9, blf: 1);

final KPose pDashW = KPose.from(pIdle, lean: .4, ft: .9, fs: -.3, bt: -.6, bs: -1.0, fu: .9, ff: 1.9, bu: -.9, bf: .2);
final KPose pBackdash = KPose.from(pIdle,
    lean: -.12, head: -.02, ft: .55, fs: -.4, bt: .25, bs: -.6, fu: 1.1, ff: 2.9, bu: .9, bf: 3.0, baf: 1);

final KPose pHitX = KPose.from(pIdle,
    lean: -.34, head: -.38, fu: -.2, ff: 1.1, bu: -.6, bf: .9, ft: .25, fs: .1, bt: -.55, bs: -.95, rx: -6);
final KPose pStagger = KPose.from(pIdle, lean: -.18, head: -.2, fu: .6, ff: 1.9, bu: .2, bf: 1.6, ft: .3, fs: 0, bt: -.4, bs: -.7);
final KPose pAirHit = KPose.from(pIdle,
    lean: -.4, head: -.4, fu: -.3, ff: .6, bu: -.7, bf: .2, ft: .5, fs: -.4, bt: 1.0, bs: -.6, tuck: 1);
final KPose pLie = KPose.from(pIdle,
    lean: 0, head: .05, fu: .15, ff: .1, bu: .1, bf: .05, ft: .1, fs: -.1, bt: -.1, bs: .1, spin: -_pi / 2, tuck: 1, ry: -29);
final KPose pKoLie = KPose.from(pLie, fu: .45, ff: .35, bu: .3, bf: .2, head: .3, ft: .25, bt: -.2);
final KPose pGrabbed = KPose.from(pIdle,
    lean: -.22, head: -.3, fu: 2.4, ff: 2.9, bu: 2.1, bf: 2.7, ft: .15, fs: .3, bt: -.15, bs: .5, rx: -4);

/// Seconds of standing in the rig: used to place a rotated body above the ground.
const double standCentreHeight = 119;
