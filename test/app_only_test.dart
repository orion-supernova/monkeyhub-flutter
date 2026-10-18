import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/privacy/app_only.dart';
import 'package:monkeyhub/privacy/capture_protection.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Where the platform cannot block a screenshot (the browser, Linux), a view
/// once message does not open: the reader is told why and where it does, and
/// the look is kept. In a browser the transcript button explains itself.
void main() {
  late BuildContext ctx;

  Widget host(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wide = size.width > 900;
    return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Above the navigator, so the sheet's route can read it too.
          builder: (context, child) => LayoutScope(
            windowClass: wide ? WindowClass.expanded : WindowClass.compact,
            width: size.width,
            child: ThemeScope(
              controller: ThemeController(BasicTheme.midnight()),
              child: child!,
            ),
          ),
          home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          }),
        );
  }

  tearDown(() => CaptureProtection.debugPlatformProtectsOverride = null);

  testWidgets('a protecting platform opens straight away', (tester) async {
    CaptureProtection.debugPlatformProtectsOverride = true;
    await tester.pumpWidget(host(tester, const Size(400, 800)));
    final open = AppOnly.confirmViewOnce(ctx);
    await tester.pumpAndSettle();
    expect(find.byType(AppOnlyPanel), findsNothing);
    expect(await open, isTrue);
  });

  testWidgets('elsewhere it explains, keeps the look, and never opens', (
    tester,
  ) async {
    CaptureProtection.debugPlatformProtectsOverride = false;
    await tester.pumpWidget(host(tester, const Size(400, 800)));
    final open = AppOnly.confirmViewOnce(ctx);
    await tester.pumpAndSettle();
    expect(find.text('Opens in the app'), findsOneWidget);
    expect(find.text('It stays sealed until you open it'), findsOneWidget);
    expect(find.text('Get the app'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing,
        reason: 'a phone browser has no second phone to scan with');

    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    expect(await open, isFalse);
  });

  testWidgets('on a computer the sheet carries a code to scan', (
    tester,
  ) async {
    CaptureProtection.debugPlatformProtectsOverride = false;
    await tester.pumpWidget(host(tester, const Size(1280, 900)));
    unawaited(AppOnly.confirmViewOnce(ctx));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Scan with your phone to get the app'), findsOneWidget);
  });

  testWidgets('transcripts say they are made on the device', (tester) async {
    await tester.pumpWidget(host(tester, const Size(400, 800)));
    unawaited(AppOnly.explainTranscripts(ctx));
    await tester.pumpAndSettle();
    expect(find.text('Transcripts'), findsOneWidget);
    expect(find.text('No audio is sent anywhere to be transcribed'),
        findsOneWidget);
  });
}
