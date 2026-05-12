import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/friend_request.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import '../widgets/visibility_badge.dart';
import 'friend_request_draft_screen.dart';
import 'room_screen.dart';

class RequestsPanel extends StatefulWidget {
  const RequestsPanel({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;
  @override
  State<RequestsPanel> createState() => _RequestsPanelState();
}

class _RequestsPanelState extends State<RequestsPanel> {
  String _tab = 'incoming';

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onRepoChange);
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final incoming = widget.repo.incomingRequests;
    final outgoing = widget.repo.outgoingRequests;
    final friends = widget.repo.friends;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _SubTab(
              label: 'incoming · ${incoming.length}',
              active: _tab == 'incoming',
              onTap: () => setState(() => _tab = 'incoming'),
            ),
            const SizedBox(width: 18),
            _SubTab(
              label: 'outgoing · ${outgoing.length}',
              active: _tab == 'outgoing',
              onTap: () => setState(() => _tab = 'outgoing'),
            ),
            const SizedBox(width: 18),
            _SubTab(
              label: 'friends · ${friends.length}',
              active: _tab == 'friends',
              onTap: () => setState(() => _tab = 'friends'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: theme.motionFast,
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: _panel(incoming, outgoing, friends),
          ),
        ),
      ],
    );
  }

  Widget _panel(
    List<FriendRequest> incoming,
    List<FriendRequest> outgoing,
    List<ChatUser> friends,
  ) {
    switch (_tab) {
      case 'incoming':
        return _IncomingList(repo: widget.repo, api: widget.api, requests: incoming);
      case 'outgoing':
        return _OutgoingList(repo: widget.repo, api: widget.api, requests: outgoing);
      case 'friends':
        return _FriendsList(repo: widget.repo, api: widget.api, friends: friends);
      default:
        return const SizedBox.shrink();
    }
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
          Text(label.toUpperCase(),
              style: theme.label.copyWith(color: active ? theme.ink : theme.inkMuted)),
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

class _IncomingList extends StatelessWidget {
  const _IncomingList({required this.repo, required this.api, required this.requests});
  final ChatRepository repo;
  final ChatApi api;
  final List<FriendRequest> requests;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (requests.isEmpty) {
      return _empty(theme, 'inbox quiet');
    }
    return Column(
      children: [
        for (final r in requests)
          _IncomingCard(req: r, repo: repo, api: api),
      ],
    );
  }
}

class _OutgoingList extends StatelessWidget {
  const _OutgoingList({required this.repo, required this.api, required this.requests});
  final ChatRepository repo;
  final ChatApi api;
  final List<FriendRequest> requests;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (requests.isEmpty) {
      return _empty(theme, 'nothing pending');
    }
    return Column(
      children: [
        for (final r in requests)
          _OutgoingCard(req: r, repo: repo, api: api),
      ],
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList({required this.repo, required this.api, required this.friends});
  final ChatRepository repo;
  final ChatApi api;
  final List<ChatUser> friends;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (friends.isEmpty) {
      return _empty(theme, 'no friends yet — discover someone');
    }
    return Column(
      children: [
        for (final f in friends) _FriendRow(user: f, repo: repo, api: api),
      ],
    );
  }
}

Widget _empty(AppTheme theme, String text) => Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Text(text, style: theme.bodySoft),
    );

