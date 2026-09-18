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
import 'destructive_sheet.dart' show SheetGrabber;
import 'puzzle_symbol.dart';

/// What a daily game is, in the plainest words the rules allow.
///
/// This exists because a grid of coloured squares does not explain itself.
/// Every one of these games is well known to the people who already play them
/// and completely opaque to everyone else — the one-line rule under a board's
/// title is a reminder for someone who has played before, not an introduction.
/// Opening a puzzle you do not understand, on a clock, next to your friends'
/// times, is how a daily gets closed and never reopened.
///
/// So the sheet answers three questions in order, and no others: what am I
/// trying to do, what are the actual rules, and what do I tap. The scoring line
/// at the end is there because these are timed and shared, and nobody should
/// discover that by seeing their name on a leaderboard.
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
  final play = await showAdaptiveSheet<bool>(
    context,
    // The rules run long in a few languages; a sheet that can outgrow a small
    // phone must stop at the status bar, which only the route can enforce.
    useSafeArea: true,
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
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.gameInfoOpen,
      shape: FocusRingShape.circle,
      radius: box / 2,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
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
                  color: theme.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.divider),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.question_mark,
                  size: size * 0.40,
                  color: theme.inkSoft,
                ),
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
    // `ModalBottomSheetRoute` strips only the TOP inset, so the home indicator
    // is still ours to clear — under the button rather than under the panel,
    // which stays attached to the bottom edge.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Bounded as a phone's bottom sheet, unbounded as the desktop popover —
    // which already scrolls its whole content, so a Flexible there would have
    // nothing to flex against and throw.
    return LayoutBuilder(
      builder: (context, constraints) => Container(
      decoration: theme.sheetDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fixed, above the scroll view: this is the part a thumb grabs to
          // swipe the sheet away, and a grabber or a close button that scrolls
          // off with the rules is one nobody can reach.
          SizedBox(
            height: 44,
            child: Stack(
              children: [
                // Given its own 16pt so the bar sits at the top of the header
                // rather than centred in it — the grabber pads itself below.
                const Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  height: 16,
                  child: SheetGrabber(),
                ),
                Positioned(
                  top: 6,
                  right: 8,
                  child: _CloseButton(
                    label: l10n.photoChromeCloseSemanticLabel,
                    onTap: () => Navigator.of(context).maybePop(false),
                  ),
                ),
              ],
            ),
          ),
          _flexIfBounded(
            constraints,
            // Clamping, not the platform's bounce: when the rules overflow a
            // short screen, a pull down at the top should read as the sheet
            // being dragged, not as the text inside it stretching away.
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // An example board rather than an icon. The words below
                      // are about crowns and colour regions and a line through
                      // squares, and every one of them is easier to read next
                      // to the thing it is describing.
                      SizedBox(
                        width: 86,
                        height: 86,
                        child: _Example(game: game, theme: theme),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.gameInfoLabel,
                              style: theme.label.copyWith(
                                color: theme.accent,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(copy.name, style: theme.displayMedium),
                            const SizedBox(height: 6),
                            Text(copy.goal, style: theme.bodySoft),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.gameInfoRulesLabel,
                    style: theme.label.copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 10),
                  for (final rule in copy.rules) ...[
                    _Bullet(text: rule),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    l10n.gameInfoControlsLabel,
                    style: theme.label.copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 8),
                  Text(copy.controls, style: theme.bodySoft),
                  const SizedBox(height: 16),
                  Container(height: 1, color: theme.divider),
                  const SizedBox(height: 14),
                  Text(
                    copy.scoring,
                    style: theme.bodySoft.copyWith(color: theme.inkMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.gameInfoSameForEveryone,
                    style: theme.monoTiny.copyWith(color: theme.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          // Pinned under the scroll view, so on a short screen the way in is
          // on screen from the first frame instead of below the rules.
          Padding(
            padding: EdgeInsets.fromLTRB(22, 16, 22, 18 + bottomInset),
            child: _PlayButton(
              label: action,
              onTap: () => Navigator.of(context).maybePop(true),
            ),
          ),
        ],
      ),
      ),
    );
  }

  static Widget _flexIfBounded(BoxConstraints c, Widget child) =>
      c.hasBoundedHeight ? Flexible(child: child) : child;
}

/// The main button. Autofocused, so a keyboard user lands on the way in.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      autofocus: true,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, size: 18, color: theme.accentInk),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.label.copyWith(color: theme.accentInk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The X. A plain disc rather than [GlassCloseButton]: a bottom sheet slides
/// in, and a blur inside it would re-rasterize on every frame of that — the
/// jank `sheet_surface.dart` documents.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.circle,
      radius: 16,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // 32pt drawn, 40pt to a thumb.
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: theme.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: theme.divider),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.close_rounded, size: 17, color: theme.inkSoft),
            ),
          ),
        ),
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
      return Center(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var s = 0; s < kPuzzleSlots; s++)
              PuzzleSymbol(index: s, size: 18, accent: theme.accent),
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

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 10),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Text(text, style: theme.bodySoft.copyWith(color: theme.inkSoft)),
        ),
      ],
    );
  }
}

/// Everything the sheet says about one game.
typedef _Copy = ({
  String name,
  String goal,
  List<String> rules,
  String controls,
  String scoring,
});

_Copy _copyFor(AppLocalizations l10n, DailyGame? game) => switch (game) {
  DailyGame.queens => (
    name: l10n.gameQueensName,
    goal: l10n.gameInfoQueensGoal,
    rules: [
      l10n.gameInfoQueensRule1,
      l10n.gameInfoQueensRule2,
      l10n.gameInfoQueensRule3,
    ],
    controls: l10n.gameInfoQueensControls,
    scoring: l10n.gameInfoScoringTimed,
  ),
  DailyGame.tango => (
    name: l10n.gameTangoName,
    goal: l10n.gameInfoTangoGoal,
    rules: [
      l10n.gameInfoTangoRule1,
      l10n.gameInfoTangoRule2,
      l10n.gameInfoTangoRule3,
    ],
    controls: l10n.gameInfoTangoControls,
    scoring: l10n.gameInfoScoringTimed,
  ),
  DailyGame.zip => (
    name: l10n.gameZipName,
    goal: l10n.gameInfoZipGoal,
    rules: [
      l10n.gameInfoZipRule1,
      l10n.gameInfoZipRule2,
      l10n.gameInfoZipRule3,
    ],
    controls: l10n.gameInfoZipControls,
    scoring: l10n.gameInfoScoringTimed,
  ),
  DailyGame.sudoku => (
    name: l10n.gameSudokuName,
    goal: l10n.gameInfoSudokuGoal,
    rules: [
      l10n.gameInfoSudokuRule1,
      l10n.gameInfoSudokuRule2,
      l10n.gameInfoSudokuRule3,
    ],
    controls: l10n.gameInfoSudokuControls,
    scoring: l10n.gameInfoScoringTimed,
  ),
  null => (
    name: l10n.gameCodeName,
    goal: l10n.gameInfoCodeGoal,
    rules: [
      l10n.gameInfoCodeRule1,
      l10n.gameInfoCodeRule2,
      l10n.gameInfoCodeRule3,
    ],
    controls: l10n.gameInfoCodeControls,
    // The one game here that is not against a clock. Saying so is the whole
    // reason this is a per-game line rather than one shared sentence.
    scoring: l10n.gameInfoScoringGuesses,
  ),
};
