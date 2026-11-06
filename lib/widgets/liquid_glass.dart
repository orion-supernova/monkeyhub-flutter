import 'dart:ui';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../data/glass_config.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../ui/foundation/ui_kit.dart';
import '../ui/kits/shader/shader_glass_surface.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show LiquidOval, LiquidRoundedRectangle, LiquidRoundedSuperellipse, LiquidShape;
import '../ui/kits/material/material_kit_theme.dart';
import 'glass_reveal.dart';
import 'spring_press.dart';
import 'sunlit_surface.dart' show sunlitHairline;

enum LiquidGlassShape { circle, capsule, rounded }

/// What a piece of glass sits over, which decides how it is lit.
///
/// * [app] — the app's own pages. Follows the glass engine: iOS Liquid Glass
///   wears the matched recipe, as does untuned Frosted chrome. Custom app
///   tuning applies when using the Flutter tab bar.
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

  /// The same glass with nothing behind it — for chrome that fades or flies,
  /// where a `BackdropFilter` is never drawn. Matched to what [fill] looks
  /// like over the black of a viewer, so the two never read as two buttons.
  static const stillFill = Color(0xF2262628);

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
  static const shadow = BoxShadow(color: Color(0x40000000), blurRadius: 14);
}

/// The opaque fill of a control drawn without glass: a step off the page —
/// an ink wash on light palettes, a white one on dark. The chrome disc of a
/// still button and every [UiKit.lite] surface wear it, so a plate on a page,
/// a sheet and a card is the same plate.
Color plateFill(AppTheme theme) => theme.isLight
    ? Color.alphaBlend(theme.ink.withValues(alpha: 0.06), theme.surface)
    : Color.alphaBlend(Colors.white.withValues(alpha: 0.12), theme.surface);

