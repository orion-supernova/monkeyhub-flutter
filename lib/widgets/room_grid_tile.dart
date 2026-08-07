import 'package:flutter/material.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';
import 'remote_image.dart';
import 'typing_indicator.dart';
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
    this.typists = const [],
  });
  final ChatRoom room;
  final VoidCallback onTap;
  final ChatApi? api;
  final ChatUser? dmUser;
  final List<ChatUser> typists;

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
                    runSpacing: 2,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (room.unreadCount > 0)
                        CountBadge(
                          count: room.unreadCount,
                          mention: room.hasMention,
                        )
                      else if (room.hasUnread)
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
                      // Icons alone up here: the tile has a name, a preview
                      // line and an unread count to fit as well, and every
                      // pill explains itself on tap. A DM gets no visibility
                      // pill at all — "private" is the only thing a
                      // one-to-one conversation could be.
                      if (!room.isDm)
                        VisibilityBadge(
                          isPublic: room.isPublic,
                          dense: true,
                          iconOnly: true,
                        ),
                      if (room.hasPassword)
                        const LockedBadge(dense: true, iconOnly: true),
                      if (room.isEphemeral && room.messageLifetime != null)
                        EphemeralBadge(
                          ttl: room.messageLifetime!,
                          dense: true,
                          iconOnly: true,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dmUser?.displayName ?? room.name,
                    style: theme.displaySmall.copyWith(
                      fontSize: 16,
                      fontWeight: room.hasUnread ? FontWeight.w700 : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: typists.isNotEmpty
                        ? TypingLine(typists: typists)
                        : Text(
                            (room.lastMessage != null && room.lastMessage!.isNotEmpty)
                                ? room.lastMessage!
                                : AppLocalizations.of(context).roomGridTileEmptyLastMessage,
                            style: (room.lastMessage != null && room.lastMessage!.isNotEmpty)
                                ? theme.body.copyWith(fontSize: 12)
                                : theme.bodySoft.copyWith(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ],
              ),
            ),
            // A DM always has exactly two people in it, so the count is noise —
            // the friend's name and avatar already say who's here.
            if (!room.isDm)
              Row(children: [
                Text('${room.memberCount}', style: theme.monoLarge.copyWith(fontSize: 16)),
                const SizedBox(width: 4),
                Text(AppLocalizations.of(context).roomGridTileMemberCountLabel, style: theme.monoTiny),
              ]),
          ],
        ),
      ),
    );
  }
}
