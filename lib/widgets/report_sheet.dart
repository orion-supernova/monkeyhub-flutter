import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'labeled_field.dart';
import 'sheet_kit.dart';
import '../l10n/text_case.dart';

/// Prompts the user to pick a report reason. Resolves to the reason string
/// (or null on dismiss). The "other" path lets the user type a free-form
/// reason; everything is short to keep the sheet tight.
Future<String?> showReportSheet(BuildContext context) {
  return showAdaptiveSheet<String>(
    context,
    builder: (_) => const _ReportSheet(),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = <(String, String)>[
    ('SPAM', 'unwanted ads or repeated messages'),
    ('HARASSMENT', 'targeting or bullying'),
    ('IMPERSONATION', 'pretending to be someone'),
    ('INAPPROPRIATE', 'sexual, violent, or illegal content'),
    ('OTHER', 'something else'),
  ];

  final _note = TextEditingController();
  String? _selected;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Lifted out of the button's inline closure so the keyboard activation path
  /// and the tap path run the same code.
  void _submitReport() {
    final selected = _selected;
    if (selected == null) return;
    final reason = selected == 'OTHER' && _note.text.trim().isNotEmpty
        ? 'OTHER: ${_note.text.trim()}'
        : selected;
    Navigator.of(context).pop(reason);
  }

  /// Display label for a reason code. The code itself (`r.$1`) stays the
  /// canonical English value used for selection matching and as the reason
  /// string sent to the backend — only what's shown on screen is localized.
  String _reasonLabel(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context);
    switch (code) {
      case 'SPAM':
        return l10n.reportSheetReasonSpamLabel;
      case 'HARASSMENT':
        return l10n.reportSheetReasonHarassmentLabel;
      case 'IMPERSONATION':
        return l10n.reportSheetReasonImpersonationLabel;
      case 'INAPPROPRIATE':
        return l10n.reportSheetReasonInappropriateLabel;
      case 'OTHER':
        return l10n.reportSheetReasonOtherLabel;
      default:
        return code;
    }
  }

  /// Display description for a reason code — see [_reasonLabel].
  String _reasonDescription(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context);
    switch (code) {
      case 'SPAM':
        return l10n.reportSheetReasonSpamDescription;
      case 'HARASSMENT':
        return l10n.reportSheetReasonHarassmentDescription;
      case 'IMPERSONATION':
        return l10n.reportSheetReasonImpersonationDescription;
      case 'INAPPROPRIATE':
        return l10n.reportSheetReasonInappropriateDescription;
      case 'OTHER':
        return l10n.reportSheetReasonOtherDescription;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    String sc(String x) => sentenceCaseOf(context, x);
    return SheetFrame(
      title: sc(l10n.reportSheetTitle),
      leading: const SheetCloseButton(),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetRise(
              child: Text(
                sc(l10n.reportSheetSubtitle),
                textAlign: TextAlign.center,
                style: theme.displaySmall.copyWith(color: theme.ink),
              ),
            ),
            const SizedBox(height: 4),
            SheetRise(
              index: 1,
              child: Text(
                sc(l10n.reportSheetPrivacyNote),
                textAlign: TextAlign.center,
                style: theme.bodySoft.copyWith(color: theme.inkMuted),
              ),
            ),
            const SizedBox(height: 18),
            SheetRise(
              index: 2,
              child: SheetGroup(
                children: [
                  for (final r in _reasons)
                    GroupedRow.choice(
                      title: sc(_reasonLabel(context, r.$1)),
                      subtitle: sc(_reasonDescription(context, r.$1)),
                      selected: _selected == r.$1,
                      onTap: () => setState(() => _selected = r.$1),
                    ),
                ],
              ),
            ),
            // The free-text note grows in under the list when it is needed,
            // instead of the sheet jumping by its height.
            AnimatedSize(
              duration: theme.motionFast,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _selected == 'OTHER'
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ThemedInput(
                        controller: _note,
                        hint: sc(l10n.reportSheetOtherNoteHint),
                        minLines: 2,
                        maxLines: 5,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 18),
            Semantics(
              label: l10n.reportSheetSubmitSemanticLabel,
              child: SheetActionButton(
                label: l10n.reportSheetSubmitButton,
                destructive: true,
                onTap: _selected == null ? null : _submitReport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
