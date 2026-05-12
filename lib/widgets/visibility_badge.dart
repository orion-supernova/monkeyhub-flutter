import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';

class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({
    super.key,
    required this.isPublic,
    this.dense = false,
    this.invert = false,
  });

  final bool isPublic;
  final bool dense;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final label = isPublic ? 'PUBLIC' : 'PRIVATE';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: dense ? 3 : 5),
      decoration: theme.chipDecoration(filled: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          theme.visibilityIcon(isPublic: isPublic, size: dense ? 10 : 12),
          SizedBox(width: dense ? 4 : 6),
          Text(label, style: theme.monoTiny.copyWith(color: invert ? theme.background : theme.inkSoft)),
        ],
      ),
    );
  }
}

class EphemeralBadge extends StatelessWidget {
  const EphemeralBadge({super.key, required this.ttl, this.dense = false});
  final Duration ttl;
  final bool dense;

  String _fmt() {
    final s = ttl.inSeconds;
    if (s < 60) return '${s}s';
    if (s < 3600) return '${(s / 60).round()}m';
    return '${(s / 3600).round()}h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: dense ? 3 : 5),
      decoration: theme.chipDecoration(filled: false).copyWith(
            border: Border.all(color: theme.accent.withValues(alpha: 0.55), width: 1),
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          theme.hourglassIcon(size: dense ? 10 : 12, color: theme.accent),
          SizedBox(width: dense ? 4 : 6),
          Text('EPHEMERAL · ${_fmt()}', style: theme.monoTiny.copyWith(color: theme.accent)),
        ],
      ),
    );
  }
}
