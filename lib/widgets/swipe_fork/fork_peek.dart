import 'package:flutter/widgets.dart';

import '../swipe_fork.dart';

/// The swipe-up fork's discoverability peek: the transcript nudges up a few
/// points and settles back once, with the small circle fading in and out in the
/// gap, exactly as a real pull would open it. No widget of its own to look at:
/// it drives [SwipeForkController.peekValue] and the lift and the overlay paint
/// it.
///
/// Plays once on mount (about a second) and calls [onDone]. The host decides
/// whether it may be mounted at all (counters, platform, Reduce Motion). A real
/// pull that starts meanwhile takes over and the peek stands down.
class ForkPeek extends StatefulWidget {
  const ForkPeek({
    super.key,
    required this.controller,
    required this.semanticLabel,
    this.onDone,
  });

  final SwipeForkController controller;
  final String semanticLabel;
  final VoidCallback? onDone;

  /// Total play time.
  static const Duration duration = Duration(milliseconds: 1000);

  /// How far the list rises, in points.
  static const double rise = 10;

  /// The circle's opacity at [t]: in over the first quarter, out over the last
  /// half. Scaled down in the painter so it stays a hint.
  static double opacityAt(double t) {
    if (t < 0.25) return Curves.easeOut.transform(t / 0.25);
    if (t < 0.5) return 1;
    return 1 - Curves.easeIn.transform((t - 0.5) / 0.5);
  }

  @override
  State<ForkPeek> createState() => _ForkPeekState();
}

class _ForkPeekState extends State<ForkPeek>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: ForkPeek.duration,
  )
    ..addListener(_push)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _stop();
        widget.onDone?.call();
      }
    });

  SwipeForkController get _fork => widget.controller;

  void _push() {
    // A real gesture owns the screen: stand down.
    if (_fork.busy) {
      _c.stop();
      return;
    }
    _fork.peekValue.value = _c.value;
  }

  void _stop() => _fork.endPeek();

  @override
  void initState() {
    super.initState();
    _fork.peekValue.value = 0;
    _fork.peekOn.value = true;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    // The tree is locked while we are torn down: let the overlay hear it after.
    WidgetsBinding.instance.addPostFrameCallback((_) => _stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: widget.semanticLabel,
        child: const SizedBox.shrink(),
      );
}
