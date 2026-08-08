import 'package:flutter/material.dart';

import '../games/game_canvas.dart';
import '../games/queens_board_art.dart';
import '../games/sudoku_board_art.dart';
import '../games/tango_board_art.dart';
import '../games/zip_board_art.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'game_board_skeleton.dart';
import 'game_info_sheet.dart';

/// Today's four games, compact enough to live on the Feed board.
///
/// This exists for the same reason [PuzzleScoreStrip] does. A daily you have to
/// navigate to is a daily nobody plays: the games would be one tap behind a hub
/// that is itself one tap behind a section nobody has a reason to open. Putting
/// the four boards — the real ones, drawn small — on the board people already
/// look at every morning is the difference between a feature and a menu item.
///
/// Shows the viewer's own status only. Friends' times cost an indexed read each
/// and live on the hub, which fetches them when it opens; the board payload
/// already carries the viewer's own rows for free.
class GamesStrip extends StatelessWidget {
  const GamesStrip({
    super.key,
    required this.boards,
    required this.results,
    required this.onOpen,
  });

  final DailyBoards boards;

  /// The viewer's row per game, straight off the Feed board payload.
  final Map<DailyGame, GameResult> results;

  final void Function(DailyGame game) onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final game in DailyGame.values)
          Expanded(
            child: Padding(
              key: ValueKey('strip_${game.wire}'),
              padding: EdgeInsets.only(
                right: game == DailyGame.values.last ? 0 : 8,
              ),
              child: _StripTile(
                game: game,
                boards: boards,
                result: results[game],
                onTap: () => onOpen(game),
              ),
            ),
          ),
      ],
    );
  }
}

class _StripTile extends StatelessWidget {
  const _StripTile({
    required this.game,
    required this.boards,
    required this.result,
    required this.onTap,
  });

  final DailyGame game;
  final DailyBoards boards;
  final GameResult? result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final row = result;
    final done = row?.finished ?? false;

    return FocusableTap(
      onTap: onTap,
      semanticLabel: _name(l10n),
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              // The disc hangs over the tile's corner, into the gutter between
              // tiles and the 12pt under the section rule.
              clipBehavior: Clip.none,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                      border: Border.all(
                        // A solved board wears the accent. Four identical
                        // outlines would make "how am I doing today" a thing
                        // you read rather than a thing you see.
                        color: done && (row?.solved ?? false)
                            ? theme.accent
                            : theme.divider,
                      ),
                    ),
                    child: _preview(theme),
                  ),
                ),
                // The whole top-right corner of the tile opens the rules. The
                // tile here is barely wider than a thumb, so the glyph has to
                // stay small — but the box around it does not, and it has to
                // sit inside the tile rather than overhang it, because a tap
                // outside a Stack's bounds never reaches the child under it.
                Positioned(
                  top: 0,
                  right: 0,
                  child: GameInfoButton(
                    onTap: () => showGameInfo(context, game),
                    // A step under the hub's, like everything else on the
                    // band, and hanging 5pt off the corner it is pinned to.
                    size: 30,
                    // Short of the 44 the hub tile can afford: past this, the
                    // corner starts eating the taps meant to open the board.
                    tapSize: 40,
                    glyphAlignment: Alignment.topRight,
                    glyphOffset: const Offset(5, -5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _name(l10n),
              style: theme.monoTiny,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              row == null
                  ? l10n.gameStatusUnplayed
                  : !row.finished
                  ? l10n.gameStatusUnfinished
                  : row.solved
                  ? formatGameTime(row.durationMs)
                  : l10n.gameStatusGaveUp,
              style: theme.monoTiny.copyWith(
                color: row != null && row.solved
                    ? theme.ink
                    : row != null && !row.finished
                    ? theme.accent
                    : theme.inkMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _name(AppLocalizations l10n) => switch (game) {
    DailyGame.queens => l10n.gameQueensName,
    DailyGame.tango => l10n.gameTangoName,
    DailyGame.zip => l10n.gameZipName,
    DailyGame.sudoku => l10n.gameSudokuName,
  };

  Widget _preview(AppTheme theme) {
    final size = switch (game) {
      DailyGame.queens => boards.queens.size,
      DailyGame.tango => boards.tango.size,
      DailyGame.zip => boards.zip.size,
      DailyGame.sudoku => boards.sudoku.size,
    };
    // Fewer cells than the hub's: at four-to-a-row the tile is under 80pt, and
    // a six-cell grid drawn that small is a texture rather than a board.
    if (size == 0) {
      return GameBoardSkeleton(radius: theme.radiusSm, cells: 4);
    }
    return CustomPaint(
      painter: switch (game) {
        DailyGame.queens => QueensBoardPainter(
          board: boards.queens,
          theme: theme,
          palette: GamePalette(theme),
        ),
        DailyGame.tango => TangoBoardPainter(board: boards.tango, theme: theme),
        DailyGame.zip => ZipBoardPainter(board: boards.zip, theme: theme),
        DailyGame.sudoku => SudokuBoardPainter(
          board: boards.sudoku,
          theme: theme,
        ),
      },
      size: Size.infinite,
    );
  }
}
