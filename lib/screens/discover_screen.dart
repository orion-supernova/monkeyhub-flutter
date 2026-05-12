import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import '../widgets/visibility_badge.dart';
import 'profile_screen.dart';
import 'room_screen.dart';

class DiscoverPanel extends StatefulWidget {
  const DiscoverPanel({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;
  @override
  State<DiscoverPanel> createState() => _DiscoverPanelState();
}

class _DiscoverPanelState extends State<DiscoverPanel> {
  final _q = TextEditingController();
  String _query = '';
  List<ChatRoom> _rooms = [];
  List<ChatUser> _users = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final rs = await widget.api.listPublic();
      final myId = widget.repo.userId ?? '';
      final us = _query.trim().isEmpty
          ? <ChatUser>[]
          : await widget.api.searchUsers(query: _query, currentUserId: myId);
      if (!mounted) return;
      setState(() {
        _rooms = _query.trim().isEmpty
            ? rs
            : rs.where((r) => r.name.toLowerCase().contains(_query.toLowerCase())).toList();
        _users = us;
      });
    } catch (e) {
      // swallow for the mock; could surface as a toast later
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: theme.inputDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.inkMuted, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _q,
                  style: theme.body.copyWith(color: theme.ink),
                  cursorColor: theme.accent,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'search public rooms · users by handle…',
                    hintStyle: theme.body.copyWith(color: theme.inkMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (v) {
                    setState(() => _query = v);
                    _refresh();
                  },
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _q.clear();
                    setState(() => _query = '');
                    _refresh();
                  },
                  child: Icon(Icons.close, color: theme.inkMuted, size: 16),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (_users.isNotEmpty) ...[
          _SectionHeader(label: 'PEOPLE', count: _users.length),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _users.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _PersonCard(user: _users[i]),
            ),
          ),
          const SizedBox(height: 22),
        ],
        _SectionHeader(label: 'ROOMS · PUBLIC ONLY', count: _rooms.length),
        const SizedBox(height: 12),
        if (_loading && _rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: theme.accent, strokeWidth: 2)),
          )
        else if (_rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('no rooms found', style: theme.bodySoft)),
          )
        else
          Column(
            children: [
              for (final r in _rooms)
                _DiscoverRoomTile(room: r, onTap: () async {
                  final nav = Navigator.of(context);
                  await widget.repo.joinRoom(roomId: r.id);
                  if (!mounted) return;
                  nav.push(MaterialPageRoute(
                      builder: (_) => RoomScreen(roomId: r.id, repo: widget.repo, api: widget.api)));
                }),
            ],
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: theme.label),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: theme.divider)),
        const SizedBox(width: 8),
        Text('$count', style: theme.monoTiny),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.user});
  final ChatUser user;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(user: user))),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: theme.roomCardDecoration(ephemeral: false, active: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(user: user, size: 38),
            const SizedBox(height: 10),
            Text(user.displayName, style: theme.displaySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('@${user.username}', style: theme.monoTiny),
            const Spacer(),
            VisibilityBadge(isPublic: true, dense: true),
          ],
        ),
      ),
    );
  }
}

class _DiscoverRoomTile extends StatelessWidget {
  const _DiscoverRoomTile({required this.room, required this.onTap});
  final ChatRoom room;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: theme.accentSoft,
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              alignment: Alignment.center,
              child: room.isEphemeral
                  ? theme.hourglassIcon(size: 14, color: theme.accent)
                  : Icon(Icons.tag, size: 14, color: theme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name, style: theme.displaySmall),
                  const SizedBox(height: 2),
                  if (room.description != null && room.description!.isNotEmpty)
                    Text(room.description!.toLowerCase(), style: theme.bodySoft, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Text('${room.memberCount}', style: theme.monoLarge),
            const SizedBox(width: 4),
            Text('IN', style: theme.monoTiny),
          ],
        ),
      ),
    );
  }
}
