// NYX - shadow spirit zoner. 900 health, floaty, weak up close.
//
// Movement: walk 3.0/2.8 px/f, dash 9.5 px/f x15f, backdash 9 px/f x16f, jump 18.
// Normals: damage 90%, reach 95%.
//
// | move          | input | st | act | rec | dmg | hit/blk stun | height | notes                                          |
// |---------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------------|
// | Moon Shard    |  S    | 16 |  -  |  30 |  55 | 18 / 12      | mid    | slow shard 3.3 px/f; EX: two shards (50 each)  |
// | Phase Step    | >S    |  8 |  -  |  14 |  -  | -            | -      | strike/throw-invuln 0-10, lands behind foe     |
// | Shadow Pool   | vS    | 14 |  -  |  20 |  -  | slow 120f    | trap   | pool 8 s, slows opponent walk 40% for 2 s      |
// | Eclipse       | ^S    |  6 |  -  |  26 |  -  | counter 4-22 | -      | if struck: teleports behind, strikes (110, KD) |
// | Total Eclipse | super | 14 | 40  |  22 | 8x38+120 | KD      | mid    | screen-wide multi-hit, invuln 0-14, 2 bars     |
// EX: Shards doubled, Phase Step recovers in 8f, Pool bigger/longer slow, Eclipse longer window.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const ProjectileDef _shard = ProjectileDef('Moon Shard', w: 6000, h: 6000, vx: 330, life: 180, damage: 55, chip: 10,
    hitstun: 18, blockstun: 12, hitstop: 8, pushback: 350, priority: 1);
const ProjectileDef _shardEx = ProjectileDef('Moon Shard EX', w: 6000, h: 6000, vx: 420, life: 150, damage: 50, chip: 10,
    hitstun: 18, blockstun: 12, hitstop: 8, pushback: 400, priority: 1);
const ProjectileDef _shardExLow = ProjectileDef('Moon Shard EX low', w: 6000, h: 6000, vx: 420, vy: -90, life: 150,
    damage: 50, chip: 10, hitstun: 18, blockstun: 12, hitstop: 8, pushback: 400, priority: 1);

const TrapDef _pool = TrapDef('Shadow Pool', w: 12000, h: 2000, life: 480, arm: 6, kind: TrapKind.slow, slowFrames: 120,
    consume: false);
const TrapDef _poolEx = TrapDef('Shadow Pool EX', w: 18000, h: 2000, life: 600, arm: 6, kind: TrapKind.slow,
    slowFrames: 180, consume: false);

const int _eclipseStrike = 19;

MoveDef _moonShard(bool ex) => MoveDef('moonShard', cls: MoveClass.special, startup: 16, active: 0, recovery: 30,
    projectiles: ex
        ? const [ProjSpawn(15, 1, 6000, 9500), ProjSpawn(15, 2, 6000, 15000)]
        : const [ProjSpawn(15, 0, 6000, 9500)],
    meterGain: 60);

MoveDef _phaseStep(bool ex) => MoveDef('phaseStep', cls: MoveClass.special, startup: 8, active: 0, recovery: ex ? 8 : 14,
    steps: const [MoveStep(8, teleport: 1, tpOffset: 9000, faceOpponent: true)],
    invuln: const [Invuln(0, 10, Inv.strike | Inv.throwing | Inv.projectile)]);

MoveDef _shadowPool(bool ex) => MoveDef('shadowPool', cls: MoveClass.special, startup: 14, active: 0, recovery: 20,
    traps: [TrapSpawn(12, ex ? 1 : 0, 14000)], pose: Pose.crouch);

MoveDef _eclipse(bool ex) => MoveDef('eclipse', cls: MoveClass.special, startup: 6, active: 0, recovery: ex ? 30 : 26,
    counterStart: 4, counterEnd: ex ? 28 : 22, counterMove: _eclipseStrike);

MoveDef _eclipseFollow() => MoveDef('eclipseStrike', cls: MoveClass.special, startup: 8, active: 4, recovery: 18,
    box: const Box(1500, 6000, 9000, 12000), damage: 110, blockstun: 16, hitstop: 11, pushback: 800, knockdown: true,
    launch: 750, juggleCost: 2, meterGain: 40, steps: const [MoveStep(0, teleport: 1, tpOffset: 7000, faceOpponent: true)],
    invuln: const [Invuln(0, 8, Inv.strike | Inv.projectile)]);

MoveDef _totalEclipse() => MoveDef('totalEclipse', cls: MoveClass.superMove, startup: 14, active: 40, recovery: 22,
    windows: rapidWindows(start: 14, hits: 9, gap: 5, box: const Box(-60000, 0, 120000, 30000), damage: 38, finisherDamage: 120),
    hitstun: 18, blockstun: 14, hitstop: 8, pushback: 300, knockdown: true, launch: 800, juggleCost: 0, scaleFloor: 40,
    invuln: const [Invuln(0, 14, Inv.all)]);

CharacterDef buildNyx() => CharacterDef(
      id: 3, key: 'nyx', name: 'NYX', kind: 'fantasy', maxHealth: 900,
      walkFwd: 300, walkBack: 280, dashSpeed: 950, dashFrames: 15, backdashSpeed: 900, backdashFrames: 16,
      jumpVy: 1800, jumpVx: 400, gravity: 80, pushHalf: 3000,
      standHurt: const [Box(-3000, 0, 6000, 16500)], crouchHurt: const [Box(-3000, 0, 6000, 9500)],
      airHurt: const [Box(-3000, 1500, 6000, 13500)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 90, reachPct: 95)),
        _moonShard(false), // 10
        _phaseStep(false), // 11
        _shadowPool(false), // 12
        _eclipse(false), // 13
        _totalEclipse(), // 14
        _moonShard(true), // 15
        _phaseStep(true), // 16
        _shadowPool(true), // 17
        _eclipse(true), // 18
        _eclipseFollow(), // 19
      ],
      projectiles: const [_shard, _shardEx, _shardExLow],
      traps: const [_pool, _poolEx],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
