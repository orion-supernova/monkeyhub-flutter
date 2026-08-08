import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/moment.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'moment_rail.dart';

/// The chronological tail of the board: everything that happened today, in
/// order, one line each.
///
/// Deliberately text-forward and low-key. The three blocks above it — the
/// rail, the puzzle, the standings — are the curated summary; this is the
/// catch-all that keeps them from having to be exhaustive. Without that split
/// the four sections end up restating each other, which is the usual way a
/// feed screen dies.
class MomentActivity extends StatelessWidget {
  const MomentActivity({
    super.key,
    required this.moments,
    required this.viewerId,
    required this.onOpen,
    this.max = 12,
  });

  final List<Moment> moments;
  final String viewerId;

  /// Opens a moment. The rect is the row's own place on screen — a row shows no
  /// picture, so the viewer's card grows out of the row instead of flying one.
  final void Function(Moment moment, Rect? origin) onOpen;

  /// How many rows to show before stopping.
  ///
  /// The board is a summary of one day, not an infinite scroll, and a phone
  /// screen that needs six flicks before anything interesting is a board
  /// nobody reaches the bottom of.
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    if (moments.isEmpty) {
      return Text(
        l10n.feedBoardActivityEmpty,
        style: theme.bodySoft.copyWith(color: theme.inkMuted),
      );
    }

    final shown = moments.take(max).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++)
          _ActivityRow(
            // Identity, never index — this list reorders as moments arrive.
            key: ValueKey('act_${shown[i].id}'),
            moment: shown[i],
            viewerId: viewerId,
            index: i,
            onTap: (origin) => onOpen(shown[i], origin),
          ),
        if (moments.length > shown.length) ...[
          const SizedBox(height: 6),
          // States what is hidden rather than silently truncating — a list that
          // stops without saying so reads as "that was everything".
          Text(
            l10n.momentActivityMoreCount(moments.length - shown.length),
            style: theme.monoTiny.copyWith(color: theme.inkMuted),
          ),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    super.key,
    required this.moment,
    required this.viewerId,
    required this.index,
    required this.onTap,
  });

  final Moment moment;
  final String viewerId;
  final int index;

  /// Handed this row's own screen rect — see [MomentActivity.onOpen].
  final void Function(Rect? origin) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final mine = moment.userId == viewerId;
    void open() => onTap(tapOriginRect(context));
    final tag = moment.tag;
    // Verb agreement rules this out of a single interpolated template. Turkish
    // conjugates the verb for person, so "{who} paylaştı" with who="sen" reads
    // as "you posted[3rd person]" — wrong, and invisibly so to anyone reading
    // only the English. Japanese and Korean have the same problem via
    // politeness forms. Two keys per sentence, one per grammatical person, is
    // the only shape that can be correct in all twelve locales.
    final headline = mine
        ? (tag == null
              ? l10n.momentActivityPostedHighlightSelf
              : l10n.momentActivityScoredSelf(
                  MomentTagChip.labelFor(l10n, tag),
                ))
        : (tag == null
              ? l10n.momentActivityPostedHighlight(moment.authorName)
              : l10n.momentActivityScored(
                  moment.authorName,
                  MomentTagChip.labelFor(l10n, tag),
                ));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(theme.motionMed, index, strideMs: 35),
      curve: motion.c(theme.motionEntrance),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 8),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: FocusableTap(
        onTap: open,
        semanticLabel: headline,
        radius: theme.radiusSm,
        child: GestureDetector(
          onTap: open,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 10),
                  child: Icon(
                    tag == null
                        ? Icons.photo_outlined
                        : MomentTagChip.iconFor(tag),
                    size: 13,
                    color: tag == null ? theme.inkMuted : theme.accent,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: theme.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (moment.caption?.isNotEmpty == true)
                        Text(
                          moment.caption!,
                          style: theme.bodySoft.copyWith(color: theme.inkMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(_ago(l10n, moment.createdAt), style: theme.monoTiny),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact relative time.
  ///
  /// Everything on this board is from today, so this never needs a date — and
  /// capping at hours is what keeps the column narrow enough to sit beside a
  /// name without squeezing it.
  static String _ago(AppLocalizations l10n, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return l10n.momentActivityJustNow;
    if (d.inHours < 1) return l10n.momentActivityMinutesAgo(d.inMinutes);
    return l10n.momentActivityHoursAgo(d.inHours);
  }
}
