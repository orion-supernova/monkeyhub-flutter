import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart' show HoverEffect;
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/density.dart';
import '../theme/theme_scope.dart';
import 'chat_list_parts.dart';
import 'chat_list_row.dart' show ChatRoomAvatar;
import 'ios_kit.dart' show SpringPress, groupedMetaStyle;
import 'live_call_row.dart';
import 'visibility_badge.dart' show ephemeralShort;

/// One conversation on its own card: a chat row with room to breathe, plus
/// the one thing a row leaves out, the room's facts spelled out in words.
///
/// The row's layout and parts inside ([ChatListTitle], [ChatListPreview],
/// [ChatListTrailing]): a face, the name and the time, two lines of what was
/// said, the unread count in the one trailing slot. Under the preview, for a
/// group, a quiet meta line: how many are inside, public or private, locked,
/// how long messages last. Glyph and word, no pills.
///
/// What it replaced led with a wrapped row of outlined pills, put a 32pt face
/// beside a display-size name, cut the preview to one line and ended on a
/// member count and an "↗ Enter" footer: the facts shouted and the
/// conversation, the thing a list is for, whispered.
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
    final density = Density.of(context);
    final decoration =
        theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false);
    final surface = decoration.color ?? theme.surface;
    final title = chatListTitleOf(context, room, dmUser);
    final radius =
        decoration.borderRadius?.resolve(Directionality.of(context)).topLeft.x ??
            theme.radiusLg;
    final face = density.chatRowAvatar - 2;
    final facts = _facts(context, theme);
    // The margin sits outside the press so the ring and the hover fill hug
    // the card, not the gap under it.
    return Padding(
      padding: EdgeInsets.only(bottom: density.compact ? 8 : 10),
      child: SpringPress(
        onTap: onTap,
        scale: 0.985,
        haptic: false,
        hover: HoverEffect.tint,
        hoverRadius: radius,
        focusRadius: radius,
        semanticLabel: title,
        child: Container(
          decoration: decoration,
          padding: EdgeInsets.fromLTRB(
            density.compact ? 12 : 14,
            density.compact ? 10 : 13,
            density.compact ? 12 : 14,
            density.compact ? 10 : 13,
          ),
          child: RoomLiveCallBuilder(
            roomId: room.id,
            builder: (context, call) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiveCallHalo(
                  call: call,
                  size: face,
                  rim: surface,
                  child: ChatRoomAvatar(
                    room: room,
                    dmUser: dmUser,
                    api: api,
                    size: face,
                  ),
                ),
                SizedBox(width: density.chatRowGap - 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ChatListTitle(
                              room: room,
                              title: title,
                              fontSize: density.chatRowTitleSize,
                              facts: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChatListStamp(
                            room: room,
                            fontSize: density.chatRowStampSize - 1,
                          ),
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
                              typists: typists,
                              fontSize: density.chatRowPreviewSize,
                              lineHeight: density.chatRowPreviewHeight,
                              surface: surface,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: ChatListTrailing(room: room, call: call),
                          ),
                        ],
                      ),
                      if (facts.isNotEmpty) ...[
                        SizedBox(height: density.compact ? 6 : 9),
                        _MetaLine(facts: facts),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The room's facts, rarest and most consequential first, so a long
  /// language ellipsizes the member count, never "messages disappear". None for a DM that is not secret: two people, private
  /// by definition, and the face already says who.
  List<_Fact> _facts(BuildContext context, AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final ttl = room.messageLifetime;
    return [
      if (room.isEphemeral && ttl != null)
        _Fact(
          (s, c) => theme.hourglassIcon(size: s, color: c),
          l10n.enterPublicRoomEphemeralBadgeLabel(ephemeralShort(l10n, ttl)),
        ),
      if (room.hasPassword)
        _Fact(
          (s, c) => Icon(CupertinoIcons.lock_fill, size: s, color: c),
          l10n.roomCardLockedBadge,
        ),
      if (!room.isDm && !room.isSavedMessages)
        _Fact(
          (s, c) => Icon(CupertinoIcons.person_2_fill, size: s + 2, color: c),
          l10n.roomCardMemberCount(room.memberCount),
        ),
      if (!room.isDm && !room.isSavedMessages)
        _Fact(
          (s, c) => theme.visibilityIcon(isPublic: room.isPublic, size: s),
          room.isPublic
              ? l10n.enterPublicRoomVisibilityPublicLabel
              : l10n.enterPublicRoomVisibilityPrivateLabel,
        ),
    ];
  }
}

class _Fact {
  const _Fact(this.glyph, this.label);
  final Widget Function(double size, Color color) glyph;
  final String label;
}

/// The facts on one line: glyph and word pairs with air between them, and an
/// ellipsis rather than a second line when a language runs long.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.facts});
  final List<_Fact> facts;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final style = groupedMetaStyle(theme).copyWith(
      fontSize: Density.of(context).compact ? 12 : 13,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final g = (style.fontSize! * 0.85).roundToDouble();
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            if (i > 0) const TextSpan(text: '   '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: IconTheme(
                  data: IconThemeData(color: theme.inkMuted),
                  child: facts[i].glyph(g, theme.inkMuted),
                ),
              ),
            ),
            TextSpan(text: facts[i].label),
          ],
        ],
      ),
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
