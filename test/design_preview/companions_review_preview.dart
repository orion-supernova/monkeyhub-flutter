// Design review renders for the companions: the install sheet, and the two
// residents' pages before anything is installed.
//
//   flutter test test/design_preview/companions_review_preview.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/brain_spec.dart';
import 'package:monkeyhub/companions/companion.dart';
import 'package:monkeyhub/screens/companions/marlowe_screen.dart';
import 'package:monkeyhub/screens/companions/sebastian_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/companion_install_sheet.dart';

import 'preview_kit.dart';

class _Page extends StatelessWidget {
  const _Page();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
        children: [Text('Chats', style: theme.displayLarge)],
      ),
    );
  }
}

const _themes = ['basic', 'basic_daylight', 'risograph_pop'];

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final tmp = Directory.systemTemp.createTempSync('mh_prev').path;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tmp,
    );
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });
  const locales = {'en': Locale('en'), 'tr': Locale('tr')};
  for (final id in _themes) {
    for (final lc in ['en', 'tr']) {
      testWidgets('companions: install sheet $id $lc', (tester) async {
        await snap(
          tester,
          previewApp(ThemeController.byId(id), const _Page(), locale: locales[lc]!),
          'comp_install_${id}_$lc.png',
          act: () async {
            final ctx = tester.element(find.byType(_Page));
            showCompanionInstallSheet(
              ctx,
              companion: Companion.sebastian,
              brain: BrainCatalog.sebastianBrains.first,
            );
            await tester.pump();
          },
        );
      });
      testWidgets('companions: sebastian $id $lc', (tester) async {
        await snap(
          tester,
          previewApp(ThemeController.byId(id), const SebastianScreen(), locale: locales[lc]!),
          'comp_sebastian_${id}_$lc.png',
        );
      });
    }
    testWidgets('companions: marlowe $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const MarloweScreen()),
        'comp_marlowe_$id.png',
      );
    });
  }
}
