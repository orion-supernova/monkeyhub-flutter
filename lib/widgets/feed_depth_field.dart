import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// The slow-moving field of light behind the Feed board.
///
/// Three soft orbs drifting at different fractions of the scroll offset, plus a
/// small tilt toward wherever the finger is. It is the one thing that makes the
/// board read as a *surface with depth* rather than a list, and it is the only
/// motion that runs when the board is otherwise empty — which is exactly when a
/// new user is deciding whether this tab is worth anything.
///
/// Sits ABOVE `theme.backgroundLayer` and below the content. It never paints a
/// background of its own: several themes already draw expensive, characterful
/// backdrops (Risograph's halftone grid, Cyberpunk's scanlines, VaultNoir's
/// grain, BioOrganic's starfield) and this has to read as light moving over
/// them, not as a replacement for them.
///
/// **Performance shape.** The widget tree never rebuilds. Scroll and pointer
/// feed two [ValueNotifier]s, the painter is handed them through
/// `CustomPaint(repaint:)`, and the whole thing sits in a [RepaintBoundary]. So
/// a scroll costs one layer repaint, not a rebuild of the board. That matters
/// more here than usual: on `WindowClass.expanded` the themed background is
/// painted twice (shell and section both draw it), so this composites over an
/// already-expensive stack.
class FeedDepthField extends StatefulWidget {
  const FeedDepthField({super.key, required this.scroll});

  /// The board's scroll controller. Drives the parallax; the field is inert
  /// (but still painted) before the controller has clients.
  final ScrollController scroll;

  @override
  State<FeedDepthField> createState() => _FeedDepthFieldState();
}

class _FeedDepthFieldState extends State<FeedDepthField> {
  /// Normalised scroll depth. Kept as a raw pixel offset scaled at paint time
  /// so the notifier does not need to know the viewport.
  final _depth = ValueNotifier<double>(0);

