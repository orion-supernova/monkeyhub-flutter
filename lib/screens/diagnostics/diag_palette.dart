import 'package:flutter/material.dart';

import '../../diagnostics/diag_event.dart';
import '../../theme/app_theme.dart';

/// Colours for the diagnostics timeline.
///
/// Severity comes from the active [AppTheme], because "this is bad" should look
/// the way it looks everywhere else in the app.
///
/// Category does NOT, and that is the one deliberate deviation from the house
/// rule of theming everything. A categorical scale needs eleven values that stay
/// distinguishable from each other; `AppTheme` offers `accent`, `danger` and
/// `success`, so deriving from it would collapse eleven categories into three
/// and destroy the thing colour is doing here — letting you see the SHAPE of a
/// log while scrolling, before reading a single word. These hues are held at a
/// middle lightness so they carry on both the light (riso) themes and the dark
/// ones, which is why none of them is a pure primary.
class DiagPalette {
  const DiagPalette._();

  static const Map<DiagCat, Color> _cats = {
    DiagCat.api: Color(0xFF4A90D9), // blue — the backbone of most sessions
    DiagCat.subscription: Color(0xFF3FA9A0), // teal, adjacent to api on purpose
    DiagCat.log: Color(0xFF8A8A96), // grey — present but never the story
    DiagCat.error: Color(0xFFD1495B), // red
    DiagCat.lifecycle: Color(0xFF9B6FD1), // purple
    DiagCat.layout: Color(0xFFE08A3C), // orange — loud, and usually the answer
    DiagCat.frame: Color(0xFFC75FA8), // magenta
    DiagCat.connection: Color(0xFF4CA666), // green
    DiagCat.network: Color(0xFF3FA0C0), // cyan
    DiagCat.nav: Color(0xFF6C7BD1), // indigo
    DiagCat.device: Color(0xFFB08948), // amber
  };

  static Color cat(DiagCat c) => _cats[c] ?? const Color(0xFF8A8A96);

  static Color severity(AppTheme theme, DiagSev sev) => switch (sev) {
    DiagSev.error => theme.danger,
    DiagSev.warn => theme.danger,
    DiagSev.info => theme.accent,
    DiagSev.debug => theme.inkSoft,
    DiagSev.trace => theme.inkMuted,
  };

  /// Whether a row should shout. Only warn and error do — if everything is
  /// emphasised then nothing is, and a log is mostly uneventful by design.
  static bool isLoud(DiagSev sev) => sev.index >= DiagSev.warn.index;
}
