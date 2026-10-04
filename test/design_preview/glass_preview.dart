// Settings › Glass with iOS Liquid Glass on and off.
//
//   flutter test test/design_preview/glass_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/screens/glass_screen.dart';
import 'package:monkeyhub/screens/navigation/native_tab_bar.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'preview_kit.dart';

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() => NativeChrome.debugSupported = true);
  tearDown(() => NativeChrome.debugSupported = false);

  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('glass surfaces preview: $id', (tester) async {
      NativeChrome.debugSupported = false;
      SettingsStore.instance.setGlassEngine(GlassEngine.flutter);
      SettingsStore.instance.selectGlassPreset('frosted');
      SettingsStore.instance.flushGlassWrites();
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const GlassScreen()),
        'glass_surfaces_$id.png',
        act: () async {
          await tester.scrollUntilVisible(
            find.text('Other surfaces'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -320),
          );
        },
      );
    });
  }

  for (final engine in GlassEngine.values) {
    for (final id in ['basic', 'basic_daylight']) {
      testWidgets('glass preview: ${engine.name} $id', (tester) async {
        // Not awaited: the field flips synchronously, and the keychain write
        // behind it never answers under flutter_test.
        SettingsStore.instance.setGlassEngine(engine);
        await snap(
          tester,
          previewApp(ThemeController.byId(id), const GlassScreen()),
          'glass_${engine.name}_$id.png',
        );
      });
    }
  }
}
