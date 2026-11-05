import 'dart:ui';

import '../../../core/core.dart';
import '../art_common.dart';
import '../camera.dart';
import '../kai_rig.dart';
import '../poser.dart' show MoveAnim;

/// One fighter's art beyond the original four (KAI, MOJO, TANK, NYX).
///
/// Every place that used to switch on a character id falls back to the
/// [castArt] registry for ids it doesn't know, so a new fighter is ONE object
/// in its family file (`monkeys.dart`, `animals.dart`, `humans.dart`,
/// `legends.dart`) and touches no shared code. Its look must follow the
/// roster's rules: shaped parts on the shared skeleton, drawn through
/// [RigPainter.fill] / [RigPainter.limb] / [RigPainter.detail] so the three
/// looks (cartoon, painted, pixel) and silhouettes come for free.
abstract class CastArt {
  const CastArt();

  /// CharacterDef.id.
  int get id;

  /// Skeleton proportions. `dims.kind` must equal [id] (it keys [joints]).
  RigDims get dims;

  /// The standing idle the whole move set is built on.
  KPose get idle;

  /// Main and mirror-match outfits. The painter may use its own colour
  /// class; these feed shared code (portrait glow, silhouettes, fallbacks).
  KPalette get palette;
  KPalette get altPalette;

  /// Floats above the ground (adds [floatHeight] to `ry` in every grounded pose).
  bool get floats => false;
  double get floatHeight => 16;

  /// Width in rig units a portrait card must fit (wide characters larger).
  double get portraitWidth => 120;

  /// Extra joints from the pose, in rig space: a weapon (`sTip`/`sEnd`, the
  /// smear and hit point for blades, staffs, spears) and a two-hand point
  /// (`mid`). Null = none.
  ({Offset sTip, Offset sEnd, Offset mid})? joints(Joints j, KPose p) => null;

  /// Paints the fighter. The canvas is already at the pelvis (translated by
  /// `p.rx` and the ground placement, rotated by `p.spin`), +x forward, rig
  /// units; draw back limbs first, front last, like [RigPainter.fighter].
  void paint(RigPainter rp, Joints j, KPose p, bool alt, double frame);

  /// A pose from the generic (KAI-derived) state poses, adjusted for this
  /// character (e.g. weapon angle). Floating is applied by the caller.
  KPose rebase(KPose k) => k;

  /// Animation for one of this fighter's moves (by `m.name`: specials,
  /// supers, follow-ups, and any normal it draws differently). Null = the
  /// generic conversion of the shared normal / move class.
  MoveAnim? anim(MoveDef m, CharacterDef def) => null;

  /// (wind-up, strike, guard) for the portrait's "ready" flourish. Null =
  /// derived from the idle.
  (KPose, KPose, KPose)? readyPoses() => null;

  /// Draws one of this fighter's projectiles at the origin facing +x, in
  /// units where 1 ≈ 1 world px of the projectile box width / 31. Return
  /// false to use the default energy ball.
  bool paintProjectile(Canvas c, FightLook look, ProjectileDef def, int age) => false;

  /// Draws one of this fighter's traps at its ground point (origin), in the
  /// same units. Return false for the default.
  bool paintTrap(Canvas c, FightLook look, TrapDef def, int age, bool armed) => false;

  /// World-space effects tied to this fighter's current move (fire breath,
  /// beams, auras, shockwaves). Drawn after both fighters. Must derive
  /// everything from [s] (rollback can rewind it).
  void paintMoveFx(Canvas c, Size size, FightCamera cam, FightState s, int player, FightLook look) {}
}
