import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// A badge that pops when its count goes up.
///
/// A number that silently ticks from 2 to 3 is a re-render; one that swells a
/// little and settles is "something just arrived", which is what the count is
/// for. Only a rise pops: reading a chat drains its count, and the reader
/// already knows they did that.
///
/// Arriving from zero (the badge appearing at all) springs in from nothing
/// instead, so a fresh badge grows into place rather than blinking on.
///
/// Free when idle: the controller only ticks for the ~half second after a
/// change, and the scale is a [ScaleTransition] (a transform at paint), so the
/// badge's own layout and text never rebuild for it. Calm motion skips it.
class CountBump extends StatefulWidget {
  const CountBump({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  State<CountBump> createState() => _CountBumpState();
}

class _CountBumpState extends State<CountBump>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  /// Which shape the current run plays: a pop (1 → 1.22 → 1) for a rise, or a
  /// spring in from zero for an arrival.
  bool _arriving = false;

  static final _pop = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.22)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 28,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.22, end: 1.0)
          .chain(CurveTween(curve: Curves.elasticOut)),
      weight: 72,
    ),
  ]);

  static final _arrive = CurveTween(curve: Curves.elasticOut);

  late final Animation<double> _scale = _c.drive(
    _Switching(() => _arriving ? _arrive : _pop),
  );

  @override
  void didUpdateWidget(CountBump old) {
    super.didUpdateWidget(old);
    if (widget.count <= old.count) return;
    if (MotionScope.of(context).calm) return;
    _arriving = old.count <= 0;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// An [Animatable] that defers to whichever one [pick] returns, so a single
/// driven animation can play either shape without being rebuilt.
class _Switching extends Animatable<double> {
  _Switching(this.pick);
  final Animatable<double> Function() pick;

  @override
  double transform(double t) => pick().transform(t);
}
