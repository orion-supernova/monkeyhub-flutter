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
                  RadialMenuItem(section: HomeSection.chat, icon: Icons.chat_bubble_outline, label: 'CHAT'),
                  RadialMenuItem(section: HomeSection.feed, icon: Icons.auto_awesome_outlined, label: 'FEED'),
                  RadialMenuItem(section: HomeSection.settings, icon: Icons.tune, label: 'SET'),
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
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.divider),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              _btn(theme, Icons.chat_bubble_outline, 'CHAT', HomeSection.chat),
              _btn(theme, Icons.auto_awesome_outlined, 'FEED', HomeSection.feed),
              _btn(theme, Icons.tune, 'SETTINGS', HomeSection.settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(AppTheme theme, IconData icon, String label, HomeSection s) {
    final isActive = s == active;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(s),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? theme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? theme.accentInk : theme.inkSoft),
              const SizedBox(width: 8),
              Text(label,
                  style: theme.label.copyWith(color: isActive ? theme.accentInk : theme.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
