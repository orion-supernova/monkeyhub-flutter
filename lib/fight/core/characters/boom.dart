// BOOM - human (he), sumo. Push-out pressure. 1300 health, slow, huge pushbox.
//
// Movement: walk 2.2/1.8 px/f, dash 6.5 px/f x20f, backdash 5.5 px/f x22f, jump 15.5 (airtime ~34f).
// Normals: damage 110%, light +2f, heavy +2f startup.
//
// | move            | input | st | act | rec | dmg | hit/blk stun | height | notes                                          |
// |-----------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------------|
// | tsuppari        |  S    | 11 | 20  |  24 | 4x22+40 | 16 / 12  | mid    | 5-hit palm barrage, heavy pushback, wall bounce|
// | dohyoCharge     | >S    | 20 | 16  |  22 |  70 | KD / 14      | mid    | armor 8-24 (1 hit), carries to the wall, bounce|
// | uwatenage       | vS    |  7 |  2  |  34 | 140 | KD / -       | GRAB   | command grab throw, short range, no tech       |
// | bellyBounce     | ^S    |  7 |  8  |  26 |  95 | KD+launch/18 | mid    | anti-air belly, strike-invuln 0-8              |
// | yokozunaThunder | super |  8 | 40  |  26 | 4x45+130 | KD      | mid    | armored charge, invuln 0-8, wall bounce, 2 bars|
// EX (heavy held, 1 bar): tsuppari 7 hits, charge 2 armor hits, throw 190 dmg + range, belly longer invuln.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

MoveDef _tsuppari(bool ex) => MoveDef('tsuppari', cls: MoveClass.special, startup: 11, active: ex ? 28 : 20, recovery: 24,
    windows: rapidWindows(start: 11, hits: ex ? 7 : 5, gap: 4, box: const Box(1000, 6000, 10500, 6000), damage: ex ? 24 : 22,
        finisherDamage: ex ? 50 : 40, stop: 3),
    chip: 6, hitstun: 16, blockstun: 12, hitstop: 8, pushback: 1100, wallBounce: true, knockdown: true, meterGain: 60,
    cancelMask: cancelSuperOnly, cancelBlock: false);

MoveDef _dohyoCharge(bool ex) => MoveDef('dohyoCharge', cls: MoveClass.special, startup: 20, active: 16, recovery: 22,
    box: const Box(1000, 0, 10500, 16000), damage: ex ? 90 : 70, chip: 12, hitstun: 22, blockstun: 14, hitstop: 11,
    pushback: 1400, wallBounce: true, knockdown: true, juggleCost: 3, meterGain: 60, cancelMask: cancelSuperOnly,
    cancelBlock: false, steps: [MoveStep(8, vx: ex ? 950 : 850), const MoveStep(36, vx: 0)],
    armorStart: 8, armorEnd: 24, armorHits: ex ? 2 : 1);

MoveDef _uwatenage(bool ex) => MoveDef('uwatenage', cls: MoveClass.special, startup: 7, active: 2, recovery: 34,
    box: Box(0, 2000, ex ? 6500 : 5500, 12000), damage: ex ? 190 : 140, hitstop: 8, pushback: 900,
    height: BlockHeight.unblockable, knockdown: true, launch: 700, grab: true, groundedOnly: true, meterGain: 90);

MoveDef _bellyBounce(bool ex) => MoveDef('bellyBounce', cls: MoveClass.special, startup: 7, active: 8, recovery: 26,
    box: const Box(-500, 8000, 10500, 17000), damage: ex ? 115 : 95, chip: 12, blockstun: 18, hitstop: 11, pushback: 1000,
    knockdown: true, launch: ex ? 1000 : 900, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    invuln: [Invuln(0, ex ? 12 : 8, Inv.strike)]);

MoveDef _yokozunaThunder() => MoveDef('yokozunaThunder', cls: MoveClass.superMove, startup: 8, active: 40, recovery: 26,
    windows: rapidWindows(start: 14, hits: 5, gap: 4, box: const Box(1000, 0, 11000, 16000), damage: 45, finisherDamage: 130),
    hitstun: 18, blockstun: 14, hitstop: 9, pushback: 1200, wallBounce: true, knockdown: true, launch: 700, juggleCost: 0,
    scaleFloor: 40, steps: const [MoveStep(6, vx: 1100), MoveStep(36, vx: 0)],
    invuln: const [Invuln(0, 8, Inv.all)], armorStart: 8, armorEnd: 40, armorHits: 2);

CharacterDef buildBoom() => CharacterDef(
      id: 15, key: 'boom', name: 'BOOM', kind: 'human', maxHealth: 1300,
      walkFwd: 220, walkBack: 180, dashSpeed: 650, dashFrames: 20, backdashSpeed: 550, backdashFrames: 22,
      jumpVy: 1550, jumpVx: 250, gravity: 90, rollSpeed: 1050, rollBackSpeed: 800, pushHalf: 5000,
      standHurt: const [Box(-5000, 0, 10000, 19000)], crouchHurt: const [Box(-5000, 0, 10000, 11500)],
      airHurt: const [Box(-5000, 1500, 10000, 16000)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 110, lightStartup: 2, heavyStartup: 2)),
        _tsuppari(false), // 10
        _dohyoCharge(false), // 11
        _uwatenage(false), // 12
        _bellyBounce(false), // 13
        _yokozunaThunder(), // 14
        _tsuppari(true), // 15
        _dohyoCharge(true), // 16
        _uwatenage(true), // 17
        _bellyBounce(true), // 18
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
