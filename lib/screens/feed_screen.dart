import '../models/chat_user.dart';
import 'profile_screen.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../backend/feed_api.dart';
import '../chat_games/bot_hub_screen.dart';
import '../data/chat_repository.dart';
import '../data/feed_store.dart';
import '../data/games_store.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../widgets/app_toast.dart';
import 'navigation/scroll_memory.dart';
import '../family/family_service.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/daily_game.dart';
import '../models/moment.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/feed_depth_field.dart';
import '../widgets/ios_kit.dart';
import '../widgets/meta_text.dart';
import '../widgets/games_strip.dart';
import '../widgets/moment_activity.dart';
import '../widgets/moment_rail.dart';
import '../widgets/points_board.dart';
import '../widgets/tab_root_bar.dart';
import 'feed/archive_screen.dart';
import 'feed/moment_composer.dart';
import 'feed/moment_viewer.dart';
import 'feed/point_composer.dart';
import 'feed/points_explainer.dart';
import 'feed/puzzle_screen.dart';
import 'games/leaderboard_screen.dart';
import 'games/daily_game_screens.dart';
import 'navigation/destinations.dart';
import 'navigation/tab_reselect.dart';

/// TODAY — the friends-activity board.
///
/// Everything on this board is scoped to the current local day: highlights are
/// listed for 24 hours, the puzzle is one per day, standings default to today.
/// That single rule is what makes four separate features read as one product,
/// and it is also the privacy model — today is shared with friends, the past is
/// yours unless you open it.
///
/// **Why this screen owns so little state.** `HomeShell` keys its section
/// `AnimatedSwitcher` on `'${section.name}_${theme.id}'`, so tapping away to
/// another tab — or merely changing theme — fully disposes this widget and
/// re-runs `initState`. Anything that must not restart lives in [FeedStore].
/// The stagger below is deliberately *not* latched: it is 300ms of settle and
/// replaying it on return reads as the board waking up. The masthead's
/// once-a-day intro is latched, because replaying that on every tab tap would
/// be obnoxious.
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.repo,
    required this.api,
    required this.feedApi,
    required this.auth,
    required this.family,
  });

  final ChatRepository repo;
  final ChatApi api;
  final FeedApi feedApi;
  final AuthService auth;
  final FamilyService family;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with TabReselectScroll<FeedScreen> {
  // Not a plain ScrollController: this section's State is destroyed on
  // every tab switch, and the framework's own PageStorage restore is what
  // produced the settle-bounce on return. See [ScrollMemory].
  final _scroll = ScrollMemory.controller();

  /// The first mount since launch shows the board in place: no stagger, no
  /// masthead intro. See [FeedStore.takeLaunchEntrance].
  final bool _launchShow = FeedStore.instance.takeLaunchEntrance();

  @override
  HomeSection get reselectSection => HomeSection.feed;
  @override
  ScrollController get reselectScroll => _scroll;

  @override
  void initState() {
    super.initState();
    ScrollMemory.attach('feed', _scroll);
    // Idempotent — arms the day-rollover timer if some earlier mount hasn't.
    FeedStore.instance.start();
    FeedStore.instance.addListener(_onChange);
    GamesStore.instance.addListener(_onChange);
    // Boards only — the four thumbnails. `games:daily` reads no table, and the
    // viewer's own results already ride in on the board payload, so the band
    // costs one cheap call on the first Feed mount of the day and nothing
    // after it. The friend leaderboards wait for the hub.
    GamesStore.instance.loadBoards();
    unawaited(_loadMyAvatar());
    // The empty state turns on the friend count, so the board has to rebuild
    // when a friend request is accepted while it is on screen.
    widget.repo.addListener(_onChange);
    // A daily-games nudge tapped before this screen existed is still waiting in
    // the store — including on a cold start, where the tap lands long before
    // any widget mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingGames());
    // …and the same for a tapped friend-activity notification, which names one
    // card rather than the shelf.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _consumePendingMoment());
    // …and the same request arriving while this screen is ALREADY on it. The
    // post-frame callback above only fires on mount, and steering the shell to
    // a section it is already showing remounts nothing — so a nudge tapped by
    // somebody who happened to be looking at the Feed would have set the
    // one-shot and then had nobody left to consume it.
    UiSelectionStore.instance.addListener(_consumePendingGames);
    UiSelectionStore.instance.addListener(_consumePendingMoment);
  }

  /// The Games band, for a tapped games notification to scroll to.
  final _gamesKey = GlobalKey(debugLabel: 'feed-games');

  /// A games notification is waiting for the board to settle before it
  /// scrolls; see [_revealGames].
  bool _gamesRevealPending = false;

  /// Takes a tapped daily-games notification (the nudge, or a friend's
  /// shared result) to the Games band on this Feed: where the five games are,
  /// with the viewer's time and rank on each. It used to open the
  /// leaderboard, which since the band landed holds the standings only.
  ///
  /// Anything this Feed's own navigator has open over it is popped first,
  /// for the reason app.dart pops the root one: a wide window keeps the
  /// section's pages on a navigator of its own, which the root pop misses.
  void _consumePendingGames() {
    if (!mounted) return;
    if (!UiSelectionStore.instance.consumeGamesView()) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    _gamesRevealPending = true;
    _revealGames();
  }

  /// Scrolls the Games band to just under the top, leaving a sliver of the
  /// section above showing, so it reads as a place on the Feed rather than a
  /// page of its own.
  ///
  /// Waits for the board: before it lands the sections above are skeletons
  /// of another height, and a scroll aimed at a band that then moves lands
  /// somewhere else. [_onChange] re-runs this when the board arrives, and a
  /// band the list has not built yet is retried on the next frame.
  void _revealGames([int tries = 10]) {
    if (!mounted || !_gamesRevealPending) return;
    if (!FeedStore.instance.loaded) return;
    final target = _gamesKey.currentContext?.findRenderObject();
    if (target == null || !_scroll.hasClients) {
      if (tries > 0) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _revealGames(tries - 1));
      }
      return;
    }
    _gamesRevealPending = false;
    final position = _scroll.position;
    final reveal = RenderAbstractViewport.maybeOf(target)
        ?.getOffsetToReveal(target, 0)
        .offset;
    if (reveal == null) return;
    final offset = (reveal - _kGamesRevealPeek)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (MotionScope.of(context).calm) {
      _scroll.jumpTo(offset);
    } else {
      _scroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Whether a tapped moment is already being fetched or shown, so a rebuild
  /// mid-fetch does not start a second one or stack a second viewer.
  bool _momentOpening = false;

  /// Opens the moment a friend-activity notification named.
  ///
  /// Peeks before consuming for the same cold-start reason
  /// [_consumePendingGames] does — the Feed can mount before the repo has a
  /// userId, and consuming there would drop the tap with nothing left to retry
  /// it. [_onChange] re-runs this once the repo attaches.
  ///
  /// The board is tried FIRST and the network only if it misses. That is not
  /// just a saved round trip: a moment already on the board arrives with its
  /// siblings, so the viewer opens as a swipeable run of the day rather than as
  /// one card in isolation — the same thing a tap on the rail gets. The fetch
  /// is the fallback for the case the board structurally cannot cover (a friend
  /// whose local day is not ours) and for a board that has not landed yet.
  void _consumePendingMoment() {
    if (!mounted || _momentOpening) return;
    final pending = UiSelectionStore.instance.momentIdPending;
    if (pending == null) return;
    final userId = widget.repo.userId;
    if (userId == null) return;
    // Read before consuming — consuming clears it.
    final comments = UiSelectionStore.instance.momentCommentsPending;
    if (UiSelectionStore.instance.consumeMoment() == null) return;

    Moment? known;
    for (final m in FeedStore.instance.moments) {
      if (m.id == pending) {
        known = m;
        break;
      }
    }
    if (known != null) {
      // Opened with the run it belongs to: a point among the day's points, a
      // highlight among the highlights.
      known.tag == null
          ? _openFromActivity(known, null, openComments: comments)
          : _openFromPoint(known, null, openComments: comments);
      return;
    }
    _momentOpening = true;
    unawaited(_openFetchedMoment(userId, pending, openComments: comments));
  }

  Future<void> _openFetchedMoment(
    String userId,
    String momentId, {
    bool openComments = false,
  }) async {
    try {
      final moment = await widget.feedApi.moment(
        userId: userId,
        momentId: momentId,
      );
      // Deleted, unfriended, or made private since the push went out. The
      // person is already on the Feed, which is the right place to have been
      // sent — saying "that's gone" about something they never saw would be
      // noise about a thing they cannot act on.
      if (!mounted || moment == null) return;
      _open(moment, openComments: openComments);
    } catch (_) {
      // Offline, or the fetch lost a race with a sign-out. Same reasoning.
    } finally {
      _momentOpening = false;
    }
  }

  @override
  void dispose() {
    FeedStore.instance.removeListener(_onChange);
    GamesStore.instance.removeListener(_onChange);
    UiSelectionStore.instance.removeListener(_consumePendingGames);
    UiSelectionStore.instance.removeListener(_consumePendingMoment);
    widget.repo.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    // The repo attaching (userId becoming available) is one of the reasons
    // this fires — see [_consumePendingGames].
    _consumePendingGames();
    _revealGames();
    _consumePendingMoment();
  }

  /// Whether this account may publish media.
  ///
  /// Gated on `hasContext` as well as `isChild`, because `FamilyContext.empty`
  /// reads as an unrestricted adult until the family subscription lands — so
  /// checking `isChild` alone hands a child a fully-composed surface on every
  /// cold start that then vanishes underneath them.
  bool get _canCapture {
    final family = widget.family;
    // Until the family subscription lands, `isChild` is false and `policy` is
    // the locked default — so `canSendMedia` alone would read as "yes, adult"
    // on every cold start and then flip. Gate on hasContext first, matching
    // DiscoverScreen._roomsUnlocked.
    if (!family.hasContext) return !family.isChild;
    return family.canSendMedia;
  }

  Future<void> _compose() async {
    final userId = widget.repo.userId;
    if (userId == null) return;
    await showMomentComposer(
      context,
      api: widget.api,
      feedApi: widget.feedApi,
      userId: userId,
    );
    // No refresh call: the board is a live subscription, so a successful post
    // arrives on its own. Awaiting it only keeps the composer's route alive
    // until it closes.
  }

  Future<void> _addPoint() async {
    final userId = widget.repo.userId;
    if (userId == null) return;
    await showPointComposer(
      context,
      api: widget.api,
      feedApi: widget.feedApi,
      userId: userId,
    );
  }

  void _openArchive() {
    final userId = widget.repo.userId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArchiveScreen(
          api: widget.api,
          feedApi: widget.feedApi,
          userId: userId,
        ),
      ),
    );
  }

  void _openPuzzle() {
    final userId = widget.repo.userId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PuzzleScreen(feedApi: widget.feedApi, userId: userId),
      ),
    );
  }

  /// Opens the leaderboard; [tab] picks a game's board over "Today".
  Future<void> _openLeaderboard({int tab = 0}) async {
    final userId = widget.repo.userId;
    if (userId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(
          feedApi: widget.feedApi,
          userId: userId,
          initialTab: tab,
        ),
      ),
    );
  }

  void _openBots() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BotHubScreen()),
    );
  }

  void _openGame(DailyGame game) {
    final userId = widget.repo.userId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => dailyGameScreen(game, userId),
      ),
    );
  }

  /// Opens a moment from the highlights rail. Its picture is on screen, so it
  /// flies; and the rest of the rail comes along as pages you can swipe to,
  /// because "the next highlight" plainly has a meaning here and backing out to
  /// tap the tile beside the one you just looked at is not an answer to it.
  void _openFromRail(Moment moment) =>
      _open(moment, siblings: FeedStore.instance.highlightStories);

  /// Opens a point from the standings board. The picture-less ones rise out of
  /// the line that was tapped; the ones with a photo go full-screen, and the
  /// other scoring points of the day are the run behind them.
  void _openFromPoint(Moment moment, Rect? origin, {bool openComments = false}) =>
      _open(
        moment,
        origin: origin,
        siblings: FeedStore.instance.points,
        openComments: openComments,
      );

  /// Opens a moment from the activity river, whose run is the river itself —
  /// today's highlights, since the points live on the standings board.
  void _openFromActivity(
    Moment moment,
    Rect? origin, {
    bool openComments = false,
  }) =>
      _open(
        moment,
        origin: origin,
        // The rail's order, so the viewer groups the river's pick with the
        // rest of that person's day, oldest first, like the rail does.
        siblings: FeedStore.instance.highlightStories,
        openComments: openComments,
      );

  void _open(
    Moment moment, {
    Rect? origin,
    List<Moment> siblings = const [],
    bool openComments = false,
  }) {
    final userId = widget.repo.userId;
    if (userId == null) return;
    showMomentViewer(
      context,
      moment: moment,
      api: widget.api,
      feedApi: widget.feedApi,
      userId: userId,
      siblings: siblings,
      origin: origin,
      openComments: openComments,
      onOpenProfile: _openProfile,
      viewerAvatarStorageId: _myAvatar,
      resolveUser: widget.repo.userById,
    );
  }

  /// The viewer's own face, for their reactions in the highlight viewer.
  ///
  /// A reaction the viewer just left is drawn before the server has echoed it
  /// (and so before it carries a face), and one left before faces were stored
  /// never will. One cheap read on mount covers both; null until it lands.
  String? _myAvatar;

  Future<void> _loadMyAvatar() async {
    final id = widget.repo.userId;
    if (id == null) return;
    try {
      final me = await widget.api.getProfile(id, viewerUserId: id);
      if (mounted) _myAvatar = me?.avatarStorageId;
    } catch (_) {
      // Offline: their reactions keep the initial, which is what they had.
    }
  }

  /// Someone tapped in a highlight's reactions or comments. Their profile
  /// screen applies their own privacy settings, so whatever they keep to
  /// themselves stays there.
  void _openProfile(ChatUser user) {
    if (user.id == widget.repo.userId) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          user: user,
          repo: widget.repo,
          api: widget.api,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = FeedStore.instance;
    // The river carries highlights only. Points already have a home — the
    // standings board tallies them and tells each one's story — and listing
    // them again here drew every point twice on the same screen.
    final activity = store.highlights;
    // Finished dailies join the river. The games band above only ever shows
    // the viewer's own tiles, so a friend's score had nowhere else to land.
    final plays = store.plays;
    // With friends but nothing to list, the section goes rather than saying
    // "quiet so far" under a board full of points; someone with no friends
    // keeps the hint, because that is what would fill it.
    final noFriends = widget.repo.friends.isEmpty;
    final showActivity = activity.isNotEmpty || plays.isNotEmpty || noFriends;

    // Sections are assembled as a list so the entrance stagger can index them
    // without every section needing to know its own position. Deeper sections
    // travel farther, which is what sells "layers settling" rather than "a list
    // fading in".
    final sections = <({String id, Widget child})>[
      (
        id: 'masthead',
        child: _Masthead(
          edition: store.edition,
          dayKey: store.dayKey,
          settled: _launchShow,
        ),
      ),
      // A board that never loaded is NOT a quiet day, and every section below
      // says "quiet day" when handed an empty list. Without this the two are
      // indistinguishable — which is exactly how a query that had been throwing
      // on every call for hours read as "nobody posted anything".
      if (store.error != null && !store.loaded)
        (id: 'trouble', child: _BoardTrouble(l10n.feedBoardLoadFailed)),
      (
        id: 'highlights',
        child: _SectionShell(
          bleed: true,
          label: l10n.feedBoardHighlightsLabel,
          // Highlights leave friends' boards after a day but are kept
          // forever — without a way in, that promise was invisible.
          actions: [
            SectionAction(
              icon: CupertinoIcons.archivebox,
              label: l10n.feedBoardOpenArchive,
              onTap: _openArchive,
            ),
          ],
          body: store.loaded && store.highlights.isEmpty && !_canCapture
              // A supervised account with media switched off has no way to
              // fill this, so offer the explanation rather than a dead rail.
              ? EmptyLine(
                  l10n.feedBoardHighlightsEmpty,
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kGutter,
                    vertical: 12,
                  ),
                )
              : MomentRail(
                  inset: _kGutter,
                  groups: store.highlightGroups,
                  api: widget.api,
                  serverNow: store.serverNow,
                  canCapture: _canCapture,
                  onCapture: _compose,
                  onOpen: _openFromRail,
                ),
        ),
      ),
      (
        id: 'games',
        child: _SectionShell(
          key: _gamesKey,
          bleed: true,
          label: l10n.feedBoardGamesLabel,
          // The band is an entry point as much as a status line, so the header
          // carries the way in to who is winning. The games themselves live
          // HERE, in one sideways row with the viewer's time and rank on each
          // tile; the page this opens is the leaderboard only, because a second
          // shelf of the same five boxes one tap away read as a repeat.
          // The code puzzle is one of
          // the five drawn here (first tile) rather than a separate section
          // above this one — it's a daily game exactly like the other four,
          // and giving it its own differently-shaped section was the
          // inconsistency, not this shelf.
          actions: [
            SectionAction(
              icon: CupertinoIcons.rosette,
              label: l10n.feedBoardGamesOpen,
              onTap: _openLeaderboard,
            ),
          ],
          body: GamesStrip(
            inset: _kGutter,
            boards: GamesStore.instance.boards,
            results: store.games,
            onOpen: _openGame,
            puzzle: store.puzzle,
            onOpenPuzzle: _openPuzzle,
            ranks: {
              for (final g in DailyGame.values)
                g: ?store.gameRank(g, widget.repo.userId ?? ''),
            },
            puzzleRank: store.puzzleRank(widget.repo.userId ?? ''),
            onOpenBots: _openBots,
          ),
        ),
      ),
      (
        id: 'standings',
        child: _SectionShell(
          label: l10n.feedBoardStandingsLabel,
          // The concept is new enough that the header carries its own
          // explainer — this is not a feed of photos with a score attached, it
          // is a game, and nobody arrives knowing that.
          // Adding a point is the board's own button, under it; the board
          // is short enough now that it never sits below a long list.
          actions: [pointsExplainerAction(context)],
          body: PointsBoard(
            points: store.points,
            viewerId: widget.repo.userId ?? '',
            api: widget.api,
            onAdd: _addPoint,
            onOpen: _openFromPoint,
          ),
        ),
      ),
      if (showActivity)
        (
          id: 'activity',
          child: _SectionShell(
            label: l10n.feedBoardActivityLabel,
            body: activity.isEmpty && plays.isEmpty && noFriends
                // Distinct from "quiet today": someone with no friends yet
                // needs to know what would fill this, not that nothing
                // happened.
                ? EmptyLine(
                    l10n.feedBoardActivityNoFriends,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  )
                : MomentActivity(
                    moments: activity,
                    plays: plays,
                    viewerId: widget.repo.userId ?? '',
                    api: widget.api,
                    // A game result carries no face; friends' come from the
                    // list the app already holds.
                    faceOf: (id) => widget.repo.userById(id)?.avatarStorageId,
                    onOpen: _openFromActivity,
                    onOpenPlay: (play) => _openLeaderboard(
                      tab: LeaderboardScreen.tabOf(play.game),
                    ),
                  ),
          ),
        ),
    ];

    // Keyed by id rather than threaded positionally, so the two layouts below
    // can each pick sections out in whatever order they want while the stagger
    // still travels by each section's ORIGINAL index — a section reordered
    // into the sidebar shouldn't suddenly animate as if it were first.
    final byId = {
      for (var i = 0; i < sections.length; i++) sections[i].id: (i, sections[i].child),
    };

    Widget staggered(String id) {
      final entry = byId[id];
      if (entry == null) return const SizedBox.shrink();
      final (index, section) = entry;
      // The page margin lives on each section, not on the scroll view, so
      // the sideways rows can run to the screen's edges (see
      // [_SectionShell.bleed]).
      final child = section is _SectionShell && section.bleed
          ? section
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kGutter),
              child: section,
            );
      if (_launchShow) return KeyedSubtree(key: ValueKey(id), child: child);
      return TweenAnimationBuilder<double>(
        // Stable section id, never the index. The board's sections will start
        // appearing and disappearing conditionally in later phases, and an
        // index key re-matches elements on that change — handing a section
        // someone else's state.
        key: ValueKey(id),
        tween: Tween(begin: 0, end: 1),
        duration: motion.stagger(theme.motionMed, index, strideMs: 70),
        // motionEntrance, never motionCurve: Risograph and Cyberpunk set
        // motionCurve to easeOutBack, which overshoots past 1.0 and would
        // assert on the Opacity here.
        curve: motion.c(theme.motionEntrance),
        builder: (context, v, child) => Transform.translate(
          offset: Offset(0, (1 - v) * (10 + 8 * index)),
          child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
        ),
        child: child,
      );
    }

    // Expanded windows get a wide dashboard instead of one long reading
    // column: a phone-width board just centred in a wide browser tab is what
    // this screen looked like before this split existed.
    //
    // Highlights and Games stay full-width bands rather than joining the
    // split below — Games especially: at sidebar width its tiles were ~70px
    // postage stamps, and "the games look tiny" was the whole complaint this
    // shape exists to fix. What's left (standings, activity) runs as two
    // even columns rather than a wide main column beside a cramped 320px
    // sidebar — with the puzzle promoted into the games shelf above, a
    // sidebar with exactly one thing left in it read as an afterthought
    // rather than a considered second column, and each is capped at its own
    // comfortable reading width instead of stretching edge to edge, so a
    // one-line "so-and-so added a point" row doesn't end up dragging a
    // trailing empty run halfway across the screen.
    final Widget body = context.isExpanded
        ? SingleChildScrollView(
            controller: _scroll,
            key: const PageStorageKey('feed_board_v2_wide'),
            padding: EdgeInsets.fromLTRB(
              0,
              TabRootBar.clearance(context),
              0,
              sectionBottomPadding(context),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ContentWidth.wide),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    staggered('masthead'),
                    staggered('trouble'),
                    staggered('highlights'),
                    staggered('games'),
                    // `Expanded`, not a fixed width centred as a pair — every
                    // band above spans the full column edge to edge, and a
                    // centred pair left Standings starting well right of
                    // where HIGHLIGHTS/GAMES did.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 40 between them: each column's own 20pt margin.
                        Expanded(child: staggered('standings')),
                        Expanded(child: staggered('activity')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        : AdaptivePageBody(
            child: ListView(
              controller: _scroll,
              // Versioned so the offset can be deliberately dropped when the
              // section order changes. Bumped to _v2 when THE GAMES landed
              // between the puzzle and the standings: a restored offset from
              // before that band existed lands the board mid-section, which
              // reads as the Feed having jumped on its own.
              key: const PageStorageKey('feed_board_v2'),
              // The bar's clearance + the masthead's own 6 lands the large
              // title exactly where the chat list's sits, so switching tabs
              // never jumps it.
              padding: EdgeInsets.fromLTRB(
                0,
                TabRootBar.clearance(context),
                0,
                sectionBottomPadding(context),
              ),
              children: [for (final s in sections) staggered(s.id)],
            ),
          );

    return Stack(
      children: [
        theme.backgroundLayer(context),
        // Above the themed backdrop, below the content: the field has to read
        // as light moving over Risograph's halftone and Cyberpunk's scanlines,
        // not as a replacement for them.
        Positioned.fill(child: FeedDepthField(scroll: _scroll)),
        // Edge to edge: the bar clears the status bar, and the list's top
        // padding starts below it. The top inset is spent here, so a nested
        // shrink-wrapped list does not pick it up again. See home_screen:
        // bottom inset here leaves a dead strip under the scroller;
        // `sectionBottomPadding` does the clearing.
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: body,
        ),
        TabRootBar(title: l10n.destinationsFeedLabel, scroll: _scroll),
      ],
    );
  }
}

