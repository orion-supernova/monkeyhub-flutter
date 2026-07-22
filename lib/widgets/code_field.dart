import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme_scope.dart';

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
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: theme.monoLarge.copyWith(letterSpacing: 10),
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: theme.monoLarge
            .copyWith(letterSpacing: 10, color: theme.inkMuted),
        filled: true,
        fillColor: theme.surfaceSunken,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radiusMd),
          borderSide: BorderSide(color: theme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radiusMd),
          borderSide: BorderSide(color: theme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radiusMd),
          borderSide: BorderSide(color: theme.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
      // Six digits is the whole code, so submit the moment it's complete
      // rather than making a child hunt for the button.
      onChanged: (v) {
        if (v.length == 6) onCompleted(v);
      },
    );
  }
}
