// BAO - panda, drunken-style dodger. 1150 health, slow and sturdy, wins by answering attacks.
//
// Movement: walk 2.6/2.3 px/f, dash 7.5 px/f x19f, backdash 6.5 px/f x20f, jump 17.
// Normals: damage 100%, light +1f, heavy +1f startup.
//
// | move         | input | st | act | rec | dmg | hit/blk stun | height | notes                                              |
// |--------------|-------|----|-----|-----|-----|--------------|--------|----------------------------------------------------|
// | drunkenSway  |  S    |  6 |  -  |  30 |  -  | dodge 2-9, counter 9-24 | strikes whiff through the sway, then it counters |
// | bellyBounce  | >S    | 14 | 10  |  14 |  85 | KD / 15      | mid    | hop + belly flop, huge pushback, wall bounce       |
// | tipsySweep   |  vS   | 10 |  4  |  22 |  60 | KD / 12      | LOW    | ducks under strikes (invuln 2-10), then sweeps     |
// | jugRise      |  ^S   |  8 |  6  |  24 |  95 | KD+launch/16 | mid    | strike-invuln 0-10 hop, anti-air                   |
// | drunkenMaster| super | 12 | 35  |  26 | 6x42+150 | KD      | mid    | stumbling flurry, invuln 0-12, 2 bars              |
// follow-up: swayCounter (move 19) from drunkenSway; swayCounterEx (move 20) from the EX version.
// EX: sway dodge 2-11 / counter 11-30 and a harder counter, belly bounce bigger, sweep dodge longer, rise dodge longer.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const int _swayCounter = 19;
const int _swayCounterEx = 20;

MoveDef _drunkenSway(bool ex) => MoveDef('drunkenSway', cls: MoveClass.special, startup: 6, active: 0, recovery: ex ? 34 : 30,
    steps: const [MoveStep(1, vx: -250), MoveStep(12, vx: 0)],
    invuln: [Invuln(2, ex ? 11 : 9, Inv.strike | Inv.projectile)],
    counterStart: ex ? 11 : 9, counterEnd: ex ? 30 : 24, counterMove: ex ? _swayCounterEx : _swayCounter);

MoveDef _swayCounterMove(bool ex) => MoveDef('swayCounter', cls: MoveClass.special, startup: 7, active: 4, recovery: 20,
    box: const Box(500, 4000, 10000, 10000), damage: ex ? 140 : 100, blockstun: 14, hitstop: 11, pushback: 700,
    knockdown: true, launch: 600, juggleCost: 2, meterGain: 40, steps: const [MoveStep(2, vx: 700), MoveStep(11, vx: 0)],
    invuln: const [Invuln(0, 7, Inv.strike | Inv.projectile)]);

MoveDef _bellyBounce(bool ex) => MoveDef('bellyBounce', cls: MoveClass.special, startup: 14, active: 10, recovery: 14,
    box: const Box(-1000, 0, 12000, 12000), damage: ex ? 105 : 85, chip: 10, hitstun: 20, blockstun: 15, hitstop: 11,
    pushback: 1000, knockdown: true, wallBounce: true, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly,
    cancelBlock: false, steps: [const MoveStep(6, vx: 800, vy: 1300)], airborne: true, landRecovery: 12);

MoveDef _tipsySweep(bool ex) => MoveDef('tipsySweep', cls: MoveClass.special, startup: ex ? 8 : 10, active: 4, recovery: 22,
    box: const Box(1500, 0, 11500, 3500), damage: ex ? 80 : 60, chip: 8, blockstun: 12, hitstop: 9, pushback: 500,
    height: BlockHeight.low, knockdown: true, meterGain: 60, pose: Pose.crouch, hurt: const [Box(-4500, 0, 9000, 8000)],
    cancelMask: cancelSuperOnly, cancelBlock: false, steps: const [MoveStep(3, vx: 700), MoveStep(14, vx: 0)],
    invuln: [Invuln(2, ex ? 13 : 10, Inv.strike)]);

MoveDef _jugRise(bool ex) => MoveDef('jugRise', cls: MoveClass.special, startup: 8, active: 6, recovery: 24,
    box: const Box(500, 6000, 8500, 16000), damage: ex ? 115 : 95, chip: 10, blockstun: 16, hitstop: 10, pushback: 300,
    knockdown: true, launch: 850, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: const [MoveStep(4, vx: 150, vy: 1400)], invuln: [Invuln(0, ex ? 14 : 10, Inv.strike)], airborne: true,
    landRecovery: 14);

MoveDef _drunkenMaster() => MoveDef('drunkenMaster', cls: MoveClass.superMove, startup: 12, active: 35, recovery: 26,
    windows: rapidWindows(start: 12, hits: 7, gap: 5, box: const Box(0, 2000, 11500, 14000), damage: 42, finisherDamage: 150),
    hitstun: 18, blockstun: 14, hitstop: 8, pushback: 600, knockdown: true, launch: 800, juggleCost: 0, scaleFloor: 40,
    steps: const [MoveStep(2, vx: 400), MoveStep(12, vx: 200), MoveStep(47, vx: 0)], invuln: const [Invuln(0, 12, Inv.all)]);

CharacterDef buildBao() => CharacterDef(
      id: 9, key: 'bao', name: 'BAO', kind: 'animal', maxHealth: 1150,
      walkFwd: 260, walkBack: 230, dashSpeed: 750, dashFrames: 19, backdashSpeed: 650, backdashFrames: 20,
      jumpVy: 1700, jumpVx: 330, gravity: 90, pushHalf: 4000,
      standHurt: const [Box(-4000, 0, 8000, 17500)], crouchHurt: const [Box(-4000, 0, 8000, 10500)],
      airHurt: const [Box(-4000, 1500, 8000, 14500)],
      moves: [
        ...sharedNormals(const NormalTweaks(lightStartup: 1, heavyStartup: 1)),
        _drunkenSway(false), // 10 neutral
        _bellyBounce(false), // 11 forward
        _tipsySweep(false), // 12 down
        _jugRise(false), // 13 up
        _drunkenMaster(), // 14 super
        _drunkenSway(true), // 15
        _bellyBounce(true), // 16
        _tipsySweep(true), // 17
        _jugRise(true), // 18
        _swayCounterMove(false), // 19
        _swayCounterMove(true), // 20
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
