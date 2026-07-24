import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'labeled_field.dart';

/// A [ThemedInput] that starts obscured and carries its own show/hide toggle.
///
/// Owns the `_obscure` bool so the eight screens with a password field don't
/// each repeat the same StatefulWidget + setState dance. Everything else is
/// forwarded straight through to [ThemedInput], so the per-theme
/// `inputDecoration()` shell stays the single source of truth for the look.
///
/// Icon convention — the icon names the *action*, not the state:
///   hidden  → open eye     ("tap to show")
///   visible → crossed eye  ("tap to hide")
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;

  /// When set, a [FieldLabel] is stacked above the input — the [LabeledField]
  /// shape, which the room-passphrase forms use.
  final String? label;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final field = ThemedInput(
      controller: widget.controller,
      hint: widget.hint,
      obscure: _obscure,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      // A password is never a dictionary word — leave the keyboard's guessing
      // engines out of it, matching what release_device_screen already did by
      // hand. Also stops iOS from echoing the password in the QuickType bar.
      autocorrect: false,
      enableSuggestions: false,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      trailing: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        tooltip: _obscure ? 'show password' : 'hide password',
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: theme.inkMuted,
          size: 18,
        ),
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [FieldLabel(widget.label!), field],
    );
  }
}
