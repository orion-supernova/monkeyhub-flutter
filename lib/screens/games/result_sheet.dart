import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/games_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/score_row.dart' show PlayerFace;
import '../../widgets/sheet_kit.dart';
import 'leaderboard_standings.dart';

/// One finisher's whole result for today's [GameResult.game]: the time (or
/// the surrender) large, and under it what the row on the board leaves out —
/// mistakes, hints, the streak.
///
/// Behind a tap rather than on the row because a board of six friends each
/// carrying "2 mistakes · 1 hint" stops being a scoreboard. The time ranks;
/// the rest is for whoever is curious, and the footer says so in as many
/// words — mistakes are counted on the player's phone, so they are shown,
/// never sorted on.
Future<void> showResultSheet(
  BuildContext context, {
  required GameResult row,
  required String viewerId,
}) {
  HapticFeedback.selectionClick();
  return showAdaptiveSheet<void>(
    context,
    useSafeArea: true,
    builder: (_) => _ResultSheet(row: row, viewerId: viewerId),
  );
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.row, required this.viewerId});

  final GameResult row;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final standings = GamesStore.instance.standings;
    final isViewer = row.userId.isEmpty || row.userId == viewerId;
    final userId = isViewer ? viewerId : row.userId;
    final label = isViewer
        ? sentenceCaseOf(context, l10n.momentRailYouLabel)
        : row.name;
    final streak = standings.streakOf(userId, row.game);
    final mine = standings.mine[row.game];
    final compare = isViewer ? null : _comparison(context, mine);

    String count(int n) => n == 0
        ? sentenceCaseOf(context, l10n.resultSheetNone)
        : '$n';

    return SheetFrame(
      title: label,
      subtitle: l10n.resultSheetToday(
        sentenceCaseOf(context, leaderboardGameName(l10n, row.game)),
      ),
      showClose: true,
      padding: EdgeInsets.zero,
      scrollsUnderInset: true,
      child: ListView(
        shrinkWrap: true,
        padding: sheetListPadding(context),
        children: [
          SheetRise(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(
                  userId: userId,
                  label: label,
                  row: row,
                  line: compare,
                ),
                const SizedBox(height: 12),
                SheetGroup(
                  children: [
                    GroupedRow(
                      title: sentenceCaseOf(context, l10n.resultSheetMistakes),
                      icon: CupertinoIcons.xmark,
                      tone: TileTone.red,
                      value: count(row.mistakes),
                      chevron: false,
                    ),
                    GroupedRow(
                      title: sentenceCaseOf(context, l10n.resultSheetHints),
                      icon: CupertinoIcons.lightbulb,
                      tone: TileTone.orange,
                      value: count(row.hintsUsed),
                      chevron: false,
                    ),
                    GroupedRow(
                      title: sentenceCaseOf(context, l10n.resultSheetStreak),
                      icon: CupertinoIcons.flame_fill,
                      tone: TileTone.orange,
                      value: streak > 0
                          ? l10n.resultSheetStreakDays(streak)
                          : sentenceCaseOf(context, l10n.resultSheetNone),
                      chevron: false,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(
                    sentenceCaseOf(
                      context,
                      row.solved && row.hintsUsed > 0
                          ? '${l10n.resultSheetHintNoRecord} '
                              '${l10n.resultSheetFooter}'
                          : l10n.resultSheetFooter,
                    ),
                    style: groupedMetaStyle(theme)
                        .copyWith(color: theme.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "You were 0:12 faster" — only when both of you solved it. Never "you
  /// lost": the sheet is a friend's result, not a verdict on yours.
  String? _comparison(BuildContext context, GameResult? mine) {
    final l10n = AppLocalizations.of(context);
    final theirs = row.durationMs;
    final yours = mine?.durationMs;
    if (!row.solved || mine == null || !mine.solved) return null;
    if (theirs == null || yours == null) return null;
    final gap = (theirs - yours).abs();
    if (gap < 1000) return sentenceCaseOf(context, l10n.resultSheetSameTime);
    final time = formatGameTime(gap);
    return sentenceCaseOf(
      context,
      yours < theirs
          ? l10n.resultSheetYouFaster(time)
          : l10n.resultSheetTheyFaster(row.name, time),
    );
  }
}

/// The face and the number the board ranked them by — or "Gave up", which is
/// a result too.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.userId,
    required this.label,
    required this.row,
    required this.line,
  });

  final String userId;
  final String label;
  final GameResult row;
  final String? line;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final avatar = GamesStore.instance.standings.avatars[userId];
    return ClipRRect(
      borderRadius: BorderRadius.circular(groupedRadius(theme)),
      child: ColoredBox(
        color: sheetGroupFill(theme),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              PlayerFace(
                userId: userId,
                label: label,
                size: 56,
                storageId: avatar,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.solved
                          ? formatGameTime(row.durationMs)
                          : sentenceCaseOf(context, l10n.gameStatusGaveUp),
                      style: groupedHeaderStyle(theme).copyWith(
                        fontSize: row.solved ? 30 : 22,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: row.solved ? theme.ink : theme.inkMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (line != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        line!,
                        style: groupedMetaStyle(theme)
                            .copyWith(color: theme.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
