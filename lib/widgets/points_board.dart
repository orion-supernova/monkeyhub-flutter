import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/moment.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'moment_rail.dart';
import 'odometer_number.dart';

/// The points board: what happened to everyone today, and who is winning.
///
/// **Text-first, on purpose.** A point is a sentence — "washed the car, it
/// rained at four" — and a photo is optional garnish. The first version of this
/// rendered points as photo cards in the highlights rail, which got it exactly
/// backwards: it implied you needed a picture to score, and buried the line of
/// text that IS the joke.
///
/// So this is a list of one-liners with a running tally on top, and the
/// highlights rail no longer carries tagged rows at all.
class PointsBoard extends StatelessWidget {
  const PointsBoard({
    super.key,
    required this.points,
    required this.viewerId,
    required this.onAdd,
    required this.onOpen,
    this.max = 8,
  });

  /// Tagged moments only — [FeedStore.points].
  final List<Moment> points;
  final String viewerId;
  final VoidCallback onAdd;
  final void Function(Moment moment) onOpen;

  /// How many lines to show before the board defers to the activity river.
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final tallies = MomentTally.from(points);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tallies.isEmpty)
          Text(
            l10n.feedBoardStandingsEmpty,
            style: theme.bodySoft.copyWith(color: theme.inkMuted),
          )
        else ...[
          _Leaderboard(tallies: tallies, points: points, viewerId: viewerId),
          const SizedBox(height: 16),
          Container(height: 1, color: theme.divider),
          const SizedBox(height: 12),
          for (var i = 0; i < points.length && i < max; i++)
            _PointLine(
              key: ValueKey('pt_${points[i].id}'),
              moment: points[i],
              viewerId: viewerId,
              index: i,
              onTap: () => onOpen(points[i]),
            ),
          if (points.length > max) ...[
            const SizedBox(height: 4),
            Text(
              l10n.momentActivityMoreCount(points.length - max),
              style: theme.monoTiny.copyWith(color: theme.inkMuted),
            ),
          ],
        ],
        const SizedBox(height: 14),
        _AddPointButton(onTap: onAdd),
      ],
    );
  }
}

/// Who is winning today.
///
/// Rows are `AnimatedPositioned` keyed by user id inside a fixed-height Stack,
/// so a point landing mid-look SLIDES the affected rows past each other rather
/// than re-rendering the list in a new order.
class _Leaderboard extends StatelessWidget {
  const _Leaderboard({
    required this.tallies,
    required this.points,
    required this.viewerId,
  });

  final List<MomentTally> tallies;
  final List<Moment> points;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);

    // Names come off the moments themselves — the author projection is
    // denormalized onto every row precisely so no screen resolves a user doc.
    final names = <String, String>{
      for (final m in points) m.userId: m.authorName,
    };

    // Derived from the text scaler rather than hardcoded: the positioning maths
    // assumes a fixed row height, and a flat number clips at large text sizes.
    final rowHeight = MediaQuery.textScalerOf(
      context,
    ).scale(28).clamp(28.0, 46.0);

    return SizedBox(
      height: rowHeight * tallies.length,
      child: Stack(
        children: [
          for (var i = 0; i < tallies.length; i++)
            AnimatedPositioned(
              key: ValueKey('rank_${tallies[i].userId}'),
              duration: motion.d(theme.motionMed),
              curve: motion.c(theme.motionEntrance),
              top: i * rowHeight,
              left: 0,
              right: 0,
              height: rowHeight,
              child: _LeaderRow(
                rank: i + 1,
                name: tallies[i].userId == viewerId
                    ? l10n.momentRailYouLabel
                    : (names[tallies[i].userId] ?? ''),
                tally: tallies[i],
                highlight: tallies[i].userId == viewerId,
              ),
            ),
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.tally,
    required this.highlight,
  });

  final int rank;
  final String name;
  final MomentTally tally;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        SizedBox(width: 20, child: Text('$rank', style: theme.monoTiny)),
        Expanded(
          child: Text(
            name,
            style: highlight
                ? theme.bodyEmph.copyWith(color: theme.accent)
                : theme.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Which categories they scored in, so a row says what KIND of day they
        // had rather than only how loud it was.
        for (final tag in MomentTag.values)
          if (tally.of(tag) > 0)
            Padding(
              key: ValueKey('${tally.userId}_${tag.wire}'),
              padding: const EdgeInsets.only(left: 5),
              child: Icon(
                MomentTagChip.iconFor(tag),
                size: 11,
                color: theme.inkMuted,
              ),
            ),
        const SizedBox(width: 10),
        OdometerNumber(
          value: tally.total,
          style: theme.monoLarge.copyWith(fontSize: 15),
          semanticLabel: '$name: ${tally.total}',
        ),
      ],
    );
  }
}

/// One point, as the line of text it actually is.
class _PointLine extends StatelessWidget {
  const _PointLine({
    super.key,
    required this.moment,
    required this.viewerId,
    required this.index,
    required this.onTap,
  });

  final Moment moment;
  final String viewerId;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final tag = moment.tag;
    if (tag == null) return const SizedBox.shrink();

    final mine = moment.userId == viewerId;
    // Verb agreement makes a single interpolated template impossible in
    // Turkish, Japanese, Korean and others — "sen … paylaştı" is simply wrong.
    // Two keys, one per grammatical person, is the only correct shape.
    final headline = mine
        ? l10n.pointLineSelf(MomentTagChip.labelFor(l10n, tag))
        : l10n.pointLineOther(
            moment.authorName,
            MomentTagChip.labelFor(l10n, tag),
          );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(theme.motionMed, index, strideMs: 40),
      curve: motion.c(theme.motionEntrance),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 8),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: headline,
        radius: theme.radiusSm,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 9),
                  child: Icon(
                    MomentTagChip.iconFor(tag),
                    size: 13,
                    color: theme.accent,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: theme.monoTiny,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (moment.caption?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        // The line of text IS the point. It gets the readable
                        // style; the "X took a JINX" header above is metadata.
                        Text(
                          moment.caption!,
                          style: theme.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (moment.mediaStorageId != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Icon(
                      Icons.image_outlined,
                      size: 13,
                      color: theme.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPointButton extends StatelessWidget {
  const _AddPointButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.pointsBoardAdd,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: theme.accentSoft,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 15, color: theme.accent),
              const SizedBox(width: 7),
              Text(
                l10n.pointsBoardAdd,
                style: theme.label.copyWith(color: theme.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
