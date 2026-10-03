import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../l10n/text_case.dart';

/// The small uppercase caption that sits above a form control.
///
/// Kept separate from [LabeledField] because several screens put a label above
/// something that isn't a text input (a visibility picker, a members list).
/// The iOS 26 text field: a soft filled rounded rect and nothing else. The
/// theme's input box drew a hairline border, which is the Material field; the
/// fill is the theme's own ink at a low alpha so it follows every palette, on
/// a page or on a sheet.
BoxDecoration fieldDecoration(AppTheme theme) => BoxDecoration(
      color: theme.ink.withValues(alpha: theme.isLight ? 0.055 : 0.09),
      borderRadius: BorderRadius.circular(
        (theme.radiusXl * 0.6).clamp(6.0, 13.0),
      ),
    );

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // The iOS section header over a field: sentence case, footnote size,
    // muted, inset to the field's text rather than its edge.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
      child: Text(
        sentenceCaseOf(context, text),
        style: theme.bodySoft.copyWith(fontSize: 13, color: theme.inkMuted),
      ),
    );
  }
}

/// A themed single-line (or multi-line) text input.
///
/// Wraps the `theme.inputDecoration()` shell plus the borderless [TextField]
/// styling every screen shares, so the per-theme look stays in one place.
class ThemedInput extends StatelessWidget {
  const ThemedInput({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.focusNode,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int? minLines;

  /// For programmatic focus — autofocus chains, moving focus on submit.
  final FocusNode? focusNode;

  /// `next` on a non-terminal field turns the soft keyboard's return key into a
  /// "next field" arrow; `done` on the last one submits. Mobile-facing — the
  /// desktop Enter path is handled by the caller's `onSubmitted`.
  final TextInputAction? textInputAction;

  /// Defaults to 1 to match [TextField]'s own default — passing `null` here
  /// would make the field grow without bound.
  final int? maxLines;
  final bool autocorrect;
  final bool enableSuggestions;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Rendered to the right of the field, inside the same shell — e.g. a
  /// password visibility toggle.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      obscureText: obscure,
      autofocus: autofocus,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: obscure ? 1 : maxLines,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      style: theme.body.copyWith(color: theme.ink, fontSize: 17),
      cursorColor: theme.accent,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: _hintText(context, hint),
        hintStyle: theme.body.copyWith(color: theme.inkMuted, fontSize: 17),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
    return Container(
      decoration: fieldDecoration(theme),
      padding: EdgeInsets.only(left: 16, right: trailing == null ? 16 : 6),
      child: trailing == null
          ? field
          : Row(children: [Expanded(child: field), trailing!]),
    );
  }
}

/// [FieldLabel] stacked on top of a [ThemedInput] — the common form row.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.focusNode,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final bool autocorrect;
  final bool enableSuggestions;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        ThemedInput(
          controller: controller,
          hint: hint,
          obscure: obscure,
          autofocus: autofocus,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          autocorrect: autocorrect,
          enableSuggestions: enableSuggestions,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          trailing: trailing,
          focusNode: focusNode,
          textInputAction: textInputAction,
        ),
      ],
    );
  }
}

/// Hints are sentence-cased like every other label — except an example value
/// (a URL, an @handle, an address), which is shown exactly as it would be
/// typed: "Https://chat.example.com" is not an example of anything.
String _hintText(BuildContext context, String hint) {
  final literal = hint.contains('://') ||
      hint.startsWith('@') ||
      hint.contains('@') ||
      RegExp(r'^[a-z0-9_.-]+\.[a-z]{2,}', caseSensitive: false).hasMatch(hint);
  return literal ? hint : sentenceCaseOf(context, hint);
}
