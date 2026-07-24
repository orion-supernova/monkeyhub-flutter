import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart';

enum BlockChoice { cancel, blockOnly, blockAndDelete }

Future<BlockChoice> showBlockChoiceSheet(
  BuildContext context, {
  required String displayName,
  required bool isFriend,
  required List<ChatRoom> sharedGroupRooms,
  required bool hasDm,
  required ChatApi api,
}) async {
  final res = await showAdaptiveSheet<BlockChoice>(
    context,
    builder: (_) => _BlockChoiceSheet(
      displayName: displayName,
      isFriend: isFriend,
      sharedGroupRooms: sharedGroupRooms,
      hasDm: hasDm,
      api: api,
    ),
  );
  return res ?? BlockChoice.cancel;
}

class _BlockChoiceSheet extends StatefulWidget {
  const _BlockChoiceSheet({
    required this.displayName,
    required this.isFriend,
    required this.sharedGroupRooms,
    required this.hasDm,
    required this.api,
  });
  final String displayName;
  final bool isFriend;
  final List<ChatRoom> sharedGroupRooms;
  final bool hasDm;
  final ChatApi api;

  @override
  State<_BlockChoiceSheet> createState() => _BlockChoiceSheetState();
}

class _BlockChoiceSheetState extends State<_BlockChoiceSheet> {
  String _subtitle() {
    final parts = <String>['they won\'t be notified.'];
    if (widget.isFriend) {
      parts.add(
        'you\'re currently friends — blocking removes the friendship, so to reconnect later you\'d have to send a new friend request.',
      );
    } else {
      parts.add('they\'ll disappear from your search and can\'t message you.');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final shared = widget.sharedGroupRooms;

    return Container(
      decoration: theme.sheetDecoration(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
            Text('BLOCK',
                style: theme.label.copyWith(color: theme.danger, letterSpacing: 2)),
            const SizedBox(height: 6),
            Text('block ${widget.displayName}?', style: theme.displayMedium),
            const SizedBox(height: 6),
            Text(_subtitle(), style: theme.bodySoft),

            // ─────────────────── Shared rooms warning ───────────────────
            if (shared.isNotEmpty) ...[
              const SizedBox(height: 14),
              SharedRoomsPanel(
                rooms: shared,
                api: widget.api,
                headline:
                    'you share ${shared.length} ${shared.length == 1 ? "room" : "rooms"} with them',
                note:
                    'these rooms stay untouched. you can leave any of them yourself from each room\'s settings.',
              ),
            ],

            // ─────────────────── Choices ───────────────────
            const SizedBox(height: 16),
            ChoiceTile(
              color: theme.danger,
              icon: Icons.block,
              title: 'BLOCK',
              sub: widget.isFriend
                  ? 'remove friendship and block. existing chat history stays in your archive.'
                  : 'they\'re hidden from search and can\'t reach you.',
              onTap: () => Navigator.of(context).pop(BlockChoice.blockOnly),
            ),
            if (widget.hasDm) ...[
              const SizedBox(height: 10),
              ChoiceTile(
                color: theme.danger,
                filled: true,
                icon: Icons.delete_sweep,
                title: 'BLOCK & DELETE DM',
                sub:
                    'also wipes your DM with them — every message, reaction, and media file is gone.',
                onTap: () => Navigator.of(context).pop(BlockChoice.blockAndDelete),
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(BlockChoice.cancel),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                  child: Text(
                    'CANCEL',
                    style: theme.label.copyWith(color: theme.inkMuted, letterSpacing: 2),
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
