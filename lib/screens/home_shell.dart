import 'dart:async' show unawaited;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../backend/feed_api.dart';
import '../data/chat_repository.dart';
import '../data/feed_store.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../family/family_service.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../ui/foundation/ui_kit.dart';
import '../ui/kits/shader/shader_tab_bar.dart';
import '../update/update_availability.dart';
import '../widgets/radial_floating_menu.dart';
import '../widgets/terms_consent.dart';
import '../widgets/ios_kit.dart' show quietFill;
import 'calls/call_log_store.dart';
import 'calls/calls_directory.dart';
import 'calls/calls_screen.dart';
import 'games_screen.dart';
import 'feed_screen.dart';
import 'home_screen.dart' as chat;
import 'navigation/destinations.dart';
import 'navigation/list_detail_split.dart';
import 'navigation/native_tab_bar.dart';
import 'navigation/open_room.dart';
import 'navigation/pill_bottom_nav.dart';
import 'navigation/room_side_pane.dart';
import 'navigation/section_switcher.dart';
import 'navigation/tab_reselect.dart';
import 'room_screen.dart';
import 'settings_screen.dart';
import '../widgets/route_depth.dart';
import '../ui/lab/controls_lab_screen.dart';
import '../ui/native/native_control.dart' show NativeControl;

const bool _kOpenLab = bool.fromEnvironment('OPEN_LAB');

/// `--dart-define=OPEN_ROOM=<n or name>` opens the n-th chat (or the first
/// whose name contains it) once rooms load: a headless simulator cannot tap.
const String _kOpenRoom = String.fromEnvironment('OPEN_ROOM');

