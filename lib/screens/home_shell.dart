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
                  for (final d in navDestinations)
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
            _PillBottomNav(
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
                for (final d in navDestinations) ...[
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
      radius: theme.radiusLg,
      child: GestureDetector(
        onTap: () => onSelect(s),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionMed,
          curve: Curves.easeOutCubic,
          width: double.infinity,
          // Matches the pill segment's vertical padding so the two chromes
          // share a rhythm as well as a radius.
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? theme.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            // Same token as the bottom pill's indicator, so the two chromes
            // agree — the point of stacking the pill was to make compact and
            // expanded read as one design.
            borderRadius: BorderRadius.circular(theme.radiusLg),
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
              // Same widened box and same inversion as the pill segment — see
              // the comment there.
              SizedBox(
                width: 46,
                height: 22,
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
                        right: 0,
                        child: CountBadge(count: badge, onAccent: isActive),
                      ),
                  ],
                ),
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
      ),
    );
  }
}

/// The floating bottom nav, stacked icon-over-label.
///
/// Went stacked when a fourth destination arrived: at four segments a 375pt
/// phone gives each item 81.75pt, and after padding the side-by-side layout
/// left ~40pt for a label needing ~45pt, so "Settings" and "Discover" both
/// ellipsised — and worse once a badge appeared. Stacking also brings this into
/// line with [_SideRail], which was already icon-over-label, so compact and
/// expanded windows finally read as the same design.
class _PillBottomNav extends StatelessWidget {
  const _PillBottomNav({
    required this.active,
    required this.onSelect,
    required this.badges,
  });
  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;

  /// Per-destination badge counts. Was a pair of named `chatBadge` /
  /// `settingsBadge` fields, which meant every new destination wanting a badge
  /// cost another constructor parameter.
  final Map<HomeSection, int> badges;

  Alignment _alignmentFor(HomeSection s) => Alignment(
    segmentAlignmentX(
      navDestinations.indexWhere((d) => d.section == s),
      navDestinations.length,
    ),
    0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Concentric with the indicator inside it: the Container's 4pt padding is
    // the gap between the two outlines, so the shell's radius has to be the
    // indicator's plus that gap. Both were `circular(999)` before the pill went
    // stacked, which clamped to a tidy capsule at 335x46 but to a 31pt
    // barrel-end at 335x63.
    final shellRadius = BorderRadius.circular(theme.radiusLg + 4);
    return Positioned(
      left: 20,
      right: 20,
      bottom: 16,
      // Bottom only. SafeArea defaults to all four sides, and the status-bar
      // inset is still in MediaQuery down here, so the default was padding ~44pt
      // of dead space onto the top of a bottom-anchored bar.
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: ClipRRect(
          borderRadius: shellRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.surface.withValues(alpha: 0.72),
                borderRadius: shellRadius,
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
                        widthFactor: 1 / navDestinations.length,
                        heightFactor: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.16),
                            // A rounded rectangle, NOT a capsule. This was
                            // `circular(999)`, which was right when a segment
                            // was ~109x38 and the radius clamped to a proper
                            // pill. Stacking the icon over its label made each
                            // segment ~82x55, where 999 clamps to min(w,h)/2
                            // and both ends round into full semicircles — the
                            // indicator rendered as a squashed circle.
                            borderRadius: BorderRadius.circular(theme.radiusLg),
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
                      for (final d in navDestinations)
                        _btn(
                          theme,
                          d.icon,
                          d.label,
                          d.section,
                          badge: badges[d.section] ?? 0,
                        ),
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
      child: FocusableTap(
        onTap: () => onSelect(s),
        semanticLabel: label,
        // Matches the indicator behind it — a capsule ring around a near-square
        // segment reads as a circle for the same reason.
        radius: theme.radiusLg,
        child: GestureDetector(
          onTap: () => onSelect(s),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The Stack is widened past the glyph so a right-anchored badge
                // has somewhere to grow into. Sized to the 22pt icon with a
                // bare `right: -10`, the badge grew LEFTWARD instead — one
                // digit covered the icon's right 6pt and "99+" covered 18 of
                // its 22.
                SizedBox(
                  width: 46,
                  height: 22,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: theme.motionMed,
                        style: TextStyle(
                          color: isActive ? theme.accent : theme.inkSoft,
                        ),
                        child: Builder(
                          builder: (ctx) => Icon(
                            icon,
                            size: 22,
                            color: DefaultTextStyle.of(ctx).style.color,
                          ),
                        ),
                      ),
                      if (badge > 0)
                        Positioned(
                          top: -6,
                          right: 0,
                          // Sits on the accent-filled sliding indicator when
                          // this segment is the active one, so it has to invert
                          // there. Hardcoding `false` painted accent@0.16 on
                          // accent@0.16 and the badge vanished on the one
                          // segment most likely to carry it.
                          child: CountBadge(count: badge, onAccent: isActive),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                AnimatedDefaultTextStyle(
                  duration: theme.motionMed,
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontFamily: 'CupertinoSystemText',
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.08,
                    color: isActive ? theme.accent : theme.inkSoft,
                  ),
                  // Still guarded: at four segments a 375pt phone gives each
                  // label ~74pt, which fits every current destination, but a
                  // fifth one or a longer word should degrade rather than
                  // throw an overflow.
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
