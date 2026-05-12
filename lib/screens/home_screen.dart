import 'dart:async';
import 'package:flutter/material.dart';
import '../data/mock_store.dart';
import '../theme/theme_scope.dart';
import '../widgets/theme_chip.dart';
import '../widgets/pill_nav.dart';
import '../widgets/room_card.dart';
import 'room_screen.dart';
import 'create_room_sheet.dart';
import 'requests_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _tab = 'rooms';
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    // Periodically prune expired ephemeral messages (the "server forgets" behavior)
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      MockStore.instance.purgeExpiredMessages();
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              theme.backgroundLayer(context),
              SafeArea(
                child: Column(
                  children: [
                    _Header(onProfileTap: () => _openProfile(context)),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                        children: [
                          _Hero(tab: _tab),
                          const SizedBox(height: 18),
                          Center(
                            child: PillNav(
                              activeId: _tab,
                              onChange: (id) => setState(() => _tab = id),
                              items: [
                                const PillNavItem(id: 'rooms', label: 'ROOMS'),
                                PillNavItem(
                                  id: 'requests',
                                  label: 'REQUESTS',
                                  badge: store.friendRequests.isEmpty && store.roomInvites.isEmpty
                                      ? null
                                      : '${store.friendRequests.length + store.roomInvites.length}',
                                ),
                                const PillNavItem(id: 'discover', label: 'DISCOVER'),
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
          floatingActionButton: _CreateRoomFab(onTap: () => _openCreate(context)),
        );
      },
    );
  }

  Widget _panel() {
    switch (_tab) {
      case 'rooms':
        return const _RoomsPanel();
      case 'requests':
        return const RequestsPanel();
      case 'discover':
        return const DiscoverPanel();
      default:
        return const _RoomsPanel();
    }
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(user: MockStore.instance.me)));
  }

  void _openCreate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CreateRoomSheet(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onProfileTap});
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final me = MockStore.instance.me;
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
                    Text(me.handle, style: theme.mono.copyWith(color: theme.inkMuted)),
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
                Text('hey, ${me.name.split(' ').first.toLowerCase()}.', style: theme.displayMedium),
              ],
            ),
          ),
          const ThemeChip(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.tab});
  final String tab;

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
    final s = MockStore.instance;
    switch (tab) {
      case 'rooms':
        final eph = s.roomsForMe().where((r) => r.isEphemeral).length;
        final std = s.roomsForMe().length - eph;
        return '$std humming · $eph fading';
      case 'requests':
        return '${s.friendRequests.length} friend · ${s.roomInvites.length} invite';
      case 'discover':
        return 'public people · public rooms';
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
  const _RoomsPanel();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final rooms = store.roomsForMe();
    if (rooms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('no rooms yet — create one', style: theme.bodySoft)),
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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RoomScreen(roomId: rooms[i].id)),
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
