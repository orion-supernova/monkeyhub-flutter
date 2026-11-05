// PIP - tiny tamarin, air acrobat. 780 health, very small hurtboxes, DOUBLE JUMP (airJumps 1).
//
// Movement: walk 3.8/3.4 px/f, dash 10.5 px/f x14f, backdash 10 px/f x15f, jump 20 (air jump 17), gravity 85.
// Normals: damage 80%, heavy -1f startup, reach 80%.
// Hurtboxes: 44 px wide, 105 px tall (a standing Kai is 70 x 170).
//
// | move        | input | st | act | rec | dmg | hit/blk stun | height | notes                                              |
// |-------------|-------|----|-----|-----|-----|--------------|--------|----------------------------------------------------|
// | nutToss     |  S    | 10 |  -  |  18 |  35 | 14 / 10      | mid    | small fast acorn 7 px/f, chip 6; EX: two acorns    |
// | swingKick   | >S    |  8 | 12  |  14 |  60 | 18 / 12      | mid    | vine-swing air kick, ends airborne (jump-cancel)   |
// | scamper     |  vS   |  6 | 10  |  16 |  45 | KD / 11      | LOW    | skitters under fire, projectile-invuln 2-14        |
// | tailSpin    |  ^S   |  6 | 12  |  16 | 25+25+45 | KD / 11 | mid    | rising 3-hit spin, ends airborne (jump-cancel)     |
// | blurFlurry  | super |  9 | 21  |  20 | 6x30+110 | KD      | mid    | vanishes (invuln 0-9), reappears behind, flurry    |
// Air moves end in the jump state, so the double jump is available afterwards.
// EX: nutToss 2 acorns, swingKick faster + harder, scamper faster, tailSpin 4 hits.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const ProjectileDef _acorn = ProjectileDef('Acorn', w: 3500, h: 3500, vx: 700, life: 60, damage: 35, chip: 6, hitstun: 14,
    blockstun: 10, hitstop: 7, pushback: 300, priority: 1, meterGain: 30);
const ProjectileDef _acornEx = ProjectileDef('Acorn EX', w: 4500, h: 4500, vx: 900, life: 60, damage: 40, chip: 6,
    hitstun: 15, blockstun: 10, hitstop: 7, pushback: 350, priority: 1, meterGain: 30);

MoveDef _nutToss(bool ex) => MoveDef('nutToss', cls: MoveClass.special, startup: ex ? 8 : 10, active: 0, recovery: ex ? 16 : 18,
    projectiles: ex
        ? const [ProjSpawn(7, 1, 4500, 6000), ProjSpawn(13, 1, 4500, 3000)]
        : const [ProjSpawn(9, 0, 4500, 6000)],
    meterGain: 40);

MoveDef _swingKick(bool ex) => MoveDef('swingKick', cls: MoveClass.special, startup: ex ? 6 : 8, active: 12, recovery: 14,
    box: const Box(1000, 0, 6500, 8000), damage: ex ? 80 : 60, chip: 8, hitstun: 18, blockstun: 12, hitstop: 8, pushback: 500,
    meterGain: 50, cancelMask: cancelSuperOnly, cancelBlock: false, steps: [MoveStep(ex ? 3 : 4, vx: ex ? 1300 : 1100, vy: 1000)],
    airborne: true, landRecovery: 8);

MoveDef _scamper(bool ex) => MoveDef('scamper', cls: MoveClass.special, startup: ex ? 4 : 6, active: 10, recovery: 16,
    box: const Box(500, 0, 7000, 3500), damage: ex ? 60 : 45, chip: 6, blockstun: 11, hitstop: 8, pushback: 400,
    height: BlockHeight.low, knockdown: true, meterGain: 50, pose: Pose.crouch, hurt: const [Box(-3000, 0, 6000, 5000)],
    cancelMask: cancelSuperOnly, cancelBlock: false, steps: const [MoveStep(2, vx: 1500), MoveStep(16, vx: 0)],
    invuln: const [Invuln(2, 14, Inv.projectile)]);

MoveDef _tailSpin(bool ex) => MoveDef('tailSpin', cls: MoveClass.special, startup: 6, active: ex ? 16 : 12, recovery: 16,
    windows: rapidWindows(start: 6, hits: ex ? 4 : 3, gap: 4, box: const Box(-3500, 0, 9000, 10000), damage: 25,
        finisherDamage: ex ? 55 : 45),
    chip: 6, hitstun: 16, blockstun: 11, hitstop: 8, pushback: 300, knockdown: true, launch: 600, juggleCost: 3,
    meterGain: 50, cancelMask: cancelSuperOnly, cancelBlock: false, steps: const [MoveStep(3, vx: 100, vy: 1700)],
    airborne: true, landRecovery: 10);

MoveDef _blurFlurry() => MoveDef('blurFlurry', cls: MoveClass.superMove, startup: 9, active: 21, recovery: 20,
    windows: rapidWindows(start: 9, hits: 7, gap: 3, box: const Box(0, 0, 9000, 12000), damage: 30, finisherDamage: 110),
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 500, knockdown: true, launch: 700, juggleCost: 0, scaleFloor: 40,
    steps: const [MoveStep(6, teleport: 1, tpOffset: 7000, faceOpponent: true)], invuln: const [Invuln(0, 9, Inv.all)]);

CharacterDef buildPip() => CharacterDef(
      id: 7, key: 'pip', name: 'PIP', kind: 'animal', maxHealth: 780,
      walkFwd: 380, walkBack: 340, dashSpeed: 1050, dashFrames: 14, backdashSpeed: 1000, backdashFrames: 15,
      jumpVy: 2000, jumpVx: 480, gravity: 85, pushHalf: 2200, airJumps: 1,
      standHurt: const [Box(-2200, 0, 4400, 10500)], crouchHurt: const [Box(-2200, 0, 4400, 6500)],
      airHurt: const [Box(-2200, 1000, 4400, 9000)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 80, heavyStartup: -1, reachPct: 80)),
        _nutToss(false), // 10 neutral
        _swingKick(false), // 11 forward
        _scamper(false), // 12 down
        _tailSpin(false), // 13 up
        _blurFlurry(), // 14 super
        _nutToss(true), // 15
        _swingKick(true), // 16
        _scamper(true), // 17
        _tailSpin(true), // 18
      ],
      projectiles: const [_acorn, _acornEx],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
