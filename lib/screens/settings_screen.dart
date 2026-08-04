import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../data/ui_selection_store.dart';
import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../push/push_manager.dart';
import '../theme/bubble_shape.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_brand_mark.dart';
import '../widgets/count_badge.dart';
import '../widgets/monkey_collection.dart';
import '../widgets/recovery_banner.dart';
import '../widgets/user_avatar.dart';
import 'bubble_style_screen.dart';
import 'chat_style_screen.dart';
import 'glass_screen.dart';
import 'language_screen.dart';
import 'reply_style_screen.dart';
import 'logo_screen.dart';
import 'navigation_screen.dart';
import 'navigation/destinations.dart';
import 'navigation/open_room.dart';
import 'profile_screen.dart';
import 'room_layout_screen.dart';
import 'theme_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ChatUser? _me;

  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    SettingsStore.instance.addListener(_onSettings);
    widget.family.addListener(_onSettings);
    // Rebuild when the desktop settings pane's selection changes so the active
    // row highlights.
    UiSelectionStore.instance.addListener(_onSettings);
    // The approvals badge should be right whenever this screen is opened.
    widget.family.refresh();
    _loadMe();
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    widget.family.removeListener(_onSettings);
    UiSelectionStore.instance.removeListener(_onSettings);
    super.dispose();
  }

  /// True when [key]'s sub-screen is the one shown in the desktop detail pane.
  bool _isOpen(String key) =>
      context.isExpanded && UiSelectionStore.instance.settingsDetailKey == key;

  Future<void> _loadMe() async {
    final s = widget.auth.session;
    if (s == null) return;
    try {
      final fresh = await widget.api.getProfile(
        s.userId,
        viewerUserId: s.userId,
      );
      if (!mounted || fresh == null) return;
      setState(() => _me = fresh);
    } catch (_) {
      /* keep the bootstrap ChatUser; avatar stays generic */
    }
  }

  /// The breadcrumb under the avatar card. A child's account has no family
  /// controls to offer and nothing to link, so it gets the things that are
  /// actually behind the card for them.
  String get _accountHint => widget.auth.isChild
      ? 'profile · privacy · my grown-ups'
      : 'profile · family · linked accounts · privacy';

  String get _layoutLabel =>
      SettingsStore.instance.roomLayout == RoomLayout.list
      ? 'Scroll list'
      : 'Grid sheet';

  String get _navLabel => SettingsStore.instance.navStyle == NavStyle.radial
      ? 'Radial orb'
      : 'Bottom pill';

  /// The active look's name, marked when it has been tuned away from what it
  /// saved. 'Custom' only when nothing is selected at all.
  String get _glassLabel {
    final store = SettingsStore.instance;
    final id = store.glassPresetId;
    if (id == null) return 'Custom';
    for (final p in store.glassPresets) {
      if (p.id == id) {
        return store.glass == p.profile ? p.name : '${p.name} · edited';
      }
    }
    return 'Custom';
  }

  String get _chatStyleLabel =>
      SettingsStore.instance.chatStyle == ChatStyle.classic
      ? 'Classic'
      : 'Compact';

  String get _languageLabel {
    final l10n = AppLocalizations.of(context);
    switch (SettingsStore.instance.localeCode) {
      case 'en':
        return l10n.languageValueEnglish;
      case 'tr':
        return l10n.languageValueTurkish;
      default:
        return l10n.languageValueSystem;
    }
  }

  String get _bubbleStyleLabel {
    switch (SettingsStore.instance.bubbleStyle) {
      case BubbleStyle.tailed:
        return 'Tailed';
      case BubbleStyle.soft:
        return 'Soft';
      case BubbleStyle.pill:
        return 'Pill';
      case BubbleStyle.slab:
        return 'Slab';
    }
  }

  String get _replyStyleLabel {
    switch (SettingsStore.instance.replyStyle) {
      case ReplyStyle.phantomEcho:
        return 'Phantom Echo';
      case ReplyStyle.stickyNote:
        return 'Sticky Note';
      case ReplyStyle.comicTail:
        return 'Comic Tail';
      case ReplyStyle.classic:
        return 'Classic';
    }
  }

  String get _logoLabel {
    final s = SettingsStore.instance;
    switch (s.logoMode) {
      case LogoMode.auto:
        return 'Auto';
      case LogoMode.alwaysDefault:
        return 'MonkeyHub';
      case LogoMode.manual:
        final id = s.manualLogoThemeId;
        if (id == null) return 'Manual';
        if (id == canonicalLogoId) return 'MonkeyHub';
        final monkey = monkeyVariantById(id);
        if (monkey != null) return monkey.displayName;
        return ThemeController.byId(id).name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final activeTheme = ThemeScope.of(context);
    final s = widget.auth.session;
    return Stack(
      children: [
        theme.backgroundLayer(context),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              28,
              20,
              kFloatingNavClearance,
            ),
            children: [
              Row(
                children: [
                  const AppBrandMark(size: 30),
                  const SizedBox(width: 10),
                  Text(
                    'SETTINGS',
                    style: theme.label.copyWith(letterSpacing: 3),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text('look. feel. you.', style: theme.displayLarge),
              const SizedBox(height: 28),
              if (s != null) ...[
                // An account with no recovery phrase is one forgotten password
                // away from being gone. Shown here because Settings is the
                // screen people actually open — profile carries the same
                // banner. `_loadMe()` already fetches with viewerUserId ==
                // userId, so hasRecoveryKey arrives with no extra query.
                //
                // Explicitly `== false`: null means "unknown" (older backend,
                // or not a self-fetch) and must not be read as "none set".
                // The isChild check is belt-and-braces — the server already
                // returns null for children, who have no reset path at all.
                if (_me?.hasRecoveryKey == false && !widget.auth.isChild) ...[
                  RecoveryPhraseBanner(
                    onTap: () => openSettingsDetail(
                      context,
                      key: 'profile',
                      builder: (_) => ProfileScreen(
                        user: _me!,
                        repo: widget.repo,
                        api: widget.api,
                        auth: widget.auth,
                        family: widget.family,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                () {
                  final me =
                      _me ??
                      ChatUser(
                        id: s.userId,
                        username: s.username,
                        name: s.name,
                      );
                  return GestureDetector(
                    onTap: () => openSettingsDetail(
                      context,
                      key: 'profile',
                      builder: (_) => ProfileScreen(
                        user: me,
                        repo: widget.repo,
                        api: widget.api,
                        auth: widget.auth,
                        family: widget.family,
                      ),
                    ),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: theme.roomCardDecoration(
                        ephemeral: false,
                        active: _isOpen('profile'),
                      ),
                      child: Row(
                        children: [
                          UserAvatar(user: me, size: 48, api: widget.api),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(me.displayName, style: theme.displaySmall),
                                Text(
                                  '@${me.username}',
                                  style: theme.mono.copyWith(
                                    color: theme.inkMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Says where the account settings went, now
                                // that family is one of them.
                                Text(
                                  _accountHint,
                                  style: theme.monoTiny.copyWith(
                                    color: theme.inkMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Approvals used to badge their own top-level row.
                          // That row now lives inside the account screen, so
                          // the count rides the way in — otherwise a guardian
                          // would have to go looking to find out anything was
                          // waiting.
                          if (widget.family.pendingCount > 0) ...[
                            CountBadge(count: widget.family.pendingCount),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: theme.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  );
                }(),
              ],
              const SizedBox(height: 24),

              _SectionHeader(label: 'APPEARANCE'),
              const SizedBox(height: 12),
              _DisclosureRow(
                label: 'THEME',
                value: activeTheme.name,
                selected: _isOpen('theme'),
                leading: _SwatchDot(color: activeTheme.accent),
                onTap: () => openSettingsDetail(
                  context,
                  key: 'theme',
                  builder: (_) => const ThemeScreen(),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'APP LOGO',
                value: _logoLabel,
                selected: _isOpen('logo'),
                leading: Icon(
                  Icons.workspaces_outline,
                  size: 16,
                  color: theme.inkSoft,
                ),
                onTap: () => openSettingsDetail(
                  context,
                  key: 'logo',
                  builder: (_) => const LogoScreen(),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'GLASS',
                value: _glassLabel,
                selected: _isOpen('glass'),
                leading: Icon(
                  Icons.blur_on_outlined,
                  size: 16,
                  color: theme.inkSoft,
                ),
                onTap: () => openSettingsDetail(
                  context,
                  key: 'glass',
                  builder: (_) => const GlassScreen(),
                ),
              ),

              const SizedBox(height: 28),
              _SectionHeader(label: 'LAYOUT'),
              const SizedBox(height: 12),
              _DisclosureRow(
                label: 'CHAT LIST',
                value: _layoutLabel,
                selected: _isOpen('roomLayout'),
                leading: Icon(
                  Icons.dashboard_outlined,
                  size: 16,
                  color: theme.inkSoft,
                ),
                onTap: () => openSettingsDetail(
                  context,
                  key: 'roomLayout',
                  builder: (_) => const RoomLayoutScreen(),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'NAVIGATION',
                value: _navLabel,
                selected: _isOpen('navigation'),
                leading: Icon(Icons.swap_horiz, size: 16, color: theme.inkSoft),
                onTap: () => openSettingsDetail(
                  context,
                  key: 'navigation',
                  builder: (_) => const NavigationScreen(),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'CHAT STYLE',
                value: _chatStyleLabel,
                selected: _isOpen('chatStyle'),
                leading: Icon(
                  Icons.bubble_chart_outlined,
                  size: 16,
                  color: theme.inkSoft,
                ),
                onTap: () => openSettingsDetail(
                  context,
                  key: 'chatStyle',
                  builder: (_) => const ChatStyleScreen(),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'BUBBLE STYLE',
                value: _bubbleStyleLabel,
                selected: _isOpen('bubbleStyle'),
                leading: Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: theme.inkSoft,
                ),
                onTap: () => openSettingsDetail(
                  context,
                  key: 'bubbleStyle',
                  builder: (_) => const BubbleStyleScreen(),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'REPLY STYLE',
                value: _replyStyleLabel,
                selected: _isOpen('replyStyle'),
                leading: Icon(
                  Icons.reply_outlined,
                  size: 16,
                  color: theme.inkSoft,
                ),
                onTap: () => openSettingsDetail(
                  context,
                  key: 'replyStyle',
                  builder: (_) => ReplyStyleScreen(api: widget.api),
                ),
              ),

              const SizedBox(height: 28),
              _SectionHeader(label: 'GENERAL'),
              const SizedBox(height: 12),
              _DisclosureRow(
                label: AppLocalizations.of(context).settingsLanguageRowLabel,
                value: _languageLabel,
                selected: _isOpen('language'),
                leading: Icon(
                  Icons.language_outlined,
                  size: 16,
                  color: theme.inkSoft,
                ),
                onTap: () => openSettingsDetail(
                  context,
                  key: 'language',
                  builder: (_) => const LanguageScreen(),
                ),
              ),

              const SizedBox(height: 28),
              _SectionHeader(label: 'LINKS'),
              const SizedBox(height: 12),
              _ShowLinkUrlsToggle(),

              const SizedBox(height: 28),
              _SectionHeader(label: 'NOTIFICATIONS'),
              const SizedBox(height: 12),
              _PushToggle(),

              const SizedBox(height: 36),
              _VersionStamp(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.label.copyWith(letterSpacing: 2.8, color: theme.accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: theme.divider)),
      ],
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.selected = false,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;

  /// Whether this row's sub-screen is currently open in the desktop detail
  /// pane. Renders an accent-tinted surface so the two-pane selection is clear.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected
              ? theme.accent.withValues(alpha: 0.14)
              : theme.surface,
          border: Border.all(
            color: selected
                ? theme.accent.withValues(alpha: 0.4)
                : theme.divider,
          ),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            SizedBox(width: 110, child: Text(label, style: theme.label)),
            Expanded(
              child: Text(
                value,
                style: theme.body.copyWith(color: theme.inkSoft),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: theme.divider, width: 0.5),
      ),
    );
  }
}

class _PushToggle extends StatefulWidget {
  @override
  State<_PushToggle> createState() => _PushToggleState();
}

class _PushToggleState extends State<_PushToggle> {
  Future<void> _toggle(bool v) async {
    await SettingsStore.instance.setPushEnabled(v);
    if (v) {
      await PushManager.instance.optIn();
    } else {
      await PushManager.instance.optOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final on = SettingsStore.instance.pushEnabled;
        return GestureDetector(
          onTap: () => _toggle(!on),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border.all(color: theme.divider),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  on
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  size: 16,
                  color: on ? theme.accent : theme.inkMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PUSH NOTIFICATIONS', style: theme.label),
                      const SizedBox(height: 2),
                      Text(
                        on
                            ? 'pings for new messages + requests'
                            : 'silent — you\'ll only see things when you open the app',
                        style: theme.bodySoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: on,
                  onChanged: _toggle,
                  activeThumbColor: theme.accent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShowLinkUrlsToggle extends StatelessWidget {
  Future<void> _toggle(bool v) => SettingsStore.instance.setShowLinkUrls(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final on = SettingsStore.instance.showLinkUrls;
        return GestureDetector(
          onTap: () => _toggle(!on),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border.all(color: theme.divider),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  on ? Icons.link_rounded : Icons.link_off_rounded,
                  size: 16,
                  color: on ? theme.accent : theme.inkMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SHOW LINK URLS', style: theme.label),
                      const SizedBox(height: 2),
                      Text(
                        on
                            ? 'raw URLs appear alongside the preview card'
                            : 'preview only — cleaner bubbles, tap to open',
                        style: theme.bodySoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: on,
                  onChanged: _toggle,
                  activeThumbColor: theme.accent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VersionStamp extends StatefulWidget {
  @override
  State<_VersionStamp> createState() => _VersionStampState();
}

class _VersionStampState extends State<_VersionStamp> {
  String? _stamp;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _stamp = 'MonkeyHub · v${info.version}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Text(_stamp ?? 'MonkeyHub', style: theme.monoTiny);
  }
}
