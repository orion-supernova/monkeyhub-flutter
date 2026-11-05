import 'package:flutter/foundation.dart';

/// How much decoration the fight draws, set by the frame-time governor
/// (lib/fight/view/fight_quality.dart), never by the player.
///
///  * [full]: everything (halftone, rim light, occlusion, every particle).
///  * [reduced]: no halftone, rim light or occlusion; fewer particles. The
///    look is the same look, a little plainer up close.
///  * [minimal]: flat fills with outlines, essential effects only. Only a
///    device that cannot hold 60 fps at [reduced] gets here.
enum FightQuality { full, reduced, minimal }

/// The current level. Art reads [fightQuality.value] while painting; the
/// governor lowers it, a new fight screen resets it to [FightQuality.full].
final ValueNotifier<FightQuality> fightQuality = ValueNotifier(FightQuality.full);

bool get fightQualityFull => fightQuality.value == FightQuality.full;
bool get fightQualityMinimal => fightQuality.value == FightQuality.minimal;
