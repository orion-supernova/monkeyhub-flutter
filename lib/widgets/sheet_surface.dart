import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'destructive_sheet.dart' show SheetGrabber;

/// The panel every bottom sheet in this family is drawn on.
///
/// **`showAdaptiveSheet` passes `backgroundColor: Colors.transparent`.** That is
/// deliberate — it lets a sheet round its own corners and bleed art to the
/// edge — but it means the surface is the CONTENT's job, and a sheet that
/// forgets simply renders over whatever is behind it. There is no error and
/// nothing in the layout looks wrong in a widget test; you just get a floating
/// column of text over the chat list.
///
/// Extracted rather than pasted for the same reason `sheet_buttons.dart` was:
/// the four group-administration sheets each need this identical shell, and
/// four hand-copied `Container(decoration: …)` blocks are four chances to get
/// the radius, the padding or the bottom inset subtly different — and one
/// chance each to forget it entirely.
///
/// Handles the three things every one of them needs:
///
///  * the themed surface with a rounded top edge,
///  * the drag handle (which hides itself on desktop, where there is nothing
///    to drag — see [SheetGrabber]),
///  * the bottom safe-area inset, which a sheet cannot read from a `SafeArea`
///    inside itself because `ModalBottomSheetRoute` has already removed it.
class SheetSurface extends StatelessWidget {
  const SheetSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
  });

  final Widget child;

  /// Bottom value is treated as the inset ABOVE the home indicator, not as the
  /// total — the safe-area padding is added to it.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.radiusLg)),
      ),
      padding: padding.copyWith(
        bottom: padding.bottom + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [const SheetGrabber(), child],
      ),
    );
  }
}
