import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';

/// What this pins: **a sheet's scrolling body pulls the sheet closed.**
///
/// `BottomSheet` only drags from what does not claim the vertical drag — the
/// handle and the bar. A scroll view claims it, so on the point composer the
/// body could only scroll and the sheet could only be closed from a 52pt
/// strip that, with the keyboard up, sat under the Dynamic Island. The user:
/// "I can not close it by swiping down that sheet". `SheetScrollBody` hands
/// the drag past the content's top to the sheet, iOS-style.
///
/// Also pinned here, because it is the same complaint's other half: the
/// sheet's × is the app's one × (the chrome disc), drawn without a backdrop
/// blur so nothing re-rasterises while the sheet rises.
void main() {
  late BuildContext sheetBody;

  Widget host() => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAdaptiveSheet<void>(
                    context,
                    builder: (_) => SheetFrame(
                      title: 'Sheet',
                      child: SheetScrollBody(
                        child: Builder(
                          builder: (context) {
                            sheetBody = context;
                            return Column(
                              children: [
                                for (var i = 0; i < 40; i++)
                                  SizedBox(height: 60, child: Text('row $i')),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsOneWidget);
  }

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(SheetScrollBody),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  testWidgets('scrolled down, a downward drag scrolls back; the sheet stays', (
    tester,
  ) async {
    await open(tester);
    position(tester).jumpTo(200);
    await tester.pump();

    await tester.timedDrag(
      find.text('row 6'),
      const Offset(0, 150),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sheet'), findsOneWidget, reason: 'the sheet stays up');
    // Within the touch slop the recogniser spends before the drag starts.
    expect(position(tester).pixels, closeTo(50, 20));
    expect(SheetDragHost.offsetOf(sheetBody)!.value, 0);
  });

  testWidgets('at the top, a long fast pull closes the sheet', (tester) async {
    await open(tester);
    await tester.fling(find.text('row 2'), const Offset(0, 300), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsNothing);
  });

  testWidgets('at the top, a short slow pull springs back', (tester) async {
    await open(tester);
    final offset = SheetDragHost.offsetOf(sheetBody)!;

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('row 2')),
    );
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(offset.value, greaterThan(0), reason: 'the sheet follows the finger');
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Sheet'), findsOneWidget);
    expect(offset.value, 0);
  });

  testWidgets("the sheet's × carries no backdrop blur", (tester) async {
    await open(tester);
    expect(find.byType(SheetCloseButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SheetCloseButton),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
  });

  testWidgets('the sheet stops 8pt below the top safe area', (tester) async {
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    await open(tester);
    final top = tester.getTopLeft(find.byType(SheetFrame)).dy;
    expect(top, greaterThanOrEqualTo(59 + 8 - 0.5));
  });

  // Any vertical list in a sheet pulls it, not just a SheetScrollBody: the
  // highlight comments list names its own physics and could only scroll,
  // so the sheet closed only from its handle or its ×. The user: "I wanna
  // be able to close the sheet with swiping down from anywhere on that
  // sheet".
  group('a list with its own physics', () {
    Widget hostWith(Widget Function() body) => ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showAdaptiveSheet<void>(
                      context,
                      builder: (_) => SizedBox(
                        height: 600,
                        child: Column(
                          children: [
                            const SheetHandle(),
                            const Text('Sheet'),
                            Expanded(child: body()),
                          ],
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );

    Future<void> openWith(WidgetTester tester, Widget Function() body) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(hostWith(body));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
    }

    List<Widget> rows() => [
          for (var i = 0; i < 40; i++)
            SizedBox(height: 60, child: Text('row $i')),
        ];

    testWidgets('clamping + always-scrollable: a pull closes the sheet', (
      tester,
    ) async {
      await openWith(
        tester,
        () => ListView(
          physics: const ClampingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: rows(),
        ),
      );
      await tester.fling(find.text('row 2'), const Offset(0, 300), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsNothing);
    });

    testWidgets('a short slow pull on it springs back', (tester) async {
      await openWith(
        tester,
        () => ListView(
          physics: const ClampingScrollPhysics(),
          children: rows(),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('row 2')),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 6));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
    });

    testWidgets('reversed (newest at the bottom): pulls from its top end', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await openWith(
        tester,
        () => ListView(
          controller: scroll,
          reverse: true,
          children: rows(),
        ),
      );
      // At rest a reversed list shows its newest rows; a downward drag
      // scrolls back through history and must not move the sheet.
      await tester.timedDrag(
        find.text('row 2'),
        const Offset(0, 150),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
      expect(scroll.position.pixels, greaterThan(0));

      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      await tester.fling(find.text('row 37'), const Offset(0, 300), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsNothing);
    });

    testWidgets('a horizontal strip never pulls', (tester) async {
      await openWith(
        tester,
        () => ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < 20; i++)
              SizedBox(width: 120, child: Text('cell $i')),
          ],
        ),
      );
      await tester.fling(find.text('cell 1'), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
    });
  });
}
