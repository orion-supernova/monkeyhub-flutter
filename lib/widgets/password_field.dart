import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'hover_hint.dart';
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
    final l10n = AppLocalizations.of(context);
    final reveal = _obscure
        ? l10n.countBadgeShowPasswordTooltip
        : l10n.countBadgeHidePasswordTooltip;
    void toggle() => setState(() => _obscure = !_obscure);
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
      // A bare glyph that toggles, never an IconButton — the app renders no
      // ink anywhere.
      trailing: HoverHint(
        label: reveal,
        child: FocusableTap(
          onTap: toggle,
          semanticLabel: reveal,
          radius: 12,
          hover: HoverEffect.tint,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: toggle,
            child: SizedBox(
              width: 40,
              height: 44,
              child: Icon(
                _obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                color: theme.inkMuted,
                size: 20,
              ),
            ),
          ),
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
