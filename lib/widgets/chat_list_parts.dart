import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../calls/live_calls_store.dart';
import '../data/matches_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';
import 'live_call_row.dart';
import 'room_identity.dart';
import 'typing_indicator.dart';

// The pieces every chat-list layout is built from: rows, cards and grid
// tiles differ in where they put these, never in what they draw. So a room
// in a call, a room with unread messages or a room you muted looks the same
// thing in all three, and a fix lands once.
//
// What made the rows layout the good-looking one, and what these carry
// into the others:
//  * three tiers of type and nothing else: the name (emphasised, full ink),
//    the preview (soft, muted, up to two lines), the stamp (small, tabular,
//    muted until something is unread);
//  * facts about a room (secret, locked, muted) as small glyphs in the
//    quietest ink after the name, never as pills;
//  * colour reserved for what needs you: unread, a call, your move;
//  * one trailing slot holding one thing.

/// The name a room goes by in the list.
String chatListTitleOf(BuildContext context, ChatRoom room, ChatUser? dmUser) =>
    room.isSavedMessages
        ? AppLocalizations.of(context).savedMessagesTitle
        : (dmUser?.displayName ?? room.name);

/// Whether the room has something unread that it is allowed to show. The
/// mute-resolved getters, so a room silenced down to its counts goes quiet
/// everywhere at once.
bool chatListUnread(ChatRoom room) =>
    room.visibleUnreadCount > 0 || room.hasUnread;

/// The time beside a room, the way Messages writes it: the clock today,
/// "Yesterday", then a short date.
String chatListStamp(BuildContext context, DateTime then) {
  final local = then.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final material = MaterialLocalizations.of(context);
  if (day == today) {
    return material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }
  if (today.difference(day).inDays == 1) {
    return AppLocalizations.of(context).chatListYesterday;
  }
  return material.formatShortMonthDay(local);
}

/// The name, and the room's facts as quiet glyphs riding right after it.
class ChatListTitle extends StatelessWidget {
  const ChatListTitle({
    super.key,
    required this.room,
    required this.title,
    this.fontSize,
    this.facts = true,
  });

  final ChatRoom room;
  final String title;

  /// Null keeps the theme's emphasised body size.
  final double? fontSize;

  /// Whether secret and locked get a glyph here. Off on a card, whose meta
  /// line already says both in words; muted always shows, since nothing
  /// else on any layout says it.
  final bool facts;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final glyph = theme.inkMuted;
    final size = fontSize ?? theme.bodyEmph.fontSize ?? 17;
    final g = (size * 0.76).roundToDouble();
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: theme.bodyEmph.copyWith(
              color: theme.ink,
              fontSize: fontSize,
              height: 1.25,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (facts && room.isEphemeral) ...[
          const SizedBox(width: 5),
          theme.hourglassIcon(size: g + 1, color: glyph),
        ],
        if (facts && room.hasPassword) ...[
          const SizedBox(width: 4),
          Icon(CupertinoIcons.lock_fill, size: g, color: glyph),
        ],
        if (room.isMuted) ...[
          const SizedBox(width: 4),
          Icon(CupertinoIcons.bell_slash_fill, size: g, color: glyph),
        ],
      ],
    );
  }
}

/// When the room last moved, in the accent while something there is unread.
class ChatListStamp extends StatelessWidget {
  const ChatListStamp({super.key, required this.room, required this.fontSize});

  final ChatRoom room;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // The body face, never the caption slot: on a character theme that is
    // tracked mono, and "Yesterday" read as terminal output.
    return Text(
      chatListStamp(context, room.lastMessageTime ?? room.createdAt),
      maxLines: 1,
      softWrap: false,
      style: theme.bodySoft.copyWith(
        fontSize: fontSize,
        height: 1.25,
        color: chatListUnread(room) && !room.isMuted
            ? theme.accent
            : theme.inkMuted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// What the room has to say right now, best first: a call going on in it,
/// someone typing, the last message, its description, or that it is quiet.
class ChatListPreview extends StatelessWidget {
  const ChatListPreview({
    super.key,
    required this.room,
    required this.call,
    required this.typists,
    required this.fontSize,
    this.lineHeight = 1.3,
    this.maxLines = 2,
    this.surface,
  });

  final ChatRoom room;
  final LiveRoomCall? call;
  final List<ChatUser> typists;
  final double fontSize;
  final double lineHeight;
  final int maxLines;

  /// What the line sits on: the page for a row, the card for a tile. The
  /// call chip derives its fill and ink from it.
  final Color? surface;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final call = this.call;
    if (call != null) {
      // A call going on outranks what was last said, and typing.
      return Align(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: 1,
        heightFactor: 1,
        child: LiveCallChip(
          call: call,
          fontSize: fontSize - 2,
          surface: surface,
        ),
      );
    }
    if (typists.isNotEmpty) {
      return TypingLine(typists: typists, fontSize: fontSize);
    }
    final subtitle = roomSubtitle(context, room);
    return Text(
      subtitle.text,
      style: theme.bodySoft.copyWith(
        fontSize: fontSize,
        height: lineHeight,
        color: subtitle.kind == RoomSubtitleKind.message
            ? theme.inkMuted
            : theme.inkMuted.withValues(alpha: 0.7),
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// The one trailing slot: Join for a group call you can join, else the
/// unread count, else the pin; with a small controller beside it when a game
/// is waiting on your move (not a count, a turn is not a message, and not in
/// place of the badge, because both can be true).
class ChatListTrailing extends StatelessWidget {
  const ChatListTrailing({
    super.key,
    required this.room,
    required this.call,
    this.dense = false,
  });

  final ChatRoom room;
  final LiveRoomCall? call;

  /// A grid tile's corner: the smaller Join pill.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final call = this.call;
    if (LiveCallJoinPill.wants(call)) {
      return LiveCallJoinPill(call: call!, dense: dense);
    }
    final theme = ThemeScope.of(context);
    final main = _unreadOrPin(theme);
    // Only this slot listens: a turn changing elsewhere rebuilds one icon,
    // not the row.
    return ListenableBuilder(
      listenable: MatchesStore.instance,
      builder: (context, _) =>
          MatchesStore.instance.myTurnRooms.contains(room.id)
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.gamecontroller_fill,
                      size: 15,
                      color: theme.accent,
                      semanticLabel:
                          AppLocalizations.of(context).chatGameYourMove,
                    ),
                    if (main != null) ...[const SizedBox(width: 6), main],
                  ],
                )
              : main ?? const SizedBox.shrink(),
    );
  }

  Widget? _unreadOrPin(AppTheme theme) {
    if (chatListUnread(room)) {
      return RoomUnreadBadge(
        count: room.visibleUnreadCount,
        unread: room.hasUnread,
        mention: room.hasVisibleMention,
        quiet: room.isMuted,
      );
    }
    if (room.isPinned) {
      return Transform.rotate(
        angle: 0.6,
        child: Icon(CupertinoIcons.pin_fill, size: 14, color: theme.inkMuted),
      );
    }
    return null;
  }
}
