// GALE - eagle, air fighter. 920 health, floaty (gravity 70, high jump), AIR DASH (double-tap in the air).
//
// Movement: walk 3.0/2.6 px/f, dash 9.5 px/f x15f, backdash 8.5 px/f x17f, jump 20, air dash 13 px/f x14f (once per jump).
// Normals: damage 95%, reach 110%.
//
// | move        | input | st | act | rec | dmg | hit/blk stun | height | notes                                              |
// |-------------|-------|----|-----|-----|-----|--------------|--------|----------------------------------------------------|
// | wingGust    |  S    | 14 |  -  |  26 |  48 | 18 / 12      | mid    | tall gust 4.8 px/f, chip 8; EX: wide, 2 hits       |
// | talonGlide  | >S    | 14 | 10  |  12 |  85 | KD / 14      | mid    | hops, glides level (frames 8-17), then dives       |
// | wingSweep   |  vS   | 11 |  5  |  22 |  62 | KD / 12      | LOW    | long low wing sweep, low profile                   |
// | skyDive     |  ^S   | 26 | 14  |  12 | 110 | KD / 16      | HIGH   | rockets up, dive kick from above, 12f landing      |
// | stormTalon  | super | 12 | 28  |  24 | 7x38+130 | KD      | mid    | whirlwind + gust, invuln 0-12, wall bounce, 2 bars |
// EX: gust wide/fast/2 hits, glide faster + harder, sweep bigger, dive faster + harder.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const int _gravity = 70;

const ProjectileDef _gust = ProjectileDef('Wing Gust', w: 6000, h: 14000, vx: 480, life: 70, damage: 48, chip: 8, hitstun: 18,
    blockstun: 12, hitstop: 8, pushback: 600, priority: 1);
const ProjectileDef _gustEx = ProjectileDef('Wing Gust EX', w: 8000, h: 16000, vx: 640, life: 70, hits: 2, damage: 42,
    chip: 10, hitstun: 18, blockstun: 12, hitstop: 8, pushback: 700, priority: 2);
const ProjectileDef _storm = ProjectileDef('Storm Gust', w: 9000, h: 18000, vx: 700, life: 80, damage: 80, chip: 12, hitstun: 20,
    blockstun: 14, hitstop: 9, pushback: 800, knockdown: true, priority: 2);

MoveDef _wingGust(bool ex) => MoveDef('wingGust', cls: MoveClass.special, startup: ex ? 11 : 14, active: 0, recovery: ex ? 22 : 26,
    projectiles: [ProjSpawn(ex ? 10 : 13, ex ? 1 : 0, 6000, 1500)], meterGain: 60);

MoveDef _talonGlide(bool ex) => MoveDef('talonGlide', cls: MoveClass.special, startup: ex ? 11 : 14, active: 10, recovery: 12,
    box: const Box(1500, 0, 9000, 10000), damage: ex ? 105 : 85, chip: 12, hitstun: 20, blockstun: 14, hitstop: 10,
    pushback: 600, knockdown: true, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [
      const MoveStep(2, vx: 600, vy: 1200),
      // Level glide: vy = gravity each frame cancels the pull of the physics step.
      for (var f = 8; f < 18; f++) MoveStep(f, vx: ex ? 1250 : 950, vy: _gravity),
      const MoveStep(18, vx: 600, vy: -500),
    ],
    airborne: true, landRecovery: 10);

MoveDef _wingSweep(bool ex) => MoveDef('wingSweep', cls: MoveClass.special, startup: ex ? 8 : 11, active: 5, recovery: 22,
    box: Box(1000, 0, ex ? 15500 : 13500, 3500), damage: ex ? 80 : 62, chip: 8, blockstun: 12, hitstop: 9, pushback: 500,
    height: BlockHeight.low, knockdown: true, meterGain: 60, pose: Pose.crouch, hurt: const [Box(-5000, 0, 10000, 7500)],
    cancelMask: cancelSuperOnly, cancelBlock: false, steps: const [MoveStep(4, vx: 500), MoveStep(14, vx: 0)]);

MoveDef _skyDive(bool ex) => MoveDef('skyDive', cls: MoveClass.special, startup: ex ? 22 : 26, active: 14, recovery: 12,
    box: const Box(1000, 0, 8000, 10000), damage: ex ? 135 : 110, chip: 14, blockstun: 16, hitstop: 11, pushback: 700,
    height: BlockHeight.high, knockdown: true, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [const MoveStep(3, vx: 250, vy: 2300), MoveStep(ex ? 20 : 24, vx: ex ? 1000 : 800, vy: -2000)],
    airborne: true, landRecovery: 12);

MoveDef _stormTalon() => MoveDef('stormTalon', cls: MoveClass.superMove, startup: 12, active: 28, recovery: 24,
    windows: rapidWindows(start: 12, hits: 7, gap: 4, box: const Box(-4000, 0, 16000, 17000), damage: 38, finisherDamage: 130),
    projectiles: const [ProjSpawn(12, 2, 6000, 1500)],
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 600, knockdown: true, wallBounce: true, launch: 800, juggleCost: 0,
    scaleFloor: 40, invuln: const [Invuln(0, 12, Inv.all)]);

CharacterDef buildGale() => CharacterDef(
      id: 11, key: 'gale', name: 'GALE', kind: 'animal', maxHealth: 920,
      walkFwd: 300, walkBack: 260, dashSpeed: 950, dashFrames: 15, backdashSpeed: 850, backdashFrames: 17,
      jumpVy: 2000, jumpVx: 420, gravity: _gravity, airDashSpeed: 1300, airDashFrames: 14, pushHalf: 3200,
      standHurt: const [Box(-3200, 0, 6400, 16500)], crouchHurt: const [Box(-3200, 0, 6400, 9500)],
      airHurt: const [Box(-3200, 1500, 6400, 13500)],
      moves: [
        ...sharedNormals(const NormalTweaks(dmgPct: 95, reachPct: 110)),
        _wingGust(false), // 10 neutral
        _talonGlide(false), // 11 forward
        _wingSweep(false), // 12 down
        _skyDive(false), // 13 up
        _stormTalon(), // 14 super
        _wingGust(true), // 15
        _talonGlide(true), // 16
        _wingSweep(true), // 17
        _skyDive(true), // 18
      ],
      projectiles: const [_gust, _gustEx, _storm],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
