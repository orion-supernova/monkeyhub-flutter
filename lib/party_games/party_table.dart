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
  });

  final ChatMatch match;
  final MatchController controller;
  final String viewerId;

  /// False while the 3-2-1 before the start runs.
  final bool enabled;

  @override
  Widget build(BuildContext context) => switch (match.game) {
    'liarsdice' => LiarsDiceTable(
      match: match,
      controller: controller,
      viewerId: viewerId,
      enabled: enabled,
    ),
    'imposter' => ImposterTable(
      match: match,
      controller: controller,
      viewerId: viewerId,
      enabled: enabled,
    ),
    'race' => RaceTable(
      match: match,
      controller: controller,
      viewerId: viewerId,
      enabled: enabled,
    ),
    _ => const SizedBox.shrink(),
  };
}
