import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../l10n/generated/app_localizations.dart';
import 'sheet_kit.dart';

enum BlockChoice { cancel, blockOnly, blockAndDelete }

/// Asks how to block someone: block only, or block and wipe the DM.
///
/// A choice before a destructive act, so it is an iOS action sheet — no ×,
/// the question as the title, what it means as the message, the two answers
/// in red and Cancel on its own below (autofocused, so Enter on a fresh sheet
/// cancels rather than blocks). Everything the old hand-built sheet spelled
/// out survives in the message: whether they're told, what happens to a
/// friendship, the rooms you still share (by name — they stay untouched),
/// and, when there is a DM, that the second answer wipes it.
///
/// [api] is kept for callers; the rooms are now named in text, so no avatars
/// are fetched.
Future<BlockChoice> showBlockChoiceSheet(
  BuildContext context, {
  required String displayName,
  required bool isFriend,
  required List<ChatRoom> sharedGroupRooms,
  required bool hasDm,
  required ChatApi api,
}) async {
  final l10n = AppLocalizations.of(context);
  final message = StringBuffer()
    ..write(l10n.bulkActionBarBlockSheetNotNotifiedNote)
    ..write(' ')
    ..write(isFriend
        ? l10n.bulkActionBarBlockSheetFriendWarning
        : l10n.bulkActionBarBlockSheetStrangerWarning);
  if (sharedGroupRooms.isNotEmpty) {
    message
      ..write('\n\n')
      ..write(l10n.bulkActionBarBlockSheetSharedRoomsHeadline(
          sharedGroupRooms.length))
      ..write(': ')
      ..write(sharedGroupRooms.map((r) => r.name).join(', '))
      ..write('. ')
      ..write(l10n.bulkActionBarBlockSheetSharedRoomsNote);
  }
  if (hasDm) {
    message
      ..write('\n\n')
      ..write(l10n.bulkActionBarBlockDeleteDmSub);
  }
  final res = await showIosActionSheet<BlockChoice>(
    context,
    title: l10n.bulkActionBarBlockSheetTitle(displayName),
    message: message.toString(),
    actions: [
      IosSheetAction(
        label: l10n.bulkActionBarBlockChoiceTileTitle,
        value: BlockChoice.blockOnly,
        destructive: true,
        icon: CupertinoIcons.hand_raised_fill,
      ),
      if (hasDm)
        IosSheetAction(
          label: l10n.bulkActionBarBlockDeleteDmTitle,
          value: BlockChoice.blockAndDelete,
          destructive: true,
          icon: CupertinoIcons.trash_fill,
        ),
    ],
    cancelLabel: l10n.bulkActionBarBlockSheetCancelLabel,
  );
  return res ?? BlockChoice.cancel;
}
