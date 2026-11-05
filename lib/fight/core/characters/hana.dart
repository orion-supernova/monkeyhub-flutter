// HANA - human (she), fencer. Long reach, low health. 900 health.
//
// Movement: walk 3.1/2.8 px/f, dash 9 px/f x15f, backdash 9 px/f x15f, jump 18.5 (airtime ~43f).
// Normals: damage 95%, reach 130% (blade pokes).
//
// | move            | input | st | act | rec | dmg | hit/blk stun | height | notes                                          |
// |-----------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------------|
// | thrustFlurry    |  S    |  7 | 12  |  18 | 4x22+40 | 14 / 10  | mid    | fast 5-hit thin thrusts, 150 px reach          |
// | lunge           | >S    | 12 |  6  |  24 |  80 | 20 / 13      | mid    | fleche, 12.5 px/f, 160 px reach, unsafe        |
// | riposte         | vS    |  5 |  -  |  26 | 120 | counter 4-24 | -      | if struck: lunges through and stabs (KD)       |
// | risingPoint     | ^S    |  7 |  8  |  26 |  85 | KD+launch/18 | mid    | raised blade anti-air, strike-invuln 0-6       |
// | grandeFleche    | super | 12 | 27  |  22 | 8x36+110 | KD      | mid    | dash-in stab flurry, invuln 0-12, 2 bars       |
// EX (heavy held, 1 bar): flurry 7 hits, lunge faster + knockdown, riposte longer window + 150 dmg,
// risingPoint longer invuln.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const int _riposteStrike = 19;
const int _riposteStrikeEx = 20;

MoveDef _thrustFlurry(bool ex) => MoveDef('thrustFlurry', cls: MoveClass.special, startup: 7, active: ex ? 18 : 12, recovery: 18,
    windows: rapidWindows(start: 7, hits: ex ? 7 : 5, gap: 3, box: const Box(2000, 8000, 15000, 2500), damage: ex ? 24 : 22,
        finisherDamage: ex ? 50 : 40, stop: 2),
    chip: 6, hitstun: 14, blockstun: 10, hitstop: 7, pushback: 300, knockdown: false, meterGain: 50,
    cancelMask: cancelSuperOnly, cancelBlock: false);

MoveDef _lunge(bool ex) => MoveDef('lunge', cls: MoveClass.special, startup: ex ? 9 : 12, active: 6, recovery: 24,
    box: const Box(2000, 7000, 16000, 3000), damage: ex ? 100 : 80, chip: 10, hitstun: 20, blockstun: 13, hitstop: 10,
    pushback: 600, knockdown: ex, meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [MoveStep(ex ? 4 : 6, vx: 1250), MoveStep(ex ? 16 : 19, vx: 0)]);

MoveDef _riposte(bool ex) => MoveDef('riposte', cls: MoveClass.special, startup: 5, active: 0, recovery: ex ? 30 : 26,
    pose: Pose.stand, counterStart: 4, counterEnd: ex ? 30 : 24, counterMove: ex ? _riposteStrikeEx : _riposteStrike);

MoveDef _riposteFollow(bool ex) => MoveDef('riposteStrike', cls: MoveClass.special, startup: 5, active: 4, recovery: 18,
    box: const Box(2000, 6000, 17000, 3500), damage: ex ? 150 : 120, blockstun: 16, hitstop: 11, pushback: 700,
    knockdown: true, launch: 600, juggleCost: 2, meterGain: 40,
    steps: const [MoveStep(0, vx: 1400), MoveStep(9, vx: 0)], invuln: const [Invuln(0, 5, Inv.strike | Inv.projectile)]);

MoveDef _risingPoint(bool ex) => MoveDef('risingPoint', cls: MoveClass.special, startup: 7, active: 8, recovery: 26,
    box: const Box(1000, 9000, 10000, 14000), damage: ex ? 105 : 85, chip: 10, blockstun: 18, hitstop: 10, pushback: 300,
    knockdown: true, launch: ex ? 950 : 800, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    invuln: [Invuln(0, ex ? 10 : 6, Inv.strike)]);

MoveDef _grandeFleche() => MoveDef('grandeFleche', cls: MoveClass.superMove, startup: 12, active: 27, recovery: 22,
    windows: rapidWindows(start: 12, hits: 9, gap: 3, box: const Box(2000, 6000, 17000, 6000), damage: 36, finisherDamage: 110),
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 600, knockdown: true, launch: 700, juggleCost: 0, scaleFloor: 40,
    steps: const [MoveStep(2, vx: 1500), MoveStep(12, vx: 250), MoveStep(39, vx: 0)],
    invuln: const [Invuln(0, 12, Inv.all)]);

CharacterDef buildHana() => CharacterDef(
      id: 14, key: 'hana', name: 'HANA', kind: 'human', maxHealth: 900,
      walkFwd: 310, walkBack: 280, dashSpeed: 900, dashFrames: 15, backdashSpeed: 900, backdashFrames: 15,
      jumpVy: 1850, jumpVx: 400, gravity: 85, pushHalf: 3000,
      standHurt: const [Box(-3000, 0, 6000, 16500)], crouchHurt: const [Box(-3000, 0, 6000, 9500)],
      airHurt: const [Box(-3000, 1500, 6000, 13500)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 95, reachPct: 130)),
        _thrustFlurry(false), // 10
        _lunge(false), // 11
        _riposte(false), // 12
        _risingPoint(false), // 13
        _grandeFleche(), // 14
        _thrustFlurry(true), // 15
        _lunge(true), // 16
        _riposte(true), // 17
        _risingPoint(true), // 18
        _riposteFollow(false), // 19
        _riposteFollow(true), // 20
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
