import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../family/family_service.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/count_badge.dart';
import '../widgets/radial_floating_menu.dart';
import 'feed_screen.dart';
import 'home_screen.dart' as chat;
import 'navigation/open_room.dart';
import 'room_screen.dart';
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
    // WindowClass is published app-wide by _WindowClassProvider in app.dart
    // (above the root navigator, so pushed routes see it too). Here we just
    // pick the shell chrome.
    return context.isExpanded ? _buildDesktop(context) : _buildCompact(context);
  }

  /// The active major section, cross-faded on section/theme change. Shared by
  /// the compact (bottom-nav) and desktop (side-rail) shells.
  Widget _sectionSwitcher(AppTheme theme, SettingsStore settings) {
    return AnimatedSwitcher(
      duration: theme.motionMed,
      switchInCurve: theme.motionEntrance,
      child: KeyedSubtree(
        key: ValueKey('${settings.section.name}_${theme.id}'),
        child: _section(),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final theme = ThemeScope.of(context);
    final settings = SettingsStore.instance;
    final radial = settings.navStyle == NavStyle.radial;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Active section content
          Positioned.fill(child: _sectionSwitcher(theme, settings)),
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
                    badgeCount: widget.repo.unreadMessageTotal,
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
              chatBadge: widget.repo.unreadMessageTotal,
              settingsBadge: widget.family.pendingCount,
            ),
        ],
      ),
    );
  }

  /// Wide-window shell: a persistent left side rail replaces the floating
  /// bottom pill / radial menu. Section switching is identical to compact —
  /// the rail calls the same [_select]. Sections still render full-width here;
  /// the chat/settings two-pane split arrives in later phases.
  Widget _buildDesktop(BuildContext context) {
    final theme = ThemeScope.of(context);
    final settings = SettingsStore.instance;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Full-bleed themed background so the glass side rail samples the
          // app's real backdrop instead of a flat (washed-out) scaffold color.
          theme.backgroundLayer(context),
          SafeArea(
            child: Row(
              children: [
                _SideRail(
                  active: settings.section,
                  onSelect: _select,
                  chatBadge: widget.repo.unreadMessageTotal,
                  settingsBadge: widget.family.pendingCount,
                ),
                VerticalDivider(
                    width: 0.5, thickness: 0.5, color: theme.divider),
                Expanded(
                  // Isolate the section's raster from side-rail repaints during
                  // a drag-resize.
                  child: RepaintBoundary(child: _desktopSection(theme, settings)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop section content, cross-faded on section/theme change. Chat renders
  /// as a two-pane master/detail; other sections render full-width (settings
  /// gains its own two-pane in a later phase).
  Widget _desktopSection(AppTheme theme, SettingsStore settings) {
    final Widget content;
    switch (settings.section) {
      case HomeSection.chat:
        content = _ChatTwoPane(
          repo: widget.repo,
          api: widget.api,
          auth: widget.auth,
          family: widget.family,
        );
      case HomeSection.feed:
        content = const FeedScreen();
      case HomeSection.settings:
        content = _SettingsTwoPane(
          repo: widget.repo,
          api: widget.api,
          auth: widget.auth,
          family: widget.family,
        );
    }
    return AnimatedSwitcher(
      duration: theme.motionMed,
      switchInCurve: theme.motionEntrance,
      child: KeyedSubtree(
        key: ValueKey('desktop_${settings.section.name}_${theme.id}'),
        child: content,
      ),
    );
  }
}

/// Desktop chat: a fixed-width master list on the left and the selected room
/// (or an empty hint) on the right. Room selection lives in [UiSelectionStore];
/// tapping a room in the list calls `openRoom`, which sets that selection on
/// expanded layouts. `PopScope` maps a system/browser back to "deselect room"
/// so it doesn't fall through and leave the app.
class _ChatTwoPane extends StatelessWidget {
  const _ChatTwoPane({
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
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final selection = UiSelectionStore.instance;
    return AnimatedBuilder(
      animation: selection,
      builder: (context, _) {
        final roomId = selection.roomId;
        return PopScope(
          canPop: roomId == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) selection.selectRoom(null);
          },
          child: Row(
            children: [
              SizedBox(
                width: 360,
                child: RepaintBoundary(
                  child: chat.HomeScreen(
                    repo: repo,
                    api: api,
                    auth: auth,
                    family: family,
                  ),
                ),
              ),
              VerticalDivider(
                  width: 0.5, thickness: 0.5, color: theme.divider),
              Expanded(
                child: RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: theme.motionMed,
                    switchInCurve: theme.motionEntrance,
                    child: roomId == null
                        ? _EmptyRoomHint(key: const ValueKey('empty'))
                        : RoomScreen(
                            key: ValueKey(roomId),
                            roomId: roomId,
                            repo: repo,
                            api: api,
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyRoomHint extends StatelessWidget {
  const _EmptyRoomHint({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Paint the theme's background layer so the empty pane matches the rest of
    // the app rather than falling through to a bare (light) surface.
    return Stack(
      fit: StackFit.expand,
      children: [
        theme.backgroundLayer(context),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.bubble_left, size: 40, color: theme.inkMuted),
              const SizedBox(height: 14),
              Text('pick a room to start chatting', style: theme.bodySoft),
            ],
          ),
        ),
      ],
    );
  }
}

/// Desktop settings: the settings list (master) on the left, the selected
/// sub-screen in a detail pane on the right. The pane is a nested [Navigator]
/// (see [settingsPaneNavKey]) whose base route is an empty hint, so each
/// sub-screen's own back button pops back to it — no sub-screen changes needed.
class _SettingsTwoPane extends StatelessWidget {
  const _SettingsTwoPane({
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
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        SizedBox(
          width: 360,
          child: RepaintBoundary(
            child: SettingsScreen(
              repo: repo,
              api: api,
              auth: auth,
              family: family,
            ),
          ),
        ),
        VerticalDivider(width: 0.5, thickness: 0.5, color: theme.divider),
        const Expanded(child: RepaintBoundary(child: _SettingsDetailPane())),
      ],
    );
  }
}

class _SettingsDetailPane extends StatefulWidget {
  const _SettingsDetailPane();
  @override
  State<_SettingsDetailPane> createState() => _SettingsDetailPaneState();
}

class _SettingsDetailPaneState extends State<_SettingsDetailPane> {
  late final _SettingsPaneObserver _observer = _SettingsPaneObserver();

  @override
  void initState() {
    super.initState();
    // A freshly (re)mounted pane starts empty — clear any stale highlight from
    // a previous visit to the Settings section.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UiSelectionStore.instance.setSettingsDetailKey(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: settingsPaneNavKey,
      observers: [_observer],
      onGenerateInitialRoutes: (navigator, initialRoute) => [
        MaterialPageRoute(builder: (_) => const _SettingsEmptyHint()),
      ],
    );
  }
}

/// Clears the active-row highlight once the pane has popped all the way back to
/// its empty base route (but not when a sub-screen merely pops one of its own
/// child routes).
class _SettingsPaneObserver extends NavigatorObserver {
  void _syncHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = settingsPaneNavKey.currentState;
      if (nav != null && !nav.canPop()) {
        UiSelectionStore.instance.setSettingsDetailKey(null);
      }
    });
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _syncHighlight();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _syncHighlight();
}

class _SettingsEmptyHint extends StatelessWidget {
  const _SettingsEmptyHint();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Match the app's themed background instead of a bare white pane.
          theme.backgroundLayer(context),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.gear, size: 40, color: theme.inkMuted),
                const SizedBox(height: 14),
                Text('pick a setting', style: theme.bodySoft),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Persistent desktop navigation rail. Hand-rolled to match the app's glass
/// aesthetic (a raw Material [NavigationRail] can't reproduce the blurred
/// surface + accent styling of [_PillBottomNav]); it reuses the same theme
/// tokens, [CountBadge], and active-accent logic as the pill, laid out
/// vertically.
class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.active,
    required this.onSelect,
    this.chatBadge = 0,
    this.settingsBadge = 0,
  });

  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;
  final int chatBadge;
  final int settingsBadge;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.72),
              border: Border(
                  right: BorderSide(color: theme.divider, width: 0.5)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 4),
                  child: theme.brandMark(size: 34),
                ),
                _railBtn(theme, CupertinoIcons.bubble_left, 'Chat',
                    HomeSection.chat,
                    badge: chatBadge),
                const SizedBox(height: 6),
                _railBtn(theme, CupertinoIcons.sparkles, 'Feed',
                    HomeSection.feed),
                const SizedBox(height: 6),
                _railBtn(theme, CupertinoIcons.gear, 'Settings',
                    HomeSection.settings,
                    badge: settingsBadge),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _railBtn(
    AppTheme theme,
    IconData icon,
    String label,
    HomeSection s, {
    int badge = 0,
  }) {
    final isActive = s == active;
    return GestureDetector(
      onTap: () => onSelect(s),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: theme.motionMed,
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? theme.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? theme.accent.withValues(alpha: 0.32)
                : Colors.transparent,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon,
                    size: 22,
                    color: isActive ? theme.accent : theme.inkSoft),
                if (badge > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: CountBadge(count: badge, onAccent: false),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'CupertinoSystemText',
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.08,
                color: isActive ? theme.accent : theme.inkSoft,
              ),
            ),
          ],
        ),
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
