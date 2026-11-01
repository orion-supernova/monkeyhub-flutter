import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// The iOS push on every touch platform: the incoming page slides in from the
/// right while the one beneath parallaxes left and dims, and on iOS the left
/// edge drags it back interactively. It is [CupertinoPageTransitionsBuilder]
/// underneath, so the interactive back gesture, the shadow and the parallax
/// are the platform's own.
///
/// **Only a deliberate request for less motion swaps the slide for a
/// cross-fade** — the OS Reduce Motion flag, or Calm chosen in Settings. Low
/// Power Mode / Battery Saver does NOT: one slide is a transform of a layer
/// that is already rasterized, which costs the GPU next to nothing, while the
/// savings power saving is after come from the decoration it already switches
/// off (loops, particles, blur). iOS itself keeps its slide in Low Power Mode.
///
/// Either way the edge swipe back stays. Under the fade it still drags the
/// route's own controller, so the page dissolves with the finger instead of
/// sliding — iOS does the same with Reduce Motion on.
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  /// Whether the person asked for less motion, as opposed to the app calming
  /// itself to save power. `LowPowerCalm` injects `disableAnimations` into the
  /// tree, so the OS flag is read from the platform, beneath that.
  static bool _reducedOnRequest(BuildContext context) =>
      MotionScope.reducedOnRequest(
        View.of(context).platformDispatcher.accessibilityFeatures.disableAnimations,
      );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_reducedOnRequest(context)) {
      // The Cupertino wrapper, held at rest (fully in, nothing underneath
      // moving) so it contributes only the back gesture, which reads the
      // route's controller and not these animations. The real animation then
      // drives the fade, and a drag back is a fade out.
      return FadeTransition(
        opacity: animation,
        child: _cupertino.buildTransitions<T>(
          route,
          context,
          const AlwaysStoppedAnimation<double>(1),
          const AlwaysStoppedAnimation<double>(0),
          child,
        ),
      );
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
