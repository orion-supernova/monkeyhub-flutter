import 'package:flutter/material.dart';

/// A [Hero] whose child is carried through the flight instead of being rebuilt
/// at the end of it.
///
/// A plain [Hero] tears its child out of the tree for the length of a flight. On
/// a pop that happens at *both* ends — `heroes.dart` passes
/// `shouldIncludedChildInPlaceholder: false` for the popping hero and takes the
/// same default for the landing one — so the thumbnail a picture is flying home
/// to is destroyed at take-off and constructed again from nothing on touchdown.
///
/// For a picture that is the difference between a landing and a blink. The
/// rebuilt subtree starts with no resolved URL and no image stream, and its
/// decode has spent the whole flight with no listener holding it live in the
/// `ImageCache`. Whatever it cannot produce in its first frame is a hole in the
/// shape of the photograph, exactly where the photograph was supposed to arrive.
///
/// Two things together fix it, and neither works alone:
///
///  * a [Hero.placeholderBuilder], so the child is still *in* the tree while the
///    flight is in the air rather than replaced by a bare [SizedBox]; and
///  * the [GlobalKey] below, because the placeholder's wrapper widgets are not
///    the ones [Hero] uses the rest of the time. Swapping between the two
///    reparents the child, and a reparented subtree is rebuilt from scratch —
///    the very thing the placeholder was added to prevent — unless a global key
///    present in both trees tells the framework to move the element instead.
///
/// Everything else about it is a [Hero]; [tag] and [flightShuttleBuilder] mean
/// what they always mean.
class SteadyHero extends StatefulWidget {
  const SteadyHero({
    super.key,
    required this.tag,
    required this.child,
    this.flightShuttleBuilder,
  });

  final Object tag;
  final Widget child;

  final HeroFlightShuttleBuilder? flightShuttleBuilder;

  @override
  State<SteadyHero> createState() => _SteadyHeroState();
}

class _SteadyHeroState extends State<SteadyHero> {
  /// Held for the life of the state, not rebuilt with the widget: it is the
  /// identity the framework matches on when the child moves between the
  /// placeholder and the hero proper.
  final GlobalKey _key = GlobalKey(debugLabel: 'SteadyHero child');

  /// Guards the hand-back below against two [SteadyHero]s bouncing a flight
  /// between each other forever when neither has a shuttle of its own.
  bool _inShuttle = false;

  /// A shuttle is always supplied, because the key must never reach one — the
  /// same global key cannot be in the tree twice, and the placeholder is already
  /// holding it. But supplying one *shadows* the other end's
  /// ([Hero] resolves `toHero`'s builder, then `fromHero`'s, then its default),
  /// and the other end usually has the opinion worth keeping: the fullscreen
  /// viewer's shuttle is what animates a photo's crop open. So when this widget
  /// has no shuttle of its own it hands control back in the order Flutter would
  /// have used, and only falls through to the default — with the key taken back
  /// off — when nobody else wants it.
  Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final own = widget.flightShuttleBuilder;
    if (own != null) {
      return own(flightContext, animation, direction, fromHeroContext, toHeroContext);
    }
    if (!_inShuttle) {
      _inShuttle = true;
      try {
        for (final heroContext in [toHeroContext, fromHeroContext]) {
          final hero = heroContext.widget;
          if (hero is! Hero) continue;
          final builder = hero.flightShuttleBuilder;
          // Tear-offs of the same method on the same instance compare equal, so
          // this reliably recognises our own builder and skips it.
          if (builder == null || builder == _shuttle) continue;
          return builder(
              flightContext, animation, direction, fromHeroContext, toHeroContext);
        }
      } finally {
        _inShuttle = false;
      }
    }
    final destination = toHeroContext.widget;
    final child = destination is Hero ? destination.child : widget.child;
    return child is KeyedSubtree ? child.child : child;
  }

  /// Holds the slot open at the size the hero had when it took off, without
  /// dismantling what is in it.
  ///
  /// `Opacity(0)` rather than [Offstage]: it still lays the child out, so there
  /// is no layout left to do when the picture comes back, and it paints nothing,
  /// so the picture is never on screen in two places at once. [IgnorePointer]
  /// because an invisible child is still hit-testable, and a thumbnail that is
  /// currently mid-flight must not answer taps.
  Widget _placeholder(BuildContext context, Size heroSize, Widget child) {
    return SizedBox.fromSize(
      size: heroSize,
      child: IgnorePointer(child: Opacity(opacity: 0, child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: widget.tag,
      placeholderBuilder: _placeholder,
      flightShuttleBuilder: _shuttle,
      child: KeyedSubtree(key: _key, child: widget.child),
    );
  }
}
