import 'package:flutter/widgets.dart';

import 'liquid_glass.dart';

/// The glass panel menus and banners sit on: [LiquidGlass], rounded, sized to
/// its content. A named composition rather than its own recipe, so a menu is
/// the same material as every glass button around it.
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
  Widget build(BuildContext context) => LiquidGlass(
        shape: LiquidGlassShape.rounded,
        radius: radius,
        padding: padding,
        child: child,
      );
}
