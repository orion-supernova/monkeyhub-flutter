import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/matches_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/app_theme.dart';
import '../theme/density.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';
import 'remote_image.dart';
import 'room_identity.dart';
import 'typing_indicator.dart';
import 'user_avatar.dart';
import 'teardown_safe.dart';

/// Avatar diameter on a chat row. Telegram and Messages both sit between 52
/// and 60; 54 keeps a two-line preview level with the avatar's own height.
/// The phone value: the row itself reads [Density.chatRowAvatar], which is 44
/// in the compact desktop layout.
const double kChatRowAvatar = 54;

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
/// No card, no border, no shadow. Rows are separated by an inset hairline
/// that starts where the text does ([kChatRowTextInset]), the Messages
/// pattern — the avatars form their own column and need no rule between them.
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

  /// False on the last row of a group, so a section ends on content rather
  /// than on a rule.
  final bool showDivider;

  @override
  State<ChatListRow> createState() => _ChatListRowState();
}

class _ChatListRowState extends State<ChatListRow>
    with TeardownSafe<ChatListRow> {
  /// Pressed highlight — a flat fill, the iOS table-cell treatment. Never a
  /// ripple.
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final room = widget.room;
    final l10n = AppLocalizations.of(context);
    final unread = room.visibleUnreadCount > 0 || room.hasUnread;

    final title = room.isSavedMessages
        ? l10n.savedMessagesTitle
        : (widget.dmUser?.displayName ?? room.name);
    final stamp = room.lastMessageTime ?? room.createdAt;
    final density = Density.of(context);

    // FocusableTap so a keyboard can reach the row (Tab, then Enter); the
    // pointer press stays the flat table-cell fill below, not a spring — a
    // whole row scaling would read as the list wobbling.
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: title,
      radius: theme.radiusLg,
      // The same rounded fill the press draws, at a whisper: a mouse over a
      // conversation lights it before the click opens it.
      hover: HoverEffect.tint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedContainer(
          duration: _pressed ? Duration.zero : theme.motionFast,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _pressed ? theme.ink.withValues(alpha: 0.06) : null,
            borderRadius: BorderRadius.circular(theme.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: density.chatRowPadding,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _avatar(theme, density),
                      SizedBox(width: density.chatRowGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _titleLine(
                              context,
                              theme,
                              density,
                              title,
                              stamp,
                              unread,
                            ),
                            SizedBox(height: density.chatRowLineGap),
                            _previewLine(context, theme, density),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showDivider)
                  Positioned(
                    left: density.chatRowTextInset,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      // One physical pixel, the iOS separator — 0.5pt is
                      // 1.5px on a 3x phone and reads as a drawn line.
                      height: 1 / MediaQuery.devicePixelRatioOf(context),
                      color: _hairline(theme),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The theme's divider is tuned for cards on a surface; a rule straight on
  /// the page background wants a touch more presence to be seen at 0.5pt.
  Color _hairline(AppTheme theme) =>
      Color.alphaBlend(theme.ink.withValues(alpha: 0.05), theme.divider);

  Widget _avatar(AppTheme theme, Density density) => ChatRoomAvatar(
        room: widget.room,
        dmUser: widget.dmUser,
        api: widget.api,
        size: density.chatRowAvatar,
      );

  Widget _titleLine(
    BuildContext context,
    AppTheme theme,
    Density density,
    String title,
    DateTime stamp,
    bool unread,
  ) {
    final room = widget.room;
    final glyph = theme.inkMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The name takes whatever the stamp leaves, and the glyphs ride
        // directly after it rather than being pushed to the stamp.
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: theme.bodyEmph.copyWith(
                    color: theme.ink,
                    fontSize: density.chatRowTitleSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Facts about the room, not about its traffic: the quietest
              // ink, there when looked for and invisible otherwise.
              if (room.isEphemeral) ...[
                const SizedBox(width: 5),
                theme.hourglassIcon(size: 13, color: glyph),
              ],
              if (room.hasPassword) ...[
                const SizedBox(width: 4),
                Icon(CupertinoIcons.lock_fill, size: 12, color: glyph),
              ],
              if (room.isMuted) ...[
                const SizedBox(width: 4),
                Icon(CupertinoIcons.bell_slash_fill, size: 12, color: glyph),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        // The body face at 15, never the caption slot: on a character theme
        // that is tracked mono, and "Yesterday" read as terminal output.
        Text(
          chatListStamp(context, stamp),
          style: theme.bodySoft.copyWith(
            fontSize: density.chatRowStampSize,
            color: unread && !room.isMuted ? theme.accent : theme.inkMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _previewLine(BuildContext context, AppTheme theme, Density density) {
    final room = widget.room;
    final Widget text;
    if (widget.typists.isNotEmpty) {
      text = TypingLine(typists: widget.typists);
    } else {
      final subtitle = roomSubtitle(context, room);
      text = Text(
        subtitle.text,
        style: theme.bodySoft.copyWith(
          fontSize: density.chatRowPreviewSize,
          height: density.chatRowPreviewHeight,
          color: subtitle.kind == RoomSubtitleKind.message
              ? theme.inkMuted
              : theme.inkMuted.withValues(alpha: 0.7),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: text),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _trailing(theme),
        ),
      ],
    );
  }

  /// Unread count, or the pin when there is nothing unread. One slot, one
  /// thing in it — the Telegram arrangement.
  ///
  /// A game waiting on the viewer's move rides beside it as a small controller
  /// glyph: not a count (a turn is not a message), and not in place of the
  /// unread badge, because both can be true and both are worth knowing.
  Widget _trailing(AppTheme theme) {
    final room = widget.room;
    final count = room.unreadCount;
    final main = _unreadOrPin(theme, room, count);
    // Only this slot listens: a turn changing elsewhere rebuilds one icon,
    // not the row.
    return ListenableBuilder(
      listenable: MatchesStore.instance,
      builder: (context, _) =>
          MatchesStore.instance.myTurnRooms.contains(room.id)
          ? _withTurn(theme, main)
          : main,
    );
  }

  Widget _withTurn(AppTheme theme, Widget main) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.gamecontroller_fill,
          size: 15,
          color: theme.accent,
          semanticLabel: AppLocalizations.of(context).chatGameYourMove,
        ),
        if (main is! SizedBox) ...[const SizedBox(width: 6), main],
      ],
    );
  }

  Widget _unreadOrPin(AppTheme theme, ChatRoom room, int count) {
    if (count > 0 || room.hasUnread) {
      return RoomUnreadBadge(
        count: count,
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
    return const SizedBox.shrink();
  }


}

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
    final letter =
        trimmed.isEmpty ? '#' : trimmed.characters.first.toUpperCase();
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

/// The time beside a row, the way Messages writes it: the clock today,
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
