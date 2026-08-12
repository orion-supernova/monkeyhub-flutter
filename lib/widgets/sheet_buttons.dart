import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';

/// The call-to-action pair every sheet in this family ends with.
///
/// One copy, because there were two. `schedule_message_sheet.dart` and
/// `scheduled_list_sheet.dart` each carried a byte-identical `_PrimaryButton`
/// and `_SecondaryButton` with a comment promising to keep them in step by
/// hand — which held exactly as long as nobody restyled either sheet. The first
/// restyle is what this file exists to survive.
///
/// `mute_room_sheet.dart` still has its own pair. It is deliberately left
/// alone: it is not part of this rewrite, and moving a working sheet onto a
/// shared widget in the same change that redesigns two others is how a
/// regression gets attributed to the wrong edit. Migrating it later is a
/// two-line change.

/// The heavy option: full-width, accent-filled, all-caps.
///
/// A null [onTap] renders disabled rather than hiding the button — a dead
/// button with the reason stated above it is legible, a button that vanishes
/// is not.
class SheetPrimaryButton extends StatelessWidget {
  const SheetPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    return FocusableTap(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? theme.accent : theme.accentSoft,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style: theme.label.copyWith(
              color: enabled ? theme.accentInk : theme.inkMuted,
              letterSpacing: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// The lighter option: outlined, or bare for a dismissal.
class SheetSecondaryButton extends StatelessWidget {
  const SheetSecondaryButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.bordered = true,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Always a border, transparent when unbordered rather than absent:
            // a `null` border and a present one lay out a pixel apart, and the
            // cancel row sitting under a bordered row would shift by that pixel
            // whenever the two swapped. The same constant-width rule the theme
            // chips and the room-info segments already follow.
            border: Border.all(
              color: bordered ? color.withValues(alpha: 0.55) : Colors.transparent,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style: theme.label.copyWith(color: color, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}
