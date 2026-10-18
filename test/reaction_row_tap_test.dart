import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/message_reaction.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/reaction_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this pins: a chip tap opens who-reacted, the same as a long-press,
/// and never adds a reaction behind your back.
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

  testWidgets('with nowhere to show reactors, a tap still toggles',
      (tester) async {
    final toggled = <String>[];
    await tester.pumpWidget(host(ReactionRow(
      reactions: reactions,
      currentUserId: 'me',
      onToggle: toggled.add,
    )));
    await tester.tap(find.text('😂'));
    await tester.pumpAndSettle();
    expect(toggled, ['😂']);
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
