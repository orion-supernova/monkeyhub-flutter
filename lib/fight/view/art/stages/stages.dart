// The places Jungle Fist can be fought in: id, name and the two accent colours
// the picker thumbnails and cards use. The art for each lives next to this file.
import 'dart:math' as math;
import 'dart:ui';

import '../../../../l10n/generated/app_localizations.dart';

class FightStageDef {
  const FightStageDef(this.id, this.top, this.bottom, this.glow);
  final int id;

  /// Sky / floor tones for thumbnails and card gradients, and an accent.
  final Color top, bottom, glow;
}

const List<FightStageDef> kFightStages = [
  FightStageDef(0, Color(0xff3b1f5e), Color(0xffe2575a), Color(0xffffc77a)), // rooftop at sunset
  FightStageDef(1, Color(0xff0f3b3a), Color(0xffd98a3a), Color(0xff9dffb0)), // moss temple at dusk
  FightStageDef(2, Color(0xff1a0f3a), Color(0xff0b0716), Color(0xffff4fa0)), // neon alley in the rain
  FightStageDef(3, Color(0xff0b1a3a), Color(0xff9fd4ff), Color(0xff6dffc0)), // aurora shrine
  FightStageDef(4, Color(0xff6fb6e8), Color(0xffd9703a), Color(0xffffe9a8)), // canyon at noon
  FightStageDef(5, Color(0xff0a1230), Color(0xff1f3b5c), Color(0xffffd27a)), // moonlit deck
];

/// Picker value meaning "a different one each fight".
const int kFightStageRandom = -1;

/// Clamps a stored or received id to a real stage.
int fightStageOf(int id) => id >= 0 && id < kFightStages.length ? id : 0;

/// Turns a pick (which may be [kFightStageRandom]) into a real stage id.
int fightStageResolve(int pick, [math.Random? rng]) =>
    pick == kFightStageRandom ? (rng ?? math.Random()).nextInt(kFightStages.length) : fightStageOf(pick);

String fightStageName(AppLocalizations l10n, int id) => switch (fightStageOf(id)) {
  1 => l10n.fightStageTemple,
  2 => l10n.fightStageNeon,
  3 => l10n.fightStageAurora,
  4 => l10n.fightStageCanyon,
  5 => l10n.fightStageDeck,
  _ => l10n.fightStageRooftop,
};
