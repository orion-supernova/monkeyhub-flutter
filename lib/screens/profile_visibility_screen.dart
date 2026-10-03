import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart';
import '../widgets/ios_kit.dart';

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
    FieldVisibility? feed,
    FieldVisibility? points,
    FieldVisibility? puzzle,
    FieldVisibility? pointsPast,
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
        feed: feed,
        points: points,
        puzzle: puzzle,
        pointsPast: pointsPast,
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
        feed: feed,
        points: points,
        puzzle: puzzle,
        pointsPast: pointsPast,
      );
    } catch (_) {/* leave optimistic state; user can retry */} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ro = widget.readOnly;
    return IosPage(
      title: l10n.acctRowVisibility,
      subtitle: l10n.pvSubtitle,
      actions: [
        // Every choice saves itself; this is the only sign one is in flight.
        AnimatedOpacity(
          opacity: _saving ? 1 : 0,
          duration: theme.motionFast,
          child: SizedBox(
            width: 18,
            height: 18,
            child: CupertinoActivityIndicator(radius: 9, color: theme.inkMuted),
          ),
        ),
      ],
      slivers: _loading
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CupertinoActivityIndicator(color: theme.inkMuted),
                ),
              ),
            ]
          : readableSlivers(context, [
              if (ro) ...[
                SoftNote(
                  icon: CupertinoIcons.shield_lefthalf_fill,
                  tone: theme.accent,
                  text: '${l10n.pvSupervisedTitle}. '
                      '${l10n.profileVisibilityScreenSupervisedBody}',
                ),
                const SizedBox(height: 24),
              ],
              InsetGroup(
                header: l10n.pvSectionProfile,
                children: [
                  _Row(
                    theme: theme,
                    label: l10n.pvAvatar,
                    desc: l10n.pvAvatarDesc,
                    value: _vis.avatar,
                    onChanged: (v) => _patch(avatar: v),
                    enabled: !ro,
                  ),
                  _Row(
                    theme: theme,
                    label: l10n.pvOnline,
                    desc: l10n.pvOnlineDesc,
                    value: _vis.status,
                    onChanged: (v) => _patch(status: v),
                    enabled: !ro,
                  ),
                  _Row(
                    theme: theme,
                    label: l10n.pvLastSeen,
                    desc: l10n.pvLastSeenDesc,
                    value: _vis.lastSeen,
                    onChanged: (v) => _patch(lastSeen: v),
                    enabled: !ro,
                  ),
                ],
              ),
              InsetGroup(
                header: l10n.pvSectionMessages,
                children: [
                  _Row(
                    theme: theme,
                    label: l10n.pvSendReceipts,
                    desc: l10n.pvSendReceiptsDesc,
                    value: _vis.seen,
                    onChanged: (v) => _patch(seen: v),
                    enabled: !ro,
                  ),
                  _RowBool(
                    theme: theme,
                    label: l10n.pvShowReceipts,
                    desc: l10n.pvShowReceiptsDesc,
                    hint: l10n.pvShowReceiptsHint,
                    value: SettingsStore.instance.viewReadReceipts,
                    onChanged: (v) =>
                        SettingsStore.instance.setViewReadReceipts(v),
                  ),
                ],
              ),
              InsetGroup(
                header: l10n.pvSectionPeople,
                children: [
                  _RowBinary(
                    theme: theme,
                    label: l10n.pvFriendRequests,
                    desc: l10n.pvFriendRequestsDesc,
                    value: _vis.friendRequests,
                    onChanged: (v) => _patch(friendRequests: v),
                    enabled: !ro,
                  ),
                ],
              ),
              InsetGroup(
                header: l10n.pvSectionFeed,
                children: [
                  _RowFeed(
                    theme: theme,
                    label: l10n.pvHighlights,
                    desc: l10n.pvHighlightsDesc,
                    value: _vis.feed,
                    onChanged: (v) => _patch(feed: v),
                    enabled: !ro,
                  ),
                  _RowFeed(
                    theme: theme,
                    label: l10n.pvPoints,
                    desc: l10n.pvPointsDesc,
                    value: _vis.points,
                    onChanged: (v) => _patch(points: v),
                    enabled: !ro,
                  ),
                  _RowFeed(
                    theme: theme,
                    label: l10n.pvPuzzle,
                    desc: l10n.pvPuzzleDesc,
                    value: _vis.puzzle,
                    onChanged: (v) => _patch(puzzle: v),
                    enabled: !ro,
                  ),
                  _RowFeed(
                    theme: theme,
                    label: l10n.pvPast,
                    desc: l10n.pvPastDesc,
                    value: _vis.pointsPast,
                    onChanged: (v) => _patch(pointsPast: v),
                    enabled: !ro,
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    style: theme.body.copyWith(color: theme.danger),
                  ),
                ),
            ]),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.body.copyWith(fontSize: 17, color: theme.ink),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: theme.caption.copyWith(fontSize: 13, color: theme.inkMuted),
          ),
          const SizedBox(height: 10),
          child,
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: theme.caption.copyWith(color: theme.inkMuted),
            ),
          ],
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
          (FieldVisibility.public, AppLocalizations.of(context).pvEveryone),
          (FieldVisibility.friends, AppLocalizations.of(context).pvFriends),
          (FieldVisibility.nobody, AppLocalizations.of(context).pvNobody),
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
          (true, AppLocalizations.of(context).pvOn),
          (false, AppLocalizations.of(context).pvOff),
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
          (FieldVisibility.public, AppLocalizations.of(context).pvAnyone),
          (FieldVisibility.nobody, AppLocalizations.of(context).pvNobody),
        ],
        value: value == FieldVisibility.friends ? FieldVisibility.public : value,
        onChanged: onChanged,
        enabled: enabled,
      ),
    );
  }
}

