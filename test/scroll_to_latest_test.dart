import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/glass_reveal.dart';
import 'package:monkeyhub/widgets/scroll_to_latest.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// The scroll-to-latest pill sits over a live transcript that is scrolling,
/// paginating and receiving messages at once, so both of its moving parts are
/// worth pinning down:
///
///  * [BottomProximity] runs on every scroll frame. Its hysteresis is what
///    stops the pill strobing when a reader parks on the threshold or an iOS
///    rubber-band settle crosses it several times in one gesture.
///  * [ScrollToLatestSlot] must render *nothing* while hidden — the pill is a
///    BackdropFilter, and one parked at zero opacity would still cost a
///    backdrop rasterization pass every frame of every chat.
void main() {
  group('BottomProximity', () {
    test('a transcript that does not fill its viewport is never "away"', () {
      final p = BottomProximity();
      addTearDown(p.dispose);

      // Pre-layout: both metrics zero.
      p.updateMetrics(pixels: 0, maxScrollExtent: 0);
      expect(p.value, isFalse);

      // A short thread. Even a nonsense offset can't make it scrolled-up.
      p.updateMetrics(pixels: 900, maxScrollExtent: 0);
      expect(p.value, isFalse);
    });

    test('shows past showAbove and stays shown until hideBelow', () {
      final p = BottomProximity();
      addTearDown(p.dispose);

      p.updateMetrics(pixels: 0, maxScrollExtent: 5000);
      expect(p.value, isFalse);

      // Just short of the trigger.
      p.updateMetrics(pixels: BottomProximity.showAbove, maxScrollExtent: 5000);
      expect(p.value, isFalse);

      p.updateMetrics(
        pixels: BottomProximity.showAbove + 1,
        maxScrollExtent: 5000,
      );
      expect(p.value, isTrue);

      // The hysteresis band: back below the show threshold, still shown.
      p.updateMetrics(pixels: 150, maxScrollExtent: 5000);
      expect(p.value, isTrue);
      p.updateMetrics(pixels: BottomProximity.hideBelow, maxScrollExtent: 5000);
      expect(p.value, isFalse);
    });

    test('iOS overscroll past the newest message reads as at-the-bottom', () {
      final p = BottomProximity();
      addTearDown(p.dispose);

      p.updateMetrics(pixels: 800, maxScrollExtent: 5000);
      expect(p.value, isTrue);

      // Bouncing beyond index 0 in a reverse list.
      p.updateMetrics(pixels: -120, maxScrollExtent: 5000);
      expect(p.value, isFalse);
    });

    test('notifies on transitions only, not on every scroll frame', () {
      final p = BottomProximity();
      addTearDown(p.dispose);
      var notifications = 0;
      p.addListener(() => notifications++);

      // A drag up through the threshold and onwards: one transition.
      for (final px in [0.0, 100.0, 241.0, 400.0, 900.0, 4000.0]) {
        p.updateMetrics(pixels: px, maxScrollExtent: 5000);
      }
      expect(notifications, 1);

      // …and back down through it: one more.
      for (final px in [3000.0, 400.0, 200.0, 95.0, 0.0]) {
        p.updateMetrics(pixels: px, maxScrollExtent: 5000);
      }
      expect(notifications, 2);
    });
  });

  group('ScrollToLatestSlot', () {
    // MaterialApp and Scaffold bring their own FadeTransitions and
    // IgnorePointers, so every structural finder here is scoped to the slot.
    Finder inSlot(Type type) => find.descendant(
      of: find.byType(ScrollToLatestSlot),
      matching: find.byType(type),
    );

    Widget host({required bool visible, VoidCallback? onTap}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(
          body: Center(
            child: ScrollToLatestSlot(visible: visible, onTap: onTap ?? () {}),
          ),
        ),
      ),
    );

    testWidgets('mounts nothing at all while hidden', (tester) async {
      await tester.pumpWidget(host(visible: false));
      expect(find.byType(ScrollToLatestPill), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('opens without waiting to be animated in', (tester) async {
      // A slot built already-visible (re-entering a room scrolled up) must not
      // grow in from nothing.
      await tester.pumpWidget(host(visible: true));
      expect(find.byType(ScrollToLatestPill), findsOneWidget);
      expect(tester.widget<GlassReveal>(inSlot(GlassReveal)).t, 1);
    });

    testWidgets('stays mounted while animating out, then unmounts', (
      tester,
    ) async {
      await tester.pumpWidget(host(visible: true));
      await tester.pumpWidget(host(visible: false));

      // Mid-fade: still painted, but no longer hit-testable — a tap landing on
      // something visibly leaving is a misfire.
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(ScrollToLatestPill), findsOneWidget);
      expect(
        tester.widget<IgnorePointer>(inSlot(IgnorePointer).first).ignoring,
        isTrue,
      );

      await tester.pumpAndSettle();
      expect(find.byType(ScrollToLatestPill), findsNothing);
    });

    testWidgets('a tap on the visible pill fires exactly once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(visible: true, onTap: () => taps++));
      await tester.tap(find.byType(ScrollToLatestPill));
      await tester.pump();
      // FocusableTap wraps the GestureDetector but registers no recognizer of
      // its own; if that ever changes this catches the double-fire.
      expect(taps, 1);
    });
  });
}
