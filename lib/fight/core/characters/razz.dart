// RAZZ - mandrill showman, flashy rushdown. 1000 health, fast dashes, multi-hit specials.
//
// Movement: walk 3.4/2.8 px/f, dash 11 px/f x14f, backdash 9.5 px/f x16f, jump 18.5.
// Normals: damage 92%, light -1f startup (3f lights), reach 100%.
//
// | move        | input | st | act | rec | dmg | hit/blk stun | height | notes                                              |
// |-------------|-------|----|-----|-----|-----|--------------|--------|----------------------------------------------------|
// | showboat    |  S    | 12 |  3  |  30 |  20 | 16 / 10      | mid    | taunt flourish: +260 meter on contact (+130 block) |
// | rumbaRush   | >S    | 10 | 12  |  22 | 24+24+58 | KD / 11 | mid    | 15 px/f dash, 3 hits, ender knocks down            |
// | cartwheel   |  vS   | 11 | 12  |  18 | 28+50 | KD / 11    | LOW    | 2-hit low cartwheel, low profile                   |
// | risingFlip  |  ^S   |  5 | 10  |  22 | 40+70 | KD+launch/14 | mid    | 2-hit flip kick, strike-invuln 0-6, anti-air       |
// | grandFinale | super | 10 | 24  |  24 | 8x36+130 | KD      | mid    | dash-in flash, invuln 0-10, wall bounce, 2 bars    |
// EX: showboat 3 hits (+300 each), rumbaRush 4 hits faster, cartwheel 3 hits, flip invuln longer.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

MoveDef _showboat(bool ex) => MoveDef('showboat', cls: MoveClass.special, startup: ex ? 10 : 12, active: ex ? 9 : 3, recovery: ex ? 26 : 30,
    windows: ex
        ? const [
            HitWindow(10, 12, Box(1500, 4000, 8500, 11000), damage: 25, finisher: false, stop: 3),
            HitWindow(14, 16, Box(1500, 4000, 8500, 11000), damage: 25, finisher: false, stop: 3),
            HitWindow(18, 20, Box(1500, 4000, 8500, 11000), damage: 40),
          ]
        : const [HitWindow(12, 15, Box(1500, 4000, 8500, 11000))],
    damage: 20, hitstun: 16, blockstun: 10, hitstop: 8, pushback: 300, knockdown: ex, meterGain: ex ? 300 : 260,
    steps: const [MoveStep(3, vx: 300), MoveStep(12, vx: 0)]);

MoveDef _rumbaRush(bool ex) => MoveDef('rumbaRush', cls: MoveClass.special, startup: ex ? 8 : 10, active: ex ? 16 : 12, recovery: 22,
    windows: rapidWindows(start: ex ? 8 : 10, hits: ex ? 4 : 3, gap: 4, box: const Box(1000, 3000, 9500, 9000),
        damage: ex ? 28 : 24, finisherDamage: ex ? 66 : 58),
    chip: 6, hitstun: 16, blockstun: 11, hitstop: 8, pushback: 500, knockdown: true, meterGain: 60,
    cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [const MoveStep(2, vx: 1500), MoveStep(ex ? 14 : 16, vx: 400), MoveStep(26, vx: 0)]);

MoveDef _cartwheel(bool ex) => MoveDef('cartwheel', cls: MoveClass.special, startup: ex ? 8 : 11, active: ex ? 15 : 12, recovery: 18,
    windows: rapidWindows(start: ex ? 8 : 11, hits: ex ? 3 : 2, gap: ex ? 5 : 6, box: const Box(0, 0, 10500, 4000),
        damage: 28, finisherDamage: ex ? 60 : 50),
    chip: 6, hitstun: 16, blockstun: 11, hitstop: 8, pushback: 450, height: BlockHeight.low, knockdown: true, meterGain: 60,
    pose: Pose.crouch, hurt: const [Box(-5000, 0, 10000, 7000)], cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: const [MoveStep(4, vx: 950), MoveStep(22, vx: 0)]);

MoveDef _risingFlip(bool ex) => MoveDef('risingFlip', cls: MoveClass.special, startup: 5, active: 10, recovery: 22,
    windows: rapidWindows(start: 5, hits: 2, gap: 5, box: const Box(0, 4000, 8500, 17000), damage: ex ? 50 : 40,
        finisherDamage: ex ? 85 : 70),
    chip: 8, hitstun: 18, blockstun: 14, hitstop: 9, pushback: 300, knockdown: true, launch: ex ? 950 : 800, juggleCost: 3,
    meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false, steps: const [MoveStep(3, vx: 250, vy: 1600)],
    invuln: [Invuln(0, ex ? 10 : 6, Inv.strike)], airborne: true, landRecovery: 12);

MoveDef _grandFinale() => MoveDef('grandFinale', cls: MoveClass.superMove, startup: 10, active: 24, recovery: 24,
    windows: rapidWindows(start: 10, hits: 8, gap: 3, box: const Box(0, 2000, 12000, 15000), damage: 36, finisherDamage: 130),
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 700, knockdown: true, wallBounce: true, launch: 800, juggleCost: 0,
    scaleFloor: 40, steps: const [MoveStep(2, vx: 1300), MoveStep(10, vx: 500), MoveStep(34, vx: 0)],
    invuln: const [Invuln(0, 10, Inv.all)]);

CharacterDef buildRazz() => CharacterDef(
      id: 6, key: 'razz', name: 'RAZZ', kind: 'animal', maxHealth: 1000,
      walkFwd: 340, walkBack: 280, dashSpeed: 1100, dashFrames: 14, backdashSpeed: 950, backdashFrames: 16,
      jumpVy: 1850, jumpVx: 450, gravity: 90, pushHalf: 3300,
      standHurt: const [Box(-3300, 0, 6600, 16500)], crouchHurt: const [Box(-3300, 0, 6600, 9500)],
      airHurt: const [Box(-3300, 1500, 6600, 13500)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 92, lightStartup: -1)),
        _showboat(false), // 10 neutral
        _rumbaRush(false), // 11 forward
        _cartwheel(false), // 12 down
        _risingFlip(false), // 13 up
        _grandFinale(), // 14 super
        _showboat(true), // 15
        _rumbaRush(true), // 16
        _cartwheel(true), // 17
        _risingFlip(true), // 18
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
