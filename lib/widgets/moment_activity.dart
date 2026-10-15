import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, RenderSliverPadding;

import '../backend/chat_api.dart';
import '../data/feed_store.dart';
import '../data/games_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/game_play.dart';
import '../models/moment.dart';
import '../screens/games/leaderboard_standings.dart' show leaderboardGameName;
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'game_stat_line.dart';
import 'game_tile.dart' show GameAvatar;
import 'ios_kit.dart';
import 'meta_text.dart';
import 'moment_rail.dart';
import 'remote_image.dart';
import 'score_row.dart';
import 'sheet_kit.dart';

/// One line of Activity: one friend's highlights, or one friend's finished
/// games. Exactly one of the two lists is filled, newest first.
///
/// A run: what one friend did back to back, with nothing from anyone else in
/// between, however far apart in the day. Someone who posts three
/// highlights or plays the dailies in a row is one thing that happened, not
/// six rows pushing everything else off the list. Anything in between splits
/// the run, so the list stays strictly in time order. One reads exactly as
/// it always did; two or more collapse into a row that opens in place.
typedef ActivityEntry = ({
  DateTime at,
  List<Moment> moments,
  List<GamePlay> plays,
});

/// An entry's identity, never its index: `moments_<oldest>` or
/// `plays_<oldest>`. The OLDEST item, since a run only ever grows at its
/// newest end: a second game arriving on top turns the row into a group
/// under the SAME key and the row does not replay its entrance.
String activityKeyOf(ActivityEntry e) => e.moments.isNotEmpty
    ? 'moments_${e.moments.last.id}'
    : 'plays_${e.plays.last.id}';

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
class MomentActivity extends StatefulWidget {
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

  /// Top-level rows shown before "See all". A group is one row however many
  /// games it holds, and opening it never pushes another row out.
  final int inline;

  /// Every entry, friends' only, newest first: back-to-back runs of one
  /// friend's highlights or one friend's games folded into one entry each,
  /// placed at their newest. Highlights and games never share a run: one
  /// opens a picture, the other a scoreboard.
  static List<ActivityEntry> entriesOf(
    List<Moment> moments,
    List<GamePlay> plays,
    String viewerId,
  ) {
    final items =
        <({DateTime at, String userId, Moment? moment, GamePlay? play})>[
          for (final m in moments)
            if (!m.mine && m.userId != viewerId)
              (at: m.createdAt, userId: m.userId, moment: m, play: null),
          for (final p in plays)
            if (p.userId != viewerId)
              (at: p.finishedAt, userId: p.userId, moment: null, play: p),
        ]..sort((a, b) => b.at.compareTo(a.at));
    final entries = <ActivityEntry>[];
    for (final i in items) {
      final last = entries.isEmpty ? null : entries.last;
      final m = i.moment;
      final p = i.play;
      if (m != null &&
          last != null &&
          last.moments.isNotEmpty &&
          last.moments.first.userId == i.userId) {
        last.moments.add(m);
      } else if (p != null &&
          last != null &&
          last.plays.isNotEmpty &&
          last.plays.first.userId == i.userId) {
        last.plays.add(p);
      } else {
        entries.add((
          at: i.at,
          moments: [?m],
          plays: [?p],
        ));
      }
    }
    return entries;
  }

  @override
  State<MomentActivity> createState() => _MomentActivityState();
}

class _MomentActivityState extends State<MomentActivity> {
  /// Groups the reader has opened, by key: survives live refreshes, resets
  /// when the screen goes.
  final _open = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final w = widget;
    final entries = MomentActivity.entriesOf(w.moments, w.plays, w.viewerId);

    if (entries.isEmpty) {
      return Text(
        l10n.feedBoardActivityEmpty,
        style: theme.bodySoft.copyWith(color: theme.inkMuted),
      );
    }

