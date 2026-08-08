import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../backend/feed_api.dart';
import '../data/chat_repository.dart';
import '../data/feed_store.dart';
import '../data/games_store.dart';
import '../data/settings_store.dart';
import '../family/family_service.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/daily_game.dart';
import '../models/moment.dart';
import '../models/puzzle.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/feed_depth_field.dart';
import '../widgets/games_strip.dart';
import '../widgets/moment_activity.dart';
import '../widgets/moment_rail.dart';
import '../widgets/points_board.dart';
import '../widgets/puzzle_score_strip.dart';
import '../widgets/puzzle_symbol.dart';
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
  final _scroll = ScrollController();

  @override
  HomeSection get reselectSection => HomeSection.feed;
  @override
  ScrollController get reselectScroll => _scroll;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    FeedStore.instance.removeListener(_onChange);
    GamesStore.instance.removeListener(_onChange);
    widget.repo.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
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

  void _openGamesHub() {
    final userId = widget.repo.userId;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GamesHubScreen(feedApi: widget.feedApi, userId: userId),
      ),
    );
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

  /// Opens a moment from the highlights rail, where its picture is on screen and
  /// can fly to the viewer. A caption-only card has no picture to fly, and
  /// claiming a tag for one would leave the viewer waiting on a flight that
  /// never departs.
  void _openFromRail(Moment moment) => _open(
    moment,
    heroTag: moment.thumbStorageId == null
        ? null
        : momentMediaHeroTag(moment.id),
  );

  /// Opens a moment from a text row — a point, an activity line. There is no
  /// picture to fly, so the viewer's card rises out of the row that was tapped.
  void _openFromRow(Moment moment, Rect? origin) =>
      _open(moment, origin: origin);

  void _open(Moment moment, {Object? heroTag, Rect? origin}) {
    final userId = widget.repo.userId;
    if (userId == null) return;
    showMomentViewer(
      context,
      moment: moment,
      api: widget.api,
      feedApi: widget.feedApi,
      userId: userId,
      heroTag: heroTag,
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
        id: 'puzzle',
        child: _SectionShell(
          label: l10n.feedBoardPuzzleLabel,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PuzzleTile(
                state: store.puzzle,
                viewerId: widget.repo.userId ?? '',
                onTap: _openPuzzle,
              ),
              // The scoreboard belongs HERE, not only inside the puzzle
              // screen. A daily game whose scores you have to navigate to see
              // is a daily game nobody compares — which is the entire reason
              // it exists.
              if (store.puzzle.scores.isNotEmpty) ...[
                const SizedBox(height: 12),
                PuzzleScoreStrip(
                  state: store.puzzle,
                  viewerId: widget.repo.userId ?? '',
                ),
              ],
            ],
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
          // extra taps the reason nobody plays them.
          action: _HeaderAction(
            icon: Icons.grid_view_outlined,
            label: l10n.feedBoardGamesOpen,
            onTap: _openGamesHub,
          ),
          body: GamesStrip(
            boards: GamesStore.instance.boards,
            results: store.games,
            onOpen: _openGame,
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
            onOpen: _openFromRow,
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
                  onOpen: _openFromRow,
                ),
        ),
      ),
    ];

    return Stack(
      children: [
        theme.backgroundLayer(context),
        // Above the themed backdrop, below the content: the field has to read
        // as light moving over Risograph's halftone and Cyberpunk's scanlines,
        // not as a replacement for them.
        Positioned.fill(child: FeedDepthField(scroll: _scroll)),
        SafeArea(
          child: AdaptivePageBody(
            child: ListView(
              controller: _scroll,
              // Versioned so the offset can be deliberately dropped when the
              // section order changes. Bumped to _v2 when THE GAMES landed
              // between the puzzle and the standings: a restored offset from
              // before that band existed lands the board mid-section, which
              // reads as the Feed having jumped on its own.
              key: const PageStorageKey('feed_board_v2'),
              padding: const EdgeInsets.fromLTRB(
                20,
                28,
                20,
                kFloatingNavClearance,
              ),
              children: [
                for (var i = 0; i < sections.length; i++)
                  TweenAnimationBuilder<double>(
                    // Stable section id, never the index. The board's sections
                    // will start appearing and disappearing conditionally in
                    // later phases, and an index key re-matches elements on
                    // that change — handing a section someone else's state.
                    key: ValueKey(sections[i].id),
                    tween: Tween(begin: 0, end: 1),
                    duration: motion.stagger(theme.motionMed, i, strideMs: 70),
                    // motionEntrance, never motionCurve: Risograph and
                    // Cyberpunk set motionCurve to easeOutBack, which
                    // overshoots past 1.0 and would assert on the Opacity here.
                    curve: motion.c(theme.motionEntrance),
                    builder: (context, v, child) => Transform.translate(
                      offset: Offset(0, (1 - v) * (10 + 8 * i)),
                      child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                    ),
                    child: sections[i].child,
                  ),
              ],
            ),
          ),
        ),
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
                    child: FocusableTap(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.feedBoardEditionHint(widget.edition),
                          ),
                        ),
                      ),
                      semanticLabel: l10n.feedBoardEditionHint(widget.edition),
                      shape: FocusRingShape.capsule,
                      child: GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.feedBoardEditionHint(widget.edition),
                            ),
                          ),
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          l10n.feedBoardEditionLabel(widget.edition),
                          style: theme.monoTiny,
                          maxLines: 1,
                        ),
                      ),
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

/// The board's summary of today's puzzle.
///
/// Three states, and the difference between them is the whole point of the
/// tile: not started (an invitation), in progress (how many tries are left),
/// finished (your score and where it put you). A tile that looked the same in
/// all three would give nobody a reason to glance at it.
class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({
    required this.state,
    required this.viewerId,
    required this.onTap,
  });

  final PuzzleState state;
  final String viewerId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final mine = state.mine;
    final rank = state.rankOf(viewerId);

    final String headline;
    if (mine == null || !mine.started) {
      headline = l10n.puzzleTilePlay;
    } else if (!mine.done) {
      headline = l10n.puzzleTileInProgress(mine.remaining);
    } else {
      headline = mine.solved
          ? l10n.puzzleSolvedTitle(mine.guesses.length)
          : l10n.puzzleFailedTitle;
    }

    return FocusableTap(
      onTap: onTap,
      semanticLabel: headline,
      radius: theme.radiusLg,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: theme.roomCardDecoration(
            // Reuse the ephemeral treatment as the "unplayed" state — it is
            // the theme's own way of saying "this is on a clock", which is
            // exactly what an unplayed daily puzzle is.
            ephemeral: mine == null || !mine.started,
            active: false,
          ),
          child: Row(
            children: [
              // A hint of the alphabet, so the tile shows what the game looks
              // like rather than only describing it.
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PuzzleSymbol(index: i, size: 18, accent: theme.accent),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: theme.bodyEmph,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rank != null && state.scores.length > 1)
                      Text(
                        l10n.puzzleTileRank(rank, state.scores.length),
                        style: theme.monoTiny,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
            ],
          ),
        ),
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
