import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../family/family_service.dart';
import '../models/family.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';

/// Per-child controls, plus the list of what they've already been granted.
///
/// Everything here is guardian-only: the child has no screen that can reach
/// these values, and `users.updateVisibility` refuses child accounts outright
/// on the backend.
class ChildPolicyScreen extends StatefulWidget {
  const ChildPolicyScreen({
    super.key,
    required this.api,
    required this.guardianId,
    required this.child,
    required this.family,
  });

  final ChatApi api;
  final String guardianId;
  final ChildSummary child;
  final FamilyService family;

  @override
  State<ChildPolicyScreen> createState() => _ChildPolicyScreenState();
}

class _ChildPolicyScreenState extends State<ChildPolicyScreen> {
  late ChildPolicy _policy = widget.child.policy;
  ChildGrants? _grants;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadGrants();
  }

  Future<void> _loadGrants() async {
    try {
      final g = await widget.api.listChildGrants(
        guardianId: widget.guardianId,
        childId: widget.child.user.id,
      );
      if (mounted) setState(() => _grants = g);
    } catch (_) {/* dashboard still works without the grant list */}
  }

  Future<void> _set({
    bool? publicRoomsEnabled,
    bool? callsEnabled,
    bool? mediaEnabled,
    bool? canRequestContacts,
    bool? canCreateRooms,
  }) async {
    if (_saving) return;
    // Optimistic: the toggle should move under the thumb, not after a round
    // trip. Reverted below if the write fails.
    final previous = _policy;
    setState(() {
      _saving = true;
      _policy = _policy.copyWith(
        publicRoomsEnabled: publicRoomsEnabled,
        callsEnabled: callsEnabled,
        mediaEnabled: mediaEnabled,
        canRequestContacts: canRequestContacts,
        canCreateRooms: canCreateRooms,
      );
    });
    try {
      final next = await widget.api.setChildPolicy(
        guardianId: widget.guardianId,
        childId: widget.child.user.id,
        publicRoomsEnabled: publicRoomsEnabled,
        callsEnabled: callsEnabled,
        mediaEnabled: mediaEnabled,
        canRequestContacts: canRequestContacts,
        canCreateRooms: canCreateRooms,
      );
      if (mounted) setState(() => _policy = next);
      widget.family.refresh();
    } catch (_) {
      if (mounted) setState(() => _policy = previous);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeRoom(RoomBrief room) async {
    final id = room.approvalId;
    if (id == null) return;
    try {
      await widget.api.revokeApproval(
        guardianId: widget.guardianId,
        approvalId: id,
      );
      await _loadGrants();
    } catch (_) {/* surfaced by the list simply not changing */}
  }

  Future<void> _revokeContact(String contactUserId) async {
    try {
      await widget.api.revokeContact(
        guardianId: widget.guardianId,
        childId: widget.child.user.id,
        contactUserId: contactUserId,
      );
      await _loadGrants();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final grants = _grants;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(Icons.arrow_back,
                            size: 20, color: theme.inkSoft),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.child.user.displayName.toUpperCase(),
                          style: theme.label.copyWith(letterSpacing: 2.8),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                    children: [
                      _SectionHeader('WHAT THEY CAN DO'),
                      const SizedBox(height: 12),
                      _Toggle(
                        label: 'PUBLIC ROOMS',
                        on: _policy.publicRoomsEnabled,
                        onDesc: 'they can browse and ask to join rooms',
                        offDesc: 'Discover is hidden completely',
                        onChanged: (v) => _set(publicRoomsEnabled: v),
                      ),
                      const SizedBox(height: 10),
                      _Toggle(
                        label: 'ASK TO ADD',
                        on: _policy.canRequestContacts,
                        onDesc: 'they can ask you about new people',
                        offDesc: 'family only — no new requests',
                        onChanged: (v) => _set(canRequestContacts: v),
                      ),
                      const SizedBox(height: 10),
                      _Toggle(
                        label: 'CALLS',
                        on: _policy.callsEnabled,
                        onDesc: 'voice + video with people they\'re allowed',
                        offDesc: 'messages only',
                        onChanged: (v) => _set(callsEnabled: v),
                      ),
                      const SizedBox(height: 10),
                      _Toggle(
                        label: 'PHOTOS + VOICE',
                        on: _policy.mediaEnabled,
                        onDesc: 'they can send pictures, video and voice notes',
                        offDesc: 'text only',
                        onChanged: (v) => _set(mediaEnabled: v),
                      ),
                      const SizedBox(height: 10),
                      _Toggle(
                        label: 'MAKE ROOMS',
                        on: _policy.canCreateRooms,
                        onDesc: 'they can start their own private rooms',
                        offDesc: 'they can\'t start rooms',
                        onChanged: (v) => _set(canCreateRooms: v),
                      ),

                      const SizedBox(height: 30),
                      _SectionHeader('PEOPLE YOU\'VE ALLOWED'),
                      const SizedBox(height: 12),
                      if (grants == null)
                        _Placeholder('loading…')
                      else if (grants.contacts.isEmpty)
                        _Placeholder('nobody outside the family yet')
                      else
                        for (final c in grants.contacts)
                          _GrantRow(
                            title: c.displayName,
                            subtitle: '@${c.username}',
                            leading: UserAvatar(
                                user: c, size: 32, api: widget.api),
                            onRevoke: () => _revokeContact(c.id),
                          ),

                      const SizedBox(height: 30),
                      _SectionHeader('ROOMS YOU\'VE ALLOWED'),
                      const SizedBox(height: 12),
                      if (grants == null)
                        _Placeholder('loading…')
                      else if (grants.rooms.isEmpty)
                        _Placeholder('no rooms yet')
                      else
                        for (final r in grants.rooms)
                          _GrantRow(
                            title: r.name,
                            subtitle: '${r.memberCount} in',
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: theme.accentSoft,
                                borderRadius:
                                    BorderRadius.circular(theme.radiusMd),
                              ),
                              alignment: Alignment.center,
                              child: Icon(Icons.tag,
                                  size: 13, color: theme.accent),
                            ),
                            onRevoke: () => _revokeRoom(r),
                          ),
                      const SizedBox(height: 24),
                      Text(
                        'Taking a room back also removes them from it.',
                        style: theme.monoTiny.copyWith(color: theme.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
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
        Text(label,
            style: theme.label.copyWith(letterSpacing: 2.8, color: theme.accent)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: theme.divider)),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.on,
    required this.onDesc,
    required this.offDesc,
    required this.onChanged,
  });

  final String label;
  final bool on;
  final String onDesc;
  final String offDesc;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: () => onChanged(!on),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.label),
                  const SizedBox(height: 2),
                  Text(on ? onDesc : offDesc, style: theme.bodySoft),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(
              value: on,
              onChanged: onChanged,
              activeThumbColor: theme.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _GrantRow extends StatelessWidget {
  const _GrantRow({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onRevoke,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.body, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: theme.monoTiny),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRevoke,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text('TAKE BACK',
                  style: theme.label.copyWith(color: theme.danger)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: theme.bodySoft),
    );
  }
}
