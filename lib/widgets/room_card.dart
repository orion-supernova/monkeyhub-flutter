import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';
import 'remote_image.dart';
import 'typing_indicator.dart';
import 'user_avatar.dart';
import 'visibility_badge.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.onTap,
    this.api,
    this.dmUser,
    this.typists = const [],
  });

  final ChatRoom room;
  final VoidCallback onTap;
  final ChatApi? api;

  /// For DM rooms, the other participant — used to override the raw "dm:..."
  /// room name with the friend's display name + avatar.
  final ChatUser? dmUser;
  final List<ChatUser> typists;

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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (dmUser != null) ...[
                  UserAvatar(user: dmUser!, size: 32, api: api),
                  const SizedBox(width: 10),
                ] else if (room.avatarStorageId != null && api != null) ...[
                  ClipOval(
                    child: RemoteImage(
                      storageId: room.avatarStorageId!,
                      api: api!,
                      width: 32,
                      height: 32,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (room.hasUnread) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: theme.accent.withValues(alpha: 0.7), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    dmUser?.displayName ?? room.name,
                    style: room.hasUnread
                        ? theme.displaySmall.copyWith(fontWeight: FontWeight.w700)
                        : theme.displaySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (room.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  CountBadge(count: room.unreadCount, mention: room.hasMention),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (typists.isNotEmpty)
              TypingLine(typists: typists)
            else if (room.lastMessage != null && room.lastMessage!.isNotEmpty)
              Text(
                room.lastMessage!,
                style: theme.bodySoft,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),
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
