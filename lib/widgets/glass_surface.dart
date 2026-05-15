import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';

/// Frosted blurred surface tailored for menus. We don't reuse [LiquidGlass]
/// here because that widget centers its child and is sized to its parent —
/// menus need intrinsic sizing.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.radius,
    required this.padding,
    required this.child,
  });
  final double radius;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isLight = MediaQuery.platformBrightnessOf(context) == Brightness.light;
    final frostAlpha = isLight ? 0.62 : 0.42;
    final radii = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radii,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radii,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: frostAlpha),
              borderRadius: radii,
              border: Border.all(
                color: theme.accent.withValues(alpha: 0.22),
                width: 1,
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
