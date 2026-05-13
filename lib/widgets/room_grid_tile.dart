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
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        ? theme.hourglassIcon(size: 20, color: theme.accent)
                        : Icon(Icons.tag, size: 20, color: theme.accent),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      VisibilityBadge(isPublic: room.isPublic, dense: true),
                      if (room.hasPassword)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: theme.chipDecoration(),
                          child: Text('LOCKED', style: theme.monoTiny),
                        ),
                      if (room.isEphemeral && room.messageLifetime != null)
                        EphemeralBadge(ttl: room.messageLifetime!, dense: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              dmUser?.displayName ?? room.name,
              style: theme.displaySmall.copyWith(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (typingNames.isNotEmpty)
              Row(children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: theme.accent.withValues(alpha: 0.7), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    typingNames.length == 1
                        ? '${typingNames.first} is typing…'
                        : '${typingNames.length} typing…',
                    style: theme.body.copyWith(color: theme.accent, fontStyle: FontStyle.italic, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ])
            else if (room.lastMessage != null && room.lastMessage!.isNotEmpty)
              Text(
                room.lastMessage!,
                style: theme.body.copyWith(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else
              Text(
                'quiet so far',
                style: theme.bodySoft.copyWith(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            Row(children: [
              Text('${room.memberCount}', style: theme.monoLarge.copyWith(fontSize: 16)),
              const SizedBox(width: 4),
              Text('IN', style: theme.monoTiny),
            ]),
          ],
        ),
      ),
    );
  }
}
