import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'bubble_shape.dart';

export 'bubble_shape.dart' show BubbleStyle, BubbleShape;

enum ThemeMood { vault, riso, aurora }

abstract class AppTheme {
  String get id;
  String get name;
  String get tagline;
  ThemeMood get mood;

  // Palette swatches (for the theme chip)
  List<Color> get swatch;

  // Surfaces
  Color get background;
  Color get surface;
  Color get surfaceRaised;
  Color get surfaceSunken;
  Color get divider;

  // Ink
  Color get ink;
  Color get inkSoft;
  Color get inkMuted;

  // Accents
  Color get accent;
  Color get accentInk;
  Color get accentSoft;
  Color get danger;
  Color get success;

  // Typography
  TextStyle get displayHero;
  TextStyle get displayLarge;
  TextStyle get displayMedium;
  TextStyle get displaySmall;
  TextStyle get body;
  TextStyle get bodyEmph;
  TextStyle get bodySoft;
  TextStyle get caption;
  TextStyle get mono;
  TextStyle get monoLarge;
  TextStyle get monoTiny;
  TextStyle get label;

  // Geometry
  double get radiusSm;
  double get radiusMd;
  double get radiusLg;
  double get radiusXl;

  // Motion
  Duration get motionFast;
  Duration get motionMed;
  Duration get motionSlow;
  Curve get motionCurve;
  Curve get motionEntrance;

  // Decorations
  BoxDecoration roomCardDecoration({required bool ephemeral, required bool active});
  BoxDecoration messageBubbleDecoration({required bool isMine, required bool ephemeral});
  BoxDecoration sheetDecoration();
  BoxDecoration chipDecoration({bool filled = false});
  BoxDecoration inputDecoration();

  // Composable widgets
  Widget backgroundLayer(BuildContext context);
  Widget ephemeralSignature({required double progress}); // 0 = fresh, 1 = expired
  Widget visibilityIcon({required bool isPublic, double size = 14});
  Widget hourglassIcon({double size = 16, Color? color});
  Widget brandMark({double size = 28});

  /// Same identity as [brandMark] but optimised for app-icon rendering: the
  /// drawing must fill the [size]×[size] square edge-to-edge with opaque
  /// pixels (no internal `borderRadius`, no shadow that depends on
  /// surrounding space). Used by `BrandIconCanvas` for the launcher PNG and
  /// the picker tile so both surfaces show identical content; the platform
  /// (iOS squircle mask, Android adaptive icon mask) applies the rounding.
  ///
  /// Default: forward to [brandMark]. Themes whose [brandMark] inset their
  /// content (e.g. a rounded button inside a square) should override this to
  /// return an edge-to-edge variant.
  Widget iconMark({double size = 28}) => brandMark(size: size);

  // Avatar gradient seeds (theme controls palette of generated avatars)
  List<Color> avatarGradient(int seed);
}

/// The geometry layer over [AppTheme.messageBubbleDecoration].
///
/// An extension rather than members on [AppTheme] because every theme
/// *implements* the interface rather than extending it — so shared behaviour
/// added to the class would land on all nine of them as an unimplemented
/// member. This way no theme file changes at all: they keep authoring colour,
/// border and shadow as a flat `BoxDecoration`, and this owns shape alone.
extension BubbleGeometry on AppTheme {
  /// The decoration a transcript should actually paint: whatever the theme
  /// authored, re-shaped for the chosen [BubbleStyle] and for this row's
  /// position in its run.
  ///
  /// A `BoxDecoration` cannot express a tail, so this returns a
  /// [ShapeDecoration] wrapping a [BubbleShape].
  Decoration bubbleDecoration({
    required bool isMine,
    required bool ephemeral,
    required BubbleStyle style,
    bool firstInRun = true,
    bool lastInRun = true,
  }) {
    final base = messageBubbleDecoration(isMine: isMine, ephemeral: ephemeral);
    return ShapeDecoration(
      color: base.color,
      gradient: base.gradient,
      image: base.image,
      // `ShapeDecoration` re-traces the outline per shadow, honouring both
      // `offset` and `spreadRadius`, so Risograph's hard offset shadow and
      // Bio-Organic's negative-spread glow both survive the move.
      shadows: base.boxShadow,
      shape: bubbleShapeFrom(
        base,
        style: style,
        isMine: isMine,
        firstInRun: firstInRun,
        lastInRun: lastInRun,
      ),
    );
  }

