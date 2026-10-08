import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/reaction_limits.dart';
import 'sheet_kit.dart';

/// Where the cap was hit, which decides the number and the wording.
enum ReactionLimitSurface { message, moment }

/// The "you've reached the reaction limit" alert.
///
/// An alert rather than a toast: the copy is two sentences that are meant to be
/// read — Slack's "brevity is the soul of wit" note is the model — and a toast
/// that slides away mid-sentence would read as an error flashing past. One
/// button, the way out, so a tap outside dismisses it too.
Future<void> showReactionLimitNotice(
  BuildContext context, {
  required ReactionLimitSurface surface,
}) {
  final l10n = AppLocalizations.of(context);
  return showIosAlert<void>(
    context,
    title: l10n.reactionLimitTitle,
    message: switch (surface) {
      ReactionLimitSurface.message =>
        l10n.reactionLimitMessageBody(kMaxMessageReactionsPerPerson),
      ReactionLimitSurface.moment =>
        l10n.reactionLimitHighlightBody(kMaxMomentReactionsPerPerson),
    },
    actions: [
      IosAlertAction<void>(
        label: l10n.reactionLimitDismiss,
        value: null,
        cancel: true,
        preferred: true,
      ),
    ],
  );
}