    final shown = entries.take(w.inline).toList();
    return GroupedSection(
      margin: EdgeInsets.zero,
      children: [
        for (var i = 0; i < shown.length; i++)
          ActivityRow(
            key: ValueKey(activityKeyOf(shown[i])),
            entry: shown[i],
            viewerId: w.viewerId,
            api: w.api,
            index: i,
            faceOf: w.faceOf,
            onOpen: w.onOpen,
            onOpenPlay: w.onOpenPlay,
            open: _open.contains(activityKeyOf(shown[i])),
            onToggle: () => setState(() {
              final k = activityKeyOf(shown[i]);
              if (!_open.remove(k)) _open.add(k);
            }),
          ),
        if (entries.length > shown.length)
          GroupedRow(
            title: sentenceCaseOf(context, l10n.pageSectionSeeAll),
            value: '${entries.length}',
            chevron: true,
            onTap: () => showActivitySheet(
              context,
              viewerId: w.viewerId,
              api: w.api,
              faceOf: w.faceOf,
              onOpen: w.onOpen,
              onOpenPlay: w.onOpenPlay,
            ),
          ),
      ],
    );
  }
}

/// One thing a friend did: their face, one line saying it, and on the
/// trailing edge the score (a game) or the picture (a highlight). A friend's
/// several games are one row that opens in place onto each game's own line.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.entry,
    required this.viewerId,
    required this.api,
    required this.onOpen,
    this.onOpenPlay,
    this.faceOf,
    this.index = 0,
    this.open = false,
    this.onToggle,
  });

  final ActivityEntry entry;
  final String viewerId;
  final ChatApi api;
  final void Function(Moment moment, Rect? origin) onOpen;
  final void Function(GamePlay play)? onOpenPlay;
  final String? Function(String userId)? faceOf;
  final int index;

  /// A group's state, held by the list so it survives refreshes.
  final bool open;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final moments = entry.moments;
    final plays = entry.plays;
    final Widget row;
    if (moments.length == 1) {
      row = _momentRow(context, moments.first);
    } else if (moments.isNotEmpty) {
      row = _MomentRun(
        moments: moments,
        api: api,
        open: open,
        onToggle: onToggle,
        onOpen: onOpen,
      );
    } else if (plays.length == 1) {
      row = _playRow(context, plays.first);
    } else if (plays.isNotEmpty) {
      row = _PlayRun(
        plays: plays,
        open: open,
        onToggle: onToggle,
        onOpenPlay: onOpenPlay,
        face: faceOf?.call(plays.first.userId),
      );
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
        subtitle: caption,
        stamp: relativeAgo(l10n, moment.createdAt),
        semanticLabel: [
          headline,
          if (caption.isNotEmpty) caption,
          relativeAgo(l10n, moment.createdAt),
        ].join(', '),
        onTap: () => onOpen(moment, tapOriginRect(context)),
        trailing: thumb == null
            ? null
            : RemoteImage(
                storageId: thumb,
                api: api,
                width: 32,
                height: 32,
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
      ),
    );
  }

  Widget _playRow(BuildContext context, GamePlay play) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final headline = playHeadline(l10n, play, mine: play.userId == viewerId);
    final stats = playStatText(l10n, play);
    final result = playResultText(context, play);
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
      // Mistakes and hints, as the leaderboard's result sheet has them; a
      // clean run says nothing.
      subtitle: stats,
      stamp: relativeAgo(l10n, play.finishedAt),
      semanticLabel: [
        headline,
        result,
        ?stats,
        relativeAgo(l10n, play.finishedAt),
      ].join(', '),
      onTap: open == null ? null : () => open(play),
      trailing: ScoreText(result, muted: !play.solved),
    );
  }
}

/// "Ece solved Queens" / "You cracked the code": one finished game as a
/// sentence. Two keys per sentence, one per grammatical person, for verb
/// agreement. The code gets sentences of its own: its name is a noun phrase
/// ("The code"), and dropped into the shared template it read "You solved
/// The code".
String playHeadline(AppLocalizations l10n, GamePlay play, {bool mine = false}) {
  final game = play.game;
  if (game == null) {
    return play.solved
        ? (mine
              ? l10n.momentActivityCodeSolvedSelf
              : l10n.momentActivityCodeSolved(play.name))
        : (mine
              ? l10n.momentActivityCodeMissedSelf
              : l10n.momentActivityCodeMissed(play.name));
  }
  final name = leaderboardGameName(l10n, game);
  return play.solved
      ? (mine
            ? l10n.momentActivityGameSolvedSelf(name)
            : l10n.momentActivityGameSolved(name, play.name))
      : (mine
            ? l10n.momentActivityGameMissedSelf(name)
            : l10n.momentActivityGameMissed(name, play.name));
}

/// The trailing score: the time, `3/6` for the code, and "Gave up" for a
/// surrendered timed board, which carries no time to show.
String playResultText(BuildContext context, GamePlay play) =>
    play.game != null && !play.solved
        ? sentenceCaseOf(context, AppLocalizations.of(context).gameStatusGaveUp)
        : play.result;

