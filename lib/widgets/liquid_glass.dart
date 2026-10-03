import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/glass_config.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../screens/navigation/native_tab_bar.dart' show NativeChrome;
import '../theme/theme_scope.dart';
import 'teardown_safe.dart';

enum LiquidGlassShape { circle, capsule, rounded }

/// Frosted-glass surface — clones the visual recipe from MonkeyHub v02's
/// `LiquidGlassModifier` (frosted blur + translucent fill + diagonal white
/// sheen + accent stroke + soft drop shadow).
///
/// Performance note: the blur is rendered through `BackdropFilter.grouped`,
/// which pairs with a `BackdropGroup` ancestor so all sibling glass surfaces
/// share a single rasterization pass. With seven instances per screen (header
/// pill + two header buttons + composer attach + camera + field + send) the
/// cost drops from seven full-screen blurs per frame to one.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.shape = LiquidGlassShape.circle,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.size,
    this.tinted = false,
    this.onTap,
    this.config,
  });

  final Widget child;
  final LiquidGlassShape shape;
  final double radius;
  final EdgeInsets padding;
  final Size? size;
  final bool tinted;
  final VoidCallback? onTap;

  /// Dial positions for this surface. Null — every caller but the bottom bar —
  /// means "whatever the user has set for the app", read live from
  /// [SettingsStore.glass].
  ///
  /// One config rather than a parameter per dial: there are eight of them, they
  /// are always set together, and they have to round-trip through a saved slot
  /// as a unit anyway.
  final GlassConfig? config;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass>
    with TeardownSafe<LiquidGlass> {
  bool _pressed = false;

  /// Saturate first, then blur. The other order blurs the colour into its
  /// neighbours before boosting it, so the boost lands on an already-averaged
  /// backdrop and mostly amplifies the haze.
  ImageFilter _backdrop(GlassConfig cfg) {
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

  OutlinedBorder _border({BorderSide side = BorderSide.none}) {
    switch (widget.shape) {
      case LiquidGlassShape.circle:
        return CircleBorder(side: side);
      case LiquidGlassShape.capsule:
        return StadiumBorder(side: side);
      case LiquidGlassShape.rounded:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.radius),
          side: side,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    if (config != null) return _build(context, config);
    // While iOS draws the tab bar, every app-drawn surface wears the matched
    // recipe instead of the user's tuning, so the two read as one material.
    if (NativeChrome.active) return _build(context, kNativeMatchGlass);
    // Only surfaces following the app-wide tuning subscribe. The bottom bar is
    // handed its config by a parent that already rebuilds on settings changes,
    // so making it listen too would just double the rebuilds.
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) =>
          _build(context, SettingsStore.instance.glass.app),
    );
  }

  Widget _build(BuildContext context, GlassConfig cfg) {
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
    final rimTint = identical(cfg, kNativeMatchGlass) ? Colors.white : theme.accent;
    final framedShape = _border(
      side: BorderSide(
        color: rimTint.withValues(alpha: cfg.of(kRimOpacity)),
        width: cfg.of(kRimWidth),
      ),
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
            Positioned.fill(
              child: Container(
                // Matched glass is a neutral, nearly clear tint rather than
                // a wash of the theme's surface — iOS glass carries the
                // colour of what is behind it, not of the app.
                color: matched
                    ? Colors.white.withValues(alpha: isLight ? 0.72 : 0.07)
                    : theme.surface.withValues(alpha: frostAlpha),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: matched && !widget.tinted
                      // Light pooling inside the top of the glass, in place
                      // of the frosted look's diagonal sheen.
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: isLight ? 0.25 : 0.10),
                            // Transparent WHITE: fading to Colors.transparent
                            // (transparent black) passes through grey and
                            // laid a dull band across the glass.
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.55],
                        )
                      : widget.tinted
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
                            // Transparent white — see the matched glow above.
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                ),
              ),
            ),
            // A Stack sizes to its non-positioned children, so THIS decides
            // how wide the glass is. Centring unconditionally made that child
            // an Align, which expands to fill whatever bounded width it is
            // given — so a capsule around two words still painted full width,
            // and every caller that wanted a pill had to defend itself with
            // an IntrinsicWidth. Centre only when [size] pins the box, where
            // there is real slack to centre the child within; otherwise let
            // the glass shrink-wrap its content.
            Padding(
              padding: widget.padding,
              child: widget.size == null
                  ? widget.child
                  : Center(child: widget.child),
            ),
          ],
        ),
      ),
    );

    // Stroke + shadow live outside the clip so the shadow casts past the glass.
    // On a light page a dropped shadow reads as a hard grey lip under the
    // glass — the elevated-FAB look. Centred and halved there, it floats the
    // surface instead; dark themes keep exactly what was tuned.
    final lightPage = theme.background.computeLuminance() > 0.5;
    final framed = matched
        ? _matchedFrame(clipShape, isLight, blurred)
        : DecoratedBox(
      decoration: ShapeDecoration(
        shape: framedShape,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: cfg.of(kShadowOpacity) * (lightPage ? 0.5 : 1),
            ),
            blurRadius: cfg.of(kShadowBlur),
            offset: Offset(0, lightPage ? 0 : cfg.of(kShadowY)),
          ),
        ],
      ),
      child: blurred,
    );

    Widget sized = framed;
    if (widget.size != null) {
      sized = SizedBox(width: widget.size!.width, height: widget.size!.height, child: framed);
    }

    final scaled = AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: theme.motionMed,
      curve: Curves.easeOutBack,
      child: sized,
    );

    // The null check is exactly the right gate for keyboard focus too: the
    // composer's glass *field* passes no onTap and must not become a focus
    // stop, while the send/attach buttons pass one and should.
    if (widget.onTap == null) return scaled;
    return FocusableTap(
      onTap: _activateFromKeyboard,
      shape: _ringShape,
      radius: widget.radius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: scaled,
      ),
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
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.24),
            blurRadius: isLight ? 16 : 18,
            offset: Offset(0, isLight ? 0 : 5),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _SpecularRim(shape: shape, light: isLight),
        child: glass,
      ),
    );
  }

  FocusRingShape get _ringShape {
    switch (widget.shape) {
      case LiquidGlassShape.circle:
        return FocusRingShape.circle;
      case LiquidGlassShape.capsule:
        return FocusRingShape.capsule;
      case LiquidGlassShape.rounded:
        return FocusRingShape.rounded;
    }
  }

  /// Enter/Space activation. Pulses the same press state a tap would, so
  /// keyboard use gets the identical scale feedback instead of firing
  /// invisibly.
  void _activateFromKeyboard() {
    final theme = ThemeScope.of(context);
    setState(() => _pressed = true);
    Future<void>.delayed(theme.motionMed, () {
      if (mounted) setState(() => _pressed = false);
    });
    widget.onTap?.call();
  }
}

/// Strokes [shape]'s outline with a top-lit gradient — the specular rim of
/// matched glass. Paint-only and cheap: one path, one shader, no layers.
class _SpecularRim extends CustomPainter {
  const _SpecularRim({required this.shape, required this.light});

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
  bool shouldRepaint(_SpecularRim old) =>
      old.light != light || old.shape != shape;
}
