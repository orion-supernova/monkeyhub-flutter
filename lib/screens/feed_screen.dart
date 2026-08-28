import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../backend/feed_api.dart';
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
import '../widgets/games_strip.dart';
import '../widgets/moment_activity.dart';
import '../widgets/moment_rail.dart';
import '../widgets/points_board.dart';
import 'feed/archive_screen.dart';
import 'feed/moment_composer.dart';
import 'feed/moment_viewer.dart';
import 'feed/point_composer.dart';
import 'feed/points_explainer.dart';
import 'feed/puzzle_screen.dart';
import 'games/games_hub_screen.dart';
import 'games/queens_screen.dart';
import 'games/sudoku_screen.dart';
import 'games/tango_screen.dart';
import 'games/zip_screen.dart';
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
    // The empty state turns on the friend count, so the board has to rebuild
    // when a friend request is accepted while it is on screen.
    widget.repo.addListener(_onChange);
    // A daily-games nudge tapped before this screen existed is still waiting in
    // the store — including on a cold start, where the tap lands long before
    // any widget mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePendingGames());
    // …and the same request arriving while this screen is ALREADY on it. The
    // post-frame callback above only fires on mount, and steering the shell to
    // a section it is already showing remounts nothing — so a nudge tapped by
    // somebody who happened to be looking at the Feed would have set the
    // one-shot and then had nobody left to consume it.
    UiSelectionStore.instance.addListener(_consumePendingGames);
  }

  /// Whether the games hub is already up, so a second request does not stack a
  /// second copy of it on top of the first.
  bool _gamesHubOpen = false;

  /// Opens the games hub for a tapped daily nudge.
  ///
  /// Pushed from HERE rather than from app.dart's push handler so the route
  /// lands on whichever navigator this Feed belongs to — the root one on a
  /// phone, and the section's own on a wide window, where a root push would
  /// cover the shell it was just told to show.
  ///
  /// Peeks [gamesViewPending] rather than consuming it up front: on a cold
  /// start, `HomeShell`/this screen can mount before `ChatRepository.attach`
  /// has run — `_applyAuthChange` in app.dart awaits the call-stack attach
  /// first — so `widget.repo.userId` (and therefore [_openGamesHub], which
  /// needs it) is briefly unavailable. Consuming the one-shot here regardless
  /// would drop the notification on the floor with nothing left to retry it.
  /// [_onChange] re-runs this once the repo attaches and notifies.
  void _consumePendingGames() {
    if (!mounted) return;
    if (!UiSelectionStore.instance.gamesViewPending) return;
    if (widget.repo.userId == null) return;
    if (!UiSelectionStore.instance.consumeGamesView()) return;
    if (_gamesHubOpen) return;
    _openGamesHub();
  }

  @override
  void dispose() {
    FeedStore.instance.removeListener(_onChange);
    GamesStore.instance.removeListener(_onChange);
    UiSelectionStore.instance.removeListener(_consumePendingGames);
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

  Future<void> _openGamesHub() async {
    final userId = widget.repo.userId;
    if (userId == null) return;
    _gamesHubOpen = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              GamesHubScreen(feedApi: widget.feedApi, userId: userId),
        ),
      );
    } finally {
      _gamesHubOpen = false;
    }
  }

  void _openGame(DailyGame game) {
    final userId = widget.repo.userId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => switch (game) {
          DailyGame.queens => QueensScreen(userId: userId),
          DailyGame.tango => TangoScreen(userId: userId),
          DailyGame.zip => ZipScreen(userId: userId),
          DailyGame.sudoku => SudokuScreen(userId: userId),
        },
      ),
    );
  }

  /// Opens a moment from the highlights rail. Its picture is on screen, so it
  /// flies; and the rest of the rail comes along as pages you can swipe to,
  /// because "the next highlight" plainly has a meaning here and backing out to
  /// tap the tile beside the one you just looked at is not an answer to it.
  void _openFromRail(Moment moment) =>
      _open(moment, siblings: FeedStore.instance.highlights);

  /// Opens a point from the standings board. The picture-less ones rise out of
  /// the line that was tapped; the ones with a photo go full-screen, and the
  /// other scoring points of the day are the run behind them.
  void _openFromPoint(Moment moment, Rect? origin) =>
      _open(moment, origin: origin, siblings: FeedStore.instance.points);

  /// Opens a moment from the activity river, whose run is the whole day.
  void _openFromActivity(Moment moment, Rect? origin) =>
      _open(moment, origin: origin, siblings: FeedStore.instance.moments);

  void _open(
    Moment moment, {
    Rect? origin,
    List<Moment> siblings = const [],
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = FeedStore.instance;

    // Sections are assembled as a list so the entrance stagger can index them
    // without every section needing to know its own position. Deeper sections
    // travel farther, which is what sells "layers settling" rather than "a list
    // fading in".
    final sections = <({String id, Widget child})>[
      (
        id: 'masthead',
        child: _Masthead(edition: store.edition, dayKey: store.dayKey),
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
          label: l10n.feedBoardHighlightsLabel,
          // Highlights leave friends' boards after a day but are kept
          // forever — without a way in, that promise was invisible.
          action: _HeaderAction(
            icon: Icons.inventory_2_outlined,
            label: l10n.feedBoardOpenArchive,
            onTap: _openArchive,
          ),
          body: store.loaded && store.highlights.isEmpty && !_canCapture
              // A supervised account with media switched off has no way to
              // fill this, so offer the explanation rather than a dead rail.
              ? _EmptyLine(l10n.feedBoardHighlightsEmpty)
              : MomentRail(
                  moments: store.highlights,
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
          label: l10n.feedBoardGamesLabel,
          // The band is an entry point as much as a status line, so the header
          // carries the way in to the rest of them — five boards do not fit a
          // Feed section, and burying the hub behind a tile would make the two
          // extra taps the reason nobody plays them. The code puzzle is one of
          // the five drawn here (first tile) rather than a separate section
          // above this one — it's a daily game exactly like the other four,
          // and giving it its own differently-shaped section was the
          // inconsistency, not this shelf.
          action: _HeaderAction(
            icon: Icons.grid_view_outlined,
            label: l10n.feedBoardGamesOpen,
            onTap: _openGamesHub,
          ),
          body: GamesStrip(
            boards: GamesStore.instance.boards,
            results: store.games,
            onOpen: _openGame,
            puzzle: store.puzzle,
            onOpenPuzzle: _openPuzzle,
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
          action: _HeaderAction(
            icon: Icons.help_outline,
            label: l10n.pointsExplainerOpen,
            onTap: () => showPointsExplainer(context),
          ),
          body: PointsBoard(
            points: store.points,
            viewerId: widget.repo.userId ?? '',
            onAdd: _addPoint,
            onOpen: _openFromPoint,
          ),
        ),
      ),
      (
        id: 'activity',
        child: _SectionShell(
          label: l10n.feedBoardActivityLabel,
          body: store.moments.isEmpty && widget.repo.friends.isEmpty
              // Distinct from "quiet today": someone with no friends yet needs
              // to know what would fill this, not that nothing happened.
              ? _EmptyLine(l10n.feedBoardActivityNoFriends)
              : MomentActivity(
                  moments: store.moments,
                  viewerId: widget.repo.userId ?? '',
                  onOpen: _openFromActivity,
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
      final (index, child) = entry;
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
              20,
              28,
              20,
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
                        Expanded(child: staggered('standings')),
                        const SizedBox(width: 40),
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
              padding: EdgeInsets.fromLTRB(
                20,
                28,
                20,
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
        // See home_screen: bottom inset here leaves a dead strip under the
        // scroller; `sectionBottomPadding` does the clearing.
        SafeArea(bottom: false, child: body),
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
  const _Masthead({required this.edition, required this.dayKey});

  final int edition;
  final String dayKey;

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

    if (FeedStore.instance.introPlayed) {
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: AnimatedBuilder(
        animation: _settle,
        builder: (context, _) {
          final t = Curves.easeOutQuart.transform(_settle.value);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.feedBoardTitle,
                // Settles from wide-set to the board's resting spacing.
                // Interpolating letterSpacing rather than scale keeps the
                // baseline fixed, so nothing below it moves.
                style: theme.label.copyWith(
                  letterSpacing: 9.0 - (9.0 - 3.0) * t,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      date,
                      style: theme.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 1, color: theme.divider)),
                  const SizedBox(width: 8),
                  Opacity(
                    // The edition stamp arrives last, in the tail of the
                    // settle — the colophon landing after the masthead sets.
                    opacity: Curves.easeOut.transform(
                      ((_settle.value - 0.6) / 0.4).clamp(0.0, 1.0),
                    ),
                    // Tappable, because "№219" beside a date is a riddle
                    // otherwise — it is the board's day count, and there is
                    // nowhere else that could possibly say so.
                    child: _EditionStamp(
                      label: l10n.feedBoardEditionLabel(widget.edition),
                      hint: l10n.feedBoardEditionHint(widget.edition),
                    ),
                  ),
                ],
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
/// Its own widget so the tap handler is written once. `FocusableTap` registers
/// no gesture recognizer of its own, so the bare `GestureDetector` inside is
/// what actually receives the pointer and both have to carry the handler —
/// which spelled inline was the same three-line closure twice.
class _EditionStamp extends StatelessWidget {
  const _EditionStamp({required this.label, required this.hint});

  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    void explain() => showAppToast(context, hint);
    return FocusableTap(
      onTap: explain,
      semanticLabel: hint,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: explain,
        behavior: HitTestBehavior.opaque,
        child: Text(label, style: theme.monoTiny, maxLines: 1),
      ),
    );
  }
}

/// One band of the board: an all-caps label, a hairline rule, and a body.
///
/// Mirrors `DiscoverSectionHeader`'s geometry so the two screens read as the
/// same app. Not reusing that widget directly because it takes a `count` string
/// this board has no use for yet — the phases that add real counts should
/// revisit whether these should merge.
class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.label,
    required this.body,
    this.action,
  });

  final String label;
  final Widget body;

  /// Optional trailing control on the band — currently only the points
  /// explainer. Sits after the rule so the rule still separates label from
  /// content at every width.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(label, style: theme.label),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: theme.divider)),
              if (action != null) ...[const SizedBox(width: 8), action!],
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

/// A small trailing control on a section band — the archive link, the points
/// explainer. One widget so the two cannot drift apart visually.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: theme.accentSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: theme.accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.monoTiny.copyWith(color: theme.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single muted line standing in for a section with nothing in it.
///
/// Matches `DiscoverEmptyLine`'s register: lowercase, conversational, and
/// stating what would put something here rather than merely reporting absence.
class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Text(text, style: theme.bodySoft.copyWith(color: theme.inkMuted));
  }
}

/// The board could not be loaded at all.
///
/// Deliberately louder than [_EmptyLine] — muted grey is the vocabulary this
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
          Icon(Icons.error_outline, size: 15, color: theme.danger),
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
