import 'package:flutter/material.dart';
import '../data/mock_store.dart';
import '../models/requests.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import '../widgets/visibility_badge.dart';

class RequestsPanel extends StatefulWidget {
  const RequestsPanel({super.key});
  @override
  State<RequestsPanel> createState() => _RequestsPanelState();
}

class _RequestsPanelState extends State<RequestsPanel> {
  String _tab = 'friends';

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _SubTab(label: 'friend · ${store.friendRequests.length}', active: _tab == 'friends', onTap: () => setState(() => _tab = 'friends')),
            const SizedBox(width: 18),
            _SubTab(label: 'invites · ${store.roomInvites.length}', active: _tab == 'invites', onTap: () => setState(() => _tab = 'invites')),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: theme.motionFast,
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: _tab == 'friends' ? const _FriendsList() : const _InvitesList(),
          ),
        ),
      ],
    );
  }
}

class _SubTab extends StatelessWidget {
  const _SubTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.label.copyWith(color: active ? theme.ink : theme.inkMuted)),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: theme.motionFast,
            height: 1.5,
            width: active ? 38 : 0,
            color: theme.accent,
          ),
        ],
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    if (store.friendRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        alignment: Alignment.center,
        child: Text('no requests · inbox quiet', style: theme.bodySoft),
      );
    }
    return Column(
      children: [
        for (final r in store.friendRequests) _FriendRequestCard(req: r),
      ],
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({required this.req});
  final FriendRequest req;

  String _ago(DateTime then) {
    final d = DateTime.now().difference(then);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final from = store.userById(req.fromUserId);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: theme.roomCardDecoration(ephemeral: false, active: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(user: from, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(from.name, style: theme.displaySmall),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(from.handle, style: theme.mono.copyWith(color: theme.inkMuted)),
                      const SizedBox(width: 8),
                      VisibilityBadge(isPublic: from.isPublic, dense: true),
                    ]),
                  ],
                ),
              ),
              Text(_ago(req.sentAt), style: theme.monoTiny),
            ],
          ),
          if (req.note != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                borderRadius: BorderRadius.circular(theme.radiusMd),
                border: Border(left: BorderSide(color: theme.accent, width: 2)),
              ),
              child: Text('"${req.note}"', style: theme.bodyEmph),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'ACCEPT',
                  filled: true,
                  onTap: () => store.resolveFriendRequest(req.id, accept: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'DECLINE',
                  filled: false,
                  onTap: () => store.resolveFriendRequest(req.id, accept: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvitesList extends StatelessWidget {
  const _InvitesList();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    if (store.roomInvites.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        alignment: Alignment.center,
        child: Text('no invites', style: theme.bodySoft),
      );
    }
    return Column(
      children: [
        for (final inv in store.roomInvites) _InviteCard(inv: inv),
      ],
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.inv});
  final RoomInvite inv;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final room = store.roomById(inv.roomId);
    final from = store.userById(inv.fromUserId);
    if (room == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: theme.surfaceRaised,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                  border: Border.all(color: theme.divider),
                ),
                alignment: Alignment.center,
                child: theme.hourglassIcon(size: 16, color: theme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: theme.displaySmall),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, children: [
                      VisibilityBadge(isPublic: room.isPublic, dense: true),
                      if (room.isEphemeral) EphemeralBadge(ttl: room.ttl!, dense: true),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: theme.body,
              children: [
                TextSpan(text: from.name.split(' ').first.toLowerCase(), style: theme.bodyEmph),
                const TextSpan(text: ' invited you in.'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'JOIN',
                  filled: true,
                  onTap: () => store.resolveRoomInvite(inv.id, accept: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'IGNORE',
                  filled: false,
                  onTap: () => store.resolveRoomInvite(inv.id, accept: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.filled, required this.onTap});
  final String label;
  final bool filled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? theme.accent : Colors.transparent,
          border: Border.all(color: filled ? theme.accent : theme.divider, width: 1.2),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(label, style: theme.label.copyWith(color: filled ? theme.accentInk : theme.ink)),
      ),
    );
  }
}
