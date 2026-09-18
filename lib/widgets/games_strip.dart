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
import 'game_board_skeleton.dart';
import 'game_info_sheet.dart';
import 'puzzle_symbol.dart';

/// Today's five games, compact enough to live on the Feed board — the code
/// puzzle first, then the four dailies. The puzzle used to get its own
/// separate section here, apart from the other four; it is a daily game
/// exactly like they are (the hub has always shelved it beside them, its own
/// tile drawn from the same two, five-board-shelf logic this strip mirrors),
/// and giving it a second, differently-shaped presentation on THIS board was
/// the inconsistency, not this list.
///
/// A daily you have to navigate to is a daily nobody plays: the games would be
/// one tap behind a hub that is itself one tap behind a section nobody has a
/// reason to open. Putting the boards — the real ones, drawn small — on the
/// board people already look at every morning is the difference between a
/// feature and a menu item.
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
    required this.puzzle,
    required this.onOpenPuzzle,
  });

  final DailyBoards boards;

  /// The viewer's row per game, straight off the Feed board payload.
  final Map<DailyGame, GameResult> results;

  final void Function(DailyGame game) onOpen;

  final PuzzleState puzzle;
  final VoidCallback onOpenPuzzle;

  @override
  Widget build(BuildContext context) {
    // Tiles used to `Expanded` to whatever this strip was handed — five equal
    // slices of a phone-width column. Fine on a phone; parked in a narrow
    // desktop sidebar the same math draws five ~60px postage stamps, and even
    // full-bleed on a wide window it would stretch the real board art into
    // squares far bigger than the four-cell preview drawn inside them ever
    // needs to be. Sizing off a target instead — capped so nothing grows past
    // a board anyone would actually want this small — is what makes the strip
    // a preview of five real games rather than five sizes of the same
    // thumbnail.
    //
    // Deliberately only an UPPER bound. A lower one (this used to have one)
    // can only ever overflow: it hands the Row a width the container did not
    // actually offer the moment five tiles' worth of that floor plus their
    // gutters exceeds what the container is wide, which on a phone narrow
    // enough is every launch, not an edge case.
    const gap = 8.0;
    const maxTile = 180.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = DailyGame.values.length + 1;
        final tile = ((constraints.maxWidth - gap * (count - 1)) / count)
            .clamp(0.0, maxTile);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              key: const ValueKey('strip_code'),
              padding: const EdgeInsets.only(right: gap),
              child: SizedBox(
                width: tile,
                child: _PuzzleStripTile(state: puzzle, onTap: onOpenPuzzle),
              ),
            ),
            for (final game in DailyGame.values)
              Padding(
                key: ValueKey('strip_${game.wire}'),
                padding: EdgeInsets.only(
                  right: game == DailyGame.values.last ? 0 : gap,
                ),
                child: SizedBox(
                  width: tile,
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
      },
    );
  }
}

/// The card shell every strip tile shares: a square preview with a rounded,
/// optionally accented frame; the info glyph hanging off its corner; a name
/// and a one-line status underneath. [_StripTile] and [_PuzzleStripTile] only
/// differ in what they hand this for [preview], [title] and [status].
class _StripCard extends StatelessWidget {
  const _StripCard({
    required this.preview,
    required this.title,
    required this.status,
    required this.accent,
    required this.onTap,
    required this.onInfo,
    required this.semanticLabel,
  });

