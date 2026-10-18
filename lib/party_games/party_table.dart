import 'package:flutter/widgets.dart';

import '../data/matches_store.dart';
import '../models/chat_match.dart';
import 'imposter_table.dart';
import 'liars_dice_table.dart';
import 'race_table.dart';

/// A party game's table, whichever game it is. What the game screen shows in
/// place of a turn game's board, plates and tools.
class PartyTable extends StatelessWidget {
  const PartyTable({
    super.key,
    required this.match,
    required this.controller,
    required this.viewerId,
    this.enabled = true,
    this.stage = false,
  });

  final ChatMatch match;
  final MatchController controller;
  final String viewerId;

  /// False while the 3-2-1 before the start runs.
  final bool enabled;

  /// The middle of the desktop stage ([partyStageFor]): the players and the
  /// history move to the panel beside it, and the keys come alive.
  final bool stage;

  @override
  Widget build(BuildContext context) => switch (match.game) {
    'liarsdice' => LiarsDiceTable(
      match: match,
      controller: controller,
      viewerId: viewerId,
      enabled: enabled,
      stage: stage,
    ),
    'imposter' => ImposterTable(
      match: match,
      controller: controller,
      viewerId: viewerId,
      enabled: enabled,
      stage: stage,
    ),
    'race' => RaceTable(
      match: match,
      controller: controller,
      viewerId: viewerId,
      enabled: enabled,
      stage: stage,
    ),
    _ => const SizedBox.shrink(),
  };
}

/// A party table split for the desktop stage (`GameStage` in
/// `game_layout_shell.dart`): [board] goes in the stage's square, at
/// [aspectRatio], and [panel] beside it.
class PartyStage {
  const PartyStage({
    required this.board,
    required this.panel,
    this.aspectRatio = 1,
  });

  final Widget board;
  final Widget panel;
  final double aspectRatio;
}

/// The desktop stage for [match]'s party game. [board] keeps its state for as
/// long as the stage is up; flipping back to the phone column (the window got
/// small) starts the table's local state (the bid picker, a typed clue) over.
PartyStage partyStageFor({
  required ChatMatch match,
  required MatchController controller,
  required String viewerId,
  bool enabled = true,
}) => PartyStage(
  board: PartyTable(
    match: match,
    controller: controller,
    viewerId: viewerId,
    enabled: enabled,
    stage: true,
  ),
  panel: switch (match.game) {
    'liarsdice' => LiarsDiceStagePanel(
      match: match,
      controller: controller,
      viewerId: viewerId,
    ),
    'imposter' => ImposterStagePanel(
      match: match,
      controller: controller,
      viewerId: viewerId,
    ),
    'race' => RaceStagePanel(match: match, viewerId: viewerId),
    _ => const SizedBox.shrink(),
  },
);
