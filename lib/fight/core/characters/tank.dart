// TANK - rhino grappler. 1250 health, slow, big pushbox, hits hard.
//
// Movement: walk 2.4/1.9 px/f, dash 7 px/f x20f, backdash 6 px/f x22f, jump 16.5, roll 11 px/f.
// Normals: damage 110%, light +1f, heavy +2f startup, reach +5%.
//
// | move             | input | st | act | rec | dmg | hit/blk stun | height | notes                                      |
// |------------------|-------|----|-----|-----|-----|--------------|--------|--------------------------------------------|
// | Stampede         |  S    | 18 | 14  |  20 |  80 | 20 / 14      | mid    | charge, armor 6-22 absorbs 1 hit (50% dmg) |
// | Horn Toss        | >S    |  8 |  2  |  32 | 150 | KD / -       | GRAB   | command grab, close range, no tech, no block|
// | Earthquake       | vS    | 20 |  6  |  26 |  80 | KD / -       | unblk  | ground shockwave, grounded only: jump it   |
// | Rhino Uppercut   | ^S    |  6 |  6  |  24 | 110 | KD+launch/18 | mid    | armor 0-10 absorbs 1 hit, anti-air         |
// | Avalanche Slam   | super |  8 |  3  |  40 | 340 | KD           | GRAB   | command-grab super, invuln 0-8, 2 bars     |
// EX: Stampede 2 armor hits, Horn Toss 190 dmg + range, Earthquake wider, Uppercut 2 armor hits.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

MoveDef _stampede(bool ex) => MoveDef('stampede', cls: MoveClass.special, startup: 18, active: 14, recovery: 20,
    box: const Box(1000, 0, 9500, 16000), damage: ex ? 100 : 80, chip: 14, hitstun: 20, blockstun: 14, hitstop: 11,
    pushback: 800, meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [MoveStep(6, vx: ex ? 1050 : 900), const MoveStep(32, vx: 0)],
    armorStart: 6, armorEnd: 22, armorHits: ex ? 2 : 1);

MoveDef _hornToss(bool ex) => MoveDef('hornToss', cls: MoveClass.special, startup: 8, active: 2, recovery: 32,
    box: Box(0, 2000, ex ? 6500 : 5000, 12000), damage: ex ? 190 : 150, hitstop: 8, pushback: 700,
    height: BlockHeight.unblockable, knockdown: true, launch: 800, grab: true, groundedOnly: true, meterGain: 90,
    cancelMask: cancelSuperOnly, cancelBlock: false);

MoveDef _earthquake(bool ex) => MoveDef('earthquake', cls: MoveClass.special, startup: ex ? 17 : 20, active: 6, recovery: 26,
    box: Box(-3000, 0, ex ? 34000 : 28000, 3500), damage: ex ? 100 : 80, hitstop: 10, pushback: 500,
    height: BlockHeight.unblockable, knockdown: true, groundedOnly: true, meterGain: 60, cancelMask: cancelSuperOnly,
    cancelBlock: false);

MoveDef _rhinoUppercut(bool ex) => MoveDef('rhinoUppercut', cls: MoveClass.special, startup: 6, active: 6, recovery: 24,
    box: const Box(500, 8000, 7500, 17000), damage: ex ? 130 : 110, chip: 12, blockstun: 18, hitstop: 11, pushback: 400,
    knockdown: true, launch: 950, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    armorStart: 0, armorEnd: 10, armorHits: ex ? 2 : 1);

MoveDef _avalancheSlam() => MoveDef('avalancheSlam', cls: MoveClass.superMove, startup: 8, active: 3, recovery: 40,
    box: const Box(0, 2000, 6500, 12000), damage: 340, hitstop: 10, pushback: 600, height: BlockHeight.unblockable,
    knockdown: true, launch: 1000, grab: true, groundedOnly: true, scaleFloor: 50, invuln: const [Invuln(0, 8, Inv.all)]);

CharacterDef buildTank() => CharacterDef(
      id: 2, key: 'tank', name: 'TANK', kind: 'animal', maxHealth: 1250,
      walkFwd: 240, walkBack: 190, dashSpeed: 700, dashFrames: 20, backdashSpeed: 600, backdashFrames: 22,
      jumpVy: 1650, jumpVx: 300, gravity: 90, rollSpeed: 1100, rollBackSpeed: 850, pushHalf: 4500,
      standHurt: const [Box(-4500, 0, 9000, 19000)], crouchHurt: const [Box(-4500, 0, 9000, 11500)],
      airHurt: const [Box(-4500, 1500, 9000, 16000)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 110, lightStartup: 1, heavyStartup: 2, reachPct: 105)),
        _stampede(false), // 10
        _hornToss(false), // 11
        _earthquake(false), // 12
        _rhinoUppercut(false), // 13
        _avalancheSlam(), // 14
        _stampede(true), // 15
        _hornToss(true), // 16
        _earthquake(true), // 17
        _rhinoUppercut(true), // 18
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
