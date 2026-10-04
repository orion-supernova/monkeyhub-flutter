import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../games/game_canvas.dart';
import '../games/game_rules.dart';
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
import 'adaptive_sheet.dart';
import 'puzzle_symbol.dart';
import 'sheet_kit.dart';
import 'ios_kit.dart';
import '../l10n/text_case.dart';

/// What a daily game is, in the plainest words the rules allow.
///
/// This exists because a grid of coloured squares does not explain itself.
/// Every one of these games is well known to the people who already play them
/// and completely opaque to everyone else — the one-line rule under a board's
/// title is a reminder for someone who has played before, not an introduction.
/// Opening a puzzle you do not understand, on a clock, next to your friends'
/// times, is how a daily gets closed and never reopened.
///
/// So the sheet answers four questions in order, and no others: what am I
/// trying to do (a picture and one line), what are the rules (3–5 numbered
/// lines, one idea each), what does that look like (one worked example), and
/// what do I tap. The copy is written for a ten-year-old on purpose — short
/// words, digits not number words, no "region" or "orthogonal" — because the
/// person reading it is deciding in five seconds whether to play. The scoring
/// line at the end is there because these are timed and shared, and nobody
/// should discover that by seeing their name on a leaderboard.
///
/// Reachable from the ⓘ on every tile — on the Feed band and on the hub — which
/// are the two places the question occurs.
///
/// The main button is the way INTO the game, labelled for where the player is
/// with it today ([entry]), and [onPlay] is what the tile itself would have
/// done. Somebody who opened the rules was deciding whether to play; ending the
/// sheet on "GOT IT" sent them back to the tile to tap it a second time.
/// Closing without playing is the X, a swipe down, or a tap outside.
Future<void> showGameInfo(
  BuildContext context,
  DailyGame game, {
  required GameInfoEntry entry,
  required VoidCallback onPlay,
}) =>
    _show(context, game, entry, onPlay);

/// The same sheet for the symbol-code puzzle, which shares the hub with the
/// four timed boards but is scored by guesses rather than by the clock.
Future<void> showCodePuzzleInfo(
  BuildContext context, {
  required GameInfoEntry entry,
  required VoidCallback onPlay,
}) =>
    _show(context, null, entry, onPlay);

/// Where the player stands with a game today, which is what the sheet's main
/// button offers them.
enum GameInfoEntry {
  /// Not opened today.
  play,

  /// Opened and left unfinished.
  resume,

  /// Finished — solved, or given up on.
  review;

  /// For one of the four timed boards, from the player's row for today.
  static GameInfoEntry forBoard(GameResult? today) => today == null
      ? play
      : today.finished
      ? review
      : resume;

  /// For the code puzzle, from the player's attempt at today's code.
  static GameInfoEntry forPuzzle(PuzzleAttempt? mine) =>
      mine == null || !mine.started
      ? play
      : mine.done
      ? review
      : resume;
}

Future<void> _show(
  BuildContext context,
  DailyGame? game,
  GameInfoEntry entry,
  VoidCallback onPlay,
) async {
  // Kept clear of the status bar by `showAdaptiveSheet`'s own default: the
  // rules run long in a few languages and can outgrow a small phone.
  final play = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _GameInfoSheet(game: game, entry: entry),
  );
  // After the sheet is fully gone, never from inside it: [onPlay] pushes the
  // game on the TILE's navigator, and a push racing the sheet's own pop is how
  // a route ends up under the one it was meant to replace.
  if (play == true && context.mounted) onPlay();
}

/// The ⓘ that opens it.
///
/// Deliberately its own tap target rather than a long-press on the tile: a
/// gesture nobody can see is a gesture nobody finds, and the whole problem here
/// is a player who does not yet know what the board in front of them is.
///
/// Sits inside the tile's own tap region, so hit-testing gives it the tap —
/// children are tested before their parents — and the tile still opens from
/// everywhere else.
class GameInfoButton extends StatelessWidget {
  const GameInfoButton({
    super.key,
    required this.onTap,
    this.size = 34,
    this.tapSize = 44,
    this.glyphAlignment = Alignment.center,
    this.glyphOffset = Offset.zero,
  });

  final VoidCallback onTap;

  /// How big the glyph is drawn — a separate question from how big it is to a
  /// thumb, and the only one the eye answers.
  final double size;

