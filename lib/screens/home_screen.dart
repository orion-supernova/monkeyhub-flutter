import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// For RenderAbstractViewport: the pull-reveal panel's drop is decided against
// the viewport it's scrolling inside, not against the scroll offset.
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../drop/drop_classifier.dart';
import '../drop/drop_controller.dart';
import '../drop/drop_intake.dart';
import '../drop/drop_item.dart';
import '../drop/drop_zone.dart';
import '../widgets/pending_placeholder.dart';
import '../widgets/skeleton_rows.dart';
import '../data/room_filter.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import 'navigation/scroll_memory.dart';
import '../family/family_service.dart';
import '../keyboard/app_shortcuts.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/density.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/ios_kit.dart' show CollapsedTitleFade;
import '../widgets/sunlit_surface.dart' show SunlitBackdrop;
import '../widgets/archived_chats_sheet.dart';
import '../widgets/chat_list_row.dart';
import '../widgets/chat_row_action_menu.dart';
import '../widgets/chat_row_swipe.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_buttons.dart';
import '../widgets/liquid_glass.dart' show GlassTone;
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
  static const _scrollMemoryKey = 'chat';

  // ───────── in-place search ─────────

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // ───────── pull-down-at-top reveal (search field + Archived Chats) ─────────

  /// Live drag distance while pulling at the top of the list, 0 when idle.
  double _pullDrag = 0;

  /// True only between the first live drag sample and release — see
  /// [PullRevealSlot.instant] for what this changes about the reveal's
  /// timing.
  bool _dragging = false;
  bool _pullPanelOpen = false;

  /// True from the frame the panel is dropped for having been scrolled away
  /// until the next pull starts. The drop is the one height change that is
  /// neither a gesture nor a button press, and the only one that has to
  /// happen off-screen in a single frame; keeping it out of [_dragging]
  /// keeps that field meaning exactly what it says.
  bool _pullDropped = false;

  /// Sits on the panel itself so [_dropScrolledAwayPanel] can measure it.
  /// Nothing here can know that height any other way: the panel is as tall as
  /// whatever is in it — a search field, an Archived Chats row only when
  /// something is archived, both at the reader's own text scale.
  final _pullPanelKey = GlobalKey();

  static const _pullOpenThreshold = 64.0;
  static const _pullMaxDrag = 96.0;

  @override
  HomeSection get reselectSection => HomeSection.chat;
  @override
  ScrollController get reselectScroll => _scroll;

  @override
  void initState() {
    super.initState();
    ScrollMemory.attach(_scrollMemoryKey, _scroll);
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
  /// and — once it's open — watches for the scroll that has carried it away.
  ///
  /// Only the opening is a gesture this has to interpret, and it tracks the
  /// finger 1:1 (`_dragging` gates the reveal to `Duration.zero`, see
  /// [PullRevealSlot]) rather than popping open on a clock of its own. The
  /// close isn't interpreted at all: the panel is a real item at the top of
  /// the list, so an ordinary upward scroll carries it off the top edge the
  /// same way, and at the same speed, as it carries the first chat row.
  ///
  /// Not interpreting it is the point. The close used to drive the panel's
  /// height from the scroll offset, collapsing it to nothing over
  /// [_pullOpenThreshold] pixels of scrolling — and that landed in the same
  /// frames as the scrolling itself, so the list moved up by the finger's
  /// distance AND by whatever height the panel had just given back. Content
  /// left the screen two to three times faster than the finger dragging it,
  /// in a gesture that had tracked that same finger exactly on the way open.
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
    if (_pullPanelOpen) {
      // Mid-drag as well as on the settle. Mid-drag is where the panel
      // normally clears the top edge, and dropping it there is safe because a
      // drag moves `pixels` by deltas from wherever it currently is. A fling
      // can't be corrected underneath (see [_dropScrolledAwayPanel]), so the
      // settle is the backstop for one.
      if (n is ScrollEndNotification ||
          (n is ScrollUpdateNotification && n.dragDetails != null)) {
        _dropScrolledAwayPanel();
      }
      return false;
    }
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0 &&
        n.metrics.pixels <= n.metrics.minScrollExtent) {
      setState(() {
        _dragging = true;
        _pullDropped = false;
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

  /// The header's search button: brings the pull-down panel in and focuses its
  /// field, the same surface a pull at the top reveals.
  void _openSearch() {
    HapticFeedback.selectionClick();
    setState(() {
      _pullPanelOpen = true;
      _pullDropped = false;
    });
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _collapsePullPanel() {
    _searchFocus.unfocus();
    setState(() => _pullPanelOpen = false);
  }

  /// Takes the open panel back out of the list once scrolling has carried it
  /// entirely off the top — the one moment removing it costs nothing to look
  /// at, because its height is already content nobody can see.
  ///
  /// Removing it does move everything below it up by that height, which is
  /// why the offset hands the same amount back in the same frame. That's a
  /// [ScrollPosition.correctBy] — the silent, layout-level offset fix — and
  /// not a `jumpTo`: a jump would dispatch a fresh round of scroll
  /// notifications from inside the one being handled, and swap the position's
  /// activity out from under the dispatch that is still running.
  ///
  /// Not correctable under a fling, which is why this is never called from
  /// one: a ballistic simulation holds absolute offsets and writes the next
  /// one straight over the correction, jumping the list by exactly the height
  /// being corrected for.
  ///
  /// Nothing is lost by waiting, because this is a standing offer rather than
  /// a single chance — every drag sample and every settle asks again for as
  /// long as the panel is open. A fling that lands within the sliver's cache
  /// extent drops the panel the moment it stops; one that outruns the cache
  /// takes the panel's element with it, and the drop waits for the sliver to
  /// build it again on the way back, which it does a cache extent before the
  /// panel would be visible. Either way it lands off-screen.
  ///
  /// A query in the field keeps the panel. The query outlives the panel
  /// either way, so dropping the field would leave the list silently filtered
  /// with nothing on screen to explain it — and scrolling through your own
  /// results is the most ordinary thing to do right after typing one.
  void _dropScrolledAwayPanel() {
    if (!_scroll.hasClients || _searchCtrl.text.isNotEmpty) return;
    final box = _pullPanelKey.currentContext?.findRenderObject();
    final viewport = box == null ? null : RenderAbstractViewport.maybeOf(box);
    if (box is! RenderBox || !box.hasSize || viewport is! RenderBox) return;
    final height = box.size.height;
    // Against the viewport's own top edge rather than against the scroll
    // offset: the list's top padding sits above the panel, so "how far the
    // list has scrolled" and "how far the panel's bottom edge still is from
    // the top of the viewport" are two different numbers.
    if (height <= 0 ||
        box.localToGlobal(Offset(0, height), ancestor: viewport).dy > 0) {
      return;
    }
    _searchFocus.unfocus();
    _scroll.position.correctBy(-height);
    // A correction notifies nobody by design, ScrollMemory's listener
    // included, so hand it the offset it would otherwise go on remembering.
    ScrollMemory.record(_scrollMemoryKey, _scroll.position.pixels);
    setState(() {
      _pullPanelOpen = false;
      _pullDropped = true;
    });
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JoinByInviteScreen(repo: widget.repo, api: widget.api),
      ),
    );
  }

  /// The rooms as the list last drew them: filtered, searched, in display
  /// order. What ⌥⌘↓ and friends walk, so "next" means the row below.
  List<ChatRoom> _shownRooms = const [];

  /// ⌘F. The search lives in the pull-down panel above the list, which a
  /// mouse has no way to pull, so the shortcut is also how a desktop opens it.
  void _focusSearch() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.minScrollExtent);
    setState(() {
      _pullPanelOpen = true;
      _pullDropped = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
    });
  }

  /// Opens the chat [by] rows from the open one. Stops at the ends rather
  /// than wrapping: landing back at the top from the bottom reads as a jump.
  /// [unread] skips to the next chat with something unread instead, and does
  /// wrap, since "the next one I haven't read" has no natural end.
  void _stepChat(int by, {bool unread = false}) {
    final rooms = _shownRooms;
    if (rooms.isEmpty) return;
    final at = rooms.indexWhere(
      (r) => r.id == UiSelectionStore.instance.roomId,
    );
    String? target;
    if (unread) {
      for (var n = 1; n <= rooms.length; n++) {
        final r = rooms[(at + n) % rooms.length];
        if (r.hasUnread && r.id != UiSelectionStore.instance.roomId) {
          target = r.id;
          break;
        }
      }
    } else {
      final to = at < 0 ? (by > 0 ? 0 : rooms.length - 1) : at + by;
      if (to >= 0 && to < rooms.length) target = rooms[to].id;
    }
    if (target == null) return;
    openRoom(context, roomId: target, repo: widget.repo, api: widget.api);
  }

  @override
  Widget build(BuildContext context) {
    // Only the bindings follow the open chat: the list itself never rebuilds
    // for a selection change it doesn't draw.
    return ListenableBuilder(
      listenable: UiSelectionStore.instance,
      builder: (context, list) {
        final open = UiSelectionStore.instance.roomId != null;
        return ShortcutBindings(
          bindings: {
            AppShortcuts.search: _focusSearch,
            AppShortcuts.newChat: _openNewChat,
            AppShortcuts.nextChat: () => _stepChat(1),
            AppShortcuts.previousChat: () => _stepChat(-1),
            AppShortcuts.nextUnread: () => _stepChat(1, unread: true),
            if (open && context.isExpanded)
              AppShortcuts.closeChat: () =>
                  UiSelectionStore.instance.selectRoom(null),
          },
          child: list!,
        );
      },
      child: _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
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
    _shownRooms = visibleRooms;
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
          const SunlitBackdrop(),
          // No SafeArea: the list runs edge to edge, under the status bar and
          // the floating header at the top and under the home indicator at the
          // bottom (a SafeArea there leaves a strip of bare background that
          // nothing can scroll into, read on device as a solid bar). It clears
          // both with its own padding: the header's height on top, and
          // `sectionBottomPadding` below, which reserves for the floating pill
          // AND the indicator (`kFloatingNavClearance` is measured against it).
          Stack(
            children: [
              Positioned.fill(
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
                      // Starts below the floating header; content scrolls
                      // under it and its soft top edge (iOS 26 scroll edge).
                      padding: EdgeInsets.fromLTRB(
                        0,
                        MediaQuery.paddingOf(context).top + _kHeaderBar,
                        0,
                        sectionBottomPadding(context),
                      ),
                      children: [
                        // The large title, native iOS: it leads the list and
                        // scrolls up under the bar, where the small centred
                        // title takes over.
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                          child: Semantics(
                            header: true,
                            child: Text(
                              AppLocalizations.of(context).homeScreenTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.displayLarge
                                  .copyWith(letterSpacing: 0.37),
                            ),
                          ),
                        ),
                        PullRevealSlot(
                          panelKey: _pullPanelKey,
                          dragExtent: _pullDrag,
                          dragThreshold: _pullOpenThreshold,
                          instant: _dragging || _pullDropped,
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
                        // A pointer and a pane: every filter on screen at once,
                        // as segmented groups, instead of a row to scroll.
                        if (chipsStyle &&
                            (Density.platformOffersCompact ||
                                context.usesSplitShell)) ...[
                          Padding(
                            padding: _gutter,
                            child: RoomFilterSegments(
                              filter: filter,
                              counts: counts,
                              onChanged: _setFilter,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ] else if (chipsStyle) ...[
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
                          // Rows carry 4pt of their own inset for the press
                          // highlight, so 16 here puts the avatars on the same
                          // 20pt edge as the large title.
                          padding: settings.roomLayout == RoomLayout.list
                              ? const EdgeInsets.symmetric(horizontal: 16)
                              : _gutter,
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _Header(
                  scroll: _scroll,
                  me: me,
                  api: widget.api,
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
                  onSearchTap: _openSearch,
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Height of the header bar below the status bar.
const double _kHeaderBar = 52;

/// The floating header, Signal iOS 26 style: your avatar left, the title
/// centred and always visible, one glass capsule (search, compose) right.
///
/// It sits OVER the list. Behind it is a soft top edge: the page background
/// fading from opaque at the status bar to clear below the bar, so rows
/// dissolve as they scroll under it (the iOS 26 scroll edge effect) without a
/// blur layer over a moving list.
///
/// Its centred title is the collapsed form of the list's large title: it
/// fades in as the large one scrolls up under the bar, as on native iOS.
class _Header extends StatelessWidget {
  const _Header({
    required this.scroll,
    required this.me,
    required this.api,
    required this.onProfileTap,
    this.onCreateTap,
    this.onSearchTap,
    this.filterButton,
  });
  final ScrollController scroll;
  final ChatUser me;
  final ChatApi api;
  final VoidCallback onProfileTap;
  final VoidCallback? onCreateTap;

  /// Opens the pull-down search field. Stands in for Signal's camera button:
  /// the camera here is a chat attachment tool (it needs a room to send into),
  /// and nothing in the chat list can receive a photo.
  final VoidCallback? onSearchTap;

  /// Null under [FilterStyle.chips], where the chip row is the whole control.
  final Widget? filterButton;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final bg = theme.background;
    final actions = [
      if (onSearchTap != null)
        GlassGroupItem(
          icon: CupertinoIcons.search,
          semanticLabel: l10n.pullRevealSearchHint,
          onTap: onSearchTap,
        ),
      // Unconditional: the sheet draws only the actions the account actually
      // has, and a locked-down child account still starts chats with people
      // its guardian approved.
      if (onCreateTap != null)
        GlassGroupItem(
          icon: CupertinoIcons.square_pencil,
          semanticLabel: l10n.homeScreenNewRoomSemanticLabel,
          onTap: onCreateTap,
        ),
    ];
    return Stack(
      children: [
        // The soft edge. Taller than the bar so the fade finishes below it.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bg,
                    bg.withValues(alpha: 0.92),
                    bg.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.62, 1],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: top, bottom: 14),
          child: SizedBox(
            height: _kHeaderBar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Centred on the screen, not on the gap between the controls,
                  // so it stays put whichever buttons the account has.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 112),
                    child: CollapsedTitleFade(
                      scroll: scroll,
                      child: Text(
                        l10n.homeScreenTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyEmph.copyWith(
                          color: theme.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      FocusableTap(
                        onTap: onProfileTap,
                        semanticLabel: l10n.homeScreenProfileSemanticLabel,
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
                      const Spacer(),
                      if (filterButton != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: filterButton,
                        ),
                      if (actions.isNotEmpty)
                        GlassButtonGroup(tone: GlassTone.app, items: actions),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    final recentMessages = all.length <= previewMaxMessages
        ? all
        : all.sublist(all.length - previewMaxMessages);
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
          child: SkeletonRows(count: 7, avatarSize: 52, circular: true),
        ),
        // THE empty state — glyph, centred title — not a lone left-wrapping
        // line of text.
        empty: (context) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: EmptyState(
            icon: CupertinoIcons.chat_bubble_2,
            title: AppLocalizations.of(context).homeScreenEmptyRoomsMessage,
            compact: true,
          ),
        ),
      );
    }

    if (rooms.isEmpty) {
      if (searching) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: EmptyState(
            icon: CupertinoIcons.search,
            title: AppLocalizations.of(
              context,
            ).homeScreenNoSearchResults(widget.searchQuery.trim()),
            compact: true,
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
      // Columns from the width the list actually has, not the window's: the
      // chat list is a ~360pt pane in the desktop shell, and three columns
      // there were 100pt tiles. Height from the tile's content, not an
      // aspect ratio — see [RoomGridMetrics.extent].
      final m = RoomGridMetrics.of(Density.of(context));
      final extent = RoomGridMetrics.extentFor(context);
      // ONE grid, pinned first, flat while searching (same reasoning as the
      // list below). Not two grids with a spacer: every pinned tile carries
      // its own pin, and a seam in a grid reads as a layout bug.
      final parts = searching ? null : partitionPinned(rooms);
      final ordered = parts == null
          ? rooms
          : [...parts.pinned, ...parts.regular];
      return LayoutBuilder(
        builder: (context, box) {
          final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: m.columnsFor(box.maxWidth),
            mainAxisSpacing: m.spacing,
            crossAxisSpacing: m.spacing,
            mainAxisExtent: extent,
          );
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Explicit, not the default: with no SafeArea above it a null
            // padding inherits the status-bar and home-indicator insets,
            // which opened a ~62pt gap above the first row of tiles.
            padding: EdgeInsets.zero,
            gridDelegate: gridDelegate,
            itemCount: ordered.length,
            itemBuilder: (context, i) =>
                _gridTile(context, theme, ordered[i], i),
          );
        },
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
            _row(
              context,
              theme,
              rooms[i],
              i,
              showDivider: i < rooms.length - 1,
            ),
        ],
      );
    }

    final parts = partitionPinned(rooms);
    if (layout == RoomLayout.list) {
      // One continuous list, pinned first. The cards below need a seam to
      // tell the groups apart; a row carries its own pin glyph in the slot
      // the unread count would use, and a gap in a hairline-ruled list reads
      // as a rendering fault rather than a section break.
      final ordered = [...parts.pinned, ...parts.regular];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < ordered.length; i++)
            _row(
              context,
              theme,
              ordered[i],
              i,
              showDivider: i < ordered.length - 1,
            ),
        ],
      );
    }
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

  /// Sends whatever was dropped on [room]'s row into that room.
  ///
  /// Two steps and a wait. The room is SELECTED (or pushed, on a narrow
  /// window) and the bundle is parked under its id; the `RoomScreen` that
  /// mounts — or the one already mounted, which on desktop is what selecting
  /// the selected room amounts to — collects it through the same
  /// `takeStagedFor` hand-off a share from the system sheet uses.
  ///
  /// The returned future is [DropIntake]'s, not this method's, and that is
  /// load-bearing: `DropController` releases the platform's staged copies when
  /// `onDrop` completes, and this method's own work is over the instant the
  /// room is selected — seconds before the bytes have been read. Returning
  /// early would delete the file out from under the transcript that is about
  /// to send it.
  Future<void> _dropOnRoom(ChatRoom room, DropBundle bundle) {
    final handoff = DropIntake.instance.stageFor(room.id, bundle);
    if (!mounted) return handoff;
    openRoom(context, roomId: room.id, repo: widget.repo, api: widget.api);
    return handoff;
  }

  /// Wraps a row or tile so a file can be dropped straight onto the chat it
  /// belongs in, without opening it first.
  ///
  /// Priority 20 against the transcript's 0: in the two-pane shell the list
  /// sits beside an open conversation, and a drop aimed at a row has to beat
  /// the room behind it. Returns [child] untouched on every platform without a
  /// desktop drag.
  Widget _droppable(ChatRoom room, Widget child) {
    if (!DropController.isSupported) return child;
    final caps = widget.repo.capabilitiesFor(room);
    return DropZone(
      priority: 20,
      enabled: caps.canReceiveForwards,
      policy: DropPolicy(
        allowFiles: FamilyService.maybeInstance?.canSendMedia ?? true,
      ),
      label: _dropLabel(room),
      onDrop: (bundle) => _dropOnRoom(room, bundle),
      borderRadius: BorderRadius.circular(ThemeScope.of(context).radiusLg),
      // A row is small enough that a lift reads as the card being picked up
      // rather than as the layout shifting — which is the opposite of the
      // call the transcript makes at 400pt tall.
      lift: 2,
      child: child,
    );
  }

  /// The name the verdict chip gives this row. Exactly what the row itself
  /// shows, so "to Alice" names the face the pointer is over.
  String _dropLabel(ChatRoom room) {
    final l10n = AppLocalizations.of(context);
    if (room.isSavedMessages) return l10n.savedMessagesTitle;
    return widget.repo.otherUserFor(room)?.displayName ?? room.name;
  }

  Widget _row(
    BuildContext context,
    AppTheme theme,
    ChatRoom room,
    int index, {
    bool showDivider = true,
  }) {
    final repo = widget.repo;
    final api = widget.api;
    // Saved Messages gets the same long-press menu as any other row. It is
    // permanent (rooms.ts ensureSavedMessagesRoom won't let it be deleted or
    // left), but pinning and archiving are per-viewer membership flags, and
    // there is no reason a notes-to-self chat can't be unpinned or filed away
    // like the rest of the list.
    final Widget content = _droppable(
      room,
      ChatRowLongPress(
        key: _keyFor(room.id),
        onLongPress: () => _showRowMenu(room),
        child: SettingsStore.instance.roomLayout == RoomLayout.cards
            ? RoomCard(
                room: room,
                api: api,
                dmUser: repo.otherUserFor(room),
                typists: repo.typingIn(room.id),
                onTap: () =>
                    openRoom(context, roomId: room.id, repo: repo, api: api),
              )
            : ChatRowSwipe(
                leading: _leadingSwipes(room),
                trailing: _trailingSwipes(room),
                child: ChatListRow(
                  room: room,
                  api: api,
                  dmUser: repo.otherUserFor(room),
                  typists: repo.typingIn(room.id),
                  showDivider: showDivider,
                  onTap: () =>
                      openRoom(context, roomId: room.id, repo: repo, api: api),
                ),
              ),
      ),
    );
    return TweenAnimationBuilder<double>(
      // See the grid layout above: keyed by room id so a recency reorder
      // or a filter change moves the element rather than repurposing it,
      // which is what made avatars reload and momentarily swap between
      // rows.
      key: ValueKey(room.id),
      tween: Tween(begin: 0, end: 1),
      // Staggered for what a screen shows; past that every row lands
      // together, so a long list never takes seconds to settle.
      duration:
          theme.motionMed + Duration(milliseconds: index.clamp(0, 9) * 45),
      curve: theme.motionEntrance,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 16),
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: content,
    );
  }

  /// Swipe right: pin or unpin — the Telegram/Mail leading action.
  List<SwipeAction> _leadingSwipes(ChatRoom room) {
    final l10n = AppLocalizations.of(context);
    final repo = widget.repo;
    return [
      SwipeAction(
        label: room.isPinned ? l10n.chatSwipeUnpin : l10n.chatSwipePin,
        icon: room.isPinned
            ? CupertinoIcons.pin_slash_fill
            : CupertinoIcons.pin_fill,
        color: const Color(0xFFFF9500),
        onTap: () =>
            room.isPinned ? repo.unpinRoom(room.id) : repo.pinRoom(room.id),
      ),
    ];
  }

  /// Swipe left: mute (when the room allows it) and archive, archive on the
  /// outside so a full swipe files the chat away, as Mail does.
  List<SwipeAction> _trailingSwipes(ChatRoom room) {
    final l10n = AppLocalizations.of(context);
    final repo = widget.repo;
    return [
      if (repo.capabilitiesFor(room).canMute)
        SwipeAction(
          label: room.isMuted ? l10n.chatSwipeUnmute : l10n.chatSwipeMute,
          icon: room.isMuted
              ? CupertinoIcons.bell_fill
              : CupertinoIcons.bell_slash_fill,
          color: const Color(0xFF5856D6),
          onTap: () => room.isMuted
              ? repo.unmuteRoom(room.id)
              : showMuteRoomSheet(context, repo: repo, room: room),
        ),
      SwipeAction(
        label: l10n.chatSwipeArchive,
        icon: CupertinoIcons.archivebox_fill,
        color: const Color(0xFF8E8E93),
        onTap: () => repo.archiveRoom(room.id),
      ),
    ];
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
    final Widget content = _droppable(
      room,
      ChatRowLongPress(
        key: _keyFor(room.id),
        onLongPress: () => _showRowMenu(room),
        child: RoomGridTile(
          room: room,
          api: api,
          dmUser: repo.otherUserFor(room),
          typists: repo.typingIn(room.id),
          onTap: () => openRoom(context, roomId: room.id, repo: repo, api: api),
        ),
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
      duration:
          theme.motionMed + Duration(milliseconds: index.clamp(0, 9) * 40),
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
