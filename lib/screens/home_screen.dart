import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../widgets/pending_placeholder.dart';
import '../widgets/skeleton_rows.dart';
import '../data/room_filter.dart';
import '../data/settings_store.dart';
import 'navigation/scroll_memory.dart';
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
import '../widgets/mute_room_sheet.dart';
import '../widgets/pull_reveal_panel.dart';
import '../widgets/room_card.dart';
import '../widgets/room_filter_bar.dart';
import '../widgets/room_filter_drawer.dart';
import '../widgets/room_grid_tile.dart';
import '../widgets/user_avatar.dart';
import 'navigation/destinations.dart';
import 'navigation/open_room.dart';
import 'navigation/tab_reselect.dart';
import '../widgets/app_toast.dart';
import '../widgets/new_chat_menu.dart';
import 'create_room_sheet.dart';
import 'join_by_invite_screen.dart';
import 'profile_screen.dart';

/// The page margin every element on this screen lines up with.
///
/// Carried per child rather than by the scroll view, because the filter chip
/// row has to be laid out edge to edge and inset itself.
const _gutter = EdgeInsets.symmetric(horizontal: 20);

/// Clamps overscroll only at the top of the chat list, leaving the bottom
/// edge whatever the platform default (bounce on iOS, clamp on Android)
/// already does.
///
/// [PullRevealSlot] turns the top overscroll into its own drag-driven reveal
/// — see `_HomeScreenState._onScrollNotification`. Left on the platform
/// default, iOS's `BouncingScrollPhysics` ALSO visually shifts the whole list
/// down by the overscroll amount while that reveal is growing by the same
/// amount: the two stack, showing up as a gap above the search field that
/// grows twice as fast as the finger dragging it open. Pinning `pixels` at
/// the top boundary — the same thing Android's default clamping physics
/// already does, which is why this was never a problem there — leaves the
/// reveal itself as the only thing moving.
class _TopClampScrollPhysics extends ScrollPhysics {
  const _TopClampScrollPhysics({super.parent});

  @override
  _TopClampScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _TopClampScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

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

  // Not a plain ScrollController: this section's State is destroyed on
  // every tab switch, and the framework's own PageStorage restore is what
  // produced the settle-bounce on return. See [ScrollMemory].
  final _scroll = ScrollMemory.controller();

  // ───────── in-place search ─────────

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ───────── pull-down-at-top reveal (search field + Archived Chats) ─────────

  /// Live drag distance while pulling at the top of the list, 0 when idle.
  double _pullDrag = 0;

  /// True only between the first live drag sample and release — see
  /// [PullRevealSlot] for what this changes about the reveal's timing.
  bool _dragging = false;
  bool _pullPanelOpen = false;

  /// True from the first forward-scroll sample of a close-by-swipe gesture
  /// until release — see `_onScrollNotification`. Distinct from
  /// [_pullPanelOpen] because that flips to `false` the moment the gesture
  /// starts (so [PullRevealSlot]'s progress tracks the drag instead of
  /// staying pinned at 1.0), while this has to keep routing later samples of
  /// the *same* gesture back into the closing branch.
  bool _closingPanel = false;
  static const _pullOpenThreshold = 64.0;
  static const _pullMaxDrag = 96.0;

  @override
  HomeSection get reselectSection => HomeSection.chat;
  @override
  ScrollController get reselectScroll => _scroll;

