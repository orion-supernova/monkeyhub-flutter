import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/privacy/capture_notice.dart';
import 'package:monkeyhub/privacy/capture_protection.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// The honest side of capture protection: where the platform cannot block a
/// screenshot (the browser, Linux), the room says so once and a view-once
/// message asks before it spends the one look.
void main() {
  late BuildContext ctx;

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // Above the navigator, so the alert's route can read it too.
    builder: (context, child) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: child!,
    ),
    home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    }),
  );

  setUp(CaptureNotice.debugReset);
  tearDown(() => CaptureProtection.debugPlatformProtectsOverride = null);

  testWidgets('a protecting platform says nothing and opens straight away', (
    tester,
  ) async {
    CaptureProtection.debugPlatformProtectsOverride = true;
    await tester.pumpWidget(host());
    final open = CaptureNotice.confirmViewOnce(ctx);
    unawaited(CaptureNotice.warnRoomOnce(ctx, 'r1'));
    await tester.pumpAndSettle();
    expect(find.text("Screenshots aren't blocked here"), findsNothing);
    expect(await open, isTrue);
  });

  testWidgets('an ephemeral room warns once per room', (tester) async {
    CaptureProtection.debugPlatformProtectsOverride = false;
    await tester.pumpWidget(host());

    unawaited(CaptureNotice.warnRoomOnce(ctx, 'r1'));
    await tester.pumpAndSettle();
    expect(find.text("Screenshots aren't blocked here"), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text("Screenshots aren't blocked here"), findsNothing);

    unawaited(CaptureNotice.warnRoomOnce(ctx, 'r1'));
    await tester.pumpAndSettle();
    expect(find.text("Screenshots aren't blocked here"), findsNothing,
        reason: 'the same room does not ask twice');

    unawaited(CaptureNotice.warnRoomOnce(ctx, 'r2'));
    await tester.pumpAndSettle();
    expect(find.text("Screenshots aren't blocked here"), findsOneWidget);
  });

  testWidgets('a view-once message asks first, and Not now keeps the look', (
    tester,
  ) async {
    CaptureProtection.debugPlatformProtectsOverride = false;
    await tester.pumpWidget(host());

    var open = CaptureNotice.confirmViewOnce(ctx);
    await tester.pumpAndSettle();
    expect(find.text('This can be captured here'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(await open, isFalse);

    open = CaptureNotice.confirmViewOnce(ctx);
    await tester.pumpAndSettle();
    expect(find.text('This can be captured here'), findsOneWidget,
        reason: 'asked every time: each open would spend the look');
    await tester.tap(find.text('Open anyway'));
    await tester.pumpAndSettle();
    expect(await open, isTrue);
  });
}