  /// How big the glyph is to a thumb, which is a different number entirely.
  /// The 26pt disc these tiles want visually is nowhere near a target anyone
  /// can hit on the first try, so the target is a transparent box around it.
  ///
  /// Callers must leave this box room inside whatever hit-tests it: a box that
  /// hangs off the edge of its parent is invisible to hit testing, not merely
  /// clipped, which is exactly how the old ⓘ ended up half the size it looked.
  final double tapSize;

  /// Where the glyph sits inside that box. Centred by default; corner-aligned
  /// where the box has to be pushed inward to stay in bounds and the glyph
  /// still belongs on the corner.
  final Alignment glyphAlignment;

  /// Nudges the glyph off the corner it is aligned to — paint only, so the box
  /// underneath does not move out of the bounds it has to stay inside. Lets the
  /// disc hang over the edge of the tile like a badge pinned to it, which is
  /// also how it reads as belonging to the tile rather than to the board art.
  ///
  /// The Stack it sits in needs [Clip.none] or the overhang is cut off.
  final Offset glyphOffset;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final box = tapSize < size ? size : tapSize;
    return SpringPress(
      onTap: onTap,
      semanticLabel: l10n.gameInfoOpen,
      focusShape: FocusRingShape.circle,
      focusRadius: box / 2,
      scale: PressSpec.scaleSmall,
      child: SizedBox(
        width: box,
        height: box,
        child: Align(
          alignment: glyphAlignment,
          child: Transform.translate(
            offset: glyphOffset,
            child: Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                // Solid, not a tint. It is painted onto a board of eight
                // region colours and across the tile's own outline, and a
                // translucent disc would carry that border line through its
                // middle.
                color: theme.ink.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                CupertinoIcons.question,
                size: size * 0.40,
                color: theme.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameInfoSheet extends StatelessWidget {
  const _GameInfoSheet({required this.game, required this.entry});

  /// Null is the symbol-code puzzle — the one game on the hub that is not one
  /// of the four timed boards.
  final DailyGame? game;
  final GameInfoEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final copy = _copyFor(l10n, game);
    final action = switch (entry) {
      GameInfoEntry.play => l10n.gameInfoPlay,
      GameInfoEntry.resume => l10n.gameInfoContinue,
      GameInfoEntry.review => l10n.gameInfoSeeResult,
    };
    final header = groupedHeaderStyle(theme);

    // The shared sheet: the game's name in the bar like every sheet's, the ×
    // the app's one chrome disc, and the way in pinned as the footer — on a
    // short phone or in a long language the rules scroll and "Play" stays put.
    // The body is a [SheetScrollBody], so a pull down from its top drags the
    // whole sheet closed instead of stretching the text.
    return SheetFrame(
      title: sentenceCaseOf(context, copy.name),
      onClose: () => Navigator.of(context).maybePop(false),
      padding: EdgeInsets.zero,
      // Autofocused, so a keyboard user lands on the way in.
      footer: SheetActionButton(
        label: action,
        icon: CupertinoIcons.play_fill,
        autofocus: true,
        haptic: false,
        onTap: () => Navigator.of(context).maybePop(true),
      ),
      child: SheetScrollBody(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The hero: an example board rather than an icon. The words below
            // are about crowns and colours and a line through squares, and
            // every one of them is easier to read next to the thing it
            // describes.
            Center(
              child: SizedBox.square(
                dimension: 132,
                child: ExcludeSemantics(
                  child: _Example(game: game, theme: theme),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // The goal, in one line, under the picture of it.
            Semantics(
              label: '${l10n.gameInfoGoalLabel}: ${copy.goal}',
              excludeSemantics: true,
              child: Text(
                sentenceCaseOf(context, copy.goal),
                textAlign: TextAlign.center,
                style: theme.bodyEmph.copyWith(
                  fontSize: 20,
                  height: 1.25,
                  color: theme.ink,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                sentenceCaseOf(context, l10n.gameInfoRulesLabel),
                style: header,
              ),
            ),
            const SizedBox(height: 12),
            // Numbered, not bulleted: "rule 3" is something a person can
            // point at, and the count tells them how much there is to learn.
            for (var i = 0; i < copy.rules.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _NumberedRule(number: i + 1, text: copy.rules[i]),
            ],
            const SizedBox(height: 24),
            _ExampleCard(text: copy.example),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                sentenceCaseOf(context, l10n.gameInfoControlsLabel),
                style: header,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sentenceCaseOf(context, copy.controls),
              style: groupedTitleStyle(theme).copyWith(color: theme.inkSoft),
            ),
            const SizedBox(height: 24),
            // How you win: quieter than the rules, because it is not needed
            // to play — but these games are timed and shared, and nobody
            // should discover that by seeing their name on a leaderboard.
            Row(
              children: [
                Icon(
                  CupertinoIcons.rosette,
                  size: 15,
                  color: theme.accent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      sentenceCaseOf(context, l10n.gameInfoWinLabel),
                      style: groupedFooterStyle(theme).copyWith(
                        color: theme.inkSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${sentenceCaseOf(context, copy.win)} '
              '${sentenceCaseOf(context, l10n.gameInfoSameForEveryone)}',
              style: groupedFooterStyle(theme),
            ),
          ],
        ),
      ),
    );
  }
}

/// One rule: a small accent number disc, then the rule at row-title size.
/// Read aloud as "1. Every row gets exactly 1 crown."
class _NumberedRule extends StatelessWidget {
  const _NumberedRule({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final line = sentenceCaseOf(context, text);
    final style = groupedTitleStyle(theme);
    // The disc centres on the FIRST line of the text, whatever the text size:
    // a fixed top offset drifts off it at 1.3×.
    final lineHeight =
        (style.fontSize ?? 17) * (style.height ?? 1.25) *
        MediaQuery.textScalerOf(context).scale(1);
    return Semantics(
      label: '$number. $line',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: lineHeight < 24 ? 24 : lineHeight,
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accent.withValues(alpha: 0.14),
                ),
                child: Text(
                  '$number',
                  textScaler: TextScaler.noScaling,
                  style: groupedMetaStyle(theme).copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.accent,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              // Centres a one-line rule on the 24pt disc when the line is
              // shorter than it.
              padding: EdgeInsets.only(
                top: lineHeight < 24 ? (24 - lineHeight) / 2 : 0,
              ),
              child: Text(line, style: style),
            ),
          ),
        ],
      ),
    );
  }
}

/// The worked example: one tiny situation, on a quiet card, so the rules
/// above stop being abstract.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: sheetGroupFill(theme),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.lightbulb_fill,
                size: 15,
                color: theme.accent,
              ),
              const SizedBox(width: 6),
              Text(
                sentenceCaseOf(context, l10n.gameInfoExampleLabel),
                style: groupedMetaStyle(theme).copyWith(
                  color: theme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sentenceCaseOf(context, text),
            style: groupedFooterStyle(theme).copyWith(color: theme.ink),
          ),
        ],
      ),
    );
  }
}

