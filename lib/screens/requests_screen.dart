import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';

class RequestsPanel extends StatelessWidget {
  const RequestsPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          theme.hourglassIcon(size: 28, color: theme.accent),
          const SizedBox(height: 12),
          Text('coming in phase 2', style: theme.label.copyWith(color: theme.accent)),
          const SizedBox(height: 6),
          Text(
            'friend requests · room invites · direct draft messages',
            style: theme.bodySoft,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
