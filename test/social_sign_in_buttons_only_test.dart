import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/social_sign_in.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/social_sign_in_buttons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// Linked Accounts renders one card per provider and asks this widget for a
/// single button at a time — the Apple one still has to be Apple's own widget
/// there, so the card narrows the set rather than hand-rolling the mark.
void main() {
  /// Pumps on [platform], then puts the override back before the body ends —
  /// the test framework asserts on any foundation debug var left set, and it
  /// checks before tearDown gets a turn.
  Future<void> pumpOn(
    WidgetTester tester,
    TargetPlatform platform, {
    List<SocialProvider>? only,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SocialSignInButtons(
                only: only,
                dividerLabel: null,
                onProvider: (_) {},
              ),
            ),
          ),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('asking for Apple alone leaves Google out', (tester) async {
    await pumpOn(tester, TargetPlatform.iOS, only: [SocialProvider.apple]);
    expect(find.byType(SignInWithAppleButton), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('asking for Google alone leaves Apple out', (tester) async {
    // Whether Google draws at all depends on the deployment's config, so the
    // assertion that matters here is the one about Apple: a card for one
    // provider must never sprout the other's button.
    await pumpOn(tester, TargetPlatform.iOS, only: [SocialProvider.google]);
    expect(find.byType(SignInWithAppleButton), findsNothing);
  });

  testWidgets('no filter still renders the full set', (tester) async {
    await pumpOn(tester, TargetPlatform.iOS);
    expect(find.byType(SignInWithAppleButton), findsOneWidget);
  });

  testWidgets('a provider this platform cannot do is dropped anyway', (
    tester,
  ) async {
    // Android has no native Sign in with Apple — asking for it loudly must not
    // conjure a button that would dead-end.
    await pumpOn(tester, TargetPlatform.android, only: [SocialProvider.apple]);
    expect(find.byType(SignInWithAppleButton), findsNothing);
  });
}
