import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The violet of vanish mode, derived from the theme.
///
/// No theme has a violet, so the accent's hue is rotated to violet while its
/// saturation and lightness are kept (clamped so it reads on any surface): it
/// follows the theme without a hard-coded hex. ONE helper for everything that
/// is "vanish coloured" – the swipe fork's left option, the chat tint, sent
/// bubbles, the countdown ring, the system line – so they can never drift.
class VanishPalette {
  VanishPalette(AppTheme theme)
      : vanish = violetOf(theme.accent),
        _theme = theme;

  final AppTheme _theme;

  /// The violet itself.
  final Color vanish;

  /// A readable glyph colour on top of [vanish] (and any other fill).
  static Color onColor(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark
          ? const Color(0xFFFFFFFF)
          : const Color(0xFF000000);

  /// Accent hue rotated to violet, saturation and lightness kept in a band
  /// that reads on dark and light surfaces alike.
  static Color violetOf(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return HSLColor.fromAHSL(
      1,
      258,
      hsl.saturation.clamp(0.45, 0.85).toDouble(),
      hsl.lightness.clamp(0.5, 0.66).toDouble(),
    ).toColor();
  }

  /// The fill of a sent bubble while vanish is on: [vanish], nudged in
  /// lightness until the theme's own outgoing ink ([AppTheme.accentInk], which
  /// the bubble's text and stamp use) reads on it.
  Color get bubbleFill {
    final ink = _theme.accentInk;
    // Every vanishing sent bubble asks for this on every build; the answer
    // depends only on these two colours, so the nudge loop (up to 12 HSL and
    // luminance rounds) runs once per theme instead of once per bubble.
    final key = (vanish, ink);
    final hit = _fillCache[key];
    if (hit != null) return hit;
    final fill = _computeBubbleFill(ink);
    if (_fillCache.length > 32) _fillCache.clear();
    return _fillCache[key] = fill;
  }

  static final Map<(Color, Color), Color> _fillCache = {};

  Color _computeBubbleFill(Color ink) {
    var hsl = HSLColor.fromColor(vanish);
    // Away from the ink: a light ink wants a darker fill and vice versa.
    final darker = ink.computeLuminance() > 0.5;
    for (var i = 0; i < 12 && _contrast(hsl.toColor(), ink) < 4.0; i++) {
      final l = (hsl.lightness + (darker ? -0.04 : 0.04)).clamp(0.12, 0.9);
      hsl = hsl.withLightness(l.toDouble());
    }
    return hsl.toColor();
  }

  /// The chat background wash: [vanish] at a whisper, stronger on light themes
  /// where the same alpha reads weaker.
  Color get tint {
    final dark = ThemeData.estimateBrightnessForColor(_theme.background) ==
        Brightness.dark;
    return vanish.withValues(alpha: dark ? 0.10 : 0.07);
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}
