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
import '../../theme/app_theme.dart';
import '../../theme/layout.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/filter_capsule.dart';
import '../../widgets/game_records.dart';
import '../../widgets/game_tile.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/skeleton_rows.dart';
import '../feed/puzzle_screen.dart';
import 'leaderboard_standings.dart';
import 'queens_screen.dart';
import 'sudoku_screen.dart';
import 'tango_screen.dart';
import 'zip_screen.dart';

/// The leaderboard — who is winning today, and today's five games under it.
///
/// It replaced the "All games" hub. A person who has just glanced at the
/// Feed's five tiles already knows what the games are; the question left is
/// "how am I doing against everyone", so the page leads with that and keeps
/// the tiles as the second section rather than the reason for the page.
///
/// "Today" is the overall standings across all five games, computed on the
/// device from the per-game boards this page already loads
/// ([overallStandings]) — no new query, no subscription. Each game's capsule
/// shows that game's own board.
///
/// Every tile below still draws the **real board** for today, small and
/// inert, from the same painter that draws the playable one.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.feedApi,
    required this.userId,
  });

  /// Handed through to the symbol-code puzzle, which submits guesses on the
  /// Feed's own API rather than the games one.
  final FeedApi feedApi;

  final String userId;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  /// Index into the capsule row: 0 is "Today", 1… are [kLeaderboardGames].
  int _tab = 0;

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

  /// Opens one of the five; null is the code.
  void _openGame(DailyGame? game) {
    _open(switch (game) {
      null => PuzzleScreen(feedApi: widget.feedApi, userId: widget.userId),
      DailyGame.queens => QueensScreen(userId: widget.userId),
      DailyGame.tango => TangoScreen(userId: widget.userId),
      DailyGame.zip => ZipScreen(userId: widget.userId),
      DailyGame.sudoku => SudokuScreen(userId: widget.userId),
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

    // The shared pushed page: back chevron, large title and subtitle at the
    // standard inset, iOS pull-to-refresh above the title. No gutter of its
    // own — the capsule row scrolls edge to edge, so each block pads itself.
    return IosPage(
      title: l10n.gamesHubTitle,
      subtitle: l10n.gamesHubSubtitle,
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
                const SizedBox(height: 2),
                _Capsules(
                  selected: _tab,
                  onSelect: (i) {
                    if (i == _tab) return;
                    HapticFeedback.selectionClick();
                    setState(() => _tab = i);
                  },
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _tab == 0
                      ? _overall(context)
                      : _perGame(context, kLeaderboardGames[_tab - 1]),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: PageSectionHeader(l10n.leaderboardGamesHeader),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _tiles(context),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: RecordsSection(viewerId: widget.userId),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Today ──────────────────────────────────────────────────────────────

  Widget _overall(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = GamesStore.instance;
    if (games.error != null && !games.standingsReady) {
      return _Trouble(
        onRetry: () => GamesStore.instance.load(widget.userId, force: true),
      );
    }
    if (!games.standingsReady) return const _Skeleton();

    final rows = overallStandings(
      games.standings,
      FeedStore.instance.puzzle,
      widget.userId,
    );
    final viewerIn = rows.any((r) => r.isViewer);
    if (rows.isEmpty) {
      // Nobody, the viewer included, has finished anything today.
      return EmptyState(
        compact: true,
        icon: CupertinoIcons.rosette,
        title: l10n.leaderboardEmptyTitle,
        message: l10n.leaderboardEmptyBody,
        actionLabel: l10n.leaderboardEmptyAction(l10n.gameCodeName),
        onAction: () => _openGame(null),
      );
    }

    final total = kLeaderboardGames.length;
    final unplayed = _firstUnplayed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Block(
          pinned: viewerIn
              ? null
              : _PinnedYou(
                  status: l10n.leaderboardNotPlayed,
                  onPlay: unplayed == null && _finished(null)
                      ? null
                      : () => _openGame(unplayed),
                ),
          rows: [
            for (var i = 0; i < rows.length; i++)
              _LeaderTile(
                key: ValueKey('overall_${rows[i].userId}'),
                rank: i + 1,
                medal: i < 3 && rows[i].solved > 0,
                name: rows[i].name,
                isViewer: rows[i].isViewer,
                subtitle: [
                  l10n.leaderboardSolved(rows[i].solved, total),
                  if (rows[i].wins > 0) l10n.leaderboardWins(rows[i].wins),
                ].join(' · '),
                trailing: _Score(
                  score: rows[i].solved,
                  dots: rows[i].solvedByGame,
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            sentenceCaseOf(context, l10n.leaderboardFooter),
            style: groupedFooterStyle(ThemeScope.of(context)),
          ),
        ),
      ],
    );
  }

  // ── One game ───────────────────────────────────────────────────────────

  Widget _perGame(BuildContext context, DailyGame? game) {
    final l10n = AppLocalizations.of(context);
    final store = GamesStore.instance;
    final viewerId = widget.userId;
    const max = 50;

    final List<_LeaderTile> tiles;
    final String empty;
    if (game == null) {
      final scores = FeedStore.instance.puzzle.scores;
      empty = l10n.puzzleScoreboardEmpty;
      tiles = [
        for (var i = 0; i < scores.length && i < max; i++)
          _LeaderTile(
            key: ValueKey('code_${scores[i].userId}'),
            rank: i + 1,
            medal: i < 3 && scores[i].solved,
            name: scores[i].name,
            isViewer: scores[i].userId == viewerId,
            trailing: _Trailing(
              scores[i].solved
                  ? '${scores[i].guessCount}/$kPuzzleMaxGuesses'
                  : 'X/$kPuzzleMaxGuesses',
              muted: !scores[i].solved,
            ),
          ),
      ];
    } else {
      // The code reads the Feed's live board; the four timed boards need the
      // standings fetch this page started.
      if (store.error != null && !store.standingsReady) {
        return _Trouble(
          onRetry: () => GamesStore.instance.load(viewerId, force: true),
        );
      }
      if (!store.standingsReady) return const _Skeleton();
      final rows = store.standings.boards[game] ?? const <GameResult>[];
      empty = l10n.gameStandingsEmpty;
      tiles = [
        for (var i = 0; i < rows.length && i < max; i++)
          _LeaderTile(
            key: ValueKey('${game.wire}_${rows[i].userId}'),
            rank: i + 1,
            medal: i < 3 && rows[i].solved,
            name: rows[i].name,
            isViewer: rows[i].userId == viewerId,
            trailing: _Trailing(
              rows[i].solved
                  ? formatGameTime(rows[i].durationMs)
                  : sentenceCaseOf(context, l10n.gameStatusGaveUp),
              muted: !rows[i].solved,
            ),
          ),
      ];
    }

    final viewerIn = tiles.any((t) => t.isViewer);
    final started = game == null
        ? FeedStore.instance.puzzle.mine?.started ?? false
        : (store.standings.mine[game] ?? FeedStore.instance.games[game]) !=
            null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Block(
          empty: tiles.isEmpty ? empty : null,
          pinned: viewerIn || _finished(game)
              ? null
              : _PinnedYou(
                  status: started
                      ? l10n.gameStatusUnfinished
                      : l10n.leaderboardNotPlayed,
                  onPlay: () => _openGame(game),
                ),
          rows: tiles,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AllTimeLink(
              game: game == null ? RecordGame.code : RecordGame.of(game),
              viewerId: viewerId,
            ),
          ),
        ),
      ],
    );
  }

  // ── Today's puzzles ────────────────────────────────────────────────────

  Widget _tiles(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final store = GamesStore.instance;
    if (store.error != null && !store.boards.ready) {
      return _Trouble(
        onRetry: () => GamesStore.instance.load(widget.userId, force: true),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on a phone, growing with the width there's actually
        // room for — the tiles are square boards, so a fixed count would
        // either crush them on a handset or leave a wide desktop pane stuck
        // at the same phone-size tiles. Capped at 5: that's every tile.
        const gap = 12.0;
        const tileTarget = 150.0;
        final columns = ((constraints.maxWidth + gap) / (tileTarget + gap))
            .floor()
            .clamp(2, 5);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        // The code puzzle leads, ahead of the four boards — the same order as
        // the Feed's strip and the capsule row above.
        final tiles = <Widget>[
          CodePuzzleTile(
            key: const ValueKey('tile_code'),
            puzzle: FeedStore.instance.puzzle,
            width: width,
            onTap: () => _openGame(null),
          ),
          for (final game in DailyGame.values)
            GameTile(
              key: ValueKey('tile_${game.wire}'),
              game: game,
              boards: store.boards,
              result: FeedStore.instance.games[game],
              rank: store.standings.rankOf(game, widget.userId),
              width: width,
              onTap: () => _openGame(game),
            ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < tiles.length; i++)
              TweenAnimationBuilder<double>(
                key: tiles[i].key,
                tween: Tween(begin: 0, end: 1),
                duration: motion.stagger(theme.motionMed, i, strideMs: 60),
                // Pops in on an overshoot, one after the other — the shelf
                // being dealt out.
                curve: motion.c(Curves.easeOutBack),
                builder: (context, v, child) => Transform.scale(
                  scale: 0.86 + 0.14 * v,
                  child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                ),
                child: tiles[i],
              ),
          ],
        );
      },
    );
  }
}

