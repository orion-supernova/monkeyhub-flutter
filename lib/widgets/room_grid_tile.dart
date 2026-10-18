import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart' show HoverEffect;
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/density.dart';
import '../theme/theme_scope.dart';
import 'chat_list_parts.dart';
import 'chat_list_row.dart' show ChatRoomAvatar;
import 'ios_kit.dart' show SpringPress;
import 'live_call_row.dart';

/// The grid's measurements, phone or compact desktop. One place, so the tile
/// and the delegate that sizes it can never disagree.
@immutable
class RoomGridMetrics {
  const RoomGridMetrics._({
    required this.pad,
    required this.avatar,
    required this.gap,
    required this.name,
    required this.preview,
    required this.previewHeight,
    required this.stamp,
    required this.lineGap,
    required this.spacing,
    required this.minTile,
  });

  static RoomGridMetrics of(Density density) => density.compact
      ? const RoomGridMetrics._(
          pad: 12,
          avatar: 40,
          gap: 10,
          name: 14,
          preview: 13,
          previewHeight: 1.25,
          stamp: 12,
          lineGap: 1,
          spacing: 8,
          minTile: 148,
        )
      : const RoomGridMetrics._(
          pad: 14,
          avatar: 48,
          gap: 12,
          name: 16,
          preview: 14,
          previewHeight: 1.3,
          stamp: 13,
          lineGap: 2,
          spacing: 10,
          minTile: 156,
        );

  /// Inside the tile's edge.
  final double pad;
  final double avatar;

  /// Face to name.
  final double gap;
  final double name;
  final double preview;
  final double previewHeight;
  final double stamp;

  /// Name to preview.
  final double lineGap;

  /// Between tiles, both ways.
  final double spacing;

  /// The narrowest a tile may get before the grid drops a column. Two
  /// columns always, however narrow: one would just be a worse row.
  final double minTile;

  /// [extent] for the tiles [context] will draw: its density, its text
  /// size, and the theme's card border (a character theme's is 2pt a side).
  static double extentFor(BuildContext context) {
    final theme = ThemeScope.of(context);
    double edge(bool ephemeral) => theme
        .roomCardDecoration(ephemeral: ephemeral, active: false)
        .padding
        .vertical;
    return of(Density.of(context)).extent(
      MediaQuery.textScalerOf(context),
      chrome: math.max(edge(false), edge(true)),
    );
  }

  /// How many columns fit [width].
  int columnsFor(double width) => math.max(
        2,
        ((width + spacing) / (minTile + spacing)).floor(),
      );

  /// The tile's height at [scaler]: the face (or the stamp over the trailing
  /// slot, if large type makes that taller), the name, two preview lines.
  /// Sized from the content rather than a fixed aspect ratio, which left a
  /// hole in a wide tile and clipped a narrow one.
  double extent(TextScaler scaler, {double chrome = 0}) {
    final corner = scaler.scale(stamp) * 1.25 + 6 + 24;
    return chrome +
        pad * 2 +
        math.max(avatar, corner) +
        gap +
        scaler.scale(name) * 1.25 +
        lineGap +
        scaler.scale(preview) * previewHeight * 2 +
        2;
  }
}

/// One conversation as a tile: the chat row's content, stood up.
///
/// The face top left; the stamp over the trailing slot (unread count, pin,
/// your move, Join) top right, the same column relation a row has; then the
/// name with its quiet fact glyphs and two lines of what was said. The same
/// three tiers of type as a row and the same parts ([ChatListTitle],
/// [ChatListPreview], [ChatListTrailing]), so a call, a typist, a muted room
/// or an unread one reads the same in every layout.
///
/// What it replaced carried a horizontally scrolling strip of pills
/// (visibility, lock, hourglass, pin, mute) beside a small face, a 17pt
/// name, one preview line, a member count footer and no time at all, in a
/// box of fixed aspect ratio: busy at the top, empty in the middle.
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
    final m = RoomGridMetrics.of(Density.of(context));
    final decoration =
        theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false);
    final surface = decoration.color ?? theme.surface;
    final title = chatListTitleOf(context, room, dmUser);
    final radius =
        decoration.borderRadius?.resolve(Directionality.of(context)) ??
            BorderRadius.circular(theme.radiusLg);
    // THE press: a spring under the finger, a tint under the pointer and a
    // keyboard focus stop.
    return SpringPress(
      onTap: onTap,
      scale: 0.97,
      haptic: false,
      hover: HoverEffect.tint,
      hoverRadius: radius.topLeft.x,
      focusRadius: radius.topLeft.x,
      semanticLabel: title,
      child: Container(
        decoration: decoration,
        padding: EdgeInsets.all(m.pad),
        child: RoomLiveCallBuilder(
          roomId: room.id,
          builder: (context, call) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LiveCallHalo(
                    call: call,
                    size: m.avatar,
                    rim: surface,
                    child: ChatRoomAvatar(
                      room: room,
                      dmUser: dmUser,
                      api: api,
                      size: m.avatar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ChatListStamp(room: room, fontSize: m.stamp),
                        const SizedBox(height: 6),
                        // Scales down rather than overflows: a long "Join"
                        // in a narrow corner shrinks a little instead.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: ChatListTrailing(
                            room: room,
                            call: call,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: m.gap),
              ChatListTitle(room: room, title: title, fontSize: m.name),
              SizedBox(height: m.lineGap),
              ChatListPreview(
                room: room,
                call: call,
                typists: typists,
                fontSize: m.preview,
                lineHeight: m.previewHeight,
                surface: surface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
