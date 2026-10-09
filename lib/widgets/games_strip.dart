import 'package:flutter/material.dart';

import '../models/daily_game.dart';
import '../models/puzzle.dart';
import 'game_tile.dart';

/// Today's five games on the Feed board, one row that scrolls sideways: the
/// code puzzle first, then the four dailies.
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
    const count = 5;
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - inset * 2;
        // All five across when they fit at a comfortable size (a wide window),
        // with nothing to scroll. Otherwise 2.4 to a screen: the fraction is
        // the affordance, a cut tile is what says "swipe".
        final across = (room - gap * (count - 1)) / count;
        final width = across >= 150
            ? across.clamp(150.0, 210.0)
            : ((room - gap * 2) / 2.4).clamp(128.0, 176.0);
        final tiles = <Widget>[
          CodePuzzleTile(
            key: const ValueKey('strip_code'),
            puzzle: puzzle,
            width: width,
            rank: puzzleRank,
            onTap: onOpenPuzzle,
          ),
          for (final game in DailyGame.values)
            GameTile(
              key: ValueKey('strip_${game.wire}'),
              game: game,
              boards: boards,
              result: results[game],
              rank: ranks[game],
              width: width,
              onTap: () => onOpen(game),
            ),
        ];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          // Vertical room for the press spring and the focus ring, which
          // paint outside a tile's bounds and a scroll view would clip.
          padding: EdgeInsets.symmetric(horizontal: inset, vertical: 4),
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                tiles[i],
              ],
            ],
          ),
        );
      },
    );
  }
}