/// The game a capsule names; null is the code.
String leaderboardGameName(AppLocalizations l10n, DailyGame? game) =>
    switch (game) {
      null => l10n.gameCodeName,
      DailyGame.queens => l10n.gameQueensName,
      DailyGame.tango => l10n.gameTangoName,
      DailyGame.zip => l10n.gameZipName,
      DailyGame.sudoku => l10n.gameSudokuName,
    };

/// "Today" then the five games, one horizontally scrolling row of
/// [FilterCapsule]s, inset to the title's 20pt edge.
class _Capsules extends StatelessWidget {
  const _Capsules({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.leaderboardOverall,
      for (final g in kLeaderboardGames) leaderboardGameName(l10n, g),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            FilterCapsule(
              key: ValueKey('capsule_$i'),
              label: sentenceCaseOf(context, labels[i]),
              active: i == selected,
              onTap: () => onSelect(i),
            ),
          ],
        ],
      ),
    );
  }
}

/// The grouped block the rows sit in: hairlines from the name's edge, and an
/// optional pinned "You" row under its own full-width hairline.
class _Block extends StatelessWidget {
  const _Block({required this.rows, this.pinned, this.empty});

  final List<Widget> rows;
  final Widget? pinned;

  /// Shown in place of the rows when there are none.
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final rule = theme.ink.withValues(alpha: 0.10);
    final none = empty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(groupedRadius(theme)),
      child: ColoredBox(
        color: groupedFill(theme),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows.isEmpty && none != null) EmptyLine(none),
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Container(height: hairline, color: rule),
                ),
            ],
            if (pinned != null) ...[
              if (rows.isNotEmpty || none != null)
                Container(height: hairline, color: rule),
              pinned!,
            ],
          ],
        ),
      ),
    );
  }
}

