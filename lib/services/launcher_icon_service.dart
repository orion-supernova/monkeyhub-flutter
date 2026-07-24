import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_brand_mark.dart' show canonicalLogoId;
import '../widgets/monkey_collection.dart';
import 'launcher_icon_names.dart';

/// Resolves the user's logo selection to a native alternate-icon name and
/// swaps the home-screen launcher icon via a method channel.
///
/// Naming convention: each theme's `id` IS its alternate-icon name (matches
/// the keys in `ios/Runner/Info.plist` `CFBundleAlternateIcons` and the
/// `<activity-alias android:name=".$id">` entries in AndroidManifest.xml).
/// The canonical MonkeyHub icon is the primary launcher icon — switching to
/// it means passing `iconName: null` (clears any active alternate).
///
/// On Android, swapping activity-aliases is done via PackageManager with
/// DONT_KILL_APP so the foreground process survives. iOS will pop a system
/// alert the first time per app version unless suppressed.
///
/// Backed by `monkeyhub/launcher_icon` — wired in:
///  - ios/Runner/AppDelegate.swift
///  - android/app/src/main/kotlin/.../MainActivity.kt
class LauncherIconService {
  LauncherIconService._();

  static const _channel = MethodChannel('monkeyhub/launcher_icon');

  /// Apply the current SettingsStore selection. Safe to call repeatedly.
  static Future<void> applyFromSettings(AppTheme activeTheme) async {
    if (!_supportedPlatform) return;
    final iconName = _resolveIconName(SettingsStore.instance, activeTheme);
    try {
      final supports =
          await _channel.invokeMethod<bool>('supportsAlternateIcons') ?? false;
      if (!supports) return;
      final current =
          await _channel.invokeMethod<String?>('getAlternateIconName');
      // ignore: avoid_print
      print(
        '[launcher_icon] requesting iconName=$iconName (current=$current)',
      );
      if (current == iconName) return;
      await _channel.invokeMethod<void>(
        'setAlternateIconName',
        {'iconName': iconName},
      );
      // ignore: avoid_print
      print('[launcher_icon] applied OK: $iconName');
    } on PlatformException catch (e) {
      // Surface the iOS-side error so we can see WHY a particular icon swap
      // is rejected (image missing in bundle, name not in plist, user denied,
      // device doesn't support it). The in-app brand mark still updates;
      // this print is purely diagnostic.
      // ignore: avoid_print
      print(
        '[launcher_icon] PlatformException: code=${e.code} msg=${e.message} details=${e.details}',
      );
    } catch (e) {
      // ignore: avoid_print
      print('[launcher_icon] unexpected error: $e');
    }
  }

  /// Returns the alt-icon name for the current selection. `null` means "use
  /// the primary icon" (the canonical MonkeyHub mark).
  static String? _resolveIconName(SettingsStore s, AppTheme activeTheme) {
    switch (s.logoMode) {
      case LogoMode.auto:
        return launcherIconNameForThemeId(activeTheme.id);
      case LogoMode.alwaysDefault:
        return null;
      case LogoMode.manual:
        final id = s.manualLogoThemeId;
        if (id == null || id == canonicalLogoId) return null;
        // Monkey-collection ids carry the platform alt-icon name directly —
        // they're not theme ids, so the ThemeController lookup below would
        // miss them.
        if (monkeyCollectionIds.contains(id)) return id;
        // Theme id — validate it still exists (guards against stale storage
        // after a theme is removed) then translate to its platform name.
        final exists = ThemeController.all.any((t) => t.id == id);
        return exists ? launcherIconNameForThemeId(id) : null;
    }
  }

  static bool get _supportedPlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);
}
