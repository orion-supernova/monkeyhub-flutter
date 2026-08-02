import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/app_brand_mark.dart';
import 'navigation/destinations.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Stack(
      children: [
        theme.backgroundLayer(context),
        SafeArea(
          child: AdaptivePageBody(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                28,
                20,
                kFloatingNavClearance,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppBrandMark(size: 30),
                      const SizedBox(width: 10),
                      Text(
                        'FEED',
                        style: theme.label.copyWith(letterSpacing: 3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  RichText(
                    text: TextSpan(
                      style: theme.displayLarge,
                      children: [
                        TextSpan(text: 'soon.\n', style: theme.displayLarge),
                        TextSpan(
                          text: 'daily moments,\nshared with rooms.',
                          style: theme.displayLarge.copyWith(
                            color: theme.inkMuted,
                            fontSize: theme.displayLarge.fontSize! * 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: theme.roomCardDecoration(
                      ephemeral: false,
                      active: false,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IN THE PIPE', style: theme.label),
                        const SizedBox(height: 10),
                        _bullet(theme, 'a daily prompt the room responds to'),
                        _bullet(
                          theme,
                          'voice notes that auto-fade with the day',
                        ),
                        _bullet(
                          theme,
                          'a wall of small, slow updates from friends',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bullet(AppTheme theme, String t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(t, style: theme.body)),
        ],
      ),
    );
  }
}
