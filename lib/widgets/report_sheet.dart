import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'labeled_field.dart';

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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.inkMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              AppLocalizations.of(context).reportSheetTitle,
              style: theme.label.copyWith(
                color: theme.danger,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context).reportSheetSubtitle,
              style: theme.displayMedium,
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).reportSheetPrivacyNote,
              style: theme.bodySoft,
            ),
            const SizedBox(height: 14),
            for (final r in _reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = r.$1),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _selected == r.$1
                          ? theme.surfaceRaised
                          : theme.surface,
                      border: Border.all(
                        color: _selected == r.$1 ? theme.danger : theme.divider,
                        width: _selected == r.$1 ? 1.6 : 1,
                      ),
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selected == r.$1
                                  ? theme.danger
                                  : theme.inkMuted,
                              width: 1.4,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: _selected == r.$1
                              ? Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: theme.danger,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _reasonLabel(context, r.$1),
                                style: theme.label,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _reasonDescription(context, r.$1),
                                style: theme.monoTiny,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_selected == 'OTHER') ...[
              const SizedBox(height: 4),
              ThemedInput(
                controller: _note,
                hint: AppLocalizations.of(context).reportSheetOtherNoteHint,
                minLines: 2,
                maxLines: 5,
              ),
            ],
            const SizedBox(height: 18),
            FocusableTap(
              onTap: _selected == null ? null : _submitReport,
              enabled: _selected != null,
              semanticLabel: AppLocalizations.of(
                context,
              ).reportSheetSubmitSemanticLabel,
              radius: theme.radiusMd,
              child: GestureDetector(
                onTap: _selected == null ? null : _submitReport,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selected == null
                        ? theme.surfaceSunken
                        : theme.danger,
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  child: Text(
                    AppLocalizations.of(context).reportSheetSubmitButton,
                    style: theme.label.copyWith(
                      color: _selected == null ? theme.inkMuted : Colors.white,
                      letterSpacing: 2.4,
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
