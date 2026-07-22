import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';

/// The small accent pill that carries a pending count.
///
/// Matches the badge treatment already used inside [PillNav] — that one stays
/// hand-rolled because its colours animate with the sliding active indicator,
/// which this doesn't need. Everywhere else should use this so the shape and
/// weight stay identical across the app.
///
/// Renders nothing at all when [count] is zero: a badge showing "0" is worse
/// than no badge, because it reads as something needing attention.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.onAccent = false,
    this.max = 99,
  });

  final int count;

  /// True when the badge sits on top of an accent-filled surface, so it
  /// needs to invert rather than blend into it.
  final bool onAccent;

  /// Counts above this render as "N+" — a parent doesn't need the exact
  /// number once it's this far past "deal with it".
  final int max;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onAccent
            ? theme.accentInk.withValues(alpha: 0.18)
            : theme.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > max ? '$max+' : '$count',
        style: theme.monoTiny.copyWith(
          color: onAccent ? theme.accentInk : theme.accent,
        ),
      ),
    );
  }
}

/// A tiny accent dot for surfaces too cramped for a number — the radial menu
/// orb, where a two-digit pill would collide with the icon.
class DotBadge extends StatelessWidget {
  const DotBadge({super.key, required this.show, this.size = 7});

  final bool show;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.accent,
        shape: BoxShape.circle,
        border: Border.all(color: theme.background, width: 1.5),
      ),
    );
  }
}
