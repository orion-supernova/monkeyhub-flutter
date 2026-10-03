import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart' show groupedRadius, quietFill;
import 'sheet_kit.dart' show SheetActionButton;
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
    // Wrapped so nothing here renders with Flutter's debug yellow underlines
    // when the sheet sits outside a Material ancestor.
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: theme.body,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            // An iOS sheet platter: the surface, rounded, and no outline.
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(groupedRadius(theme) + 8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_shield_fill,
                      size: 18,
                      color: theme.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sentenceCaseOf(
                        context,
                        alreadyAsked
                            ? AppLocalizations.of(context)
                                .approvalGateAlreadyAskedLabel
                            : AppLocalizations.of(context)
                                .approvalGateAskGrownUpLabel,
                      ),
                      style: theme.bodySoft.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  alreadyAsked
                      ? AppLocalizations.of(context)
                          .approvalGateAlreadyAskedBody(what)
                      : canAsk
                          ? AppLocalizations.of(context)
                              .approvalGateNeedApprovalBody(what)
                          : AppLocalizations.of(context)
                              .approvalGateDisabledBody,
                  style: theme.bodyEmph.copyWith(
                    fontSize: 20,
                    height: 1.25,
                    color: theme.ink,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(detail!, style: theme.bodySoft),
                ],
                const SizedBox(height: 8),
                Text(
                  alreadyAsked
                      ? AppLocalizations.of(context)
                          .approvalGateAlreadyAskedFooter
                      : canAsk
                          ? AppLocalizations.of(context)
                              .approvalGateWillNotifyFooter
                          : AppLocalizations.of(context)
                              .approvalGateTalkToThemFooter,
                  style: theme.bodySoft,
                ),
                const SizedBox(height: 22),
                if (canAsk && !alreadyAsked)
                  _GateButton(
                    label: AppLocalizations.of(context).approvalGateAskIos,
                    filled: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                if (canAsk && !alreadyAsked) const SizedBox(height: 10),
                _GateButton(
                  label: canAsk && !alreadyAsked
                      ? AppLocalizations.of(context).approvalGateNotNowButton
                      : AppLocalizations.of(context).approvalGateOkButton,
                  filled: false,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet's two buttons: the ask as the filled primary, everything else
/// as the tinted secondary — the iOS sheet pair.
class _GateButton extends StatelessWidget {
  const _GateButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      SheetActionButton(label: label, onTap: onTap, tonal: !filled);
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
          Icon(CupertinoIcons.hourglass, size: 12, color: theme.accent),
          const SizedBox(width: 5),
          Text(
            sentenceCaseOf(context, resolvedLabel),
            style: theme.bodySoft.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.accent,
            ),
          ),
        ],
      ),
    );
  }
}
