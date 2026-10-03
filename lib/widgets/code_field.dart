import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme_scope.dart';
import 'labeled_field.dart' show fieldDecoration;

/// The six-digit entry box used wherever a guardian-issued code is typed in:
/// pairing a child's device, and handing one back.
///
/// Shared rather than copied because the two screens are deliberately twins —
/// a child who has typed one of these should recognise the other instantly,
/// and two copies of the styling would drift apart.
class CodeField extends StatelessWidget {
  const CodeField({
    super.key,
    required this.controller,
    required this.onCompleted,
    required this.enabled,
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // The iOS one-time-code field: a soft filled slab like every other field
    // (see [fieldDecoration]), no outline, big tabular digits spaced out so
    // each one reads as its own box.
    final digits = theme.monoLarge.copyWith(
      fontSize: 30,
      letterSpacing: 12,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return DecoratedBox(
      decoration: fieldDecoration(theme),
      child: TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      cursorColor: theme.accent,
      style: digits.copyWith(color: theme.ink),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: digits.copyWith(color: theme.inkMuted.withValues(alpha: 0.5)),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
      // Six digits is the whole code, so submit the moment it's complete
      // rather than making a child hunt for the button.
      onChanged: (v) {
        if (v.length == 6) onCompleted(v);
      },
      ),
    );
  }
}