/// A friends-or-nobody row, for the three Feed keys.
///
/// Distinct from [_RowBinary], which offers ANYONE or nobody. The Feed board
/// fans out over accepted friendships and nothing else, so "anyone" is not an
/// option it could honour — the server refuses to store it — and offering it
/// here would be a control that silently does nothing.
class _RowFeed extends StatelessWidget {
  const _RowFeed({
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
          (FieldVisibility.friends, AppLocalizations.of(context).pvFriends),
          (FieldVisibility.nobody, AppLocalizations.of(context).pvNobody),
        ],
        // A stored "public" from some future client collapses to friends
        // rather than leaving the segment showing neither option selected.
        value: value == FieldVisibility.public ? FieldVisibility.friends : value,
        onChanged: onChanged,
        enabled: enabled,
      ),
    );
  }
}

/// The iOS segmented control: a recessed track and a raised thumb that slides
/// to the chosen option on a spring.
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

  /// False for a supervised child: the control still shows what is set, but
  /// only a grown-up can move it.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    final index = options.indexWhere((o) => o.$1 == value).clamp(0, 99);
    final n = options.length;
    final thumb = theme.isLight
        ? Colors.white
        : Color.alphaBlend(
            Colors.white.withValues(alpha: 0.16),
            groupedFill(theme),
          );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: theme.ink.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: Alignment(n == 1 ? 0 : -1 + index * 2 / (n - 1), 0),
              duration: motion.d(const Duration(milliseconds: 380)),
              curve: Curves.easeOutBack,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: thumb,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final o in options)
                  Expanded(
                    child: GestureDetector(
                      onTap: enabled && o.$1 != value
                          ? () {
                              HapticFeedback.selectionClick();
                              onChanged(o.$1);
                            }
                          : null,
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: theme.motionFast,
                          style: theme.body.copyWith(
                            fontSize: 13,
                            letterSpacing: 0,
                            fontWeight: o.$1 == value
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: o.$1 == value ? theme.ink : theme.inkSoft,
                          ),
                          child: Text(
                            o.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
