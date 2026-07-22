import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../family/family_service.dart';
import '../models/chat_user.dart';
import '../push/push_manager.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_brand_mark.dart';
import '../widgets/monkey_collection.dart';
import '../widgets/user_avatar.dart';
import 'approvals_screen.dart';
import 'chat_style_screen.dart';
import 'family_screen.dart';
import 'reply_style_screen.dart';
import 'logo_screen.dart';
import 'navigation_screen.dart';
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
    // The approvals badge should be right whenever this screen is opened.
    widget.family.refresh();
    _loadMe();
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    widget.family.removeListener(_onSettings);
    super.dispose();
  }

  Future<void> _loadMe() async {
    final s = widget.auth.session;
    if (s == null) return;
    try {
      final fresh = await widget.api.getProfile(s.userId, viewerUserId: s.userId);
      if (!mounted || fresh == null) return;
      setState(() => _me = fresh);
    } catch (_) {/* keep the bootstrap ChatUser; avatar stays generic */}
  }

  String get _familyLabel {
    final n = widget.family.context.children.length;
    if (n == 0) return 'add a child';
    return n == 1 ? '1 child' : '$n children';
  }

  String get _layoutLabel =>
      SettingsStore.instance.roomLayout == RoomLayout.list ? 'Scroll list' : 'Grid sheet';

  String get _navLabel =>
      SettingsStore.instance.navStyle == NavStyle.radial ? 'Radial orb' : 'Bottom pill';

  String get _chatStyleLabel =>
      SettingsStore.instance.chatStyle == ChatStyle.classic ? 'Classic' : 'Compact';

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
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
            children: [
              Row(children: [
                const AppBrandMark(size: 30),
                const SizedBox(width: 10),
                Text('SETTINGS', style: theme.label.copyWith(letterSpacing: 3)),
              ]),
              const SizedBox(height: 28),
              Text('look. feel. you.', style: theme.displayLarge),
              const SizedBox(height: 28),
              if (s != null) ...[
                () {
                  final me = _me ??
                      ChatUser(id: s.userId, username: s.username, name: s.name);
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        user: me,
                        repo: widget.repo,
                        api: widget.api,
                        auth: widget.auth,
                      ),
                    )),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: theme.roomCardDecoration(ephemeral: false, active: false),
                      child: Row(
                        children: [
                          UserAvatar(user: me, size: 48, api: widget.api),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(me.displayName, style: theme.displaySmall),
                                Text('@${me.username}',
                                    style: theme.mono.copyWith(color: theme.inkMuted)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: theme.inkMuted),
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
                leading: _SwatchDot(color: activeTheme.accent),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ThemeScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'APP LOGO',
                value: _logoLabel,
                leading: Icon(Icons.workspaces_outline, size: 16, color: theme.inkSoft),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LogoScreen()),
                ),
              ),

              const SizedBox(height: 28),
              _SectionHeader(label: 'LAYOUT'),
              const SizedBox(height: 12),
              _DisclosureRow(
                label: 'ROOM LAYOUT',
                value: _layoutLabel,
                leading: Icon(Icons.dashboard_outlined, size: 16, color: theme.inkSoft),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RoomLayoutScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'NAVIGATION',
                value: _navLabel,
                leading: Icon(Icons.swap_horiz, size: 16, color: theme.inkSoft),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NavigationScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'CHAT STYLE',
                value: _chatStyleLabel,
                leading: Icon(Icons.bubble_chart_outlined, size: 16, color: theme.inkSoft),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatStyleScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _DisclosureRow(
                label: 'REPLY STYLE',
                value: _replyStyleLabel,
                leading: Icon(Icons.reply_outlined, size: 16, color: theme.inkSoft),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReplyStyleScreen(api: widget.api),
                  ),
                ),
              ),

              const SizedBox(height: 28),
              _SectionHeader(label: 'FAMILY'),
              const SizedBox(height: 12),
              if (widget.family.isChild)
                _GuardiansRow(family: widget.family)
              else ...[
                _DisclosureRow(
                  label: 'FAMILY',
                  value: _familyLabel,
                  leading: Icon(Icons.family_restroom,
                      size: 16, color: theme.inkSoft),
                  onTap: () {
                    final s = widget.auth.session;
                    if (s == null) return;
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FamilyScreen(
                        api: widget.api,
                        userId: s.userId,
                        family: widget.family,
                      ),
                    ));
                  },
                ),
                if (widget.family.context.children.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DisclosureRow(
                    label: 'APPROVALS',
                    value: widget.family.pendingCount == 0
                        ? 'nothing waiting'
                        : '${widget.family.pendingCount} waiting',
                    leading: Icon(
                      Icons.pending_actions,
                      size: 16,
                      color: widget.family.pendingCount > 0
                          ? theme.accent
                          : theme.inkSoft,
                    ),
                    onTap: () {
                      final s = widget.auth.session;
                      if (s == null) return;
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ApprovalsScreen(
                          api: widget.api,
                          guardianId: s.userId,
                          family: widget.family,
                        ),
                      ));
                    },
                  ),
                ],
              ],

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
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border.all(color: theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
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

/// The child's side of the FAMILY section: who looks after them, stated
/// plainly. Read-only — there's nothing here for them to change, and
/// pretending otherwise would be worse than saying so.
class _GuardiansRow extends StatelessWidget {
  const _GuardiansRow({required this.family});
  final FamilyService family;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final guardians = family.context.guardians;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: theme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MY GROWN-UPS', style: theme.label),
                const SizedBox(height: 4),
                Text(
                  guardians.isEmpty
                      ? 'nobody looking after this account yet'
                      : guardians.map((g) => g.displayName).join(' · '),
                  style: theme.body.copyWith(color: theme.inkSoft),
                ),
                const SizedBox(height: 6),
                Text(
                  'They can see when you\'re online and who you talk to.',
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
                  on ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
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