  /// The same outline [bubbleDecoration] paints, for callers that need the
  /// path itself — the scroll-to-message halo, which has to hug the tail
  /// rather than cut across it.
  BubbleShape bubbleShape({
    required bool isMine,
    required bool ephemeral,
    required BubbleStyle style,
    bool firstInRun = true,
    bool lastInRun = true,
  }) =>
      bubbleShapeFrom(
        messageBubbleDecoration(isMine: isMine, ephemeral: ephemeral),
        style: style,
        isMine: isMine,
        firstInRun: firstInRun,
        lastInRun: lastInRun,
      );

  /// Width of the gutter [bubbleDecoration] reserves on the sender's side for
  /// the tail. Callers that align siblings (timestamps, reactions) to the
  /// bubble *body* rather than its tail tip need it; 0 for tail-less styles.
  double bubbleTailGutter(BubbleStyle style) => bubbleShapeFrom(
        messageBubbleDecoration(isMine: true, ephemeral: false),
        style: style,
        isMine: true,
      ).tailWidth;
}

/// The surface a tap-to-explain tooltip paints itself on.
///
/// Derived rather than authored per theme, for the same reason [BubbleGeometry]
/// is an extension: nine themes would each have to implement it. It has to sit
/// above whatever it covers, so it takes the raised surface and a hard edge —
/// a translucent chip would let the room card read straight through the
/// sentence.
extension TooltipSurface on AppTheme {
  BoxDecoration tooltipDecoration() => BoxDecoration(
        color: surfaceRaised,
        borderRadius: BorderRadius.circular(radiusSm),
        border: Border.all(color: divider),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: 0.55),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

/// The inks and surfaces message-body formatting draws with — inline code,
/// link entities, the spoiler veil.
///
/// Derived rather than authored per theme, for the reason [BubbleGeometry]
/// spells out: every theme *implements* [AppTheme], so a new abstract member
/// breaks all of them at once, where a derivation breaks none and can still
/// be promoted to a real member later if some theme earns an override.
///
/// Everything here takes `isMine`, because a bubble's ground truth is its
/// fill: an outgoing bubble is FILLED with [accent], so any accent-coloured
/// treatment inside one is invisible — the exact trap the link ink below was
/// originally written to dodge.
extension FormattingSurface on AppTheme {
  /// Ink for tappable link text — both bare URLs and link entities.
  ///
  /// Lifted verbatim from `_LinkAwareBubble`, history included: on the
  /// viewer's own (accent-filled) bubble only [accentInk] is guaranteed to
  /// read; on everyone else's, a dark accent is used as-is and a light one
  /// falls back to [ink] so the link never washes out against the surface.
  Color linkInk({required bool isMine}) => isMine
      ? accentInk
      : (accent.computeLuminance() < 0.2 ? accent : ink);

  /// The wash behind an inline-code run — a chip painted by
  /// `TextStyle.background` (never a WidgetSpan; see `_LinkAwareBubble`'s
  /// self-mention note for why placeholders are banned in the paragraph).
  /// Ink-derived on both fills so it reads on every one of the themes' bubble
  /// colours without any theme having to say so.
  Color codeBackground({required bool isMine}) => isMine
      ? accentInk.withValues(alpha: 0.14)
      : ink.withValues(alpha: 0.08);

  /// The monospace face for inline code, over whatever [base] the bubble was
  /// already using.
  ///
  /// NOT [mono]: several themes deliberately keep that slot on the
  /// proportional system face with tabular figures (see `BasicTheme`), and
  /// code that isn't monospaced is just text with a background. JetBrains
  /// Mono ships in the bundle (`assets/google_fonts/`, runtime fetching off),
  /// subset to Latin — CJK code falls back to the platform face, which is
  /// accepted. Slightly under the body size and with the body's height kept,
  /// so a code word doesn't breathe the line box it sits in.
  TextStyle codeStyle(TextStyle base) => GoogleFonts.jetBrainsMono(
        textStyle: base,
        fontSize: (base.fontSize ?? 15) * 0.92,
        height: base.height,
        letterSpacing: 0,
      );

  /// Base colour of the spoiler veil over this bubble. The veil paints it
  /// near-opaque (the opacity IS the privacy guarantee — dust is garnish) and
  /// derives its particle alphas from the same colour, so the whole effect
  /// stays one ink. The text's own ink, deliberately: a veil in the ink the
  /// hidden words would have used reads as "text, redacted" on every theme,
  /// which no bubble-coloured bar manages.
  Color spoilerCover({required bool isMine}) => isMine ? accentInk : ink;
}
