// The normals frame-data template every character shares (animations differ,
// numbers only move through [NormalTweaks]).
//
// Frames are 60 Hz. start = frames before the first active frame.
//
// | move            | st | act | rec | dmg | hitstun | blockstun | height | notes                          |
// |-----------------|----|-----|-----|-----|---------|-----------|--------|--------------------------------|
// | stand light     |  4 |  3  |   7 |  30 |   13    |    9      | mid    | chains to light, cancels       |
// | stand light 2   |  4 |  3  |   9 |  30 |   14    |   10      | mid    | chains to finisher on heavy    |
// | finisher (L-L-H)|  8 |  4  |  16 |  60 | knockdn |   14      | mid    | target combo ender             |
// | stand heavy     |  9 |  4  |  18 |  70 |   20    |   13      | mid    | cancels                        |
// | crouch light    |  5 |  3  |   9 |  25 |   12    |    8      | low    | cancels                        |
// | crouch heavy    | 10 |  4  |  22 |  55 | knockdn |   14      | low    | sweep, super-cancel only       |
// | jump light      |  4 |  8  |   6 |  35 |   14    |   10      | mid    | air, lands in 3                |
// | jump heavy      |  8 |  6  |   8 |  60 |   20    |   14      | HIGH   | overhead, lands in 4           |
// | fwd + heavy     | 20 |  4  |  20 |  65 |   22    |   12      | HIGH   | slow overhead command normal   |
// | throw (L+H)     |  5 |  2  |  28 | 110 | knockdn |    -      | unblk  | 7f tech window, ground only    |

import '../character_def.dart';
import '../input.dart';
import '../move_def.dart';

const int _cancelSpecialSuper = (1 << 1) | (1 << 2); // MoveClass.special | superMove
const int _cancelSuper = 1 << 2;

class NormalTweaks {
  final int dmgPct; // damage scale in percent
  final int lightStartup, heavyStartup; // frame deltas
  final int reachPct; // hitbox width scale
  const NormalTweaks({this.dmgPct = 100, this.lightStartup = 0, this.heavyStartup = 0, this.reachPct = 100});
}

Box _b(NormalTweaks t, int x, int y, int w, int h) => Box(x, y, w * t.reachPct ~/ 100, h);
int _d(NormalTweaks t, int v) => v * t.dmgPct ~/ 100;

List<MoveDef> sharedNormals([NormalTweaks t = const NormalTweaks()]) {
  final ls = 4 + t.lightStartup, hs = 9 + t.heavyStartup;
  return [
    // 0 stand light
    MoveDef('standLight', startup: ls, active: 3, recovery: 7, box: _b(t, 2000, 9000, 6500, 3500),
        damage: _d(t, 30), hitstun: 13, blockstun: 9, hitstop: 7, pushback: 450, meterGain: 30,
        cancelMask: _cancelSpecialSuper, chainButton: Inp.light, chainInto: N.standLight2),
    // 1 stand light 2
    MoveDef('standLight2', startup: ls, active: 3, recovery: 9, box: _b(t, 2000, 9000, 7000, 3500),
        damage: _d(t, 30), hitstun: 14, blockstun: 10, hitstop: 7, pushback: 500, meterGain: 30,
        cancelMask: _cancelSpecialSuper, chainButton: Inp.heavy, chainInto: N.standFinisher),
    // 2 target-combo finisher
    MoveDef('standFinisher', startup: 8 + t.heavyStartup, active: 4, recovery: 16, box: _b(t, 2000, 8000, 9500, 5000),
        damage: _d(t, 60), blockstun: 14, hitstop: 11, pushback: 700, knockdown: true, meterGain: 60,
        cancelMask: _cancelSpecialSuper),
    // 3 stand heavy
    MoveDef('standHeavy', startup: hs, active: 4, recovery: 18, box: _b(t, 2000, 8000, 10000, 5500),
        damage: _d(t, 70), hitstun: 20, blockstun: 13, hitstop: 11, pushback: 800, meterGain: 60,
        cancelMask: _cancelSpecialSuper),
    // 4 crouch light
    MoveDef('crouchLight', startup: 5 + t.lightStartup, active: 3, recovery: 9, box: _b(t, 2000, 0, 7500, 3500),
        damage: _d(t, 25), hitstun: 12, blockstun: 8, hitstop: 7, pushback: 400, height: BlockHeight.low,
        pose: Pose.crouch, meterGain: 25, cancelMask: _cancelSpecialSuper),
    // 5 crouch heavy (sweep)
    MoveDef('crouchHeavy', startup: 10 + t.heavyStartup, active: 4, recovery: 22, box: _b(t, 2000, 0, 12000, 3500),
        damage: _d(t, 55), blockstun: 14, hitstop: 10, pushback: 600, height: BlockHeight.low, knockdown: true,
        pose: Pose.crouch, meterGain: 50, cancelMask: _cancelSuper),
    // 6 jump light
    MoveDef('jumpLight', startup: 4, active: 8, recovery: 6, box: _b(t, 1500, 0, 8000, 8000),
        damage: _d(t, 35), hitstun: 14, blockstun: 10, hitstop: 8, pushback: 400, airborne: true,
        landRecovery: 3, meterGain: 30),
    // 7 jump heavy (overhead)
    MoveDef('jumpHeavy', startup: 8, active: 6, recovery: 8, box: _b(t, 1000, 0, 9500, 10000),
        damage: _d(t, 60), hitstun: 20, blockstun: 14, hitstop: 10, pushback: 500, height: BlockHeight.high,
        airborne: true, landRecovery: 4, juggleCost: 2, meterGain: 50),
    // 8 forward heavy (slow overhead)
    MoveDef('fwdHeavy', startup: 20, active: 4, recovery: 20, box: _b(t, 3000, 6000, 8500, 9000),
        damage: _d(t, 65), hitstun: 22, blockstun: 12, hitstop: 10, pushback: 700, height: BlockHeight.high,
        steps: const [MoveStep(10, vx: 250), MoveStep(24, vx: 0)], meterGain: 50),
    // 9 throw
    MoveDef('throw', cls: MoveClass.system, startup: 5, active: 2, recovery: 28, box: _b(t, 0, 2000, 5500, 12000),
        damage: _d(t, 110), hitstop: 0, pushback: 900, height: BlockHeight.unblockable, knockdown: true,
        grab: true, techable: true, groundedOnly: true, meterGain: 80),
  ];
}


/// Evenly spaced hits for multi-hit moves: [hits] windows starting at [start],
/// one every [gap] frames, the last one a finisher worth [finisherDamage].
List<HitWindow> rapidWindows({
  required int start,
  required int hits,
  required int gap,
  required Box box,
  required int damage,
  required int finisherDamage,
  int stop = 3,
  Box? finisherBox,
}) {
  final out = <HitWindow>[];
  for (var k = 0; k < hits; k++) {
    final last = k == hits - 1;
    final a = start + k * gap;
    out.add(HitWindow(a, a + gap, last && finisherBox != null ? finisherBox : box,
        damage: last ? finisherDamage : damage, finisher: last, stop: last ? -1 : stop));
  }
  return out;
}

const List<Box> stdStandHurt = [Box(-3500, 0, 7000, 17000)];
const List<Box> stdCrouchHurt = [Box(-3500, 0, 7000, 10000)];
const List<Box> stdAirHurt = [Box(-3500, 1500, 7000, 14000)];

const int cancelSuperOnly = 1 << 2;