/// Hosts the active major section (Chat / Discover / Feed / Settings) and
/// switches via the [RadialFloatingMenu] (or a conventional bottom-pill nav,
/// depending on [SettingsStore.navStyle]).
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repo,
    required this.api,
    required this.feedApi,
    required this.auth,
    required this.family,
  });
  final ChatRepository repo;
  final ChatApi api;
  final FeedApi feedApi;
  final AuthService auth;
  final FamilyService family;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    FeedStore.instance.noteShellLaunch(
      SettingsStore.instance.section == HomeSection.feed,
    );
    SettingsStore.instance.addListener(_onSettings);
    // Without this the approvals badge would only update when something else
    // happened to rebuild the shell.
    widget.family.addListener(_onSettings);
    // Keep the Chat tab's unread badge live as rooms gain/clear unread state.
    widget.repo.addListener(_onSettings);
    // Same for the Feed tab's badge. Its own listener: the board changes on
    // every comment, reaction and guess, and only a change of the NUMBER is
    // worth rebuilding the nav for.
    FeedStore.instance.addListener(_onFeed);
    // Missed calls move the Calls tab's badge.
    CallLogStore.instance.addListener(_onSettings);
    // Lights the Settings tab the moment either the launch check or a manual
    // "Check for Updates" tap finds a newer build.
    UpdateAvailability.instance.addListener(_onSettings);
    // The Terms of Use, for an account that never ticked the sign-up box (it
    // predates the box, or an old build made it). Once per shell, a frame
    // late because it pushes a sheet; a no-op for everyone who agreed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ensureTermsAccepted(context, widget.api));
    });
    // Debug convenience for simulator screenshots:
    // `--dart-define=OPEN_LAB=true` opens the Controls lab after the first
    // frame of the shell.
    if (_kOpenRoom.isNotEmpty) {
      widget.repo.addListener(_openRoomOnce);
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRoomOnce());
    }
    if (_kOpenLab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ControlsLabScreen()),
        );
      });
    }
  }

  bool _openedRoom = false;

  void _openRoomOnce() {
    final rooms = widget.repo.rooms;
    if (_openedRoom || !mounted || rooms.isEmpty) return;
    final index = int.tryParse(_kOpenRoom);
    final room = index != null
        ? rooms[index.clamp(0, rooms.length - 1)]
        : rooms.firstWhere(
            (r) => r.name.toLowerCase().contains(_kOpenRoom.toLowerCase()),
            orElse: () => rooms.first,
          );
    _openedRoom = true;
    widget.repo.removeListener(_openRoomOnce);
    openRoom(context, roomId: room.id, repo: widget.repo, api: widget.api);
  }

  @override
  void dispose() {
    if (_kOpenRoom.isNotEmpty) widget.repo.removeListener(_openRoomOnce);
    SettingsStore.instance.removeListener(_onSettings);
    widget.family.removeListener(_onSettings);
    widget.repo.removeListener(_onSettings);
    FeedStore.instance.removeListener(_onFeed);
    CallLogStore.instance.removeListener(_onSettings);
    UpdateAvailability.instance.removeListener(_onSettings);
    super.dispose();
  }

  /// The Feed tab's badge as last built, so [_onFeed] can tell a board change
  /// that moves the number from the many that do not.
  int _feedBadge = -1;

  /// Friends' unopened moments plus friends' results the Activity board has
  /// not yet been on screen for. Everything it reads is already loaded by the
  /// app-wide board subscription: no query of its own.
  int _feedBadgeNow() =>
      FeedStore.instance.unseenCount +
      FeedStore.instance.newPlayCount(
        SettingsStore.instance.feedActivitySeenAt,
      );

  void _onFeed() {
    if (!mounted || _feedBadgeNow() == _feedBadge) return;
    _onSettings();
  }

  void _onSettings() {
    if (!mounted) return;
    // The Calls tab's missed-call subscription lives exactly as long as the
    // tab is switched on. A no-op when nothing changed.
    CallLogStore.instance.setEnabled(SettingsStore.instance.showCallsTab);
    setState(() {});
  }

  /// All three nav chromes report every tap here, including one on the
  /// destination that is already active. That used to reach
  /// [SettingsStore.setSection], which returns early on a same-section change —
  /// so tapping Chat while reading a scrolled-down chat list did nothing at
  /// all. Re-tapping the active tab is the standard way back to the top of it,
  /// so the shell announces it and the section on screen answers (see
  /// [TabReselectScroll]).
  void _select(HomeSection s) {
    if (s == SettingsStore.instance.section) {
      TabReselect.instance.fire(s);
      return;
    }
    SettingsStore.instance.setSection(s);
  }

  /// Badge counts per destination, built once and shared by all three nav
  /// chromes so they can't drift apart. Destinations with nothing to report are
  /// simply absent; [CountBadge] renders nothing at zero anyway.
  Map<HomeSection, int> get _badges => {
    // Unread messages plus friend requests and group invites: Discover is a
    // page off the chat list now, and the Requests row at the top of that
    // list is where those wait, so the tab that leads to them carries them.
    HomeSection.chat: widget.repo.unreadMessageTotal +
        widget.repo.incomingRequests.length +
        widget.repo.roomInvitations.length,
    // Missed calls since the Calls tab was last opened. Read from the store's
    // one shared "missed" subscription; zero when the tab is switched off.
    if (SettingsStore.instance.showCallsTab)
      HomeSection.calls: CallLogStore.instance.badgeCount,
    // What friends did that the user hasn't seen: moments not yet opened plus
    // finished results the Activity board hasn't been on screen for. One
    // entry lights the badge in all the nav chromes, and it is the only
    // reason anyone opens this tab on day thirty. FeedStore is subscribed app-wide (attached in
    // app.dart, not by the Feed screen), so this stays live while the user is
    // on another tab.
    HomeSection.feed: _feedBadge = _feedBadgeNow(),
    // Approvals plus "there's a new version" share the one badge slot
    // Settings has always had — same rationale as the other three rows: one
    // number saying the tab has something to show you, not a taxonomy of why.
    HomeSection.settings:
        widget.family.pendingCount +
        (UpdateAvailability.instance.available ? 1 : 0),
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
      case HomeSection.games:
        return GamesScreen(repo: widget.repo, feedApi: widget.feedApi);
      case HomeSection.calls:
        return CallsScreen(
          directory: RepoCallsDirectory(widget.repo, widget.api),
          api: widget.api,
        );
      case HomeSection.feed:
        return FeedScreen(
          repo: widget.repo,
          api: widget.api,
          feedApi: widget.feedApi,
          auth: widget.auth,
          family: widget.family,
        );
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
    // WindowClass is published app-wide by _WindowClassProvider in app.dart
    // (above the root navigator, so pushed routes see it too). Here we just
    // pick the shell chrome.
    // `usesSplitShell`, not `isExpanded`: a desktop gets the rail from
    // Breakpoints.split up, so a half-screen Mac window is still a Mac app.
    return context.usesSplitShell
        ? _buildDesktop(context)
        : _buildCompact(context);
  }

  /// The active major section, transitioned on section/theme change. Shared by
  /// the compact (bottom-nav) and desktop (side-rail) shells.
  Widget _sectionSwitcher(AppTheme theme, SettingsStore settings) =>
      SectionSwitcher(
        section: settings.section,
        variant: theme.id,
        keepAlive: NativeControl.readyIn(context),
        child: _section(),
      );

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
          else if (NativeChrome.active)
            // Positioned, not a bare child. It paints nothing, and a Stack
            // sizes itself to its unpositioned children — the pill is
            // full-size, so it was holding this Stack open; a 0×0 child in its
            // place collapsed the whole shell, section and all, to nothing.
            Positioned.fill(
              child: NativeTabBar(
                active: settings.section,
                onSelect: _select,
                badges: _badges,
              ),
            )
          else if (UiKit.of(context) == UiKit.shader)
            // The shader kit's own bar: the package's GlassTabBar with
            // per-tab pill widths.
            ShaderTabBar(
              active: settings.section,
              onSelect: _select,
              badges: _badges,
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
  /// the rail calls the same [_select]. The rail is permanent regardless of
  /// which section is active or how deep it's navigated — see
  /// [_desktopSection].
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

  /// Desktop section content, cross-faded on section/theme change. Chat and
  /// Settings render as a two-pane master/detail; Feed and Discover render
  /// full-width in their own single-pane [_SectionPane], which is the part
  /// that matters here — without it, the ~dozen `Navigator.of(context).push`
  /// call sites inside those two sections (games, archive, the daily puzzle,
  /// search, the full people/rooms lists, …) would land on the app's ROOT
  /// navigator and cover the side rail with a bare, phone-shaped page, same as
  /// on compact. [_SectionPane] catches every one of those pushes in a
  /// navigator scoped to the content pane instead, so the rail never moves.
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
      case HomeSection.games:
        // Full-width like Feed: the games, the leaderboard and the bot's
        // matches all push, and those land in the content pane.
        content = _SectionPane(
          sectionKey: 'games',
          child: GamesScreen(repo: widget.repo, feedApi: widget.feedApi),
        );
      case HomeSection.calls:
        // Full-width like Feed; the details sheet and any chat it opens stay
        // inside the content pane.
        content = _SectionPane(
          sectionKey: 'calls',
          child: CallsScreen(
          directory: RepoCallsDirectory(widget.repo, widget.api),
          api: widget.api,
        ),
        );
      case HomeSection.feed:
        content = _SectionPane(
          sectionKey: 'feed',
          child: FeedScreen(
            repo: widget.repo,
            api: widget.api,
            feedApi: widget.feedApi,
            auth: widget.auth,
            family: widget.family,
          ),
        );
      case HomeSection.settings:
        content = _SettingsTwoPane(
          repo: widget.repo,
          api: widget.api,
          auth: widget.auth,
          family: widget.family,
        );
    }
    return SectionSwitcher(
      section: settings.section,
      variant: 'desktop_${theme.id}',
      keepAlive: NativeControl.readyIn(context),
      child: content,
    );
  }
}