/// A finished game's mistakes and hints, or null. Not for a give-up, whose
/// mistakes before the surrender are noise, nor the code, whose guesses are
/// already its score.
String? playStatText(AppLocalizations l10n, GamePlay play) =>
    play.solved && play.game != null
        ? gameStatText(l10n, mistakes: play.mistakes, hints: play.hintsUsed)
        : null;

/// A friend's games, folded: "Ece solved 3 games", the games named under it,
/// opening in place onto one line per game with its result and its stats.
///
/// Opens rather than navigating: one tap cannot pick between several
/// leaderboards, so each game's own line is the way into its board.
class _PlayRun extends StatelessWidget {
  const _PlayRun({
    required this.plays,
    required this.open,
    required this.onToggle,
    required this.onOpenPlay,
    required this.face,
  });

  /// Newest first, two or more, all one friend's.
  final List<GamePlay> plays;
  final bool open;
  final VoidCallback? onToggle;
  final void Function(GamePlay play)? onOpenPlay;
  final String? face;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final who = plays.first;
    final solved = plays.where((p) => p.solved).length;
    final headline = solved == plays.length
        ? l10n.momentActivityGamesSolvedAll(plays.length, who.name)
        : solved == 0
        ? l10n.momentActivityGamesPlayed(plays.length, who.name)
        : l10n.momentActivityGamesSolvedSome(plays.length, who.name, solved);
    final names = [
      for (final p in plays)
        p.game == null ? l10n.gameCodeName : leaderboardGameName(l10n, p.game!),
    ].join(' · ');
    final duration = motion.d(theme.motionMed);

    final header = Semantics(
      button: true,
      expanded: open,
      child: PersonRow(
        avatar: PlayerFace(
          userId: who.userId,
          label: who.name,
          size: kPersonRowAvatar,
          storageId: face,
          badge: solved > 0
              ? null
              : Icon(
                  CupertinoIcons.game_controller,
                  size: 11,
                  color: theme.inkMuted,
                ),
        ),
        title: headline,
        titleMaxLines: 2,
        // Every name, never "…": ten games scroll sideways in place.
        subtitle: names,
        subtitleScrolls: true,
        stamp: relativeAgo(l10n, who.finishedAt),
        stampAccessory: _FoldChevron(open: open),
        semanticLabel:
            '$headline, $names, ${relativeAgo(l10n, who.finishedAt)}',
        onTap: onToggle,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        _FoldBody(
          open: open,
          duration: duration,
          children: [
            for (final p in plays)
              _PlayLine(
                key: ValueKey('play_${p.id}'),
                play: p,
                onTap: onOpenPlay == null ? null : () => onOpenPlay!(p),
              ),
          ],
        ),
      ],
    );
  }
}

/// One game inside an opened [_PlayRun]: the game's own board as its face,
/// its name, the stats and when, the result on the trailing edge. Set under
/// the header's text, so the friend's face reads as owning every line.
class _PlayLine extends StatelessWidget {
  const _PlayLine({super.key, required this.play, this.onTap});

  final GamePlay play;
  final VoidCallback? onTap;

  static const double _face = 28;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = sentenceCaseOf(
      context,
      play.game == null
          ? l10n.gameCodeName
          : leaderboardGameName(l10n, play.game!),
    );
    final stats = playStatText(l10n, play);
    final result = playResultText(context, play);
    final ago = relativeAgo(l10n, play.finishedAt);
    final row = _LineBody(
      lead: GameAvatar(
        game: play.game,
        boards: GamesStore.instance.boards,
        size: _face,
      ),
      title: name,
      meta: stats,
      stamp: ago,
      trailing: ScoreText(result, muted: !play.solved),
    );
    final label = [name, result, ?stats, ago].join(', ');
    final tap = onTap;
    if (tap == null) return Semantics(label: label, child: row);
    return SpringPress(
      onTap: tap,
      scale: 0.98,
      haptic: false,
      hoverRadius: 0,
      semanticLabel: label,
      child: ColoredBox(color: Colors.transparent, child: row),
    );
  }
}

