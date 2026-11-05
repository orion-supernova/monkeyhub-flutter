// BRUNO - gorilla brawler. 1200 health, big pushbox, heavy hands, slow and tanky.
//
// Movement: walk 2.8/2.2 px/f, dash 8 px/f x18f, backdash 7 px/f x20f, jump 17/-, roll 11.5 px/f.
// Normals: damage 108%, light +1f, heavy +1f startup, reach +5%.
//
// | move        | input | st | act | rec | dmg | hit/blk stun | height | notes                                              |
// |-------------|-------|----|-----|-----|-----|--------------|--------|----------------------------------------------------|
// | chestDrum   |  S    |  6 |  -  |  28 |  -  | counter 4-22 | -      | if struck: answers with drumSlam (130, KD, launch) |
// | gutPunch    | >S    | 15 |  4  |  26 | 110 | KD / 15      | mid    | lumbering haymaker, wall bounce, chip 12           |
// | groundPound |  vS   | 20 |  5  |  28 |  90 | KD / 16      | LOW    | fist slam, ground bounce (juggle starter)          |
// | hammerLeap  |  ^S   | 18 |  8  |  14 | 110 | KD / 16      | HIGH   | short leap, double-fist overhead, 14f landing      |
// | jungleKing  | super | 14 | 30  |  26 | 6x40+160 | KD      | mid    | drum rampage, invuln 0-14, wall bounce, 2 bars     |
// follow-up: drumSlam (move 19, 6f st) from chestDrum; drumSlamEx (move 20) from the EX version.
// EX: chestDrum window 4-30 and a harder slam, gutPunch armor 2-12 (1 hit) + faster, groundPound faster +
// more damage, hammerLeap faster + more damage.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const int _drumSlam = 19;
const int _drumSlamEx = 20;

MoveDef _chestDrum(bool ex) => MoveDef('chestDrum', cls: MoveClass.special, startup: 6, active: 0, recovery: ex ? 32 : 28,
    counterStart: 4, counterEnd: ex ? 30 : 22, counterMove: ex ? _drumSlamEx : _drumSlam);

MoveDef _drumSlamMove(bool ex) => MoveDef('drumSlam', cls: MoveClass.special, startup: 6, active: 4, recovery: 22,
    box: const Box(500, 3000, 11000, 13000), damage: ex ? 170 : 130, blockstun: 16, hitstop: 12, pushback: 800,
    knockdown: true, launch: 700, wallBounce: ex, juggleCost: 2, meterGain: 40,
    invuln: const [Invuln(0, 6, Inv.strike | Inv.projectile)]);

MoveDef _gutPunch(bool ex) => MoveDef('gutPunch', cls: MoveClass.special, startup: ex ? 12 : 15, active: 4, recovery: 26,
    box: const Box(2000, 6000, 10500, 8000), damage: ex ? 135 : 110, chip: 12, hitstun: 22, blockstun: 15, hitstop: 12,
    pushback: 900, knockdown: true, wallBounce: true, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly,
    cancelBlock: false, steps: [MoveStep(ex ? 4 : 6, vx: 500), MoveStep(ex ? 20 : 24, vx: 0)],
    armorStart: ex ? 2 : 0, armorEnd: ex ? 12 : 0, armorHits: ex ? 1 : 0);

MoveDef _groundPound(bool ex) => MoveDef('groundPound', cls: MoveClass.special, startup: ex ? 16 : 20, active: 5, recovery: 28,
    box: const Box(2500, 0, 11000, 3500), damage: ex ? 115 : 90, chip: 10, blockstun: 16, hitstop: 12, pushback: 500,
    height: BlockHeight.low, knockdown: true, groundBounce: true, juggleCost: 3, meterGain: 60,
    cancelMask: cancelSuperOnly, cancelBlock: false);

MoveDef _hammerLeap(bool ex) => MoveDef('hammerLeap', cls: MoveClass.special, startup: ex ? 15 : 18, active: 8, recovery: 14,
    box: const Box(1000, 0, 9500, 12000), damage: ex ? 135 : 110, chip: 14, blockstun: 16, hitstop: 12, pushback: 700,
    height: BlockHeight.high, knockdown: true, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly,
    cancelBlock: false, steps: [const MoveStep(3, vx: 600, vy: 1500), MoveStep(ex ? 13 : 14, vx: 500, vy: -1500)],
    airborne: true, landRecovery: 14);

MoveDef _jungleKing() => MoveDef('jungleKing', cls: MoveClass.superMove, startup: 14, active: 30, recovery: 26,
    windows: rapidWindows(start: 14, hits: 6, gap: 5, box: const Box(500, 2000, 11500, 14000), damage: 40, finisherDamage: 160),
    hitstun: 18, blockstun: 14, hitstop: 8, pushback: 600, knockdown: true, wallBounce: true, launch: 800, juggleCost: 0,
    scaleFloor: 40, steps: const [MoveStep(4, vx: 500), MoveStep(14, vx: 200), MoveStep(44, vx: 0)],
    invuln: const [Invuln(0, 14, Inv.all)]);

CharacterDef buildBruno() => CharacterDef(
      id: 4, key: 'bruno', name: 'BRUNO', kind: 'animal', maxHealth: 1200,
      walkFwd: 280, walkBack: 220, dashSpeed: 800, dashFrames: 18, backdashSpeed: 700, backdashFrames: 20,
      jumpVy: 1700, jumpVx: 330, gravity: 90, rollSpeed: 1150, rollBackSpeed: 900, pushHalf: 4200,
      standHurt: const [Box(-4200, 0, 8400, 18500)], crouchHurt: const [Box(-4200, 0, 8400, 11000)],
      airHurt: const [Box(-4200, 1500, 8400, 15500)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 108, lightStartup: 1, heavyStartup: 1, reachPct: 105)),
        _chestDrum(false), // 10 neutral
        _gutPunch(false), // 11 forward
        _groundPound(false), // 12 down
        _hammerLeap(false), // 13 up
        _jungleKing(), // 14 super
        _chestDrum(true), // 15
        _gutPunch(true), // 16
        _groundPound(true), // 17
        _hammerLeap(true), // 18
        _drumSlamMove(false), // 19
        _drumSlamMove(true), // 20
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
