// GOLEM - legend (she), stone giant. Super armor. 1400 health, slowest walk, huge pushbox.
//
// Movement: walk 2.0/1.6 px/f, dash 6 px/f x22f, backdash 5 px/f x24f, jump 15 (airtime ~33f), roll 10 px/f.
// Normals: damage 115%, light +2f, heavy +3f startup, reach +10%. standHeavy (idx 3) is ARMORED: frames 5-13
// absorb 1 hit (replaces the template move; same numbers otherwise).
//
// | move            | input | st | act | rec | dmg | hit/blk stun | height | notes                                          |
// |-----------------|-------|----|-----|-----|-----|--------------|--------|------------------------------------------------|
// | rockThrow       |  S    | 22 |  -  |  30 | 100 | KD / 14      | mid    | boulder 3.8 px/f, priority 3, armor 8-20 on    |
// |                 |       |    |     |     |     |              |        | the wind-up (1 hit)                            |
// | stoneShoulder   | >S    | 20 |  8  |  26 |  95 | 22 / 15      | mid    | slow armored lunge, armor 4-22 (1 hit)         |
// | groundSlam      | vS    | 22 |  10 |  28 | 60+50 | KD / 14    | LOW    | fist then shockwave, 330 px, grounded only     |
// |                 |       |    |     |     |     |              |        | (jump it), armor 6-20 (1 hit)                  |
// | crushGrab       | ^S    |  9 |  2  |  36 | 160 | KD / -       | GRAB   | command grab, armor 0-9 (1 hit), no tech       |
// | cataclysm       | super | 20 | 16  |  40 | 150+140 | KD+launch | mid   | armored slam + stage-wide low shockwave        |
// EX (heavy held, 1 bar): throw 2-hit boulder, shoulder 2 armor hits, slam wider/faster, grab 210 + range.
//
// Approximation: "armored normals" is one armored normal (standHeavy); the rest are the shared template.

import '../character_def.dart';
import '../move_def.dart';
import 'shared_normals.dart';

const int _cancelSpecialSuper = (1 << 1) | (1 << 2);

const ProjectileDef _boulder = ProjectileDef('Boulder', w: 9000, h: 9000, vx: 380, life: 140, damage: 100, chip: 14,
    hitstun: 22, blockstun: 14, hitstop: 10, pushback: 700, knockdown: true, priority: 3);
const ProjectileDef _boulderEx = ProjectileDef('Boulder EX', w: 10500, h: 10500, vx: 480, life: 120, hits: 2, damage: 90,
    chip: 16, hitstun: 22, blockstun: 14, hitstop: 10, pushback: 800, knockdown: true, priority: 4);

// Armored standHeavy: same numbers as the shared template (dmg 115%, +3f startup).
MoveDef _armoredHeavy() => MoveDef('standHeavy', startup: 9 + 3, active: 4, recovery: 18,
    box: const Box(2000, 8000, 11000, 5500), damage: 70 * 115 ~/ 100, hitstun: 20, blockstun: 13, hitstop: 11, pushback: 800,
    meterGain: 60, cancelMask: _cancelSpecialSuper, armorStart: 5, armorEnd: 13, armorHits: 1);

MoveDef _rockThrow(bool ex) => MoveDef('rockThrow', cls: MoveClass.special, startup: 22, active: 0, recovery: 30,
    projectiles: [ProjSpawn(21, ex ? 1 : 0, 8000, 5000)], armorStart: 8, armorEnd: 20, armorHits: ex ? 2 : 1, meterGain: 60);

MoveDef _stoneShoulder(bool ex) => MoveDef('stoneShoulder', cls: MoveClass.special, startup: 20, active: 8, recovery: 26,
    box: const Box(1000, 0, 10500, 17000), damage: ex ? 120 : 95, chip: 14, hitstun: 22, blockstun: 15, hitstop: 11,
    pushback: 900, meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false,
    steps: [MoveStep(8, vx: ex ? 750 : 650), const MoveStep(28, vx: 0)], armorStart: 4, armorEnd: 22, armorHits: ex ? 2 : 1);

MoveDef _groundSlam(bool ex) => MoveDef('groundSlam', cls: MoveClass.special, startup: ex ? 18 : 22, active: 10, recovery: 28,
    windows: [
      HitWindow(ex ? 18 : 22, ex ? 22 : 26, const Box(1000, 0, 9000, 12000), damage: ex ? 70 : 60, finisher: false, stop: 4),
      HitWindow(ex ? 22 : 26, ex ? 28 : 32, Box(1000, 0, ex ? 38000 : 33000, 3500), damage: ex ? 60 : 50),
    ],
    chip: 10, hitstun: 20, blockstun: 14, hitstop: 10, pushback: 500, height: BlockHeight.low, knockdown: true,
    groundedOnly: true, meterGain: 60, cancelMask: cancelSuperOnly, cancelBlock: false,
    armorStart: 6, armorEnd: ex ? 18 : 20, armorHits: 1);

MoveDef _crushGrab(bool ex) => MoveDef('crushGrab', cls: MoveClass.special, startup: 9, active: 2, recovery: 36,
    box: Box(0, 2000, ex ? 7000 : 6000, 12000), damage: ex ? 210 : 160, hitstop: 8, pushback: 700,
    height: BlockHeight.unblockable, knockdown: true, launch: 700, grab: true, groundedOnly: true, meterGain: 90,
    armorStart: 0, armorEnd: 9, armorHits: 1);

MoveDef _cataclysm() => MoveDef('cataclysm', cls: MoveClass.superMove, startup: 20, active: 16, recovery: 40,
    windows: const [
      HitWindow(20, 24, Box(0, 0, 12000, 20000), damage: 150, finisher: false, stop: 6),
      HitWindow(28, 36, Box(-40000, 0, 80000, 6000), damage: 140),
    ],
    chip: 30, hitstun: 22, blockstun: 16, hitstop: 12, pushback: 400, height: BlockHeight.mid, knockdown: true, launch: 900,
    juggleCost: 0, scaleFloor: 50, invuln: const [Invuln(0, 8, Inv.all)], armorStart: 8, armorEnd: 28, armorHits: 2);

CharacterDef buildGolem() {
  final normals = sharedNormals(const NormalTweaks(dmgPct: 115, lightStartup: 2, heavyStartup: 3, reachPct: 110));
  normals[N.standHeavy] = _armoredHeavy();
  return CharacterDef(
    id: 19, key: 'golem', name: 'GOLEM', kind: 'fantasy', maxHealth: 1400,
    walkFwd: 200, walkBack: 160, dashSpeed: 600, dashFrames: 22, backdashSpeed: 500, backdashFrames: 24,
    jumpVy: 1500, jumpVx: 200, gravity: 90, rollSpeed: 1000, rollBackSpeed: 800, pushHalf: 5200,
    standHurt: const [Box(-5200, 0, 10400, 20000)], crouchHurt: const [Box(-5200, 0, 10400, 12500)],
    airHurt: const [Box(-5200, 1500, 10400, 17000)],
    moves: [
      ...normals,
      _rockThrow(false), // 10
      _stoneShoulder(false), // 11
      _groundSlam(false), // 12
      _crushGrab(false), // 13
      _cataclysm(), // 14
      _rockThrow(true), // 15
      _stoneShoulder(true), // 16
      _groundSlam(true), // 17
      _crushGrab(true), // 18
    ],
    projectiles: const [_boulder, _boulderEx],
    specials: const [10, 11, 12, 13],
    exSpecials: const [15, 16, 17, 18],
    superMove: 14,
  );
}