/// One player's line: rank (a medal disc for the podium), name, an optional
/// subtitle, and whatever the board ranks by on the trailing edge.
class _LeaderTile extends StatelessWidget {
  const _LeaderTile({
    super.key,
    required this.rank,
    required this.medal,
    required this.name,
    required this.isViewer,
    required this.trailing,
    this.subtitle,
  });

  final int rank;
  final bool medal;
  final String name;
  final bool isViewer;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final label = isViewer ? sentenceCaseOf(context, l10n.momentRailYouLabel) : name;
    final sub = subtitle;
    return Semantics(
      container: true,
      label: '$rank. $label${sub == null ? '' : ', $sub'}',
      child: Container(
        color: isViewer ? quietFill(theme) : null,
        constraints: const BoxConstraints(minHeight: kGroupedRowMinHeight),
        padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
        // One announcement per row — "2. Ece, 3 of 5 solved" — rather than
        // the disc, the name and the score read out as three stops.
        child: ExcludeSemantics(
          child: Row(
            children: [
              _MedalDisc(rank: rank, medal: medal),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: isViewer
                          ? groupedTitleStyle(theme).copyWith(
                              color: theme.accent,
                              fontWeight: FontWeight.w600,
                            )
                          : groupedTitleStyle(theme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sentenceCaseOf(context, sub),
                        style: groupedSubtitleStyle(theme),
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold, silver, bronze for the podium; everyone after gets a quiet numbered
/// disc. The same three gradients the game screens' standings use.
class _MedalDisc extends StatelessWidget {
  const _MedalDisc({required this.rank, required this.medal});

  final int rank;
  final bool medal;

  static const _medals = [
    [Color(0xFFFFD86B), Color(0xFFF0A81E)],
    [Color(0xFFE4E7EC), Color(0xFFA9AFB8)],
    [Color(0xFFF2B48A), Color(0xFFC77A44)],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final colors = medal && rank <= 3 ? _medals[rank - 1] : null;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: colors == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
        color: colors == null ? quietFill(theme) : null,
      ),
      child: Text(
        '$rank',
        style: groupedMetaStyle(theme).copyWith(
          fontWeight: FontWeight.w700,
          color: colors == null ? theme.inkMuted : const Color(0xFF3A2A00),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// The overall row's trailing edge: the score, then one dot per game —
/// solved in the success colour, not solved a faint ink.
class _Score extends StatelessWidget {
  const _Score({required this.score, required this.dots});

  final int score;
  final List<bool> dots;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$score',
          style: groupedTitleStyle(theme).copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 10),
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

/// A per-game row's trailing edge: a time or "4/6", tabular so the column of
/// them lines up.
class _Trailing extends StatelessWidget {
  const _Trailing(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Text(
      text,
      style: groupedTitleStyle(theme).copyWith(
        fontWeight: FontWeight.w600,
        color: muted ? theme.inkMuted : theme.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The viewer, pinned under the board when they are not on it yet — so the
/// leaderboard always answers "where am I", and the answer comes with the
/// way onto it.
class _PinnedYou extends StatelessWidget {
  const _PinnedYou({required this.status, required this.onPlay});

  final String status;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      color: quietFill(theme),
      constraints: const BoxConstraints(minHeight: kGroupedRowMinHeight),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: Row(
        children: [
          _QuietDash(theme: theme),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sentenceCaseOf(context, l10n.momentRailYouLabel),
                  style: groupedTitleStyle(theme).copyWith(
                    color: theme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sentenceCaseOf(context, status),
                  style: groupedSubtitleStyle(theme),
                ),
              ],
            ),
          ),
          if (onPlay != null)
            RowPillButton(
              label: l10n.leaderboardPlay,
              filled: true,
              onTap: onPlay,
            ),
        ],
      ),
    );
  }
}

/// The rank disc's place on the pinned row: no rank yet, so a dash.
class _QuietDash extends StatelessWidget {
  const _QuietDash({required this.theme});

  final AppTheme theme;

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: quietFill(theme),
        ),
        child: Text(
          '–',
          style: groupedMetaStyle(theme).copyWith(fontWeight: FontWeight.w700),
        ),
      );
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
        child: const SkeletonRows(count: 4, avatarSize: 28),
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
