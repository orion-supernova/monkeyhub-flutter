// EMBER - legend (she), dragon kid. Fire zoner with a flame-wing hop. 950 health.
//
// Movement: walk 3.4/2.8 px/f, dash 8.8 px/f x15f, backdash 8 px/f x16f, jump 20 (airtime ~47f).
// Normals: damage 100%, reach 95%.
//
// | move            | input | st | act | rec | dmg | hit/blk stun | height | notes                                          |
// |-----------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------------|
// | fireball        |  S    | 15 |  -  |  28 |  65 | 18 / 12      | mid    | 5 px/f fireball, chip 12; EX: 2 hits, faster   |
// | fireBreath      | >S    | 12 |  -  |  30 |  4x20 | 14 / 9     | mid    | short-range (~80 px) 4-hit breath puff; EX 6   |
// | tailSweep       | vS    |  9 |  5  |  22 |  60 | KD / 12      | LOW    | low sweep with the tail, 130 px reach          |
// | flameWingHop    | ^S    |  6 | 14  |  14 |  75 | KD+launch/16 | mid    | winged hop, strike-invuln 0-6, anti-air; EX    |
// |                 |       |    |     |     |     |              |        | adds a diving flame kick                       |
// | dragonInferno   | super | 14 | 30  |  24 | 9x36+110 | KD      | mid    | long (300 px) breath hitbox, invuln 0-14       |
// EX (heavy held, 1 bar): fireball 2-hit, breath 6 hits wider, sweep faster/harder, hop + dive.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const ProjectileDef _fireball = ProjectileDef('Fireball', w: 6500, h: 6500, vx: 500, life: 110, damage: 65, chip: 12,
    hitstun: 18, blockstun: 12, hitstop: 8, pushback: 500, priority: 1);
const ProjectileDef _fireballEx = ProjectileDef('Fireball EX', w: 8500, h: 8000, vx: 650, life: 100, hits: 2, damage: 60,
    chip: 14, hitstun: 20, blockstun: 14, hitstop: 8, pushback: 600, priority: 2);
const ProjectileDef _breath = ProjectileDef('Fire Breath', w: 9000, h: 6000, vx: 450, life: 14, hits: 4, damage: 20, chip: 5,
    hitstun: 14, blockstun: 9, hitstop: 3, pushback: 250, priority: 0);
const ProjectileDef _breathEx = ProjectileDef('Fire Breath EX', w: 12000, h: 7500, vx: 500, life: 18, hits: 6, damage: 22,
    chip: 6, hitstun: 14, blockstun: 9, hitstop: 3, pushback: 300, priority: 1);

MoveDef _fireballMove(bool ex) => MoveDef('fireball', cls: MoveClass.special, startup: ex ? 12 : 15, active: 0,
    recovery: ex ? 24 : 28, projectiles: [ProjSpawn(ex ? 11 : 14, ex ? 1 : 0, 7000, 9000)], meterGain: 60);

MoveDef _fireBreathMove(bool ex) => MoveDef('fireBreath', cls: MoveClass.special, startup: 12, active: 0, recovery: 30,
    projectiles: [ProjSpawn(11, ex ? 3 : 2, 6000, 9500)], meterGain: 60);

MoveDef _tailSweep(bool ex) => MoveDef('tailSweep', cls: MoveClass.special, startup: ex ? 7 : 9, active: 5, recovery: 22,
    box: const Box(1000, 0, 13000, 3500), damage: ex ? 80 : 60, chip: 8, blockstun: 12, hitstop: 9, pushback: 500,
    height: BlockHeight.low, knockdown: true, pose: Pose.crouch, meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false);

MoveDef _flameWingHop(bool ex) => MoveDef('flameWingHop', cls: MoveClass.special, startup: 6, active: 14, recovery: 14,
    box: const Box(-1000, 2000, 10000, 14000), damage: ex ? 95 : 75, chip: 10, hitstun: 18, blockstun: 16, hitstop: 10,
    pushback: 400, knockdown: true, launch: 700, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: ex
        ? const [MoveStep(4, vx: 400, vy: 1900), MoveStep(20, vx: 900, vy: -1100)]
        : const [MoveStep(4, vx: 400, vy: 1900)],
    invuln: const [Invuln(0, 6, Inv.strike)], airborne: true, landRecovery: 10);

MoveDef _dragonInferno() => MoveDef('dragonInferno', cls: MoveClass.superMove, startup: 14, active: 30, recovery: 24,
    windows: rapidWindows(start: 14, hits: 9, gap: 3, box: const Box(2000, 3000, 30000, 12000), damage: 36, finisherDamage: 110),
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 300, knockdown: true, launch: 800, juggleCost: 0, scaleFloor: 40,
    invuln: const [Invuln(0, 14, Inv.all)]);

CharacterDef buildEmber() => CharacterDef(
      id: 18, key: 'ember', name: 'EMBER', kind: 'fantasy', maxHealth: 950,
      walkFwd: 340, walkBack: 280, dashSpeed: 880, dashFrames: 15, backdashSpeed: 800, backdashFrames: 16,
      jumpVy: 2000, jumpVx: 450, gravity: 85, pushHalf: 3200,
      standHurt: const [Box(-3200, 0, 6400, 16000)], crouchHurt: const [Box(-3200, 0, 6400, 9500)],
      airHurt: const [Box(-3200, 1500, 6400, 13500)],
      moves: [
        ...sharedNormals(const NormalTweaks(reachPct: 95)),
        _fireballMove(false), // 10
        _fireBreathMove(false), // 11
        _tailSweep(false), // 12
        _flameWingHop(false), // 13
        _dragonInferno(), // 14
        _fireballMove(true), // 15
        _fireBreathMove(true), // 16
        _tailSweep(true), // 17
        _flameWingHop(true), // 18
      ],
      projectiles: const [_fireball, _fireballEx, _breath, _breathEx],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
