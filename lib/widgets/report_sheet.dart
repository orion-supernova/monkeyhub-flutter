import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            Text('REPORT', style: theme.label.copyWith(color: theme.danger, letterSpacing: 2)),
            const SizedBox(height: 6),
            Text('tell us what\'s wrong.', style: theme.displayMedium),
            const SizedBox(height: 4),
            Text(
              'reports are private — the other person isn\'t notified.',
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
                      color: _selected == r.$1 ? theme.surfaceRaised : theme.surface,
                      border: Border.all(
                        color: _selected == r.$1 ? theme.danger : theme.divider,
                        width: _selected == r.$1 ? 1.6 : 1,
                      ),
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: Row(children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selected == r.$1 ? theme.danger : theme.inkMuted,
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
                            Text(r.$1, style: theme.label),
                            const SizedBox(height: 2),
                            Text(r.$2, style: theme.monoTiny),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            if (_selected == 'OTHER') ...[
              const SizedBox(height: 4),
              ThemedInput(
                controller: _note,
                hint: 'what happened?',
                minLines: 2,
                maxLines: 5,
              ),
            ],
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _selected == null
                  ? null
                  : () {
                      final reason = _selected == 'OTHER' && _note.text.trim().isNotEmpty
                          ? 'OTHER: ${_note.text.trim()}'
                          : _selected!;
                      Navigator.of(context).pop(reason);
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selected == null ? theme.surfaceSunken : theme.danger,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text(
                  'SUBMIT',
                  style: theme.label.copyWith(
                    color: _selected == null ? theme.inkMuted : Colors.white,
                    letterSpacing: 2.4,
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
