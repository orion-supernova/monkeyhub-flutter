import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

/// THE way glass enters and leaves: it grows out of [alignment] while what
/// sits on it fades. The glass itself is never faded.
///
/// Fading glass is the flicker this exists to end. A [BackdropFilter] inside
/// an [Opacity] (or a FadeTransition, or an AnimatedOpacity) is drawn into
/// the opacity's offscreen layer, and what it blurs there is that layer's
/// empty backdrop, not the page. So for every frame of the fade the panel is
/// a flat white wash, and on the frame the opacity reaches 1 Flutter drops
/// the layer and the real frost snaps in. Closing does the same in reverse.
/// It happened on every glass menu that opened with a fade.
///
/// Growing instead of fading keeps the blur reading the real page on every
/// frame, which is also how iOS unfolds a menu out of the control that opened
/// it. The fade still happens, on the content: [LiquidGlass] reads
/// [GlassContentFade] and fades its own labels and glyphs inside the blur,
/// where an [Opacity] costs nothing and breaks nothing.
///
/// [t] is the animation's value, 0 hidden to 1 shown; a spring may overshoot
/// past 1 and the scale follows it.
class GlassReveal extends StatelessWidget {
  const GlassReveal({
    super.key,
    required this.t,
    required this.child,
    this.alignment = Alignment.center,
    this.from = 0.3,
  });

  final double t;
  final Widget child;

  /// The corner or edge the glass grows out of: the control that opened it.
  final AlignmentGeometry alignment;

  /// The scale at [t] = 0. Small enough that the glass reads as unfolding
  /// from its anchor rather than popping in at nearly full size.
  final double from;

  @override
  Widget build(BuildContext context) {
    final shown = t.clamp(0.0, 1.0);
    return Transform.scale(
      scale: lerpDouble(from, 1, t)!,
      alignment: alignment,
      child: GlassContentFade(
        // The content trails the glass a little, so the labels don't swim
        // at a size where they cannot be read.
        opacity: Curves.easeIn.transform(shown),
        child: child,
      ),
    );
  }
}

/// How visible the content laid on glass is, for [GlassReveal]. Read by
/// [LiquidGlass], which fades its content inside the blur.
class GlassContentFade extends InheritedWidget {
  const GlassContentFade({
    super.key,
    required this.opacity,
    required super.child,
  });

  final double opacity;

  /// 1 when no [GlassReveal] is animating this glass.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassContentFade>()?.opacity ??
      1;

  @override
  bool updateShouldNotify(GlassContentFade old) => old.opacity != opacity;
}

/// Media glass under here draws its blur-free twin ([LiquidGlass.still]).
///
/// For chrome that must genuinely fade, not grow: a whole rail of controls
/// dimmed out of the way while something else has the screen. Inside a
/// fading layer a blur samples the layer's empty buffer, so the glass would
/// be a flat wash for the fade and snap to frost at the end of it. A still
/// disc has no blur to get wrong, and it looks the same at rest. The caller
/// keeps [still] true until its fade has fully settled at 1.
///
/// One signal over the subtree rather than a `still:` threaded to every
/// button, pill and panel in it: a control added to the rail later follows
/// the rule without anyone remembering to pass it. App-tone glass ignores it
/// (it has no blur-free twin of its own).
class GlassStill extends InheritedWidget {
  const GlassStill({super.key, required this.still, required super.child});

  final bool still;

  /// False when no [GlassStill] is above.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassStill>()?.still ?? false;

  @override
  bool updateShouldNotify(GlassStill old) => old.still != still;
}
