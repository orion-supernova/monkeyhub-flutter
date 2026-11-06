import 'package:flutter/widgets.dart';

/// The swipe-up's discoverability peek: the tops of the capsules rise 8pt out
/// of the dock's edge, hold a beat and slide back. Colour only, no words.
///
/// Plays once on mount (about a second) and calls [onDone]. The host decides
/// whether it may be mounted at all (counters, platform, Reduce Motion), and
/// anchors it so its bottom edge is the dock's top edge.
class ForkPeek extends StatefulWidget {
  const ForkPeek({
    super.key,
    required this.semanticLabel,
    this.colors = const [Color(0xFF8E8E93)],
    this.onDone,
  });

  final String semanticLabel;

  /// The capsules' fills, left to right on screen: one wide capsule or two.
  final List<Color> colors;

  final VoidCallback? onDone;

  /// Total play time.
  static const Duration duration = Duration(milliseconds: 1000);

  /// How far the capsules peek out, in points.
  static const double rise = 8;

  /// Side margin and gap, the same as the capsules' own.
  static const double margin = 12;
  static const double gap = 6;

  @override
  State<ForkPeek> createState() => _ForkPeekState();
}

class _ForkPeekState extends State<ForkPeek>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: ForkPeek.duration,
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 0 hidden, 1 fully peeking: up over the first third, hold, back down over
  /// the last third.
  static double peekAt(double t) {
    if (t < 0.33) return Curves.easeOutCubic.transform(t / 0.33);
    if (t < 0.6) return 1;
    return 1 - Curves.easeInCubic.transform((t - 0.6) / 0.4);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: widget.semanticLabel,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ForkPeek.margin),
            child: SizedBox(
              height: ForkPeek.rise,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, ForkPeek.rise * (1 - peekAt(_c.value))),
                    child: child,
                  ),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 40,
                    maxHeight: 40,
                    child: Row(
                      children: [
                        for (var i = 0; i < widget.colors.length; i++) ...[
                          if (i > 0) const SizedBox(width: ForkPeek.gap),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: widget.colors[i],
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
