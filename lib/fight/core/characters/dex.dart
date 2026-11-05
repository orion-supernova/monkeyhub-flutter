// DEX - human (he), capoeira dancer. Evasive, flowing pressure. 950 health.
//
// Movement: walk 3.4/3.0 px/f, dash 9.5 px/f x15f, backdash 8.5 px/f x17f, jump 18.5 (airtime ~43f).
// Normals: damage 95%, reach 105%.
//
// | move            | input | st | act | rec | dmg | hit/blk stun | height | notes                                          |
// |-----------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------------|
// | spinKick        |  S    | 10 | 10  |  20 | 40+50 | 16 / 12    | mid    | 2-hit meia-lua spin, ender knocks down         |
// | flowCombo       | >S    | 12 | 15  |  22 | 30+30+55 | 16 / 12 | mid    | advancing 3-hit flow, ender knocks down        |
// | lowCartwheel    | vS    |  9 | 10  |  18 | 30+45 | KD / 12    | LOW    | 2-hit low cartwheel, projectile-invuln 3-21    |
// | invertida       | ^S    |  8 |  8  |  22 |  85 | KD+launch/16 | mid    | handstand kick, strike+projectile-invuln 0-12  |
// | rodaDeFogo      | super | 12 | 28  |  22 | 6x42+110 | KD      | mid    | whirling rush, invuln 0-12, 2 bars             |
// EX (heavy held, 1 bar): spinKick 3 hits, flowCombo 4 hits, lowCartwheel faster, invertida longer invuln.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

MoveDef _spinKick(bool ex) => MoveDef('spinKick', cls: MoveClass.special, startup: ex ? 8 : 10, active: ex ? 15 : 10, recovery: 20,
    windows: rapidWindows(start: ex ? 8 : 10, hits: ex ? 3 : 2, gap: 5, box: const Box(0, 3000, 11500, 6000),
        damage: ex ? 40 : 38, finisherDamage: ex ? 60 : 50, stop: 3),
    chip: 8, hitstun: 16, blockstun: 12, hitstop: 9, pushback: 600, knockdown: true, meterGain: 60,
    cancelMask: cancelSuperOnly, cancelBlock: false);

MoveDef _flowCombo(bool ex) => MoveDef('flowCombo', cls: MoveClass.special, startup: 12, active: ex ? 20 : 15, recovery: 22,
    windows: rapidWindows(start: 12, hits: ex ? 4 : 3, gap: 5, box: const Box(1000, 2000, 10000, 10000),
        damage: ex ? 34 : 30, finisherDamage: ex ? 65 : 55, stop: 3),
    chip: 8, hitstun: 16, blockstun: 12, hitstop: 9, pushback: 600, knockdown: true, meterGain: 60,
    cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [const MoveStep(6, vx: 500), MoveStep(ex ? 32 : 27, vx: 0)]);

MoveDef _lowCartwheel(bool ex) => MoveDef('lowCartwheel', cls: MoveClass.special, startup: ex ? 7 : 9, active: 10, recovery: 18,
    windows: rapidWindows(start: ex ? 7 : 9, hits: 2, gap: 5, box: const Box(0, 0, 10500, 4500), damage: ex ? 36 : 30,
        finisherDamage: ex ? 55 : 45, stop: 3),
    chip: 8, blockstun: 12, hitstun: 14, hitstop: 9, pushback: 500, height: BlockHeight.low, knockdown: true,
    pose: Pose.crouch, hurt: const [Box(-5000, 0, 10000, 5500)], meterGain: 60, cancelMask: cancelSuperOnly,
    cancelBlock: false, steps: [MoveStep(ex ? 2 : 3, vx: ex ? 1250 : 1050), MoveStep(ex ? 19 : 21, vx: 0)],
    invuln: const [Invuln(3, 21, Inv.projectile)]);

MoveDef _invertida(bool ex) => MoveDef('invertida', cls: MoveClass.special, startup: 8, active: 8, recovery: 22,
    box: const Box(1000, 4000, 9500, 12000), damage: ex ? 105 : 85, chip: 10, hitstun: 16, blockstun: 16, hitstop: 10,
    pushback: 400, knockdown: true, launch: ex ? 800 : 600, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly,
    cancelBlock: false, steps: const [MoveStep(2, vx: 700, vy: 900)],
    invuln: [Invuln(0, ex ? 16 : 12, Inv.strike | Inv.projectile)], airborne: true, landRecovery: 8);

MoveDef _rodaDeFogo() => MoveDef('rodaDeFogo', cls: MoveClass.superMove, startup: 12, active: 28, recovery: 22,
    windows: rapidWindows(start: 12, hits: 7, gap: 4, box: const Box(-4000, 1000, 15000, 12000), damage: 42,
        finisherDamage: 110),
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 700, knockdown: true, launch: 700, juggleCost: 0, scaleFloor: 40,
    steps: const [MoveStep(2, vx: 1200), MoveStep(12, vx: 250), MoveStep(40, vx: 0)],
    invuln: const [Invuln(0, 12, Inv.all)]);

CharacterDef buildDex() => CharacterDef(
      id: 13, key: 'dex', name: 'DEX', kind: 'human', maxHealth: 950,
      walkFwd: 340, walkBack: 300, dashSpeed: 950, dashFrames: 15, backdashSpeed: 850, backdashFrames: 17,
      jumpVy: 1850, jumpVx: 450, gravity: 85, pushHalf: 3300,
      standHurt: const [Box(-3300, 0, 6600, 16500)], crouchHurt: const [Box(-3300, 0, 6600, 9500)],
      airHurt: const [Box(-3300, 1500, 6600, 13500)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 95, reachPct: 105)),
        _spinKick(false), // 10
        _flowCombo(false), // 11
        _lowCartwheel(false), // 12
        _invertida(false), // 13
        _rodaDeFogo(), // 14
        _spinKick(true), // 15
        _flowCombo(true), // 16
        _lowCartwheel(true), // 17
        _invertida(true), // 18
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
