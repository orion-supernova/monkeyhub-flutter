import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/feed_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/game_play.dart';
import '../models/moment.dart';
import '../screens/games/leaderboard_standings.dart' show leaderboardGameName;
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'meta_text.dart';
import 'moment_rail.dart';
import 'remote_image.dart';
import 'score_row.dart';
import 'sheet_kit.dart';

/// The chronological tail of the board: what FRIENDS did today, newest
/// first, one line each with their face.
///
/// Highlights, not points: points have their own board, and handing them
/// here as well drew every point twice. And friends, not you: your own
/// games are on the games band right above, and your own highlights on the
/// rail; listing them again here was the board restating itself.
///
/// The newest [inline] rows, then "See all" for the rest ([showActivitySheet]).
/// A summary of one day, not an infinite scroll.
class MomentActivity extends StatelessWidget {
  const MomentActivity({
    super.key,
    required this.moments,
    required this.viewerId,
    required this.api,
    required this.onOpen,
    this.plays = const [],
    this.onOpenPlay,
    this.faceOf,
    this.inline = 10,
  });

  final List<Moment> moments;
  final String viewerId;
  final ChatApi api;

  /// Opens a moment. The rect is the row's own place on screen.
  final void Function(Moment moment, Rect? origin) onOpen;

  /// Finished daily results, interleaved with [moments] by time.
  final List<GamePlay> plays;

  /// Opens the scoreboard a result was posted on.
  final void Function(GamePlay play)? onOpenPlay;

  /// A friend's profile picture, for a game result (which carries no face of
  /// its own). Highlights bring theirs.
  final String? Function(String userId)? faceOf;

  final int inline;

  /// Every entry, friends' only, newest first.
  static List<({DateTime at, Moment? moment, GamePlay? play})> entriesOf(
    List<Moment> moments,
    List<GamePlay> plays,
    String viewerId,
  ) =>
      [
        for (final m in moments)
          if (!m.mine && m.userId != viewerId)
            (at: m.createdAt, moment: m, play: null),
        for (final p in plays)
          if (p.userId != viewerId) (at: p.finishedAt, moment: null, play: p),
      ]..sort((a, b) => b.at.compareTo(a.at));

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final entries = entriesOf(moments, plays, viewerId);

    if (entries.isEmpty) {
      return Text(
        l10n.feedBoardActivityEmpty,
        style: theme.bodySoft.copyWith(color: theme.inkMuted),
      );
    }

    final shown = entries.take(inline).toList();
    return GroupedSection(
      margin: EdgeInsets.zero,
      children: [
        for (var i = 0; i < shown.length; i++)
          ActivityRow(
            // Identity, never index: this list reorders as things arrive.
            key: ValueKey(_keyOf(shown[i].moment, shown[i].play)),
            moment: shown[i].moment,
            play: shown[i].play,
            viewerId: viewerId,
            api: api,
            index: i,
            faceOf: faceOf,
            onOpen: onOpen,
            onOpenPlay: onOpenPlay,
          ),
        if (entries.length > shown.length)
          GroupedRow(
            title: sentenceCaseOf(context, l10n.pageSectionSeeAll),
            value: '${entries.length}',
            chevron: true,
            onTap: () => showActivitySheet(
              context,
              viewerId: viewerId,
              api: api,
              faceOf: faceOf,
              onOpen: onOpen,
              onOpenPlay: onOpenPlay,
            ),
          ),
      ],
    );
  }
}

/// A row's identity: `act_<moment>` or `play_<result>`, never its index.
String _keyOf(Moment? m, GamePlay? p) =>
    m != null ? 'act_${m.id}' : 'play_${p!.id}';

