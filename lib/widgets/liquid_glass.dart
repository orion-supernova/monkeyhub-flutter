import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/glass_config.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../screens/navigation/native_tab_bar.dart' show NativeChrome;
import '../theme/theme_scope.dart';
import 'spring_press.dart';

enum LiquidGlassShape { circle, capsule, rounded }

/// What a piece of glass sits over, which decides how it is lit.
///
/// * [app] — the app's own pages. Follows the glass engine: iOS Liquid Glass
///   wears the matched recipe, Frosted wears the user's tuning.
/// * [media] — photographs, video and the camera. The backdrop is arbitrary,
///   so a theme-tinted glass can vanish over a bright sky; this glass is a
///   fixed neutral dark with white ink on every theme, and the theme speaks
///   only through a [LiquidGlass.tint] on a control that is on.
enum GlassTone { app, media }

/// The palette of [GlassTone.media] glass — and of anything that sits on it
/// (ink for icons and labels). One set of values for the camera, the editor,
/// every viewer and the photo tray.
abstract final class MediaGlass {
  /// Translucent white over the blur. Reads as glass on any photo.
  static const fill = Color(0x2BFFFFFF);
  static const fillPressed = Color(0x3DFFFFFF);

  /// Hairline that separates the glass from whatever is behind it. Without it
  /// a button over a light photo has no edge at all.
  static const stroke = Color(0x33FFFFFF);

  static const ink = Color(0xFFFFFFFF);
  static const inkDim = Color(0x8AFFFFFF);
  static const inkDisabled = Color(0x4DFFFFFF);

  /// Every media surface blurs by the same amount, so a row of them reads as
  /// one pane of glass rather than a row of unrelated buttons.
  static const blurSigma = 20.0;

  /// Centred, not dropped: an offset shadow reads as a grey lip under the
  /// glass. Centred, it still separates white glass from a bright photo.
  static const shadow = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 14,
  );
}

