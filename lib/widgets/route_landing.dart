import 'package:flutter/material.dart';

/// Tells a [State] whether the route it lives on has finished arriving.
///
/// Several screens want to do less while a route is still moving — paint a
/// picture from the thumbnail decode that is already resident rather than
/// starting a full one, hold a video player back, wait before raising the
/// keyboard. All of them are competing for the same frames as an opening
/// transition, and all of them are worth deferring by exactly one animation.
///
/// **The trap this exists to close.** The obvious way to write it is
///
/// ```dart
/// final animation = ModalRoute.of(context)!.animation;
/// if (animation.isCompleted) landed = true;          // wrong
/// else animation.addStatusListener(...);
/// ```
///
/// and it silently does nothing. `HeroController` parks an arriving route
/// *offstage* for one frame so it can measure where the heroes are going to
/// land, and `TransitionRoute.offstage` swaps the route's animation for
/// `kAlwaysCompleteAnimation` while it is there — so on precisely the frame a
/// hero flight is being set up, a route that has not begun to move reports
/// itself finished. Every screen that reads its own route animation during its
/// first build reads that lie, latches `landed = true`, and defers nothing
/// for the rest of its life. It is invisible: nothing breaks, the optimization
/// just never happens.
///
/// So [landed] is never decided during a build. The status listener below is
/// attached unconditionally, and the "was it already finished?" question is
/// asked once the frame is over — by which time `HeroController` has put the
/// route back onstage and the animation is telling the truth again.
///
/// Costs one frame of `landed == false` even on a route that never animates.
/// That is the right default for everything this is used for: one frame of the
/// cheaper thing.
mixin RouteLanding<T extends StatefulWidget> on State<T> {
  /// True once the enclosing route has stopped moving.
  bool get landed => _landed;
  bool _landed = false;

  /// Whether a route that starts *leaving* counts as un-landed again.
  ///
  /// Off by default: most callers use [landed] to decide how hard to work on
  /// the way in, and there is nothing to reconsider on the way out. On for the
  /// one that has to put something back before the pop can animate it — see
  /// `MediaPagerScreen`'s video page, which owes the closing flight a poster.
  bool get unlandsOnExit => false;

  /// Fires after [landed] flips and the rebuild has been scheduled. Never
  /// during a build, so it is safe to do more here than set a field.
  void onRouteLandingChanged() {}

  Animation<double>? _routeAnimation;
  bool _wired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    // `_wired` rather than a bare identity check: the first call may legally
    // find no route at all, and `identical(null, null)` would read as "already
    // subscribed" and skip the deferred check below forever.
    if (_wired && identical(animation, _routeAnimation)) return;
    _wired = true;
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _routeAnimation = animation;
    animation?.addStatusListener(_handleRouteStatus);
    WidgetsBinding.instance.addPostFrameCallback(_settleLanding);
  }

  /// The honest reading, taken after the frame the offstage lie lives in.
  void _settleLanding(Duration _) {
    if (!mounted) return;
    final animation = _routeAnimation;
    _setLanded(animation == null || animation.isCompleted);
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (status.isCompleted) {
      _setLanded(true);
    } else if (unlandsOnExit) {
      _setLanded(false);
    }
  }

  void _setLanded(bool value) {
    if (value == _landed || !mounted) return;
    setState(() => _landed = value);
    onRouteLandingChanged();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    super.dispose();
  }
}