/// A friend's highlights, folded: "Alperen posted 3 highlights", when under
/// it, their pictures stacked on the trailing edge. Opens in place onto one
/// line per highlight, each opening its own picture.
///
/// One picture is never on screen twice: opening flies each stacked picture
/// down into its own line's slot, and closing flies them back onto the
/// stack. While open the stack is empty, its space kept so the title does not
/// reflow. A highlight past the stack's three fades in where it lands.
class _MomentRun extends StatefulWidget {
  const _MomentRun({
    required this.moments,
    required this.api,
    required this.open,
    required this.onToggle,
    required this.onOpen,
  });

  /// Newest first, two or more, all one friend's.
  final List<Moment> moments;
  final ChatApi api;
  final bool open;
  final VoidCallback? onToggle;
  final void Function(Moment moment, Rect? origin) onOpen;

  @override
  State<_MomentRun> createState() => _MomentRunState();
}

class _MomentRunState extends State<_MomentRun>
    with SingleTickerProviderStateMixin {
  late final _flight = AnimationController(
    vsync: this,
    value: widget.open ? 1 : 0,
  );
  final _runKey = GlobalKey();
  final _stackKey = GlobalKey();
  final _slotKeys = <String, GlobalKey>{};

  /// Where each picture sits in the run, measured, by moment id: on the
  /// stack (the first three only) and in its line's slot.
  final _onStack = <String, Rect>{};
  final _inSlot = <String, Rect>{};

  bool get _flying => _flight.isAnimating;

  GlobalKey _slotKey(String id) => _slotKeys[id] ??= GlobalKey();

  List<Moment> get _pictured => [
    for (final m in widget.moments)
      if (m.thumbStorageId != null) m,
  ];

  @override
  void initState() {
    super.initState();
    _flight.addListener(() => setState(() {}));
    if (widget.open) _measureAfterFrame();
  }

  @override
  void didUpdateWidget(_MomentRun old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) {
      if (widget.open && !_flying) _measureAfterFrame();
      return;
    }
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    _flight.duration = motion.d(theme.motionMed);
    if (motion.calm) {
      _flight.value = widget.open ? 1 : 0;
      if (widget.open) _measureAfterFrame();
      return;
    }
    if (widget.open) {
      // The lines exist from this frame on: measure them once laid out,
      // then fly. Until then the stack still shows, so nothing blinks.
      _measureAfterFrame(then: () => _flight.forward(from: 0));
    } else {
      // The lines go at once; their last measured places are where the
      // pictures leave from.
      _measureStack();
      _flight.reverse(from: 1);
    }
  }

  void _measureAfterFrame({VoidCallback? then}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureStack();
      _measureSlots();
      then?.call();
    });
  }

  RenderBox? _box(GlobalKey key) {
    final r = key.currentContext?.findRenderObject();
    return r is RenderBox && r.hasSize && r.attached ? r : null;
  }

  void _measureStack() {
    final run = _box(_runKey);
    final stack = _box(_stackKey);
    if (run == null || stack == null) return;
    final origin = stack.localToGlobal(Offset.zero, ancestor: run);
    final pictured = _pictured.take(_ThumbStack.most).toList();
    final back = pictured.length - 1;
    for (var i = 0; i < pictured.length; i++) {
      _onStack[pictured[i].id] = _ThumbStack.cardRect(i, back).shift(origin);
    }
  }

  void _measureSlots() {
    final run = _box(_runKey);
    if (run == null) return;
    for (final m in _pictured) {
      final slot = _box(_slotKey(m.id));
      if (slot == null) continue;
      _inSlot[m.id] =
          slot.localToGlobal(Offset.zero, ancestor: run) & slot.size;
    }
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final w = widget;
    final who = w.moments.first;
    final headline =
        l10n.momentActivityHighlightsPosted(w.moments.length, who.authorName);
    final pictured = _pictured;
    final thumbs = [
      for (final m in pictured.take(_ThumbStack.most)) m.thumbStorageId!,
    ];
    final duration = motion.d(theme.motionMed);
    final curve = motion.c(theme.motionEntrance);
    final t = curve.transform(_flight.value);
    // The stack shows only while fully shut and still; the slots only while
    // fully open and still. In between, the flying pictures are the only
    // copies on screen.
    final stackShown = !w.open && !_flying;
    final slotsShown = w.open && !_flying;

    final header = Semantics(
      button: true,
      expanded: w.open,
      child: PersonRow(
        avatar: PlayerFace(
          userId: who.userId,
          label: who.authorName,
          size: kPersonRowAvatar,
          storageId: who.authorAvatarStorageId,
          dot: w.moments.any((m) => !m.seen),
        ),
        title: headline,
        titleMaxLines: 2,
        // No caption: each is its own line's once it opens, and one of
        // them here as well was the row saying it twice.
        stamp: relativeAgo(l10n, who.createdAt),
        stampAccessory: _FoldChevron(open: w.open),
        semanticLabel: '$headline, ${relativeAgo(l10n, who.createdAt)}',
        onTap: w.onToggle,
        trailing: thumbs.isEmpty
            ? null
            : Opacity(
                opacity: stackShown ? 1 : 0,
                child: _ThumbStack(
                  key: _stackKey,
                  storageIds: thumbs,
                  api: w.api,
                ),
              ),
      ),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        _FoldBody(
          open: w.open,
          duration: duration,
          children: [
            for (final m in w.moments)
              _MomentLine(
                key: ValueKey('act_${m.id}'),
                moment: m,
                api: w.api,
                onOpen: w.onOpen,
                slotKey: _slotKey(m.id),
                showThumb: slotsShown,
              ),
          ],
        ),
      ],
    );
    // Always this Stack, flying or not: swapping the widget type around the
    // column would rebuild the lines mid-animation.
    final radius = BorderRadius.circular(theme.radiusSm);
    return Stack(
      key: _runKey,
      clipBehavior: Clip.none,
      children: [
        column,
        if (_flying)
          for (final m in pictured)
            if (_inSlot[m.id] case final to?)
              _flyer(m, _onStack[m.id], to, t, radius),
      ],
    );
  }

  /// One picture in flight at [t] (0 on the stack, 1 in its slot). One
  /// that was never on the stack fades in at its slot instead.
  Widget _flyer(Moment m, Rect? from, Rect to, double t, BorderRadius radius) {
    final rect = from == null
        ? to.shift(Offset(0, (1 - t) * -8))
        : Rect.lerp(from, to, t)!;
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: Opacity(
          opacity: from == null ? t.clamp(0.0, 1.0) : 1,
          child: RemoteImage(
            storageId: m.thumbStorageId!,
            api: widget.api,
            width: rect.width,
            height: rect.height,
            borderRadius: radius,
          ),
        ),
      ),
    );
  }
}

