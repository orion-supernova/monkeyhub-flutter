import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'password_field.dart';
import 'sheet_kit.dart';

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
    // SheetFrame adds the keyboard inset to its own bottom padding, so the
    // field it was opened to fill is never under the keyboard.
    return SheetFrame(
      title: sentenceCaseOf(context, widget.title),
      leading: const SheetCloseButton(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
            ),
            const SizedBox(height: 18),
          ],
          PasswordField(
            controller: _password,
            hint: AppLocalizations.of(context).reactionBubblePasswordHint,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 18),
          SheetActionButton(label: widget.actionLabel, onTap: _submit),
        ],
      ),
    );
  }
}
