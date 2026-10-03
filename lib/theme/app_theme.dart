import 'dart:math' as math;

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
    Color? fill,
    Color? edge,
  }) {
    final base = _speakerTinted(
      messageBubbleDecoration(isMine: isMine, ephemeral: ephemeral),
      fill: fill,
      edge: edge,
    );
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

  /// Restates a theme's authored bubble in one speaker's colour.
  ///
  /// [fill] replaces the authored background outright — it is already that
  /// background with the speaker's colour washed through it
  /// (`SpeakerPalette.speakerWash`), computed by the caller so the blend has
  /// exactly one definition and this file does no colour maths.
  ///
  /// [edge] only ever lends its HUE. Alpha and width stay whatever the theme
  /// authored, because those are what make Risograph's border a 1.8px slab and
  /// Bio-Organic's a 0.8px whisper — a speaker colour that overrode them would
  /// be redrawing the theme, not tinting it. A theme that draws no border on
  /// an incoming bubble (Basic, Deep Ocean) does not grow one here either: the
  /// wash, the name and the avatar ring are the signal there.
  ///
  /// Both null — every caller outside a group room — returns the decoration
  /// untouched.
  BoxDecoration _speakerTinted(
    BoxDecoration base, {
    required Color? fill,
    required Color? edge,
  }) {
    if (fill == null && edge == null) return base;
    final authored = base.border;
    final BoxBorder? border;
    if (edge != null && authored is Border && authored.isUniform) {
      final side = authored.top;
      border = Border.all(
        color: Color.lerp(side.color, edge, 0.6)!
            .withValues(alpha: side.color.a),
        width: side.width,
      );
    } else {
      border = authored;
    }
    return base.copyWith(color: fill ?? base.color, border: border);
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

/// WCAG relative-luminance contrast between two colours, both assumed opaque.
///
/// Exposed to tests through [debugFormattingContrast] so the contrast floors
/// this file promises are asserted rather than asserted-about.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The smallest blend toward [pole] that clears [target] contrast against
/// [base], or null if [maxAlpha] never gets there.
double? _alphaFor(Color base, Color pole, double target, double maxAlpha) {
  if (_contrast(Color.lerp(base, pole, maxAlpha)!, base) < target) return null;
  var lo = 0.0;
  var hi = maxAlpha;
  // Seven halvings resolve alpha finer than an 8-bit channel can express, so
  // the answer is exact for every colour this can be handed.
  for (var i = 0; i < 7; i++) {
    final mid = (lo + hi) / 2;
    if (_contrast(Color.lerp(base, pole, mid)!, base) >= target) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);

/// Memo for [_nudgeAlong]. A transcript of thirty bubbles asks for the same
/// four colours thirty times; the bisection runs once per distinct request.
final _nudgeCache = <(Color, Color, double, double), Color>{};

/// Which way [base] has more room — the side that reaches [target] contrast
/// with the smaller blend.
///
/// Chosen by cost, NOT by a luminance threshold, and that is the whole point.
/// The obvious "lighten if dark, darken if light" rule breaks on the three
/// accents that sit just under L=0.5 — Forest `#9BBF7C` (0.457), Bio-Organic
/// `#1FBBD4` (0.406), Deep Ocean `#23BABB` (0.391). A threshold sends all
/// three toward white, where they have almost no headroom left: measured
/// 1.15:1 fill and 1.31:1 border, i.e. the same invisible chip this replaced,
/// on three themes instead of thirteen.
Color _cheaperPole(Color base, {required double target, required double maxAlpha}) {
  final down = _alphaFor(base, _black, target, maxAlpha);
  final up = _alphaFor(base, _white, target, maxAlpha);
  if (down != null && (up == null || down <= up)) return _black;
  if (up != null) return _white;
  return _contrast(Color.lerp(base, _black, maxAlpha)!, base) >=
          _contrast(Color.lerp(base, _white, maxAlpha)!, base)
      ? _black
      : _white;
}

/// [base] blended toward [pole] just far enough to clear [target] contrast,
/// capped at [maxAlpha].
///
/// Falls back to the opposite pole only when [pole] genuinely cannot get
/// there — an inconsistent edge beats an invisible one, but barely, so the
/// caller is expected to pick the pole once and reuse it (see [codeBorder]).
Color _nudgeAlong(
  Color base,
  Color pole, {
  required double target,
  required double maxAlpha,
}) {
  final key = (base, pole, target, maxAlpha);
  final hit = _nudgeCache[key];
  if (hit != null) return hit;

  final along = _alphaFor(base, pole, target, maxAlpha);
  final other = pole == _black ? _white : _black;
  final Color result;
  if (along != null) {
    result = Color.lerp(base, pole, along)!;
  } else {
    final back = _alphaFor(base, other, target, maxAlpha);
    if (back != null) {
      result = Color.lerp(base, other, back)!;
    } else {
      // Neither side clears the target inside the budget — spend all of it on
      // whichever gets furthest. Returning [base] unchanged would silently
      // reinstate an invisible chip, the bug this exists to prevent.
      final p = Color.lerp(base, pole, maxAlpha)!;
      final o = Color.lerp(base, other, maxAlpha)!;
      result = _contrast(p, base) >= _contrast(o, base) ? p : o;
    }
  }
  _nudgeCache[key] = result;
  return result;
}


/// Test seam for the contrast floors in [FormattingSurface].
@visibleForTesting
double debugFormattingContrast(Color a, Color b) => _contrast(a, b);

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

  /// The opaque colour a message bubble actually ends up painted in.
  ///
  /// Every derivation below measures against this rather than against
  /// [surfaceRaised] / [accent], because two themes fill their bubbles with
  /// `accent.withValues(alpha: 0.88)` and the ~12% of page background showing
  /// through is enough to move a contrast ratio across a floor.
  Color bubbleFill({required bool isMine, bool ephemeral = false}) {
    final d = messageBubbleDecoration(isMine: isMine, ephemeral: ephemeral);
    final c = d.color;
    if (c != null) return Color.alphaBlend(c, background);
    // No theme ships a gradient bubble today; this keeps the first one that
    // does out of the `isMine ? accent : surfaceRaised` fallback, which would
    // measure a colour the user never sees.
    final g = d.gradient;
    if (g != null && g.colors.isNotEmpty) {
      return Color.alphaBlend(
        Color.lerp(g.colors.first, g.colors.last, 0.5)!,
        background,
      );
    }
    return isMine ? accent : surfaceRaised;
  }

  /// The fill of an inline-code chip.
  ///
  /// Derived from [bubbleFill] rather than from ink, and by measured contrast
  /// rather than by a fixed alpha. The previous rule — `ink @ 8%` incoming,
  /// `accentInk @ 14%` outgoing — was white-on-dark on every dark theme, the
  /// one direction with no headroom: it composited to 1.27:1 and 1.21:1 on
  /// Midnight, so the only thing distinguishing a code run from prose was the
  /// monospace face. Note that the larger alpha produced the *worse* ratio,
  /// which is why nothing here is expressed as an alpha any more.
  ///
  /// Painted as a rounded, padded chip by `InlineCodeUnderlay`, NOT by
  /// `TextStyle.background`. The standing ban on placeholders in the message
  /// paragraph is intact and is exactly why the chip is an underlay: a
  /// WidgetSpan pill would add a second placeholder beside the stamp spacer,
  /// whose sizing is load-bearing.
  Color codeBackground({required bool isMine}) {
    final bubble = bubbleFill(isMine: isMine);
    return _nudgeAlong(bubble, _codePole(bubble, _codeInk(isMine)),
        target: 1.55, maxAlpha: 0.34);
  }

  /// The hairline around an inline-code chip.
  ///
  /// A fill alone cannot carry a chip on a dark theme: at Midnight's
  /// luminance the entire range between the bubble and pure black spans only
  /// 1.32:1, so the *edge* is what the eye actually reads. Held well clear of
  /// the fill so the two never collapse into one flat patch.
  ///
  /// Travels along the SAME pole as [codeBackground], not down whichever side
  /// is individually cheapest for its own target. Deciding per-target lets the
  /// two disagree — Vault Noir's red bubble took a darker fill and a *lighter*
  /// border, painting a pale outline around a dark well, which reads as two
  /// materials rather than one chip.
  Color codeBorder({required bool isMine}) {
    final bubble = bubbleFill(isMine: isMine);
    return _nudgeAlong(bubble, _codePole(bubble, _codeInk(isMine)),
        target: 2.60, maxAlpha: 0.62);
  }

  /// The ink a code run is set in: the bubble's own text colour.
  Color _codeInk(bool isMine) => isMine ? accentInk : ink;

  /// The one direction a code chip's fill and border both travel, fixed by
  /// the fill's target so the pair can never split.
  ///
  /// Away from the code's own ink whenever that direction can reach the
  /// target: a chip that moves toward its text colour eats the text's
  /// contrast, which is what made the chip unreadable on every outgoing
  /// bubble whose white text sat at about 5:1 — Daylight, Rose, Ivory,
  /// Risograph. Only when that side has no room (a near-black bubble cannot
  /// get 1.55:1 darker) does the cheaper pole decide, as before.
  Color _codePole(Color bubble, Color codeInk) {
    final away = codeInk.computeLuminance() > bubble.computeLuminance()
        ? _black
        : _white;
    if (_alphaFor(bubble, away, 1.55, 0.34) != null) return away;
    return _cheaperPole(bubble, target: 1.55, maxAlpha: 0.34);
  }

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

  /// The ink of the spoiler's dust motes.
  ///
  /// The text's own ink, so the field reads as the hidden words ground to
  /// powder — and so it clears the bubble by at least what the words do.
  /// There is no plate token any more: the veil used to paint an opaque
  /// rectangle in [bubbleFill] under its dust, which was only invisible when
  /// that colour matched the bubble EXACTLY, and it could not on a translucent
  /// fill, a speaker-tinted group bubble or a photograph. The veil now hides
  /// the glyphs themselves and paints nothing over the bubble at all (see
  /// `spoiler_veil.dart`), so the only colour it needs is this one.
  ///
  /// [onMedia] is for captions, where the dust sits on a photograph instead
  /// of a bubble: no palette colour is the ground there, so a fixed neutral.
  Color spoilerDust({required bool isMine, bool onMedia = false}) =>
      onMedia ? const Color(0xFFFFFFFF) : (isMine ? accentInk : ink);
}
