import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';
import 'user_avatar.dart';
import 'visibility_badge.dart';

/// Compact 2-column grid variant of the room card.
class RoomGridTile extends StatelessWidget {
  const RoomGridTile({
    super.key,
    required this.room,
    required this.onTap,
    this.api,
    this.dmUser,
    this.typingNames = const [],
  });
  final ChatRoom room;
  final VoidCallback onTap;
  final ChatApi? api;
  final ChatUser? dmUser;
  final List<String> typingNames;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              if (dmUser != null)
                UserAvatar(user: dmUser!, size: 40, api: api, showStatus: false)
              else if (room.avatarStorageId != null && api != null)
                ClipOval(
                  child: RemoteImage(
                    storageId: room.avatarStorageId!,
                    api: api!,
                    width: 40,
                    height: 40,
                    borderRadius: BorderRadius.circular(20),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.surfaceSunken,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.divider),
                  ),
                  child: room.isEphemeral
                      ? theme.hourglassIcon(size: 18, color: theme.accent)
                      : Icon(Icons.tag, size: 18, color: theme.accent),
                ),
              const Spacer(),
              theme.visibilityIcon(isPublic: room.isPublic, size: 14),
            ]),
            const SizedBox(height: 10),
            Text(
              dmUser?.displayName ?? room.name,
              style: theme.displaySmall.copyWith(fontSize: 17),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (typingNames.isNotEmpty)
              Text(
                typingNames.length == 1
                    ? '${typingNames.first} is typing…'
                    : '${typingNames.length} typing…',
                style: theme.body.copyWith(color: theme.accent, fontStyle: FontStyle.italic, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else if (room.lastMessage != null && room.lastMessage!.isNotEmpty)
              Text(
                room.lastMessage!,
                style: theme.body.copyWith(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text('quiet so far', style: theme.bodySoft.copyWith(fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Text('${room.memberCount}', style: theme.monoLarge),
              const SizedBox(width: 4),
              Text('IN', style: theme.monoTiny),
              if (room.isEphemeral && room.messageLifetime != null) ...[
                const Spacer(),
                EphemeralBadge(ttl: room.messageLifetime!, dense: true),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}
