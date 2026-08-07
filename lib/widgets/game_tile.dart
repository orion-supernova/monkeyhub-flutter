import 'package:flutter/material.dart';

import '../games/game_canvas.dart';
import '../games/queens_board_art.dart';
import '../games/sudoku_board_art.dart';
import '../games/tango_board_art.dart';
import '../games/zip_board_art.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/daily_game.dart';
import '../models/puzzle.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'puzzle_symbol.dart';

/// One game on the hub: today's real board, its name, and how you did.
///
/// The preview is drawn by the same painter as the playable board, with no
/// player state passed in. Two things follow from that, and both are the point:
/// the hub looks different every morning, and the tile is an honest picture of
/// the puzzle behind it rather than a stock icon that would look identical on a
/// day the board happens to be brutal.
class GameTile extends StatelessWidget {
  const GameTile({
    super.key,
    required this.game,
    required this.boards,
    required this.width,
    required this.onTap,
    this.result,
    this.rank,
  });

  final DailyGame game;
  final DailyBoards boards;

  /// The viewer's row for today, absent if they have not opened this board.
  final GameResult? result;

  /// Where they placed among friends who have finished, if they have.
  final int? rank;

  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return _TileShell(
      width: width,
      onTap: onTap,
      semanticLabel: _name(l10n),
      preview: _preview(theme),
      title: _name(l10n),
      status: _Status(result: result, rank: rank),
    );
  }

  String _name(AppLocalizations l10n) => switch (game) {
    DailyGame.queens => l10n.gameQueensName,
    DailyGame.tango => l10n.gameTangoName,
    DailyGame.zip => l10n.gameZipName,
    DailyGame.sudoku => l10n.gameSudokuName,
  };

  Widget _preview(AppTheme theme) {
    final painter = switch (game) {
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
    };
    final size = switch (game) {
      DailyGame.queens => boards.queens.size,
      DailyGame.tango => boards.tango.size,
      DailyGame.zip => boards.zip.size,
      DailyGame.sudoku => boards.sudoku.size,
    };
    if (size == 0) return const _PreviewSkeleton();
    return CustomPaint(painter: painter, size: Size.infinite);
  }
}

/// The symbol-code puzzle's tile.
///
/// Kept on the same shelf as the four new dailies even though it is a different
/// shape of game — six guesses rather than a stopwatch, and its own table
/// behind it. Splitting the two apart would mean a player has to remember there
/// are games in two places, which is how one of them stops being played.
class CodePuzzleTile extends StatelessWidget {
  const CodePuzzleTile({
    super.key,
    required this.puzzle,
    required this.width,
    required this.onTap,
  });

  final PuzzleState puzzle;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final mine = puzzle.mine;

    return _TileShell(
      width: width,
      onTap: onTap,
      semanticLabel: l10n.gameCodeName,
      title: l10n.gameCodeName,
      preview: Center(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var s = 0; s < kPuzzleSymbolCount; s++)
              PuzzleSymbol(index: s, size: 16, accent: theme.accent),
          ],
        ),
      ),
      status: Text(
        mine == null || !mine.started
            ? l10n.gameStatusUnplayed
            : mine.done
            ? (mine.solved
                  ? '${mine.guesses.length}/$kPuzzleMaxGuesses'
                  : 'X/$kPuzzleMaxGuesses')
            : l10n.gameStatusUnfinished,
        style: theme.monoLarge.copyWith(
          fontSize: 14,
          color: mine?.done == true ? theme.ink : theme.inkMuted,
        ),
      ),
    );
  }
}

/// The card every tile is drawn in — square preview, name, status.
class _TileShell extends StatelessWidget {
  const _TileShell({
    required this.width,
    required this.onTap,
    required this.semanticLabel,
    required this.preview,
    required this.title,
    required this.status,
  });

  final double width;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget preview;
  final String title;
  final Widget status;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      width: width,
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: semanticLabel,
        radius: theme.radiusLg,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(theme.radiusLg),
              border: Border.all(color: theme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(aspectRatio: 1, child: preview),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: theme.bodyEmph,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                status,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How the viewer did, in one line.
class _Status extends StatelessWidget {
  const _Status({required this.result, required this.rank});

  final GameResult? result;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final row = result;

    if (row == null) {
      return Text(
        l10n.gameStatusUnplayed,
        style: theme.monoTiny.copyWith(color: theme.inkMuted),
      );
    }
    if (!row.finished) {
      return Text(
        l10n.gameStatusUnfinished,
        style: theme.monoTiny.copyWith(color: theme.accent),
      );
    }
    if (!row.solved) {
      return Text(
        l10n.gameStatusGaveUp,
        style: theme.monoTiny.copyWith(color: theme.inkMuted),
      );
    }
    return Row(
      children: [
        Text(
          formatGameTime(row.durationMs),
          style: theme.monoLarge.copyWith(fontSize: 14),
        ),
        if (rank != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.accentSoft,
              borderRadius: BorderRadius.circular(theme.radiusSm),
            ),
            child: Text(
              l10n.gameRankBadge('$rank'),
              style: theme.monoTiny.copyWith(color: theme.accent),
            ),
          ),
        ],
      ],
    );
  }
}

/// Stands in for a board that has not arrived yet.
///
/// A muted grid rather than a spinner: the tile is a square either way, and a
/// grid settling into a real board reads as loading where a spinner replaced by
/// a grid reads as two different screens.
class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
    );
  }
}
