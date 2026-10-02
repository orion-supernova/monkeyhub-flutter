// Renders first-run and sign-in screens to PNG under a few themes.
//
//   flutter test test/design_preview/onboarding_preview.dart
//
// Output: build/design_preview/onb_<screen>_<themeId>.png. Not a test.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/login_screen.dart';
import 'package:monkeyhub/screens/logo_screen.dart';
import 'package:monkeyhub/screens/theme_onboarding_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'preview_kit.dart';

/// SettingsStore writes through to the keychain; a no-op one keeps a tap in
/// a preview from throwing a MissingPluginException.
class _NullKeychain extends FlutterSecureStoragePlatform {
  final Map<String, String> items = {};

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => items[key];

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => items[key] = value;

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => items.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => items.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      items.clear();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => items;
}

/// [snap], with a hook between the first pump and the capture — for screens
/// whose interesting state is one tap away.
Future<void> _snapAfter(
  WidgetTester tester,
  Widget widget,
  String name,
  Future<void> Function() before,
) async {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = kIphone16Pro * dpr;
  final pad = FakeViewPadding(
    top: kIphoneTopInset * dpr,
    bottom: kIphoneBottomInset * dpr,
  );
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: widget));
  await _decodeImages(tester);
  await tester.pump(const Duration(seconds: 2));
  await before();
  // The tap's own frame only starts whatever it triggers; the second pump is
  // the one that lands it.
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(seconds: 2));
  await _decodeImages(tester);
  await tester.pump(const Duration(milliseconds: 16));

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final out = File('$kPreviewDir/$name');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes!);
}

/// Image.asset decodes on real time, which a test's fake clock never gives it:
/// precache every image on screen for real, then repaint.
Future<void> _decodeImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
}

void main() {
  setUpAll(() async {
    FlutterSecureStoragePlatform.instance = _NullKeychain();
    await loadPreviewFonts();
  });

  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    final theme = ThemeController.byId(id);

    testWidgets('onboarding look: $id', (tester) async {
      await snap(
        tester,
        previewApp(theme, const ThemeOnboardingScreen()),
        'onb_look_$id.png',
      );
    });

    testWidgets('onboarding icon: $id', (tester) async {
      await _snapAfter(
        tester,
        previewApp(theme, const ThemeOnboardingScreen()),
        'onb_icon_$id.png',
        () async {
          final l10n = await AppLocalizations.delegate.load(
            const Locale('en'),
          );
          await tester.tap(find.text(l10n.onboardingContinue));
        },
      );
    });

    testWidgets('login: $id', (tester) async {
      await snap(
        tester,
        previewApp(
          theme,
          LoginScreen(auth: AuthService(ChatApi(ConvexBackend.instance))),
        ),
        'onb_login_$id.png',
      );
    });

    testWidgets('logo screen: $id', (tester) async {
      await snap(
        tester,
        previewApp(theme, const LogoScreen()),
        'onb_logo_$id.png',
      );
    });
  }
}
