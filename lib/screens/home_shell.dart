import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/radial_floating_menu.dart';
import 'feed_screen.dart';
import 'home_screen.dart' as chat;
import 'settings_screen.dart';

/// Hosts the active major section (Chat / Feed / Settings) and switches via
/// the [RadialFloatingMenu] (or a conventional bottom-pill nav, depending on
/// [SettingsStore.navStyle]).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repo, required this.api, required this.auth});
  final ChatRepository repo;
  final ChatApi api;
  final AuthService auth;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    SettingsStore.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _select(HomeSection s) => SettingsStore.instance.setSection(s);

  Widget _section() {
    switch (SettingsStore.instance.section) {
      case HomeSection.chat:
        return chat.HomeScreen(repo: widget.repo, api: widget.api, auth: widget.auth);
      case HomeSection.feed:
        return const FeedScreen();
      case HomeSection.settings:
        return SettingsScreen(repo: widget.repo, api: widget.api, auth: widget.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final settings = SettingsStore.instance;
    final radial = settings.navStyle == NavStyle.radial;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Active section content
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: theme.motionMed,
              switchInCurve: theme.motionEntrance,
              child: KeyedSubtree(
                key: ValueKey('${settings.section.name}_${theme.id}'),
                child: _section(),
              ),
            ),
          ),
          // Radial menu overlay
          if (radial)
            Positioned.fill(
              child: RadialFloatingMenu(
                active: settings.section,
                onSelect: _select,
                items: const [
                  RadialMenuItem(section: HomeSection.chat, icon: CupertinoIcons.bubble_left, label: 'CHAT'),
                  RadialMenuItem(section: HomeSection.feed, icon: CupertinoIcons.sparkles, label: 'FEED'),
                  RadialMenuItem(section: HomeSection.settings, icon: CupertinoIcons.gear, label: 'SET'),
                ],
              ),
            )
          else
            _PillBottomNav(
              active: settings.section,
              onSelect: _select,
            ),
        ],
      ),
    );
  }
}

class _PillBottomNav extends StatelessWidget {
  const _PillBottomNav({required this.active, required this.onSelect});
  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Positioned(
      left: 20,
      right: 20,
      bottom: 16,
      child: SafeArea(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.divider, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _btn(theme, CupertinoIcons.bubble_left, 'Chat', HomeSection.chat),
                  _btn(theme, CupertinoIcons.sparkles, 'Feed', HomeSection.feed),
                  _btn(theme, CupertinoIcons.gear, 'Settings', HomeSection.settings),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn(AppTheme theme, IconData icon, String label, HomeSection s) {
    final isActive = s == active;
    final color = isActive ? theme.accent : theme.inkSoft;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(s),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'CupertinoSystemText',
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.08,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
