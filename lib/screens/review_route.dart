import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart' show Curves, MaterialPageRoute;
import 'package:flutter/widgets.dart';

/// A route that swaps in over the camera with no transition at all.
///
/// The review surfaces — the chat editor, the avatar cropper — are pushed on
/// top of the still-live camera route the instant the shutter fires. Animating
/// that push would show the camera sliding away under a page arriving, which is
/// exactly the dismiss-then-present the in-place review exists to remove: the
/// photo should appear where the preview was, in the frame after the shutter.
///
/// Zero in both directions, because RETAKE has the same problem in reverse — it
/// should reveal the camera, not animate a page off it.
Route<T> reviewRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => child,
  );
}

/// How a full-screen editor arrives from somewhere other than the camera.
///
/// A phone keeps the platform push (it slides in from the right, and a swipe
/// back undoes it). On a desktop that motion reads as the whole window
/// shoving sideways for what is really a dialog over the chat, so there the
/// page fades in with a slight settle instead, and fades out the same way.
Route<T> editorRoute<T>(Widget child) {
  final desktop = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };
  if (!desktop) return MaterialPageRoute<T>(builder: (_) => child);
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, _, _) => child,
    transitionsBuilder: (_, animation, _, page) {
      final eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(eased),
          child: page,
        ),
      );
    },
  );
}
