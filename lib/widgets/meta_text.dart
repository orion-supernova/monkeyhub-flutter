import 'package:flutter/painting.dart';

import '../theme/app_theme.dart';

/// Small supporting text — times, counts, "2 days ago" — in the theme's body
/// face at 13pt with tabular figures.
///
/// The replacement for `theme.monoTiny` on Feed and Games surfaces. That slot
/// is a widely tracked monospace on most themes, which made every timestamp
/// and counter read as terminal output next to iOS-style rows.
TextStyle metaText(AppTheme theme, {Color? color}) => theme.bodySoft.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
      color: color ?? theme.inkMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// A short action or section label in sentence case — the replacement for
/// `theme.label`, whose tracked capitals were the old style's voice.
TextStyle labelText(AppTheme theme, {Color? color}) => theme.body.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: color ?? theme.ink,
    );
