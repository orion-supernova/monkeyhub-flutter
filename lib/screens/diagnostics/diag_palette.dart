import 'package:flutter/material.dart';

import '../../diagnostics/diag_event.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';

/// A category's name as the screen says it — "Live updates", not
/// `subscription`.
///
/// Every chip, filter row, event row and toast goes through this; they used
/// to print the enum's own name, which is a developer's word in a developer's
/// case in every language. The exported log keeps the raw names (see
/// diag_export): it is read by people grepping, not by people tapping.
///
/// An exhaustive switch, so a new category fails the build until it has a
/// name rather than shipping as a blank chip.
String diagCategoryLabel(AppLocalizations l10n, DiagCat c) => switch (c) {
  DiagCat.api => l10n.diagCatApi,
  DiagCat.connection => l10n.diagCatConnection,
  DiagCat.device => l10n.diagCatDevice,
  DiagCat.error => l10n.diagCatError,
  DiagCat.frame => l10n.diagCatFrame,
  DiagCat.layout => l10n.diagCatLayout,
  DiagCat.lifecycle => l10n.diagCatLifecycle,
  DiagCat.log => l10n.diagCatLog,
  DiagCat.nav => l10n.diagCatNav,
  DiagCat.network => l10n.diagCatNetwork,
  DiagCat.subscription => l10n.diagCatSubscription,
};

/// A severity's name — `warn` reads as a level in a log and as a typo in a
/// sentence, so the screen says "Warning".
String diagSeverityLabel(AppLocalizations l10n, DiagSev s) => switch (s) {
  DiagSev.trace => l10n.diagSevTrace,
  DiagSev.debug => l10n.diagSevDebug,
  DiagSev.info => l10n.diagSevInfo,
  DiagSev.warn => l10n.diagSevWarning,
  DiagSev.error => l10n.diagSevError,
};

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
