import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/family.dart';
import 'sheet_kit.dart';

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
/// A destructive confirm, so it is an iOS action sheet — no ×, the question
/// as the title, the blast radius as the message (what gets deleted, how
/// recently they talked, the rooms they still share — named, since those
/// stay), the one red answer, and an autofocused Cancel on its own below so
/// Enter cancels rather than removes.
///
/// Returns true when the parent confirmed.
Future<bool> showRemoveContactSheet(
  BuildContext context, {
  required String contactName,
  required String childName,
  required ContactRemovalPreview preview,
  required ChatApi api,
}) async {
  final l10n = AppLocalizations.of(context);
  final hasChats = preview.dmCount > 0;
  final messagesPhrase =
      l10n.incomingGroupCallScreenRemoveContactSheetMessagesCount(
    preview.messageCount,
  );
  final shared = preview.sharedGroupRooms;
  final lastSeen = _lastSeenPhrase(l10n, preview.lastMessageAt);

  final message = StringBuffer(
    hasChats
        ? l10n.incomingGroupCallScreenRemoveContactSheetBodyWithChats
        : l10n.incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
            contactName,
          ),
  );
  if (hasChats) {
    message
      ..write('\n\n')
      ..write(l10n.incomingGroupCallScreenRemoveContactSheetDeletionSummary(
        l10n.incomingGroupCallScreenRemoveContactSheetChatsCount(
          preview.dmCount,
        ),
        messagesPhrase,
      ))
      ..write('. ')
      ..write(l10n.incomingGroupCallScreenRemoveContactSheetDeletionDetail);
    // Its own paragraph: tacked onto the line above, the bare "Last message
    // just now" fragment read as a run-on of "This can't be undone."
    if (lastSeen != null) message.write('\n\n$lastSeen');
  }
  if (shared.isNotEmpty) {
    message
      ..write('\n\n')
      ..write(l10n.incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
        shared.length,
      ))
      ..write(': ')
      ..write(shared.map((r) => r.name).join(', '))
      ..write('. ')
      ..write(l10n.incomingGroupCallScreenRemoveContactSheetSharedRoomsNote);
  }

  final res = await showIosActionSheet<bool>(
    context,
    // Positional args must follow alphabetical placeholder order
    // ("childName" < "contactName") — gen-l10n sorts undeclared
    // placeholders alphabetically for the generated signature.
    title: l10n.incomingGroupCallScreenRemoveContactSheetHeadline(
      childName,
      contactName,
    ),
    message: message.toString(),
    actions: [
      IosSheetAction(
        label: hasChats
            ? l10n.incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete
            : l10n.incomingGroupCallScreenRemoveContactSheetTitleBadge,
        value: true,
        destructive: true,
        icon: CupertinoIcons.person_badge_minus_fill,
      ),
    ],
    cancelLabel: l10n.incomingGroupCallScreenRemoveContactSheetCancelButton,
  );
  return res ?? false;
}

/// "last message 3 days ago" — makes "active" concrete, which is the whole
/// reason a parent wants warning before this happens.
String? _lastSeenPhrase(AppLocalizations l10n, DateTime? at) {
  if (at == null) return null;
  final ago = DateTime.now().difference(at);
  if (ago.inMinutes < 60) {
    return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageJustNow;
  }
  if (ago.inHours < 24) {
    return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
      ago.inHours,
    );
  }
  if (ago.inDays == 1) {
    return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageYesterday;
  }
  if (ago.inDays < 30) {
    return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
      ago.inDays,
    );
  }
  return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo;
}
