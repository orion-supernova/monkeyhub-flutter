import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/fight/core/bot.dart' as fb;
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/fight_renderer.dart';
import 'package:monkeyhub/fight/view/fight_screen.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// Screenshots of the real fight screen, so a human (or agent) can look at
/// the layout and every look. Written to FIGHT_SHOTS when set, else skipped
/// writing (the test still asserts the screen runs and renders).
final String? shotDir = Platform.environment['FIGHT_SHOTS'];

Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
  if (shotDir == null) return;
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    Directory(shotDir!).createSync(recursive: true);
    File('$shotDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await GoogleFonts.pendingFonts([
      GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800),
      GoogleFonts.anta(),
      GoogleFonts.doto(fontWeight: FontWeight.w900),
    ]);
    // Load the shader here, in the real async zone: a future first created
    // inside a test's fake-async zone never completes in the next test.
    await FightRenderer.warmUp();
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<GlobalKey> pumpFight(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FightScreen(player: roster[0], opponent: roster[0], level: fb.BotLevel.hard),
          ),
        ),
      ),
    );
    return key;
  }

  for (final look in ['cartoon', 'painted', 'pixel']) {
    testWidgets('phone portrait, $look: runs the fight and renders', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await SettingsStore.instance.setFightLook(look);
      final key = await pumpFight(tester, const Size(393, 852));
      // Intro, then ~4 seconds of the bot fighting a still player.
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (i == 40 || i == 120) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      }
      expect(tester.takeException(), isNull);
      await shot(tester, key, 'portrait_$look');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('landscape, $look: overlay controls and pause menu', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await SettingsStore.instance.setFightLook(look);
      final key = await pumpFight(tester, const Size(852, 393));
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (i == 40) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      }
      await shot(tester, key, 'landscape_$look');
      await tester.tapAt(Offset(852 / 2, 393 * 0.13 + 20));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Paused'), findsOneWidget);
      await shot(tester, key, 'landscape_${look}_paused');
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('desktop: keyboard hint, no touch deck', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await SettingsStore.instance.setFightLook('cartoon');
    final key = await pumpFight(tester, const Size(1280, 800));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.textContaining('WASD'), findsOneWidget);
    await shot(tester, key, 'desktop_cartoon');
    debugDefaultTargetPlatformOverride = null;
  });
}
