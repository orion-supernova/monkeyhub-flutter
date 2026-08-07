import 'dart:ui';

import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';

/// The way out of a full-screen overlay: a frosted circle with an X in it.
///
/// Deliberately **not** in `photo_chrome.dart`, whose whole argument is that
/// chrome floating over an arbitrary photograph must be fixed neutral dark
/// because a pale theme's glass over a bright sky disappears. This one sits
/// over the app's own surfaces — a dimmed board, a themed page — where the
/// theme *is* the backdrop and `theme.surface` is exactly right.
///
/// Extracted from the thread overlay, which had the only good version of this
/// and kept it private while two other surfaces went without: the moment viewer
/// had no close affordance at all, and the fullscreen image viewer grew a bare
/// white icon that vanishes against a light photo. A third copy was the wrong
/// answer.
class GlassCloseButton extends StatelessWidget {
  const GlassCloseButton({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    this.size = 40,
  });

  final VoidCallback onTap;

  /// Localized. There is an existing `photoChromeCloseSemanticLabel` for this.
  final String semanticLabel;

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.surface.withValues(alpha: 0.55),
                border: Border.all(
                  color: theme.accent.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(Icons.close, size: size * 0.45, color: theme.ink),
            ),
          ),
        ),
      ),
    );
  }
}
