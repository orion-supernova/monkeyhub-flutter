import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';
import 'remote_image.dart';
import 'room_identity.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final decoration = theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false);
    // A room with a picture already has a face, and a DM borrows the other
    // person's; the monogram is for the ones with neither.
    final unfaced = dmUser == null && (room.avatarStorageId == null || api == null);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: decoration,
        child: ClipRRect(
          borderRadius: decoration.borderRadius?.resolve(Directionality.of(context))
              ?? BorderRadius.circular(theme.radiusLg),
          child: Stack(
            children: [
              if (unfaced)
                Positioned(
                  right: -10,
                  bottom: -30,
                  child: RoomMonogram(name: room.name, seed: room.id, size: 96),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: _body(context, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final subtitle = roomSubtitle(context, room);
    return Column(
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
                  // A full row has the width for words, so these keep
                  // their labels; the tap tooltip is the long form. No
                  // visibility pill on a DM — it could only ever say
                  // "private".
                  if (!room.isDm)
                    VisibilityBadge(isPublic: room.isPublic, dense: true),
                  if (room.isEphemeral && room.messageLifetime != null)
                    EphemeralBadge(ttl: room.messageLifetime!, dense: true),
                  if (room.hasPassword) const LockedBadge(dense: true),
                ],
              ),
            ),
            // A room nobody has spoken in has no "last" anything, so the
            // stamp answers the question you'd actually ask of it: how
            // long has it been sitting here quiet.
            Text(
              room.lastMessageTime != null
                  ? roomTimeAgo(context, room.lastMessageTime!)
                  : l10n.roomCardStartedAgo(roomTimeAgo(context, room.createdAt)),
              style: theme.monoTiny,
            ),
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
        // Always a line here, even when there's nothing to preview: the
        // slot used to vanish, and a card that shrinks for want of
        // content is the one that looks broken next to a full one.
        if (typists.isNotEmpty)
          TypingLine(typists: typists)
        else
          Text(
            subtitle.text,
            style: subtitle.kind == RoomSubtitleKind.message
                ? theme.bodySoft
                : theme.bodySoft.copyWith(color: theme.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            // A DM always has exactly two people in it, so "2 inside" is
            // noise — the friend's name and avatar already say who's here.
            if (!room.isDm) Text(l10n.roomCardMemberCount(room.memberCount), style: theme.caption),
            const Spacer(),
            if (room.isEphemeral)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  theme.hourglassIcon(size: 12, color: theme.accent),
                  const SizedBox(width: 6),
                  Text(l10n.roomCardMessagesFadeLabel, style: theme.monoTiny.copyWith(color: theme.accent)),
                ],
              )
            else
              Text(l10n.roomCardEnterLabel, style: theme.monoTiny),
          ],
        ),
      ],
    );
  }
}
