import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/feed_api.dart';
import '../../data/feed_store.dart';
import '../../data/games_store.dart';
import '../../data/records_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
import '../../models/daily_game.dart';
import '../../models/game_record.dart';
import '../../models/puzzle.dart';
import '../../theme/layout.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/filter_capsule.dart';
import '../../widgets/game_records.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/skeleton_rows.dart';
import '../../widgets/score_row.dart';
import '../feed/puzzle_screen.dart';
import 'leader_podium.dart';
import 'daily_game_screens.dart';
import 'leaderboard_standings.dart';
import 'result_sheet.dart';
import 'streak_card.dart';
import '../../widgets/desktop_scroll.dart';

/// The leaderboard: your streaks, who is winning today, and the all-time
/// records.
///
/// Three blocks, each with one job, so the eye has somewhere to land:
///
///  * **Streaks** — yours, one column per game ([StreakCard]). The personal
///    reason to come back tomorrow.
///  * **The board** — "Today" (the overall standings across every game,
///    computed on the device by [overallStandings] from boards this page
///    already loads) or one game's own. The top three stand on a
///    [LeaderPodium]; everyone after is a one-line [PersonRow] with their
///    rank, face, streak flame and score.
///  * **All-time** — every game's record on "Today", only the selected
///    game's on a game's board ([RecordsSection.only]).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.feedApi,
    required this.userId,
    this.initialTab = 0,
  });

  /// The capsule to open on: 0 is "Today", [tabOf] names a game's.
  final int initialTab;

  /// The capsule index of one game's board; null is the code.
  static int tabOf(DailyGame? game) => 1 + kLeaderboardGames.indexOf(game);

  /// Handed through to the symbol-code puzzle, which submits guesses on the
  /// Feed's own API rather than the games one.
  final FeedApi feedApi;

  final String userId;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  /// Index into the capsule row: 0 is "Today", 1… are [kLeaderboardGames].
  late int _tab = widget.initialTab.clamp(0, kLeaderboardGames.length);

  @override
  void initState() {
    super.initState();
    GamesStore.instance.addListener(_onChange);
    FeedStore.instance.addListener(_onChange);
    GamesStore.instance.load(widget.userId);
    RecordsStore.instance.load(widget.userId);
  }

  @override
  void dispose() {
    GamesStore.instance.removeListener(_onChange);
    FeedStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    // A board finished behind this screen changes the standings, every
    // tile's status and the viewer's pinned row, so catch up on the way back
    // rather than showing a stale "not played" over a puzzle just solved.
    GamesStore.instance.load(widget.userId);
    // …and a solve may just have set a record.
    RecordsStore.instance.load(widget.userId, force: true);
  }

  /// Opens one of the games; null is the code.
  void _openGame(DailyGame? game) {
    _open(switch (game) {
      null => PuzzleScreen(feedApi: widget.feedApi, userId: widget.userId),
      final DailyGame daily => dailyGameScreen(daily, widget.userId),
    });
  }

  /// Whether the viewer has finished [game] today, from their own rows —
  /// which land before the friend boards do.
  bool _finished(DailyGame? game) {
    if (game == null) return FeedStore.instance.puzzle.mine?.done ?? false;
    final mine = GamesStore.instance.standings.mine[game] ??
        FeedStore.instance.games[game];
    return mine?.finished ?? false;
  }

  /// The first game the viewer has not finished, in shelf order — what the
  /// pinned row's "Play" opens.
  DailyGame? get _firstUnplayed {
    for (final g in kLeaderboardGames) {
      if (!_finished(g)) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final game = _tab == 0 ? null : kLeaderboardGames[_tab - 1];

    // The shared pushed page: back chevron, large title, iOS pull-to-refresh
    // above the title. No subtitle: the capsules already say "Today". No
    // gutter of its own: the capsule row scrolls edge to edge, so each block
    // pads itself, cards at 16 and headers at the title's 20.
    return IosPage(
      title: l10n.gamesHubTitle,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      onRefresh: () {
        HapticFeedback.lightImpact();
        // The code's scores ride the Feed's live board, so they need no
        // reload of their own.
        return Future.wait([
          GamesStore.instance.load(widget.userId, force: true),
          RecordsStore.instance.load(widget.userId, force: true),
        ]);
      },
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.isExpanded
                  ? ContentWidth.wide
                  : ContentWidth.readable,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                if (GamesStore.instance.standingsReady) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: PageSectionHeader(
                      l10n.myStreaksLabel,
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StreakCard(
                      streaks: GamesStore.instance.standings.myStreaks,
                      viewerId: widget.userId,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                _Capsules(selected: _tab, onSelect: _select),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: motion.d(theme.motionFast),
                  switchInCurve: theme.motionEntrance,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: _tab == 0
                        ? _overall(context)
                        : _perGame(context, game),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: RecordsSection(
                    viewerId: widget.userId,
                    onPlay: (g) => _openGame(g.daily),
                    only: _tab == 0
                        ? null
                        : (game == null ? RecordGame.code : RecordGame.of(game)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _select(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  /// [userId]'s flame on "Today": their longest live run across every
  /// game. Which game it is on is the streaks card's question; here it only
  /// says "this person keeps coming back".
  int _overallStreak(String userId) {
    final standings = GamesStore.instance.standings;
    var best = 0;
    for (final g in kLeaderboardGames) {
      final n = standings.streakOf(userId, g);
      if (n > best) best = n;
    }
    return best;
  }

  // ── Today ──────────────────────────────────────────────────────────────

  Widget _overall(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = GamesStore.instance;
    if (games.error != null && !games.standingsReady) {
      return _inset(_Trouble(
        onRetry: () => GamesStore.instance.load(widget.userId, force: true),
      ));
    }
    if (!games.standingsReady) return _inset(const _Skeleton());

    final rows = overallStandings(
      games.standings,
      FeedStore.instance.puzzle,
      widget.userId,
    );
    if (rows.isEmpty) {
      // Nobody, the viewer included, has finished anything today.
      return _inset(EmptyState(
        compact: true,
        icon: CupertinoIcons.rosette,
        title: l10n.leaderboardEmptyTitle,
        message: l10n.leaderboardEmptyBody,
        actionLabel: l10n.leaderboardEmptyAction(l10n.gameCodeName),
        onAction: () => _openGame(null),
      ));
    }

    final total = kLeaderboardGames.length;
    final unplayed = _firstUnplayed;
    final viewerIn = rows.any((r) => r.isViewer);
    return _Board(
      entries: [
        for (var i = 0; i < rows.length; i++)
          _Entry(
            userId: rows[i].userId,
            name: rows[i].name,
            isViewer: rows[i].isViewer,
            medal: rows[i].solved > 0,
            streak: _overallStreak(rows[i].userId),
            semantics: l10n.leaderboardSolved(rows[i].solved, total),
            podiumMetric: SolvedDots(
              dots: rows[i].solvedByGame,
              score: rows[i].solved,
            ),
            trailing: SolvedDots(
              dots: rows[i].solvedByGame,
              score: rows[i].solved,
            ),
          ),
      ],
      pinned: viewerIn
          ? null
          : _pinnedYou(
              context,
              l10n.leaderboardNotPlayed,
              unplayed == null && _finished(null)
                  ? null
                  : () => _openGame(unplayed),
            ),
      footer: l10n.leaderboardFooter,
    );
  }

  // ── One game ───────────────────────────────────────────────────────────

  Widget _perGame(BuildContext context, DailyGame? game) {
    final l10n = AppLocalizations.of(context);
    final store = GamesStore.instance;
    final viewerId = widget.userId;
    const max = 50;

    final List<_Entry> entries;
    final String empty;
    if (game == null) {
      final scores = FeedStore.instance.puzzle.scores;
      empty = l10n.puzzleScoreboardEmpty;
      entries = [
        for (var i = 0; i < scores.length && i < max; i++)
          _entry(
            userId: scores[i].userId,
            name: scores[i].name,
            solved: scores[i].solved,
            game: null,
            text: scores[i].solved
                ? '${scores[i].guessCount}/$kPuzzleMaxGuesses'
                : 'X/$kPuzzleMaxGuesses',
          ),
      ];
    } else {
      // The code reads the Feed's live board; the four timed boards need the
      // standings fetch this page started.
      if (store.error != null && !store.standingsReady) {
        return _inset(_Trouble(
          onRetry: () => GamesStore.instance.load(viewerId, force: true),
        ));
      }
      if (!store.standingsReady) return _inset(const _Skeleton());
      final rows = store.standings.boards[game] ?? const <GameResult>[];
      empty = l10n.gameStandingsEmpty;
      entries = [
        for (var i = 0; i < rows.length && i < max; i++)
          _entry(
            userId: rows[i].userId,
            name: rows[i].name,
            solved: rows[i].solved,
            game: game,
            text: rows[i].solved
                ? formatGameTime(rows[i].durationMs)
                : sentenceCaseOf(context, l10n.gameStatusGaveUp),
            result: rows[i],
          ),
      ];
    }

    final viewerIn = entries.any((e) => e.isViewer);
    final started = game == null
        ? FeedStore.instance.puzzle.mine?.started ?? false
        : (store.standings.mine[game] ?? FeedStore.instance.games[game]) !=
            null;
    return _Board(
      entries: entries,
      empty: empty,
      pinned: viewerIn || _finished(game)
          ? null
          : _pinnedYou(
              context,
              started ? l10n.gameStatusUnfinished : l10n.leaderboardNotPlayed,
              () => _openGame(game),
            ),
    );
  }

  _Entry _entry({
    required String userId,
    required String name,
    required bool solved,
    required DailyGame? game,
    required String text,
    GameResult? result,
  }) {
    final isViewer = userId == widget.userId;
    return _Entry(
      userId: userId,
      name: name,
      isViewer: isViewer,
      medal: solved,
      streak: solved ? GamesStore.instance.standings.streakOf(userId, game) : 0,
      semantics: text,
      podiumMetric: ScoreText(text, muted: !solved, large: true),
      trailing: ScoreText(text, muted: !solved),
      onTap: result == null
          ? null
          : () => showResultSheet(
              context,
              row: result,
              viewerId: widget.userId,
            ),
    );
  }

  /// The viewer, under the board when they are not on it yet: the board
  /// always answers "where am I", and the answer comes with the way onto it.
  Widget _pinnedYou(BuildContext context, String status, VoidCallback? onPlay) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final you = sentenceCaseOf(context, l10n.momentRailYouLabel);
    return PersonRow(
      emphasis: true,
      lead: Text('–', style: scoreRankStyle(theme)),
      avatar: PlayerFace(
        userId: widget.userId,
        label: you,
        size: kPersonRowAvatar,
      ),
      title: you,
      subtitle: sentenceCaseOf(context, status),
      semanticLabel: '$you, ${sentenceCaseOf(context, status)}',
      trailing: onPlay == null
          ? null
          : RowPillButton(
              label: l10n.leaderboardPlay,
              filled: true,
              onTap: onPlay,
            ),
    );
  }

  static Widget _inset(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: child,
      );
}

/// One person on a board, before it is split into podium and rows.
class _Entry {
  const _Entry({
    required this.userId,
    required this.name,
    required this.isViewer,
    required this.medal,
    required this.streak,
    required this.semantics,
    required this.podiumMetric,
    required this.trailing,
    this.onTap,
  });

  final String userId;
  final String name;
  final bool isViewer;

  /// Earned a place at all: solved something. A podium needs it.
  final bool medal;
  final int streak;
  final String semantics;
  final Widget podiumMetric;
  final Widget trailing;

  /// Opens the whole result (see [showResultSheet]). Null on the boards that
  /// have nothing behind the row: "Today" and the code puzzle.
  final VoidCallback? onTap;
}

/// A board: the top three on a [LeaderPodium], everyone else as rows under
/// it, and the viewer pinned last when they are not on it yet.
///
/// The same shape on every tab, however many have played: a place nobody has
/// taken yet is an empty seat on the podium rather than the podium giving
/// way to a list, which made each capsule look like a different screen.
class _Board extends StatelessWidget {
  const _Board({
    required this.entries,
    this.pinned,
    this.empty,
    this.footer,
  });

  final List<_Entry> entries;
  final Widget? pinned;
  final String? empty;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Medal places only: a gave-up row at the top of a board is first, but
    // it did not win a place to stand on.
    var podium = 0;
    while (podium < 3 &&
        podium < entries.length &&
        entries[podium].medal) {
      podium++;
    }
    final rest = entries.sublist(podium);
    final none = empty;

    final rows = <Widget>[
      if (entries.isEmpty && none != null) EmptyLine(none),
      for (var i = 0; i < rest.length; i++)
        _row(context, rank: podium + i + 1, entry: rest[i]),
      ?pinned,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LeaderPodium(
            entries: [
              for (final e in entries.take(podium))
                PodiumEntry(
                  userId: e.userId,
                  name: e.isViewer ? '' : e.name,
                  isViewer: e.isViewer,
                  metric: e.podiumMetric,
                  semantics: e.semantics,
                  streak: e.streak,
                  onTap: e.onTap,
                ),
            ],
          ),
        if (rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GroupedSection(margin: EdgeInsets.zero, children: rows),
          ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              sentenceCaseOf(context, footer!),
              style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, {required int rank, required _Entry entry}) =>
      ScoreRow(
        key: ValueKey('row_${entry.userId}'),
        rank: rank,
        userId: entry.userId,
        name: entry.name,
        isViewer: entry.isViewer,
        streak: entry.streak,
        semantics: entry.semantics,
        trailing: entry.trailing,
        onTap: entry.onTap,
      );
}

/// "Today" then every game, one horizontally scrolling row of
/// [FilterCapsule]s, inset to the title's 20pt edge.
class _Capsules extends StatefulWidget {
  const _Capsules({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<_Capsules> createState() => _CapsulesState();
}

class _CapsulesState extends State<_Capsules> {
  /// One per capsule, stable for the row's life, so revealing the selected one
  /// never remounts it (a key that followed the selection would).
  final _keys = List.generate(kLeaderboardGames.length + 1, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    // Opened straight onto a game's board (an Activity row does this), the
    // selected capsule can sit past the right edge, and a highlighted tab you
    // cannot see reads as nothing being selected.
    if (widget.selected == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[widget.selected].currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.leaderboardOverall,
      for (final g in kLeaderboardGames) leaderboardGameName(l10n, g),
    ];
    return HorizontalWheelScroll(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              KeyedSubtree(
                key: _keys[i],
                child: FilterCapsule(
                  key: ValueKey('capsule_$i'),
                  label: sentenceCaseOf(context, labels[i]),
                  active: i == widget.selected,
                  onTap: () => widget.onSelect(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The overall score: the number, then one dot per game, solved in the
/// success colour and the rest a faint ink. The number steps back to the
/// soft ink so the name stays the loudest thing on the row.
class SolvedDots extends StatelessWidget {
  const SolvedDots({super.key, required this.dots, this.score});

  final List<bool> dots;

  /// Drawn before the dots when given.
  final int? score;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final n = score;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (n != null) ...[
          Text(
            '$n',
            style: groupedValueStyle(theme).copyWith(
              fontWeight: FontWeight.w600,
              color: theme.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
        ],
        for (var i = 0; i < dots.length; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dots[i]
                  ? theme.success
                  : theme.ink.withValues(alpha: 0.15),
            ),
          ),
        ],
      ],
    );
  }
}

/// Four placeholder rows the shape of the real ones, until the standings
/// answer.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(groupedRadius(theme)),
      child: ColoredBox(
        color: groupedFill(theme),
        child: const SkeletonRows(count: 4, avatarSize: kPersonRowAvatar),
      ),
    );
  }
}

/// Shown when today's boards or standings could not be fetched at all.
///
/// Distinct from an empty board: a fetch that failed is a network problem the
/// player can retry, and "No scores yet today" for it would be a lie.
class _Trouble extends StatelessWidget {
  const _Trouble({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return GroupedSection(
      margin: EdgeInsets.zero,
      children: [
        GroupedRow(
          icon: CupertinoIcons.wifi_exclamationmark,
          tone: TileTone.orange,
          title: sentenceCaseOf(context, l10n.gamesLoadFailed),
          chevron: false,
          onTap: onRetry,
          trailing: Text(
            sentenceCaseOf(context, l10n.gamesRetry),
            style: groupedTitleStyle(theme).copyWith(color: theme.accent),
          ),
        ),
      ],
    );
  }
}
