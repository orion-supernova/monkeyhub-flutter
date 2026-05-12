import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repo, required this.api, required this.auth});
  final ChatRepository repo;
  final ChatApi api;
  final AuthService auth;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _confirmDelete = false;

  void _onSettings() { if (mounted) setState(() {}); }

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

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      await widget.auth.signOut();
      await widget.repo.detach();
      if (!mounted) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(auth: widget.auth)),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      await widget.auth.deleteAccount();
      await widget.repo.detach();
      if (!mounted) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(auth: widget.auth)),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
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
              Text('look. feel. you.', style: theme.displayHero),
              const SizedBox(height: 28),

              if (s != null)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      user: ChatUser(id: s.userId, username: s.username, name: s.name),
                      repo: widget.repo,
                      api: widget.api,
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
                        Text('EDIT ↗', style: theme.monoTiny.copyWith(color: theme.accent)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 28),
              _section(theme, 'THEME · 8'),
              const SizedBox(height: 12),
              _ThemePicker(),

              const SizedBox(height: 28),
              _section(theme, 'ROOM LAYOUT'),
              const SizedBox(height: 12),
              _SegmentRow<RoomLayout>(
                options: const [
                  _SegOption(value: RoomLayout.list, label: 'SCROLL LIST', sub: 'one column, full bleed'),
                  _SegOption(value: RoomLayout.grid, label: 'GRID SHEET', sub: 'two columns, compact'),
                ],
                value: SettingsStore.instance.roomLayout,
                onChanged: SettingsStore.instance.setRoomLayout,
              ),

              const SizedBox(height: 28),
              _section(theme, 'NAVIGATION'),
              const SizedBox(height: 12),
              _SegmentRow<NavStyle>(
                options: const [
                  _SegOption(value: NavStyle.radial, label: 'RADIAL ORB', sub: 'hold + drag to select'),
                  _SegOption(value: NavStyle.pill, label: 'BOTTOM PILL', sub: 'classic tap'),
                ],
                value: SettingsStore.instance.navStyle,
                onChanged: SettingsStore.instance.setNavStyle,
              ),

              const SizedBox(height: 32),
              _section(theme, 'ACCOUNT'),
              const SizedBox(height: 10),
              _RowAction(label: 'SIGN OUT', danger: false, busy: _busy, onTap: _signOut),
              const SizedBox(height: 8),
              _RowAction(
                label: _confirmDelete ? 'TAP AGAIN TO CONFIRM DELETE' : 'DELETE ACCOUNT',
                danger: true,
                busy: _busy,
                onTap: () {
                  if (!_confirmDelete) {
                    setState(() => _confirmDelete = true);
                    Future.delayed(const Duration(seconds: 4), () {
                      if (mounted) setState(() => _confirmDelete = false);
                    });
                  } else {
                    _delete();
                  }
                },
              ),

              const SizedBox(height: 32),
              Text('MonkeyHub · v1.3.7+1', style: theme.monoTiny),
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

class _ThemePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final controller = ThemeScope.controllerOf(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final t in ThemeController.all)
          _ThemeTile(
            theme: t,
            active: t.id == theme.id,
            onTap: () {
              controller.theme = t;
              SettingsStore.instance.setThemeId(t.id);
            },
          ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.theme, required this.active, required this.onTap});
  final AppTheme theme;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final outer = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: outer.surface,
          borderRadius: BorderRadius.circular(outer.radiusLg),
          border: Border.all(
            color: active ? outer.accent : outer.divider,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: outer.accent.withValues(alpha: 0.30), blurRadius: 18)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3-swatch row using the theme's own swatch
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  for (var i = 0; i < theme.swatch.length; i++)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i == theme.swatch.length - 1 ? 0 : 4),
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.swatch[i],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: outer.divider, width: 0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(theme.name, style: outer.displaySmall.copyWith(fontSize: 16)),
            const SizedBox(height: 2),
            Text(theme.tagline, style: outer.monoTiny),
            if (active) ...[
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(color: outer.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('ACTIVE', style: outer.monoTiny.copyWith(color: outer.accent)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegOption<T> {
  const _SegOption({required this.value, required this.label, required this.sub});
  final T value;
  final String label;
  final String sub;
}

class _SegmentRow<T> extends StatelessWidget {
  const _SegmentRow({required this.options, required this.value, required this.onChanged});
  final List<_SegOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(options[i].value),
              child: AnimatedContainer(
                duration: theme.motionFast,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: options[i].value == value ? theme.surfaceRaised : theme.surfaceSunken,
                  border: Border.all(
                    color: options[i].value == value ? theme.accent : theme.divider,
                    width: options[i].value == value ? 1.4 : 1,
                  ),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(options[i].label, style: theme.label),
                    const SizedBox(height: 4),
                    Text(options[i].sub, style: theme.monoTiny),
                  ],
                ),
              ),
            ),
          ),
          if (i < options.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({required this.label, required this.danger, required this.busy, required this.onTap});
  final String label;
  final bool danger;
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border.all(color: danger ? theme.danger.withValues(alpha: 0.5) : theme.divider),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(danger ? Icons.delete_outline : Icons.logout, size: 16,
                color: danger ? theme.danger : theme.inkSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: theme.label.copyWith(color: danger ? theme.danger : theme.ink)),
            ),
            if (busy) SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent)),
          ],
        ),
      ),
    );
  }
}
