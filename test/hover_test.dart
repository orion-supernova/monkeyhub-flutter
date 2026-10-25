import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/keyboard/app_shortcuts.dart';
import 'package:monkeyhub/keyboard/focusable_tap.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/density.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/hover_hint.dart';
import 'package:monkeyhub/widgets/ios_kit.dart';

/// The pointer-polish primitives: hover owned by FocusableTap, the gentler
/// mouse press of SpringPress, HoverHint, and the desktop density.
///
/// What matters most is what must NOT happen: no hover layer, controller or
/// rebuild for a control no mouse has touched (every tappable on a phone),
/// and no hint at all on a touch platform.
void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  // FocusableActionDetector only reports hover in the "traditional"
  // highlight mode, which is the default on a desktop OS and never on a
  // phone. These tests are about desktop, so they run as macOS.
  void testDesktop(String name, WidgetTesterCallback body) =>
      testWidgets(name, (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

  Future<TestGesture> mouseOver(WidgetTester tester, Finder f) async {
    final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await g.addPointer(location: Offset.zero);
    addTearDown(g.removePointer);
    await g.moveTo(tester.getCenter(f));
    await tester.pump();
    return g;
  }

  Finder hoverLayer(Finder of) => find.descendant(
        of: of,
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter != null &&
              w.painter.runtimeType.toString() == '_HoverPainter',
        ),
      );

  testDesktop('no hover layer until a mouse arrives, then a fade',
      (tester) async {
    await tester.pumpWidget(host(FocusableTap(
      onTap: () {},
      hover: HoverEffect.tint,
      child: const SizedBox(key: Key('t'), width: 100, height: 40),
    )));
    final tap = find.byType(FocusableTap);
    expect(hoverLayer(tap), findsNothing);

    final g = await mouseOver(tester, find.byKey(const Key('t')));
    await tester.pump(kHoverFade);
    expect(hoverLayer(tap), findsOneWidget);

    // Leaving fades it out but keeps the (cheap) layer for the next visit.
    await g.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(hoverLayer(tap), findsOneWidget);
  });

  testDesktop('HoverEffect.none never mounts a layer', (tester) async {
    await tester.pumpWidget(host(FocusableTap(
      onTap: () {},
      child: const SizedBox(key: Key('t'), width: 100, height: 40),
    )));
    await mouseOver(tester, find.byKey(const Key('t')));
    await tester.pump(kHoverFade);
    expect(hoverLayer(find.byType(FocusableTap)), findsNothing);
  });

  testDesktop('stateBuilder hears hover', (tester) async {
    bool? seen;
    await tester.pumpWidget(host(SpringPress(
      onTap: () {},
      stateBuilder: (context, pressed, hovered) {
        seen = hovered;
        return const SizedBox(key: Key('t'), width: 60, height: 60);
      },
    )));
    expect(seen, isFalse);
    await mouseOver(tester, find.byKey(const Key('t')));
    expect(seen, isTrue);
  });

  testWidgets('a mouse press dips a quarter as deep as a finger',
      (tester) async {
    // SpringPress now drives its own spring: read where the press has got to
    // after the 90ms dip has played out (the first frame only starts its clock).
    Future<double> target() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      return tester
          .widget<Transform>(find.ancestor(
              of: find.byKey(const Key('t')), matching: find.byType(Transform)))
          .transform
          .storage[0];
    }
    await tester.pumpWidget(host(SpringPress(
      onTap: () {},
      haptic: false,
      scale: PressSpec.scaleSmall,
      child: const SizedBox(key: Key('t'), width: 60, height: 60),
    )));
    final center = tester.getCenter(find.byKey(const Key('t')));

    final finger = await tester.startGesture(center);
    expect(await target(), closeTo(PressSpec.scaleSmall, 1e-3));
    await finger.up();
    await tester.pumpAndSettle();

    final mouse =
        await tester.startGesture(center, kind: PointerDeviceKind.mouse);
    expect(await target(), closeTo(0.98, 1e-3));
    await mouse.up();
    await tester.pumpAndSettle();
  });

  group('HoverHint', () {
    testWidgets('is inert on a touch platform', (tester) async {
      await tester.pumpWidget(host(const HoverHint(
        label: 'Back',
        child: SizedBox(key: Key('t'), width: 40, height: 40),
      )));
      expect(find.byType(OverlayPortal), findsNothing);
    });

    testDesktop('shows after the delay with keys, and a press dismisses it',
        (tester) async {
      await tester.pumpWidget(host(GlassBackButton(onTap: null)));
      final g = await mouseOver(tester, find.byType(GlassBackButton));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HintBubble), findsNothing);
      await tester.pump(HoverHint.delay);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(HintBubble), findsOneWidget);
      // The default pop is what Esc does, so the back button says so.
      expect(find.text('Esc'), findsOneWidget);

      // Bubble sits below the button, inside the window.
      final button = tester.getRect(find.byType(GlassBackButton));
      final bubble = tester.getRect(find.byType(HintBubble));
      expect(bubble.top, greaterThan(button.bottom));

      await g.down(tester.getCenter(find.byType(GlassBackButton)));
      await tester.pump();
      expect(find.byType(HintBubble), findsNothing);
      await g.up();
      await tester.pumpAndSettle();
    });

    testDesktop('a custom onTap shows no keys unless told', (tester) async {
      await tester.pumpWidget(host(GlassIconButton(
        icon: Icons.add,
        onTap: () {},
        semanticLabel: 'New chat',
        shortcut: AppShortcuts.newChat,
      )));
      await mouseOver(tester, find.byType(GlassIconButton));
      await tester.pump(HoverHint.delay);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('New chat'), findsOneWidget);
      expect(find.text('⌘'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
    });
  });

  group('Density', () {
    testWidgets('phone rows and buttons keep their sizes', (tester) async {
      await tester.pumpWidget(host(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GroupedRow(title: 'Row', icon: Icons.add, onTap: () {}),
          GlassCloseButton(onTap: () {}, still: true),
        ],
      )));
      expect(Density.of(tester.element(find.byType(GroupedRow))).compact,
          isFalse);
      expect(tester.getSize(find.byType(GroupedRow)).height,
          kGroupedRowMinHeight);
      expect(tester.getSize(find.byType(ChromeDisc)), const Size(44, 44));
    });

    testDesktop('desktop is compact by default', (tester) async {
      await tester.pumpWidget(host(DensityScope(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GroupedRow(title: 'Row', icon: Icons.add, onTap: () {}),
            GlassCloseButton(onTap: () {}, still: true),
            // An explicit size is the caller's, density or not.
            GlassIconButton(
              icon: Icons.add,
              onTap: () {},
              size: 44,
              still: true,
            ),
          ],
        ),
      )));
      expect(tester.getSize(find.byType(GroupedRow)).height, 40);
      expect(tester.getSize(find.byType(ChromeDisc).first), const Size(32, 32));
      expect(tester.getSize(find.byType(ChromeDisc).last), const Size(44, 44));
    });
  });
}
