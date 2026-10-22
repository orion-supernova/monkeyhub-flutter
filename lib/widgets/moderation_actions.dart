import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_message.dart';
import 'app_toast.dart';
import 'message_action_menu.dart';
import 'sheet_kit.dart';

/// Carries out a moderator's choice on a report card in the moderation room:
/// remove the reported message, moment or comment for everyone, ban or unban the reported
/// person, or dismiss the report.
///
/// Shared by the room screen and the thread overlay (an outcome line is a
/// reply to its card, so a card can be long-pressed from either), so the
/// confirmation and the copy cannot drift between them.
///
/// The two that take something away ask first, on the same iOS action sheet
/// every other destructive confirmation in the app uses; the two that do not
/// run at once. The server re-checks that the caller is staff on every call
/// (`moderation.act`), so a client that somehow showed these rows to anybody
/// else would get NOT_AUTHORIZED, not a ban.
///
/// The outcome is also posted under the card by Monkey Reporter, so the room
/// itself is the record of who did what; the toast is only the immediate
/// "that went through".
Future<void> runModeratorAction(
  BuildContext context, {
  required ChatApi api,
  required ModerationCard card,
  required MessageAction action,
}) async {
  final l10n = AppLocalizations.of(context);
  final toast = AppToast.of(context);
  final String wire;
  String? confirmTitle;
  String? confirmBody;
  String? confirmLabel;
  switch (action) {
    case MessageAction.modRemoveMessage:
      wire = 'removeMessage';
      confirmTitle = l10n.moderationConfirmRemoveTitle;
      confirmBody = l10n.moderationConfirmRemoveBody;
      confirmLabel = l10n.moderationActionRemoveMessage;
    case MessageAction.modRemoveContent:
      wire = 'removeContent';
      confirmTitle = l10n.moderationConfirmRemoveContentTitle;
      confirmBody = l10n.moderationConfirmRemoveContentBody;
      confirmLabel = l10n.moderationActionRemoveContent;
    case MessageAction.modBanUser:
      wire = 'ban';
      confirmTitle = l10n.moderationConfirmBanTitle;
      confirmBody = l10n.moderationConfirmBanBody;
      confirmLabel = l10n.moderationActionBan;
    case MessageAction.modUnbanUser:
      wire = 'unban';
    case MessageAction.modDismiss:
      wire = 'dismiss';
    default:
      return;
  }

  if (confirmTitle != null) {
    final ok = await showIosActionSheet<bool>(
      context,
      title: confirmTitle,
      message: confirmBody,
      actions: [
        IosSheetAction(
          label: sentenceCaseOf(context, confirmLabel!),
          value: true,
          destructive: true,
        ),
      ],
    );
    if (ok != true) return;
    HapticFeedback.heavyImpact();
  }

  try {
    await api.moderationAct(reportId: card.reportId, action: wire);
    toast.success(l10n.moderationActionDone);
  } catch (e) {
    toast.error(
      e.toString().contains('CANT_BAN_ACCOUNT')
          ? l10n.moderationCantBan
          : l10n.moderationActionFailed,
    );
  }
}
