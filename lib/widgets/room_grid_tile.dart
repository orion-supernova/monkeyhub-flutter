import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';
import 'visibility_badge.dart';

/// Compact 2-column grid variant of the room card.
class RoomGridTile extends StatelessWidget {
  const RoomGridTile({
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              if (room.avatarStorageId != null && api != null)
                ClipOval(
                  child: RemoteImage(
                    storageId: room.avatarStorageId!,
                    api: api!,
                    width: 22,
                    height: 22,
                    borderRadius: BorderRadius.circular(11),
                  ),
                )
              else if (room.isEphemeral)
                theme.hourglassIcon(size: 14, color: theme.accent)
              else
                Icon(Icons.tag, size: 14, color: theme.accent),
              const Spacer(),
              theme.visibilityIcon(isPublic: room.isPublic, size: 12),
            ]),
            const SizedBox(height: 10),
            Text(
              room.name,
              style: theme.displaySmall.copyWith(fontSize: 17),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text('quiet so far', style: theme.bodySoft.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
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
