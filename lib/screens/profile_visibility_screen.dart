import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';

/// Per-field profile visibility editor.
///
/// Each field can be set to public / friends / nobody. friendRequests is
/// special — it's a binary public / nobody (since "friends" doesn't make
/// sense for "who can send me requests").
class ProfileVisibilityScreen extends StatefulWidget {
  const ProfileVisibilityScreen({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;

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
    FieldVisibility? bio,
    FieldVisibility? avatar,
    FieldVisibility? status,
    FieldVisibility? lastSeen,
    FieldVisibility? friendRequests,
  }) async {
    final me = widget.repo.userId;
    if (me == null) return;
    // Optimistic update.
    setState(() {
      _saving = true;
      _vis = _vis.copyWith(
        bio: bio,
        avatar: avatar,
        status: status,
        lastSeen: lastSeen,
        friendRequests: friendRequests,
      );
    });
    try {
      await widget.api.updateVisibility(
        userId: me,
        bio: bio,
        avatar: avatar,
        status: status,
        lastSeen: lastSeen,
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
            child: Column(
              children: [
                _header(theme),
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.accent, strokeWidth: 2,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('control what other people see.',
                                  style: theme.bodySoft),
                              const SizedBox(height: 22),
                              _Row(
                                theme: theme,
                                label: 'AVATAR',
                                desc: 'your profile picture',
                                value: _vis.avatar,
                                onChanged: (v) => _patch(avatar: v),
                              ),
                              const SizedBox(height: 16),
                              _Row(
                                theme: theme,
                                label: 'BIO',
                                desc: 'the text on your profile',
                                value: _vis.bio,
                                onChanged: (v) => _patch(bio: v),
                              ),
                              const SizedBox(height: 16),
                              _Row(
                                theme: theme,
                                label: 'ONLINE / AWAY',
                                desc: 'whether you appear active right now',
                                value: _vis.status,
                                onChanged: (v) => _patch(status: v),
                              ),
                              const SizedBox(height: 16),
                              _Row(
                                theme: theme,
                                label: 'LAST SEEN',
                                desc: 'the time you were last around',
                                value: _vis.lastSeen,
                                onChanged: (v) => _patch(lastSeen: v),
                              ),
                              const SizedBox(height: 22),
                              Text('FRIEND REQUESTS',
                                  style: theme.label.copyWith(letterSpacing: 2)),
                              const SizedBox(height: 4),
                              Text(
                                'control whether strangers can send you friend requests.',
                                style: theme.bodySoft,
                              ),
                              const SizedBox(height: 10),
                              _BinaryRow(
                                theme: theme,
                                value: _vis.friendRequests,
                                onChanged: (v) => _patch(friendRequests: v),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Text(_error!, style: theme.body.copyWith(color: theme.danger)),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
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

  Widget _header(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
          ),
          const SizedBox(width: 4),
          Text('PROFILE VISIBILITY', style: theme.label.copyWith(letterSpacing: 2.4)),
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
  });
  final AppTheme theme;
  final String label;
  final String desc;
  final FieldVisibility value;
  final ValueChanged<FieldVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.label.copyWith(letterSpacing: 1.8)),
        const SizedBox(height: 2),
        Text(desc, style: theme.monoTiny),
        const SizedBox(height: 8),
        _Seg<FieldVisibility>(
          theme: theme,
          options: const [
            (FieldVisibility.public, 'PUBLIC'),
            (FieldVisibility.friends, 'FRIENDS'),
            (FieldVisibility.nobody, 'NOBODY'),
          ],
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _BinaryRow extends StatelessWidget {
  const _BinaryRow({
    required this.theme,
    required this.value,
    required this.onChanged,
  });
  final AppTheme theme;
  final FieldVisibility value;
  final ValueChanged<FieldVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Seg<FieldVisibility>(
      theme: theme,
      options: const [
        (FieldVisibility.public, 'ANYONE'),
        (FieldVisibility.nobody, 'NOBODY'),
      ],
      value: value == FieldVisibility.friends ? FieldVisibility.public : value,
      onChanged: onChanged,
    );
  }
}

class _Seg<T> extends StatelessWidget {
  const _Seg({
    required this.theme,
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final AppTheme theme;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                onTap: () => onChanged(o.$1),
                child: AnimatedContainer(
                  duration: theme.motionFast,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == o.$1 ? theme.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(theme.radiusMd - 2),
                  ),
                  child: Text(
                    o.$2,
                    style: theme.label.copyWith(
                      color: value == o.$1 ? theme.accentInk : theme.inkSoft,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
