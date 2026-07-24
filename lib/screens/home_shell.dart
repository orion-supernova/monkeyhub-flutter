import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../family/family_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/count_badge.dart';
import '../widgets/radial_floating_menu.dart';
import 'feed_screen.dart';
import 'home_screen.dart' as chat;
import 'settings_screen.dart';

/// Hosts the active major section (Chat / Feed / Settings) and switches via
/// the [RadialFloatingMenu] (or a conventional bottom-pill nav, depending on
/// [SettingsStore.navStyle]).
class HomeShell extends StatefulWidget {
  const HomeShell({
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
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    SettingsStore.instance.addListener(_onSettings);
    // Without this the approvals badge would only update when something else
    // happened to rebuild the shell.
    widget.family.addListener(_onSettings);
    // Keep the Chat tab's unread badge live as rooms gain/clear unread state.
    widget.repo.addListener(_onSettings);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    widget.family.removeListener(_onSettings);
    widget.repo.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _select(HomeSection s) => SettingsStore.instance.setSection(s);

  Widget _section() {
    switch (SettingsStore.instance.section) {
      case HomeSection.chat:
        return chat.HomeScreen(
          repo: widget.repo,
          api: widget.api,
          auth: widget.auth,
          family: widget.family,
        );
      case HomeSection.feed:
        return const FeedScreen();
      case HomeSection.settings:
        return SettingsScreen(
          repo: widget.repo,
          api: widget.api,
          auth: widget.auth,
          family: widget.family,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[home_shell] build');
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
                items: [
                  RadialMenuItem(
                    section: HomeSection.chat,
                    icon: CupertinoIcons.bubble_left,
                    label: 'CHAT',
                    badgeCount: widget.repo.unreadRoomCount,
                  ),
                  const RadialMenuItem(
                      section: HomeSection.feed,
                      icon: CupertinoIcons.sparkles,
                      label: 'FEED'),
                  RadialMenuItem(
                    section: HomeSection.settings,
                    icon: CupertinoIcons.gear,
                    label: 'SET',
                    badgeCount: widget.family.pendingCount,
                  ),
                ],
              ),
            )
          else
            _PillBottomNav(
              active: settings.section,
              onSelect: _select,
              chatBadge: widget.repo.unreadRoomCount,
              settingsBadge: widget.family.pendingCount,
            ),
        ],
      ),
    );
  }
}

class _PillBottomNav extends StatelessWidget {
  const _PillBottomNav({
    required this.active,
    required this.onSelect,
    this.chatBadge = 0,
    this.settingsBadge = 0,
  });
  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;

  /// Rooms with unread messages. Rendered on the Chat segment.
  final int chatBadge;

  /// Approvals waiting on this account. Rendered on the Settings segment,
  /// which is the only route to the family screen.
  final int settingsBadge;

  static const _sections = [
    HomeSection.chat,
    HomeSection.feed,
    HomeSection.settings,
  ];

  Alignment _alignmentFor(HomeSection s) {
    // 3 segments → -1, 0, +1 on the x axis.
    final i = _sections.indexOf(s);
    return Alignment(-1 + i * 1.0, 0);
  }

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
              child: Stack(
                children: [
                  // Sliding accent indicator behind the active segment.
                  Positioned.fill(
                    child: AnimatedAlign(
                      duration: theme.motionMed,
                      curve: Curves.easeOutCubic,
                      alignment: _alignmentFor(active),
                      child: FractionallySizedBox(
                        widthFactor: 1 / _sections.length,
                        heightFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: theme.accent.withValues(alpha: 0.32),
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _btn(theme, CupertinoIcons.bubble_left, 'Chat', HomeSection.chat,
                          badge: chatBadge),
                      _btn(theme, CupertinoIcons.sparkles, 'Feed', HomeSection.feed),
                      _btn(theme, CupertinoIcons.gear, 'Settings', HomeSection.settings,
                          badge: settingsBadge),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn(
    AppTheme theme,
    IconData icon,
    String label,
    HomeSection s, {
    int badge = 0,
  }) {
    final isActive = s == active;
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
              AnimatedDefaultTextStyle(
                duration: theme.motionMed,
                style: TextStyle(color: isActive ? theme.accent : theme.inkSoft),
                child: Builder(
                  builder: (ctx) => Icon(
                    icon,
                    size: 20,
                    color: DefaultTextStyle.of(ctx).style.color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Flexible so the label ellipsises rather than overflowing when
              // the badge appears — a third of a narrow phone's pill is only
              // just wide enough for "Settings" on its own.
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: theme.motionMed,
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontFamily: 'CupertinoSystemText',
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.08,
                    color: isActive ? theme.accent : theme.inkSoft,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 5),
                CountBadge(count: badge, onAccent: isActive),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
