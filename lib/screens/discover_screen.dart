import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import '../widgets/room_password_sheet.dart';
import '../widgets/visibility_badge.dart';
import 'room_screen.dart';
import 'search_screen.dart';
// Discover panel doesn't open profile directly anymore — search screen does.

class DiscoverPanel extends StatefulWidget {
  const DiscoverPanel({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;
  @override
  State<DiscoverPanel> createState() => _DiscoverPanelState();
}

class _DiscoverPanelState extends State<DiscoverPanel> {
  List<ChatRoom> _rooms = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final rs = await widget.api.listPublic();
      if (!mounted) return;
      setState(() => _rooms = rs);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SearchScreen(repo: widget.repo, api: widget.api),
            ),
          ),
          child: Container(
            decoration: theme.inputDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.search, color: theme.inkMuted, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'search people · rooms…',
                    style: theme.body.copyWith(color: theme.inkMuted),
                  ),
                ),
                Icon(Icons.arrow_outward, color: theme.inkMuted, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('ROOMS · PUBLIC', style: theme.label),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: theme.divider)),
            const SizedBox(width: 8),
            Text('${_rooms.length}', style: theme.monoTiny),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading && _rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: theme.accent, strokeWidth: 2)),
          )
        else if (_rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('no public rooms', style: theme.bodySoft)),
          )
        else
          Column(
            children: [
              for (final r in _rooms)
                _DiscoverRoomTile(
                  room: r,
                  onTap: () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    String? password;
                    if (r.hasPassword) {
                      password = await showRoomPasswordSheet(context, r);
                      if (!mounted || password == null || password.isEmpty) return;
                    }
                    try {
                      await widget.repo.joinRoom(roomId: r.id, password: password);
                      if (!mounted) return;
                      nav.push(MaterialPageRoute(
                          builder: (_) =>
                              RoomScreen(roomId: r.id, repo: widget.repo, api: widget.api)));
                    } catch (e) {
                      final msg = e.toString().contains('WRONG_PASSWORD')
                          ? 'wrong password'
                          : 'couldn\'t join — try again';
                      messenger.showSnackBar(SnackBar(content: Text(msg)));
                    }
                  },
                ),
            ],
          ),
      ],
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
                    Text(room.description!.toLowerCase(),
                        style: theme.bodySoft, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            VisibilityBadge(isPublic: room.isPublic, dense: true),
            const SizedBox(width: 8),
            Text('${room.memberCount}', style: theme.monoLarge),
            const SizedBox(width: 4),
            Text('IN', style: theme.monoTiny),
          ],
        ),
      ),
    );
  }
}