  /// Pointer tilt on both axes, each clamped to -1..1.
  final _tilt = ValueNotifier<Offset>(Offset.zero);

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant FeedDepthField old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll.removeListener(_onScroll);
      widget.scroll.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_onScroll);
    _depth.dispose();
    _tilt.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scroll.hasClients) return;
    _depth.value = widget.scroll.position.pixels;
  }

  void _onPointer(PointerEvent e, Size size) {
    if (size.isEmpty) return;
    _tilt.value = Offset(
      ((e.position.dx / size.width) * 2 - 1).clamp(-1.0, 1.0),
      ((e.position.dy / size.height) * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);

    // Under calm motion the field is still PAINTED — it is part of the board's
    // identity, and deleting it would leave a flat rectangle where every other
    // theme has texture. It simply stops tracking: no scroll listener work, no
    // pointer tilt, no repaints at all. This is the "calm is a code path, not a
    // shorter duration" rule from MotionScope.
    if (motion.calm) {
      return IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _DepthFieldPainter(
              depth: 0,
              tilt: Offset.zero,
              accent: theme.accent,
              accentSoft: theme.accentSoft,
            ),
            size: Size.infinite,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          // Move-only, and behaviour: deferToChild would swallow nothing but
          // also receive nothing, since this widget has no hit-testable child.
          // `translucent` lets the board underneath keep every gesture while
          // still reporting pointer position here.
          behavior: HitTestBehavior.translucent,
          onPointerMove: (e) => _onPointer(e, size),
          onPointerHover: (e) => _onPointer(e, size),
          onPointerUp: (_) => _tilt.value = Offset.zero,
          onPointerCancel: (_) => _tilt.value = Offset.zero,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _DepthFieldPainter(
                depth: 0,
                tilt: Offset.zero,
                accent: theme.accent,
                accentSoft: theme.accentSoft,
                repaint: Listenable.merge([_depth, _tilt]),
                depthOf: () => _depth.value,
                tiltOf: () => _tilt.value,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}

/// Paints the three orbs.
///
/// Colours arrive as constructor arguments — painters in this codebase never
/// touch [BuildContext] or [ThemeScope]. The live values arrive as closures
/// rather than fields so the painter instance can stay stable across repaints
/// while still reading the notifiers' current values; `repaint:` is what
/// actually schedules the work.
class _DepthFieldPainter extends CustomPainter {
  _DepthFieldPainter({
    required this.depth,
    required this.tilt,
    required this.accent,
    required this.accentSoft,
    this.depthOf,
    this.tiltOf,
    super.repaint,
  });

  final double depth;
  final Offset tilt;
  final Color accent;
  final Color accentSoft;
  final double Function()? depthOf;
  final Offset Function()? tiltOf;

  /// Parallax rate per orb, as a fraction of scroll offset. Spread wide on
  /// purpose — three layers moving at similar rates read as one layer with a
  /// rendering glitch rather than as depth.
  static const _rates = [0.18, 0.34, 0.62];

  /// Tilt travel per orb, in logical pixels. Deliberately small: this is a
  /// hint of the surface being physical, not a gyroscope toy. Anything past
  /// ~10pt starts to look like the content is sliding off.
  static const _tiltTravel = [6.0, 10.0, 16.0];

  /// Orb geometry as fractions of the viewport, so it composes at any window
  /// size without a breakpoint. Seeded by hand rather than randomly — a fixed
  /// arrangement can be judged against every theme, a random one cannot.
  static const _origins = [Offset(0.18, 0.12), Offset(0.86, 0.34), Offset(0.42, 0.78)];
  static const _radii = [0.52, 0.40, 0.62];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final d = depthOf?.call() ?? depth;
    final t = tiltOf?.call() ?? tilt;

    for (var i = 0; i < _origins.length; i++) {
      final radius = size.shortestSide * _radii[i];
      final centre = Offset(
        size.width * _origins[i].dx + t.dx * _tiltTravel[i],
        size.height * _origins[i].dy - d * _rates[i] + t.dy * _tiltTravel[i],
      );

      // Cull once the orb has scrolled entirely clear. Cheap, and it means a
      // long board stops paying for the top orb the moment it is gone.
      if (centre.dy + radius < 0 || centre.dy - radius > size.height) continue;

      // Alternating accent/accentSoft rather than one colour at two alphas:
      // several themes give accentSoft a genuinely different hue (it is a
      // surface tint, not a faded accent), and using both is what keeps the
      // field from reading as a single flat wash.
      final base = i.isEven ? accent : accentSoft;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              base.withValues(alpha: 0.10),
              base.withValues(alpha: 0.0),
            ],
            // Push the falloff outward so the orb has a soft shoulder instead
            // of a visible edge. A plain two-stop gradient bands badly on the
            // light themes, where there is no grain to hide it.
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_DepthFieldPainter old) =>
      // Real field comparison, per the house rule. The live values come through
      // `repaint:`, so this only has to catch a theme change (new colours) and
      // the static/live swap that calm motion performs.
      old.accent != accent ||
      old.accentSoft != accentSoft ||
      old.depth != depth ||
      old.tilt != tilt ||
      (old.depthOf == null) != (depthOf == null);

  @override
  bool hitTest(Offset position) => false;
}

/// Exposed for `test/feed_depth_field_test.dart` so the parallax arithmetic can
/// be checked without pumping a widget — the same discipline `RadialGeometry`
/// uses for the nav fan.
@visibleForTesting
Offset orbCentreFor({
  required int index,
  required Size size,
  required double depth,
  required Offset tilt,
}) {
  final origins = _DepthFieldPainter._origins;
  final rates = _DepthFieldPainter._rates;
  final travel = _DepthFieldPainter._tiltTravel;
  final i = index % origins.length;
  return Offset(
    size.width * origins[i].dx + tilt.dx * travel[i],
    size.height * origins[i].dy - depth * rates[i] + tilt.dy * travel[i],
  );
}

/// Radius of orb [index] for a viewport of [size].
@visibleForTesting
double orbRadiusFor({required int index, required Size size}) =>
    size.shortestSide * _DepthFieldPainter._radii[index % 3];

/// Whether orb [index] is entirely off-screen and can be skipped.
@visibleForTesting
bool orbCulled({
  required int index,
  required Size size,
  required double depth,
  required Offset tilt,
}) {
  final c = orbCentreFor(index: index, size: size, depth: depth, tilt: tilt);
  final r = orbRadiusFor(index: index, size: size);
  return c.dy + r < 0 || c.dy - r > size.height;
}
