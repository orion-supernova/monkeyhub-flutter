import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../models/chat_user.dart';
import '../push/push_manager.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'chat_style_screen.dart';
import 'navigation_screen.dart';
import 'profile_screen.dart';
import 'room_layout_screen.dart';
import 'theme_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repo, required this.api, required this.auth});
  final ChatRepository repo;
  final ChatApi api;
  final AuthService auth;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _onSettings() {
    if (mounted) setState(() {});
  }

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

  String get _layoutLabel =>
      SettingsStore.instance.roomLayout == RoomLayout.list ? 'Scroll list' : 'Grid sheet';

  String get _navLabel =>
      SettingsStore.instance.navStyle == NavStyle.radial ? 'Radial orb' : 'Bottom pill';

  String get _chatStyleLabel =>
      SettingsStore.instance.chatStyle == ChatStyle.classic ? 'Classic' : 'Compact';

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
                theme.brandMark(size: 30),
                const SizedBox(width: 10),
                Text('SETTINGS', style: theme.label.copyWith(letterSpacing: 3)),
              ]),
              const SizedBox(height: 28),
              Text('look. feel. you.', style: theme.displayLarge),
              const SizedBox(height: 28),
              if (s != null)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      user: ChatUser(id: s.userId, username: s.username, name: s.name),
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
                        UserAvatar(
                          user: ChatUser(id: s.userId, username: s.username, name: s.name),
                          size: 48,
                          api: widget.api,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: theme.displaySmall),
                              Text('@${s.username}', style: theme.mono.copyWith(color: theme.inkMuted)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 18, color: theme.inkMuted),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

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

              const SizedBox(height: 28),
              _section(theme, 'NOTIFICATIONS'),
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

  Widget _section(AppTheme theme, String t) => Row(children: [
        Text(t, style: theme.label),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: theme.divider)),
      ]);
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
    setState(() => _stamp = 'MonkeyHub · v${info.version}+${info.buildNumber}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Text(_stamp ?? 'MonkeyHub', style: theme.monoTiny);
  }
}
