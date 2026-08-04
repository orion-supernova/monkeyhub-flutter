import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

/// Visibility & privacy preferences, grouped into PROFILE / MESSAGES / PEOPLE.
///
/// Most fields are tri-state visibility (public / friends / nobody). FRIEND
/// REQUESTS is binary (anyone / nobody). SHOW READ RECEIPTS is a local-only
/// bool living in [SettingsStore] — everything else is server-stored on
/// `users.visibility`.
class ProfileVisibilityScreen extends StatefulWidget {
  const ProfileVisibilityScreen({
    super.key,
    required this.repo,
    required this.api,
    this.readOnly = false,
  });
  final ChatRepository repo;
  final ChatApi api;

  /// Child accounts see their settings but can't change them — these are
  /// guardian-controlled, and `users.updateVisibility` refuses them outright
  /// on the backend. Showing the values honestly beats hiding the screen:
  /// a child should be able to see what their grown-ups can see.
  final bool readOnly;

  @override
  State<ProfileVisibilityScreen> createState() => _ProfileVisibilityScreenState();
}

class _ProfileVisibilityScreenState extends State<ProfileVisibilityScreen> {
  ProfileVisibility _vis = ProfileVisibility();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hydrate();
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

  Future<void> _hydrate() async {
    final me = widget.repo.userId;
    if (me == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final self = await widget.api.getProfile(me, viewerUserId: me);
      if (!mounted) return;
      setState(() {
        _vis = self?.visibility ?? ProfileVisibility();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _patch({
    FieldVisibility? avatar,
    FieldVisibility? status,
    FieldVisibility? lastSeen,
    FieldVisibility? seen,
    FieldVisibility? friendRequests,
  }) async {
    final me = widget.repo.userId;
    if (me == null || widget.readOnly) return;
    setState(() {
      _saving = true;
      _vis = _vis.copyWith(
        avatar: avatar,
        status: status,
        lastSeen: lastSeen,
        seen: seen,
        friendRequests: friendRequests,
      );
    });
    try {
      await widget.api.updateVisibility(
        userId: me,
        avatar: avatar,
        status: status,
        lastSeen: lastSeen,
        seen: seen,
        friendRequests: friendRequests,
      );
    } catch (_) {/* leave optimistic state; user can retry */} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: Column(
              children: [
                _backBar(theme),
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.accent, strokeWidth: 2,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(AppLocalizations.of(context).profileVisibilityScreenTitle,
                                  style: theme.displayMedium),
                              const SizedBox(height: 10),
                              Row(children: [
                                Container(width: 18, height: 1, color: theme.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(context).profileVisibilityScreenSubtitle,
                                    style: theme.caption,
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 24),
                              if (widget.readOnly) ...[
                                _SupervisedNotice(theme: theme),
                                const SizedBox(height: 24),
                              ],
                              const SizedBox(height: 12),

                              // ───── PROFILE ─────
                              _Section(theme: theme, label: AppLocalizations.of(context).profileVisibilityScreenSectionProfile),
                              const SizedBox(height: 22),
                              _Row(
                                theme: theme,
                                label: AppLocalizations.of(context).profileVisibilityScreenAvatarLabel,
                                desc: AppLocalizations.of(context).profileVisibilityScreenAvatarDesc,
                                value: _vis.avatar,
                                onChanged: (v) => _patch(avatar: v),
                                enabled: !widget.readOnly,
                              ),
                              const SizedBox(height: 26),
                              _Row(
                                theme: theme,
                                label: AppLocalizations.of(context).profileVisibilityScreenOnlineAwayLabel,
                                desc: AppLocalizations.of(context).profileVisibilityScreenOnlineAwayDesc,
                                value: _vis.status,
                                onChanged: (v) => _patch(status: v),
                                enabled: !widget.readOnly,
                              ),
                              const SizedBox(height: 26),
                              _Row(
                                theme: theme,
                                label: AppLocalizations.of(context).profileVisibilityScreenLastSeenLabel,
                                desc: AppLocalizations.of(context).profileVisibilityScreenLastSeenDesc,
                                value: _vis.lastSeen,
                                onChanged: (v) => _patch(lastSeen: v),
                                enabled: !widget.readOnly,
                              ),
                              const SizedBox(height: 40),

                              // ───── MESSAGES ─────
                              _Section(theme: theme, label: AppLocalizations.of(context).profileVisibilityScreenSectionMessages),
                              const SizedBox(height: 22),
                              _Row(
                                theme: theme,
                                label: AppLocalizations.of(context).profileVisibilityScreenSendReadReceiptsLabel,
                                desc: AppLocalizations.of(context).profileVisibilityScreenSendReadReceiptsDesc,
                                value: _vis.seen,
                                onChanged: (v) => _patch(seen: v),
                                enabled: !widget.readOnly,
                              ),
                              const SizedBox(height: 26),
                              _RowBool(
                                theme: theme,
                                label: AppLocalizations.of(context).profileVisibilityScreenShowReadReceiptsLabel,
                                desc: AppLocalizations.of(context).profileVisibilityScreenShowReadReceiptsDesc,
                                hint: AppLocalizations.of(context).profileVisibilityScreenShowReadReceiptsHint,
                                value: SettingsStore.instance.viewReadReceipts,
                                onChanged: (v) =>
                                    SettingsStore.instance.setViewReadReceipts(v),
                              ),
                              const SizedBox(height: 40),

                              // ───── PEOPLE ─────
                              _Section(theme: theme, label: AppLocalizations.of(context).profileVisibilityScreenSectionPeople),
                              const SizedBox(height: 22),
                              _RowBinary(
                                theme: theme,
                                label: AppLocalizations.of(context).profileVisibilityScreenFriendRequestsLabel,
                                desc: AppLocalizations.of(context).profileVisibilityScreenFriendRequestsDesc,
                                value: _vis.friendRequests,
                                onChanged: (v) => _patch(friendRequests: v),
                                enabled: !widget.readOnly,
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 24),
                                Text(_error!,
                                    style: theme.body.copyWith(color: theme.danger)),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
            ),
          ),
          if (_saving)
            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              right: 20,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _backBar(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.theme, required this.label});
  final AppTheme theme;
  final String label;

  @override
  Widget build(BuildContext context) {
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
          style: theme.label.copyWith(
            letterSpacing: 2.8,
            color: theme.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: theme.divider)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.theme,
    required this.label,
    required this.desc,
    required this.child,
    this.hint,
  });
  final AppTheme theme;
  final String label;
  final String desc;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.label.copyWith(letterSpacing: 1.8)),
        const SizedBox(height: 3),
        Text(desc, style: theme.monoTiny),
        const SizedBox(height: 10),
        child,
        if (hint != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 12, color: theme.inkMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(hint!, style: theme.monoTiny)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Shown at the top of this screen for a child: their visibility isn't
/// theirs to set, and their grown-ups can see everything regardless. Better
/// to say that plainly than to let them wonder why nothing moves.
class _SupervisedNotice extends StatelessWidget {
  const _SupervisedNotice({required this.theme});
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.accentSoft,
        border: Border.all(color: theme.accent.withValues(alpha: 0.35)),
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
                Text(AppLocalizations.of(context).profileVisibilityScreenSupervisedTitle,
                    style: theme.label.copyWith(color: theme.accent)),
                const SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).profileVisibilityScreenSupervisedBody,
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

class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final AppTheme theme;
  final String label;
  final String desc;
  final FieldVisibility value;
  final ValueChanged<FieldVisibility> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _Field(
      theme: theme,
      label: label,
      desc: desc,
      child: _Seg<FieldVisibility>(
        theme: theme,
        options: [
          (FieldVisibility.public, AppLocalizations.of(context).profileVisibilityScreenOptionPublic),
          (FieldVisibility.friends, AppLocalizations.of(context).profileVisibilityScreenOptionFriends),
          (FieldVisibility.nobody, AppLocalizations.of(context).profileVisibilityScreenOptionNobody),
        ],
        value: value,
        onChanged: onChanged,
        enabled: enabled,
      ),
    );
  }
}

class _RowBool extends StatelessWidget {
  const _RowBool({
    required this.theme,
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
    this.hint,
  });
  final AppTheme theme;
  final String label;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return _Field(
      theme: theme,
      label: label,
      desc: desc,
      hint: hint,
      child: _Seg<bool>(
        theme: theme,
        options: [
          (true, AppLocalizations.of(context).profileVisibilityScreenOptionOn),
          (false, AppLocalizations.of(context).profileVisibilityScreenOptionOff),
        ],
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _RowBinary extends StatelessWidget {
  const _RowBinary({
    required this.theme,
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final AppTheme theme;
  final String label;
  final String desc;
  final FieldVisibility value;
  final ValueChanged<FieldVisibility> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _Field(
      theme: theme,
      label: label,
      desc: desc,
      child: _Seg<FieldVisibility>(
        theme: theme,
        options: [
          (FieldVisibility.public, AppLocalizations.of(context).profileVisibilityScreenOptionAnyone),
          (FieldVisibility.nobody, AppLocalizations.of(context).profileVisibilityScreenOptionNobody),
        ],
        value: value == FieldVisibility.friends ? FieldVisibility.public : value,
        onChanged: onChanged,
        enabled: enabled,
      ),
    );
  }
}

class _Seg<T> extends StatelessWidget {
  const _Seg({
    required this.theme,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final AppTheme theme;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// When false the control still shows the current value but ignores taps —
  /// used for a child, whose visibility is guardian-controlled.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: enabled ? () => onChanged(o.$1) : null,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: theme.motionFast,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == o.$1 ? theme.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(theme.radiusMd - 2),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: theme.motionFast,
                    curve: Curves.easeOutCubic,
                    style: theme.label.copyWith(
                      color: value == o.$1 ? theme.accentInk : theme.inkSoft,
                      letterSpacing: 1.6,
                    ),
                    child: Text(o.$2),
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}
