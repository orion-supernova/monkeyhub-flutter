// UNIT-7 - legend (it), robot. Rockets and lasers, zoner with a thruster dash. 1000 health.
//
// Movement: walk 2.8/2.4 px/f, dash 8 px/f x17f, backdash 7 px/f x18f, jump 17 (airtime ~38f).
// Normals: damage 100%, heavy +1f startup.
//
// | move            | input | st | act | rec | dmg | hit/blk stun | height | notes                                          |
// |-----------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------------|
// | rocket          |  S    | 18 |  -  |  30 |  90 | KD / 14      | mid    | slow rocket 3.5 px/f, sinks 0.6 px/f (downward |
// |                 |       |    |     |     |     |              |        | step), priority 3; EX: high + low pair         |
// | thrusterDash    | >S    | 10 |  8  |  20 |  70 | KD / 13      | mid    | hover dash, 13 px/f with a small lift          |
// | laserBeam       | vS    | 16 |  -  |  24 | 4x25 | 14 / 10     | mid    | fast long beam (15 px/f, 300 px wide), 4 hits, |
// |                 |       |    |     |     |     |              |        | chest height: crouch under it; EX 6 hits       |
// | jetRise         | ^S    |  6 | 10  |  24 | 100 | KD+launch/18 | mid    | thruster uppercut, strike-invuln 0-6           |
// | selfDestruct    | super | 30 |  3  |  60 | 350 | KD+launch    | mid    | huge blast, invuln 0-20, chip 40; long recovery|
// EX (heavy held, 1 bar): rocket pair, dash longer, laser 6 hits, jetRise longer invuln.
//
// Approximation: the rocket is not homing; it is a straight projectile with a constant downward drift (vy -60).
// Approximation: selfDestruct has no health cost (no mechanic); a 60f recovery is the price instead.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const ProjectileDef _rocket = ProjectileDef('Rocket', w: 7000, h: 6000, vx: 350, vy: -60, life: 160, damage: 90, chip: 14,
    hitstun: 22, blockstun: 14, hitstop: 10, pushback: 700, knockdown: true, priority: 3);
const ProjectileDef _rocketExHigh = ProjectileDef('Rocket EX high', w: 7000, h: 6000, vx: 450, vy: -70, life: 130, damage: 80,
    chip: 14, hitstun: 22, blockstun: 14, hitstop: 10, pushback: 700, knockdown: true, priority: 3);
const ProjectileDef _rocketExLow = ProjectileDef('Rocket EX low', w: 7000, h: 6000, vx: 450, vy: 0, life: 130, damage: 80,
    chip: 14, hitstun: 22, blockstun: 14, hitstop: 10, pushback: 700, knockdown: true, priority: 3);
const ProjectileDef _laser = ProjectileDef('Laser', w: 30000, h: 3000, vx: 1500, life: 14, hits: 4, damage: 25, chip: 6,
    hitstun: 14, blockstun: 10, hitstop: 3, pushback: 200, priority: 3);
const ProjectileDef _laserEx = ProjectileDef('Laser EX', w: 36000, h: 3500, vx: 1700, life: 16, hits: 6, damage: 28, chip: 6,
    hitstun: 14, blockstun: 10, hitstop: 3, pushback: 250, priority: 4);

MoveDef _rocketMove(bool ex) => MoveDef('rocket', cls: MoveClass.special, startup: 18, active: 0, recovery: 30,
    projectiles: ex
        ? const [ProjSpawn(17, 1, 6000, 11000), ProjSpawn(17, 2, 6000, 1000)]
        : const [ProjSpawn(17, 0, 6000, 11000)],
    meterGain: 60);

MoveDef _thrusterDash(bool ex) => MoveDef('thrusterDash', cls: MoveClass.special, startup: ex ? 8 : 10, active: 8, recovery: 20,
    box: const Box(1000, 3000, 9500, 10000), damage: ex ? 90 : 70, chip: 10, hitstun: 20, blockstun: 13, hitstop: 10,
    pushback: 600, knockdown: true, juggleCost: 2, meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [MoveStep(ex ? 4 : 5, vx: ex ? 1500 : 1300, vy: 400)], airborne: true, landRecovery: 6);

MoveDef _laserBeam(bool ex) => MoveDef('laserBeam', cls: MoveClass.special, startup: 16, active: 0, recovery: 24,
    projectiles: [ProjSpawn(15, ex ? 4 : 3, 5000, 10500)], meterGain: 60);

MoveDef _jetRise(bool ex) => MoveDef('jetRise', cls: MoveClass.special, startup: 6, active: 10, recovery: 24,
    box: const Box(0, 5000, 8500, 17000), damage: ex ? 120 : 100, chip: 12, blockstun: 18, hitstop: 10, pushback: 300,
    knockdown: true, launch: ex ? 1000 : 850, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: const [MoveStep(3, vx: 150, vy: 1400)], invuln: [Invuln(0, ex ? 10 : 6, Inv.strike)], airborne: true, landRecovery: 12);

MoveDef _selfDestruct() => MoveDef('selfDestruct', cls: MoveClass.superMove, startup: 30, active: 3, recovery: 60,
    box: const Box(-12000, 0, 24000, 20000), damage: 350, chip: 40, hitstun: 26, blockstun: 18, hitstop: 14, pushback: 1000,
    knockdown: true, launch: 1200, juggleCost: 0, scaleFloor: 50, invuln: const [Invuln(0, 20, Inv.all)]);

CharacterDef buildUnit7() => CharacterDef(
      id: 16, key: 'unit7', name: 'UNIT-7', kind: 'fantasy', maxHealth: 1000,
      walkFwd: 280, walkBack: 240, dashSpeed: 800, dashFrames: 17, backdashSpeed: 700, backdashFrames: 18,
      jumpVy: 1700, jumpVx: 350, gravity: 90, pushHalf: 3800,
      standHurt: const [Box(-3800, 0, 7600, 18000)], crouchHurt: const [Box(-3800, 0, 7600, 10500)],
      airHurt: const [Box(-3800, 1500, 7600, 15000)],
      moves: [
        ...sharedNormals(const NormalTweaks(heavyStartup: 1)),
        _rocketMove(false), // 10
        _thrusterDash(false), // 11
        _laserBeam(false), // 12
        _jetRise(false), // 13
        _selfDestruct(), // 14
        _rocketMove(true), // 15
        _thrusterDash(true), // 16
        _laserBeam(true), // 17
        _jetRise(true), // 18
      ],
      projectiles: const [_rocket, _rocketExHigh, _rocketExLow, _laser, _laserEx],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