/// The hairline round a [plateFill] surface, so it keeps an edge on a page of
/// the same colour.
Color plateEdge(AppTheme theme) => theme.isLight
    ? theme.ink.withValues(alpha: 0.08)
    : Colors.white.withValues(alpha: 0.08);

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
    this.neutral = false,
    this.still = false,
    this.pressScale = PressSpec.bloom,
  });

  /// Scale while held. Glass controls bloom (grow); a large glass surface
  /// that is tappable should pass a value at or below 1.
  final double pressScale;

  /// No backdrop blur — [GlassTone.media] only — for glass that fades or
  /// moves. Same shape, rim and light; a solid fill in place of the blur.
  /// A [GlassStill] above turns it on for a whole faded subtree.
  final bool still;

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

  /// Neutral, top-lit glass for explicitly configured chrome previews and bars. Keeps its dial positions
  /// while using a white specular edge instead of the theme's accent rim.
  /// Ignored by [GlassTone.media].
  final bool neutral;

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
    // The Material kit draws app chrome as a tonal surface with a ripple. Over
    // photos (media tone) it keeps the blur-free plate below, as lite does.
    if (tone == GlassTone.app && UiKit.of(context) == UiKit.material) {
      return _sized(_tonal(context));
    }
    Widget surface(bool pressed) => _sized(_material(context, pressed));
    if (onTap == null) return surface(false);
    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: pressScale,
      semanticLabel: semanticLabel,
      focusShape: _ringShape,
      focusRadius: radius,
      builder: (context, pressed) => surface(pressed),
    );
  }

  /// The [UiKit.material] surface: a Material 3 tonal container in the same
  /// shape, no blur, a hairline of elevation, and a ripple when tappable.
  Widget _tonal(BuildContext context) {
    final scheme = MaterialKitTheme.of(ThemeScope.of(context)).colorScheme;
    final fill = tint ??
        (tinted ? scheme.secondaryContainer : scheme.surfaceContainerHigh);
    final tap = onTap;
    Widget body = Material(
      color: fill,
      elevation: shadow ? 1 : 0,
      shadowColor: scheme.shadow,
      surfaceTintColor: tint == null ? scheme.surfaceTint : Colors.transparent,
      shape: _border(),
      clipBehavior: Clip.antiAlias,
      child: tap == null
          ? _content(context)
          : InkWell(
              onTap: tap,
              customBorder: _border(),
              child: _content(context),
            ),
    );
    if (tap != null) {
      body = Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: body,
      );
    }
    return MaterialKitScope(child: body);
  }

  Widget _sized(Widget glass) => size == null
      ? glass
      : SizedBox(width: size!.width, height: size!.height, child: glass);

  /// The engine-aware material: which recipe the glass wears.
  Widget _material(BuildContext context, bool pressed) {
    final kit = UiKit.of(context);
    if (kit == UiKit.shader && tone == GlassTone.app) {
      return _shader(context, pressed);
    }
    if (!kit.blurs) {
      return tone == GlassTone.media
          ? _media(context, pressed, plate: true)
          : _plate(context, pressed);
    }
    if (tone == GlassTone.media) return _media(context, pressed);
    final cfg = config;
    if (cfg != null) return _app(context, cfg, pressed);
    // Untuned app chrome keeps its matched appearance independently of the
    // tab bar's engine or tuning. Resolve inside the listener so an existing
    // button also reacts when the engine or the app's dials change.
    // Only surfaces following the app-wide tuning subscribe. The bottom bar is
    // handed its config by a parent that already rebuilds on settings changes,
    // so making it listen too would just double the rebuilds.
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        final app = SettingsStore.instance.glass.app;
        // Resolved in here, not above: with no scope over this glass the kit
        // comes straight from the store, and this is the part that listens.
        final liquid = UiKit.of(context) == UiKit.liquid;
        final recipe = liquid || app.isUntouched
            ? kNativeMatchGlass
            : resolveAppGlass(app);
        return _app(
          context,
          recipe,
          pressed,
          appChrome: !liquid && !app.isUntouched,
        );
      },
    );
  }

  /// The [UiKit.shader] surface: the same shape and content, drawn by the
  /// shader engine with the user's shader dials. Listens to the store so the
  /// dials repaint live.
  Widget _shader(BuildContext context, bool pressed) {
    final theme = ThemeScope.of(context);
    final isLight = theme.background.computeLuminance() > 0.5;
    final LiquidShape engineShape = switch (shape) {
      LiquidGlassShape.circle => const LiquidOval(),
      LiquidGlassShape.capsule => const LiquidRoundedRectangle(borderRadius: 999),
      LiquidGlassShape.rounded => LiquidRoundedSuperellipse(borderRadius: radius),
    };
    final wash = tint ??
        (tinted ? theme.accent.withValues(alpha: 0.38) : null);
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) => ShaderGlassSurface(
        shape: engineShape,
        isLight: isLight,
        color: wash,
        pressed: pressed,
        shadow: shadow,
        content: _content(context),
      ),
    );
  }

  /// The content laid over the glass. A Stack sizes to its non-positioned
  /// children, so THIS decides how wide the glass is: centred only when
  /// [size] pins the box (there is slack to centre within), otherwise the
  /// glass shrink-wraps its content — a capsule around two words never
  /// paints full width.
  ///
  /// Faded inside the blur when a [GlassReveal] is bringing this glass in or
  /// out: the content may fade, the glass itself never does (see there).
  Widget _content(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: size == null ? child : Center(child: child),
    );
    // Always wrapped, even at 1 (where Opacity paints straight through, no
    // layer). Adding the wrapper as a reveal starts and dropping it as it
    // lands changes the tree's shape, which remounts everything on the glass:
    // a menu's rows lost their state and replayed their entrance from blank,
    // one empty frame of glass mid-open.
    return Opacity(opacity: GlassContentFade.of(context), child: content);
  }

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
      lr * i + s,
      lg * i,
      lb * i,
      0,
      0,
      lr * i,
      lg * i + s,
      lb * i,
      0,
      0,
      lr * i,
      lg * i,
      lb * i + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  /// Glass over a photograph, the iOS 26 Photos way: clear dark glass with
  /// light pooling at the top and a specular edge brightest along the top —
  /// not a filled disc with a dropped shadow and an even outline, which is
  /// Material elevation and read as Android over a photo. A [tint] makes it a
  /// solid, lit control.
  ///
  /// [plate] is the lite kit: the still fill, and no shadow.
  Widget _media(BuildContext context, bool pressed, {bool plate = false}) {
    final t = tint;
    final shape = _border();
    // Shadows the field: still here or still because the subtree is fading.
    final still = plate || this.still || GlassStill.of(context);
    final Color fill;
    if (t != null) {
      fill = t;
    } else if (still) {
      fill = pressed
          ? Color.lerp(MediaGlass.stillFill, const Color(0xFFFFFFFF), 0.08)!
          : MediaGlass.stillFill;
    } else {
      fill = pressed ? MediaGlass.fillPressed : MediaGlass.fill;
    }
    final body = Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: fill)),
        if (t == null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    // Transparent WHITE: fading to transparent black lays a
                    // grey band across the glass.
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
            ),
          ),
        _content(context),
      ],
    );
    final clipped = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: still || t != null
          ? body
          : BackdropFilter.grouped(
              filter: ImageFilter.blur(
                sigmaX: MediaGlass.blurSigma,
                sigmaY: MediaGlass.blurSigma,
              ),
              child: body,
            ),
    );
    // Rim and shadow sit outside the clip so the shadow casts past the glass
    // instead of being cut off at its own edge. Centred, never dropped.
    return GlassShadow(
      shape: shape,
      shadows: shadow && !plate ? const [MediaGlass.shadow] : null,
      child: CustomPaint(
        foregroundPainter: SpecularRim(
          shape: shape,
          light: false,
          opacity: t == null ? 1 : 0.7,
        ),
        child: clipped,
      ),
    );
  }

  /// The [UiKit.lite] surface: the same shape as the glass, drawn as an
  /// opaque plate one step off the page, with a hairline edge. No backdrop
  /// blur and no shadow, which are the two things a low-end GPU pays for.
  Widget _plate(BuildContext context, bool pressed) {
    final theme = ThemeScope.of(context);
    final t = tint;
    final fill = t ??
        (tinted
            ? Color.alphaBlend(theme.accent.withValues(alpha: 0.22), theme.surface)
            : plateFill(theme));
    final shape = _border(
      side: BorderSide(color: plateEdge(theme), width: t == null ? 0.5 : 0),
    );
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: ShapeDecoration(shape: shape),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: _border()),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: fill)),
            if (pressed)
              Positioned.fill(
                child: ColoredBox(
                  color: (theme.isLight ? theme.ink : Colors.white)
                      .withValues(alpha: 0.07),
                ),
              ),
            _content(context),
          ],
        ),
      ),
    );
  }

  /// Glass on the app's own pages, in either engine's recipe.
  Widget _app(
    BuildContext context,
    GlassConfig cfg,
    bool pressed, {
    bool appChrome = false,
  }) {
    final theme = ThemeScope.of(context);
    // The theme's brightness, not the phone's: Midnight on a phone in light
    // mode is a dark page, and wanted dark frost.
    final isLight = theme.background.computeLuminance() > 0.5;
    final adjustable = neutral || appChrome;
    final matched = adjustable || identical(cfg, kNativeMatchGlass);

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

    final Color base =
        tint ??
        (matched
            // Matched glass is a neutral, nearly clear tint rather than a
            // wash of the theme's surface — iOS glass carries the colour of
            // what is behind it, not of the app.
            ? Colors.white.withValues(
                alpha: adjustable
                    ? ((isLight ? 0.72 : 0.07) * frost / 0.55).clamp(0.0, 1.0)
                    : (isLight ? 0.72 : 0.07),
              )
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
              Colors.white.withValues(
                alpha:
                    (isLight ? 0.25 : 0.10) * (adjustable ? frost / 0.55 : 1),
              ),
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
            _content(context),
          ],
        ),
      ),
    );

    if (matched) {
      return _matchedFrame(
        clipShape,
        isLight,
        blurred,
        config: adjustable ? cfg : null,
        edge: isLight ? sunlitHairline(theme) : null,
      );
    }

    // Stroke + shadow live outside the clip so the shadow casts past the glass.
    // On a light page a dropped shadow reads as a hard grey lip under the
    // glass — the elevated-FAB look. Centred and halved there, it floats the
    // surface instead; dark themes keep exactly what was tuned.
    // The accent rim is a FOREGROUND decoration: painted under the glass, the
    // backdrop blur smeared it along with the shadow.
    return GlassShadow(
      shape: clipShape,
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
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(shape: framedShape),
        child: blurred,
      ),
    );
  }

  /// The edge and shadow of matched (iOS Liquid Glass) glass: a specular rim
  /// brightest along the top, fading down the sides and catching a little
  /// light again at the bottom — the lit edge that makes iOS 26 glass read as
  /// a material over a flat page, where there is nothing behind it to bend.
  Widget _matchedFrame(
    OutlinedBorder shape,
    bool isLight,
    Widget glass, {
    GlassConfig? config,
    Color? edge,
  }) {
    return GlassShadow(
      shape: shape,
      shadows: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: config == null
                        ? (isLight ? 0.08 : 0.24)
                        : (config.of(kShadowOpacity) * (isLight ? 2 / 3 : 2))
                              .clamp(0.0, 1.0),
                  ),
                  blurRadius: config == null
                      ? (isLight ? 16 : 18)
                      : config.of(kShadowBlur) * (isLight ? 0.8 : 0.9),
                  offset: Offset(
                    0,
                    isLight
                        ? (config == null ? 0 : config.of(kShadowY) - 4)
                        : (config?.of(kShadowY) ?? 4) * 1.25,
                  ),
                ),
                // A white pill on a near-white page needs a contact shadow
                // as well as the ambient one, or it has no edge.
                if (isLight && edge != null)
                  BoxShadow(
                    color: edge.withValues(alpha: edge.a * 1.6),
                    blurRadius: 2.5,
                    offset: const Offset(0, 1),
                  ),
              ]
            : null,
      child: CustomPaint(
        foregroundPainter: SpecularRim(
          shape: shape,
          light: isLight,
          opacity: config == null ? 1 : config.of(kRimOpacity) / 0.22,
          width: config?.of(kRimWidth) ?? 1,
          edge: edge,
        ),
        child: glass,
      ),
    );
  }
}

