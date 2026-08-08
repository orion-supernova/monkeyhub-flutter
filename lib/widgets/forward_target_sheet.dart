import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;
import 'selection_check.dart';
import 'user_avatar.dart';

/// Most rooms one forward may target at once.
///
/// The server caps messages per call, not rooms — the client issues one call
/// per room — so this is a UI bound rather than a validation. Five is where a
/// "share to everyone" reflex starts producing something the recipients would
/// call spam.
const int kMaxForwardTargets = 5;

/// Picks which chats to forward into.
///
/// Reads rooms from [ChatRepository.rooms] rather than querying
/// `rooms:listUserRooms`: the repository is already subscribed to it, and a
/// fresh query would re-run the server's per-room unread computation to render
/// a list that shows no unread badges.
///
/// Returns the chosen rooms, or null if dismissed.
Future<List<ChatRoom>?> showForwardTargetSheet(
  BuildContext context, {
  required ChatRepository repo,
  required int messageCount,

  /// Excluded from the list — forwarding a room's messages back into itself is
  /// refused by the server (`SAME_ROOM`) and would read as a bug if offered.
  required String excludeRoomId,
}) {
  return showAdaptiveSheet<List<ChatRoom>>(
    context,
    builder: (_) => _ForwardTargetSheet(
      repo: repo,
      messageCount: messageCount,
      excludeRoomId: excludeRoomId,
    ),
  );
}

class _ForwardTargetSheet extends StatefulWidget {
  const _ForwardTargetSheet({
    required this.repo,
    required this.messageCount,
    required this.excludeRoomId,
  });

  final ChatRepository repo;
  final int messageCount;
  final String excludeRoomId;

  @override
  State<_ForwardTargetSheet> createState() => _ForwardTargetSheetState();
}

class _ForwardTargetSheetState extends State<_ForwardTargetSheet> {
  final Set<String> _picked = {};
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _titleOf(ChatRoom room) {
    if (room.isSavedMessages) return AppLocalizations.of(context).savedMessagesTitle;
    if (!room.isDm) return room.name;
    // A DM's stored name is the internal `dm:<a>:<b>` key, never something to
    // render. The peer's profile is the title; falling back to "direct
    // message" covers a roster the client hasn't cached yet.
    return widget.repo.otherUserFor(room)?.name ??
        AppLocalizations.of(context).approvalsScreenForwardDirectMessageFallback;
  }

  List<ChatRoom> get _visible {
    final q = _search.text.trim().toLowerCase();
    final out = <ChatRoom>[];
    for (final r in widget.repo.rooms) {
      if (r.id == widget.excludeRoomId) continue;
      if (!r.isMember) continue;
      if (q.isNotEmpty && !_titleOf(r).toLowerCase().contains(q)) continue;
      out.add(r);
    }
    // Most recently active first — the room someone wants to forward into is
    // overwhelmingly one they were just in.
    out.sort((a, b) {
      final at = a.lastMessageTime, bt = b.lastMessageTime;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return out;
  }

  void _toggle(ChatRoom room) {
    setState(() {
      if (_picked.remove(room.id)) return;
      if (_picked.length >= kMaxForwardTargets) {
        HapticFeedback.heavyImpact();
        return;
      }
      _picked.add(room.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final rooms = _visible;
    final n = widget.messageCount;

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: theme.body.copyWith(color: theme.ink),
        child: Container(
          decoration: theme.sheetDecoration(),
          padding: EdgeInsets.fromLTRB(
              22, 14, 22, 22 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetGrabber(),
              Text(
                loc.approvalsScreenForwardTitle(n),
                style: theme.label.copyWith(letterSpacing: 2.4),
              ),
              const SizedBox(height: 12),
              _SearchField(
                controller: _search,
                theme: theme,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: rooms.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 26),
                        child: Text(
                          _search.text.trim().isEmpty
                              ? loc.approvalsScreenForwardNoChatsYet
                              : loc.approvalsScreenForwardNoMatches,
                          textAlign: TextAlign.center,
                          style: theme.bodySoft,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: rooms.length,
                        itemBuilder: (_, i) => _RoomRow(
                          room: rooms[i],
                          title: _titleOf(rooms[i]),
                          repo: widget.repo,
                          picked: _picked.contains(rooms[i].id),
                          onTap: () => _toggle(rooms[i]),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              _SendButton(
                theme: theme,
                count: _picked.length,
                onTap: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          [for (final r in rooms) if (_picked.contains(r.id)) r],
                        ),
              ),
              if (_picked.length >= kMaxForwardTargets) ...[
                const SizedBox(height: 8),
                Text(
                  loc.approvalsScreenForwardMaxTargetsHint(kMaxForwardTargets),
                  textAlign: TextAlign.center,
                  style: theme.caption.copyWith(color: theme.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.theme,
    required this.onChanged,
  });

  final TextEditingController controller;
  final AppTheme theme;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      decoration: theme.inputDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 15, color: theme.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: theme.body.copyWith(color: theme.ink),
              cursorColor: theme.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: loc.approvalsScreenForwardSearchHint,
                hintStyle: theme.bodySoft.copyWith(color: theme.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.title,
    required this.repo,
    required this.picked,
    required this.onTap,
  });

  final ChatRoom room;
  final String title;
  final ChatRepository repo;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final peer = room.isDm ? repo.otherUserFor(room) : null;

    // `FocusableTap` registers no gesture recognizer of its own, so the bare
    // `GestureDetector` inside is what actually receives the pointer. Both
    // carry the handler; wrapping alone would render a row that does nothing.
    // Never an InkWell — this app draws no ink anywhere.
    return FocusableTap(
      onTap: onTap,
      semanticLabel: picked
          ? loc.approvalsScreenForwardDeselectSemantic(title)
          : loc.approvalsScreenForwardSelectSemantic(title),
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: picked ? theme.accent.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(
              color: picked ? theme.accent : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              if (peer != null)
                UserAvatar(user: peer, size: 32, api: repo.api)
              else
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.surfaceRaised,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.divider, width: 0.8),
                  ),
                  child: Icon(
                    room.isEphemeral
                        ? CupertinoIcons.timer
                        : CupertinoIcons.person_2,
                    size: 15,
                    color: theme.inkMuted,
                  ),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyEmph.copyWith(color: theme.ink),
                ),
              ),
              if (room.isEphemeral)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    loc.approvalsScreenForwardFadesBadge,
                    style: theme.monoTiny.copyWith(color: theme.inkMuted),
                  ),
                ),
              const SizedBox(width: 8),
              SelectionCheck(picked: picked),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.theme,
    required this.count,
    required this.onTap,
  });

  final AppTheme theme;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final enabled = onTap != null;
    return FocusableTap(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: loc.approvalsScreenForwardSendSemantic,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? theme.accent : theme.surfaceSunken,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            loc.approvalsScreenForwardSendButton(count),
            style: theme.label.copyWith(
              letterSpacing: 2.0,
              color: enabled ? theme.accentInk : theme.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