/// A small worked example of the board being described.
///
/// Hand-built rather than today's real puzzle, and that is the point: the sheet
/// is teaching the shape of the game, and a live board is a spoiler on three of
/// the four — a Queens example with its crowns already placed would hand over
/// part of today's answer to someone who only wanted the rules.
class _Example extends StatelessWidget {
  const _Example({required this.game, required this.theme});

  final DailyGame? game;
  final AppTheme theme;

  static const _queens = QueensBoard(
    size: 4,
    regions: [0, 0, 1, 1, 0, 2, 2, 1, 3, 3, 2, 1, 3, 3, 2, 2],
  );

  static const _tango = TangoBoard(
    size: 4,
    givens: [0, 1, -1, -1, -1, -1, 1, 0, 1, -1, -1, -1, -1, 0, -1, 1],
    signs: [TangoSign(a: 0, b: 4, eq: false), TangoSign(a: 6, b: 7, eq: true)],
  );

  static const _zip = ZipBoard(size: 4, checkpoints: [0, 6, 9, 15]);

  /// A single crown on the example board.
  ///
  /// One, not a solved grid: "one per row, one per column, one per colour"
  /// needs something to point at, and a finished example would be a walkthrough
  /// of an answer rather than a picture of the rules.
  static final _oneCrown = [
    for (var i = 0; i < 16; i++)
      i == 5 ? QueensMark.crown : QueensMark.none,
  ];

