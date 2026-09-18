import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/app.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/theme_onboarding_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_preference.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// "If your phone switches to dark mode in the evening, the app should pick
/// that up too" — and everything that has to be true for it to.
class _MemoryKeychain extends FlutterSecureStoragePlatform {
  final Map<String, String> items = {};

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      items[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      {...items};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async =>
      items[key] = value;

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      items.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async =>
      items.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      items.clear();
}

void main() {
  group('which themes are light', () {
    // Derived from each palette's background, not declared — the declaration
    // that existed (ThemeMood) called Daylight dark, and put white status-bar
    // glyphs on its white background.
    test('the four light palettes, and only those', () {
      final light = {
        for (final t in ThemeController.all)
          if (t.isLight) t.id,
      };
      expect(light, {
        'basic_daylight',
        'basic_rose',
        'vault_ivory',
        'risograph_pop',
      });
    });

    test('the default pair is one of each', () {
      expect(ThemeController.byId(kDefaultLightThemeId).isLight, isTrue);
      expect(ThemeController.byId(kDefaultDarkThemeId).isLight, isFalse);
    });
  });

  group('resolving', () {
    test('following the device, the slot matches its brightness', () {
      String at(Brightness b) => resolveThemeId(
            mode: AppearanceMode.system,
            platform: b,
            fixedId: 'cyberpunk',
            lightId: 'basic_rose',
            darkId: 'deep_ocean',
          );
      expect(at(Brightness.light), 'basic_rose');
      expect(at(Brightness.dark), 'deep_ocean');
    });

    test('fixed ignores the device entirely', () {
      for (final b in Brightness.values) {
        expect(
          resolveThemeId(
            mode: AppearanceMode.fixed,
            platform: b,
            fixedId: 'cyberpunk',
            lightId: 'basic_rose',
            darkId: 'deep_ocean',
          ),
          'cyberpunk',
        );
      }
    });
  });

  group('what an upgrade finds', () {
    test('a fresh install follows the device, and is asked first', () {
      final a = StoredAppearance.parse();
      expect(a.mode, AppearanceMode.system);
      expect(a.lightId, kDefaultLightThemeId);
      expect(a.darkId, kDefaultDarkThemeId);
      expect(a.onboarded, isFalse);
    });

    test('an install that had picked a theme keeps it, fixed', () {
      final a = StoredAppearance.parse(theme: 'vault_noir');
      expect(a.mode, AppearanceMode.fixed);
      expect(a.fixedId, 'vault_noir');
      expect(a.onboarded, isTrue, reason: 'it already answered the question');
    });

    test('a stored mode wins over the inference', () {
      final a = StoredAppearance.parse(theme: 'vault_noir', mode: 'system');
      expect(a.mode, AppearanceMode.system);
    });
  });

  group('the store', () {
    setUp(() {
      FlutterSecureStoragePlatform.instance = _MemoryKeychain();
    });

    test('fixing a theme from "match device" keeps what is on screen', () async {
      final store = SettingsStore.instance;
      await store.setAppearanceMode(AppearanceMode.system);
      await store.setAppearanceMode(AppearanceMode.fixed, current: 'basic_rose');

      expect(store.themeIdFor(Brightness.dark), 'basic_rose');
      expect(store.themeIdFor(Brightness.light), 'basic_rose');
    });

    test('each half of the pair is set on its own', () async {
      final store = SettingsStore.instance;
      await store.setAppearanceMode(AppearanceMode.system);
      await store.setSlotTheme(Brightness.light, 'vault_ivory');
      await store.setSlotTheme(Brightness.dark, 'neon_night');

      expect(store.themeIdFor(Brightness.light), 'vault_ivory');
      expect(store.themeIdFor(Brightness.dark), 'neon_night');
    });

    test('picking one theme outright leaves "match device"', () async {
      final store = SettingsStore.instance;
      await store.setAppearanceMode(AppearanceMode.system);
      await store.setThemeId('cyberpunk');

      expect(store.appearanceMode, AppearanceMode.fixed);
      expect(store.themeIdFor(Brightness.light), 'cyberpunk');
    });
  });

  testWidgets('the first-launch picker records its answer', (t) async {
    FlutterSecureStoragePlatform.instance = _MemoryKeychain();
    t.view.physicalSize = const Size(430, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final store = SettingsStore.instance;
    await store.setAppearanceMode(AppearanceMode.system);

    await t.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ThemeOnboardingScreen(),
      ),
    ));
    await t.pumpAndSettle();

    // Following the device: a strip for each half of the pair.
    expect(find.text('LIGHT MODE'), findsOneWidget);
    expect(find.text('DARK MODE'), findsOneWidget);

    await t.tap(find.text('Rose'));
    await t.pump();
    expect(store.lightThemeId, 'basic_rose');

    await t.tap(find.text('One theme'));
    await t.pumpAndSettle();
    expect(store.appearanceMode, AppearanceMode.fixed);
    expect(find.text('YOUR THEME'), findsOneWidget);

    await t.tap(find.text('CONTINUE'));
    await t.pump();
    expect(store.themeOnboarded, isTrue);
  });

  // End to end, through the real app: the device goes light and the app goes
  // with it, live — the status bar's idea of light included.
  testWidgets('the app follows the device from dark to light', (t) async {
    FlutterSecureStoragePlatform.instance = _MemoryKeychain();
    await SettingsStore.instance.setAppearanceMode(AppearanceMode.system);
    await SettingsStore.instance.setSlotTheme(Brightness.light, 'basic_daylight');
    await SettingsStore.instance.setSlotTheme(Brightness.dark, 'basic');
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

    await t.pumpWidget(const MonkeyHubApp());
    await t.pump(const Duration(milliseconds: 200));
    BuildContext app() => t.element(find.byType(MaterialApp));
    expect(ThemeScope.of(app()).id, 'basic');
    expect(Theme.of(t.element(find.byType(Navigator).first)).brightness,
        Brightness.dark);

    t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await t.pump();
    // Past MaterialApp's own theme animation, which lerps ThemeData over
    // kThemeAnimationDuration and flips brightness halfway through.
    await t.pump(const Duration(milliseconds: 300));

    expect(ThemeScope.of(app()).id, 'basic_daylight');
    expect(Theme.of(t.element(find.byType(Navigator).first)).brightness,
        Brightness.light);
  });
}
