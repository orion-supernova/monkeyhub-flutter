import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'password_field.dart';

/// Asks for the account password. Returns null if the user backed out.
///
/// Exists because attaching or detaching an Apple/Google identity is an
/// account-takeover primitive — `socialAuth.link` and `socialAuth.unlink` demand
/// the password for the same reason `auth.setRecoveryKey` does — and there was
/// no reusable way to collect one outside `RecoveryPhraseScreen`.
///
/// The password is returned, never stored. Callers hand it straight to the API
/// layer, which hashes it; nothing here keeps a copy.
Future<String?> askPassword(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String? subtitle,
}) {
  return showAdaptiveSheet<String>(
    context,
    builder: (_) => _PasswordPromptSheet(
      title: title,
      actionLabel: actionLabel,
      subtitle: subtitle,
    ),
  );
}

class _PasswordPromptSheet extends StatefulWidget {
  const _PasswordPromptSheet({
    required this.title,
    required this.actionLabel,
    this.subtitle,
  });

  final String title;
  final String actionLabel;
  final String? subtitle;

  @override
  State<_PasswordPromptSheet> createState() => _PasswordPromptSheetState();
}

class _PasswordPromptSheetState extends State<_PasswordPromptSheet> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _password.text;
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      // Lifts the sheet clear of the keyboard, which otherwise covers the very
      // field it was opened to fill.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.label),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(widget.subtitle!, style: theme.bodySoft),
            ],
            const SizedBox(height: 16),
            PasswordField(
              controller: _password,
              hint: 'password',
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FocusableTap(
              onTap: _submit,
              semanticLabel: widget.actionLabel,
              radius: theme.radiusMd,
              // Never InkWell anywhere in this app.
              child: GestureDetector(
                onTap: _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  child: Text(
                    widget.actionLabel,
                    style: theme.label
                        .copyWith(color: theme.accentInk, letterSpacing: 2),
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
