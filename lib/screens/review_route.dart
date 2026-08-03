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
