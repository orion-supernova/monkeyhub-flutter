import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../models/enums.dart';
import '../models/family.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart';

/// Confirms taking a person away from a child, spelling out what gets deleted.
///
/// Removing a contact wipes the conversation for BOTH of them — that's the
/// point (the child shouldn't keep the history of someone they're no longer
/// allowed to talk to) but it's destructive to the other person's data too,
/// so it never happens without this.
///
/// Callers skip this entirely when [preview] `isEmpty` — asking "are you sure?"
/// about nothing is just friction.
///
/// Returns true when the parent confirmed.
Future<bool> showRemoveContactSheet(
  BuildContext context, {
  required String contactName,
  required String childName,
  required ContactRemovalPreview preview,
  required ChatApi api,
}) async {
  final res = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _RemoveContactSheet(
      contactName: contactName,
      childName: childName,
      preview: preview,
      api: api,
    ),
  );
  return res ?? false;
}

class _RemoveContactSheet extends StatelessWidget {
  const _RemoveContactSheet({
    required this.contactName,
    required this.childName,
    required this.preview,
    required this.api,
  });

  final String contactName;
  final String childName;
  final ContactRemovalPreview preview;
  final ChatApi api;

  String get _chatsPhrase {
    final n = preview.dmCount;
    return n == 1 ? '1 chat' : '$n chats';
  }

  String get _messagesPhrase {
    final n = preview.messageCount;
    return n == 1 ? '1 message' : '$n messages';
  }

  /// "last message 3 days ago" — makes "active" concrete, which is the whole
  /// reason a parent wants warning before this happens.
  String? get _lastSeenPhrase {
    final at = preview.lastMessageAt;
    if (at == null) return null;
    final ago = DateTime.now().difference(at);
    if (ago.inMinutes < 60) return 'last message just now';
    if (ago.inHours < 24) return 'last message ${ago.inHours}h ago';
    if (ago.inDays == 1) return 'last message yesterday';
    if (ago.inDays < 30) return 'last message ${ago.inDays} days ago';
    return 'last message a while ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // RoomBrief carries only what the queue needs; SharedRoomsPanel renders
    // ChatRoom, so adapt rather than duplicating the row widget.
    final shared = preview.sharedGroupRooms
        .map((r) => ChatRoom(
              id: r.id,
              name: r.name,
              createdBy: '',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              isPrivate: false,
              memberCount: r.memberCount,
              avatarStorageId: r.avatarStorageId,
              type: RoomType.regular,
            ))
        .toList();
    final hasChats = preview.dmCount > 0;

    return Container(
      decoration: theme.sheetDecoration(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
            Text('TAKE BACK',
                style: theme.label
                    .copyWith(color: theme.danger, letterSpacing: 2)),
            const SizedBox(height: 6),
            Text('take $contactName away from $childName?',
                style: theme.displayMedium),
            const SizedBox(height: 6),
            Text(
              hasChats
                  ? 'they won\'t be able to reach each other, and their '
                      'conversation goes with it.'
                  : 'they won\'t be able to reach each other. '
                      '$contactName won\'t be told.',
              style: theme.bodySoft,
            ),

            // ─────────────────── What gets destroyed ───────────────────
            if (hasChats) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: theme.danger.withValues(alpha: 0.10),
                  border:
                      Border(left: BorderSide(color: theme.danger, width: 2)),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.delete_sweep,
                          size: 14, color: theme.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$_chatsPhrase · $_messagesPhrase will be deleted',
                          style: theme.label.copyWith(
                              color: theme.danger, letterSpacing: 1.2),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      'gone for both of them, including photos and voice '
                      'notes. this can\'t be undone.',
                      style: theme.monoTiny,
                    ),
                    if (_lastSeenPhrase != null) ...[
                      const SizedBox(height: 4),
                      Text(_lastSeenPhrase!, style: theme.monoTiny),
                    ],
                  ],
                ),
              ),
            ],

            // ─────────────────── Rooms that survive ───────────────────
            if (shared.isNotEmpty) ...[
              const SizedBox(height: 12),
              SharedRoomsPanel(
                rooms: shared,
                api: api,
                headline:
                    'they also share ${shared.length} ${shared.length == 1 ? "room" : "rooms"}',
                note:
                    'these stay. take the room back from the ROOMS list below if you want them out of it.',
              ),
            ],

            const SizedBox(height: 16),
            ChoiceTile(
              color: theme.danger,
              filled: true,
              icon: Icons.person_remove,
              title: hasChats ? 'TAKE BACK & DELETE' : 'TAKE BACK',
              sub: hasChats
                  ? 'removes $contactName and wipes $_messagesPhrase.'
                  : 'removes $contactName from the allowed list.',
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 14),
            Center(
              // Autofocused so Enter cancels rather than removing. Tab to
              // reach the destructive option.
              child: FocusableTap(
                onTap: () => Navigator.of(context).pop(false),
                autofocus: true,
                semanticLabel: 'Cancel',
                radius: theme.radiusMd,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                    child: Text(
                      'CANCEL',
                      style: theme.label
                          .copyWith(color: theme.inkMuted, letterSpacing: 2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
