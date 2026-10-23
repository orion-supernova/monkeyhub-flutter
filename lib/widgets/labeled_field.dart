import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'spring_press.dart';

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

/// THE text input inside a sheet (and anywhere a form field has no label
/// row above it): a soft filled rounded field, 17pt ink, the hint in the
/// muted subtitle ink, an accent cursor.
///
/// The composers drew bare floating text with no field shape and the default
/// cursor colour; this is the shape [ThemedInput] already has on pages, with
/// the knobs a sheet needs (multi-line growth, a character limit, a leading
/// glyph). Hints are sentence-cased like every label.
class SheetTextField extends StatelessWidget {
  const SheetTextField({
    super.key,
    required this.controller,
    this.hint,
    this.focusNode,
    this.autofocus = false,
    this.obscure = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.leadingIcon,
    this.trailing,
    this.fill,
  });

  final TextEditingController controller;
  final String? hint;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool obscure;
  final int? minLines;

  /// 1 by default; null grows without bound (a composer), clamped by the
  /// sheet's own height.
  final int? maxLines;

  /// Enforced, but no counter is drawn — a caller that wants one shows it.
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// A glyph before the text (Cupertino, 18pt, muted).
  final IconData? leadingIcon;

  /// After the text, inside the field — a visibility toggle, a clear button.
  final Widget? trailing;

  /// Overrides the field's fill (rare: a field on a photo).
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      obscureText: obscure,
      minLines: obscure ? null : minLines,
      maxLines: obscure ? 1 : maxLines,
      maxLength: maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      enabled: enabled,
      style: theme.body.copyWith(color: theme.ink, fontSize: 17, height: 1.3),
      cursorColor: theme.accent,
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        counterText: '',
        hintText: hint == null ? null : _hintText(context, hint!),
        hintStyle: _hintStyle(theme),
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
    final deco = fieldDecoration(theme);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: fill == null ? deco : deco.copyWith(color: fill),
        padding: EdgeInsets.only(
          left: leadingIcon == null ? 14 : 11,
          right: trailing == null ? 14 : 6,
        ),
        child: Row(
          crossAxisAlignment: (maxLines ?? 2) > 1
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              Padding(
                padding: EdgeInsets.only(
                  bottom: (maxLines ?? 2) > 1 ? 13 : 0,
                ),
                child: Icon(leadingIcon, size: 18, color: theme.inkMuted),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(child: field),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The hint of a [SheetTextField]: the muted subtitle ink at the field's own
/// 17pt, so the placeholder sits exactly where the text will.
TextStyle _hintStyle(AppTheme theme) =>
    theme.body.copyWith(fontSize: 17, height: 1.3, color: theme.inkMuted);

/// How [FormErrorBanner] is tinted: an error, or a confirmation that reuses
/// the same layout (for example "your account is being deleted").
enum FormBannerTone { error, success }

/// THE error under (or above) a form: a red-washed rounded block with an
/// exclamation glyph and a 15pt sentence — and, optionally, the one thing to
/// do about it ("Try again", "Use password instead").
///
/// Replaces five private banners that had drifted to three radii and two
/// icon treatments (login, recovery, device scan, social username, device
/// panel).
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(
    this.message, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.icon = CupertinoIcons.exclamationmark_circle_fill,
    this.tone = FormBannerTone.error,
  });

  final FormBannerTone tone;

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final radius = (theme.radiusXl.clamp(6.0, 26.0)) * 0.6;
    final color = tone == FormBannerTone.success ? theme.success : theme.danger;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: theme.bodySoft.copyWith(
                      fontSize: 15,
                      height: 1.3,
                      color: color,
                    ),
                  ),
                  if (actionLabel != null && onAction != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SpringPress(
                        onTap: onAction,
                        scale: PressSpec.scaleSmall,
                        semanticLabel: actionLabel,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Text(
                            sentenceCaseOf(context, actionLabel!),
                            style: theme.bodySoft.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
