import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../games/game_canvas.dart';
import '../games/queens_board_art.dart';
import '../games/sudoku_board_art.dart';
import '../games/tango_board_art.dart';
import '../games/zip_board_art.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/daily_game.dart';
import '../models/puzzle.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'game_board_skeleton.dart';
import 'game_info_sheet.dart';
import 'ios_kit.dart';
import 'puzzle_symbol.dart';
import '../l10n/text_case.dart';

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
      onInfo: () => showGameInfo(
        context,
        game,
        entry: GameInfoEntry.forBoard(result),
        onPlay: onTap,
      ),
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
    if (size == 0) return GameBoardSkeleton(radius: theme.radiusMd);
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
      onInfo: () => showCodePuzzleInfo(
        context,
        entry: GameInfoEntry.forPuzzle(puzzle.mine),
        onPlay: onTap,
      ),
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
      status: mine == null || !mine.started
          ? StatusChip(
              label: sentenceCaseOf(context, l10n.gameStatusUnplayed),
              tone: theme.inkMuted,
            )
          : !mine.done
          ? StatusChip(
              label: sentenceCaseOf(context, l10n.gameStatusUnfinished),
              tone: theme.accent,
            )
          : StatusChip(
              label: mine.solved
                  ? '${mine.guesses.length}/$kPuzzleMaxGuesses'
                  : 'X/$kPuzzleMaxGuesses',
              tone: mine.solved ? theme.success : theme.inkMuted,
              icon: mine.solved ? CupertinoIcons.checkmark_alt : null,
            ),
    );
  }
}

/// The card every tile is drawn in — square preview, name, status.
class _TileShell extends StatelessWidget {
  const _TileShell({
    required this.width,
    required this.onTap,
    required this.onInfo,
    required this.semanticLabel,
    required this.preview,
    required this.title,
    required this.status,
  });

  final double width;
  final VoidCallback onTap;

  /// Opens the how-to-play sheet. A separate target inside the tile's own tap
  /// region — children are hit-tested before their parents, so the ⓘ takes the
  /// tap and everywhere else still opens the board.
  final VoidCallback onInfo;
  final String semanticLabel;
  final Widget preview;
  final String title;
  final Widget status;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // An Arcade card: a borderless rounded block that dips on a spring, the
    // day's real board inset with its own rounded corners, the name and a
    // status capsule under it. The ⓘ sits on the title line, inside the
    // card, instead of hanging off its corner.
    return SizedBox(
      width: width,
      child: SpringPress(
        onTap: onTap,
        semanticLabel: semanticLabel,
        scale: 0.95,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 12),
          decoration: BoxDecoration(
            color: groupedFill(theme),
            borderRadius: BorderRadius.circular(groupedRadius(theme) + 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    groupedRadius(theme) - 6,
                  ),
                  child: AspectRatio(aspectRatio: 1, child: preview),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        sentenceCaseOf(context, title),
                        style: theme.bodyEmph.copyWith(
                          fontSize: 17,
                          color: theme.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  GameInfoButton(onTap: onInfo, size: 30, tapSize: 36),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: status,
              ),
            ],
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
      return StatusChip(
        label: sentenceCaseOf(context, l10n.gameStatusUnplayed),
        tone: theme.inkMuted,
      );
    }
    if (!row.finished) {
      return StatusChip(
        label: sentenceCaseOf(context, l10n.gameStatusUnfinished),
        tone: theme.accent,
      );
    }
    if (!row.solved) {
      return StatusChip(
        label: sentenceCaseOf(context, l10n.gameStatusGaveUp),
        tone: theme.inkMuted,
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        StatusChip(
          label: formatGameTime(row.durationMs),
          tone: theme.success,
          icon: CupertinoIcons.checkmark_alt,
        ),
        if (rank != null)
          StatusChip(
            label: l10n.gameRankBadge('$rank'),
            tone: theme.accent,
          ),
      ],
    );
  }
}

/// A small tinted capsule: a state in its own colour, never shouting.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final Color tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // Neutral, with the tone on the glyph and words: a 14% wash of a
        // blue tone is a navy pill on a dark page.
        color: quietFill(theme),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tone,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
