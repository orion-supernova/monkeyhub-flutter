import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// The iOS push on every touch platform: the incoming page slides in from the
/// right while the one beneath parallaxes left and dims, and on iOS the left
/// edge drags it back interactively. It is [CupertinoPageTransitionsBuilder]
/// underneath, so the interactive back gesture, the shadow and the parallax
/// are the platform's own.
///
/// Under calm motion (Reduce Motion / Low Power Mode) the slide becomes the
/// cross-fade iOS itself substitutes. Material routes do not look at
/// `disableAnimations` on their own, so this is where it is honoured; the
/// edge-swipe is a slide by nature and is traded away with it.
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MotionScope.of(context).calm) {
      return FadeTransition(opacity: animation, child: child);
    }
    return _cupertino.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Slide-and-parallax push for iOS, macOS and Android; desktop Linux and
/// Windows keep Flutter's own (a pointer has no edge to swipe from, and the
/// zoom there is the platform's convention).
const PageTransitionsTheme glassPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.iOS: GlassPageTransitionsBuilder(),
    TargetPlatform.macOS: GlassPageTransitionsBuilder(),
    TargetPlatform.android: GlassPageTransitionsBuilder(),
  },
);
