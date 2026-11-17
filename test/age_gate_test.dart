import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/age_gate.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The client half of the age check. The rules must match
/// `backend/convex/ageCore.ts` exactly (the server decides; this only spares a
/// refused child the round trip), and a refusal must stick on the install.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ageInYears matches ageCore.ageInYears', () {
    test('a year counts only once the birth month has passed', () {
      final march2026 = DateTime.utc(2026, 3, 15);
      final april2026 = DateTime.utc(2026, 4, 1);
      expect(ageInYears(const BirthMonth(2013, 3), march2026), 12);
      expect(ageInYears(const BirthMonth(2013, 3), april2026), 13);
      expect(ageInYears(const BirthMonth(2013, 2), march2026), 13);
    });

    test('bands: under 9, 9 to 12, 13 and over', () {
      expect(ageBand(8), AgeBand.tooYoung);
      expect(ageBand(9), AgeBand.needsGuardian);
      expect(ageBand(12), AgeBand.needsGuardian);
      expect(ageBand(13), AgeBand.ok);
    });
  });

  late BuildContext ctx;
  Future<void> host(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
  }

  testWidgets('old enough: confirm returns the month', (tester) async {
    await host(tester);
    BirthMonth? got;
    unawaited(askAgeForSignUp(ctx).then((b) => got = b));
    await tester.pumpAndSettle();
    // The wheels open 15 years back.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('so you’re 1'), findsOneWidget);
    await tester.tap(find.text('Yes, that’s right'));
    await tester.pumpAndSettle();
    expect(got?.year, DateTime.now().year - 15);
  });

  testWidgets('too young for their own account: refused, and it sticks',
      (tester) async {
    await host(tester);
    var done = false;
    BirthMonth? got;
    unawaited(askAgeForSignUp(ctx).then((b) {
      got = b;
      done = true;
    }));
    await tester.pumpAndSettle();
    // Scroll the year wheel 4 rows towards now: 11 years back, so 10 or 11.
    await tester.drag(find.text('${DateTime.now().year - 15}'), const Offset(0, 4 * 38));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, that’s right'));
    await tester.pumpAndSettle();
    expect(find.text('Ask a parent'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(got, isNull);

    // Opening it again goes straight to the refusal: no second try.
    unawaited(askAgeForSignUp(ctx));
    await tester.pumpAndSettle();
    expect(find.text('Ask a parent'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });
}
