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
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/room_card.dart';
import '../widgets/room_filter_bar.dart';
import '../widgets/room_filter_drawer.dart';
import '../widgets/room_grid_tile.dart';
import '../widgets/user_avatar.dart';
import 'navigation/destinations.dart';
import 'navigation/open_room.dart';
import 'create_room_sheet.dart';
import 'profile_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  ChatUser? _me;

  /// Whether the drawer-style filter panel is open. Purely presentational, so
  /// unlike the filter itself it isn't persisted.
  bool _filterExpanded = false;

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
    _loadMe();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onChange);
    widget.family.removeListener(_onChange);
    SettingsStore.instance.removeListener(_onChange);
    super.dispose();
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
    // Resolved once per build and threaded down. `repo.rooms` allocates an
    // unmodifiable view on every call and the repository notifies on every
    // typing keystroke in any room, so the cue and the list must not each go
    // and filter it themselves.
    final allRooms = widget.repo.rooms;
    final visibleRooms = filter.apply(allRooms);
    // Projected, not the repository's raw totals: every number on a filter
    // control is what tapping it would actually show.
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
                  child: ListView(
                    key: const PageStorageKey('home_main_list'),
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      14,
                      20,
                      kFloatingNavClearance,
                    ),
                    children: [
                      // The filter control rides inside the scroll view rather
                      // than sitting above it: as a fixed band it ate a strip of
                      // an already short viewport on every screen, and it reads
                      // as part of the list's own header, not as chrome. Only
                      // the header above stays pinned.
                      if (chipsStyle) ...[
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
                        ActiveFilterCue(
                          filter: filter,
                          matchCount: visibleRooms.length,
                          onClear: _clearFilter,
                        ),
                      if (!chipsStyle)
                        RoomFilterPanel(
                          filter: filter,
                          counts: counts,
                          expanded: _filterExpanded,
                          onChanged: _setFilter,
                          onDone: () => setState(() => _filterExpanded = false),
                        ),
                      const SizedBox(height: 14),
                      _RoomsPanel(
                        repo: widget.repo,
                        api: widget.api,
                        filter: filter,
                        allRooms: allRooms,
                        rooms: visibleRooms,
                        onClearFilter: _clearFilter,
                      ),
                    ],
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

class _RoomsPanel extends StatelessWidget {
  const _RoomsPanel({
    required this.repo,
    required this.api,
    required this.filter,
    required this.allRooms,
    required this.rooms,
    required this.onClearFilter,
  });
  final ChatRepository repo;
  final ChatApi api;
  final RoomFilter filter;

  /// Every room, unfiltered — only used to tell "you have no rooms" apart from
  /// "your filter hid them all", and to size the escape hatch.
  final List<ChatRoom> allRooms;

  /// What actually renders. Already filtered by the caller.
  final List<ChatRoom> rooms;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

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
      return FilteredEmptyState(
        filter: filter,
        total: allRooms.length,
        onClear: onClearFilter,
      );
    }

    final layout = SettingsStore.instance.roomLayout;

    if (layout == RoomLayout.grid) {
      // Medium/expanded windows get a third column; phones stay at two.
      final cols = context.isCompact ? 2 : 3;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: rooms.length,
        itemBuilder: (context, i) {
          return TweenAnimationBuilder<double>(
            // Identity key, not position. Rooms are ordered by recency, so any
            // incoming message reorders this list — and toggling a filter
            // reorders it far more violently. Without a key Flutter re-matches
            // elements by index, handing the tile at position i a DIFFERENT
            // room; its avatar then reloads (and briefly shows the wrong face).
            // See the same fix on the list layout.
            key: ValueKey(rooms[i].id),
            tween: Tween(begin: 0, end: 1),
            duration: theme.motionMed + Duration(milliseconds: i * 40),
            curve: theme.motionEntrance,
            builder: (context, v, child) => Transform.translate(
              offset: Offset(0, (1 - v) * 12),
              child: Opacity(opacity: v.clamp(0, 1), child: child),
            ),
            child: RoomGridTile(
              room: rooms[i],
              api: api,
              dmUser: repo.otherUserFor(rooms[i]),
              typists: repo.typingIn(rooms[i].id),
              onTap: () =>
                  openRoom(context, roomId: rooms[i].id, repo: repo, api: api),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rooms.length; i++)
          TweenAnimationBuilder<double>(
            // See the grid layout above: keyed by room id so a recency reorder
            // or a filter change moves the element rather than repurposing it,
            // which is what made avatars reload and momentarily swap between
            // rows.
            key: ValueKey(rooms[i].id),
            tween: Tween(begin: 0, end: 1),
            duration: theme.motionMed + Duration(milliseconds: i * 60),
            curve: theme.motionEntrance,
            builder: (context, v, child) => Transform.translate(
              offset: Offset(0, (1 - v) * 16),
              child: Opacity(opacity: v.clamp(0, 1), child: child),
            ),
            child: RoomCard(
              room: rooms[i],
              api: api,
              dmUser: repo.otherUserFor(rooms[i]),
              typists: repo.typingIn(rooms[i].id),
              onTap: () =>
                  openRoom(context, roomId: rooms[i].id, repo: repo, api: api),
            ),
          ),
      ],
    );
  }
}
