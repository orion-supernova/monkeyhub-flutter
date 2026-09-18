import 'package:flutter/material.dart';

import 'app_theme.dart';

/// How the app picks its theme.
enum AppearanceMode {
  /// Follows the device: one theme while the phone is in light mode, another
  /// in dark — so a phone that goes dark at dusk takes the app with it.
  system,

  /// One theme, all day, whatever the device says.
  fixed;

  static AppearanceMode? parse(String? s) => switch (s) {
        'system' => AppearanceMode.system,
        'fixed' => AppearanceMode.fixed,
        _ => null,
      };
}

/// The light-mode half of the device-following pair, until somebody picks
/// another: iOS in the morning.
const String kDefaultLightThemeId = 'basic_daylight';

/// The dark-mode half: the app's own first theme.
const String kDefaultDarkThemeId = 'basic';

/// Light or dark, read off the theme's own background.
///
/// Derived rather than declared because the declaration that existed —
/// `ThemeMood` — is about typography and texture, not luminance: Daylight,
/// Rose and Vault Ivory are all light and none of them is `riso`. Keying the
/// status-bar glyphs off the mood painted white glyphs on Daylight's white
/// background. The palette is the truth, and a new theme is classified
/// correctly the day it ships without anybody remembering to tag it.
extension AppThemeBrightness on AppTheme {
  Brightness get brightness => ThemeData.estimateBrightnessForColor(background);

  bool get isLight => brightness == Brightness.light;
}

/// Which theme id [mode] resolves to under [platform].
///
/// A pure function so the rule is testable without a store or a binding:
/// fixed is [fixedId] whatever the device says; system is the slot matching
/// the device's brightness.
String resolveThemeId({
  required AppearanceMode mode,
  required Brightness platform,
  required String fixedId,
  required String lightId,
  required String darkId,
}) {
  if (mode == AppearanceMode.fixed) return fixedId;
  return platform == Brightness.light ? lightId : darkId;
}

/// What the settings store holds about appearance, parsed — including the one
/// judgement call, which is what an install that predates this setting gets.
///
/// Pure, so the upgrade path is testable without a keychain: the store hands
/// it the raw strings it read and takes the answer.
class StoredAppearance {
  const StoredAppearance({
    required this.mode,
    required this.fixedId,
    required this.lightId,
    required this.darkId,
    required this.onboarded,
  });

  final AppearanceMode mode;
  final String? fixedId;
  final String lightId;
  final String darkId;
  final bool onboarded;

  /// No stored mode means one of two installs: a fresh one, which follows the
  /// device, or one from before this setting existed — where a stored theme is
  /// a choice somebody made, and stays fixed. Either kind of choice also means
  /// the first-launch picker has nothing left to ask.
  factory StoredAppearance.parse({
    String? theme,
    String? mode,
    String? light,
    String? dark,
    String? onboarded,
  }) =>
      StoredAppearance(
        mode: AppearanceMode.parse(mode) ??
            (theme != null ? AppearanceMode.fixed : AppearanceMode.system),
        fixedId: theme,
        lightId: light ?? kDefaultLightThemeId,
        darkId: dark ?? kDefaultDarkThemeId,
        onboarded: onboarded == 'true' || theme != null || mode != null,
      );
}
