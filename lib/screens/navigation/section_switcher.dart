import 'package:flutter/material.dart';

import '../../data/settings_store.dart';
import '../../theme/motion.dart';
import 'destinations.dart';

/// How long a section transition runs. Longer than the `motionMed` it replaced
/// — the arriving section has all of it to glide, and it finishes fading well
/// before the end so the child underneath can be discarded without anything
/// showing through.
const Duration _kDuration = Duration(milliseconds: 440);

/// The arriving section is opaque by 70% of the way in; the rest of the time it
/// is only still gliding. Fading and moving on the same clock makes the arrival
/// read as one long dissolve rather than as something coming to rest.
const Curve _kFade = Interval(0, 0.7, curve: Curves.easeInOutCubic);

/// Emphasized deceleration: nearly all the distance early, then a long, slow
/// arrival. The tail is what reads as weight; a plain `easeOut` stops dead.
const Curve _kGlide = Cubic(0.05, 0.7, 0.1, 1);

/// How far the arriving section slides, as a fraction of its own width. Small
/// on purpose — this is a hint of direction, not a page swipe, and a section
/// that travels far has to travel fast to arrive on time, which is the opposite
/// of what the slide is for.
const double _kSlide = 0.045;

/// Most layers a frantic tapper can stack up before the oldest — and by then
/// the most thoroughly covered — start being dropped. Only reachable by
/// switching sections faster than [_kDuration] over and over; one completed
/// transition clears the lot.
const int _kMaxRetired = 3;

/// Cross-fades the shell's major sections, sliding the arriving one in from the
/// side it lives on in [navOrder].
///
/// The section being replaced is held **fully opaque and still** underneath
/// until the arriving one has completely covered it. That asymmetry is the
/// whole design. A symmetric cross-fade has both children translucent through
/// the middle of the transition, and there is no app-wide backdrop behind the
/// compact shell — each section paints its own — so the overlap shows through
/// to bare canvas. The usual fix is to fade the outgoing child out fast, and
/// "fast" is exactly why switching tabs used to read as a cut. Held opaque
/// underneath, the arriving section can take as long as it likes.
///
/// Hand-rolled rather than an [AnimatedSwitcher] for that one reason.
/// AnimatedSwitcher builds each child's transition *once*, when it becomes the
/// current child, and then runs that same widget in reverse on the way out — so
/// "the leaver does something different from the arriver" is not expressible
/// through it. Trying anyway, by branching inside its `transitionBuilder`, is
/// worse than it looks: the builder only re-runs when its own identity changes,
/// an inline closure changes identity on every rebuild of the owner, and the
/// branch returned a different widget *type* for the leaver — which unmounts
/// and reconstructs an entire section, mid-transition, on every tab change.
/// That was a visible flicker, and it is what `test/section_switcher_test.dart`
/// exists to prevent a return of.
///
/// Its own widget, and public, so that test can pump it at all: the shell needs
/// five backend services to build, so anything living inside it is checked by
/// nothing.
class SectionSwitcher extends StatefulWidget {
  const SectionSwitcher({
    super.key,
    required this.section,
    required this.variant,
    required this.child,
  });

  /// The section [child] renders. Changing it runs a transition, in the
  /// direction implied by [navOrder].
  final HomeSection section;

  /// Anything else that should re-key the child — the theme id, and which
  /// shell is asking. A change here cross-fades in place instead of pretending
  /// to navigate, because nothing navigated.
  final String variant;

  final Widget child;

  @override
  State<SectionSwitcher> createState() => _SectionSwitcherState();
}

