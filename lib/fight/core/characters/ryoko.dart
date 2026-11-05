// RYOKO - tiger, claw rushdown. 1050 health, quick, pounces in.
//
// Movement: walk 3.3/2.7 px/f, dash 10 px/f x15f, backdash 8.5 px/f x17f, jump 18.5.
// Normals: damage 102%, reach 100%.
//
// | move        | input | st | act | rec | dmg | hit/blk stun | height | notes                                              |
// |-------------|-------|----|-----|-----|-----|--------------|--------|----------------------------------------------------|
// | clawFlurry  |  S    |  7 | 15  |  24 | 4x17+40 | KD / 10  | mid    | rapid 5-hit claw, creeps forward                   |
// | pounce      | >S    | 14 | 10  |  14 |  90 | KD / 16      | mid    | leaping special (13 px/f), 12f landing, chip 12    |
// | lowRake     |  vS   |  9 |  4  |  20 |  60 | KD / 12      | LOW    | crouching rake, low profile, projectile-invuln 3-12|
// | risingClaw  |  ^S   |  5 |  7  |  24 |  90 | KD+launch/16 | mid    | strike-invuln 0-7, anti-air                        |
// | tigerRage   | super | 10 | 27  |  24 | 8x34+130 | KD      | mid    | lunge + shredding flurry, invuln 0-10, 2 bars      |
// EX: clawFlurry 7 hits, pounce faster + wall bounce, lowRake faster, risingClaw longer invuln + launch.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

MoveDef _clawFlurry(bool ex) => MoveDef('clawFlurry', cls: MoveClass.special, startup: 7, active: ex ? 21 : 15, recovery: 24,
    windows: rapidWindows(start: 7, hits: ex ? 7 : 5, gap: 3, box: const Box(1500, 5000, 9000, 8000), damage: ex ? 18 : 17,
        finisherDamage: ex ? 55 : 40),
    chip: 4, hitstun: 14, blockstun: 10, hitstop: 7, pushback: 350, knockdown: true, meterGain: 50,
    cancelMask: cancelSuperOnly, cancelBlock: false, steps: const [MoveStep(3, vx: 500), MoveStep(26, vx: 0)]);

MoveDef _pounce(bool ex) => MoveDef('pounce', cls: MoveClass.special, startup: ex ? 10 : 14, active: 10, recovery: 14,
    box: const Box(1500, 0, 9000, 11000), damage: ex ? 110 : 90, chip: 12, hitstun: 20, blockstun: 16, hitstop: 10,
    pushback: 700, knockdown: true, wallBounce: ex, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly,
    cancelBlock: false, steps: [MoveStep(ex ? 4 : 6, vx: 1350, vy: 1300)], airborne: true, landRecovery: 12);

MoveDef _lowRake(bool ex) => MoveDef('lowRake', cls: MoveClass.special, startup: ex ? 7 : 9, active: 4, recovery: 20,
    box: const Box(1500, 0, 11000, 3500), damage: ex ? 80 : 60, chip: 8, blockstun: 12, hitstop: 9, pushback: 500,
    height: BlockHeight.low, knockdown: true, meterGain: 60, pose: Pose.crouch, hurt: const [Box(-5500, 0, 11000, 6500)],
    cancelMask: cancelSuperOnly, cancelBlock: false, steps: const [MoveStep(3, vx: 1100), MoveStep(14, vx: 0)],
    invuln: const [Invuln(3, 12, Inv.projectile)]);

MoveDef _risingClaw(bool ex) => MoveDef('risingClaw', cls: MoveClass.special, startup: 5, active: 7, recovery: 24,
    box: const Box(0, 6000, 8500, 16000), damage: ex ? 110 : 90, chip: 10, blockstun: 16, hitstop: 10, pushback: 300,
    knockdown: true, launch: ex ? 1000 : 850, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: const [MoveStep(3, vx: 200, vy: 1500)], invuln: [Invuln(0, ex ? 11 : 7, Inv.strike)], airborne: true,
    landRecovery: 14);

MoveDef _tigerRage() => MoveDef('tigerRage', cls: MoveClass.superMove, startup: 10, active: 27, recovery: 24,
    windows: rapidWindows(start: 10, hits: 9, gap: 3, box: const Box(500, 2000, 11500, 14000), damage: 34, finisherDamage: 130),
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 700, knockdown: true, launch: 750, juggleCost: 0, scaleFloor: 40,
    steps: const [MoveStep(2, vx: 1500), MoveStep(10, vx: 300), MoveStep(38, vx: 0)], invuln: const [Invuln(0, 10, Inv.all)]);

CharacterDef buildRyoko() => CharacterDef(
      id: 8, key: 'ryoko', name: 'RYOKO', kind: 'animal', maxHealth: 1050,
      walkFwd: 330, walkBack: 270, dashSpeed: 1000, dashFrames: 15, backdashSpeed: 850, backdashFrames: 17,
      jumpVy: 1850, jumpVx: 430, gravity: 90, pushHalf: 3500,
      standHurt: const [Box(-3500, 0, 7000, 16500)], crouchHurt: const [Box(-3500, 0, 7000, 9500)],
      airHurt: const [Box(-3500, 1500, 7000, 13500)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 102)),
        _clawFlurry(false), // 10 neutral
        _pounce(false), // 11 forward
        _lowRake(false), // 12 down
        _risingClaw(false), // 13 up
        _tigerRage(), // 14 super
        _clawFlurry(true), // 15
        _pounce(true), // 16
        _lowRake(true), // 17
        _risingClaw(true), // 18
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
