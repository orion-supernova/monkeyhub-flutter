// SAGE - orangutan monk, fruit zoner. 920 health, floaty, calm, weak up close.
//
// Movement: walk 2.7/2.5 px/f, dash 8.5 px/f x16f, backdash 8 px/f x18f, jump 17.5, gravity 80 (floaty).
// Normals: damage 88%, heavy +1f startup, reach 95%.
//
// | move        | input | st | act | rec | dmg | hit/blk stun | height | notes                                               |
// |-------------|-------|----|-----|-----|-----|--------------|--------|-----------------------------------------------------|
// | mangoLob    |  S    | 18 |  -  |  28 |  60 | 18 / 12      | mid    | thrown mango arcs down (3 px/f); EX: arc + flat pair|
// | coconutRoll | >S    | 16 |  -  |  26 |  65 | 20 / 14      | LOW    | coconut rolls along the ground (2.6 px/f); EX: 2 hit|
// | lotusSway   |  vS   | 12 |  -  |  14 |  -  | -            | -      | back-hop, strike/throw/proj-invuln 2-14             |
// | skyPalm     |  ^S   |  7 |  6  |  24 |  70 | KD+launch/14 | mid    | small hop palm, strike-invuln 0-5, anti-air         |
// | fruitFeast  | super | 12 |  -  |  50 | 7 fruits | KD last | mid    | rains 7 fruits across the screen, invuln 0-12, 2 bar|
// EX: mangoLob throws two (arc + flat) faster, coconut pierces twice, sway longer, palm launches higher.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const ProjectileDef _mango = ProjectileDef('Mango', w: 5000, h: 5000, vx: 300, vy: -170, life: 150, damage: 60, chip: 10,
    hitstun: 18, blockstun: 12, hitstop: 8, pushback: 400, priority: 1);
const ProjectileDef _mangoExArc = ProjectileDef('Mango EX arc', w: 5500, h: 5500, vx: 380, vy: -200, life: 140, damage: 55,
    chip: 10, hitstun: 18, blockstun: 12, hitstop: 8, pushback: 450, priority: 1);
const ProjectileDef _mangoExFlat = ProjectileDef('Mango EX flat', w: 5500, h: 5500, vx: 520, life: 110, damage: 55,
    chip: 10, hitstun: 18, blockstun: 12, hitstop: 8, pushback: 450, priority: 1);
const ProjectileDef _coconut = ProjectileDef('Coconut', w: 5000, h: 3500, vx: 260, life: 150, damage: 65, chip: 10,
    hitstun: 20, blockstun: 14, hitstop: 8, pushback: 450, height: BlockHeight.low, priority: 1);
const ProjectileDef _coconutEx = ProjectileDef('Coconut EX', w: 6000, h: 4000, vx: 380, life: 130, hits: 2, damage: 55,
    chip: 12, hitstun: 20, blockstun: 14, hitstop: 8, pushback: 500, height: BlockHeight.low, priority: 2);
const ProjectileDef _fruit = ProjectileDef('Fruit', w: 5000, h: 5000, vx: 0, vy: -420, life: 90, damage: 55, chip: 8,
    hitstun: 18, blockstun: 12, hitstop: 7, pushback: 250, priority: 1);
const ProjectileDef _fruitLast = ProjectileDef('Fruit finale', w: 6000, h: 6000, vx: 0, vy: -420, life: 90, damage: 90,
    chip: 8, hitstun: 18, blockstun: 12, hitstop: 9, pushback: 400, knockdown: true, priority: 1);

MoveDef _mangoLob(bool ex) => MoveDef('mangoLob', cls: MoveClass.special, startup: ex ? 14 : 18, active: 0, recovery: ex ? 22 : 28,
    projectiles: ex
        ? const [ProjSpawn(13, 1, 6000, 24000), ProjSpawn(13, 2, 6000, 11000)]
        : const [ProjSpawn(17, 0, 6000, 24000)],
    meterGain: 60);

MoveDef _coconutRoll(bool ex) => MoveDef('coconutRoll', cls: MoveClass.special, startup: ex ? 13 : 16, active: 0,
    recovery: ex ? 22 : 26, projectiles: [ProjSpawn(ex ? 12 : 15, ex ? 4 : 3, 6000, 0)], meterGain: 60);

MoveDef _lotusSway(bool ex) => MoveDef('lotusSway', cls: MoveClass.special, startup: 12, active: 0, recovery: ex ? 18 : 14,
    steps: const [MoveStep(2, vx: -700), MoveStep(12, vx: 0)],
    invuln: [Invuln(2, ex ? 18 : 14, Inv.strike | Inv.throwing | Inv.projectile)]);

MoveDef _skyPalm(bool ex) => MoveDef('skyPalm', cls: MoveClass.special, startup: 7, active: 6, recovery: 24,
    box: const Box(500, 7000, 7500, 15000), damage: ex ? 90 : 70, chip: 8, blockstun: 14, hitstop: 10, pushback: 300,
    knockdown: true, launch: ex ? 1000 : 800, juggleCost: 3, meterGain: 60, cancelMask: cancelSuperOnly,
    cancelBlock: false, steps: const [MoveStep(3, vx: 100, vy: 1200)],
    invuln: [Invuln(0, ex ? 9 : 5, Inv.strike)], airborne: true, landRecovery: 12);

MoveDef _fruitFeast() => MoveDef('fruitFeast', cls: MoveClass.superMove, startup: 12, active: 0, recovery: 50,
    projectiles: [for (var k = 0; k < 7; k++) ProjSpawn(14 + 4 * k, k == 6 ? 6 : 5, 7000 + 7000 * k, 30000)],
    invuln: const [Invuln(0, 12, Inv.all)]);

CharacterDef buildSage() => CharacterDef(
      id: 5, key: 'sage', name: 'SAGE', kind: 'animal', maxHealth: 920,
      walkFwd: 270, walkBack: 250, dashSpeed: 850, dashFrames: 16, backdashSpeed: 800, backdashFrames: 18,
      jumpVy: 1750, jumpVx: 380, gravity: 80, pushHalf: 3400,
      standHurt: const [Box(-3400, 0, 6800, 17000)], crouchHurt: const [Box(-3400, 0, 6800, 10000)],
      airHurt: const [Box(-3400, 1500, 6800, 14000)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 88, heavyStartup: 1, reachPct: 95)),
        _mangoLob(false), // 10 neutral
        _coconutRoll(false), // 11 forward
        _lotusSway(false), // 12 down
        _skyPalm(false), // 13 up
        _fruitFeast(), // 14 super
        _mangoLob(true), // 15
        _coconutRoll(true), // 16
        _lotusSway(true), // 17
        _skyPalm(true), // 18
      ],
      projectiles: const [_mango, _mangoExArc, _mangoExFlat, _coconut, _coconutEx, _fruit, _fruitLast],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