class _SectionSwitcherState extends State<SectionSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: _kDuration,
    value: 1,
  )..addStatusListener(_onArrived);

  /// Sections that have been replaced but are not yet covered, oldest first.
  ///
  /// Usually zero or one. More than one only when a transition is interrupted
  /// by another, and each is frozen at the opacity and offset it had at that
  /// moment — so an interruption changes nothing on screen for the frame it
  /// happens in, which is the difference between a live redirect and a blink.
  final List<_Retired> _retired = [];

  /// Both assigned in [initState] rather than by a `late` initializer.
  /// A lazy initializer is evaluated on first *read*, and the first read of
  /// [_index] is inside [didUpdateWidget] — where `widget` is already the new
  /// one, so it would initialise to the index it is being compared against and
  /// every transition would travel backwards.
  late Key _key;
  late int _index;

  /// Which way the current arrival travels: +1 when it sits later in
  /// [navOrder] than the section it replaces, -1 earlier, 0 when only
  /// [SectionSwitcher.variant] changed and nothing navigated.
  int _travel = 0;

  static Key _keyFor(SectionSwitcher w) =>
      ValueKey('${w.section.name}_${w.variant}');

  @override
  void initState() {
    super.initState();
    _key = _keyFor(widget);
    _index = navIndexOf(widget.section);
  }

  @override
  void didUpdateWidget(covariant SectionSwitcher old) {
    super.didUpdateWidget(old);
    final key = _keyFor(widget);
    if (key == _key) return;

    // Retired first, while [_travel] still describes the journey the child
    // being replaced was on: it is frozen mid-slide, and freezing it against
    // the *next* transition's direction would jerk it sideways at the exact
    // moment it is supposed to stop moving.
    _retire(old.child);
    _key = key;

    final i = navIndexOf(widget.section);
    _travel = widget.section == old.section ? 0 : (i > _index ? 1 : -1);
    _index = i;
    if (MotionScope.of(context).calm) {
      // Nothing to cover, so nothing to keep underneath.
      _retired.clear();
      _arrival.value = 1;
    } else {
      _arrival.forward(from: 0);
    }
  }

  /// Freezes the child being replaced where it is and parks it underneath.
  void _retire(Widget child) {
    final t = _arrival.value;
    final opacity = _kFade.transform(t);
    // Anything below a fully opaque layer is invisible; drop it rather than
    // keep paying to paint it.
    if (opacity >= 1) {
      _retired.clear();
    } else if (_retired.length >= _kMaxRetired) {
      _retired.removeAt(0);
    }
    _retired.add(
      _Retired(key: _key, child: child, opacity: opacity, dx: _travelOffset(t)),
    );
  }

  double _travelOffset(double t) =>
      _travel * _kSlide * (1 - _kGlide.transform(t));

  void _onArrived(AnimationStatus status) {
    // The arriving section is opaque well before the end (see [_kFade]), but
    // the ones underneath are only *certainly* covered once it has stopped
    // moving — until then its slide leaves a sliver of them showing.
    if (status != AnimationStatus.completed || _retired.isEmpty) return;
    setState(_retired.clear);
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  /// Every layer, live or frozen, is built to the identical widget shape,
  /// under a key, at the top.
  ///
  /// Both halves of that matter, and neither is cosmetic:
  ///
  ///  * **Identical shape.** A layer whose structure changes when it is retired
  ///    cannot be updated in place, so its whole subtree — a real section, with
  ///    its scroll offsets and controllers — is thrown away and rebuilt at the
  ///    exact moment it is supposed to be sitting perfectly still.
  ///  * **Key on the outside.** The [Stack]'s children are matched by
  ///    `runtimeType` and key, in order, and this list grows and shrinks from
  ///    the *front* as sections retire and are dropped. Unkeyed, every layer is
  ///    an interchangeable [FadeTransition] and the arriving section gets
  ///    matched against the departing one's element — which reconstructs it
  ///    from scratch, one frame after it appeared. A key buried further down
  ///    the subtree does not help: by then the match has already been made
  ///    above it.
  Widget _layer({
    required Key key,
    required Animation<double> opacity,
    required Animation<Offset> position,
    required Widget child,
  }) {
    return KeyedSubtree(
      key: key,
      child: FadeTransition(
        opacity: opacity,
        child: SlideTransition(position: position, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final r in _retired)
          _layer(
            key: r.key,
            opacity: AlwaysStoppedAnimation(r.opacity),
            position: AlwaysStoppedAnimation(Offset(r.dx, 0)),
            child: r.child,
          ),
        _layer(
          key: _key,
          opacity: _arrival.drive(CurveTween(curve: _kFade)),
          position: _arrival.drive(
            Tween(
              begin: Offset(_travel * _kSlide, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: _kGlide)),
          ),
          child: widget.child,
        ),
      ],
    );
  }
}

/// A replaced section, frozen at the moment it was replaced.
@immutable
class _Retired {
  const _Retired({
    required this.key,
    required this.child,
    required this.opacity,
    required this.dx,
  });
  final Key key;

  /// The exact widget instance that was on screen. Reused rather than rebuilt,
  /// so a retired section costs a paint and nothing else.
  final Widget child;
  final double opacity;
  final double dx;
}
