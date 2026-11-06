import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

import '../../theme/theme_scope.dart';

/// The swipe-up fork's discoverability peek: one small upward chevron that
/// rises a few points and fades, just above the composer. Glyph only.
///
/// Plays once on mount (about a second) and calls [onDone]. The host decides
/// whether it may be mounted at all (counters, platform, Reduce Motion).
class ForkPeek extends StatefulWidget {
  const ForkPeek({super.key, required this.semanticLabel, this.onDone});

  final String semanticLabel;
  final VoidCallback? onDone;

  /// Total play time.
  static const Duration duration = Duration(milliseconds: 1000);

  /// How far the chevron rises, in points.
  static const double rise = 10;

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

  /// Fades in over the first quarter, out over the last half.
  static double opacityAt(double t) {
    if (t < 0.25) return Curves.easeOut.transform(t / 0.25);
    if (t < 0.5) return 1;
    return 1 - Curves.easeIn.transform((t - 0.5) / 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return IgnorePointer(
      child: Semantics(
        label: widget.semanticLabel,
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              return Opacity(
                opacity: opacityAt(t) * 0.7,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    -ForkPeek.rise * Curves.easeOutCubic.transform(t),
                  ),
                  child: Icon(
                    CupertinoIcons.chevron_up,
                    size: 20,
                    color: theme.inkSoft,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
