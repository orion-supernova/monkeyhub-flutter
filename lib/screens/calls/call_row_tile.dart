import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../calls/call_models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_room.dart';
import '../../models/chat_user.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/chat_list_row.dart' show ChatRoomAvatar, MonogramAvatar;
import '../../widgets/chat_row_action_menu.dart' show ChatRowLongPress;
import '../../widgets/chat_row_swipe.dart';
import '../../widgets/count_badge.dart';
import '../../widgets/glass_buttons.dart';
import '../../widgets/ios_kit.dart' show quietFill;
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
/// consecutive calls ([row] with several entries) show "x3" and open into
/// their individual times on tap.
class CallRowTile extends StatefulWidget {
  const CallRowTile({
    super.key,
    required this.row,
    required this.directory,
    required this.api,
    required this.expanded,
    required this.onToggleExpanded,
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
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final void Function(CallLogEntry entry) onOpenDetails;
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
        : callDetail(l10n, e);
    final time = clockTime(context, e.startedAt);
    // A stack spans its first call to its last ("19:52 – 19:56"), so the row
    // never repeats a time the list under it already shows.
    final earliest = merged ? clockTime(context, row.entries.last.startedAt) : time;
    final span = earliest == time ? time : '$earliest – $time';
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
                      onTap: merged
                          ? widget.onToggleExpanded
                          : () => widget.onOpenDetails(e),
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          subject.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.bodyEmph.copyWith(
                                            fontSize: 16,
                                            color: nameColor,
                                          ),
                                        ),
                                      ),
                                      if (merged) ...[
                                        const SizedBox(width: 8),
                                        // The call bubble's run pill, so a
                                        // stack reads the same in a chat and
                                        // here; the chevron says it opens.
                                        _StackPill(
                                          count: row.count,
                                          missed: missed,
                                          open: widget.expanded,
                                        ),
                                      ],
                                    ],
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
                                    span,
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
          // The merged calls, one line each, springing open under the row.
          AnimatedSize(
            duration: const Duration(milliseconds: 460),
            curve: const ElasticOutCurve(0.9),
            alignment: Alignment.topCenter,
            child: merged && widget.expanded
                ? _StackCard(
                    entries: row.entries,
                    onOpen: widget.onOpenDetails,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// The "×3" pill beside a stacked row's name: [CountBadge.label] as the call
/// bubble draws its run, red for missed calls, with a chevron that turns as
/// the stack opens.
class _StackPill extends StatelessWidget {
  const _StackPill({
    required this.count,
    required this.missed,
    required this.open,
  });
  final int count;
  final bool missed;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = missed ? Colors.white : theme.inkSoft;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CountBadge.label(
          text: AppLocalizations.of(context).callBubbleRunBadge(count),
          fill: missed ? theme.danger : quietFill(theme),
          ink: ink,
        ),
        const SizedBox(width: 4),
        AnimatedRotation(
          turns: open ? 0.5 : 0,
          duration: MotionScope.of(context).d(theme.motionFast),
          curve: Curves.easeOutCubic,
          child: Icon(
            CupertinoIcons.chevron_down,
            size: 12,
            color: theme.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// A stack's calls, opened: a line of time capsules under the row's text,
/// newest first, each opening that call's details. No card and no dividers:
/// the row already says who and what, so each call is only its time (and,
/// when they talked, how long).
class _StackCard extends StatelessWidget {
  const _StackCard({required this.entries, required this.onOpen});
  final List<CallLogEntry> entries;
  final void Function(CallLogEntry entry) onOpen;

  @override
  Widget build(BuildContext context) => Padding(
        // Under the name: 20 page inset + 48 avatar + 12 gap.
        padding: const EdgeInsetsDirectional.fromSTEB(80, 0, 20, 12),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < entries.length; i++)
                _SubCall(
                  entry: entries[i],
                  index: i,
                  onTap: () => onOpen(entries[i]),
                ),
            ],
          ),
        ),
      );
}

/// One call of an opened stack: a quiet capsule with its time, rising into
/// place a beat after the one before it.
class _SubCall extends StatelessWidget {
  const _SubCall({
    required this.entry,
    required this.index,
    required this.onTap,
  });
  final CallLogEntry entry;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final missed = entry.isMissed;
    final talked = entry.wasAnswered && entry.durationMs > 0;
    final ink = missed ? theme.danger : theme.ink;
    final figures = const [FontFeature.tabularFigures()];
    final motion = MotionScope.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.d(Duration(milliseconds: 260 + 50 * index.clamp(0, 6))),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 6),
          child: child,
        ),
      ),
      child: SpringPress(
        onTap: onTap,
        scale: PressSpec.scaleSmall,
        haptic: false,
        focusRadius: 15,
        hoverRadius: 15,
        semanticLabel: clockTime(context, entry.startedAt),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: ShapeDecoration(
            color: missed
                ? theme.danger.withValues(alpha: 0.14)
                : quietFill(theme),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                clockTime(context, entry.startedAt),
                style: theme.bodyEmph.copyWith(
                  fontSize: 13.5,
                  color: ink,
                  fontFeatures: figures,
                ),
              ),
              if (talked) ...[
                const SizedBox(width: 6),
                Text(
                  clockDuration(entry.durationMs),
                  style: theme.bodySoft.copyWith(
                    fontSize: 13,
                    color: theme.inkMuted,
                    fontFeatures: figures,
                  ),
                ),
              ],
            ],
          ),
        ),
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