  static const _sudoku = SudokuBoard(
    size: 6,
    givens: [
      1, 0, 0, 4, 0, 0, //
      0, 0, 5, 0, 0, 2, //
      0, 3, 0, 0, 6, 0, //
      0, 6, 0, 0, 1, 0, //
      2, 0, 0, 6, 0, 0, //
      0, 0, 4, 0, 0, 5, //
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      // The code as a 2×2 board of cells, the way the real grid draws a
      // guess. A loose Wrap of four bare glyphs broke 3+1 and looked broken.
      Widget cell(int i) => Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: PuzzleSymbol(index: i, size: 24, accent: theme.accent),
          );
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < kPuzzleSlots ~/ 2; r++) ...[
              if (r > 0) const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  cell(r * 2),
                  const SizedBox(width: 8),
                  cell(r * 2 + 1),
                ],
              ),
            ],
          ],
        ),
      );
    }
    return CustomPaint(
      painter: switch (game!) {
        DailyGame.queens => QueensBoardPainter(
          board: _queens,
          theme: theme,
          palette: GamePalette(theme),
          marks: _oneCrown,
        ),
        DailyGame.tango => TangoBoardPainter(board: _tango, theme: theme),
        DailyGame.zip => ZipBoardPainter(
          board: _zip,
          theme: theme,
          path: const [0, 1, 2, 3],
        ),
        DailyGame.sudoku => SudokuBoardPainter(board: _sudoku, theme: theme),
      },
      size: Size.infinite,
    );
  }
}

/// Everything the sheet says about one game.
typedef _Copy = ({
  String name,
  String goal,
  List<String> rules,
  String example,
  String controls,
  String win,
});

_Copy _copyFor(AppLocalizations l10n, DailyGame? game) => switch (game) {
  DailyGame.queens => (
    name: l10n.gameQueensName,
    goal: l10n.gameInfoQueensGoal,
    rules: [
      l10n.gameInfoQueensRule1,
      l10n.gameInfoQueensRule2,
      l10n.gameInfoQueensRule3,
      l10n.gameInfoQueensRule4,
    ],
    example: l10n.gameInfoQueensExample,
    controls: l10n.gameInfoQueensControls,
    win: l10n.gameInfoScoringTimed,
  ),
  DailyGame.tango => (
    name: l10n.gameTangoName,
    goal: l10n.gameInfoTangoGoal,
    rules: [
      l10n.gameInfoTangoRule1,
      l10n.gameInfoTangoRule2,
      l10n.gameInfoTangoRule3,
      l10n.gameInfoTangoRule4,
    ],
    example: l10n.gameInfoTangoExample,
    controls: l10n.gameInfoTangoControls,
    win: l10n.gameInfoScoringTimed,
  ),
  DailyGame.zip => (
    name: l10n.gameZipName,
    goal: l10n.gameInfoZipGoal,
    rules: [
      l10n.gameInfoZipRule1,
      l10n.gameInfoZipRule2,
      l10n.gameInfoZipRule3,
      l10n.gameInfoZipRule4,
      l10n.gameInfoZipRule5,
    ],
    example: l10n.gameInfoZipExample,
    controls: l10n.gameInfoZipControls,
    win: l10n.gameInfoScoringTimed,
  ),
  DailyGame.sudoku => (
    name: l10n.gameSudokuName,
    goal: l10n.gameInfoSudokuGoal,
    rules: [
      l10n.gameInfoSudokuRule1,
      l10n.gameInfoSudokuRule2,
      l10n.gameInfoSudokuRule3,
    ],
    example: l10n.gameInfoSudokuExample,
    controls: l10n.gameInfoSudokuControls,
    win: l10n.gameInfoScoringTimed,
  ),
  null => (
    name: l10n.gameCodeName,
    goal: l10n.gameInfoCodeGoal,
    rules: [
      l10n.gameInfoCodeRule1,
      l10n.gameInfoCodeRule2,
      l10n.gameInfoCodeRule3,
      l10n.gameInfoCodeRule4,
      l10n.gameInfoCodeRule5,
    ],
    example: l10n.gameInfoCodeExample,
    controls: l10n.gameInfoCodeControls,
    // The one game here that is not against a clock. Saying so is the whole
    // reason this is a per-game line rather than one shared sentence.
    win: l10n.gameInfoScoringGuesses,
  ),
};
