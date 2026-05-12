import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';
import 'visibility_badge.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.onTap,
    this.api,
    this.typingNames = const [],
  });

  final ChatRoom room;
  final VoidCallback onTap;
  final ChatApi? api;
  final List<String> typingNames;

  String _ago(DateTime? then) {
    if (then == null) return '';
    final d = DateTime.now().difference(then);
    if (d.inSeconds < 30) return 'just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      VisibilityBadge(isPublic: room.isPublic, dense: true),
                      if (room.isEphemeral && room.messageLifetime != null)
                        EphemeralBadge(ttl: room.messageLifetime!, dense: true),
                      if (room.hasPassword)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: theme.chipDecoration(),
                          child: Text('LOCKED', style: theme.monoTiny),
                        ),
                    ],
                  ),
                ),
                Text(_ago(room.lastMessageTime), style: theme.monoTiny),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room.avatarStorageId != null && api != null) ...[
                  ClipOval(
                    child: RemoteImage(
                      storageId: room.avatarStorageId!,
                      api: api!,
                      width: 36,
                      height: 36,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Text(room.name, style: theme.displayMedium)),
              ],
            ),
            if (room.description != null && room.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(room.description!.toLowerCase(), style: theme.bodySoft),
            ],
            const SizedBox(height: 12),
            if (typingNames.isNotEmpty)
              Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: theme.accent.withValues(alpha: 0.7), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    typingNames.length == 1
                        ? '${typingNames.first} is typing…'
                        : '${typingNames.length} typing…',
                    style: theme.body.copyWith(color: theme.accent, fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ])
            else if (room.lastMessage != null && room.lastMessage!.isNotEmpty)
              Text(
                room.lastMessage!,
                style: theme.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('${room.memberCount} inside', style: theme.caption),
                const Spacer(),
                if (room.isEphemeral)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      theme.hourglassIcon(size: 12, color: theme.accent),
                      const SizedBox(width: 6),
                      Text('messages fade', style: theme.monoTiny.copyWith(color: theme.accent)),
                    ],
                  )
                else
                  Text('↗ enter', style: theme.monoTiny),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
