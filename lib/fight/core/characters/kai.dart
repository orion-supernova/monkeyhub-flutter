// KAI - human, all-rounder street kickboxer. 1000 health.
//
// Movement: walk 3.3/2.6 px/f, dash 9 px/f x16f, backdash 8 px/f x18f, jump 18/-, airtime ~40f.
// Normals: shared template (no tweaks).
//
// | move              | input | st | act | rec | dmg | hit/blk stun | height | notes                                    |
// |-------------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------|
// | Surge Palm        |  S    | 14 |  -  |  29 |  60 | 18 / 12      | mid    | fireball 6 px/f, chip 12; EX: 2 hits     |
// | Comet Knee        | >S    | 12 | 12  |  22 |  90 | KD / 18      | mid    | advancing air knee, ender, wall bounce   |
// | Slide Step        | vS    |  8 | 12  |  20 |  60 | KD / 14      | low    | low profile, projectile-invuln 6-20      |
// | Rising Heel       | ^S    |  5 |  8  |  25 | 100 | KD+launch/20 | mid    | strike-invuln 0-10, anti-air flip kick   |
// | Hundred Storm     | super | 12 | 26  |  24 | 8x40+100 | KD      | mid    | dash-in rush, invuln 0-12, 2 bars        |
// EX (heavy held, 1 bar): Surge Palm 2-hit fast fireball, Comet Knee armor-less faster/stronger,
// Slide Step faster, Rising Heel longer invuln + more launch.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const ProjectileDef _surge = ProjectileDef('Surge Palm', w: 5000, h: 5000, vx: 600, life: 120, damage: 60, chip: 12,
    hitstun: 18, blockstun: 12, hitstop: 8, pushback: 500, priority: 1);
const ProjectileDef _surgeEx = ProjectileDef('Surge Palm EX', w: 6500, h: 6000, vx: 800, life: 110, hits: 2, damage: 55,
    chip: 14, hitstun: 20, blockstun: 14, hitstop: 8, pushback: 600, priority: 2);

MoveDef _surgePalm(bool ex) => MoveDef('surgePalm', cls: MoveClass.special, startup: ex ? 11 : 14, active: 0,
    recovery: ex ? 22 : 29, projectiles: [ProjSpawn(ex ? 10 : 13, ex ? 1 : 0, 7000, 9500)], meterGain: 60);

MoveDef _cometKnee(bool ex) => MoveDef('cometKnee', cls: MoveClass.special, startup: ex ? 9 : 12, active: 12, recovery: 22,
    box: const Box(2000, 2000, 8500, 9000), damage: ex ? 110 : 90, chip: 14, blockstun: 18, hitstop: 10, pushback: 900,
    knockdown: true, wallBounce: true, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [MoveStep(ex ? 5 : 8, vx: ex ? 1250 : 1100, vy: 500)], airborne: true, landRecovery: 12);

MoveDef _slideStep(bool ex) => MoveDef('slideStep', cls: MoveClass.special, startup: ex ? 6 : 8, active: 12, recovery: 20,
    box: const Box(1000, 0, 9000, 4500), damage: ex ? 75 : 60, chip: 10, blockstun: 14, hitstop: 9, pushback: 500,
    height: BlockHeight.low, knockdown: true, pose: Pose.crouch, hurt: const [Box(-6000, 0, 12000, 5500)],
    steps: [MoveStep(ex ? 2 : 4, vx: ex ? 1400 : 1150), const MoveStep(20, vx: 0)],
    invuln: const [Invuln(4, 20, Inv.projectile)], meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false);

MoveDef _risingHeel(bool ex) => MoveDef('risingHeel', cls: MoveClass.special, startup: 5, active: 8, recovery: 25,
    box: const Box(-1000, 6000, 8000, 16000), damage: ex ? 120 : 100, chip: 12, blockstun: 20, hitstop: 10, pushback: 300,
    knockdown: true, launch: ex ? 1000 : 850, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly,
    cancelBlock: false, steps: const [MoveStep(3, vx: 150, vy: 1500)],
    invuln: [Invuln(0, ex ? 14 : 10, Inv.strike)], airborne: true, landRecovery: 14);

MoveDef _hundredStorm() => MoveDef('hundredStorm', cls: MoveClass.superMove, startup: 12, active: 26, recovery: 24,
    windows: rapidWindows(start: 12, hits: 9, gap: 3, box: const Box(1000, 3000, 9500, 12000), damage: 40, finisherDamage: 100),
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 800, knockdown: true, launch: 700, juggleCost: 0, scaleFloor: 40,
    steps: const [MoveStep(2, vx: 1500), MoveStep(12, vx: 250), MoveStep(40, vx: 0)],
    invuln: const [Invuln(0, 12, Inv.all)]);

CharacterDef buildKai() => CharacterDef(
      id: 0, key: 'kai', name: 'KAI', kind: 'human', maxHealth: 1000,
      walkFwd: 330, walkBack: 260, dashSpeed: 900, dashFrames: 16, backdashSpeed: 800, backdashFrames: 18,
      jumpVy: 1800, jumpVx: 400, gravity: 90, pushHalf: 3500,
      standHurt: stdStandHurt, crouchHurt: stdCrouchHurt, airHurt: stdAirHurt,
      moves: [
        ...sharedNormals(),
        _surgePalm(false), // 10 neutral
        _cometKnee(false), // 11 forward
        _slideStep(false), // 12 down
        _risingHeel(false), // 13 up
        _hundredStorm(), // 14 super
        _surgePalm(true), // 15
        _cometKnee(true), // 16
        _slideStep(true), // 17
        _risingHeel(true), // 18
      ],
      projectiles: const [_surge, _surgeEx],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
