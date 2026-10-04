import 'package:flutter/cupertino.dart';

import '../l10n/generated/app_localizations.dart';
import 'sheet_kit.dart';

/// Asks before opening a link ENTITY — text like "check this" that carries a
/// URL the visible words say nothing about.
///
/// Bare URLs in a message keep their direct tap-to-open, because there the
/// visible text IS the destination. A link entity severs that: the sender
/// chose both the words and the target independently, which is precisely the
/// shape of a phishing lure, so the one thing this sheet exists to do is put
/// the real destination in front of the reader's eyes before anything loads.
/// It is a confirmation, so it is an iOS action sheet — no ×, the choice in
/// the group and a separate, autofocused Cancel below (Enter on a fresh sheet
/// cancels rather than opens, the destructive-sheet convention: "open an
/// unread URL" is the riskier of the two answers). The question is the bold
/// line and the full URL, verbatim, the message under it — the title slot is
/// sentence-cased, which would turn "example.com" into "Example.com".
///
/// Returns true when the reader chose to open.
Future<bool> showLinkConfirmSheet(BuildContext context, {required String url}) async {
  final l10n = AppLocalizations.of(context);
  final res = await showIosActionSheet<bool>(
    context,
    title: l10n.linkConfirmSheetTitle,
    message: url,
    actions: [
      IosSheetAction(
        label: l10n.linkConfirmSheetOpenLabel,
        value: true,
        icon: CupertinoIcons.arrow_up_right_square,
      ),
    ],
    cancelLabel: l10n.linkConfirmSheetCancelLabel,
  );
  return res ?? false;
}
