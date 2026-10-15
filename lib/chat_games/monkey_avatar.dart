import 'package:flutter/material.dart';

/// Monkey, the bot you play against: the app's own launcher monkey (shades,
/// handheld console) in a circle. The real mark rather than a theme's
/// lettered tile, because "Monkey" is a character here, not a logo.
///
/// Decoded at the size it is drawn: the source is 512px, and a 34pt avatar
/// has no business holding a megabyte of it in the image cache.
class MonkeyAvatar extends StatelessWidget {
  const MonkeyAvatar({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ClipOval(
      child: Image.asset(
        'branding/logo.webp',
        width: size,
        height: size,
        cacheWidth: px,
        cacheHeight: px,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
  }
}
