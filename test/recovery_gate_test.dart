import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/recovery_phrase.dart';
import 'package:monkeyhub/screens/recovery_phrase_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// The save-your-recovery-phrase gate.
///
/// ANTI-HANG DISCIPLINE — this suite runs in about ten seconds and a hanging
/// test is a bug in the test, not a cost of the toolchain. Two rules for this
/// file: `onCommit` must complete immediately (never a real network future),
/// and the screen must start no `Timer` — deliberately unlike
/// pairing_code_screen.dart, whose one-second ticker would leave the binding
/// with pending timers at the end of every pump.
void main() {
  // Seeded so the rendered words are deterministic.
  final phrase = RecoveryPhrase.generate(random: Random(42));

  /// Twelve word cells plus a hero, two paragraphs, a copy button and a CTA is
  /// taller than the 800x600 default test window, so the primary button sits
  /// off-screen and `tap()` silently misses it. Give every test room rather
  /// than sprinkling `ensureVisible` around — the point of these tests is the
  /// behaviour, not the scroll position.
  void roomToBreathe(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: child,
        ),
      );

  /// A host that PUSHES the gate as a route, for the pop-guard tests.
  ///
  /// ThemeScope goes ABOVE MaterialApp here, not inside `home:`. A pushed
  /// route is a sibling of `home` under the Navigator, so a ThemeScope nested
  /// inside `home` is not an ancestor of it and `ThemeScope.of` asserts. This
  /// mirrors the real app, which wraps MaterialApp at app.dart:575 — get it
  /// wrong and you are testing a tree the app never builds.
  Widget pushHost(GlobalKey<NavigatorState> nav, Widget Function() screen) =>
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorKey: nav,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => screen()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

  Widget gate({
    RecoveryGateMode mode = RecoveryGateMode.setup,
    bool dismissible = false,
    String? knownPassword,
  }) =>
      RecoveryPhraseScreen(
        phrase: phrase,
        mode: mode,
        dismissible: dismissible,
        knownPassword: knownPassword,
        onCommit: (_, _) async {},
      );

  group('show step', () {
    testWidgets('renders all twelve words, numbered', (tester) async {
      roomToBreathe(tester);
      await tester.pumpWidget(host(gate()));

      for (var i = 0; i < 12; i++) {
        expect(find.text('${i + 1}'), findsWidgets, reason: 'index ${i + 1}');
      }
      // Words repeat (12 draws from 2048 with replacement), so assert on the
      // distinct set rather than expecting one widget per word.
      for (final w in phrase.words.toSet()) {
        expect(find.text(w), findsWidgets, reason: w);
      }
    });

    testWidgets('offers copy and the save confirmation', (tester) async {
      roomToBreathe(tester);
      await tester.pumpWidget(host(gate()));

      expect(find.text('COPY'), findsOneWidget);
      expect(find.text('I SAVED THEM'), findsOneWidget);
    });
  });

  group('escape hatches', () {
    testWidgets('setup offers a way back — no account exists yet',
        (tester) async {
      roomToBreathe(tester);
      await tester.pumpWidget(host(gate()));

      expect(find.text('← back'), findsOneWidget);
    });

    testWidgets('a dismissible repair offers "not now"', (tester) async {
      roomToBreathe(tester);
      await tester.pumpWidget(host(gate(
        mode: RecoveryGateMode.repair,
        dismissible: true,
        knownPassword: 'pw',
      )));

      expect(find.text('not now — keep my current phrase'), findsOneWidget);
    });

    testWidgets('a non-dismissible repair offers nothing but the CTA',
        (tester) async {
      roomToBreathe(tester);
      await tester.pumpWidget(host(gate(
        mode: RecoveryGateMode.repair,
        knownPassword: 'pw',
      )));

      expect(find.text('not now — keep my current phrase'), findsNothing);
      expect(find.text('← back'), findsNothing);
      expect(find.text('I SAVED THEM'), findsOneWidget);
    });
  });

  group('pop guard', () {
    // The property the whole feature rests on: a user must not be able to
    // dismiss their way past an un-saved phrase.
    testWidgets('blocks pop when not dismissible', (tester) async {
      roomToBreathe(tester);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(pushHost(nav, () => gate()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryPhraseScreen), findsOneWidget);

      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryPhraseScreen), findsOneWidget,
          reason: 'PopScope should have refused the pop');
    });

    testWidgets('allows pop when dismissible', (tester) async {
      roomToBreathe(tester);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(pushHost(
        nav,
        () => gate(
          mode: RecoveryGateMode.rotate,
          dismissible: true,
          knownPassword: 'pw',
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryPhraseScreen), findsNothing);
    });
  });

  group('saving', () {
    // "I saved them" is taken at face value — there is deliberately no
    // type-the-words-back step. It read as a test, it landed after the user
    // had already done the work, and with the phrase on screen throughout it
    // stopped nobody who wanted to skip.
    testWidgets('asks the user to type nothing back', (tester) async {
      roomToBreathe(tester);
      await tester.pumpWidget(host(gate()));

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('WORD #'), findsNothing);
    });

    testWidgets('setup pops true without touching the network',
        (tester) async {
      roomToBreathe(tester);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(pushHost(nav, () => gate()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('I SAVED THEM'));
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryPhraseScreen), findsNothing);
    });

    testWidgets('repair commits before it pops', (tester) async {
      roomToBreathe(tester);
      var committed = false;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(pushHost(
        nav,
        () => RecoveryPhraseScreen(
          phrase: phrase,
          mode: RecoveryGateMode.repair,
          knownPassword: 'pw',
          onCommit: (password, hash) async {
            committed = true;
            expect(password, 'pw');
            expect(hash, recoveryPhraseHash(phrase.canonical));
          },
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('I SAVED THEM'));
      await tester.pumpAndSettle();

      expect(committed, isTrue);
      expect(find.byType(RecoveryPhraseScreen), findsNothing);
    });

    testWidgets('a failed commit keeps the user here and says why',
        (tester) async {
      roomToBreathe(tester);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(pushHost(
        nav,
        () => RecoveryPhraseScreen(
          phrase: phrase,
          mode: RecoveryGateMode.repair,
          knownPassword: 'pw',
          // The user must never walk away believing a phrase is live when the
          // server rejected it.
          onCommit: (_, _) async => throw Exception('TOO_MANY_ATTEMPTS'),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('I SAVED THEM'));
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryPhraseScreen), findsOneWidget);
      expect(find.textContaining('Too many tries'), findsOneWidget);
    });
  });

  group('password step', () {
    testWidgets('repair without a known password asks for it first',
        (tester) async {
      roomToBreathe(tester);
      await tester.pumpWidget(host(gate(mode: RecoveryGateMode.repair)));

      // The words must not be on screen yet — being told to save twelve words
      // and only then discovering you can't remember your password is the
      // failure this ordering avoids.
      expect(find.text('CONTINUE'), findsOneWidget);
      expect(find.text('I SAVED THEM'), findsNothing);
    });

    testWidgets('a known password skips straight to the words',
        (tester) async {
      roomToBreathe(tester);
      await tester.pumpWidget(host(gate(
        mode: RecoveryGateMode.repair,
        knownPassword: 'pw',
      )));

      expect(find.text('CONTINUE'), findsNothing);
      expect(find.text('I SAVED THEM'), findsOneWidget);
    });
  });
}