/// Desktop chat: the room list on the left (drag the divider to resize it, see
/// [ListDetailSplit]) and the selected room (or an empty hint) on the right,
/// with room info opening in a third pane beside it (see [RoomSidePane]). Room selection lives in [UiSelectionStore];
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
    return ListDetailSplit(
      resizable: true,
      // The list listens to the selection itself (for its highlight), so only
      // the detail side rebuilds when a room is picked.
      master: RepaintBoundary(
        child: chat.HomeScreen(
          repo: repo,
          api: api,
          auth: auth,
          family: family,
        ),
      ),
      detail: AnimatedBuilder(
        animation: selection,
        builder: (context, _) {
          final roomId = selection.roomId;
          // No PopScope here: back from an open chat is the room's to handle,
          // since it has modes to unwind first. See [RoomScreen.inShellPane].
          return RoomSidePane(
            roomId: roomId,
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
                        inShellPane: true,
                      ),
              ),
            ),
          );
        },
      ),
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

/// Gives a full-width desktop section (Feed, Discover) its own [Navigator], so
/// that section's internal pushes stay confined to the content pane instead of
/// reaching the app's root navigator and covering [_SideRail].
///
/// Unlike [_SettingsTwoPane]'s detail pane, there's no separate master list to
/// keep on screen underneath — [child] (the section's own screen, e.g.
/// [FeedScreen]) IS the base route, and every further push it or a descendant
/// makes (games, archive, the daily puzzle, search, a full people/rooms list,
/// …) layers on top of it inside this same navigator, unmodified: they already
/// just call `Navigator.of(context).push`, which resolves to the nearest
/// ancestor — this one — rather than the root.
///
/// [sectionKey] only has to be stable per section; [SectionSwitcher]'s own key
/// already tears the whole pane down (dropping any pushed routes) on a section
/// or theme change, matching how these screens already behave on compact.
class _SectionPane extends StatelessWidget {
  const _SectionPane({required this.sectionKey, required this.child});

  final String sectionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: ValueKey('section_pane_$sectionKey'),
      observers: [RouteDepthObserver()],
      onGenerateInitialRoutes: (navigator, initialRoute) => [
        MaterialPageRoute(builder: (_) => child),
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
    // Same row as chat's, minus the drag handle: the settings list is a menu
    // of fixed labels with nothing to gain from width.
    return ListDetailSplit(
      master: RepaintBoundary(
        child: SettingsScreen(
          repo: repo,
          api: api,
          auth: auth,
          family: family,
        ),
      ),
      detail: const _SettingsDetailPane(),
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
  final _depth = RouteDepthObserver();

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
      observers: [_observer, _depth],
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
          enabled: UiKit.of(context).blurs,
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              color: UiKit.of(context).blurs
                  ? theme.surface.withValues(alpha: 0.72)
                  : theme.surface,
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
                for (final d in navDestinations(
                  AppLocalizations.of(context),
                )) ...[
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
                ? quietFill(theme)
                : Colors.transparent,
            // Same shape as the bottom pill's indicator, so the two chromes
            // agree — the point of stacking the pill was to make compact and
            // expanded read as one design.
            shape: StadiumBorder(
              side: BorderSide(
                color: Colors.transparent,
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
                        child: NavTabBadge(section: s, count: badge),
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
