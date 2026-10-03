import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/glass_config.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/glass_screen.dart';
import 'package:monkeyhub/screens/navigation/native_tab_bar.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

void main() {
  final store = SettingsStore.instance;
  final en = lookupAppLocalizations(const Locale('en'));

  setUp(() => NativeChrome.debugSupported = true);
  tearDown(() {
    NativeChrome.debugSupported = false;
    store.setGlassEngine(GlassEngine.native);
    store.selectGlassPreset(kDefaultGlassPresetId);
    store.flushGlassWrites();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GlassScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Scale of the checkmark on the row titled [title] — 1 when it shows.
  double tick(WidgetTester tester, String title) {
    final row = find.ancestor(
      of: find.text(title),
      matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'GroupedRow'),
    );
    final scale = find.descendant(of: row, matching: find.byType(AnimatedScale));
    return tester.widget<AnimatedScale>(scale.last).scale;
  }

  testWidgets('the checkmark follows every tap, both ways', (tester) async {
    store.setGlassEngine(GlassEngine.native);
    await pump(tester);
    expect(tick(tester, en.glassStyleLiquidTitle), 1);
    expect(tick(tester, en.glassStyleFrostedTitle), 0);

    await tester.tap(find.text(en.glassStyleFrostedTitle));
    await tester.pumpAndSettle();
    expect(store.glassEngine, GlassEngine.flutter);
    expect(tick(tester, en.glassStyleFrostedTitle), 1,
        reason: 'the tick has to move, not just the stored value');
    expect(tick(tester, en.glassStyleLiquidTitle), 0);

    await tester.tap(find.text(en.glassStyleLiquidTitle));
    await tester.pumpAndSettle();
    expect(store.glassEngine, GlassEngine.native);
    expect(tick(tester, en.glassStyleLiquidTitle), 1);
  });

  testWidgets('under Frosted a look can be picked', (tester) async {
    store.setGlassEngine(GlassEngine.flutter);
    await pump(tester);
    final clear = find.text('Clear');
    await tester.scrollUntilVisible(clear, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(store.glassPresetId, 'clear');
  });
}
