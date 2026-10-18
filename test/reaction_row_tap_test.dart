import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/message_reaction.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/reaction_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this pins: in chat a chip tap opens who-reacted, the same as a
/// long-press, and never adds a reaction behind your back. Moment comments
/// opt out and keep tap-to-toggle.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final reactions = [
    MessageReaction(
      id: 'r1',
      messageId: 'm1',
      userId: 'ada',
      emoji: '😂',
      createdAt: DateTime(2026, 10, 18),
    ),
  ];

  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  testWidgets('a tap opens the reactors instead of toggling', (tester) async {
    final shown = <String>[];
    final toggled = <String>[];
    await tester.pumpWidget(host(ReactionRow(
      reactions: reactions,
      currentUserId: 'me',
      onToggle: toggled.add,
      onShowReactors: shown.add,
    )));
    await tester.tap(find.text('😂'));
    await tester.pumpAndSettle();
    expect(shown, ['😂']);
    expect(toggled, isEmpty);
  });

  testWidgets('tapShowsReactors: false keeps tap-to-toggle', (tester) async {
    final shown = <String>[];
    final toggled = <String>[];
    await tester.pumpWidget(host(ReactionRow(
      reactions: reactions,
      currentUserId: 'me',
      onToggle: toggled.add,
      onShowReactors: shown.add,
      tapShowsReactors: false,
    )));
    await tester.tap(find.text('😂'));
    await tester.pumpAndSettle();
    expect(toggled, ['😂']);
    expect(shown, isEmpty);
  });

  testWidgets('a count change rolls and hops without throwing',
      (tester) async {
    Widget row(List<MessageReaction> r) => host(ReactionRow(
          reactions: r,
          currentUserId: 'me',
          onToggle: (_) {},
        ));
    await tester.pumpWidget(row(reactions));
    await tester.pumpWidget(row([
      ...reactions,
      MessageReaction(
        id: 'r2',
        messageId: 'm1',
        userId: 'me',
        emoji: '😂',
        createdAt: DateTime(2026, 10, 18, 1),
      ),
    ]));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('2'), findsOneWidget);
  });
}
