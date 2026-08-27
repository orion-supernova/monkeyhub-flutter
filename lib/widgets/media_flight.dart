import 'package:flutter/material.dart';

/// The shuttle a picture is painted with while it is between the thumbnail it
/// was tapped in and the fullscreen view of it.
///
/// Every fullscreen surface in the app is reached by flying a thumbnail to it,
/// and left by flying it home, so the two ends always disagree about two
/// things. This reconciles both, and it exists as one function because getting
/// either of them wrong is invisible in code review and unmissable on a phone.
///
///  * **The crop.** A thumbnail fills its box (`cover`, cropped); the
///    fullscreen view shows the whole frame (`contain`, letterboxed). A
///    shuttle that paints `contain` — which is what Flutter's default one
///    inherits from the destination — letterboxes the picture inside the
///    *small* end and then snaps to the thumbnail's fill on landing. Painting
///    `cover` reproduces the thumbnail's crop at the small end, and at the big
///    end the rect already has the picture's own ratio, where `cover` and
///    `contain` are the same thing. The crop animates instead of cutting.
///  * **The corners.** A thumbnail is clipped to a radius and the fullscreen
///    view is square-cornered. Without a tween the corners snap at whichever
///    endpoint the shuttle happens to render, which is the single most obvious
///    tell that a flight is a cut and not a movement.
///
/// [image] must be built by the caller and painted `cover`: it owns the storage
/// id, and — more importantly — the decode width. Whatever flies has to be a
/// decode that is already resident, or the flight animates a shimmer.
///
/// The animation Flutter hands a shuttle runs 0→1 from the *thumbnail* end to
/// the *fullscreen* end in both directions (a pop drives the popping route's
/// own animation backwards), so [radius] is unconditionally the begin value and
/// there is no direction to branch on.
HeroFlightShuttleBuilder mediaFlightShuttle({
  required Widget image,
  BorderRadius radius = BorderRadius.zero,
}) {
  return (flightContext, animation, direction, fromHeroContext, toHeroContext) {
    if (radius == BorderRadius.zero) return image;
    final tween = BorderRadiusTween(begin: radius, end: BorderRadius.zero);
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curved,
      builder: (_, child) => ClipRRect(
        clipBehavior: Clip.antiAlias,
        borderRadius: tween.evaluate(curved) ?? BorderRadius.zero,
        child: child,
      ),
      child: image,
    );
  };
}
