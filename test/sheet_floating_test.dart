import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';

/// What this pins: **the compact sheet floats** (8pt in from the sides, lifted
/// off the bottom to hug the home indicator), **moves on a spring that a drag
/// can take over** (1:1, x0.25 rubber band above rest, closes past 40% of its
/// height, springs back otherwise) and **presents with no animation under
/// calm motion**.
void main() {
  const key = Key('content');
  late BuildContext sheetBody;

  Widget host({bool calm = false}) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: calm),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAdaptiveSheet<void>(
                    context,
                    builder: (ctx) {
                      sheetBody = ctx;
                      return Container(
                        key: key,
                        height: 300,
                        color: Colors.blueGrey,
                      );
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.reset);
  }

  Future<void> open(WidgetTester tester, {bool calm = false}) async {
    phone(tester);
    await tester.pumpWidget(host(calm: calm));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('floats 8pt in from the sides and hugs the home indicator', (
    tester,
  ) async {
    await open(tester);
    final r = tester.getRect(find.byKey(key));
    expect(r.left, 8);
    expect(r.right, 393 - 8);
    // max(8, 34 - 26) = 8 above the bottom edge.
    expect(r.bottom, 852 - 8);
    expect(r.height, 300);
  });

  testWidgets('content sees only the home-indicator inset left over', (
    tester,
  ) async {
    await open(tester);
    expect(MediaQuery.of(sheetBody).padding.bottom, 26);
    expect(MediaQuery.of(sheetBody).padding.top, 0);
  });

  testWidgets('pulled up past rest, it rubber-bands at a quarter', (
    tester,
  ) async {
    await open(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(key)));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, -10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final shown = SheetDragHost.offsetOf(sheetBody)!.value;
    expect(shown, closeTo(-100 * 0.25, 4)); // within the touch slop
    await g.up();
    await tester.pumpAndSettle();
    expect(SheetDragHost.offsetOf(sheetBody)!.value, 0);
  });

  testWidgets('a slow drag past 40% of its height dismisses it', (
    tester,
  ) async {
    await open(tester);
    final g = await tester.startGesture(tester.getCenter(find.byKey(key)));
    for (var i = 0; i < 16; i++) {
      await g.moveBy(const Offset(0, 10)); // 160 > 0.4 * 300
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300)); // finger rests
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(key), findsNothing);
  });

  testWidgets('a small drag springs back to where it floats', (tester) async {
    await open(tester);
    final rest = tester.getRect(find.byKey(key));
    final g = await tester.startGesture(tester.getCenter(find.byKey(key)));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(0, 8)); // ~30 after the slop, < 120
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.getRect(find.byKey(key)).top, greaterThan(rest.top));
    await tester.pump(const Duration(milliseconds: 300));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byKey(key), findsOneWidget);
    expect(tester.getRect(find.byKey(key)), rest);
  });

  testWidgets('a fast flick closes it', (tester) async {
    await open(tester);
    await tester.fling(find.byKey(key), const Offset(0, 60), 1500);
    await tester.pumpAndSettle();
    expect(find.byKey(key), findsNothing);
  });

  testWidgets('presents on a spring: off screen at first, then arrives', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getRect(find.byKey(key)).top, greaterThan(852 - 300));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(key)).bottom, 852 - 8);
  });

  testWidgets('calm motion presents it in place with no animation', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(host(calm: true));
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(tester.getRect(find.byKey(key)).bottom, 852 - 8);
  });
}
