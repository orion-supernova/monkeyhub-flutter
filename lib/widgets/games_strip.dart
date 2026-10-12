import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/daily_game.dart';
import '../models/game_catalog.dart';
import '../models/puzzle.dart';
import '../theme/theme_scope.dart';
import 'game_tile.dart';
import 'desktop_scroll.dart';
import 'ios_kit.dart';

/// Today's games on the Feed board, one row that scrolls sideways: the code
/// puzzle and the dailies, easiest first.
///
/// The same tiles the hub used to shelve, with the same time and rank on them.
/// The hub is the leaderboard now, and carrying the games there too put the
/// same five boxes on two screens one tap apart. A daily you have to navigate
/// to is a daily nobody plays, so the boards themselves, drawn small, live on
/// the board people already look at every morning.
///
/// One row rather than a wrapped grid: two rows of tiles pushed everything
/// under the band a full screen down, and the band is a summary, not the
/// destination. The row is sized so the third tile is cut by the edge on a
/// phone, which is what tells a thumb there is more to the right.
///
/// Grouped by [GameTier], easy first, each group under a small caption in the
/// same row — still one line of tiles, so the band stays a summary. A tier
/// with nothing in it yet holds a [ComingSoonTile] rather than vanishing, so
/// the three captions are always there to read.
///
/// Ranks come off the Feed's live board ([FeedStore.gameRank]), so they need
/// no fetch of their own and move the moment a friend finishes.
class GamesStrip extends StatelessWidget {
  const GamesStrip({
    super.key,
    required this.boards,
    required this.results,
    required this.onOpen,
    required this.puzzle,
    required this.onOpenPuzzle,
    this.ranks = const {},
    this.puzzleRank,
    this.inset = 0,
  });

  /// The page's side margin, laid INSIDE the scroll view: the row runs to
  /// the screen's edges and tiles scroll off them, while at rest the first
  /// one still lines up with the band's header.
  final double inset;

  final DailyBoards boards;

  /// The viewer's row per game, straight off the Feed board payload.
  final Map<DailyGame, GameResult> results;

  final void Function(DailyGame game) onOpen;

  final PuzzleState puzzle;
  final VoidCallback onOpenPuzzle;

  /// The viewer's place among friends per finished game, when they have one.
  final Map<DailyGame, int> ranks;

  /// The same for the code.
  final int? puzzleRank;

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    // Between groups: wide enough that a caption reads as starting a new
    // group, not labelling the tile before it.
    const groupGap = 22.0;
    // Every tile the row will hold, placeholders included, for the "all of
    // them fit" test below.
    final tiers = {tierOf(null), for (final g in DailyGame.values) tierOf(g)};
    final count = DailyGame.values.length +
        1 +
        GameTier.values.where((t) => !tiers.contains(t)).length;
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - inset * 2;
        // All of them across when they fit at a comfortable size (a wide window),
        // with nothing to scroll. Otherwise 2.4 to a screen: the fraction is
        // the affordance, a cut tile is what says "swipe".
        final across = (room - gap * (count - 1)) / count;
        final width = across >= 150
            ? across.clamp(150.0, 210.0)
            : ((room - gap * 2) / 2.4).clamp(128.0, 176.0);
        Widget gameTile(DailyGame game) => GameTile(
          key: ValueKey('strip_${game.wire}'),
          game: game,
          boards: boards,
          result: results[game],
          rank: ranks[game],
          width: width,
          onTap: () => onOpen(game),
        );
        final groups = <GameTier, List<Widget>>{
          for (final tier in GameTier.values) tier: [],
        };
        groups[tierOf(null)]!.add(
          CodePuzzleTile(
            key: const ValueKey('strip_code'),
            puzzle: puzzle,
            width: width,
            rank: puzzleRank,
            onTap: onOpenPuzzle,
          ),
        );
        for (final game in DailyGame.values) {
          groups[tierOf(game)]!.add(gameTile(game));
        }
        for (final tier in GameTier.values) {
          if (groups[tier]!.isEmpty) {
            groups[tier]!.add(
              ComingSoonTile(key: ValueKey('strip_soon_$tier'), width: width),
            );
          }
        }
        final caption = groupedMetaStyle(theme).copyWith(
          fontWeight: FontWeight.w600,
          color: theme.inkMuted,
        );
        String label(GameTier tier) => sentenceCaseOf(
          context,
          switch (tier) {
            GameTier.easy => l10n.gameTierEasy,
            GameTier.medium => l10n.gameTierMedium,
            GameTier.hard => l10n.gameTierHard,
          },
        );
        return HorizontalWheelScroll(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            // Vertical room for the press spring and the focus ring, which
            // paint outside a tile's bounds and a scroll view would clip.
            padding: EdgeInsets.symmetric(horizontal: inset, vertical: 4),
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final tier in GameTier.values) ...[
                  if (tier != GameTier.values.first)
                    const SizedBox(width: groupGap),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          label(tier),
                          style: caption,
                          semanticsLabel: label(tier),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (i, tile) in groups[tier]!.indexed) ...[
                            if (i > 0) const SizedBox(width: gap),
                            tile,
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
