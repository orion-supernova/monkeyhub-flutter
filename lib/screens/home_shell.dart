import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../family/family_service.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/count_badge.dart';
import '../widgets/radial_floating_menu.dart';
import 'discover_screen.dart';
import 'feed_screen.dart';
import 'home_screen.dart' as chat;
import 'navigation/destinations.dart';
import 'navigation/open_room.dart';
import 'navigation/pill_bottom_nav.dart';
import 'room_screen.dart';
import 'settings_screen.dart';

/// Hosts the active major section (Chat / Discover / Feed / Settings) and
/// switches via the [RadialFloatingMenu] (or a conventional bottom-pill nav,
/// depending on [SettingsStore.navStyle]).
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

  /// Badge counts per destination, built once and shared by all three nav
  /// chromes so they can't drift apart. Destinations with nothing to report are
  /// simply absent; [CountBadge] renders nothing at zero anyway.
  Map<HomeSection, int> get _badges => {
    HomeSection.chat: widget.repo.unreadMessageTotal,
    HomeSection.discover: widget.repo.incomingRequests.length,
    HomeSection.settings: widget.family.pendingCount,
  };

  Widget _section() {
    switch (SettingsStore.instance.section) {
      case HomeSection.chat:
        return chat.HomeScreen(
          repo: widget.repo,
          api: widget.api,
          auth: widget.auth,
          family: widget.family,
        );
      case HomeSection.discover:
        return DiscoverScreen(
          repo: widget.repo,
          api: widget.api,
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
                  for (final d in navDestinations(AppLocalizations.of(context)))
                    RadialMenuItem(
                      section: d.section,
                      icon: d.icon,
                      label: d.short,
                      badgeCount: _badges[d.section] ?? 0,
                    ),
                ],
              ),
            )
          else
            PillBottomNav(
              active: settings.section,
              onSelect: _select,
              badges: _badges,
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
                  badges: _badges,
                ),
                VerticalDivider(
                  width: 0.5,
                  thickness: 0.5,
                  color: theme.divider,
                ),
                Expanded(
                  // Isolate the section's raster from side-rail repaints during
                  // a drag-resize.
                  child: RepaintBoundary(
                    child: _desktopSection(theme, settings),
                  ),
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
      case HomeSection.discover:
        // Full-width like Feed. Discover's own rows push detail screens
        // (search, requests, a joined room), so there's no master/detail split
        // to make here.
        content = DiscoverScreen(
          repo: widget.repo,
          api: widget.api,
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
              VerticalDivider(width: 0.5, thickness: 0.5, color: theme.divider),
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
              Text(
                AppLocalizations.of(context).homeShellEmptyRoomHint,
                style: theme.bodySoft,
              ),
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
                Text(
                  AppLocalizations.of(context).homeShellEmptySettingHint,
                  style: theme.bodySoft,
                ),
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
    required this.badges,
  });

  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;
  final Map<HomeSection, int> badges;

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
                right: BorderSide(color: theme.divider, width: 0.5),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 4),
                  child: theme.brandMark(size: 34),
                ),
                for (final d in navDestinations(AppLocalizations.of(context))) ...[
                  _railBtn(
                    theme,
                    d.icon,
                    d.label,
                    d.section,
                    badge: badges[d.section] ?? 0,
                  ),
                  const SizedBox(height: 6),
                ],
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
    return FocusableTap(
      onTap: () => onSelect(s),
      semanticLabel: label,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: () => onSelect(s),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          curve: Curves.easeOutCubic,
          width: double.infinity,
          // Matches the pill segment's vertical padding so the two chromes
          // share a rhythm as well as a shape.
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: ShapeDecoration(
            color: isActive
                ? theme.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            // Same shape as the bottom pill's indicator, so the two chromes
            // agree — the point of stacking the pill was to make compact and
            // expanded read as one design.
            shape: StadiumBorder(
              side: BorderSide(
                color: isActive
                    ? theme.accent.withValues(alpha: 0.32)
                    : Colors.transparent,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Same glyph-sized box, same left-anchored badge and same
              // inversion as the pill segment — see the comments there.
              SizedBox.square(
                dimension: 22,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isActive ? theme.accent : theme.inkSoft,
                    ),
                    if (badge > 0)
                      Positioned(
                        top: -6,
                        left: 13,
                        child: CountBadge(count: badge, onAccent: isActive),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
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
      ),
    );
  }
}