  @override
  void initState() {
    super.initState();
    ScrollMemory.attach('chat', _scroll);
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
    _searchFocus.dispose();
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

  /// Tracks the overscroll-at-the-top gesture that reveals [PullRevealSlot],
  /// and — once it's open — the ordinary forward drag that closes it again.
  /// Both directions track the finger 1:1 (`_dragging` gates the reveal to
  /// `Duration.zero`, see [PullRevealSlot]) rather than the close firing a
  /// canned collapse animation on its own fixed clock, disconnected from how
  /// fast the list is actually being scrolled.
  ///
  /// The list runs on [_TopClampScrollPhysics], which pins `pixels` at the
  /// top boundary instead of letting it go negative, so a pull-past-the-top
  /// always arrives the same way regardless of platform: `pixels` stays at
  /// the boundary and the denied delta is reported separately via
  /// `OverscrollNotification.overscroll`. `dragDetails != null` is required
  /// throughout — non-null only while a real finger drag is in progress, null
  /// during the ballistic spring-back Flutter runs after release, which would
  /// otherwise be misread as a second pull while the position animates back
  /// to zero.
  bool _onScrollNotification(ScrollNotification n) {
    if (_pullPanelOpen || _closingPanel) {
      if (n is ScrollUpdateNotification && n.dragDetails != null) {
        setState(() {
          _pullPanelOpen = false;
          _closingPanel = true;
          _dragging = true;
          // Remaining "openness": full at the top (pixels 0, matching the
          // 1.0 progress the panel was already showing, so there's no jump
          // the instant this branch takes over) and gone by the same
          // distance the opening pull commits at.
          _pullDrag = (_pullOpenThreshold - n.metrics.pixels).clamp(
            0.0,
            _pullOpenThreshold,
          );
        });
      } else if (n is ScrollEndNotification && _closingPanel) {
        // Dragged past the halfway point: commit closed. Short of that:
        // spring back open, the same forgiveness an opening pull that
        // doesn't reach its own threshold gets.
        final reopen = _pullDrag > _pullOpenThreshold / 2;
        setState(() {
          _dragging = false;
          _closingPanel = false;
          _pullDrag = 0;
          _pullPanelOpen = reopen;
        });
        if (!reopen) _searchFocus.unfocus();
      }
      return false;
    }
    if (n is OverscrollNotification &&
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

  void _collapsePullPanel() {
    _searchFocus.unfocus();
    setState(() => _pullPanelOpen = false);
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
      if (!mounted) return;
      // `null` is not "nothing changed" — `users.getProfile` returns it only
      // when the row is gone, and asking for our OWN profile means this
      // account has been deleted. Conflating it with `!mounted` is what kept a
      // deleted account on screen indefinitely: the stale cached username was
      // rendered, the correction was discarded, and nothing ever retried.
      if (fresh == null) {
        widget.auth.onSelfProfileMissing();
        return;
      }
      setState(() => _me = fresh);
    } catch (_) {}
  }

  void _setFilter(RoomFilter next) =>
      SettingsStore.instance.setRoomFilter(next);

  void _clearFilter() {
    HapticFeedback.lightImpact();
    SettingsStore.instance.setRoomFilter(RoomFilter.empty);
  }

  /// The `+`. Every way a new chat starts, in the order people want them.
  ///
  /// Friends first, with a search bar over them, then create-a-room and
  /// join-with-a-code underneath — see [showNewChatMenu] for why messaging a
  /// person you already know belongs on the button new chats come from rather
  /// than a tab away in Discover.
  ///
  /// The old shortcut that skipped the sheet when only one ROOM action was
  /// available is gone with it: there is now always a third thing in the
  /// sheet (the people), so there is no longer a case where the menu has one
  /// entry in it.
  Future<void> _openNewChat() async {
    final canCreate = widget.family.canCreateRooms;
    // Matches the rest of the child model rather than inventing a new rule:
    // Discover — the app's other way into a room you are not in — is hidden
    // from children outright, so this door is too. Redeeming a code still
    // needs a guardian's yes server-side either way (`roomInvites.redeem`).
    final canJoin = !widget.family.isChild;

    final outcome = await showNewChatMenu(
      context,
      repo: widget.repo,
      api: widget.api,
      canCreateRoom: canCreate,
      canJoinByCode: canJoin,
    );
    if (!mounted || outcome == null) return;

    final friend = outcome.friend;
    if (friend != null) {
      await _openDmWith(friend);
      return;
    }
    switch (outcome.choice) {
      case NewChatChoice.createRoom:
        _showCreateRoom();
      case NewChatChoice.joinWithCode:
        _showJoinByCode();
      case null:
        break;
    }
  }

  /// Opens (or mints) the DM with [friend] and lands in it.
  ///
  /// `getOrCreateDM` is idempotent and always returns the same room for the
  /// same pair, so tapping a friend twice reopens the conversation rather than
  /// starting a second one.
  Future<void> _openDmWith(ChatUser friend) async {
    final toast = AppToast.of(context);
    try {
      final roomId = await widget.repo.openDmWith(friend);
      if (!mounted) return;
      openRoom(context, roomId: roomId, repo: widget.repo, api: widget.api);
    } catch (_) {
      if (!mounted) return;
      toast.show(
        AppLocalizations.of(context).newChatMenuOpenDmFailed,
        tone: ToastTone.danger,
      );
    }
  }

  void _showCreateRoom() {
    showAdaptiveSheet(
      context,
      // The tallest sheet in the app, and the only one that can reach the top
      // of the screen — see the parameter's own doc. Without it the name field
      // can end up under the status bar on a short phone with the keyboard up.
      useSafeArea: true,
      builder: (_) => CreateRoomSheet(repo: widget.repo, api: widget.api),
    );
  }

  void _showJoinByCode() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => JoinByInviteScreen(repo: widget.repo, api: widget.api),
    ));
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
            // `bottom: false` so the scroller reaches the screen edge.
            //
            // The default insets the WHOLE column by the home-indicator inset,
            // which ends the list ~34pt short of the bottom and leaves a strip
            // of bare background under it that nothing can scroll into — read
            // on device as a solid bar. Edge-to-edge is already on
            // (`SystemUiMode.edgeToEdge`, transparent nav bar), so content is
            // meant to run under the indicator and be cleared by padding
            // instead: `sectionBottomPadding` reserves for the floating pill
            // AND the indicator, which is what `kFloatingNavClearance` is
            // measured against.
            bottom: false,
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
                  // Unconditional now. It used to be hidden unless the account
                  // could create a room or join by code, which meant a
                  // locked-down child account had no `+` at all — and starting
                  // a chat with someone their guardian has already approved is
                  // the one thing that account exists to do. The sheet itself
                  // draws only the actions the account actually has.
                  onCreateTap: _openNewChat,
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
                        physics: const _TopClampScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          0,
                          14,
                          0,
                          sectionBottomPadding(context),
                        ),
                        children: [
                          PullRevealSlot(
                            dragExtent: _pullDrag,
                            dragThreshold: _pullOpenThreshold,
                            dragging: _dragging,
                            open: _pullPanelOpen,
                            searchCtrl: _searchCtrl,
                            searchFocus: _searchFocus,
                            onSearchChanged: _onSearchChanged,
                            onClearSearch: _clearSearch,
                            archivedCount: widget.repo.archivedRooms.length,
                            onOpenArchived: () => showArchivedChatsSheet(
                              context,
                              repo: widget.repo,
                              api: widget.api,
                            ),
                            onCollapse: _collapsePullPanel,
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

  /// Same preview builder for both layouts — see `_row` and `_gridTile`,
  /// which differ only in what they show at rest (`RoomCard` vs
  /// `RoomGridTile`); the long-press preview is one richer card regardless of
  /// which compact shape was pressed.
  Future<void> _showRowMenu(ChatRoom room) async {
    final repo = widget.repo;
    // The tail of this room's transcript already resident in the repo — see
    // [ChatRowPreviewCard]'s doc for why this never fetches. Empty for any
    // room the viewer hasn't opened this session, which is most of them; the
    // card falls back to `room.lastMessage` for those.
    final all = repo.messagesFor(room.id);
    final recentMessages =
        all.length <= previewMaxMessages ? all : all.sublist(all.length - previewMaxMessages);
    final action = await showChatRowActionMenu(
      context: context,
      anchorKey: _keyFor(room.id),
      previewBuilder: (context) => ChatRowPreviewCard(
        room: room,
        api: widget.api,
        dmUser: repo.otherUserFor(room),
        recentMessages: recentMessages,
        currentUserId: repo.userId ?? '',
        typists: repo.typingIn(room.id),
      ),
      isPinned: room.isPinned,
      isArchived: room.isArchived,
      isMuted: room.isMuted,
      canMute: widget.repo.capabilitiesFor(room).canMute,
    );
    if (!mounted) return;
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
      case ChatRowAction.mute:
        // Straight into the sheet rather than muting on the spot with a
        // default: the whole point of two switches and four durations is that
        // there is no single sensible default to apply silently.
        await showMuteRoomSheet(context, repo: widget.repo, room: room);
        break;
      case ChatRowAction.unmute:
        await widget.repo.unmuteRoom(room.id);
        break;
      case ChatRowAction.open:
        // Same call the row's own onTap makes — see `_row`/`_gridTile` below.
        openRoom(context, roomId: room.id, repo: repo, api: widget.api);
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

    // Genuinely empty account — distinct from "filtered down to nothing", and
    // distinct again from "the answer has not arrived yet", which is what
    // `roomsLoaded` is for. All three are the same empty list, and telling
    // someone with a hundred rooms that they have none for as long as their
    // network takes was the whole of the bug.
    if (allRooms.isEmpty) {
      return PendingPlaceholder(
        pending: !widget.repo.roomsLoaded,
        loading: (context) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          // Rounded-square, not circular: these stand in for rooms, and the
          // count is what a phone shows without scrolling, so nothing moves
          // when the real list replaces them.
          child: SkeletonRows(count: 7, avatarSize: 44, circular: false),
        ),
        empty: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              AppLocalizations.of(context).homeScreenEmptyRoomsMessage,
              style: theme.bodySoft,
            ),
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

      // ONE grid, pinned first — not two grids with a spacer between them.
      //
      // The two-grid version existed to put a visible seam between the groups,
      // standing in for the "PINNED" heading that was removed. But every
      // pinned tile already carries its own pin badge, which is what made the
      // heading redundant in the first place — and it makes the seam redundant
      // for exactly the same reason. What the seam actually produced was a
      // grid that looked like it had a layout bug in it.
      //
      // Building it as one grid does not just remove the gap, it makes the gap
      // unrepresentable: every row is separated by `mainAxisSpacing` because
      // there is only one thing doing the separating. Tuning the spacer to
      // "look equal" would have been a number to keep in sync with the
      // delegate forever.
      //
      // The LIST layout below still has its deliberate doubled seam. Left
      // alone on purpose: it is a different layout with a different rhythm
      // (each card carries its own margin), and nobody asked for it to change.
      final parts = partitionPinned(rooms);
      final ordered = [...parts.pinned, ...parts.regular];
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: gridDelegate,
        itemCount: ordered.length,
        itemBuilder: (context, i) => _gridTile(context, theme, ordered[i], i),
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
      onLongPress: () => _showRowMenu(room),
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
      onLongPress: () => _showRowMenu(room),
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
