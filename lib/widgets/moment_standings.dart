import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/moment.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'moment_rail.dart';
import 'odometer_number.dart';

/// Today's points, by category and by person.
///
/// Reads the same `moments` rows the composer writes — there is no separate
/// points table and no separate write path. A moment with a `tag` scores; one
/// without is just a highlight.
///
/// Defaults to today, deliberately. The whole board is a daily edition, and a
/// standings tile that opened on all-time totals would quietly make the day's
/// scores irrelevant on about day nine.
class MomentStandings extends StatelessWidget {
  const MomentStandings({
    super.key,
    required this.moments,
    required this.viewerId,
  });

  final List<Moment> moments;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final tallies = MomentTally.from(moments);

    if (tallies.isEmpty) {
      return Text(
        l10n.feedBoardStandingsEmpty,
        style: theme.bodySoft.copyWith(color: theme.inkMuted),
      );
    }

    // Category totals across everyone, so the tile leads with what kind of day
    // the group is having before it gets to who is winning.
    final byTag = <MomentTag, int>{};
    for (final m in moments) {
      final t = m.tag;
      if (t != null) byTag[t] = (byTag[t] ?? 0) + 1;
    }
    final ordered = MomentTag.values.where(byTag.containsKey).toList()
      ..sort((a, b) => (byTag[b] ?? 0).compareTo(byTag[a] ?? 0));

    // Name lookup comes off the moments themselves — the author projection is
    // denormalized onto every row precisely so no screen has to resolve a user
    // document to render one.
    final names = <String, String>{
      for (final m in moments) m.userId: m.authorName,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tag in ordered)
          Padding(
            key: ValueKey('tagrow_${tag.wire}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: _TagTotalRow(tag: tag, count: byTag[tag] ?? 0),
          ),
        const SizedBox(height: 6),
        _Leaderboard(tallies: tallies, names: names, viewerId: viewerId),
      ],
    );
  }
}

class _TagTotalRow extends StatelessWidget {
  const _TagTotalRow({required this.tag, required this.count});

  final MomentTag tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final label = MomentTagChip.labelFor(l10n, tag);

    return Row(
      children: [
        Icon(MomentTagChip.iconFor(tag), size: 13, color: theme.accent),
        const SizedBox(width: 8),
        Text(label, style: theme.label),
        const SizedBox(width: 10),
        Expanded(child: _TallyMarks(count: count)),
        const SizedBox(width: 10),
        OdometerNumber(
          value: count,
          style: theme.monoLarge.copyWith(fontSize: 16),
          semanticLabel: '$label: $count',
        ),
      ],
    );
  }
}

/// Five-bar-gate tally marks, drawn rather than typed.
///
/// A number already sits at the end of the row; these are what make the row
/// read as a running score somebody is keeping rather than a database column.
/// Capped, because a group having a good day can put thirty marks on one line
/// and the row has finite width.
class _TallyMarks extends StatelessWidget {
  const _TallyMarks({required this.count});

  final int count;

  /// Beyond this the marks stop and the number carries it. Chosen so five full
  /// gates fit comfortably on the narrowest phone this app supports.
  static const _maxDrawn = 25;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      height: 14,
      child: CustomPaint(
        painter: _TallyPainter(
          count: count.clamp(0, _maxDrawn),
          // Painters here never read context — colours arrive as constructor
          // arguments from the widget that builds them.
          color: theme.inkSoft,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _TallyPainter extends CustomPainter {
  _TallyPainter({required this.count, required this.color});

  final int count;
  final Color color;

  static const _pitch = 4.0; // gap between marks within a gate
  static const _gateGap = 6.0; // extra gap between gates
  static const _height = 11.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final top = (size.height - _height) / 2;
    var x = 0.0;
    for (var i = 0; i < count; i++) {
      final inGate = i % 5;
      if (inGate == 4) {
        // The fifth mark is the diagonal strike across the previous four.
        canvas.drawLine(
          Offset(x - _pitch * 4 - 1, top + _height),
          Offset(x - 1, top),
          paint,
        );
        x += _gateGap;
      } else {
        if (x + _pitch > size.width) return; // ran out of row
        canvas.drawLine(Offset(x, top), Offset(x, top + _height), paint);
        x += _pitch;
      }
    }
  }

  @override
  bool shouldRepaint(_TallyPainter old) =>
      old.count != count || old.color != color;
}

/// Who is winning today.
///
/// Rows live in a fixed-height `Stack` of `AnimatedPositioned`, keyed by user
/// id. Because the key is identity rather than position, a score arriving
/// mid-look SLIDES the affected rows past each other instead of re-rendering
/// the list in a new order — which is the difference between "the standings
/// changed" and "the screen flickered".
class _Leaderboard extends StatelessWidget {
  const _Leaderboard({
    required this.tallies,
    required this.names,
    required this.viewerId,
  });

  final List<MomentTally> tallies;
  final Map<String, String> names;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);

    // Derived from the text scaler rather than hardcoded: the AnimatedPositioned
    // maths below assumes a fixed row height, and a fixed number clips the name
    // at accessibility text sizes.
    final rowHeight = MediaQuery.textScalerOf(
      context,
    ).scale(26).clamp(26.0, 44.0);

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
        SizedBox(
          width: 22,
          child: Text('$rank', style: theme.monoTiny),
        ),
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
        // The categories this person actually scored in, so a row says what
        // kind of day they had and not only how loud it was.
        for (final tag in MomentTag.values)
          if (tally.of(tag) > 0)
            Padding(
              key: ValueKey('${tally.userId}_${tag.wire}'),
              padding: const EdgeInsets.only(left: 6),
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
