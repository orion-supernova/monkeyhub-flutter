import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/theme_preference.dart';
import '../../../theme/theme_scope.dart';

/// The Material 3 look of the Android kit, derived from the current
/// [AppTheme] so the nine-plus themes still read as themselves: the seed is the
/// theme's accent, the surfaces are the theme's own, the fonts are kept.
///
/// Built once per [AppTheme] object and cached (an [Expando], so a theme that
/// is dropped takes its ThemeData with it): a skin that wraps itself in
/// [MaterialKitScope] costs one inherited lookup per build, never a ThemeData.
///
/// The app-wide theme turns ink off ([NoSplash]); the Material kit is the one
/// place ripples are allowed (approved 2026-11-07), so [splashFactory] here is
/// a real [InkRipple]. Pure Dart, no shader: it also renders in tests.
abstract final class MaterialKitTheme {
  static final Expando<ThemeData> _cache = Expando<ThemeData>('materialKit');

  /// The Material 3 [ThemeData] for [theme].
  static ThemeData of(AppTheme theme) =>
      _cache[theme] ??= _build(theme);

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  static ThemeData _build(AppTheme t) {
    final brightness = t.brightness;
    final seeded = ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: brightness,
    );
    // Tonal surface ramp from the theme's own surface towards its ink, so a
    // Midnight page stays near-black and a Daylight page stays near-white
    // while the containers still step up in tone.
    Color step(double v) => _mix(t.surface, t.ink, v);
    final scheme = seeded.copyWith(
      primary: t.accent,
      onPrimary: t.accentInk,
      primaryContainer: _mix(t.surface, t.accent, t.isLight ? 0.22 : 0.34),
      onPrimaryContainer: t.isLight ? t.ink : Colors.white,
      secondaryContainer: _mix(t.surface, t.accent, t.isLight ? 0.16 : 0.26),
      onSecondaryContainer: t.isLight ? t.ink : Colors.white,
      error: t.danger,
      onError: Colors.white,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.inkSoft,
      surfaceDim: t.background,
      surfaceBright: step(0.10),
      surfaceContainerLowest: t.background,
      surfaceContainerLow: step(0.03),
      surfaceContainer: step(0.06),
      surfaceContainerHigh: step(0.09),
      surfaceContainerHighest: step(0.12),
      outline: t.inkMuted,
      outlineVariant: t.divider,
    );
    final family = t.body.fontFamily;
    final fallback = t.body.fontFamilyFallback;
    final text = Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(
          fontFamily: family,
          fontFamilyFallback: fallback,
          bodyColor: t.ink,
          displayColor: t.ink,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      fontFamily: family,
      fontFamilyFallback: fallback,
      textTheme: text,
      // The one place ink is allowed.
      splashFactory: InkRipple.splashFactory,
      splashColor: t.accent.withValues(alpha: 0.18),
      highlightColor: t.ink.withValues(alpha: 0.06),
      hoverColor: t.ink.withValues(alpha: 0.06),
      focusColor: t.ink.withValues(alpha: 0.12),
      dividerColor: t.divider,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        circularTrackColor: Colors.transparent,
        linearTrackColor: scheme.surfaceContainerHighest,
        strokeCap: StrokeCap.round,
        strokeWidth: 3,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.accent,
        selectionColor: t.accent.withValues(alpha: 0.28),
        selectionHandleColor: t.accent,
      ),
    );
  }
}

/// Wraps a Material skin in the kit's Theme (and a transparent Material, so
/// ink has somewhere to splash and bare text never falls back to Flutter's
/// debug style). Reads the app theme from [ThemeScope].
///
/// Use it INSIDE a `material:` builder only; the other kits never see it.
class MaterialKitScope extends StatelessWidget {
  const MaterialKitScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = MaterialKitTheme.of(ThemeScope.of(context));
    return Theme(
      data: data,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// The colour scheme of the Material kit for the current app theme, for a skin
/// that needs a colour outside a widget's own theme.
ColorScheme materialKitScheme(BuildContext context) =>
    MaterialKitTheme.of(ThemeScope.of(context)).colorScheme;
