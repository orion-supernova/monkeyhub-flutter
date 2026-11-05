// LUZ - human (she), luchadora. Aerial grappler. 1000 health, high jump, strong air game.
//
// Movement: walk 3.2/2.6 px/f, dash 8.5 px/f x16f, backdash 8 px/f x18f, jump 20 (airtime ~44f).
// Normals: damage 105%, heavy +1f startup.
//
// | move            | input | st | act | rec | dmg | hit/blk stun | height | notes                                          |
// |-----------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------------|
// | dropkick        |  S    | 14 | 10  |  18 |  75 | KD / 13      | mid    | leaping two-foot kick, lands in 8f             |
// | runningSplash   | >S    | 18 | 10  |  24 |  90 | KD / 14      | mid    | sprinting body splash, 10 px/f                 |
// | slideKick       | vS    |  9 | 10  |  22 |  55 | KD / 12      | LOW    | low profile slide, projectile-invuln 3-19      |
// | hurricanrana    | ^S    | 12 |  8  |  22 | 140 | KD / -       | GRAB   | JUMPING command grab (aerial), ground only    |
// | topRopeSwan     | super | 24 | 16  |  14 | 280 | KD+launch    | HIGH   | high-flying dive overhead, invuln 0-14, 2 bars |
// EX (heavy held, 1 bar): dropkick faster/harder, splash faster, slide faster/harder,
// hurricanrana faster + 190 dmg.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

MoveDef _dropkick(bool ex) => MoveDef('dropkick', cls: MoveClass.special, startup: ex ? 11 : 14, active: 10, recovery: 18,
    box: const Box(1500, 1500, 9500, 8000), damage: ex ? 100 : 75, chip: 10, hitstun: 18, blockstun: 13, hitstop: 10,
    pushback: 700, knockdown: true, juggleCost: 2, meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [MoveStep(ex ? 4 : 6, vx: ex ? 1150 : 950, vy: 700)], airborne: true, landRecovery: 8);

MoveDef _runningSplash(bool ex) => MoveDef('runningSplash', cls: MoveClass.special, startup: ex ? 14 : 18, active: 10, recovery: 24,
    box: const Box(1000, 0, 9500, 15000), damage: ex ? 110 : 90, chip: 12, hitstun: 20, blockstun: 14, hitstop: 11,
    pushback: 700, knockdown: true, juggleCost: 2, meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [MoveStep(ex ? 4 : 6, vx: ex ? 1200 : 1000), MoveStep(ex ? 24 : 28, vx: 0)]);

MoveDef _slideKick(bool ex) => MoveDef('slideKick', cls: MoveClass.special, startup: ex ? 6 : 9, active: 10, recovery: 22,
    box: const Box(1500, 0, 10000, 3500), damage: ex ? 75 : 55, chip: 8, blockstun: 12, hitstop: 9, pushback: 500,
    height: BlockHeight.low, knockdown: true, pose: Pose.crouch, hurt: const [Box(-6000, 0, 12000, 5500)],
    steps: [MoveStep(ex ? 2 : 3, vx: ex ? 1300 : 1100), MoveStep(ex ? 18 : 19, vx: 0)],
    invuln: const [Invuln(3, 19, Inv.projectile)], meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false);

// Jumping command grab: she launches herself, the grab box covers the air in front.
MoveDef _hurricanrana(bool ex) => MoveDef('hurricanrana', cls: MoveClass.special, startup: ex ? 9 : 12, active: 8, recovery: 22,
    box: const Box(0, -8000, 8000, 14000), damage: ex ? 190 : 140, hitstop: 8, pushback: 600,
    height: BlockHeight.unblockable, knockdown: true, grab: true, groundedOnly: true, meterGain: 90,
    steps: [MoveStep(4, vx: 600, vy: 1700)], airborne: true, landRecovery: 10);

MoveDef _topRopeSwan() => MoveDef('topRopeSwan', cls: MoveClass.superMove, startup: 24, active: 16, recovery: 14,
    box: const Box(-2000, -14000, 11000, 30000), damage: 280, chip: 30, hitstun: 24, blockstun: 16, hitstop: 12, pushback: 700,
    height: BlockHeight.high, knockdown: true, launch: 900, juggleCost: 0, scaleFloor: 50,
    steps: const [MoveStep(2, vx: 300, vy: 1700)], invuln: const [Invuln(0, 14, Inv.all)], airborne: true, landRecovery: 14);

CharacterDef buildLuz() => CharacterDef(
      id: 12, key: 'luz', name: 'LUZ', kind: 'human', maxHealth: 1000,
      walkFwd: 320, walkBack: 260, dashSpeed: 850, dashFrames: 16, backdashSpeed: 800, backdashFrames: 18,
      jumpVy: 2000, jumpVx: 450, gravity: 90, pushHalf: 3500,
      standHurt: stdStandHurt, crouchHurt: stdCrouchHurt, airHurt: stdAirHurt,
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 105, heavyStartup: 1)),
        _dropkick(false), // 10 neutral
        _runningSplash(false), // 11 forward
        _slideKick(false), // 12 down
        _hurricanrana(false), // 13 up
        _topRopeSwan(), // 14 super
        _dropkick(true), // 15
        _runningSplash(true), // 16
        _slideKick(true), // 17
        _hurricanrana(true), // 18
      ],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
