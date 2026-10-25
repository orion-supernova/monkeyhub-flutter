import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../keyboard/focusable_tap.dart' show HoverEffect;
import '../theme/app_theme.dart';
import '../theme/density.dart';
import '../theme/theme_scope.dart';
import 'chat_list_parts.dart';
import 'live_call_row.dart';
import 'remote_image.dart';
import 'spring_press.dart';
import 'user_avatar.dart';
import 'teardown_safe.dart';

export 'chat_list_parts.dart' show chatListStamp;

/// Avatar diameter on a chat row. Telegram and Messages both sit between 52
/// and 60; 54 keeps a two-line preview level with the avatar's own height.
/// The phone value: the row itself reads [Density.chatRowAvatar], which is 44
/// in the compact desktop layout.
const double kChatRowAvatar = 52;

/// Where a row's text begins, measured from the row's leading edge. The
/// hairline between rows starts here too, so the eye reads one column of
/// names rather than a stack of boxes. Phone value; see
/// [Density.chatRowTextInset].
const double kChatRowTextInset = kChatRowAvatar + 14;

/// One conversation in the home list, laid out the way iOS lays out a
/// conversation: a face, a name, the time, two lines of what was said.
///
/// Replaces [RoomCard] as the default row. The card carried every fact about a
/// room as a labelled pill — public, ephemeral, locked, pinned, muted — plus a
/// member count and an "ENTER" in its footer, so the one thing a list is for,
/// who said what and when, had to be dug out from under the metadata. Here the
/// metadata collapses into small glyphs beside the name, drawn in the quietest
/// ink, and only unread state is allowed colour.
///
/// No card, no border, no shadow, no divider: rows are separated by spacing
/// alone, as in Signal. Pressing one dips it to 0.98 and lights a rounded
/// ink@0.06 highlight.
class ChatListRow extends StatefulWidget {
  const ChatListRow({
    super.key,
    required this.room,
    required this.onTap,
    this.api,
    this.dmUser,
    this.typists = const [],
    this.showDivider = true,
  });

  final ChatRoom room;
  final VoidCallback onTap;
  final ChatApi? api;

  /// For DMs, the other person — their name and face stand in for the raw
  /// `dm:...` room name.
  final ChatUser? dmUser;
  final List<ChatUser> typists;

  /// Kept for call-site compatibility. Signal draws no rule between chat rows
  /// (the avatars form their own column), so this no longer draws anything.
  final bool showDivider;

  @override
  State<ChatListRow> createState() => _ChatListRowState();
}

class _ChatListRowState extends State<ChatListRow>
    with TeardownSafe<ChatListRow> {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final room = widget.room;
    final title = chatListTitleOf(context, room, widget.dmUser);
    final density = Density.of(context);
    final compact = density.compact;
    // Signal's proportions on a phone: a 52 face in a ~72 row, name 16/600,
    // preview 14, stamp 13. Desktop keeps Density's own compact metrics.
    final avatar = compact ? density.chatRowAvatar : kChatRowAvatar;
    final titleSize = compact ? density.chatRowTitleSize : 16.0;
    final previewSize = compact ? density.chatRowPreviewSize : 14.0;
    final stampSize = compact ? density.chatRowStampSize : 13.0;

    // SpringPress owns the tap, keyboard activation and the 0.98 dip (list
    // rows keep shrinking, never bloom). The pressed state draws a soft
    // rounded highlight, not a flat table-cell fill.
    return SpringPress(
      onTap: widget.onTap,
      scale: _kRowPressScale,
      haptic: false,
      semanticLabel: title,
      focusRadius: _kRowRadius,
      hoverRadius: _kRowRadius,
      hover: HoverEffect.tint,
      builder: (context, pressed) => AnimatedContainer(
        duration: pressed ? Duration.zero : theme.motionFast,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: pressed ? theme.ink.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(_kRowRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: density.chatRowPadding),
            // Only this room's call: one starting elsewhere rebuilds nothing
            // here.
            child: RoomLiveCallBuilder(
              roomId: room.id,
              builder: (context, call) => Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LiveCallHalo(
                    call: call,
                    size: avatar,
                    child: ChatRoomAvatar(
                      room: room,
                      dmUser: widget.dmUser,
                      api: widget.api,
                      size: avatar,
                    ),
                  ),
                  SizedBox(width: density.chatRowGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The name takes whatever the stamp leaves.
                        Row(
                          children: [
                            Expanded(
                              child: ChatListTitle(
                                room: room,
                                title: title,
                                fontSize: titleSize,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ChatListStamp(room: room, fontSize: stampSize),
                          ],
                        ),
                        SizedBox(height: density.chatRowLineGap),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ChatListPreview(
                                room: room,
                                call: call,
                                typists: widget.typists,
                                fontSize: previewSize,
                                lineHeight: density.chatRowPreviewHeight,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: ChatListTrailing(room: room, call: call),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _kRowRadius = 16;
const double _kRowPressScale = 0.98;

/// A room's face at any size: Saved Messages' bookmark disc, a DM peer's
/// avatar, the room's own picture, or its monogram — the one rule the chat
/// list, the forward sheet and the share sheet all draw by, so a group never
/// turns into a generic people glyph in one of them.
class ChatRoomAvatar extends StatelessWidget {
  const ChatRoomAvatar({
    super.key,
    required this.room,
    required this.size,
    this.dmUser,
    this.api,
  });

  final ChatRoom room;
  final double size;
  final ChatUser? dmUser;
  final ChatApi? api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final api = this.api;
    if (room.isSavedMessages) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(theme.accent, Colors.white, 0.18)!,
              theme.accent,
            ],
          ),
        ),
        child: Icon(
          CupertinoIcons.bookmark_fill,
          size: size * 0.4,
          color: theme.accentInk,
        ),
      );
    }
    final dm = dmUser;
    if (dm != null) {
      return UserAvatar(user: dm, size: size, api: api);
    }
    if (room.avatarStorageId != null && api != null) {
      return ClipOval(
        child: RemoteImage(
          storageId: room.avatarStorageId!,
          api: api,
          width: size,
          height: size,
          borderRadius: BorderRadius.circular(size / 2),
        ),
      );
    }
    return MonogramAvatar(label: room.name, seed: room.id, size: size);
  }
}

/// A face for something that has no picture: one hue from the theme's avatar
/// palette, lit from above, with the first letter on it.
///
/// One hue rather than the two-colour blend [UserAvatar] used to draw — a pair
/// picked independently at random is how a list ends up with an orange-to-
/// purple disc next to a green-to-blue one, which is the opposite of calm.
class MonogramAvatar extends StatelessWidget {
  const MonogramAvatar({
    super.key,
    required this.label,
    required this.seed,
    required this.size,
  });

  final String label;
  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final trimmed = label.trim();
    final letter = trimmed.isEmpty
        ? '#'
        : trimmed.characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: monogramGradient(theme, seed.hashCode),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: 'CupertinoSystemDisplay',
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The single-hue top-lit gradient every lettered avatar wears.
LinearGradient monogramGradient(AppTheme theme, int seed) {
  final hue = theme.avatarGradient(seed & 0x7fffffff).first;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.lerp(hue, Colors.white, 0.22)!,
      Color.lerp(hue, Colors.black, 0.12)!,
    ],
  );
}
