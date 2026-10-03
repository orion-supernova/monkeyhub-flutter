import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show quietFill;
import 'count_badge.dart';
import 'muted_badge.dart';
import 'pinned_badge.dart';
import 'remote_image.dart';
import 'room_identity.dart';
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

  // Listens to the settings it reads: this widget is built `const`, and a
  // const widget is never rebuilt by its parent, so a changed setting would
  // otherwise leave it showing the old value.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SettingsStore.instance,
        builder: (context, _) => _buildListening(context),
      );

  Widget _buildListening(BuildContext context) {
    final theme = ThemeScope.of(context);
    final decoration = theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false);
    final subtitle = roomSubtitle(context, room);
    final quiet = subtitle.kind == RoomSubtitleKind.empty;
    // Off unless asked for, and even then only where there's actually a hole
    // to fill: a tile with a preview line is carrying pills, a count and a
    // sentence already, and a letter behind all that is one more thing in the
    // way rather than a backdrop. A room with a picture has a face, and a DM
    // borrows the other person's.
    final monogrammed = SettingsStore.instance.roomMonogram &&
        quiet &&
        dmUser == null &&
        (room.avatarStorageId == null || api == null);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: decoration.borderRadius?.resolve(Directionality.of(context))
              ?? BorderRadius.circular(theme.radiusLg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (monogrammed)
                Positioned(
                  right: -14,
                  bottom: -34,
                  child: RoomMonogram(name: room.name, seed: room.id, size: 132),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _body(context, theme, subtitle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppTheme theme, RoomSubtitle subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (room.isSavedMessages)
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: quietFill(theme), shape: BoxShape.circle),
                child: Icon(CupertinoIcons.bookmark_fill, size: 18, color: theme.accent),
              )
            else if (dmUser != null)
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    // Mute-resolved, same as room_card.dart: a badge-muted
                    // room shows neither the pill nor the dot it falls back to.
                    if (room.visibleUnreadCount > 0)
                      CountBadge(
                        count: room.visibleUnreadCount,
                        mention: room.hasVisibleMention,
                      )
                    else if (room.hasUnread)
                      Container(
                        width: 14,
                        height: 14,
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
                    // Shown for Saved Messages too, same reasoning as
                    // room_card.dart: pinning it is now a choice, not a given.
                    if (room.isPinned)
                      const PinnedBadge(dense: true, iconOnly: true),
                    // Icon-only here: a tile this narrow has no room for the
                    // word, and the pill's tap tooltip still spells out which of
                    // the two switches is on.
                    if (room.isMuted)
                      MutedBadge(
                        dense: true,
                        iconOnly: true,
                        silencesNotifications: room.notificationsMuted,
                        silencesCounts: room.badgesMuted,
                      ),
                  ],
                ),
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
                room.isSavedMessages
                    ? AppLocalizations.of(context).savedMessagesTitle
                    : (dmUser?.displayName ?? room.name),
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
                        subtitle.text,
                        style: switch (subtitle.kind) {
                          RoomSubtitleKind.message => theme.body.copyWith(fontSize: 12),
                          // The room's own words, not a placeholder: quieter
                          // than a message, but not greyed out to nothing.
                          RoomSubtitleKind.description =>
                              theme.bodySoft.copyWith(fontSize: 12, height: 1.35),
                          RoomSubtitleKind.empty => theme.bodySoft.copyWith(fontSize: 12),
                        },
                        maxLines: subtitle.kind == RoomSubtitleKind.description ? 2 : 1,
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
    );
  }
}
