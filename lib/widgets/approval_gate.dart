import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart'
    show groupedFooterStyle, groupedHeaderStyle, groupedMetaStyle, quietFill;
import 'sheet_kit.dart' show SheetActionButton, SheetFrame;
import '../l10n/text_case.dart';

// The guard error codes and `isChildGateError` live in models/family.dart so
// non-UI layers can use them too; this file is only the sheet that renders
// the result.

/// The sheet a child sees whenever they hit something that needs a grown-up.
///
/// Every gated action in the app routes here so the wording, the tone, and
/// the "already asked" state are written exactly once. Returns true when the
/// child chose to send the request.
Future<bool> showApprovalGate(
  BuildContext context, {
  required String what,
  String? detail,
  bool alreadyAsked = false,
  bool canAsk = true,
}) async {
  final result = await showAdaptiveSheet<bool>(
    context,
    builder: (ctx) => _ApprovalGateSheet(
      what: what,
      detail: detail,
      alreadyAsked: alreadyAsked,
      canAsk: canAsk,
    ),
  );
  return result ?? false;
}

class _ApprovalGateSheet extends StatelessWidget {
  const _ApprovalGateSheet({
    required this.what,
    required this.detail,
    required this.alreadyAsked,
    required this.canAsk,
  });

  final String what;
  final String? detail;
  final bool alreadyAsked;
  final bool canAsk;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final asking = canAsk && !alreadyAsked;
    // An optional prompt: titled, with the × leading as the way out — which
    // is why there is no "Not now" button any more; it was a second ×. The
    // shield glyph rides in the body as the hero, the name of the sheet in
    // the bar like every other sheet. SheetFrame's Material keeps Flutter's
    // debug yellow underlines away.
    return SheetFrame(
      title: alreadyAsked
          ? l10n.approvalGateAlreadyAskedLabel
          : l10n.approvalGateAskGrownUpLabel,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: DefaultTextStyle(
        style: theme.body,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              CupertinoIcons.checkmark_shield_fill,
              size: 44,
              color: theme.accent,
            ),
            const SizedBox(height: 14),
            Text(
              alreadyAsked
                  ? l10n.approvalGateAlreadyAskedBody(what)
                  : canAsk
                      ? l10n.approvalGateNeedApprovalBody(what)
                      : l10n.approvalGateDisabledBody,
              textAlign: TextAlign.center,
              // The question, at the sheet-title step (17/w600) — it was 20,
              // off the scale and louder than the title above it.
              style: groupedHeaderStyle(theme),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: groupedFooterStyle(theme),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              alreadyAsked
                  ? l10n.approvalGateAlreadyAskedFooter
                  : canAsk
                      ? l10n.approvalGateWillNotifyFooter
                      : l10n.approvalGateTalkToThemFooter,
              textAlign: TextAlign.center,
              style: groupedFooterStyle(theme),
            ),
            const SizedBox(height: 22),
            // One action: the ask when there is one to make, otherwise the
            // acknowledgement. Either way the × is the "not now".
            SheetActionButton(
              label: asking ? l10n.approvalGateAskIos : l10n.approvalGateOkButton,
              tonal: !asking,
              onTap: () => Navigator.of(context).pop(asking),
            ),
          ],
        ),
      ),
    );
  }
}

/// The inline "waiting for a grown-up" pill, for rows the child has already
/// asked about (a room in Discover, a person in search).
class WaitingPill extends StatelessWidget {
  const WaitingPill({super.key, this.label});

  /// Defaults to a stock "waiting for a grown-up" copy when omitted; callers
  /// pass their own label when the row already has a more specific one.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final resolvedLabel =
        label ?? AppLocalizations.of(context).approvalGateWaitingPillLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: quietFill(theme),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.hourglass, size: 13, color: theme.accent),
          const SizedBox(width: 5),
          Text(
            sentenceCaseOf(context, resolvedLabel),
            // Meta (13/w600) — 12 was off the scale.
            style: groupedMetaStyle(theme).copyWith(
              fontWeight: FontWeight.w600,
              color: theme.accent,
            ),
          ),
        ],
      ),
    );
  }
}
