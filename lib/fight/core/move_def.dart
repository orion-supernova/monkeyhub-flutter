// Data model for moves, projectiles and traps. Pure data, no behaviour.

/// Where a hit must be blocked. `high` = overhead (must stand-block),
/// `low` must be crouch-blocked, `mid` either, `unblockable` never.
enum BlockHeight { high, mid, low, unblockable }

enum MoveClass { normal, special, superMove, system }

/// Which hurtbox set a move uses while it plays (air always wins when y > 0).
enum Pose { stand, crouch }

/// Invulnerability bits.
class Inv {
  static const int strike = 1;
  static const int throwing = 2;
  static const int projectile = 4;
  static const int all = 7;
}

/// Axis aligned box. [x] is the left edge relative to the owner's origin when
/// facing right (mirrored when facing left), [y] is the bottom above ground.
class Box {
  final int x, y, w, h;
  const Box(this.x, this.y, this.w, this.h);
}

/// One hit of a move. Several windows give a multi-hit move; each window can
/// connect once per move.
class HitWindow {
  final int start; // first active frame (inclusive)
  final int end; // exclusive
  final Box box;
  final int damage; // -1 = use the move's damage
  final bool finisher; // knockdown/launch/pushback flags only apply on finishers
  final int stop; // -1 = use the move's hitstop
  const HitWindow(this.start, this.end, this.box, {this.damage = -1, this.finisher = true, this.stop = -1});
}

/// Per-frame movement: sets velocity (forward-relative vx) and/or vy on [frame].
class MoveStep {
  final int frame;
  final int? vx; // units/frame, positive = forward
  final int? vy;
  final bool faceOpponent; // re-aim facing at the opponent on this frame
  final int teleport; // 0 none, 1 = to the far side of the opponent
  final int tpOffset; // distance from the opponent after teleporting
  const MoveStep(this.frame, {this.vx, this.vy, this.faceOpponent = false, this.teleport = 0, this.tpOffset = 0});
}

class Invuln {
  final int start, end, mask;
  const Invuln(this.start, this.end, this.mask);
}

class ProjSpawn {
  final int frame;
  final int proj; // index into CharacterDef.projectiles
  final int x, y; // forward offset / height of the spawn point
  const ProjSpawn(this.frame, this.proj, this.x, this.y);
}

class TrapSpawn {
  final int frame;
  final int trap; // index into CharacterDef.traps
  final int x; // forward offset on the ground
  const TrapSpawn(this.frame, this.trap, this.x);
}

class MoveDef {
  final String name;
  final MoveClass cls;
  final int startup, active, recovery;
  final List<HitWindow> windows;
  final int damage, chip, hitstun, blockstun, hitstop, pushback;
  final BlockHeight height;
  final bool knockdown, wallBounce, groundBounce;
  final int launch; // upward velocity given to the victim (0 = none)
  final int juggleCost;
  final int scaleFloor;

  // Cancel rules. Classes it may cancel into (bit = 1 << MoveClass.index) and
  // under which contact; a chain sends a pressed button to another move.
  final int cancelMask;
  final bool cancelHit, cancelBlock, cancelWhiff;
  final int chainButton; // Inp bit, 0 = none
  final int chainInto; // move index

  final List<MoveStep> steps;
  final List<Invuln> invuln;
  final int armorStart, armorEnd, armorHits;
  final int meterGain;
  final List<ProjSpawn> projectiles;
  final List<TrapSpawn> traps;
  final int counterStart, counterEnd, counterMove; // counter stance (-1 = none)
  final bool grab; // throw / command grab: ignores block and strike invuln
  final bool techable;
  final bool groundedOnly; // cannot hit airborne victims
  final bool airborne; // ends on landing
  final int landRecovery;
  final Pose pose;
  final List<Box>? hurt; // overrides the pose hurtboxes while playing

  int get total => startup + active + recovery;

  MoveDef(
    this.name, {
    this.cls = MoveClass.normal,
    required this.startup,
    required this.active,
    required this.recovery,
    Box? box,
    List<HitWindow>? windows,
    this.damage = 0,
    this.chip = 0,
    this.hitstun = 0,
    this.blockstun = 0,
    this.hitstop = 8,
    this.pushback = 0,
    this.height = BlockHeight.mid,
    this.knockdown = false,
    this.wallBounce = false,
    this.groundBounce = false,
    this.launch = 0,
    this.juggleCost = 1,
    this.scaleFloor = comboScaleFloorDefault,
    this.cancelMask = 0,
    this.cancelHit = true,
    this.cancelBlock = true,
    this.cancelWhiff = false,
    this.chainButton = 0,
    this.chainInto = -1,
    this.steps = const [],
    this.invuln = const [],
    this.armorStart = 0,
    this.armorEnd = 0,
    this.armorHits = 0,
    this.meterGain = 0,
    this.projectiles = const [],
    this.traps = const [],
    this.counterStart = -1,
    this.counterEnd = -1,
    this.counterMove = -1,
    this.grab = false,
    this.techable = false,
    this.groundedOnly = false,
    this.airborne = false,
    this.landRecovery = 0,
    this.pose = Pose.stand,
    this.hurt,
  }) : windows = windows ?? (box != null ? [HitWindow(startup, startup + active, box)] : const []);

  /// Invulnerability mask at frame [f].
  int invAt(int f) {
    var m = 0;
    for (final i in invuln) {
      if (f >= i.start && f < i.end) m |= i.mask;
    }
    return m;
  }

  bool armorAt(int f) => armorHits > 0 && f >= armorStart && f < armorEnd;
  bool counterAt(int f) => counterMove >= 0 && f >= counterStart && f < counterEnd;
}

const int comboScaleFloorDefault = 30;

class ProjectileDef {
  final String name;
  final int w, h;
  final int vx, vy; // vx forward-relative
  final int life, hits;
  final int damage, chip, hitstun, blockstun, hitstop, pushback;
  final BlockHeight height;
  final bool knockdown;
  final int priority; // clash: higher survives
  final int meterGain;
  const ProjectileDef(
    this.name, {
    required this.w,
    required this.h,
    required this.vx,
    this.vy = 0,
    required this.life,
    this.hits = 1,
    required this.damage,
    this.chip = 0,
    required this.hitstun,
    required this.blockstun,
    this.hitstop = 8,
    this.pushback = 400,
    this.height = BlockHeight.mid,
    this.knockdown = false,
    this.priority = 1,
    this.meterGain = 40,
  });
}

enum TrapKind { trip, slow }

class TrapDef {
  final String name;
  final int w, h;
  final int life, arm; // lifetime, frames before it can trigger
  final TrapKind kind;
  final int damage;
  final int slowFrames;
  final bool consume;
  const TrapDef(
    this.name, {
    required this.w,
    required this.h,
    required this.life,
    this.arm = 12,
    required this.kind,
    this.damage = 0,
    this.slowFrames = 0,
    this.consume = true,
  });
}
