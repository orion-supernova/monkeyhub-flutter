import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';

/// THE filter chip: a soft neutral capsule at rest, solid accent when on —
/// the Apple Music filter treatment. The chat list's facet row and the
/// diagnostics categories both draw this, so a filter looks like a filter
/// wherever it is.
class FilterCapsule extends StatelessWidget {
  const FilterCapsule({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.showZeroCount = false,
    this.leading,
    this.faded = false,
    this.onLongPress,
    this.semanticLabel,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  /// Shown after the label in tabular figures. A zero is dimmed into the
  /// label rather than printed, unless [showZeroCount].
  final int? count;
  final bool showZeroCount;

  /// A small mark before the label — a category's colour dot, say.
  final Widget? leading;

  /// Half-strength while not [active]: a filter that is set aside.
  final bool faded;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final n = count;
    final empty = n == 0;
    final showCount = n != null && (n > 0 || showZeroCount);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      selected: active,
      shape: FocusRingShape.capsule,
      radius: 999,
      inset: 2,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: faded && !active ? 0.5 : 1,
          child: AnimatedContainer(
            duration: theme.motionFast,
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 34),
            padding: EdgeInsets.fromLTRB(leading == null ? 14 : 11, 0, 14, 0),
            decoration: BoxDecoration(
              color: active ? theme.accent : theme.ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
            ),
            // Hugs its label (a Container `alignment` would stretch the
            // capsule across a Wrap); centred in whatever height it is given.
            child: Center(
              widthFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 6),
                  ],
                  AnimatedDefaultTextStyle(
                    duration: theme.motionFast,
                    style: theme.bodySoft.copyWith(
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: -0.2,
                      color: active
                          ? theme.accentInk
                          // A filter matching nothing is dimmed rather than
                          // hidden — a row that reshuffled itself every time a
                          // count hit zero would be impossible to aim at.
                          : (empty ? theme.inkMuted : theme.inkSoft),
                    ),
                    child: Text(label),
                  ),
                  if (showCount) ...[
                    const SizedBox(width: 5),
                    Text(
                      '$n',
                      // The body face, not the caption slot (tracked mono on
                      // a character theme).
                      style: theme.bodySoft.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: active
                            ? theme.accentInk.withValues(alpha: 0.75)
                            : theme.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