/// One thing a friend did: their face, one line saying it, and on the
/// trailing edge the score (a game) or the picture (a highlight).
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.viewerId,
    required this.api,
    required this.onOpen,
    this.moment,
    this.play,
    this.onOpenPlay,
    this.faceOf,
    this.index = 0,
  });

  final Moment? moment;
  final GamePlay? play;
  final String viewerId;
  final ChatApi api;
  final void Function(Moment moment, Rect? origin) onOpen;
  final void Function(GamePlay play)? onOpenPlay;
  final String? Function(String userId)? faceOf;
  final int index;

  @override
  Widget build(BuildContext context) {
    final m = moment;
    final p = play;
    final Widget row;
    if (m != null) {
      row = _momentRow(context, m);
    } else if (p != null) {
      row = _playRow(context, p);
    } else {
      return const SizedBox.shrink();
    }
    return _Entrance(index: index, child: row);
  }

  Widget _momentRow(BuildContext context, Moment moment) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final tag = moment.tag;
    final mine = moment.userId == viewerId;
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

    final caption = moment.caption?.trim() ?? '';
    final thumb = moment.thumbStorageId;
    return Builder(
      builder: (context) => PersonRow(
        avatar: PlayerFace(
          userId: moment.userId,
          label: moment.authorName,
          size: kPersonRowAvatar,
          storageId: moment.authorAvatarStorageId,
          dot: !moment.mine && !moment.seen,
          badge: tag == null
              ? null
              : Icon(
                  MomentTagChip.iconFor(tag),
                  size: 11,
                  color: momentTagColor(theme, tag),
                ),
        ),
        title: headline,
        titleMaxLines: 2,
        subtitle: [
          if (caption.isNotEmpty) caption,
          relativeAgo(l10n, moment.createdAt),
        ].join(' · '),
        semanticLabel: headline,
        onTap: () => onOpen(moment, tapOriginRect(context)),
        trailing: thumb == null
            ? null
            : RemoteImage(
                storageId: thumb,
                api: api,
                width: 36,
                height: 36,
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
      ),
    );
  }

  Widget _playRow(BuildContext context, GamePlay play) {
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
    final open = onOpenPlay;
    return PersonRow(
      avatar: PlayerFace(
        userId: play.userId,
        label: play.name,
        size: kPersonRowAvatar,
        storageId: faceOf?.call(play.userId),
        // A miss reads as one at a glance; a solve needs no mark.
        badge: play.solved
            ? null
            : Icon(
                CupertinoIcons.game_controller,
                size: 11,
                color: theme.inkMuted,
              ),
      ),
      title: headline,
      titleMaxLines: 2,
      subtitle: relativeAgo(l10n, play.finishedAt),
      semanticLabel: '$headline, ${play.result}',
      onTap: open == null ? null : () => open(play),
      trailing: ScoreText(play.result, muted: !play.solved),
    );
  }
}

/// A row's first appearance: risen and faded in, staggered by [index].
/// Keyed by identity upstream, so only a NEW row plays it.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    if (motion.calm) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(theme.motionMed, index, strideMs: 35),
      curve: motion.c(theme.motionEntrance),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 8),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}

/// Everything friends did today, newest first, in a sheet; what "See all"
/// opens. Reads the board live.
Future<void> showActivitySheet(
  BuildContext context, {
  required String viewerId,
  required ChatApi api,
  required void Function(Moment moment, Rect? origin) onOpen,
  void Function(GamePlay play)? onOpenPlay,
  String? Function(String userId)? faceOf,
}) {
  return showAdaptiveSheet<void>(
    context,
    useSafeArea: true,
    builder: (sheet) {
      final l10n = AppLocalizations.of(sheet);
      return SheetFrame(
        title: sentenceCaseOf(sheet, l10n.feedBoardActivityLabel),
        showClose: true,
        padding: EdgeInsets.zero,
        // Tall, and the list runs to the bottom edge under the home
        // indicator: a long list, not a card with a solid foot.
        maxHeightFraction: 0.92,
        scrollsUnderInset: true,
        child: ListenableBuilder(
          listenable: FeedStore.instance,
          builder: (context, _) {
            final store = FeedStore.instance;
            final entries =
                MomentActivity.entriesOf(store.highlights, store.plays, viewerId);
            return ListView(
              padding: sheetListPadding(context),
              children: [
                SheetRise(
                  child: SheetGroup(
                    children: [
                      for (final e in entries)
                        ActivityRow(
                          key: ValueKey(_keyOf(e.moment, e.play)),
                          moment: e.moment,
                          play: e.play,
                          viewerId: viewerId,
                          api: api,
                          faceOf: faceOf,
                          onOpen: onOpen,
                          // The leaderboard is a page: leave the sheet first,
                          // or it would open behind it.
                          onOpenPlay: onOpenPlay == null
                              ? null
                              : (p) {
                                  Navigator.of(context).pop();
                                  onOpenPlay(p);
                                },
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