/// One highlight inside an opened [_MomentRun]: its picture leading, its
/// caption, and when in the corner.
class _MomentLine extends StatelessWidget {
  const _MomentLine({
    super.key,
    required this.moment,
    required this.api,
    required this.onOpen,
    this.slotKey,
    this.showThumb = true,
  });

  final Moment moment;
  final ChatApi api;
  final void Function(Moment moment, Rect? origin) onOpen;

  /// The picture's slot, measured by the run to fly the picture into.
  final GlobalKey? slotKey;

  /// False while the picture is in flight to (or from) this slot: the
  /// slot keeps its place, empty.
  final bool showThumb;

  static const double thumb = 28;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final caption = moment.caption?.trim() ?? '';
    final ago = relativeAgo(l10n, moment.createdAt);
    final picture = moment.thumbStorageId;
    final row = _LineBody(
      // The picture leads, as a game's board does on a game's line.
      lead: picture == null
          ? null
          : SizedBox.square(
              key: slotKey,
              dimension: thumb,
              child: !showThumb
                  ? null
                  : RemoteImage(
                      storageId: picture,
                      api: api,
                      width: thumb,
                      height: thumb,
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                    ),
            ),
      title: caption.isEmpty ? ago : caption,
      titleLines: 2,
      // An unseen one keeps its dot, as the friend's face does.
      titleTrailing: moment.seen
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
            ),
      stamp: caption.isEmpty ? null : ago,
    );
    return Builder(
      builder: (context) => SpringPress(
        onTap: () => onOpen(moment, tapOriginRect(context)),
        scale: 0.98,
        haptic: false,
        hoverRadius: 0,
        semanticLabel: [if (caption.isNotEmpty) caption, ago].join(', '),
        child: ColoredBox(color: Colors.transparent, child: row),
      ),
    );
  }
}

/// An opened fold's line, laid out as its header is one size down: the
/// title and its meta on the left, the time in the top-right corner on the
/// title's first baseline, the result or picture under it. Set under the
/// header's text, so the friend's face reads as owning every line.
class _LineBody extends StatelessWidget {
  const _LineBody({
    required this.title,
    this.lead,
    this.meta,
    this.stamp,
    this.trailing,
    this.titleLines = 1,
    this.titleTrailing,
  });

