import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/game_play.dart';
import '../models/moment.dart';
import '../screens/games/leaderboard_screen.dart' show leaderboardGameName;
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'moment_rail.dart';
import 'meta_text.dart';

/// The chronological tail of the board: today's highlights and finished daily
/// games, newest first, one line each.
///
/// Highlights, not points. Points have their own home on the standings board,
/// which tallies them and tells each one's story, and handing them to this list
/// as well drew every point twice on one screen — the Feed passes
/// `FeedStore.highlights`, never `moments`. Game results are the opposite case:
/// the games band above shows only the viewer's own tiles, so a friend's score
/// had nowhere on the Feed to appear but here.
///
/// Deliberately text-forward and low-key. The blocks above it — the rail, the
/// games, the standings — are the curated summary; this is the plain log
/// under them. Without that split the sections end up restating each other,
/// which is the usual way a feed screen dies.
class MomentActivity extends StatelessWidget {
  const MomentActivity({
    super.key,
    required this.moments,
    required this.viewerId,
    required this.onOpen,
    this.plays = const [],
    this.onOpenPlay,
    this.max = 12,
  });

  final List<Moment> moments;
  final String viewerId;

  /// Opens a moment. The rect is the row's own place on screen — a row shows no
  /// picture, so the viewer's card grows out of the row instead of flying one.
  final void Function(Moment moment, Rect? origin) onOpen;

  /// Finished daily results, interleaved with [moments] by time.
  final List<GamePlay> plays;

  /// Opens the scoreboard a result was posted on.
  final void Function(GamePlay play)? onOpenPlay;

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

    // Records rather than a shared base class: the two rows have nothing in
    // common but a timestamp, and a highlight is not something a game is.
    final entries = <({DateTime at, Moment? moment, GamePlay? play})>[
      for (final m in moments) (at: m.createdAt, moment: m, play: null),
      for (final p in plays) (at: p.finishedAt, moment: null, play: p),
    ]..sort((a, b) => b.at.compareTo(a.at));

    if (entries.isEmpty) {
      return Text(
        l10n.feedBoardActivityEmpty,
        style: theme.bodySoft.copyWith(color: theme.inkMuted),
      );
    }

    final shown = entries.take(max).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++)
          if (shown[i].moment case final m?)
            _ActivityRow(
              // Identity, never index — this list reorders as moments arrive.
              key: ValueKey('act_${m.id}'),
              moment: m,
              viewerId: viewerId,
              index: i,
              onTap: (origin) => onOpen(m, origin),
            )
          else if (shown[i].play case final p?)
            _PlayRow(
              key: ValueKey('play_${p.id}'),
              play: p,
              viewerId: viewerId,
              index: i,
              onTap: onOpenPlay == null ? null : () => onOpenPlay!(p),
            ),
        if (entries.length > shown.length) ...[
          const SizedBox(height: 6),
          // States what is hidden rather than silently truncating — a list that
          // stops without saying so reads as "that was everything".
          Text(
            l10n.momentActivityMoreCount(entries.length - shown.length),
            style: metaText(theme, color: theme.inkMuted),
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
    final l10n = AppLocalizations.of(context);
    final mine = moment.userId == viewerId;
    // `moment.mine` rather than the id comparison above: the server decides
    // what counts as yours, and your own rows are always seen.
    final unseen = !moment.mine && !moment.seen;
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

    return _RowFrame(
      index: index,
      headline: headline,
      detail: moment.caption,
      at: moment.createdAt,
      badge: unseen,
      onTap: () => onTap(tapOriginRect(context)),
      icon: Icon(
        tag == null ? CupertinoIcons.photo : MomentTagChip.iconFor(tag),
        size: 13,
        color: tag == null ? theme.inkMuted : theme.accent,
      ),
    );
  }
}

/// One finished daily result: "Ece solved Queens", with the score under it.
class _PlayRow extends StatelessWidget {
  const _PlayRow({
    super.key,
    required this.play,
    required this.viewerId,
    required this.index,
    required this.onTap,
  });

  final GamePlay play;
  final String viewerId;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final mine = play.userId == viewerId;
    final game = play.game;
    // Two keys per sentence, one per grammatical person, for the verb
    // agreement reason spelled out on [_ActivityRow]. The code gets sentences
    // of its own: its name is a noun phrase ("The code"), and dropped into the
    // shared template it read "You solved The code".
    final String headline;
    if (game == null) {
      headline = play.solved
          ? (mine
                ? l10n.momentActivityCodeSolvedSelf
                : l10n.momentActivityCodeSolved(play.name))
          : (mine
                ? l10n.momentActivityCodeMissedSelf
                : l10n.momentActivityCodeMissed(play.name));
    } else {
      final name = leaderboardGameName(l10n, game);
      headline = play.solved
          ? (mine
                ? l10n.momentActivityGameSolvedSelf(name)
                : l10n.momentActivityGameSolved(name, play.name))
          : (mine
                ? l10n.momentActivityGameMissedSelf(name)
                : l10n.momentActivityGameMissed(name, play.name));
    }
    return _RowFrame(
      index: index,
      headline: headline,
      detail: play.result,
      at: play.finishedAt,
      onTap: onTap,
      icon: Icon(
        CupertinoIcons.game_controller,
        size: 13,
        color: play.solved ? theme.accent : theme.inkMuted,
      ),
    );
  }
}

/// The row both kinds of entry draw: a glyph in the gutter, a headline with an
/// optional muted second line, and the time on the right.
///
/// Shared so a game result and a highlight sit on exactly the same grid; the
/// list's left edge is what makes it scannable.
class _RowFrame extends StatelessWidget {
  const _RowFrame({
    required this.index,
    required this.headline,
    required this.icon,
    required this.at,
    required this.onTap,
    this.detail,
    this.badge = false,
  });

  final int index;
  final String headline;
  final Widget icon;
  final DateTime at;
  final VoidCallback? onTap;
  final String? detail;

  /// Whether the glyph carries the unseen dot.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 10),
            // The category glyph, badged when this row has not been looked at.
            // Badged rather than given its own column: an unread marker in the
            // gutter would indent every unseen row differently from every seen
            // one, and the list's left edge is the thing that makes it
            // scannable.
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                icon,
                if (badge)
                  const Positioned(
                    top: -5,
                    right: -6,
                    child: MomentUnseenDot(size: 9),
                  ),
              ],
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
                if (detail?.isNotEmpty == true)
                  Text(
                    detail!,
                    style: theme.bodySoft.copyWith(color: theme.inkMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(_ago(l10n, at), style: metaText(theme)),
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(theme.motionMed, index, strideMs: 35),
      curve: motion.c(theme.motionEntrance),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 8),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: onTap == null
          ? row
          : FocusableTap(
              onTap: onTap!,
              semanticLabel: headline,
              radius: theme.radiusSm,
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: row,
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
