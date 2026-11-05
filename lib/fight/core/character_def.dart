import 'move_def.dart';

/// Special slots: the direction held with the Special button.
class Slot {
  static const int neutral = 0;
  static const int forward = 1;
  static const int down = 2;
  static const int up = 3;
}

/// Indices of the shared normals at the head of every character's move list.
class N {
  static const int standLight = 0;
  static const int standLight2 = 1;
  static const int standFinisher = 2; // light, light, heavy target combo
  static const int standHeavy = 3;
  static const int crouchLight = 4;
  static const int crouchHeavy = 5; // sweep
  static const int jumpLight = 6;
  static const int jumpHeavy = 7; // overhead
  static const int fwdHeavy = 8; // overhead command normal
  static const int throwMove = 9;
  static const int count = 10;
}

class CharacterDef {
  final int id;
  final String key;
  final String name;
  final String kind; // human / animal / fantasy, for the roster UI
  final int maxHealth;
  final int walkFwd, walkBack;
  final int dashSpeed, dashFrames, backdashSpeed, backdashFrames;
  final int jumpVy, jumpVx, gravity, prejump;
  final int rollSpeed, rollBackSpeed;
  final int pushHalf; // pushbox half width
  final List<Box> standHurt, crouchHurt, airHurt;
  final List<MoveDef> moves; // shared normals first, then specials, EX, super, follow-ups
  final List<ProjectileDef> projectiles;
  final List<TrapDef> traps;
  final List<int> specials; // by Slot -> move index
  final List<int> exSpecials; // by Slot -> move index (-1 = none)
  final int superMove;

  const CharacterDef({
    required this.id,
    required this.key,
    required this.name,
    required this.kind,
    required this.maxHealth,
    required this.walkFwd,
    required this.walkBack,
    required this.dashSpeed,
    required this.dashFrames,
    required this.backdashSpeed,
    required this.backdashFrames,
    required this.jumpVy,
    required this.jumpVx,
    required this.gravity,
    this.prejump = 4,
    this.rollSpeed = 1250,
    this.rollBackSpeed = 950,
    required this.pushHalf,
    required this.standHurt,
    required this.crouchHurt,
    required this.airHurt,
    required this.moves,
    this.projectiles = const [],
    this.traps = const [],
    required this.specials,
    required this.exSpecials,
    required this.superMove,
  });
}