  final Widget? lead;
  final String title;
  final int titleLines;
  final Widget? titleTrailing;
  final String? meta;
  final String? stamp;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final metaStyle = groupedMetaStyle(theme).copyWith(color: theme.inkMuted);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: titleLines,
                overflow: TextOverflow.ellipsis,
                style: groupedTitleStyle(theme).copyWith(fontSize: 15),
              ),
            ),
            if (titleTrailing != null) ...[
              const SizedBox(width: 6),
              titleTrailing!,
            ],
          ],
        ),
        if (meta != null && meta!.isNotEmpty)
          Text(
            meta!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metaStyle,
          ),
      ],
    );
    final corner = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stamp != null)
          Text(
            stamp!,
            maxLines: 1,
            softWrap: false,
            style: metaStyle.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        if (stamp != null && trailing != null) const SizedBox(height: 2),
        ?trailing,
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          kPersonRowTextInset,
          5,
          14,
          5,
        ),
        child: Row(
          children: [
            if (lead != null) ...[lead!, const SizedBox(width: 10)],
            Expanded(
              child: Row(
                crossAxisAlignment: stamp == null
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 10),
                  corner,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A run's pictures, newest in front, the older ones peeking out behind it
/// to the left: "there is more than one" before the row is opened.
class _ThumbStack extends StatelessWidget {
  const _ThumbStack({super.key, required this.storageIds, required this.api});

  /// Pictures on the stack at most.
  static const int most = 3;

  /// Where card [i] (0 the newest) of a stack of `back + 1` draws its
  /// picture, inside the stack's own box: past its ring.
  static Rect cardRect(int i, int back) => Rect.fromLTWH(
    (back - i) * _peek + _ring,
    _ring,
    _size - 2 * _ring,
    _size - 2 * _ring,
  );

  final List<String> storageIds;
  final ChatApi api;

  static const double _size = 32;
  static const double _peek = 6;
  static const double _ring = 1.5;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final back = storageIds.length - 1;
    return SizedBox(
      width: _size + back * _peek,
      height: _size,
      child: Stack(
        children: [
          // Oldest first, so the newest paints last, on top.
          for (var i = back; i >= 0; i--)
            Positioned(
              left: (back - i) * _peek,
              top: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(theme.radiusSm + _ring),
                  border: Border.all(color: groupedFill(theme), width: _ring),
                ),
                child: RemoteImage(
                  storageId: storageIds[i],
                  api: api,
                  width: _size - 2 * _ring,
                  height: _size - 2 * _ring,
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A fold's chevron: down when shut, up when open.
class _FoldChevron extends StatelessWidget {
  const _FoldChevron({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return AnimatedRotation(
      turns: open ? 0.5 : 0,
      duration: motion.d(theme.motionMed),
      curve: motion.c(theme.motionEntrance),
      child: Icon(
        CupertinoIcons.chevron_down,
        size: 15,
        color: theme.inkMuted,
      ),
    );
  }
}

/// A fold's lines, growing in under its header. Size only: a blur in flight
/// is the one effect this app never animates.
///
/// Opening one is asking to read it, so the list scrolls along as it grows
/// until the last line clears the list's own bottom padding (the tab bar's
/// clearance on the Feed, the home indicator's in the sheet). Never so far
/// that the header leaves the top, and a finger on the list stops it.
class _FoldBody extends StatefulWidget {
  const _FoldBody({
    required this.open,
    required this.duration,
    required this.children,
  });

  final bool open;
  final Duration duration;
  final List<Widget> children;

  @override
  State<_FoldBody> createState() => _FoldBodyState();
}

class _FoldBodyState extends State<_FoldBody> {
  /// Room left above the header when a tall fold stops at the top.
  static const _headerRoom = 8.0;

  final _lines = GlobalKey();

  /// Whether a reveal is following this opening; a close cancels it.
  bool _revealing = false;

  @override
  void didUpdateWidget(_FoldBody old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    _revealing = widget.open;
    if (widget.open) {
      // The lines are laid out (at full size, clipped) from the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _startReveal());
    }
  }

  void _startReveal() {
    if (!mounted || !_revealing) return;
    final fold = context.findRenderObject();
    final lines = _lines.currentContext?.findRenderObject();
    final position = Scrollable.maybeOf(context)?.position;
    if (fold is! RenderBox || lines is! RenderBox || position == null) return;
    if (!fold.hasSize || !lines.hasSize || !fold.attached) return;
    final viewport = RenderAbstractViewport.maybeOf(fold);
    if (viewport == null) return;

    // The whole row: header and fold, the Column they share.
    final row = fold.parent is RenderBox ? fold.parent! as RenderBox : fold;
    final headerAtTop =
        viewport.getOffsetToReveal(row, 0).offset - _headerRoom;
    final linesAtBottom = viewport
            .getOffsetToReveal(
              fold,
              1,
              rect: Offset.zero & Size(fold.size.width, lines.size.height),
            )
            .offset +
        _listBottomPadding(fold);
    final to = linesAtBottom < headerAtTop ? linesAtBottom : headerAtTop;
    if (to <= position.pixels) return;
    _follow(position, fold, lines, position.pixels, to);
  }

  /// Moves the list by the share of the fold that has grown, once per frame
  /// after layout, so the scroll extent it lands in already exists.
  void _follow(
    ScrollPosition position,
    RenderBox fold,
    RenderBox lines,
    double from,
    double to,
  ) {
    if (!mounted || !_revealing || !fold.attached || !lines.attached) return;
    // A drag or fling the reader started wins.
    if (position.isScrollingNotifier.value) return;
    final full = lines.size.height;
    final grown = full <= 0 ? 1.0 : (fold.size.height / full).clamp(0.0, 1.0);
    final target = (from + (to - from) * grown)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (target > position.pixels) position.jumpTo(target);
    if (grown >= 1) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _follow(position, fold, lines, from, to),
    );
  }

  /// The list's own bottom padding: where its content is meant to end above
  /// whatever floats over its foot.
  static double _listBottomPadding(RenderObject from) {
    RenderObject? node = from.parent;
    while (node != null && node is! RenderAbstractViewport) {
      if (node is RenderSliverPadding) {
        return node.resolvedPadding?.bottom ?? 0;
      }
      node = node.parent;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return AnimatedSize(
      duration: widget.duration,
      curve: motion.c(theme.motionEntrance),
      alignment: Alignment.topCenter,
      child: !widget.open
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: _lines,
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
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
        child: _ActivitySheetList(
          viewerId: viewerId,
          api: api,
          onOpen: onOpen,
          faceOf: faceOf,
          // The leaderboard is a page: leave the sheet first, or it would
          // open behind it.
          onOpenPlay: onOpenPlay == null
              ? null
              : (p) {
                  Navigator.of(sheet).pop();
                  onOpenPlay(p);
                },
        ),
      );
    },
  );
}

/// The sheet's list, with groups of its own to open: the sheet's state is
/// its own, so closing it forgets which were open.
class _ActivitySheetList extends StatefulWidget {
  const _ActivitySheetList({
    required this.viewerId,
    required this.api,
    required this.onOpen,
    this.onOpenPlay,
    this.faceOf,
  });

  final String viewerId;
  final ChatApi api;
  final void Function(Moment moment, Rect? origin) onOpen;
  final void Function(GamePlay play)? onOpenPlay;
  final String? Function(String userId)? faceOf;

  @override
  State<_ActivitySheetList> createState() => _ActivitySheetListState();
}

class _ActivitySheetListState extends State<_ActivitySheetList> {
  final _open = <String>{};

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return ListenableBuilder(
      listenable: FeedStore.instance,
      builder: (context, _) {
        final store = FeedStore.instance;
        final entries =
            MomentActivity.entriesOf(store.highlights, store.plays, w.viewerId);
        return ListView(
          padding: sheetListPadding(context),
          children: [
            SheetRise(
              child: SheetGroup(
                children: [
                  for (final e in entries)
                    ActivityRow(
                      key: ValueKey(activityKeyOf(e)),
                      entry: e,
                      viewerId: w.viewerId,
                      api: w.api,
                      faceOf: w.faceOf,
                      onOpen: w.onOpen,
                      onOpenPlay: w.onOpenPlay,
                      open: _open.contains(activityKeyOf(e)),
                      onToggle: () => setState(() {
                        final k = activityKeyOf(e);
                        if (!_open.remove(k)) _open.add(k);
                      }),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
