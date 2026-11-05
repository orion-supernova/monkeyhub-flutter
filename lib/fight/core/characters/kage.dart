// KAGE - legend (he), ghost samurai. Counters and phasing. 900 health, floaty.
//
// Movement: walk 3.2/2.8 px/f, dash 9.5 px/f x14f, backdash 8.5 px/f x16f, jump 18.5 (floaty, gravity 75).
// Normals: damage 95%, reach 115% (katana).
//
// | move            | input | st | act | rec | dmg | hit/blk stun | height | notes                                          |
// |-----------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------------|
// | iaido           |  S    |  5 |  -  |  24 | 130 | counter 3-24 | -      | sheathed stance; if struck: draws instantly,   |
// |                 |       |    |     |     |     |              |        | 16 px/f cut (iaidoStrike, KD). Whiff = recovery|
// | dashSlash       | >S    |  8 |  6  |  22 |  85 | KD / 14      | mid    | dash-through cut, ends on the FAR side         |
// | shadowSlip      | vS    | 14 |  4  |  20 |  60 | KD / 12      | LOW    | phase: strike+projectile-invuln 2-14, drifts   |
// |                 |       |    |     |     |     |              |        | forward into a low cut                         |
// | risingSlash     | ^S    |  6 |  8  |  24 | 55+60 | KD+launch/18 | mid  | 2-hit anti-air, strike-invuln 0-9              |
// | yuureiRyu       | super | 16 | 24  |  22 | 8x38+110 | KD      | mid    | vanish (invuln 0-14), reappear behind, flurry  |
// EX (heavy held, 1 bar): iaido longer window + 170 dmg, dashSlash strike-invuln, slip faster/harder,
// risingSlash longer invuln.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const int _iaidoStrike = 19;
const int _iaidoStrikeEx = 20;

MoveDef _iaido(bool ex) => MoveDef('iaido', cls: MoveClass.special, startup: 5, active: 0, recovery: ex ? 28 : 24,
    counterStart: 3, counterEnd: ex ? 28 : 24, counterMove: ex ? _iaidoStrikeEx : _iaidoStrike);

MoveDef _iaidoFollow(bool ex) => MoveDef('iaidoStrike', cls: MoveClass.special, startup: 3, active: 4, recovery: 22,
    box: const Box(1000, 6000, 15000, 5000), damage: ex ? 170 : 130, blockstun: 16, hitstop: 12, pushback: 800,
    knockdown: true, launch: 650, juggleCost: 2, meterGain: 40, steps: const [MoveStep(0, vx: 1600), MoveStep(7, vx: 0)],
    invuln: const [Invuln(0, 6, Inv.strike | Inv.projectile)]);

MoveDef _dashSlash(bool ex) => MoveDef('dashSlash', cls: MoveClass.special, startup: ex ? 6 : 8, active: 6, recovery: 22,
    box: const Box(0, 4000, 12000, 9000), damage: ex ? 105 : 85, chip: 10, blockstun: 14, hitstop: 10, pushback: 300,
    knockdown: true, meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [MoveStep(ex ? 3 : 4, vx: 1900), MoveStep(ex ? 14 : 16, vx: 0, teleport: 1, tpOffset: 6000, faceOpponent: true)],
    invuln: ex ? const [Invuln(0, 12, Inv.strike | Inv.projectile)] : const []);

MoveDef _shadowSlip(bool ex) => MoveDef('shadowSlip', cls: MoveClass.special, startup: ex ? 11 : 14, active: 4, recovery: 20,
    box: const Box(1000, 0, 12000, 3500), damage: ex ? 80 : 60, chip: 8, blockstun: 12, hitstop: 9, pushback: 400,
    height: BlockHeight.low, knockdown: true, pose: Pose.crouch, hurt: const [Box(-4000, 0, 8000, 9000)], meterGain: 60,
    steps: [MoveStep(2, vx: ex ? 1300 : 1100), MoveStep(ex ? 10 : 12, vx: 0)],
    invuln: [Invuln(2, ex ? 11 : 14, Inv.strike | Inv.projectile)]);

MoveDef _risingSlash(bool ex) => MoveDef('risingSlash', cls: MoveClass.special, startup: 6, active: 8, recovery: 24,
    windows: rapidWindows(start: 6, hits: 2, gap: 4, box: const Box(0, 6000, 10000, 17000), damage: ex ? 60 : 55,
        finisherDamage: ex ? 70 : 60, stop: 3),
    chip: 8, hitstun: 18, blockstun: 18, hitstop: 10, pushback: 300, knockdown: true, launch: ex ? 950 : 800, juggleCost: 3,
    meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false, steps: const [MoveStep(3, vx: 100, vy: 1000)],
    invuln: [Invuln(0, ex ? 14 : 9, Inv.strike)], airborne: true, landRecovery: 12);

MoveDef _yuureiRyu() => MoveDef('yuureiRyu', cls: MoveClass.superMove, startup: 16, active: 24, recovery: 22,
    windows: rapidWindows(start: 16, hits: 8, gap: 3, box: const Box(0, 2000, 13000, 12000), damage: 38, finisherDamage: 110),
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 400, knockdown: true, launch: 800, juggleCost: 0, scaleFloor: 40,
    steps: const [MoveStep(14, vx: 0, teleport: 1, tpOffset: 5000, faceOpponent: true)],
    invuln: const [Invuln(0, 16, Inv.all)]);

CharacterDef buildKage() => CharacterDef(
      id: 17, key: 'kage', name: 'KAGE', kind: 'fantasy', maxHealth: 900,
      walkFwd: 320, walkBack: 280, dashSpeed: 950, dashFrames: 14, backdashSpeed: 850, backdashFrames: 16,
      jumpVy: 1850, jumpVx: 420, gravity: 75, pushHalf: 3000,
      standHurt: const [Box(-3000, 0, 6000, 16500)], crouchHurt: const [Box(-3000, 0, 6000, 9500)],
      airHurt: const [Box(-3000, 1500, 6000, 13500)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 95, reachPct: 115)),
        _iaido(false), // 10
        _dashSlash(false), // 11
        _shadowSlip(false), // 12
        _risingSlash(false), // 13
        _yuureiRyu(), // 14
        _iaido(true), // 15
        _dashSlash(true), // 16
        _shadowSlip(true), // 17
        _risingSlash(true), // 18
        _iaidoFollow(false), // 19
        _iaidoFollow(true), // 20
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
