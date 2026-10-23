import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/social_sign_in.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/screens/social_username_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// Regresses a trap this screen actually shipped with.
///
/// A first-time Apple sign-in landed here, the user typed the username they had
/// owned for months, got USERNAME_TAKEN — and could not leave. The screen is
/// pushed as a `fullscreenDialog`, which on iOS also disables swipe-back, and it
/// carries no AppBar, so Flutter's usual close button never appeared. There was
/// no gesture and no control that exited.
///
/// Two rules fall out of that, and both are asserted here: there is always a way
/// out, and there is always a way to reach the existing-account path.
///
/// ANTI-HANG DISCIPLINE — same as recovery_gate_test: nothing here may touch
/// the network. Every assertion is about what is on screen, so the AuthService
/// is never actually called.
void main() {
  /// Never invoked — the tests below only tap controls that navigate or switch
  /// mode locally, never the submit button.
  AuthService inertAuth() => AuthService(ChatApi(ConvexBackend.instance));

  const credential = SocialCredential(
    provider: SocialProvider.apple,
    idToken: 'header.payload.signature',
    rawNonce: 'nonce',
  );

  /// Pushes the screen the way the login screen does — as a fullscreenDialog,
  /// which is the exact configuration that hid the close button.
  ///
  /// ThemeScope goes ABOVE MaterialApp: a pushed route is a sibling of `home`
  /// under the Navigator, so a ThemeScope nested inside `home` is not an
  /// ancestor of it. Mirrors the real app. (Same note as recovery_gate_test.)
  Future<void> pushScreen(WidgetTester tester, {AuthService? auth}) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late BuildContext ctx;
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

    unawaited(
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => SocialUsernameScreen(
            auth: auth ?? inertAuth(),
            credential: credential,
            suggestedName: 'Murat',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('there is always a way out', (tester) async {
    await pushScreen(tester);
    expect(find.byType(SocialUsernameScreen), findsOneWidget);

    // The trap was the absence of exactly this.
    final close = find.byIcon(CupertinoIcons.xmark);
    expect(close, findsOneWidget,
        reason: 'no close control means a failed attempt strands the user');

    await tester.tap(close);
    await tester.pumpAndSettle();

    expect(find.byType(SocialUsernameScreen), findsNothing);
  });

  testWidgets('the existing-account path is reachable', (tester) async {
    await pushScreen(tester);

    // Creating is the default, so the password field is not up yet.
    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.text('Already have an account?'));
    await tester.pumpAndSettle();

    // Now it asks for the credential that proves the existing account.
    expect(find.text('Create account'), findsNothing);
    expect(find.textContaining('Sign in & link'), findsOneWidget);
  });

  testWidgets('it can switch back, so neither mode is a trap either',
      (tester) async {
    await pushScreen(tester);

    await tester.tap(find.text('Already have an account?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('success dismisses the route instead of covering the app',
      (tester) async {
    // The second bug this screen shipped, and the one that looked like a hang.
    //
    // Signing in flips `isSignedIn`, which makes `_AppHome` swap its child from
    // LoginScreen to HomeShell. But that child is `MaterialApp.home`, and this
    // screen is pushed ON TOP of it — so without the pop the app is fully
    // signed in, HomeShell is built and rendering, and the user still sees this
    // form. Nothing in the logs looks wrong, which is what made it confusing.
    await pushScreen(tester, auth: _StubAuth());
    expect(find.byType(SocialUsernameScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'murat');

    // Creating an account needs the Terms consent (TermsConsentRow). Without
    // it the submit is refused and the screen correctly stays up.
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(SocialUsernameScreen), findsOneWidget,
        reason: 'no consent, no account');

    await tester.tap(find.byIcon(CupertinoIcons.square));
    await tester.pump();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(SocialUsernameScreen), findsNothing,
        reason: 'the route must pop, or it hides the HomeShell underneath it');
  });
}

/// An AuthService whose social calls succeed instantly and touch nothing.
///
/// Subclassed rather than mocked because the screen only needs two methods to
/// return, and a real one would reach the network — see the anti-hang note.
class _StubAuth extends AuthService {
  _StubAuth() : super(ChatApi(ConvexBackend.instance));

  @override
  Future<void> completeSocialSignUp({
    required SocialCredential credential,
    required String username,
    String? name,
  }) async {}

  @override
  Future<void> linkSocialToExistingAccount({
    required SocialCredential credential,
    required String username,
    required String password,
  }) async {}
}
