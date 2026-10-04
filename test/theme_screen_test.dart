import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/theme_screen.dart';
import 'package:monkeyhub/theme/theme_preference.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';

/// The theme picker's full-screen preview: it has to be FINDABLE (a visible
/// way in, not only touch-and-hold), and applying from it has to land the
/// theme and close cleanly while the app re-themes underneath.
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

/// The app in miniature: the store drives the theme, and the home under the
/// picker is keyed by the theme — the same remount a real theme change
/// causes — with the picker pushed on the root navigator above it.
Widget _app(ThemeController controller) => AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        controller.theme = ThemeController.byId(SettingsStore.instance.themeId ?? 'basic');
        return ThemeScope(
          controller: controller,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              key: ValueKey('home_${controller.theme.id}'),
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ThemeScreen()),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
      },
    );

Future<void> _openPicker(WidgetTester tester, ThemeController c) async {
  tester.view.physicalSize = const Size(393, 1600) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(c));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    FlutterSecureStoragePlatform.instance = _MemoryKeychain();
    await SettingsStore.instance
        .setAppearanceMode(AppearanceMode.fixed, current: 'basic');
    await SettingsStore.instance.setThemeId('basic');
  });

  testWidgets('the section header\'s Preview opens the carousel on the theme '
      'in use, and × closes it', (tester) async {
    final c = ThemeController(ThemeController.byId('basic'));
    await _openPicker(tester, c);

    expect(find.byType(PageView), findsNothing);
    await tester.tap(find.text('Preview').first);
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(GlassCloseButton), findsOneWidget);
    // Opened on Midnight, which is already the theme: the pill says so.
    expect(find.text('In use'), findsOneWidget);

    await tester.tap(find.byType(GlassCloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(ThemeScreen), findsOneWidget);
  });

  testWidgets('a tile\'s corner glyph opens the carousel on THAT theme',
      (tester) async {
    final c = ThemeController(ThemeController.byId('basic'));
    await _openPicker(tester, c);

    // Third tile: Graphite.
    await tester.tap(
      find.byIcon(CupertinoIcons.arrow_up_left_arrow_down_right).at(2),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Use Graphite'), findsOneWidget);
  });

  testWidgets('APPLY lands the theme, remounts the home and closes the '
      'carousel without throwing', (tester) async {
    final c = ThemeController(ThemeController.byId('basic'));
    await _openPicker(tester, c);

    await tester.tap(
      find.byIcon(CupertinoIcons.arrow_up_left_arrow_down_right).at(2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Graphite'));
    await tester.pumpAndSettle();

    expect(SettingsStore.instance.themeId, 'basic_graphite');
    expect(c.theme.id, 'basic_graphite');
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(ThemeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
