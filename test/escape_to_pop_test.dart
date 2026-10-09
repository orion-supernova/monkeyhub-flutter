import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/keyboard/escape_to_pop.dart';
import 'package:monkeyhub/keyboard/viewer_keys.dart';

void main() {
  Widget app(GlobalKey<NavigatorState> nav) => MaterialApp(
        navigatorKey: nav,
        builder: (_, child) => EscapeToPop(navigatorKey: nav, child: child!),
        home: const Text('home'),
      );

  PageRouteBuilder<Object?> page(Widget child) => PageRouteBuilder<Object?>(
        opaque: false,
        pageBuilder: (_, _, _) => child,
      );

  testWidgets('Esc pops a full-screen PageRouteBuilder', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(nav));
    nav.currentState!.push(page(const Text('viewer')));
    await tester.pumpAndSettle();
    expect(find.text('viewer'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('viewer'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Esc on the root route does nothing', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(nav));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Esc respects PopScope', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    var asked = 0;
    await tester.pumpWidget(app(nav));
    nav.currentState!.push(page(PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) => asked++,
      child: const Text('guarded'),
    )));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('guarded'), findsOneWidget);
    expect(asked, 1);
  });

  testWidgets('Esc reaches a PopScope on the bottom route', (tester) async {
    // The wide shell's open chat: nowhere to pop to, but back still means
    // "close the chat".
    final nav = GlobalKey<NavigatorState>();
    var asked = 0;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      builder: (_, child) => EscapeToPop(navigatorKey: nav, child: child!),
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, _) => asked++,
        child: const Focus(autofocus: true, child: Text('shell')),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(asked, 1);
  });

  testWidgets('a dialog keeps its own Esc', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(nav));
    nav.currentState!.push(page(const Text('page')));
    await tester.pumpAndSettle();
    showDialog<void>(
      context: nav.currentContext!,
      builder: (_) => const Text('dialog'),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsNothing);
    // One Esc, one level: the page under the dialog is still there.
    expect(find.text('page'), findsOneWidget);
  });

  testWidgets('ViewerKeys routes Esc to its own close and arrows to steps',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final log = <String>[];
    await tester.pumpWidget(app(nav));
    nav.currentState!.push(page(ViewerKeys(
      onClose: () => log.add('close'),
      onPrevious: () => log.add('prev'),
      onNext: () => log.add('next'),
      child: const Text('pager'),
    )));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(log, ['next', 'prev', 'close']);
    // Its own close ran instead of the generic pop.
    expect(find.text('pager'), findsOneWidget);
  });
}
