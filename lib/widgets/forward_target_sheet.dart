import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart';
import 'adaptive_sheet.dart';
import 'chat_list_row.dart' show ChatRoomAvatar;
import 'search_field.dart';
import 'sheet_kit.dart';
import '../l10n/text_case.dart';

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
      // No `isMember` test — see the note in `buildShareTargets`. The field is
      // `rooms:listPublic`'s alone and is false on everything this list holds,
      // so filtering on it emptied the sheet outright.
      // A write-only feed the app posts into is not a place to put things.
      if (!widget.repo.capabilitiesFor(r).canReceiveForwards) continue;
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
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);

    return SheetFrame(
      title: sentenceCaseOf(context, loc.approvalsScreenForwardTitle(n)),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: DefaultTextStyle(
        style: theme.body.copyWith(color: theme.ink),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // THE search bar — the same pill, magnifier and clear button as
            // the share sheet and the new-chat sheet, not a sunken box.
            SearchField(
              controller: _search,
              hintText: loc.chatTargetSearchHint,
              onChanged: (_) => setState(() {}),
              onClear: () => setState(() {}),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: rooms.isEmpty
                  ? EmptyLine(
                      _search.text.trim().isEmpty
                          ? loc.approvalsScreenForwardNoChatsYet
                          : loc.approvalsScreenForwardNoMatches,
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: rooms.length,
                      itemBuilder: (_, i) => Stack(
                        key: ValueKey(rooms[i].id),
                        children: [
                          _RoomRow(
                            room: rooms[i],
                            title: _titleOf(rooms[i]),
                            repo: widget.repo,
                            picked: _picked.contains(rooms[i].id),
                            onTap: () => _toggle(rooms[i]),
                          ),
                          // The Contacts rule: a hairline from the text on,
                          // none under the last row.
                          if (i < rooms.length - 1)
                            Positioned(
                              left: kPersonRowTextInset,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                height: hairline,
                                color: theme.ink.withValues(alpha: 0.10),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: loc.approvalsScreenForwardSendSemantic,
              child: SheetActionButton(
                label: loc.approvalsScreenForwardSendButton(_picked.length),
                onTap: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          [for (final r in rooms) if (_picked.contains(r.id)) r],
                        ),
              ),
            ),
            if (_picked.length >= kMaxForwardTargets) ...[
              const SizedBox(height: 8),
              Text(
                loc.approvalsScreenForwardMaxTargetsHint(kMaxForwardTargets),
                textAlign: TextAlign.center,
                style: groupedMetaStyle(theme),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A destination: the room's real face (its picture, the DM peer, or its
/// monogram — never a generic people glyph), its name at row-title weight,
/// a quiet "fades" tag for ephemeral rooms and the selection circle. Drawn by
/// the shared [PersonRow].
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
    return PersonRow(
      avatar: ChatRoomAvatar(
        room: room,
        dmUser: room.isDm ? repo.otherUserFor(room) : null,
        api: repo.api,
        size: kPersonRowAvatar,
      ),
      title: title,
      titleTrailing: room.isEphemeral
          ? Text(
              loc.approvalsScreenForwardFadesBadge,
              style: groupedMetaStyle(theme),
            )
          : null,
      trailing: SelectionCheck(picked: picked),
      semanticLabel: picked
          ? loc.approvalsScreenForwardDeselectSemantic(title)
          : loc.approvalsScreenForwardSelectSemantic(title),
      onTap: onTap,
    );
  }
}