  final Widget preview;
  final String title;
  final Widget status;
  final bool accent;
  final VoidCallback onTap;
  final VoidCallback onInfo;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel,
      radius: theme.radiusLg,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(theme.radiusLg),
                      // A solved board wears the accent, and a touch heavier
                      // than a resting tile's hairline — four (five) identical
                      // outlines would make "how am I doing today" a thing you
                      // read rather than a thing you see.
                      border: Border.all(
                        color: accent ? theme.accent : theme.divider,
                        width: accent ? 1.4 : 1,
                      ),
                      boxShadow: accent
                          ? [
                              BoxShadow(
                                color: theme.accent.withValues(alpha: 0.22),
                                blurRadius: 14,
                                spreadRadius: -2,
                              ),
                            ]
                          : null,
                    ),
                    child: preview,
                  ),
                ),
                // The whole top-right corner of the tile opens the rules. On
                // a phone the tile is barely wider than a thumb, so the glyph
                // has to stay small — but the box around it does not, and it
                // has to sit inside the tile rather than overhang it, because
                // a tap outside a Stack's bounds never reaches the child
                // under it.
                Positioned(
                  top: 0,
                  right: 0,
                  child: GameInfoButton(
                    onTap: onInfo,
                    // A step under the hub's, like everything else on the
                    // band, and hanging 5pt off the corner it is pinned to.
                    size: 32,
                    // Short of the 44 the hub tile can afford: past this, the
                    // corner starts eating the taps meant to open the board.
                    tapSize: 40,
                    glyphAlignment: Alignment.topRight,
                    glyphOffset: const Offset(5, -5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.bodyEmph.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            status,
          ],
        ),
      ),
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

    return _StripCard(
      onTap: onTap,
      onInfo: () => showGameInfo(
        context,
        game,
        entry: GameInfoEntry.forBoard(result),
        onPlay: onTap,
      ),
      semanticLabel: _name(l10n),
      accent: done && (row?.solved ?? false),
      preview: _preview(theme),
      title: _name(l10n),
      status: Text(
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
    // Fewer cells than the hub's: at five-to-a-row the tile is under 80pt, and
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

/// The code puzzle's own strip tile — same [_StripCard] shell as the four
/// dailies, a Wordle-style row of symbols standing in for board art (it has
/// none) and the same "unplayed / in progress / N of six" status shape the
/// puzzle screen and the hub both already use.
class _PuzzleStripTile extends StatelessWidget {
  const _PuzzleStripTile({required this.state, required this.onTap});

  final PuzzleState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final mine = state.mine;
    final done = mine?.done ?? false;

    return _StripCard(
      onTap: onTap,
      onInfo: () => showCodePuzzleInfo(
        context,
        entry: GameInfoEntry.forPuzzle(state.mine),
        onPlay: onTap,
      ),
      semanticLabel: l10n.gameCodeName,
      accent: done && mine!.solved,
      preview: _symbolGrid(theme),
      title: l10n.gameCodeName,
      status: Text(
        mine == null || !mine.started
            ? l10n.gameStatusUnplayed
            : done
            ? (mine.solved
                  ? '${mine.guesses.length}/$kPuzzleMaxGuesses'
                  : l10n.gameStatusGaveUp)
            : l10n.gameStatusUnfinished,
        style: theme.monoTiny.copyWith(
          color: mine != null && done
              ? (mine.solved ? theme.ink : theme.inkMuted)
              : mine != null && !done
              ? theme.accent
              : theme.inkMuted,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// The six symbols as a proper 3×2 board of bordered cells — the same
  /// language the real grid draws each guess in — rather than a loose
  /// [Wrap] of bare glyphs. A `Wrap` at this size wraps unevenly depending on
  /// exactly how many px the tile lands on and reads as clutter next to the
  /// four real, structured boards beside it; a fixed grid looks like a board
  /// no matter what width it's handed.
  Widget _symbolGrid(AppTheme theme) {
    const cols = 3;
    const rows = 2;
    const gap = 4.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - gap * (cols - 1)) / cols <
                (constraints.maxHeight - gap * (rows - 1)) / rows
            ? (constraints.maxWidth - gap * (cols - 1)) / cols
            : (constraints.maxHeight - gap * (rows - 1)) / rows;
        return Center(
          child: SizedBox(
            width: cell * cols + gap * (cols - 1),
            height: cell * rows + gap * (rows - 1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var r = 0; r < rows; r++) ...[
                  if (r > 0) SizedBox(height: gap),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var c = 0; c < cols; c++) ...[
                        if (c > 0) SizedBox(width: gap),
                        _symbolCell(theme, r * cols + c, cell),
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

  Widget _symbolCell(AppTheme theme, int index, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: theme.surfaceSunken,
      borderRadius: BorderRadius.circular(theme.radiusSm),
      border: Border.all(color: theme.divider),
    ),
    alignment: Alignment.center,
    child: PuzzleSymbol(
      index: index,
      size: size * 0.52,
      accent: theme.accent,
    ),
  );
}
