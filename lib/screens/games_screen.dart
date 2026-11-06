import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/feed_api.dart';
import '../chat_games/bot_hub_screen.dart' show BotHubPanel;
import '../data/chat_repository.dart';
import '../data/feed_store.dart';
import '../data/games_store.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/daily_game.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/games_strip.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sunlit_surface.dart' show SunlitBackdrop;
import '../widgets/tab_root_bar.dart';
import 'feed/puzzle_screen.dart';
import 'games/daily_game_screens.dart';
import 'games/leaderboard_screen.dart';
import 'games/streak_card.dart';
import 'navigation/destinations.dart';
import 'navigation/scroll_memory.dart';
import 'navigation/tab_reselect.dart';

/// The Games tab: the viewer's streaks, today's dailies, and the bot.
///
/// The games used to be one sideways band on the Feed with the bot a push
/// further, which made a daily habit with its own streaks, leaderboard and
/// practice mode a summary inside a page about friends. Here they are the
/// page: the dailies laid out as a grid by difficulty, the bot's picker
/// inline under them.
///
/// Reads nothing new. The dailies and their ranks ride the Feed board that
/// [FeedStore] keeps live app-wide; the streaks are [GamesStore]'s standings,
/// re-read only when older than its TTL, the same read the leaderboard makes.
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.repo, required this.feedApi});

  final ChatRepository repo;
  final FeedApi feedApi;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen>
    with TabReselectScroll<GamesScreen> {
  final _scroll = ScrollMemory.controller();

  @override
  HomeSection get reselectSection => HomeSection.games;
  @override
  ScrollController get reselectScroll => _scroll;

  /// Page margin, the same 20 the other tab roots use.
  static const _gutter = 20.0;

  @override
  void initState() {
    super.initState();
    ScrollMemory.attach('games', _scroll);
    FeedStore.instance.start();
    FeedStore.instance.addListener(_onChange);
    GamesStore.instance.addListener(_onChange);
    widget.repo.addListener(_onChange);
    GamesStore.instance.loadBoards();
    _loadStandings();
    // A tapped daily-games notification, before or while this tab is up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingGames());
    UiSelectionStore.instance.addListener(_consumePendingGames);
  }

  @override
  void dispose() {
    FeedStore.instance.removeListener(_onChange);
    GamesStore.instance.removeListener(_onChange);
    widget.repo.removeListener(_onChange);
    UiSelectionStore.instance.removeListener(_consumePendingGames);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    _loadStandings();
  }

  /// The streak card's data. Waits for the repo's userId on a cold start;
  /// [GamesStore.load] answers from its held copy inside the TTL, so calling
  /// this on every change costs nothing.
  bool _standingsAsked = false;
  void _loadStandings() {
    if (_standingsAsked) return;
    final userId = widget.repo.userId;
    if (userId == null) return;
    _standingsAsked = true;
    GamesStore.instance.load(userId);
  }

  /// A tapped games notification lands here: anything pushed over the tab is
  /// popped, and the page goes back to its top, where today's games are.
  void _consumePendingGames() {
    if (!mounted) return;
    if (!UiSelectionStore.instance.consumeGamesView()) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (!_scroll.hasClients) return;
    if (MotionScope.of(context).calm) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openGame(DailyGame game) {
    final userId = widget.repo.userId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => dailyGameScreen(game, userId)),
    );
  }

  void _openPuzzle() {
    final userId = widget.repo.userId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PuzzleScreen(feedApi: widget.feedApi, userId: userId),
      ),
    );
  }

  void _openLeaderboard() {
    final userId = widget.repo.userId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LeaderboardScreen(
          feedApi: widget.feedApi,
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = FeedStore.instance;
    final games = GamesStore.instance;
    final userId = widget.repo.userId ?? '';

    final children = <Widget>[
      if (games.standingsReady) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _gutter),
          child: PageSectionHeader(l10n.myStreaksLabel),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: StreakCard(
            streaks: games.standings.myStreaks,
            viewerId: userId,
          ),
        ),
        const SizedBox(height: 32),
      ],
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gutter),
        child: PageSectionHeader(
          l10n.gamesTabTodayLabel,
          actions: [
            SectionAction(
              icon: CupertinoIcons.rosette,
              label: l10n.feedBoardGamesOpen,
              onTap: _openLeaderboard,
            ),
          ],
        ),
      ),
      GamesStrip(
        key: const ValueKey('games_tab_grid'),
        shelves: true,
        inset: 16,
        boards: games.boards,
        results: store.games,
        onOpen: _openGame,
        puzzle: store.puzzle,
        onOpenPuzzle: _openPuzzle,
        ranks: {
          for (final g in DailyGame.values) g: ?store.gameRank(g, userId),
        },
        puzzleRank: store.puzzleRank(userId),
      ),
      const SizedBox(height: 32),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gutter),
        child: PageSectionHeader(sentenceCaseOf(context, l10n.botHubTitle)),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: BotHubPanel(key: ValueKey('games_tab_bots')),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const SunlitBackdrop(),
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: AdaptivePageBody(
              maxWidth: ContentWidth.wide,
              child: ListView(
                key: const PageStorageKey('games_tab_v1'),
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                  0,
                  TabRootBar.clearance(context) + 6,
                  0,
                  sectionBottomPadding(context),
                ),
                children: children,
              ),
            ),
          ),
          TabRootBar(title: l10n.destinationsGamesLabel, scroll: _scroll),
        ],
      ),
    );
  }
}
