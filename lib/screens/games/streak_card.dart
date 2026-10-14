import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/games_store.dart';
import '../../games/ranking.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
import '../../models/daily_game.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/odometer_number.dart';
import '../../widgets/score_row.dart';
import '../../widgets/sheet_kit.dart';
import 'leaderboard_standings.dart';

/// The viewer's OWN streaks, one column per game: a flame, the run, the
/// game. A tap shows that game's streak ranking ([showStreakSheet]): where
/// your run stands against your friends'.
///
/// The flame says where the run stands at a glance. Filled: today is in it.
/// Hollow: alive, but today's board is still to play, and it goes out at
/// midnight. Grey: no run on.
///
/// No "best" under each: a second number in every column read as a second
/// streak. The longest run lives in the ranking, under the list.
///
/// Static on purpose: no looping flame, no glass. The number rolls (an
/// [OdometerNumber]) when it changes, which is the one moment worth moving
/// for: coming back from the solve that made it one longer.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streaks,
    required this.viewerId,
  });

  /// Per game, null the code. A game never solved is absent: a grey zero.
  final Map<DailyGame?, GameStreak> streaks;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final atRisk = streaks.values.any((s) => s.atRisk);
    // Two rows, never one: ten games across one phone row left each name
    // about 37pt, and shrinking each to its own column set every name at a
    // different size. Half a row each, every name at one size.
    final games = kLeaderboardGames;
    final perRow = (games.length / 2).ceil();
    Widget column(DailyGame? game) => Expanded(
      child: _StreakColumn(
        game: game,
        streak: streaks[game],
        onTap: () => showStreakSheet(
          context,
          game: game,
          viewerId: viewerId,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
          child: ColoredBox(
            color: groupedFill(theme),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              child: Column(
                children: [
                  for (var r = 0; r < games.length; r += perRow)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = r; i < r + perRow; i++)
                          if (i < games.length)
                            column(games[i])
                          else
                            const Spacer(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (atRisk)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              sentenceCaseOf(context, l10n.streakAtRiskFooter),
              style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
            ),
          ),
      ],
    );
  }
}

class _StreakColumn extends StatelessWidget {
  const _StreakColumn({
    required this.game,
    required this.streak,
    required this.onTap,
  });

  final DailyGame? game;
  final GameStreak? streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = streak?.current ?? 0;
    final today = streak?.today ?? false;
    final flame = streakColor(theme);
    final name = leaderboardGameName(l10n, game);

    return SpringPress(
      onTap: onTap,
      scale: PressSpec.scaleSmall,
      focusRadius: theme.radiusMd,
      semanticLabel: '$name, ${l10n.streakDays(current)}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                current > 0 && today
                    ? CupertinoIcons.flame_fill
                    : CupertinoIcons.flame,
                size: 22,
                color: current > 0
                    ? flame
                    : theme.inkMuted.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 4),
              OdometerNumber(
                value: current,
                style: groupedHeaderStyle(theme).copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: current > 0 ? theme.ink : theme.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              // One size for every name; a long one ("Mayın tarlası")
              // takes a second line rather than shrinking alone.
              Text(
                sentenceCaseOf(context, name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: groupedMetaStyle(theme).copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.inkSoft,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One game's streak ranking: you and your friends, longest run first, with
/// your longest ever under it. What a tap on a streak column opens.
Future<void> showStreakSheet(
  BuildContext context, {
  required DailyGame? game,
  required String viewerId,
}) {
  HapticFeedback.selectionClick();
  return showAdaptiveSheet<void>(
    context,
    useSafeArea: true,
    builder: (_) => _StreakSheet(game: game, viewerId: viewerId),
  );
}

class _StreakSheet extends StatelessWidget {
  const _StreakSheet({required this.game, required this.viewerId});

  final DailyGame? game;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SheetFrame(
      title: sentenceCaseOf(context, leaderboardGameName(l10n, game)),
      subtitle: sentenceCaseOf(context, l10n.streaksLabel),
      showClose: true,
      padding: EdgeInsets.zero,
      // As tall as its rows, and the list runs to the bottom edge under
      // the home indicator rather than stopping above a solid foot.
      scrollsUnderInset: true,
      child: ListenableBuilder(
        listenable: GamesStore.instance,
        builder: (context, _) {
          final standings = GamesStore.instance.standings;
          final ranking = standings.streakRanking(
            game,
            viewerId,
            you: sentenceCaseOf(context, l10n.momentRailYouLabel),
          );
          // Equal runs share a place: a tie is a tie, not whoever's name
          // sorts first.
          final places = rankedPlaces(ranking, (a, b) => a.streak == b.streak);
          final longest = standings.myStreaks[game]?.best ?? 0;
          return ListView(
            shrinkWrap: true,
            padding: sheetListPadding(context),
            children: [
              if (ranking.isEmpty)
                EmptyLine(l10n.streaksEmpty)
              else
                SheetRise(
                  child: SheetGroup(
                    children: [
                      for (var i = 0; i < ranking.length; i++)
                        ScoreRow(
                          key: ValueKey(ranking[i].userId),
                          rank: places[i],
                          medal: places[i] <= 3,
                          userId: ranking[i].userId,
                          name: ranking[i].name,
                          isViewer: ranking[i].userId == viewerId,
                          semantics: l10n.streakDays(ranking[i].streak),
                          trailing: _Flame(ranking[i].streak),
                        ),
                    ],
                  ),
                ),
              if (longest > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Text(
                    sentenceCaseOf(context, l10n.streakLongest(longest)),
                    style: groupedMetaStyle(theme)
                        .copyWith(color: theme.inkMuted),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A streak as a ranking's score: the flame and the days, at the row
/// value's size so the column lines up like a time does.
class _Flame extends StatelessWidget {
  const _Flame(this.days);

  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = streakColor(theme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.flame_fill, size: 17, color: color),
        const SizedBox(width: 4),
        ScoreText('$days'),
      ],
    );
  }
}
