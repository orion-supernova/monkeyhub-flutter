import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'ios_kit.dart';

/// A flame and a number after a name: days in a row this person has solved.
///
/// Nothing under two. A one-day "streak" is just having played today, which
/// the row already says, and a flame on every row would be noise rather than
/// a thing worth noticing. The row's own semantics say it aloud.
class StreakBadge extends StatelessWidget {
  const StreakBadge(this.count, {super.key, this.size = 13});

  final int count;

  /// The flame's size; the number follows it.
  final double size;

  @override
  Widget build(BuildContext context) {
    if (count < 2) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    final color = streakColor(theme);
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.flame_fill, size: size, color: color),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: groupedMetaStyle(theme).copyWith(
              fontSize: size,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
