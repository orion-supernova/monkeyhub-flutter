import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/medal_disc.dart';
import '../../widgets/score_row.dart' show EmptyFace, PlayerFace;
import '../../widgets/streak_badge.dart';

/// One of the three on a [LeaderPodium].
class PodiumEntry {
  const PodiumEntry({
    required this.userId,
    required this.name,
    required this.isViewer,
    required this.metric,
    required this.semantics,
    this.streak = 0,
    this.onTap,
  });

  final String userId;

  /// Empty for the viewer, who is "You".
  final String name;
  final bool isViewer;

  /// What the board ranks by, drawn under the name: the solved dots on
  /// "Today", a time or "4/6" on one game's board.
  final Widget metric;

  /// The metric read aloud, after the place and the name.
  final String semantics;
  final int streak;

  /// The same as tapping the row would be: the whole result.
  final VoidCallback? onTap;
}

/// The top three, drawn as a podium: first in the middle and raised, second
/// and third either side, each a face with its medal set into the bottom
/// edge. On the page, not in a card: the winners are the one thing on this
/// screen that should not look like a settings row.
///
/// No pedestal blocks. Steps under the faces read as clip art; the height
/// difference alone says who won.
///
/// The three rise in once per change of WHO is on it (keyed on their ids), so
/// a refresh that changes nothing does not replay it, and Reduce Motion
/// skips it entirely.
class LeaderPodium extends StatelessWidget {
  const LeaderPodium({super.key, required this.entries});

  /// Best first, up to three. A place nobody has taken is drawn as an empty
  /// seat, so the podium keeps its shape whether three have played or none.
  final List<PodiumEntry> entries;

  @override
  Widget build(BuildContext context) {
    // Second, first, third, left to right.
    const order = [1, 0, 2];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final i in order)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 22),
                child: i < entries.length
                    ? _Rise(
                        key: ValueKey('podium_${i}_${entries[i].userId}'),
                        // First place lands first.
                        index: i,
                        child: _Slot(place: i + 1, entry: entries[i]),
                      )
                    : _EmptySeat(place: i + 1),
              ),
            ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.place, required this.entry});

  final int place;
  final PodiumEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final first = place == 1;
    final size = first ? 72.0 : 56.0;
    final label = entry.isViewer
        ? sentenceCaseOf(context, l10n.momentRailYouLabel)
        : entry.name;
    final nameStyle = (first
            ? groupedHeaderStyle(theme)
            : groupedTitleStyle(theme).copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ))
        .copyWith(color: entry.isViewer ? theme.accent : null);

    final slot = Semantics(
      container: true,
      button: entry.onTap != null,
      label: [
        '$place. $label',
        entry.semantics,
        if (entry.streak >= 2) l10n.streakDays(entry.streak),
      ].join(', '),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: entry.isViewer ? theme.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: PlayerFace(
                    userId: entry.userId,
                    label: label,
                    size: size,
                  ),
                ),
                Positioned(
                  bottom: -10,
                  child: MedalDisc(
                    rank: place,
                    medal: true,
                    size: 26,
                    border: theme.background,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: nameStyle,
            ),
            const SizedBox(height: 4),
            entry.metric,
            if (entry.streak >= 2) ...[
              const SizedBox(height: 5),
              StreakBadge(entry.streak),
            ],
          ],
        ),
      ),
    );
    final onTap = entry.onTap;
    if (onTap == null) return slot;
    return SpringPress(
      onTap: onTap,
      scale: PressSpec.scaleSmall,
      focusRadius: theme.radiusMd,
      child: slot,
    );
  }
}

/// A podium place nobody has taken yet: the outline of a face in the quiet
/// fill, its place in a grey disc, and a dash for the name. Quiet enough that
/// a podium of one reads as one winner, not as two people missing.
class _EmptySeat extends StatelessWidget {
  const _EmptySeat({required this.place});

  final int place;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final size = place == 1 ? 72.0 : 56.0;
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Padding(
                // The same 2.5 + 2 the taken seats' ring takes, so an empty
                // seat sits at exactly the height of a full one.
                padding: const EdgeInsets.all(4.5),
                child: EmptyFace(size: size),
              ),
              Positioned(
                bottom: -10,
                child: MedalDisc(
                  rank: place,
                  medal: false,
                  size: 26,
                  border: theme.background,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '–',
            style: groupedTitleStyle(theme).copyWith(color: theme.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts one slot in, staggered by [index].
class _Rise extends StatelessWidget {
  const _Rise({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    if (motion.calm) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(theme.motionMed, index, strideMs: 60),
      // motionEntrance rather than motionCurve: some themes' motionCurve
      // overshoots past 1, which Opacity asserts on.
      curve: theme.motionEntrance,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}
