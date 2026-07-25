import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/ui_selection_store.dart';
import '../data/settings_store.dart';
import '../family/family_service.dart';
import '../models/chat_user.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/pill_nav.dart';
import '../widgets/room_card.dart';
import '../widgets/room_grid_tile.dart';
import '../widgets/user_avatar.dart';
import 'navigation/open_room.dart';
import 'create_room_sheet.dart';
import 'friends_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';

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
  String _tab = 'rooms';
  int _direction = 1;
  ChatUser? _me;

  /// Discover disappears entirely for a child whose guardian hasn't unlocked
  /// public rooms — not greyed out, not empty, absent. A locked door still
  /// tells a child there's a room behind it.
  ///
  /// Discover is public *rooms* only. People live under Friends, which is
  /// always present — so "ask to add" never depends on public rooms.
  List<String> get _tabOrder => widget.family.canSeePublicRooms
      ? const ['rooms', 'discover', 'friends']
      : const ['rooms', 'friends'];

  void _setTab(String next) {
    if (next == _tab) return;
    final oldIdx = _tabOrder.indexOf(_tab);
    final newIdx = _tabOrder.indexOf(next);
    setState(() {
      _direction = newIdx >= oldIdx ? 1 : -1;
      _tab = next;
    });
  }

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onRepoChange);
    widget.family.addListener(_onFamilyChange);
    UiSelectionStore.instance.addListener(_onExternalTabRequest);
    // A tap that arrived before this screen mounted (cold start from a
    // notification) is still waiting in the store.
    _onExternalTabRequest();
    _loadMe();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChange);
    widget.family.removeListener(_onFamilyChange);
    UiSelectionStore.instance.removeListener(_onExternalTabRequest);
    super.dispose();
  }

  /// Honour a tab switch requested from outside the widget tree — a friend
  /// request notification tap. Ignored if the tab isn't available to this
  /// account (a child without Discover).
  void _onExternalTabRequest() {
    final requested = UiSelectionStore.instance.requestedHomeTab;
    if (requested == null || !_tabOrder.contains(requested)) return;
    UiSelectionStore.instance.consumeRequestedHomeTab();
    if (!mounted) return;
    _setTab(requested);
  }

  /// A guardian can unlock (or re-lock) Discover while the child is looking
  /// at this screen. If the tab we're on just vanished, fall back to rooms.
  void _onFamilyChange() {
    if (!mounted) return;
    setState(() {
      if (!_tabOrder.contains(_tab)) _tab = 'rooms';
    });
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMe() async {
    final session = widget.auth.session;
    if (session == null) return;
    try {
      final fresh = await widget.api.getProfile(session.userId, viewerUserId: session.userId);
      if (!mounted || fresh == null) return;
      setState(() => _me = fresh);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final session = widget.auth.session;
    if (session == null) return const SizedBox.shrink();
    final rooms = widget.repo.rooms;
    final me = _me ??
        ChatUser(id: session.userId, username: session.username, name: session.name);

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
                  onProfileTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        user: me,
                        repo: widget.repo,
                        api: widget.api,
                      ),
                    ),
                  ),
                  onCreateTap: _tab == 'rooms' && widget.family.canCreateRooms
                      ? _openCreate
                      : null,
                ),
                Expanded(
                  child: ListView(
                    key: const PageStorageKey('home_main_list'),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    children: [
                      _Hero(tab: _tab, roomCount: rooms.length),
                      const SizedBox(height: 18),
                      Center(
                        child: PillNav(
                          activeId: _tab,
                          onChange: _setTab,
                          items: [
                            PillNavItem(
                              id: 'rooms',
                              label: 'ROOMS',
                              badge: widget.repo.unreadMessageTotal == 0
                                  ? null
                                  : '${widget.repo.unreadMessageTotal}',
                            ),
                            if (widget.family.canSeePublicRooms)
                              const PillNavItem(
                                  id: 'discover', label: 'DISCOVER'),
                            PillNavItem(
                              id: 'friends',
                              label: 'FRIENDS',
                              badge: widget.repo.incomingRequests.isEmpty
                                  ? null
                                  : '${widget.repo.incomingRequests.length}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      AnimatedSize(
                        duration: theme.motionMed,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: theme.motionMed,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            final isExiting = anim.status == AnimationStatus.reverse ||
                                anim.status == AnimationStatus.dismissed;
                            final dx = (isExiting ? -1.0 : 1.0) * _direction * 0.08;
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(
                                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                                ),
                                child: child,
                              ),
                            );
                          },
                          layoutBuilder: (currentChild, previousChildren) => Stack(
                            alignment: Alignment.topLeft,
                            children: [
                              ...previousChildren,
                              ?currentChild,
                            ],
                          ),
                          child: KeyedSubtree(
                            key: ValueKey('${_tab}_${theme.id}'),
                            child: _panel(),
                          ),
                        ),
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

  Widget _panel() {
    switch (_tab) {
      case 'rooms':
        return _RoomsPanel(repo: widget.repo, api: widget.api);
      case 'friends':
        return FriendsPanel(
          repo: widget.repo,
          api: widget.api,
          family: widget.family,
        );
      case 'discover':
        return DiscoverPanel(
          repo: widget.repo,
          api: widget.api,
          family: widget.family,
        );
      default:
        return _RoomsPanel(repo: widget.repo, api: widget.api);
    }
  }

  void _openCreate() {
    HapticFeedback.lightImpact();
    showAdaptiveSheet(
      context,
      builder: (_) => CreateRoomSheet(repo: widget.repo, api: widget.api),
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
  });
  final ChatUser me;
  final ChatApi api;
  final String greeting;
  final VoidCallback onProfileTap;
  final VoidCallback? onCreateTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: UserAvatar(user: me, size: 36, api: api, showStatus: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'hey, $greeting.',
              style: theme.displayMedium,
              overflow: TextOverflow.ellipsis,
            ),
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
                          border: Border.all(color: theme.ink.withValues(alpha: 0.18), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: theme.accent.withValues(alpha: 0.32),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(CupertinoIcons.plus, size: 16, color: theme.accentInk),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.tab, required this.roomCount});
  final String tab;
  final int roomCount;

  String _word() {
    switch (tab) {
      case 'rooms':
        return 'rooms.';
      case 'friends':
        return 'friends.';
      case 'discover':
        return 'discover.';
      default:
        return 'rooms.';
    }
  }

  String _caption() {
    switch (tab) {
      case 'rooms':
        return '$roomCount in your hub';
      case 'friends':
        return 'people · requests · invites';
      case 'discover':
        return 'public rooms · open to join';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1.0),
            duration: theme.motionSlow,
            curve: theme.motionEntrance,
            builder: (context, v, child) => Transform.translate(
              offset: Offset(0, (1 - v) * 24),
              child: Opacity(opacity: ((v - 0.92) / 0.08).clamp(0.0, 1.0), child: child),
            ),
            child: AnimatedSwitcher(
              duration: theme.motionMed,
              switchInCurve: theme.motionEntrance,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: anim.drive(
                    Tween(begin: const Offset(0, 0.18), end: Offset.zero)
                        .chain(CurveTween(curve: theme.motionEntrance)),
                  ),
                  child: child,
                ),
              ),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.centerLeft,
                children: [
                  ...previousChildren,
                  ?currentChild,
                ],
              ),
              child: RichText(
                key: ValueKey('hero_word_$tab'),
                text: TextSpan(
                  style: theme.displayLarge,
                  children: [
                    TextSpan(text: 'your ', style: theme.displayLarge.copyWith(color: theme.inkMuted)),
                    TextSpan(text: _word()),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: theme.motionMed,
            switchInCurve: theme.motionEntrance,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: anim.drive(
                  Tween(begin: const Offset(0, 0.18), end: Offset.zero)
                      .chain(CurveTween(curve: theme.motionEntrance)),
                ),
                child: child,
              ),
            ),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                ...previousChildren,
                ?currentChild,
              ],
            ),
            child: Row(
              key: ValueKey('hero_cap_$tab'),
              children: [
                Container(width: 18, height: 1, color: theme.accent),
                const SizedBox(width: 8),
                Text(_caption(), style: theme.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomsPanel extends StatelessWidget {
  const _RoomsPanel({required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final rooms = repo.rooms;
    if (rooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('no rooms yet — create one', style: theme.bodySoft)),
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
            // incoming message reorders this list — and without a key Flutter
            // re-matches elements by index, handing the tile at position i a
            // DIFFERENT room. Its avatar then reloads (and briefly shows the
            // wrong face) on every reorder. See the same fix on the list layout.
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
            // moves the element rather than repurposing it, which is what made
            // avatars reload and momentarily swap between rows.
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

