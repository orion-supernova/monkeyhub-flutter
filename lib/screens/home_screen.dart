import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/room_filter.dart';
import '../data/settings_store.dart';
import '../family/family_service.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/archived_chats_sheet.dart';
import '../widgets/chat_row_action_menu.dart';
import '../widgets/pull_reveal_panel.dart';
import '../widgets/room_card.dart';
import '../widgets/room_filter_bar.dart';
import '../widgets/room_filter_drawer.dart';
import '../widgets/room_grid_tile.dart';
import '../widgets/user_avatar.dart';
import 'navigation/destinations.dart';
import 'navigation/open_room.dart';
import 'navigation/tab_reselect.dart';
import 'create_room_sheet.dart';
import 'profile_screen.dart';

/// The page margin every element on this screen lines up with.
///
/// Carried per child rather than by the scroll view, because the filter chip
/// row has to be laid out edge to edge and inset itself.
const _gutter = EdgeInsets.symmetric(horizontal: 20);

/// Your conversations, and nothing else.
///
/// Discover (public rooms) and Friends used to live here as sibling tabs, above
/// a hero headline that restated the tab you were already on. Both were really
/// *ways to find things* rather than peers of your own chat list, so they moved
/// to their own shell section and this screen collapsed to one header row, a
/// filter control, and the list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repo,
    required this.api,
    required this.auth,
    required this.family,
  });
  final ChatRepository repo;
  final ChatApi api;
  final AuthService auth;
  final FamilyService family;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TabReselectScroll<HomeScreen> {
  ChatUser? _me;

  /// Whether the drawer-style filter panel is open. Purely presentational, so
  /// unlike the filter itself it isn't persisted.
  bool _filterExpanded = false;

  final _scroll = ScrollController();

  // ───────── in-place search ─────────

  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ───────── pull-down-at-top reveal (search field + Archived Chats) ─────────

  /// Live drag distance while pulling at the top of the list, 0 when idle.
  double _pullDrag = 0;

  /// True only between the first live drag sample and release — see
  /// [PullRevealSlot] for what this changes about the reveal's timing.
  bool _dragging = false;
  bool _pullPanelOpen = false;
  static const _pullOpenThreshold = 64.0;
  static const _pullMaxDrag = 96.0;

  @override
  HomeSection get reselectSection => HomeSection.chat;
  @override
  ScrollController get reselectScroll => _scroll;

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onChange);
    widget.family.addListener(_onChange);
    // The filter and its style both live in SettingsStore. HomeShell also
    // listens and would rebuild us anyway, but depending on an ancestor's
    // subscription to stay correct is the kind of coupling that breaks quietly;
    // two setState calls in one frame coalesce into a single rebuild.
    SettingsStore.instance.addListener(_onChange);
    // `_me` is fetched once and drives the header avatar, with the session as
    // its stand-in until then. A handle change rewrites the session and would
    // otherwise leave both here showing the old one until this screen is
    // rebuilt from scratch — which, being the app's home, it rarely is.
    widget.auth.addListener(_onAuth);
    _loadMe();
  }

  void _onAuth() {
    if (mounted) _loadMe();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onChange);
    widget.family.removeListener(_onChange);
    SettingsStore.instance.removeListener(_onChange);
    widget.auth.removeListener(_onAuth);
    _scroll.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _searchQuery = v);
    });
  }

  /// The field's own clear button — instant, not debounced. A user tapping
  /// "clear" wants the list back immediately, not after the same 250ms a
  /// typed keystroke waits out.
  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
  }

  /// Matches on the resolved, on-screen label (a friend's display name, or
  /// the localized "Saved Messages" string) rather than the raw room `name` —
  /// a DM's name is `dm:regular:<id>:<id>`, which contains nothing a user
  /// would ever type.
  bool _matchesSearch(ChatRoom r, String query) {
    final needle = query.toLowerCase();
    final label = r.isSavedMessages
        ? AppLocalizations.of(context).savedMessagesTitle
        : (widget.repo.otherUserFor(r)?.displayName ?? r.name);
    return label.toLowerCase().contains(needle);
  }

  /// Tracks the overscroll-at-the-top gesture that reveals [PullRevealSlot].
  /// Once the panel is open it is ordinary list content and this stops
  /// intervening — see the panel's own collapse chevron for how it closes.
  ///
  /// Two physics families report a pull-past-the-top completely differently,
  /// and both need handling — relying on only one silently broke the gesture
  /// on whichever platform uses the other:
  ///   - Clamping (Android default): `pixels` stays pinned at the boundary,
  ///     and each denied delta is reported separately via
  ///     `OverscrollNotification.overscroll`.
  ///   - Bouncing (iOS default): nothing is ever "denied" —
  ///     `BouncingScrollPhysics.applyBoundaryConditions` always returns 0, so
  ///     `OverscrollNotification` never fires at all. `pixels` genuinely goes
  ///     negative instead, delivered as an ordinary `ScrollUpdateNotification`
  ///     whose `metrics.pixels` IS the absolute overscroll amount.
  /// Both branches also require `dragDetails != null` — non-null only while a
  /// real finger drag is in progress, null during the ballistic spring-back
  /// Flutter runs after release, which would otherwise be misread as a second
  /// pull while the position animates back to zero.
  bool _onScrollNotification(ScrollNotification n) {
    if (_pullPanelOpen) return false;
    if (n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        n.metrics.pixels < 0) {
      setState(() {
        _dragging = true;
        _pullDrag = (-n.metrics.pixels).clamp(0.0, _pullMaxDrag);
      });
    } else if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0 &&
        n.metrics.pixels <= n.metrics.minScrollExtent) {
      setState(() {
        _dragging = true;
        _pullDrag = (_pullDrag - n.overscroll).clamp(0.0, _pullMaxDrag);
      });
    } else if (n is ScrollEndNotification && _dragging) {
      final openNow = _pullDrag >= _pullOpenThreshold;
      setState(() {
        _dragging = false;
        _pullPanelOpen = openNow;
        _pullDrag = 0;
      });
    }
    return false;
  }

  void _onChange() {
    if (!mounted) return;
    // Switching to chips unmounts the panel, so a left-open drawer would
    // otherwise stay `true` invisibly and spring back open on the way back.
    if (SettingsStore.instance.filterStyle != FilterStyle.drawer) {
      _filterExpanded = false;
    }
    setState(() {});
  }

  Future<void> _loadMe() async {
    final session = widget.auth.session;
    if (session == null) return;
    try {
      final fresh = await widget.api.getProfile(
        session.userId,
        viewerUserId: session.userId,
      );
      if (!mounted || fresh == null) return;
      setState(() => _me = fresh);
    } catch (_) {}
  }

  void _setFilter(RoomFilter next) =>
      SettingsStore.instance.setRoomFilter(next);

  void _clearFilter() {
    HapticFeedback.lightImpact();
    SettingsStore.instance.setRoomFilter(RoomFilter.empty);
  }

  void _openCreate() {
    HapticFeedback.lightImpact();
    showAdaptiveSheet(
      context,
      builder: (_) => CreateRoomSheet(repo: widget.repo, api: widget.api),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final session = widget.auth.session;
    if (session == null) return const SizedBox.shrink();

    final settings = SettingsStore.instance;
    final filter = settings.roomFilter;
    // Resolved once per build and threaded down. `repo.activeRooms` allocates
    // an unmodifiable view on every call and the repository notifies on every
    // typing keystroke in any room, so the cue and the list must not each go
    // and filter it themselves. Archived rooms never enter this pipeline —
    // they're reachable only through the Archived Chats sheet.
    final allRooms = widget.repo.activeRooms;
    final searching = _searchQuery.trim().isNotEmpty;
    final matched = searching
        ? allRooms.where((r) => _matchesSearch(r, _searchQuery)).toList()
        : allRooms;
    final visibleRooms = filter.apply(matched);
    // Projected, not the repository's raw totals: every number on a filter
    // control is what tapping it would actually show. Deliberately against
    // `allRooms`, not `matched` — the facet chips describe the chat list as a
    // whole, not the in-progress search.
    final counts = RoomFacetCounts.projected(allRooms, filter);
    final me =
        _me ??
        ChatUser(
          id: session.userId,
          username: session.username,
          name: session.name,
        );

    final chipsStyle = settings.filterStyle == FilterStyle.chips;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  me: me,
                  api: widget.api,
                  greeting: session.name.split(' ').first.toLowerCase(),
                  // The same profile Settings opens, not a lesser one. Without
                  // `auth` and `family` the screen silently drops its whole
                  // ACCOUNT section — family, linked accounts, recovery phrase,
                  // sign out, delete — so tapping your own avatar used to land
                  // on a page that looked like your profile with half of it
                  // missing, and the missing half is the half people go looking
                  // for.
                  onProfileTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        user: me,
                        repo: widget.repo,
                        api: widget.api,
                        auth: widget.auth,
                        family: widget.family,
                      ),
                    ),
                  ),
                  // No longer conditional on which tab you're looking at — the
                  // create affordance used to appear and vanish as you moved
                  // between Rooms and Friends, which made it feel unreliable.
                  onCreateTap: widget.family.canCreateRooms
                      ? _openCreate
                      : null,
                  filterButton: chipsStyle
                      ? null
                      : RoomFilterButton(
                          filter: filter,
                          expanded: _filterExpanded,
                          onTap: () => setState(
                            () => _filterExpanded = !_filterExpanded,
                          ),
                        ),
                ),
                Expanded(
                  // No horizontal padding here — the chip row has to reach the
                  // screen edge to scroll off it, so the page margin lives on
                  // each child instead of on the viewport.
                  //
                  // The two NotificationListeners implement the pull-down-at-
                  // the-top reveal for the search field / Archived Chats row:
                  // the outer one silences Android's default overscroll glow
                  // (Flutter's own documented pattern for a custom overscroll
                  // affordance), the inner one tracks the drag itself. Neither
                  // requires bouncing physics — Flutter dispatches
                  // OverscrollNotification on a drag past either edge under
                  // any ScrollPhysics, which is what already powers that glow.
                  child: NotificationListener<OverscrollIndicatorNotification>(
                    onNotification: (n) {
                      n.disallowIndicator();
                      return true;
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: ListView(
                        key: const PageStorageKey('home_main_list'),
                        controller: _scroll,
                        // Required, not cosmetic: a list shorter than its
                        // viewport (a new account with one or two chats) is
                        // otherwise judged "not scrollable" and never emits
                        // overscroll at all — silently breaking the pull
                        // gesture for exactly the accounts that most need an
                        // easy path to Archived Chats.
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          0,
                          14,
                          0,
                          kFloatingNavClearance,
                        ),
                        children: [
                          PullRevealSlot(
                            dragExtent: _pullDrag,
                            dragThreshold: _pullOpenThreshold,
                            dragging: _dragging,
                            open: _pullPanelOpen,
                            searchCtrl: _searchCtrl,
                            onSearchChanged: _onSearchChanged,
                            onClearSearch: _clearSearch,
                            archivedCount: widget.repo.archivedRooms.length,
                            onOpenArchived: () => showArchivedChatsSheet(
                              context,
                              repo: widget.repo,
                              api: widget.api,
                            ),
                            onCollapse: () =>
                                setState(() => _pullPanelOpen = false),
                          ),
                      // The filter control rides inside the scroll view rather
                      // than sitting above it: as a fixed band it ate a strip of
                      // an already short viewport on every screen, and it reads
                      // as part of the list's own header, not as chrome. Only
                      // the header above stays pinned.
                      if (chipsStyle) ...[
                        // Not wrapped in `_gutter` on purpose: it takes the full
                        // width and applies the margin as scroll padding.
                        RoomFilterBar(
                          filter: filter,
                          counts: counts,
                          onChanged: _setFilter,
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Shown under BOTH styles. The chip row scrolls and holds
                      // nine chips against a ~320pt viewport, so the active one
                      // can easily be off-screen on a cold start — and the
                      // filter persists, so a cold start really can open onto a
                      // short list with no visible reason for it.
                      if (filter.isNotEmpty)
                        Padding(
                          padding: _gutter,
                          child: ActiveFilterCue(
                            filter: filter,
                            matchCount: visibleRooms.length,
                            onClear: _clearFilter,
                          ),
                        ),
                      if (!chipsStyle)
                        Padding(
                          padding: _gutter,
                          child: RoomFilterPanel(
                            filter: filter,
                            counts: counts,
                            expanded: _filterExpanded,
                            onChanged: _setFilter,
                            onDone: () =>
                                setState(() => _filterExpanded = false),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: _gutter,
                        child: _RoomsPanel(
                          repo: widget.repo,
                          api: widget.api,
                          filter: filter,
                          allRooms: allRooms,
                          rooms: visibleRooms,
                          searchQuery: _searchQuery,
                          onClearFilter: _clearFilter,
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.me,
    required this.api,
    required this.greeting,
    required this.onProfileTap,
    this.onCreateTap,
    this.filterButton,
  });
  final ChatUser me;
  final ChatApi api;
  final String greeting;
  final VoidCallback onProfileTap;
  final VoidCallback? onCreateTap;

  /// Null under [FilterStyle.chips], where the chip row is the whole control.
  final Widget? filterButton;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FocusableTap(
            onTap: onProfileTap,
            semanticLabel: AppLocalizations.of(context).homeScreenProfileSemanticLabel,
            shape: FocusRingShape.circle,
            radius: 999,
            child: GestureDetector(
              onTap: onProfileTap,
              child: UserAvatar(
                user: me,
                size: 36,
                api: api,
                showStatus: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).homeScreenGreeting(greeting),
              style: theme.displayMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (filterButton != null)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: filterButton,
            ),
          AnimatedSwitcher(
            duration: theme.motionFast,
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: onCreateTap != null
                ? Padding(
                    key: const ValueKey('plus_visible'),
                    padding: const EdgeInsets.only(left: 10),
                    child: FocusableTap(
                      onTap: onCreateTap,
                      semanticLabel: AppLocalizations.of(context).homeScreenNewRoomSemanticLabel,
                      shape: FocusRingShape.circle,
                      radius: 999,
                      child: GestureDetector(
                        onTap: onCreateTap,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.accent,
                            border: Border.all(
                              color: theme.ink.withValues(alpha: 0.18),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.accent.withValues(alpha: 0.32),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            CupertinoIcons.plus,
                            size: 16,
                            color: theme.accentInk,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('plus_hidden')),
          ),
        ],
      ),
    );
  }
}

class _RoomsPanel extends StatefulWidget {
  const _RoomsPanel({
    required this.repo,
    required this.api,
    required this.filter,
    required this.allRooms,
    required this.rooms,
    required this.searchQuery,
    required this.onClearFilter,
  });
  final ChatRepository repo;
  final ChatApi api;
  final RoomFilter filter;

  /// Every room, unfiltered — only used to tell "you have no rooms" apart from
  /// "your filter hid them all", and to size the escape hatch.
  final List<ChatRoom> allRooms;

  /// What actually renders. Already filtered (facets + search) by the caller.
  final List<ChatRoom> rooms;

  /// Raw text from the pull-reveal search field. Empty when not searching.
  final String searchQuery;
  final VoidCallback onClearFilter;

  @override
  State<_RoomsPanel> createState() => _RoomsPanelState();
}

class _RoomsPanelState extends State<_RoomsPanel> {
  /// One stable [GlobalKey] per room, so the long-press menu can anchor to
  /// the exact row that was pressed regardless of where it sits in the list.
  final Map<String, GlobalKey> _rowKeys = {};
  GlobalKey _keyFor(String id) => _rowKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _showRowMenu(ChatRoom room, WidgetBuilder rowBuilder) async {
    final action = await showChatRowActionMenu(
      context: context,
      anchorKey: _keyFor(room.id),
      rowBuilder: rowBuilder,
      isPinned: room.isPinned,
      isArchived: room.isArchived,
    );
    switch (action) {
      case ChatRowAction.pin:
        await widget.repo.pinRoom(room.id);
        break;
      case ChatRowAction.unpin:
        await widget.repo.unpinRoom(room.id);
        break;
      case ChatRowAction.archive:
        await widget.repo.archiveRoom(room.id);
        break;
      case ChatRowAction.unarchive:
        await widget.repo.unarchiveRoom(room.id);
        break;
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final allRooms = widget.allRooms;
    final rooms = widget.rooms;
    final filter = widget.filter;
    final searching = widget.searchQuery.trim().isNotEmpty;

    // Genuinely empty account — distinct from "filtered down to nothing".
    if (allRooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            AppLocalizations.of(context).homeScreenEmptyRoomsMessage,
            style: theme.bodySoft,
          ),
        ),
      );
    }

    if (rooms.isEmpty) {
      if (searching) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              AppLocalizations.of(
                context,
              ).homeScreenNoSearchResults(widget.searchQuery.trim()),
              style: theme.bodySoft,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return FilteredEmptyState(
        filter: filter,
        total: allRooms.length,
        onClear: widget.onClearFilter,
      );
    }

    final layout = SettingsStore.instance.roomLayout;

    if (layout == RoomLayout.grid) {
      // Medium/expanded windows get a third column; phones stay at two.
      final cols = context.isCompact ? 2 : 3;
      final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
      );

      // Flat while searching, same reasoning as the list layout below.
      if (searching) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: gridDelegate,
          itemCount: rooms.length,
          itemBuilder: (context, i) => _gridTile(context, theme, rooms[i], i),
        );
      }

      final parts = partitionPinned(rooms);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (parts.pinned.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: gridDelegate,
              itemCount: parts.pinned.length,
              itemBuilder: (context, i) =>
                  _gridTile(context, theme, parts.pinned[i], i),
            ),
            // Now the only break between the groups, since the "PINNED" label
            // above this grid is gone — every pinned tile carries its own pin
            // badge, so the heading was naming what each tile already showed.
            // Doubling the row gap is what a reader has left to see the seam
            // by, so it has to stay: without it the two grids fuse into one.
            SizedBox(height: gridDelegate.mainAxisSpacing),
          ],
          if (parts.regular.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: gridDelegate,
              itemCount: parts.regular.length,
              itemBuilder: (context, i) => _gridTile(
                context,
                theme,
                parts.regular[i],
                parts.pinned.length + i,
              ),
            ),
        ],
      );
    }

    if (searching) {
      // Flat: a text search is about finding one specific chat, not
      // browsing — section headers are noise there, and nothing gets
      // promoted just because it happens to be pinned.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rooms.length; i++)
            _row(context, theme, rooms[i], i),
        ],
      );
    }

    final parts = partitionPinned(rooms);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parts.pinned.isNotEmpty) ...[
          for (var i = 0; i < parts.pinned.length; i++)
            _row(context, theme, parts.pinned[i], i),
          // The break the "PINNED" heading used to be. A RoomCard already
          // carries a 10px bottom margin, so this second 10 doubles the gap at
          // the seam and leaves every other gap alone — the same 10-then-20
          // rhythm the grid above uses. Dropping it entirely would run the
          // pinned rows straight into the rest with nothing but each row's own
          // badge to tell them apart.
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < parts.regular.length; i++)
          _row(context, theme, parts.regular[i], parts.pinned.length + i),
      ],
    );
  }

  Widget _row(BuildContext context, AppTheme theme, ChatRoom room, int index) {
    final repo = widget.repo;
    final api = widget.api;
    // Saved Messages gets the same long-press menu as any other row. It is
    // permanent (rooms.ts ensureSavedMessagesRoom won't let it be deleted or
    // left), but pinning and archiving are per-viewer membership flags, and
    // there is no reason a notes-to-self chat can't be unpinned or filed away
    // like the rest of the list.
    final Widget content = ChatRowLongPress(
      key: _keyFor(room.id),
      onLongPress: () => _showRowMenu(
        room,
        (context) => RoomCard(
          room: room,
          api: api,
          dmUser: repo.otherUserFor(room),
          typists: repo.typingIn(room.id),
          onTap: () {},
        ),
      ),
      child: RoomCard(
        room: room,
        api: api,
        dmUser: repo.otherUserFor(room),
        typists: repo.typingIn(room.id),
        onTap: () => openRoom(context, roomId: room.id, repo: repo, api: api),
      ),
    );
    return TweenAnimationBuilder<double>(
      // See the grid layout above: keyed by room id so a recency reorder
      // or a filter change moves the element rather than repurposing it,
      // which is what made avatars reload and momentarily swap between
      // rows.
      key: ValueKey(room.id),
      tween: Tween(begin: 0, end: 1),
      duration: theme.motionMed + Duration(milliseconds: index * 60),
      curve: theme.motionEntrance,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 16),
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: content,
    );
  }

  Widget _gridTile(
    BuildContext context,
    AppTheme theme,
    ChatRoom room,
    int index,
  ) {
    final repo = widget.repo;
    final api = widget.api;
    // Same menu for every tile, Saved Messages included — see [_row].
    final Widget content = ChatRowLongPress(
      key: _keyFor(room.id),
      onLongPress: () => _showRowMenu(
        room,
        (context) => RoomGridTile(
          room: room,
          api: api,
          dmUser: repo.otherUserFor(room),
          typists: repo.typingIn(room.id),
          onTap: () {},
        ),
      ),
      child: RoomGridTile(
        room: room,
        api: api,
        dmUser: repo.otherUserFor(room),
        typists: repo.typingIn(room.id),
        onTap: () => openRoom(context, roomId: room.id, repo: repo, api: api),
      ),
    );
    return TweenAnimationBuilder<double>(
      // Identity key, not position. Rooms are ordered by recency, so any
      // incoming message reorders this list — and toggling a filter
      // reorders it far more violently. Without a key Flutter re-matches
      // elements by index, handing the tile at position i a DIFFERENT
      // room; its avatar then reloads (and briefly shows the wrong face).
      key: ValueKey(room.id),
      tween: Tween(begin: 0, end: 1),
      duration: theme.motionMed + Duration(milliseconds: index * 40),
      curve: theme.motionEntrance,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 12),
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: content,
    );
  }
}

/// Uppercase-ish section label above the pinned group, matching the
/// dimension-label typography already used by [RoomFilterPanel].
