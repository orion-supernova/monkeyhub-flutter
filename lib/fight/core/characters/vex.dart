// VEX - fox, illusions and fakes. 880 health, quick, slippery, fragile.
//
// Movement: walk 3.4/3.1 px/f, dash 10 px/f x15f, backdash 9.5 px/f x15f, jump 18.5, gravity 85.
// Normals: damage 92%, reach 100%.
//
// | move        | input | st | act | rec | dmg | hit/blk stun | height | notes                                              |
// |-------------|-------|----|-----|-----|-----|--------------|--------|----------------------------------------------------|
// | decoy       |  S    | 12 |  -  |  24 |  70 | 18 / 12      | mid    | a stationary fox illusion 140 px ahead, 2.5 s;     |
// |             |       |    |     |     |     |              |        | EX: creeps forward, 2 hits                         |
// | fakeOut     | >S    |  7 |  -  |  14 |  -  | -            | -      | feint lunge that cancels into any special from f7  |
// | phantomSnare|  vS   | 12 |  -  |  22 |  45 | trip (KD)    | trap   | places 1 trap (8 s), a new one replaces it         |
// | mirageStep  |  ^S   | 10 |  4  |  22 |  70 | KD+launch/-  | mid    | invuln 0-9, teleports behind at f8, then strikes   |
// | nineTails   | super | 32 |  4  |  24 | 5x50+120 | KD      | mid    | invuln 0-12, 5 spirit foxes then a burst, 2 bars   |
// EX: decoy creeps, fakeOut has strike-invuln 1-9 and cancels from f5, snare is bigger/longer, mirageStep faster + harder.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const int _cancelAnySpecial = (1 << 1) | (1 << 2); // special | super

const ProjectileDef _decoy = ProjectileDef('Decoy', w: 6000, h: 15000, vx: 0, life: 150, damage: 70, chip: 8, hitstun: 18,
    blockstun: 12, hitstop: 8, pushback: 500, priority: 1, meterGain: 50);
const ProjectileDef _decoyEx = ProjectileDef('Decoy EX', w: 6500, h: 15500, vx: 160, life: 200, hits: 2, damage: 55,
    chip: 8, hitstun: 18, blockstun: 12, hitstop: 8, pushback: 500, priority: 2, meterGain: 50);
const ProjectileDef _spirit = ProjectileDef('Spirit Fox', w: 5000, h: 5000, vx: 650, life: 90, damage: 50, chip: 8,
    hitstun: 16, blockstun: 11, hitstop: 7, pushback: 350, priority: 1);

const TrapDef _snare = TrapDef('Phantom Snare', w: 6000, h: 3000, life: 480, arm: 10, kind: TrapKind.trip, damage: 45);
const TrapDef _snareEx = TrapDef('Phantom Snare EX', w: 8000, h: 3000, life: 720, arm: 6, kind: TrapKind.trip, damage: 60);

MoveDef _decoyMove(bool ex) => MoveDef('decoy', cls: MoveClass.special, startup: 12, active: 0, recovery: 24,
    projectiles: [ProjSpawn(11, ex ? 1 : 0, 14000, 0)], meterGain: 40);

MoveDef _fakeOut(bool ex) => MoveDef('fakeOut', cls: MoveClass.special, startup: ex ? 5 : 7, active: 0, recovery: ex ? 9 : 7,
    steps: [const MoveStep(1, vx: 1000), MoveStep(ex ? 5 : 7, vx: 0)],
    invuln: ex ? const [Invuln(1, 9, Inv.strike)] : const [],
    cancelMask: _cancelAnySpecial, cancelWhiff: true, cancelHit: true, cancelBlock: true);

MoveDef _phantomSnare(bool ex) => MoveDef('phantomSnare', cls: MoveClass.special, startup: ex ? 9 : 12, active: 0, recovery: 22,
    traps: [TrapSpawn(ex ? 7 : 10, ex ? 1 : 0, 11000)], pose: Pose.crouch);

MoveDef _mirageStep(bool ex) => MoveDef('mirageStep', cls: MoveClass.special, startup: ex ? 8 : 10, active: 4, recovery: 22,
    box: const Box(1500, 5000, 8500, 11000), damage: ex ? 90 : 70, chip: 8, blockstun: 14, hitstop: 10, pushback: 500,
    knockdown: true, launch: 600, juggleCost: 2, meterGain: 60,
    steps: [MoveStep(ex ? 6 : 8, teleport: 1, tpOffset: 8500, faceOpponent: true)],
    invuln: [Invuln(0, ex ? 7 : 9, Inv.strike | Inv.throwing | Inv.projectile)]);

MoveDef _nineTails() => MoveDef('nineTails', cls: MoveClass.superMove, startup: 32, active: 4, recovery: 24,
    windows: const [HitWindow(32, 36, Box(0, 0, 16000, 17000))],
    projectiles: const [
      ProjSpawn(12, 2, 5000, 1000),
      ProjSpawn(16, 2, 5000, 6000),
      ProjSpawn(20, 2, 5000, 11000),
      ProjSpawn(24, 2, 5000, 6000),
      ProjSpawn(28, 2, 5000, 1000),
    ],
    damage: 120, blockstun: 14, hitstop: 10, pushback: 700, knockdown: true, launch: 800, juggleCost: 0, scaleFloor: 40,
    invuln: const [Invuln(0, 12, Inv.all)]);

CharacterDef buildVex() => CharacterDef(
      id: 10, key: 'vex', name: 'VEX', kind: 'animal', maxHealth: 880,
      walkFwd: 340, walkBack: 310, dashSpeed: 1000, dashFrames: 15, backdashSpeed: 950, backdashFrames: 15,
      jumpVy: 1850, jumpVx: 420, gravity: 85, pushHalf: 3000,
      standHurt: const [Box(-3000, 0, 6000, 15500)], crouchHurt: const [Box(-3000, 0, 6000, 9000)],
      airHurt: const [Box(-3000, 1500, 6000, 12500)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 92)),
        _decoyMove(false), // 10 neutral
        _fakeOut(false), // 11 forward
        _phantomSnare(false), // 12 down
        _mirageStep(false), // 13 up
        _nineTails(), // 14 super
        _decoyMove(true), // 15
        _fakeOut(true), // 16
        _phantomSnare(true), // 17
        _mirageStep(true), // 18
      ],
      projectiles: const [_decoy, _decoyEx, _spirit],
      traps: const [_snare, _snareEx],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