/// The board's masthead: brand mark, wordmark, today's date and edition number.
///
/// The wordmark settles its letter-spacing once per day. Latched in [FeedStore]
/// rather than in this widget's `State`, because a tab switch or theme change
/// disposes the whole screen — a local flag would replay the intro every time
/// the user came back to the tab.
class _Masthead extends StatefulWidget {
  const _Masthead({required this.edition, required this.dayKey, this.settled = false});

  final int edition;
  final String dayKey;

  /// Start in place, with the day's intro counted as played: the app's own
  /// launch already was the arrival.
  final bool settled;

  @override
  State<_Masthead> createState() => _MastheadState();
}

class _MastheadState extends State<_Masthead>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ThemeScope is not available in initState — the house rule for every
    // animated widget that reads a theme duration.
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    _settle.duration = motion.d(theme.motionSlow);

    if (FeedStore.instance.introPlayed || widget.settled) {
      FeedStore.instance.markIntroPlayed();
      _settle.value = 1;
    } else {
      FeedStore.instance.markIntroPlayed();
      _settle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    // Localized via MaterialLocalizations rather than `intl`: the latter is
    // only a transitive dependency here, and promoting it to a direct one for a
    // single date string is not worth the resolution risk.
    //
    // Deliberately NOT .toUpperCase()'d despite the all-caps band styling
    // elsewhere on this board. Dart's toUpperCase is locale-independent, so a
    // Turkish date containing 'i' would come back with a dotless 'I' instead of
    // 'İ' — a real, visible mistranslation in one of this app's 12 locales.
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime.now());

    // The tab's large title, same size and place as Chats and Discover. On
    // the first open of the day it rises a few points into place on a soft
    // spring — the board arriving — then the date and the edition settle in
    // under it.
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 26),
      child: AnimatedBuilder(
        animation: _settle,
        builder: (context, _) {
          final v = _settle.value;
          final rise = const ElasticOutCurve(0.8).transform(v);
          final tail = Curves.easeOut.transform(((v - 0.35) / 0.65).clamp(0.0, 1.0));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.translate(
                offset: Offset(0, (1 - rise) * 14),
                child: Opacity(
                  opacity: Curves.easeOut.transform((v * 2).clamp(0.0, 1.0)),
                  child: Text(
                    l10n.destinationsFeedLabel,
                    style: theme.displayLarge.copyWith(letterSpacing: 0.37),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Opacity(
                opacity: tail,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        date,
                        style: theme.body.copyWith(
                          fontSize: 15,
                          color: theme.inkMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tappable, because "№219" beside a date is a riddle
                    // otherwise — it is the board's day count.
                    _EditionStamp(
                      label: l10n.feedBoardEditionLabel(widget.edition),
                      hint: l10n.feedBoardEditionHint(widget.edition),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The colophon's day count, and the one tap that explains what it counts.
///
/// Its own widget so the tap handler is written once; [SpringPress] carries
/// both the press and the keyboard focus ring.
class _EditionStamp extends StatelessWidget {
  const _EditionStamp({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    void explain() => showAppToast(context, hint);
    return SpringPress(
      onTap: explain,
      semanticLabel: hint,
      focusShape: FocusRingShape.capsule,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: quietFill(theme),
          borderRadius: BorderRadius.circular(999),
        ),
        // The body face, not the theme's caption: on character themes that
        // slot is tracked monospace.
        child: Text(
          label,
          style: metaText(theme, color: theme.inkSoft).copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

/// One band of the board: the shared page-section header (the theme's
/// display face, sentence case, an optional accent text link on the same
/// baseline — the App Store / Music shape) over its body.
///
/// The header is [PageSectionHeader], the same one Discover uses, so the two
/// tabs cannot drift apart. No rule — the air above separates the bands.
/// The board's side margin. Applied per section rather than on the scroll
/// view, so a full-bleed row can ignore it.
const double _kGutter = 20;

/// How much of the section above the Games band stays in view when a games
/// notification scrolls to it: enough to read that the Feed scrolled, not so
/// much that the band sits mid-screen.
const _kGamesRevealPeek = 28.0;

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    super.key,
    required this.label,
    required this.body,
    this.actions = const [],
    this.bleed = false,
  });

  final String label;
  final Widget body;

  /// The body runs to the screen's edges (a sideways row that lays the
  /// margin inside its own scroll view); only the header keeps the page
  /// margin. Otherwise the whole band sits in the margin.
  final bool bleed;

  /// The band's buttons on its header: the archive, the leaderboard, the
  /// points explainer and Add. Capsules ([SectionActionButton]), one shape
  /// for all of them, so a header's way in reads as a real destination.
  final List<SectionAction> actions;

  @override
  Widget build(BuildContext context) {
    // 32 between bands and the header's own 10 to its body: the tab-root
    // rhythm every tab shares (§A of the round-2 spec).
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: bleed ? _kGutter : 0),
            child: PageSectionHeader(label, actions: actions),
          ),
          body,
        ],
      ),
    );
  }
}

/// The board could not be loaded at all.
///
/// Deliberately louder than [EmptyLine] — muted grey is the vocabulary this
/// board uses for "nothing happened today", and a broken subscription wearing
/// that same colour is what made a hard failure invisible for a whole day.
class _BoardTrouble extends StatelessWidget {
  const _BoardTrouble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 15,
            color: theme.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.bodySoft.copyWith(color: theme.danger),
            ),
          ),
        ],
      ),
    );
  }
}