/// THE glass of the app. Every glass surface — buttons, pills, menus, bars,
/// camera and viewer chrome — is this widget, so they read as one material.
///
/// Performance note: the blur is rendered through `BackdropFilter.grouped`,
/// which pairs with a `BackdropGroup` ancestor so all sibling glass surfaces
/// share a single rasterization pass. The blur itself is never animated.
///
/// Interactive when [onTap] is given: it springs through [SpringPress] like
/// every other control, and brightens while held.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.shape = LiquidGlassShape.circle,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.size,
    this.tinted = false,
    this.tint,
    this.tone = GlassTone.app,
    this.shadow = true,
    this.onTap,
    this.semanticLabel,
    this.config,
  });

  final Widget child;
  final LiquidGlassShape shape;
  final double radius;
  final EdgeInsets padding;
  final Size? size;

  /// A light accent wash over the frost (the app tone's "selected" glass).
  final bool tinted;

  /// A solid fill instead of glass — for a control that is ON (the armed pen,
  /// an active toggle, the primary Send pill).
  final Color? tint;
  final GlassTone tone;

  /// Whether the surface casts its shadow. Off for glass nested in glass.
  final bool shadow;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Dial positions for this surface. Null — every caller but the bottom bar —
  /// means "whatever the user has set for the app", read live from
  /// [SettingsStore.glass]. Ignored by [GlassTone.media].
  ///
  /// One config rather than a parameter per dial: there are eight of them, they
  /// are always set together, and they have to round-trip through a saved slot
  /// as a unit anyway.
  final GlassConfig? config;

  FocusRingShape get _ringShape => switch (shape) {
        LiquidGlassShape.circle => FocusRingShape.circle,
        LiquidGlassShape.capsule => FocusRingShape.capsule,
        LiquidGlassShape.rounded => FocusRingShape.rounded,
      };

  OutlinedBorder _border({BorderSide side = BorderSide.none}) =>
      switch (shape) {
        LiquidGlassShape.circle => CircleBorder(side: side),
        LiquidGlassShape.capsule => StadiumBorder(side: side),
        LiquidGlassShape.rounded => RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: side,
          ),
      };

  @override
  Widget build(BuildContext context) {
    Widget surface(bool pressed) => _sized(_material(context, pressed));
    if (onTap == null) return surface(false);
    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: 0.94,
      semanticLabel: semanticLabel,
      focusShape: _ringShape,
      focusRadius: radius,
      builder: (context, pressed) => surface(pressed),
    );
  }

  Widget _sized(Widget glass) => size == null
      ? glass
      : SizedBox(width: size!.width, height: size!.height, child: glass);

  /// The engine-aware material: which recipe the glass wears.
  Widget _material(BuildContext context, bool pressed) {
    if (tone == GlassTone.media) return _media(pressed);
    final cfg = config;
    if (cfg != null) return _app(context, cfg, pressed);
    // While iOS draws the tab bar, every app-drawn surface wears the matched
    // recipe instead of the user's tuning, so the two read as one material.
    if (NativeChrome.active) return _app(context, kNativeMatchGlass, pressed);
    // Only surfaces following the app-wide tuning subscribe. The bottom bar is
    // handed its config by a parent that already rebuilds on settings changes,
    // so making it listen too would just double the rebuilds.
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) =>
          _app(context, SettingsStore.instance.glass.app, pressed),
    );
  }

  /// The content laid over the glass. A Stack sizes to its non-positioned
  /// children, so THIS decides how wide the glass is: centred only when
  /// [size] pins the box (there is slack to centre within), otherwise the
  /// glass shrink-wraps its content — a capsule around two words never
  /// paints full width.
  Widget _content() => Padding(
        padding: padding,
        child: size == null ? child : Center(child: child),
      );

  /// Saturate first, then blur. The other order blurs the colour into its
  /// neighbours before boosting it, so the boost lands on an already-averaged
  /// backdrop and mostly amplifies the haze.
  static ImageFilter _backdrop(GlassConfig cfg) {
    final sigma = cfg.of(kBlur);
    final blur = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    final saturation = cfg.of(kSaturation);
    // Tolerance, not equality: a slider lands on 0.997 as readily as on 1, and
    // composing an identity matrix costs a whole extra filter pass per frame
    // on every glass surface in the app.
    if ((saturation - 1).abs() < 0.02) return blur;
    return ImageFilter.compose(outer: blur, inner: _saturate(saturation));
  }

  /// Standard luminance-preserving saturation matrix — the channel weights are
  /// Rec. 709, so boosting colour does not also drag the backdrop's brightness
  /// around.
  static ColorFilter _saturate(double s) {
    const lr = 0.213, lg = 0.715, lb = 0.072;
    final i = 1 - s;
    return ColorFilter.matrix(<double>[
      lr * i + s, lg * i, lb * i, 0, 0,
      lr * i, lg * i + s, lb * i, 0, 0,
      lr * i, lg * i, lb * i + s, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  /// Glass over a photograph: fixed neutral dark, white hairline, the one
  /// media blur. A [tint] makes it a solid, lit control.
  Widget _media(bool pressed) {
    final t = tint;
    final fill = t ?? (pressed ? MediaGlass.fillPressed : MediaGlass.fill);
    final stroke = t == null
        ? MediaGlass.stroke
        : Color.lerp(t, const Color(0xFFFFFFFF), 0.25)!;
    final blurred = ClipPath(
      clipper: ShapeBorderClipper(shape: _border()),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(
          sigmaX: MediaGlass.blurSigma,
          sigmaY: MediaGlass.blurSigma,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: fill)),
            _content(),
          ],
        ),
      ),
    );
    // Stroke and shadow sit outside the clip so the shadow casts past the
    // glass instead of being cut off at its own edge.
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: _border(side: BorderSide(color: stroke, width: 0.8)),
        shadows: shadow ? const [MediaGlass.shadow] : null,
      ),
      child: blurred,
    );
  }

  /// Glass on the app's own pages, in either engine's recipe.
  Widget _app(BuildContext context, GlassConfig cfg, bool pressed) {
    final theme = ThemeScope.of(context);
    // The theme's brightness, not the phone's: Midnight on a phone in light
    // mode is a dark page, and wanted dark frost.
    final isLight = theme.background.computeLuminance() > 0.5;
    final matched = identical(cfg, kNativeMatchGlass);

    final frost = cfg.of(kFrost);
    final frostAlpha = (isLight ? 0.55 : 0.35) * frost;
    final overlayTop = (isLight ? 0.45 : 0.10) * frost;
    final overlayMid = 0.05 * frost;

    final clipShape = _border();
    // Apple's glass has a white specular edge; the app's own frosted glass
    // keeps its accent rim.
    final rimTint = matched ? Colors.white : theme.accent;
    final framedShape = _border(
      side: BorderSide(
        color: rimTint.withValues(alpha: cfg.of(kRimOpacity)),
        width: cfg.of(kRimWidth),
      ),
    );

    final Color base = tint ??
        (matched
            // Matched glass is a neutral, nearly clear tint rather than a
            // wash of the theme's surface — iOS glass carries the colour of
            // what is behind it, not of the app.
            ? Colors.white.withValues(alpha: isLight ? 0.72 : 0.07)
            : theme.surface.withValues(alpha: frostAlpha));

    final Gradient? overlay = tint != null
        ? null
        : matched && !tinted
            // Light pooling inside the top of the glass, in place of the
            // frosted look's diagonal sheen.
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isLight ? 0.25 : 0.10),
                  // Transparent WHITE: fading to Colors.transparent
                  // (transparent black) passes through grey and laid a dull
                  // band across the glass.
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.55],
              )
            : tinted
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.accent.withValues(alpha: 0.50),
                      theme.accent.withValues(alpha: 0.18),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: overlayTop),
                      Colors.white.withValues(alpha: overlayMid),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  );

    // BackdropFilter.grouped looks up the nearest BackdropGroup ancestor and
    // shares a single rasterization pass across all sibling grouped filters.
    // Falls back to a private group if no ancestor is found.
    final blurred = ClipPath(
      clipper: ShapeBorderClipper(shape: clipShape),
      child: BackdropFilter.grouped(
        filter: _backdrop(cfg),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: base)),
            if (overlay != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: overlay),
                ),
              ),
            // Held: a little more light in the glass, the way iOS glass
            // brightens under a finger.
            if (pressed)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: isLight ? 0.18 : 0.06),
                ),
              ),
            _content(),
          ],
        ),
      ),
    );

    if (matched) return _matchedFrame(clipShape, isLight, blurred);

    // Stroke + shadow live outside the clip so the shadow casts past the glass.
    // On a light page a dropped shadow reads as a hard grey lip under the
    // glass — the elevated-FAB look. Centred and halved there, it floats the
    // surface instead; dark themes keep exactly what was tuned.
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: framedShape,
        shadows: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: cfg.of(kShadowOpacity) * (isLight ? 0.5 : 1),
                  ),
                  blurRadius: cfg.of(kShadowBlur),
                  offset: Offset(0, isLight ? 0 : cfg.of(kShadowY)),
                ),
              ]
            : null,
      ),
      child: blurred,
    );
  }

  /// The edge and shadow of matched (iOS Liquid Glass) glass: a specular rim
  /// brightest along the top, fading down the sides and catching a little
  /// light again at the bottom — the lit edge that makes iOS 26 glass read as
  /// a material over a flat page, where there is nothing behind it to bend.
  Widget _matchedFrame(OutlinedBorder shape, bool isLight, Widget glass) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.24),
                  blurRadius: isLight ? 16 : 18,
                  offset: Offset(0, isLight ? 0 : 5),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        foregroundPainter: SpecularRim(shape: shape, light: isLight),
        child: glass,
      ),
    );
  }
}

/// Strokes [shape]'s outline with a top-lit gradient — the specular rim of
/// matched glass. Paint-only and cheap: one path, one shader, no layers.
///
/// Public because the chrome disc (`glass_buttons.dart`) wears the same lit
/// edge: the 40pt × on a sheet and the one on a page are one button, and the
/// rim is most of what makes them read as one.
class SpecularRim extends CustomPainter {
  const SpecularRim({required this.shape, required this.light});

  final OutlinedBorder shape;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: light
            ? [
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.60),
              ]
            : [
                Colors.white.withValues(alpha: 0.42),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.16),
              ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawPath(shape.getOuterPath(rect.deflate(0.5)), paint);
  }

  @override
  bool shouldRepaint(SpecularRim old) =>
      old.light != light || old.shape != shape;
}
