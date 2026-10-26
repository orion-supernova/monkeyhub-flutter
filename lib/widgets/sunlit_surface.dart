import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';

// The house surface: lit from above, softly shadowed, tactile.
//
// It is the chrome disc's language (a white-ish disc, a top-down sunlight
// highlight, a thin lit rim, a soft shadow) lifted off the 44pt circle and
// onto cards, groups and sheets. Flutter cannot replicate native Liquid
// Glass, so this does not try: it is our own material, and it matters most
// on LIGHT themes, where white glass on a near-white page has nothing to
// show and a flat white card has no depth.
//
// Every value is derived from the theme: the shadow and the hairline are the
// theme's INK (a warm brown on Paper and Riso, a cool grey on Daylight), the
// highlight is white. No other colour appears.
//
// Dark themes: a card there already separates by luminance, so the dark
// recipe is deliberately quiet (a faint top light, a faint lit rim, a deeper
// shadow). `GroupedSection` does not use it on dark at all.

/// How tall the top light is. Fixed rather than a fraction of the surface so
/// a tall card is lit like a short one, only along its upper edge.
const double kSunlitLightDepth = 56;

/// How far down the sides the rim stays lit before it settles to the hairline.
const double _kRimLit = 22;

/// A box shadow pair for a sunlit surface, tuned per brightness: an ambient
/// blur that lifts the surface off the page and a tight contact shadow that
/// sits it on the page. [lift] scales both (1 = a card, 0.5 = a small
/// control, 0 = none).
///
/// Light shadows are the theme's ink, so they take the page's temperature
/// instead of the grey a pure-black shadow leaves on cream.
List<BoxShadow> sunlitShadows(AppTheme theme, {double lift = 1}) {
  if (lift <= 0) return const [];
  if (theme.isLight) {
    return [
      BoxShadow(
        color: theme.ink.withValues(alpha: 0.09 * lift),
        blurRadius: 22 * lift,
        offset: Offset(0, 8 * lift),
      ),
      BoxShadow(
        color: theme.ink.withValues(alpha: 0.04 * lift),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.32 * lift),
      blurRadius: 18 * lift,
      offset: Offset(0, 5 * lift),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.28 * lift),
      blurRadius: 2.5,
      offset: const Offset(0, 1),
    ),
  ];
}

/// The ink whisper that gives a small pale control (a chrome disc, a glass
/// pill) an edge on a light page, where a white rim cannot be seen. Cards use
/// a fraction of it and lean on light and shadow instead.
Color sunlitHairline(AppTheme theme) =>
    theme.ink.withValues(alpha: theme.isLight ? 0.045 : 0.0);

/// The top-down light as a gradient, for a custom shape that cannot use
/// [SunlitSurface] (a circle, a pill). Same stops and alphas as the surface.
LinearGradient sunlitHighlight(AppTheme theme) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        // Transparent WHITE, never Colors.transparent: fading to transparent
        // black lays a grey band across.
        Colors.white.withValues(alpha: theme.isLight ? 0.60 : 0.05),
        Colors.white.withValues(alpha: 0),
      ],
    );

/// A surface in the chrome disc's spirit: [fill], a top highlight, a thin
/// specular rim and a two-layer soft shadow, in a [borderRadius]-rounded box.
///
/// [fill] defaults to the theme's surface. [lift] scales the shadow (see
/// [sunlitShadows]); 0 keeps the light and the rim and drops the shadow, for
/// a surface inside another (a sheet's group). The child is clipped to the
/// shape and painted over the light, so rows and their press states sit ON
/// it. It is paint-only: no blur, no animation, nothing to calm.
class SunlitSurface extends StatelessWidget {
  const SunlitSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.fill,
    this.lift = 1,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color? fill;
  final double lift;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill ?? theme.surface,
        borderRadius: borderRadius,
        boxShadow: sunlitShadows(theme, lift: lift),
      ),
      child: CustomPaint(
        painter: _SunlitLight(
          theme: theme,
          borderRadius: borderRadius,
        ),
        foregroundPainter: _SunlitRim(
          theme: theme,
          borderRadius: borderRadius,
        ),
        child: ClipRRect(borderRadius: borderRadius, child: child),
      ),
    );
  }
}

/// The light that pools along the top edge.
class _SunlitLight extends CustomPainter {
  const _SunlitLight({required this.theme, required this.borderRadius});

  final AppTheme theme;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(borderRadius.toRRect(rect));
    final depth = size.height < kSunlitLightDepth
        ? size.height
        : kSunlitLightDepth;
    final top = Rect.fromLTWH(0, 0, size.width, depth);
    canvas.drawRect(
      top,
      Paint()..shader = sunlitHighlight(theme).createShader(top),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SunlitLight old) =>
      old.theme != theme || old.borderRadius != borderRadius;
}

/// The rim: a barely-there ink edge all the way round (light pages only, so
/// the shape is defined where the shadow is faintest) and the lit white edge
/// on top, which fades out smoothly from the top down the sides. One colour
/// family, two strokes, no join: nothing to kink at the corners.
class _SunlitRim extends CustomPainter {
  const _SunlitRim({required this.theme, required this.borderRadius});

  final AppTheme theme;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 1.0;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(width / 2);
    final light = theme.isLight;
    if (light) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = sunlitHairline(theme).withValues(alpha: 0.025),
      );
    }
    // The lit stretch is a fixed length, like the light itself.
    final fall = (_kRimLit / size.height).clamp(0.05, 0.9);
    final lit = Colors.white.withValues(alpha: light ? 0.95 : 0.14);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Transparent WHITE: the fade must not pass through grey.
          colors: [lit, Colors.white.withValues(alpha: light ? 0 : 0.03)],
          stops: [0, fall],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SunlitRim old) =>
      old.theme != theme || old.borderRadius != borderRadius;
}

/// The page behind sunlit surfaces. On a light theme it lays a very soft
/// top-down sunlight over [AppTheme.backgroundLayer] (a touch lighter at the
/// top, a touch deeper at the bottom, never more than ~3% of the page's
/// luminance) so a white card has something to lift off; a flat slab of one
/// colour gives the shadow nothing to fall on. Dark themes get the theme's own
/// layer, untouched.
class SunlitBackdrop extends StatelessWidget {
  const SunlitBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final layer = theme.backgroundLayer(context);
    if (!theme.isLight) return layer;
    // Two plain two-colour gradients, not one four-stop gradient through
    // transparent white and transparent ink: that interpolation is not worth
    // the risk of a premultiplied-alpha smear over a translucent layer.
    return Stack(
      fit: StackFit.expand,
      children: [
        layer,
        IgnorePointer(
          child: FractionallySizedBox(
            alignment: Alignment.topCenter,
            heightFactor: 0.3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        IgnorePointer(
          child: FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: 0.45,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.ink.withValues(alpha: 0),
                    theme.ink.withValues(alpha: 0.035),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }
}