String _ago(DateTime then) {
  final d = DateTime.now().difference(then);
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

class _IncomingCard extends StatefulWidget {
  const _IncomingCard({required this.req, required this.repo, required this.api});
  final FriendRequest req;
  final ChatRepository repo;
  final ChatApi api;
  @override
  State<_IncomingCard> createState() => _IncomingCardState();
}

class _IncomingCardState extends State<_IncomingCard> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      final roomId = await widget.repo.approveDirectRequest(widget.req.user.id);
      if (!mounted) return;
      if (roomId != null) {
        nav.push(MaterialPageRoute(
            builder: (_) => RoomScreen(roomId: roomId, repo: widget.repo, api: widget.api)));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repo.rejectDirectRequest(widget.req.user.id);
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDraft() async {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FriendRequestDraftScreen(
        repo: widget.repo,
        api: widget.api,
        req: widget.req,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final req = widget.req;
    return GestureDetector(
      onTap: _openDraft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: theme.roomCardDecoration(
          ephemeral: req.roomType == RoomType.secret,
          active: false,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(user: req.user, size: 42, api: widget.api),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(req.user.displayName, style: theme.displaySmall),
                      const SizedBox(height: 2),
                      Row(children: [
                        Text('@${req.user.username}', style: theme.mono.copyWith(color: theme.inkMuted)),
                        const SizedBox(width: 8),
                        if (req.roomType == RoomType.secret && req.messageLifetime != null)
                          EphemeralBadge(ttl: req.messageLifetime!, dense: true)
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: theme.chipDecoration(),
                            child: Text('STANDARD', style: theme.monoTiny),
                          ),
                      ]),
                    ],
                  ),
                ),
                Text(_ago(req.createdAt), style: theme.monoTiny),
              ],
            ),
            if (req.initialMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: theme.surfaceSunken,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                  border: Border(left: BorderSide(color: theme.accent, width: 2)),
                ),
                child: Text('"${req.initialMessage}"', style: theme.bodyEmph),
              ),
            ],
            if (req.messageCount > 1) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.forum_outlined, size: 12, color: theme.accent),
                const SizedBox(width: 6),
                Text('${req.messageCount} draft messages · tap to view',
                    style: theme.monoTiny.copyWith(color: theme.accent)),
              ]),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Action(label: _busy ? '…' : 'APPROVE', filled: true, onTap: _busy ? null : _accept),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Action(label: 'DECLINE', filled: false, onTap: _busy ? null : _reject),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingCard extends StatefulWidget {
  const _OutgoingCard({required this.req, required this.repo, required this.api});
  final FriendRequest req;
  final ChatRepository repo;
  final ChatApi api;
  @override
  State<_OutgoingCard> createState() => _OutgoingCardState();
}

class _OutgoingCardState extends State<_OutgoingCard> {
  bool _busy = false;
  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repo.cancelDirectRequest(widget.req.user.id);
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final req = widget.req;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: theme.roomCardDecoration(
        ephemeral: req.roomType == RoomType.secret,
        active: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(user: req.user, size: 42, api: widget.api),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.user.displayName, style: theme.displaySmall),
                    const SizedBox(height: 2),
                    Text('@${req.user.username}',
                        style: theme.mono.copyWith(color: theme.inkMuted)),
                  ],
                ),
              ),
              Text('SENT ${_ago(req.createdAt).toUpperCase()}', style: theme.monoTiny),
            ],
          ),
          if (req.messageCount > 0) ...[
            const SizedBox(height: 12),
            Text('${req.messageCount} message${req.messageCount == 1 ? '' : 's'} pending',
                style: theme.bodySoft),
          ],
          const SizedBox(height: 14),
          _Action(label: _busy ? '…' : 'CANCEL REQUEST', filled: false, onTap: _busy ? null : _cancel),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.user, required this.repo, required this.api});
  final ChatUser user;
  final ChatRepository repo;
  final ChatApi api;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: () async {
        final nav = Navigator.of(context);
        try {
          final roomId = await repo.openDmWith(user);
          if (!context.mounted) return;
          nav.push(MaterialPageRoute(
              builder: (_) => RoomScreen(roomId: roomId, repo: repo, api: api)));
        } catch (_) {}
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: theme.roomCardDecoration(ephemeral: false, active: false),
        child: Row(
          children: [
            UserAvatar(user: user, size: 36, api: api),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: theme.displaySmall.copyWith(fontSize: 16)),
                  Text('@${user.username}', style: theme.monoTiny),
                ],
              ),
            ),
            Icon(Icons.north_east, size: 14, color: theme.inkMuted),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.filled, required this.onTap});
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (onTap == null ? theme.accentSoft : theme.accent)
              : Colors.transparent,
          border: Border.all(color: filled ? theme.accent : theme.divider, width: 1.2),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(label,
            style: theme.label.copyWith(color: filled ? theme.accentInk : theme.ink)),
      ),
    );
  }
}
