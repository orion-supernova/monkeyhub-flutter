import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_row_swipe.dart';

void main() {
  late List<String> fired;
  late int rowTaps;

  Widget host() => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 390,
                height: 76,
                child: ChatRowSwipe(
                  leading: [
                    SwipeAction(
                      label: 'Pin',
                      icon: Icons.push_pin,
                      color: Colors.orange,
                      onTap: () => fired.add('pin'),
                    ),
                  ],
                  trailing: [
                    SwipeAction(
                      label: 'Mute',
                      icon: Icons.notifications_off,
                      color: Colors.indigo,
                      onTap: () => fired.add('mute'),
                    ),
                    SwipeAction(
                      label: 'Archive',
                      icon: Icons.archive,
                      color: Colors.grey,
                      onTap: () => fired.add('archive'),
                    ),
                  ],
                  child: GestureDetector(
                    onTap: () => rowTaps++,
                    child: const ColoredBox(
                      color: Colors.black,
                      child: SizedBox.expand(child: Text('row')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  setUp(() {
    fired = [];
    rowTaps = 0;
  });

  testWidgets('a short swipe left opens the actions and stays open',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.drag(find.text('row'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Mute'), findsOneWidget);
    expect(fired, isEmpty);
  });

  testWidgets('tapping an open row closes it instead of opening the chat',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.drag(find.text('row'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('row'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(rowTaps, 0);
    expect(find.text('Archive'), findsNothing);

    await tester.tap(find.text('row'));
    expect(rowTaps, 1, reason: 'a closed row opens the chat as usual');
  });

  testWidgets('a revealed button fires its action and closes the row',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.drag(find.text('row'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mute'));
    await tester.pumpAndSettle();
    expect(fired, ['mute']);
    expect(find.text('Mute'), findsNothing);
  });

  testWidgets('a full swipe left fires the outer action, right fires pin',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.drag(find.text('row'), const Offset(-330, 0));
    await tester.pumpAndSettle();
    expect(fired, ['archive']);

    await tester.drag(find.text('row'), const Offset(330, 0));
    await tester.pumpAndSettle();
    expect(fired, ['archive', 'pin']);
  });
}
