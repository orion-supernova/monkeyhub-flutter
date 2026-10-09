import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/ui_selection_store.dart';
import 'package:monkeyhub/keyboard/escape_to_pop.dart';
import 'package:monkeyhub/screens/navigation/list_detail_split.dart';
import 'package:monkeyhub/screens/navigation/room_side_pane.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/desktop_scroll.dart';

void main() {
  group('split shell predicate', () {
    test('touch platforms split only at expanded', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(Breakpoints.splitShellFor(599), isFalse);
      expect(Breakpoints.splitShellFor(800), isFalse);
      expect(Breakpoints.splitShellFor(1023), isFalse);
      expect(Breakpoints.splitShellFor(1024), isTrue);
      debugDefaultTargetPlatformOverride = null;
    });

    test('desktops split from Breakpoints.split', () {
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = p;
        expect(Breakpoints.splitShellFor(599), isFalse, reason: '$p');
        expect(Breakpoints.splitShellFor(719), isFalse, reason: '$p');
        expect(Breakpoints.splitShellFor(720), isTrue, reason: '$p');
        expect(Breakpoints.splitShellFor(1400), isTrue, reason: '$p');
      }
      debugDefaultTargetPlatformOverride = null;
    });

    test('the native window floors sit above the split breakpoint', () {
      // MainFlutterWindow.swift, win32_window.cpp and my_application.cc all
      // floor the window at 760: a desktop app must never see the phone shell.
      expect(760, greaterThanOrEqualTo(Breakpoints.split));
    });
  });

  group('ListDetailSplit.resolve', () {
    double r(double? p, double a, {bool expanded = true}) =>
        ListDetailSplit.resolve(preferred: p, available: a, expanded: expanded);

    test('defaults by class', () {
      expect(r(null, 1400), ListDetailSplit.defaultExpanded);
      expect(r(null, 900, expanded: false), ListDetailSplit.defaultMedium);
    });

    test('clamps a preference into range', () {
      expect(r(100, 1400), ListDetailSplit.minWidth);
      expect(r(900, 1400), ListDetailSplit.maxWidth);
      expect(r(400, 1400), 400);
    });

    test('the list gives way before the detail drops under minDetail', () {
      // 676 = a 760 window minus the rail.
      expect(r(440, 676), 676 - ListDetailSplit.minDetail);
      // Never under the list's own floor, however narrow.
      expect(r(440, 500), ListDetailSplit.minWidth);
    });
  });

  group('ListDetailSplit drag', () {
    testWidgets('drag resizes, double-click resets', (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final master = GlobalKey();
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LayoutScope(
              windowClass: WindowClass.expanded,
              width: 1400,
              child: ListDetailSplit(
                resizable: true,
                master: SizedBox.expand(key: master),
                detail: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      final start = tester.getSize(find.byKey(master)).width;
      expect(start, ListDetailSplit.defaultExpanded);

      // The handle straddles the hairline at x = width.
      await tester.dragFrom(Offset(start + 1, 400), const Offset(60, 0));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(master)).width, closeTo(start + 60, 20));

      await tester.dragFrom(
        Offset(tester.getSize(find.byKey(master)).width + 1, 400),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(master)).width, ListDetailSplit.maxWidth);

      final x = ListDetailSplit.maxWidth + 1;
      await tester.tapAt(Offset(x, 400));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(Offset(x, 400));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(master)).width,
          ListDetailSplit.defaultExpanded);
    });
  });

  group('RoomSidePane', () {
    late GlobalKey<NavigatorState> nav;
    late GlobalKey chat;

    Widget harness({String? roomId = 'a', double width = 1400}) => ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            navigatorKey: nav,
            builder: (_, child) => EscapeToPop(navigatorKey: nav, child: child!),
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 800,
                child: RoomSidePane(
                  roomId: roomId,
                  child: SizedBox.expand(key: chat),
                ),
              ),
            ),
          ),
        );

    Widget page(String label, {bool leave = false}) => Material(
          child: Builder(
            builder: (context) => Column(
              children: [
                Text(label),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop('jump'),
                  child: const Text('show in chat'),
                ),
                GestureDetector(
                  onTap: () {
                    // Room info's Leave: itself, then the room under it.
                    Navigator.of(context).pop();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('leave'),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const Material(child: Text('members')),
                  )),
                  child: const Text('push'),
                ),
              ],
            ),
          ),
        );

    RoomSidePaneState pane() => RoomSidePane.maybeOf(chat.currentContext!)!;

    setUp(() {
      nav = GlobalKey<NavigatorState>();
      chat = GlobalKey();
    });

    Future<void> sized(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('docks beside a wide chat and returns the page result',
        (tester) async {
      await sized(tester);
      await tester.pumpWidget(harness());
      expect(tester.getSize(find.byKey(chat)).width, 1400);

      final result = pane().open<String>((_) => page('info'), tag: 'info');
      await tester.pumpAndSettle();
      expect(find.text('info'), findsOneWidget);
      expect(tester.getSize(find.byKey(chat)).width, 1400 - RoomSidePane.width);

      await tester.tap(find.text('show in chat'));
      await tester.pumpAndSettle();
      expect(await result, 'jump');
      expect(find.text('info'), findsNothing);
      expect(pane().isOpen, isFalse);
      expect(tester.getSize(find.byKey(chat)).width, 1400);
    });

    testWidgets('floats over a narrow chat instead of crushing it',
        (tester) async {
      await sized(tester);
      await tester.pumpWidget(harness(width: 700));
      pane().open<void>((_) => page('info'));
      await tester.pumpAndSettle();
      expect(find.text('info'), findsOneWidget);
      expect(tester.getSize(find.byKey(chat)).width, 700);
    });

    testWidgets('pushes from inside stay inside the pane', (tester) async {
      await sized(tester);
      await tester.pumpWidget(harness());
      pane().open<void>((_) => page('info'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('push'));
      await tester.pumpAndSettle();
      expect(find.text('members'), findsOneWidget);
      // Still beside the chat, not over the window.
      expect(tester.getTopLeft(find.text('members')).dx,
          greaterThanOrEqualTo(1400 - RoomSidePane.width));
      expect(nav.currentState!.canPop(), isFalse);

      // Back out of members: the pane stays open on info.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('members'), findsNothing);
      expect(find.text('info'), findsOneWidget);
      expect(pane().isOpen, isTrue);
    });

    testWidgets('Esc closes it', (tester) async {
      await sized(tester);
      await tester.pumpWidget(harness());
      final result = pane().open<String>((_) => page('info'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await result, isNull);
      expect(find.text('info'), findsNothing);
      expect(pane().isOpen, isFalse);
    });

    testWidgets('the same tag toggles it shut', (tester) async {
      await sized(tester);
      await tester.pumpWidget(harness());
      pane().open<void>((_) => page('info'), tag: 'info');
      await tester.pumpAndSettle();
      pane().open<void>((_) => page('info'), tag: 'info');
      await tester.pumpAndSettle();
      expect(find.text('info'), findsNothing);

      // A different tag replaces instead.
      pane().open<void>((_) => page('info'), tag: 'info');
      await tester.pumpAndSettle();
      pane().open<void>((_) => page('profile'), tag: 'profile:x');
      await tester.pumpAndSettle();
      expect(find.text('info'), findsNothing);
      expect(find.text('profile'), findsOneWidget);
    });

    testWidgets('switching rooms closes it', (tester) async {
      await sized(tester);
      await tester.pumpWidget(harness());
      pane().open<void>((_) => page('info'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(roomId: 'b'));
      await tester.pump();
      expect(find.text('info'), findsNothing);
      expect(tester.getSize(find.byKey(chat)).width, 1400);
    });

    testWidgets("leave's second pop closes the room too", (tester) async {
      await sized(tester);
      UiSelectionStore.instance.selectRoom('a');
      addTearDown(() => UiSelectionStore.instance.selectRoom(null));
      await tester.pumpWidget(harness());
      pane().open<void>((_) => page('info'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('leave'));
      await tester.pumpAndSettle();
      expect(UiSelectionStore.instance.roomId, isNull);
      expect(find.text('info'), findsNothing);
    });
  });

  group('HorizontalWheelScroll', () {
    testWidgets('a vertical wheel scrolls the strip, then the page',
        (tester) async {
      final page = ScrollController();
      final strip = ScrollController();
      addTearDown(page.dispose);
      addTearDown(strip.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ListView(
            controller: page,
            children: [
              SizedBox(
                height: 100,
                child: HorizontalWheelScroll(
                  child: ListView(
                    controller: strip,
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < 20; i++)
                        const SizedBox(width: 100),
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < 20; i++) const SizedBox(height: 100),
            ],
          ),
        ),
      );

      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      mouse.hover(const Offset(50, 50));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(strip.offset, 120);
      expect(page.offset, 0);

      // At the end of the strip the wheel goes back to the page.
      strip.jumpTo(strip.position.maxScrollExtent);
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(page.offset, 120);
    });

    testWidgets('a wheel over plain page content is untouched',
        (tester) async {
      final page = ScrollController();
      addTearDown(page.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: HorizontalWheelScroll(
            child: ListView(
              controller: page,
              children: [
                for (var i = 0; i < 20; i++) const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      );
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      mouse.hover(const Offset(50, 50));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(page.offset, 120);
    });
  });
}
