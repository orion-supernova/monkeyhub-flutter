import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../games/how_to/daily_guides.dart';
import '../games/how_to/how_to_play.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/daily_game.dart';
import '../models/puzzle.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart';

/// What a daily game is, in the plainest words the rules allow.
///
/// This exists because a grid of coloured squares does not explain itself.
/// Every one of these games is well known to the people who already play them
/// and completely opaque to everyone else — the one-line rule under a board's
/// title is a reminder for someone who has played before, not an introduction.
/// Opening a puzzle you do not understand, on a clock, next to your friends'
/// times, is how a daily gets closed and never reopened.
///
/// So it is a short swipeable guide (`lib/games/how_to/`): each step one
/// casual line and a little board that plays the move in front of you, which
/// teaches faster than any amount of rules text. The copy is written for a
/// ten-year-old on purpose — short words, digits not number words — because
/// the person reading it is deciding in five seconds whether to play. The
/// scoring line at the end is there because these are timed and shared, and
/// nobody should discover that by seeing their name on a leaderboard.
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
/// timed boards but is scored by guesses rather than by the clock.
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
  final l10n = AppLocalizations.of(context);
  final play = await showHowToPlay(
    context,
    dailyGuide(l10n, game),
    actionLabel: switch (entry) {
      GameInfoEntry.play => l10n.gameInfoPlay,
      GameInfoEntry.resume => l10n.gameInfoContinue,
      GameInfoEntry.review => l10n.gameInfoSeeResult,
    },
    actionIcon: CupertinoIcons.play_fill,
  );
  // After the sheet is fully gone, never from inside it: [onPlay] pushes the
  // game on the TILE's navigator, and a push racing the sheet's own pop is how
  // a route ends up under the one it was meant to replace.
  if (play && context.mounted) onPlay();
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
