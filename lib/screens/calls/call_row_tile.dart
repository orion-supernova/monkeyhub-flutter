import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../calls/call_models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_room.dart';
import '../../models/chat_user.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/chat_list_row.dart' show ChatRoomAvatar, MonogramAvatar;
import '../../widgets/chat_row_action_menu.dart' show ChatRowLongPress;
import '../../widgets/chat_row_swipe.dart';
import '../../widgets/glass_buttons.dart';
import '../../widgets/pull_down_menu.dart';
import '../../widgets/spring_press.dart';
import '../../widgets/user_avatar.dart';
import 'call_log_models.dart';
import 'calls_directory.dart';
import 'calls_format.dart';

/// Who or what a call row is about, resolved from what the app already holds.
class CallSubject {
  const CallSubject({required this.name, required this.avatar, this.room, this.user});
  final String name;
  final Widget Function(double size) avatar;
  final ChatRoom? room;
  final ChatUser? user;
}

/// Resolves [e]'s room and peer. Never copies profile data: this runs at build
/// time, so a renamed friend or a new picture shows on the next frame.
CallSubject resolveSubject(
  AppLocalizations l10n,
  CallsDirectory dir,
  ChatApi? api,
  CallLogEntry e,
) {
  final room = dir.room(e.roomId);
  final user = e.kind == CallLogKind.direct && e.peerId != null
      ? dir.user(e.peerId!)
      : null;
  if (user != null) {
    return CallSubject(
      name: user.displayName,
      room: room,
      user: user,
      avatar: (s) => UserAvatar(user: user, size: s, api: api, showStatus: false),
    );
  }
  if (room != null && !(e.kind == CallLogKind.direct && room.isDm)) {
    return CallSubject(
      name: room.name,
      room: room,
      avatar: (s) => ChatRoomAvatar(room: room, size: s, api: api),
    );
  }
  final gone = room == null;
  return CallSubject(
    name: gone ? l10n.callsTabDeletedChat : l10n.callsTabUnknown,
    room: room,
    avatar: (s) => MonogramAvatar(label: '?', seed: e.roomId, size: s),
  );
}

enum CallRowAction { voice, video, chat, addFavourite, removeFavourite, delete }

/// One line of the Calls list: a swipeable, holdable, tappable row. Merged
/// consecutive calls ([row] with several entries) say "(3)" after the call,
/// as the iPhone's Recents does, and open the details sheet with each of
/// them under "Call history".
class CallRowTile extends StatefulWidget {
  const CallRowTile({
    super.key,
    required this.row,
    required this.directory,
    required this.api,
    required this.onOpenDetails,
    required this.onAction,
    this.favourite,
  });

  /// Whether the row's person is pinned; null for rows with no single person
  /// to pin (group calls, people not in the friend list).
  final bool? favourite;

  final CallRow row;
  final CallsDirectory directory;
  final ChatApi? api;
  final void Function(CallRow row) onOpenDetails;
  final void Function(CallRow row, CallRowAction action) onAction;

  @override
  State<CallRowTile> createState() => _CallRowTileState();
}

class _CallRowTileState extends State<CallRowTile> {
  final GlobalKey _anchor = GlobalKey(debugLabel: 'call-row');

  Future<void> _menu() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPullDownMenu<CallRowAction>(
      context: context,
      anchorKey: _anchor,
      items: [
        PullDownItem(
          value: CallRowAction.voice,
          label: l10n.callsTabVoiceCall,
          icon: CupertinoIcons.phone,
        ),
        PullDownItem(
          value: CallRowAction.video,
          label: l10n.callsTabVideoCall,
          icon: CupertinoIcons.video_camera,
        ),
        PullDownItem(
          value: CallRowAction.chat,
          label: l10n.callsTabOpenChat,
          icon: CupertinoIcons.bubble_left,
        ),
        if (widget.favourite != null)
          PullDownItem(
            value: widget.favourite!
                ? CallRowAction.removeFavourite
                : CallRowAction.addFavourite,
            label: widget.favourite! ? l10n.callsTabFavRemove : l10n.callsTabFavAdd,
            icon: widget.favourite!
                ? CupertinoIcons.star_slash
                : CupertinoIcons.star,
          ),
        PullDownItem(
          value: CallRowAction.delete,
          label: l10n.callsTabDeleteFromHistory,
          icon: CupertinoIcons.delete,
          destructive: true,
          startsGroup: true,
        ),
      ],
    );
    if (picked != null && mounted) widget.onAction(widget.row, picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final row = widget.row;
    final e = row.first;
    final subject = resolveSubject(l10n, widget.directory, widget.api, e);
    final missed = e.isMissed;
    final merged = row.count > 1;
    // How long it lasted rides in the sentence ("Outgoing video call · 12:34"),
    // never as a bare second number under the time where it reads as a clock.
    final detail = e.wasAnswered && e.durationMs > 0 && !merged
        ? '${callDetail(l10n, e)} · ${clockDuration(e.durationMs)}'
        : merged
            ? '${callDetail(l10n, e)} (${row.count})'
            : callDetail(l10n, e);
    final time = clockTime(context, e.startedAt);
    final nameColor = missed ? theme.danger : theme.ink;
    // Swipe left: Delete (a full swipe commits it). Calling back lives in the
    // two buttons on the row, so there is no swipe-right.
    return ChatRowSwipe(
      trailing: [
        SwipeAction(
          label: l10n.messageActionMenuDeleteLabel,
          icon: CupertinoIcons.delete_solid,
          color: const Color(0xFFFF3B30),
          onTap: () => widget.onAction(row, CallRowAction.delete),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatRowLongPress(
            key: _anchor,
            onLongPress: _menu,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Row(
                children: [
                  Expanded(
                    child: SpringPress(
                      onTap: () => widget.onOpenDetails(row),
                      scale: 0.985,
                      haptic: false,
                      semanticLabel:
                          l10n.callsTabRowSemantic(detail, subject.name, time),
                      focusRadius: 14,
                      hoverRadius: 14,
                      builder: (context, pressed) => Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            20, 10, 4, 10),
                        child: Row(
                          children: [
                            subject.avatar(48),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.bodyEmph.copyWith(
                                      fontSize: 16,
                                      color: nameColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        e.incoming
                                            ? CupertinoIcons.arrow_down_left
                                            : CupertinoIcons.arrow_up_right,
                                        size: 13,
                                        color: missed
                                            ? theme.danger
                                            : theme.inkMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          detail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.bodySoft.copyWith(
                                            fontSize: 14,
                                            color: missed
                                                ? theme.danger
                                                : theme.inkMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    time,
                                    maxLines: 1,
                                    style: theme.bodySoft.copyWith(
                                      fontSize: 13,
                                      color: theme.inkMuted,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Calling back is a visible control, not a gesture. `still`:
                  // the row slides, so no backdrop blur under the discs.
                  GlassIconButton(
                    icon: CupertinoIcons.phone_fill,
                    size: 44,
                    iconSize: 19,
                    still: true,
                    color: theme.accent,
                    semanticLabel: l10n.callsTabVoiceCall,
                    onTap: () => widget.onAction(row, CallRowAction.voice),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: CupertinoIcons.videocam_fill,
                    size: 44,
                    iconSize: 20,
                    still: true,
                    color: theme.accent,
                    semanticLabel: l10n.callsTabVideoCall,
                    onTap: () => widget.onAction(row, CallRowAction.video),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which [CallMediaKind] a row action means.
CallMediaKind? kindOf(CallRowAction a) => switch (a) {
      CallRowAction.voice => CallMediaKind.audio,
      CallRowAction.video => CallMediaKind.video,
      _ => null,
    };
