import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/theme_chip.dart';
import '../widgets/pill_nav.dart';
import '../widgets/room_card.dart';
import '../widgets/room_grid_tile.dart';
import 'room_screen.dart';
import 'create_room_sheet.dart';
import 'requests_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repo, required this.api, required this.auth});
  final ChatRepository repo;
  final ChatApi api;
  final AuthService auth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _tab = 'rooms';

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final session = widget.auth.session;
    if (session == null) return const SizedBox.shrink();
    final rooms = widget.repo.rooms;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  greeting: session.name.split(' ').first.toLowerCase(),
                  handle: '@${session.username}',
                  onProfileTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        user: ChatUser(
                          id: session.userId,
                          username: session.username,
                          name: session.name,
                        ),
                        repo: widget.repo,
                        api: widget.api,
                      ),
                    ),
                  ),
                  onSignOut: () async {
                    final nav = Navigator.of(context);
                    await widget.auth.signOut();
                    await widget.repo.detach();
                    if (!mounted) return;
                    nav.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => LoginScreen(auth: widget.auth)),
                      (_) => false,
                    );
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    children: [
                      _Hero(tab: _tab, roomCount: rooms.length),
                      const SizedBox(height: 18),
                      Center(
                        child: PillNav(
                          activeId: _tab,
                          onChange: (id) => setState(() => _tab = id),
                          items: const [
                            PillNavItem(id: 'rooms', label: 'ROOMS'),
                            PillNavItem(id: 'requests', label: 'REQUESTS'),
                            PillNavItem(id: 'discover', label: 'DISCOVER'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      AnimatedSwitcher(
                        duration: theme.motionMed,
                        switchInCurve: theme.motionEntrance,
                        child: KeyedSubtree(
                          key: ValueKey('${_tab}_${theme.id}'),
                          child: _panel(),
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
      floatingActionButton: _CreateRoomFab(onTap: _openCreate),
    );
  }

  Widget _panel() {
    switch (_tab) {
      case 'rooms':
        return _RoomsPanel(repo: widget.repo, api: widget.api);
      case 'requests':
        return RequestsPanel(repo: widget.repo, api: widget.api);
      case 'discover':
        return DiscoverPanel(repo: widget.repo, api: widget.api);
      default:
        return _RoomsPanel(repo: widget.repo, api: widget.api);
    }
  }

  void _openCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CreateRoomSheet(repo: widget.repo, api: widget.api),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.handle,
    required this.onProfileTap,
    required this.onSignOut,
  });
  final String greeting;
  final String handle;
  final VoidCallback onProfileTap;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(onTap: onProfileTap, child: theme.brandMark(size: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        handle,
                        style: theme.mono.copyWith(color: theme.inkMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.success,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: theme.success.withValues(alpha: 0.6), blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('hey, $greeting.', style: theme.displayMedium),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: theme.surfaceRaised,
            padding: EdgeInsets.zero,
            onSelected: (v) {
              if (v == 'signout') onSignOut();
            },
            icon: Icon(Icons.more_vert, color: theme.inkSoft, size: 18),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'signout', child: Text('Sign out', style: theme.body)),
            ],
          ),
          const ThemeChip(),
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
      case 'requests':
        return 'requests.';
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
      case 'requests':
        return 'friend · invite · direct';
      case 'discover':
        return 'public rooms · open profiles';
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
            child: RichText(
              text: TextSpan(
                style: theme.displayHero,
                children: [
                  TextSpan(text: 'your ', style: theme.displayHero.copyWith(color: theme.inkMuted)),
                  TextSpan(text: _word()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 18, height: 1, color: theme.accent),
              const SizedBox(width: 8),
              Text(_caption(), style: theme.caption),
            ],
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
      final cols = MediaQuery.of(context).size.width > 700 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.82,
        ),
        itemCount: rooms.length,
        itemBuilder: (context, i) {
          return TweenAnimationBuilder<double>(
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
              typingNames: repo.typingIn(rooms[i].id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RoomScreen(roomId: rooms[i].id, repo: repo, api: api)),
              ),
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
              typingNames: repo.typingIn(rooms[i].id),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RoomScreen(roomId: rooms[i].id, repo: repo, api: api)),
              ),
            ),
          ),
      ],
    );
  }
}

class _CreateRoomFab extends StatelessWidget {
  const _CreateRoomFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: theme.accent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.ink.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(color: theme.accent.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: theme.accentInk),
            const SizedBox(width: 8),
            Text('NEW ROOM', style: theme.label.copyWith(color: theme.accentInk)),
          ],
        ),
      ),
    );
  }
}
