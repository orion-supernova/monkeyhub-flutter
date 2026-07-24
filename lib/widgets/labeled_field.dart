import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';

/// The small uppercase caption that sits above a form control.
///
/// Kept separate from [LabeledField] because several screens put a label above
/// something that isn't a text input (a visibility picker, a members list).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: ThemeScope.of(context).label),
      );
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
      style: theme.body.copyWith(color: theme.ink),
      cursorColor: theme.accent,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: theme.body.copyWith(color: theme.inkMuted),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
    return Container(
      decoration: theme.inputDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
