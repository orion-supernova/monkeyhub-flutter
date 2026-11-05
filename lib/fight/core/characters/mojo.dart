// MOJO - monkey trickster with a bo staff. 1000 health, fast, long normals.
//
// Movement: walk 3.6/3.0 px/f, dash 10 px/f x15f, backdash 9 px/f x17f, jump 19/-.
// Normals: damage 100%, staff reach +15%, heavy +1f startup.
//
// | move            | input | st | act | rec | dmg | hit/blk stun | height | notes                                        |
// |-----------------|-------|----|-----|-----|-----|--------------|--------|----------------------------------------------|
// | Staff Vault     |  S    | 22 |  8  |  14 |  80 | 18 / 12      | mid    | pole-vaults over, re-aims mid-air (cross-up) |
// | Spin Sweep      | >S    |  9 | 11  |  22 | 32+32+50 | 16 / 12 | mid    | 3-hit spinning staff, ender knocks down      |
// | Banana Peel     | vS    | 12 |  -  |  22 |  40 | trip (KD)    | trap   | places 1 trap (10 s), a new one replaces it  |
// | Canopy Dive     | ^S    | 32 | 28  |  10 | 100 | KD / 16      | HIGH   | leaps high, dives diagonally, 12f landing    |
// | Jungle Fury     | super | 10 | 28  |  22 | 7x45+110 | KD      | mid    | staff extends (190 px), invuln 0-10, 2 bars  |
// EX: Vault faster + harder, Spin Sweep 4 hits, Peel trips harder, Dive faster, all +damage.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const TrapDef _peel = TrapDef('Banana Peel', w: 6000, h: 3000, life: 600, arm: 10, kind: TrapKind.trip, damage: 40);

MoveDef _staffVault(bool ex) => MoveDef('staffVault', cls: MoveClass.special, startup: ex ? 18 : 22, active: 8, recovery: 14,
    box: const Box(1000, 2000, 8500, 9000), damage: ex ? 95 : 80, chip: 8, hitstun: 18, blockstun: 12, hitstop: 9, pushback: 500,
    meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [MoveStep(5, vx: ex ? 1000 : 800, vy: ex ? 1450 : 1500), MoveStep(ex ? 16 : 20, faceOpponent: true)],
    airborne: true, landRecovery: 8);

MoveDef _spinSweep(bool ex) => MoveDef('spinSweep', cls: MoveClass.special, startup: 9, active: ex ? 15 : 11, recovery: 22,
    windows: rapidWindows(start: 9, hits: ex ? 4 : 3, gap: 4, box: const Box(0, 1000, 12500, 6000), damage: ex ? 36 : 32,
        finisherDamage: ex ? 60 : 50, stop: 3),
    chip: 6, hitstun: 16, blockstun: 12, hitstop: 9, pushback: 600, knockdown: true, meterGain: 60,
    cancelMask: cancelSuperOnly, cancelBlock: false, steps: const [MoveStep(6, vx: 450), MoveStep(26, vx: 0)]);

MoveDef _bananaPeel(bool ex) => MoveDef('bananaPeel', cls: MoveClass.special, startup: ex ? 9 : 12, active: 0, recovery: 22,
    traps: [TrapSpawn(ex ? 7 : 10, 0, ex ? 18000 : 12000)], pose: Pose.crouch);

MoveDef _canopyDive(bool ex) => MoveDef('canopyDive', cls: MoveClass.special, startup: 32, active: 28, recovery: 10,
    box: const Box(1500, 0, 8000, 9000), damage: ex ? 120 : 100, chip: 14, blockstun: 16, hitstop: 10, pushback: 700,
    height: BlockHeight.high, knockdown: true, juggleCost: 3, meterGain: 70, cancelMask: cancelSuperOnly,
    cancelBlock: false,
    steps: [const MoveStep(4, vx: 300, vy: 2300), MoveStep(ex ? 26 : 30, vx: ex ? 1200 : 900, vy: -1700)],
    airborne: true, landRecovery: 12);

MoveDef _jungleFury() => MoveDef('jungleFury', cls: MoveClass.superMove, startup: 10, active: 28, recovery: 22,
    windows: rapidWindows(start: 10, hits: 8, gap: 4, box: const Box(0, 0, 19000, 15000), damage: 45, finisherDamage: 110),
    hitstun: 16, blockstun: 14, hitstop: 8, pushback: 700, knockdown: true, launch: 800, juggleCost: 0, scaleFloor: 40,
    steps: const [MoveStep(10, vx: 0)], invuln: const [Invuln(0, 10, Inv.all)]);

CharacterDef buildMojo() => CharacterDef(
      id: 1, key: 'mojo', name: 'MOJO', kind: 'animal', maxHealth: 1000,
      walkFwd: 360, walkBack: 300, dashSpeed: 1000, dashFrames: 15, backdashSpeed: 900, backdashFrames: 17,
      jumpVy: 1900, jumpVx: 450, gravity: 90, pushHalf: 3200,
      standHurt: const [Box(-3200, 0, 6400, 16000)], crouchHurt: const [Box(-3200, 0, 6400, 9500)],
      airHurt: const [Box(-3200, 1500, 6400, 13500)],
      moves: [
        ...sharedNormals(const NormalTweaks(reachPct: 115, heavyStartup: 1)),
        _staffVault(false), // 10
        _spinSweep(false), // 11
        _bananaPeel(false), // 12
        _canopyDive(false), // 13
        _jungleFury(), // 14
        _staffVault(true), // 15
        _spinSweep(true), // 16
        _bananaPeel(true), // 17
        _canopyDive(true), // 18
      ],
      traps: const [_peel],
      specials: const [10, 11, 12, 13],
      exSpecials: const [15, 16, 17, 18],
      superMove: 14,
    );
