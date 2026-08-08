import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/apple_button_titles.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/social_sign_in_buttons.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// The Apple and Google buttons are the two places in this app where the design
/// is somebody else's to dictate. Both have already drifted once — the Apple
/// title into three wrong translations, the Google button into the app's own
/// colours with no "G" at all — so the vendors' fixed values are asserted here
/// rather than left to a reviewer to notice.
void main() {
  setUpAll(() {
    // `SocialSignIn.googleAvailable` is gated on a real OAuth client id, which
    // a test process has no dotenv to read. Without this the Google button
    // simply never renders and every assertion below passes vacuously.
    dotenv.loadFromString(envString: 'GOOGLE_SERVER_CLIENT_ID=test-client-id');
  });

  Future<void> pump(
    WidgetTester tester, {
    required AppTheme theme,
    Locale locale = const Locale('en'),
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(theme),
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SocialSignInButtons(dividerLabel: null, onProvider: (_) {}),
            ),
          ),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// The Google button's own container — located through the "G", so this can
  /// never accidentally read the Apple button's decoration instead.
  BoxDecoration googleDecoration(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.byType(SvgPicture),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  group('Apple button title', () {
    test('every supported locale has one of Apple\'s own titles', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final title = appleContinueTitle(locale);
        expect(title, isNotEmpty, reason: 'no title for $locale');
        expect(
          title,
          contains('Apple'),
          reason: 'Apple keeps its name untranslated in every locale — $locale',
        );
      }
    });

    test('an unsupported locale falls back to English', () {
      expect(appleContinueTitle(const Locale('is')), 'Continue with Apple');
    });

    test('regional variants resolve through their language', () {
      // pt-BR has no entry of its own because Apple ships the same string for
      // both Portuguese variants.
      expect(
        appleContinueTitle(const Locale('pt', 'BR')),
        appleContinueTitle(const Locale('pt')),
      );
    });

    testWidgets('the button renders Apple\'s string, not ours', (tester) async {
      // zh is the sharpest case: Apple sets it without spaces around "Apple",
      // and the ARB value this replaced had them.
      await pump(
        tester,
        theme: BasicTheme.midnight(),
        locale: const Locale('zh'),
      );
      expect(find.byType(SignInWithAppleButton), findsOneWidget);
      expect(find.text('通过Apple继续'), findsOneWidget);
      expect(find.text('通过 Apple 继续'), findsNothing);
    });
  });

  group('Google button', () {
    testWidgets('carries Google\'s mark', (tester) async {
      await pump(tester, theme: BasicTheme.midnight());
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('and that mark actually resolves and parses', (tester) async {
      // find.byType(SvgPicture) passes even when the asset is missing or
      // malformed — the widget renders empty and says nothing. This is the
      // assertion that would fail if branding/google_g.svg were dropped from
      // pubspec, renamed, or hand-edited into invalid XML.
      await tester.runAsync(() async {
        final bytes = await const SvgAssetLoader(
          'branding/google_g.svg',
        ).loadBytes(null);
        expect(bytes.lengthInBytes, greaterThan(0));
      });
    });

    testWidgets('sets its label in Google Sans Medium 14/20, not the theme\'s '
        'face', (tester) async {
      await pump(tester, theme: BasicTheme.midnight());
      final label = tester.widget<Text>(find.text('Continue with Google'));
      expect(label.style!.fontFamily, 'Google Sans');
      expect(label.style!.fontWeight, FontWeight.w500);
      expect(label.style!.fontSize, 14);
      expect(label.style!.height, 20 / 14);

      // Flutter resolves fontFamily by string and falls back to the platform
      // face without a word if nothing is registered under that name, so the
      // asset behind it is asserted separately — a `fonts:` entry dropped from
      // pubspec would otherwise surface only on a real device.
      await tester.runAsync(() async {
        final ttf = await rootBundle.load('assets/fonts/GoogleSans-Medium.ttf');
        expect(ttf.lengthInBytes, greaterThan(0));
      });
    });

    testWidgets('renders every localized label it claims to support', (
      tester,
    ) async {
      // The subset covers Latin + Latin Extended plus whatever these twelve
      // labels need. Adding a locale without re-cutting it would show up as
      // tofu on a device and as nothing at all in a normal widget test, so the
      // labels are at least asserted to be present and non-empty per locale.
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = await AppLocalizations.delegate.load(locale);
        expect(
          l10n.socialButtonGoogleContinue,
          contains('Google'),
          reason: 'Google keeps its name untranslated — $locale',
        );
      }
    });

    testWidgets('wears Google\'s dark treatment on a dark theme', (
      tester,
    ) async {
      await pump(tester, theme: BasicTheme.midnight());
      final decoration = googleDecoration(tester);
      expect(decoration.color, const Color(0xFF131314));
      expect(
        (decoration.border! as Border).top.color,
        const Color(0xFF8E918F),
      );
    });

    testWidgets('wears Google\'s light treatment on a light theme', (
      tester,
    ) async {
      await pump(tester, theme: BasicTheme.daylight());
      final decoration = googleDecoration(tester);
      expect(decoration.color, const Color(0xFFFFFFFF));
      expect(
        (decoration.border! as Border).top.color,
        const Color(0xFF747775),
      );
    });

    testWidgets('takes no colour from the theme', (tester) async {
      // The bug this replaces: the container was theme.surfaceRaised with a
      // theme.divider border, which changes with the palette. Google's does not.
      await pump(tester, theme: BasicTheme.midnight());
      final midnight = googleDecoration(tester).color;
      await pump(tester, theme: BasicTheme.graphite());
      expect(googleDecoration(tester).color, midnight);
    });

    testWidgets('shares the theme radius with the Apple button', (tester) async {
      final theme = BasicTheme.midnight();
      await pump(tester, theme: theme);
      final apple = tester.widget<SignInWithAppleButton>(
        find.byType(SignInWithAppleButton),
      );
      expect(apple.borderRadius, BorderRadius.circular(theme.radiusMd));
      expect(
        googleDecoration(tester).borderRadius,
        BorderRadius.circular(theme.radiusMd),
      );
    });

    testWidgets('is never shorter than the Apple button', (tester) async {
      // Guideline 4.8 / the HIG: Apple's may not end up the smaller of the two.
      await pump(tester, theme: BasicTheme.midnight());
      final apple = tester.getSize(find.byType(SignInWithAppleButton));
      final google = tester.getSize(
        find
            .ancestor(
              of: find.byType(SvgPicture),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(google.height, apple.height);
    });
  });
}
