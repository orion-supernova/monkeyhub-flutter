import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/puzzle.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// Today's puzzle results, compact enough to live on the board.
///
/// This exists because the first version put the scoreboard **only** inside the
/// puzzle screen, which meant you had to go and look for it. A daily game whose
/// scores you have to navigate to is a daily game nobody compares — and
/// comparing is the entire reason there is a scoreboard rather than just a
/// puzzle.
///
/// Deliberately shows finished players only. A friend still mid-attempt is
/// absent from the payload on purpose: knowing someone is on their fifth try
/// leaks how hard today is.
class PuzzleScoreStrip extends StatelessWidget {
  const PuzzleScoreStrip({
    super.key,
    required this.state,
    required this.viewerId,
    this.max = 5,
  });

  final PuzzleState state;
  final String viewerId;

  /// How many rows before the strip defers to the full screen.
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final scores = state.scores;
    if (scores.isEmpty) return const SizedBox.shrink();

    final shown = scores.take(max).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++)
          TweenAnimationBuilder<double>(
            // Identity, never index — this list reorders as people finish.
            key: ValueKey('score_${shown[i].userId}'),
            tween: Tween(begin: 0, end: 1),
            duration: motion.stagger(theme.motionMed, i, strideMs: 45),
            curve: motion.c(theme.motionEntrance),
            builder: (context, v, child) => Transform.translate(
              offset: Offset(0, (1 - v) * 6),
              child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ScoreRow(
                rank: i + 1,
                score: shown[i],
                isViewer: shown[i].userId == viewerId,
              ),
            ),
          ),
        if (scores.length > shown.length)
          Text(
            l10n.momentActivityMoreCount(scores.length - shown.length),
            style: theme.monoTiny.copyWith(color: theme.inkMuted),
          ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.rank,
    required this.score,
    required this.isViewer,
  });

  final int rank;
  final PuzzleScore score;
  final bool isViewer;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        SizedBox(width: 20, child: Text('$rank', style: theme.monoTiny)),
        Expanded(
          child: Text(
            isViewer ? l10n.momentRailYouLabel : score.name,
            style: isViewer
                ? theme.bodyEmph.copyWith(color: theme.accent)
                : theme.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // The emoji grid's first row, as a glanceable trace of how it went.
        // Positionless, like the pegs themselves — it reveals nothing about the
        // answer to anyone who has not played.
        if (score.feedback.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text(
              score.feedback.last.shareRow,
              style: theme.monoTiny,
              maxLines: 1,
            ),
          ),
        Text(
          score.solved
              ? '${score.guessCount}/$kPuzzleMaxGuesses'
              : 'X/$kPuzzleMaxGuesses',
          style: theme.monoLarge.copyWith(
            fontSize: 14,
            color: score.solved ? theme.ink : theme.inkMuted,
          ),
        ),
      ],
    );
  }
}
