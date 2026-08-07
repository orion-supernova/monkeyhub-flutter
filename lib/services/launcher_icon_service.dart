import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

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
    final iconName = _platformIconName(activeTheme);
    try {
      final supports =
          await _channel.invokeMethod<bool>('supportsAlternateIcons') ?? false;
      if (!supports) return;
      final current = await _channel.invokeMethod<String?>(
        'getAlternateIconName',
      );
      if (current == iconName) return;
      await _channel.invokeMethod<void>('setAlternateIconName', {
        'iconName': iconName,
      });
    } on PlatformException catch (e) {
      // Surface the iOS-side error so we can see WHY a particular icon swap
      // is rejected (image missing in bundle, name not in plist, user denied,
      // device doesn't support it). The in-app brand mark still updates;
      // this is purely diagnostic.
      debugPrint(
        '[launcher_icon] PlatformException: code=${e.code} msg=${e.message} details=${e.details}',
      );
    } catch (e) {
      debugPrint('[launcher_icon] unexpected error: $e');
    }
  }

  /// The name actually handed to the platform, which is NOT the user's
  /// selection on Android.
  ///
  /// Android always gets `null` — the primary icon — no matter what the user
  /// picked. Every `<activity-alias>` icon ships as a single flat PNG under
  /// `res/mipmap-{density}/ic_launcher_{id}.png` with no `mipmap-anydpi-v26`
  /// XML beside it, so Android 8+ treats all 17 of them as LEGACY icons: the
  /// launcher supplies its own plate, masks the art, and shrinks it to fit.
  /// The primary MainActivity icon is the only adaptive one in the project
  /// (background colour + a foreground inset to the safe zone), so *any* swap
  /// away from it visibly downgrades the home screen. It lands hardest on OEM
  /// launchers — One UI plates legacy icons on white and scales them most
  /// aggressively — which is why this only ever reproduced on "some Android
  /// devices", and only for users who had picked a theme.
  ///
  /// Returning null also REPAIRS installs already stuck on an alias: the
  /// caller re-enables MainActivity whenever the live name differs from this
  /// one, so the next reconcile puts the adaptive icon back.
  ///
  /// iOS is untouched. `CFBundleAlternateIcons` takes the same flat art with
  /// no plating or masking, so the swap looks right there.
  ///
  /// Re-enable Android by deleting this branch once the alternates are
  /// generated as real adaptive icons — a background layer, a 108dp foreground
  /// respecting the 66% safe zone, and a monochrome layer for themed icons —
  /// with one `mipmap-anydpi-v26/ic_launcher_{id}.xml` per alias.
  static String? _platformIconName(AppTheme activeTheme) {
    if (Platform.isAndroid) return null;
    return _resolveIconName(SettingsStore.instance, activeTheme);
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
