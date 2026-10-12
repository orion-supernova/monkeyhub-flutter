import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../games/flow_board_art.dart';
import '../games/futoshiki_board_art.dart';
import '../games/game_canvas.dart';
import '../games/game_names.dart';
import '../games/minesweeper_board_art.dart';
import '../games/nonogram_board_art.dart';
import '../games/queens_board_art.dart';
import '../games/starbattle_board_art.dart';
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

  String _name(AppLocalizations l10n) => dailyGameName(l10n, game);

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
      DailyGame.flow => FlowBoardPainter(
        board: boards.flow,
        theme: theme,
        palette: GamePalette(theme),
      ),
      DailyGame.futoshiki => FutoshikiBoardPainter(
        board: boards.futoshiki,
        theme: theme,
      ),
      DailyGame.nonogram => NonogramBoardPainter(
        board: boards.nonogram,
        theme: theme,
      ),
      DailyGame.minesweeper => MinesweeperBoardPainter(
        board: boards.minesweeper,
        theme: theme,
      ),
      DailyGame.starbattle => StarBattleBoardPainter(
        board: boards.starbattle,
        theme: theme,
        palette: GamePalette(theme),
      ),
    };
    final size = boards.sizeOf(game);
    if (size == 0) return GameBoardSkeleton(radius: theme.radiusMd);
    return CustomPaint(painter: painter, size: Size.infinite);
  }
}

/// The symbol-code puzzle's tile.
///
/// Kept on the same shelf as the timed dailies even though it is a different
/// shape of game — six guesses rather than a stopwatch, and its own table
/// behind it. Splitting the two apart would mean a player has to remember there
/// are games in two places, which is how one of them stops being played.
class CodePuzzleTile extends StatelessWidget {
  const CodePuzzleTile({
    super.key,
    required this.puzzle,
    required this.width,
    required this.onTap,
    this.rank,
  });

  final PuzzleState puzzle;
  final double width;
  final VoidCallback onTap;

  /// Where the viewer placed among friends who have finished, if they have.
  final int? rank;

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
      preview: const _CodeGridPreview(),
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
          : Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                StatusChip(
                  label: mine.solved
                      ? '${mine.guesses.length}/$kPuzzleMaxGuesses'
                      : 'X/$kPuzzleMaxGuesses',
                  tone: mine.solved ? theme.success : theme.inkMuted,
                  icon: mine.solved ? CupertinoIcons.checkmark_alt : null,
                ),
                if (rank != null)
                  StatusChip(
                    label: l10n.gameRankBadge('$rank'),
                    tone: theme.accent,
                  ),
              ],
            ),
    );
  }
}

/// A place held for a daily that is not out yet, in a group that would
/// otherwise be empty.
///
/// Quiet on purpose: a grey outline of a board with no shimmer (a placeholder
/// that animates forever is a ticker nobody asked for), the name and the chip
/// muted, and no tap — there is nothing behind it to open yet.
class ComingSoonTile extends StatelessWidget {
  const ComingSoonTile({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Opacity(
      opacity: 0.6,
      child: _TileShell(
        width: width,
        semanticLabel:
            '${l10n.gameComingSoonName}, ${l10n.gameComingSoon}',
        preview: ColoredBox(color: theme.ink.withValues(alpha: 0.05)),
        title: l10n.gameComingSoonName,
        muted: true,
        status: StatusChip(
          label: sentenceCaseOf(context, l10n.gameComingSoon),
          tone: theme.inkMuted,
        ),
      ),
    );
  }
}

/// The card every tile is drawn in — square preview, name, status.
class _TileShell extends StatelessWidget {
  const _TileShell({
    required this.width,
    this.onTap,
    this.onInfo,
    required this.semanticLabel,
    required this.preview,
    required this.title,
    required this.status,
    this.muted = false,
  });

  final double width;

  /// Null for a tile with nothing behind it ([ComingSoonTile]).
  final VoidCallback? onTap;

  /// Opens the how-to-play sheet. A separate target inside the tile's own tap
  /// region — children are hit-tested before their parents, so the ⓘ takes the
  /// tap and everywhere else still opens the board. Null hides the ⓘ.
  final VoidCallback? onInfo;
  final bool muted;
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
    final card = Container(
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
                  // Shrinks to fit rather than truncating a game's name.
                  child: FitLabel(
                    sentenceCaseOf(context, title),
                    style: theme.bodyEmph.copyWith(
                      fontSize: 17,
                      color: muted ? theme.inkMuted : theme.ink,
                    ),
                    maxLines: 1,
                    minFontSize: 13,
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
              if (onInfo != null)
                GameInfoButton(onTap: onInfo!, size: 30, tapSize: 36)
              else
                // The ⓘ's footprint, so a placeholder's name sits on the
                // same line height as its neighbours'.
                const SizedBox(width: 6, height: 36),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: status,
          ),
        ],
      ),
    );
    final tap = onTap;
    return SizedBox(
      width: width,
      child: tap == null
          ? Semantics(label: semanticLabel, child: ExcludeSemantics(child: card))
          : SpringPress(
              onTap: tap,
              semanticLabel: semanticLabel,
              scale: 0.95,
              child: card,
            ),
    );
  }
}

/// The code puzzle's thumbnail: a small guess grid — four columns, six rows,
/// the first two filled with symbols — the same board language the puzzle
/// screen draws, so the tile is a picture of the game beside the real boards
/// rather than a near-empty card with a few loose glyphs on it.
///
/// Decorative only: the symbols are in index order and the cells carry no
/// right/wrong tint, so it hints at nothing about today's code.
class _CodeGridPreview extends StatelessWidget {
  const _CodeGridPreview();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    const cols = kPuzzleSlots;
    const rows = kPuzzleMaxGuesses;
    const filled = 2;
    return LayoutBuilder(
      builder: (context, c) {
        final gap = (c.maxWidth * 0.035).clamp(2.0, 6.0);
        final cell = ((c.maxHeight - gap * (rows - 1)) / rows)
            .clamp(0.0, (c.maxWidth - gap * (cols - 1)) / cols);
        return ColoredBox(
          color: theme.ink.withValues(alpha: 0.03),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < rows; r++) ...[
                  if (r > 0) SizedBox(height: gap),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var col = 0; col < cols; col++) ...[
                        if (col > 0) SizedBox(width: gap),
                        Container(
                          width: cell,
                          height: cell,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.ink.withValues(
                              alpha: r < filled ? 0.10 : 0.06,
                            ),
                            borderRadius: BorderRadius.circular(cell * 0.26),
                          ),
                          child: r < filled
                              ? PuzzleSymbol(
                                  index: (r * cols + col) % kPuzzleSymbolCount,
                                  size: cell * 0.56,
                                  accent: theme.accent,
                                )
                              : null,
                        ),
                      ],
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
            Icon(icon, size: 13, color: tone),
            // 5, not 3: at 3 the glyph touched the first letter in Turkish
            // at large text ("Bugün 4 tane kaldı").
            const SizedBox(width: 5),
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
