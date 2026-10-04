import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'sheet_kit.dart';

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

/// Both are thin aliases now: [SheetPrimaryButton] is [SheetActionButton],
/// [SheetSecondaryButton] is its `tonal` variant or a [TextLinkButton]. New
/// code uses those directly.

/// The heavy option: a full-width accent capsule, sentence case — the iOS
/// sheet's primary button. Drawn by [SheetActionButton].
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
  Widget build(BuildContext context) =>
      SheetActionButton(label: label, onTap: onTap);
}

/// The lighter option: a soft tinted capsule, or bare text for a dismissal.
class SheetSecondaryButton extends StatelessWidget {
  const SheetSecondaryButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.bordered = true,
  });

  final String label;

  /// The label's colour. Danger reads as destructive; anything else keeps the
  /// theme's own ink so the secondary never competes with the primary.
  final Color color;
  final VoidCallback onTap;

  /// True for the tinted slab; false for a plain text button (Cancel).
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final destructive = color == theme.danger;
    if (bordered) {
      return SheetActionButton(
        label: label,
        onTap: onTap,
        tonal: true,
        destructive: destructive,
      );
    }
    return TextLinkButton(label: label, onTap: onTap, destructive: destructive);
  }
}