/// Casts [shadows] around [child] in the shape of [shape], for glass.
///
/// Never put a glass surface's shadow in a `BoxDecoration`/`ShapeDecoration`
/// under it: a decoration paints before its child, so the child's backdrop
/// blur samples the shadow and smears it inward as a grey ring just inside
/// the edge — invisible on a dark page, a dirty bevel on a light one. This
/// paints the shadow AFTER the child, clipped to the outside of the shape, so
/// the blur never sees it and none of it shows through translucent glass.
class GlassShadow extends StatelessWidget {
  const GlassShadow({
    super.key,
    required this.shape,
    required this.shadows,
    required this.child,
  });

  final ShapeBorder shape;
  final List<BoxShadow>? shadows;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = shadows;
    if (s == null || s.isEmpty) return child;
    return CustomPaint(
      foregroundPainter: _OuterShadowPainter(shape: shape, shadows: s),
      child: child,
    );
  }
}

class _OuterShadowPainter extends CustomPainter {
  const _OuterShadowPainter({required this.shape, required this.shadows});

  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var reach = 0.0;
    for (final s in shadows) {
      final r = s.blurSigma * 3 + s.spreadRadius + s.offset.distance;
      if (r > reach) reach = r;
    }
    // Half a pixel inside the edge: the glass's own anti-aliased edge is
    // partly transparent, and stopping the shadow exactly at it leaves a
    // pale seam between glass and shadow.
    final hole = shape.getOuterPath(rect.deflate(0.5));
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(reach + 1)),
        hole,
      ),
    );
    for (final s in shadows) {
      canvas.drawPath(
        shape.getOuterPath(rect.shift(s.offset).inflate(s.spreadRadius)),
        s.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.shape != shape || !listEquals(old.shadows, shadows);
}

/// Strokes [shape]'s outline with a top-lit gradient — the specular rim of
/// matched glass. Paint-only and cheap: one path, one shader, no layers.
///
/// Public because the chrome disc (`glass_buttons.dart`) wears the same lit
/// edge: the 40pt × on a sheet and the one on a page are one button, and the
/// rim is most of what makes them read as one.
class SpecularRim extends CustomPainter {
  const SpecularRim({
    required this.shape,
    required this.light,
    this.opacity = 1,
    this.width = 1,
    this.edge,
  });

  final OutlinedBorder shape;
  final bool light;
  final double opacity;
  final double width;

  /// Light only: the colour the rim settles to below its lit top. Without it
  /// the light rim is white all the way round, which on a white page is no
  /// rim at all; with it (a whisper of the theme's ink) the edge still reads.
  final Color? edge;

  @override
  void paint(Canvas canvas, Size size) {
    if (width <= 0 || opacity <= 0) return;
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect.deflate(width / 2));
    final e = edge;
    if (light && e != null) {
      // Two strokes, never one gradient from white to the ink edge: a
      // gradient between an opaque white and a nearly transparent dark
      // interpolates through a half-opaque mid-grey, which drew a grey arc
      // across the shoulders of every light disc, right where it should be
      // brightest. The even hairline first, then the light fading out to
      // transparent WHITE above it.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = e.withValues(alpha: e.a * opacity),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.3],
          ).scale(opacity).createShader(rect),
      );
      return;
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
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
      ).scale(opacity).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SpecularRim old) =>
      old.light != light ||
      old.shape != shape ||
      old.opacity != opacity ||
      old.width != width ||
      old.edge != edge;
}
