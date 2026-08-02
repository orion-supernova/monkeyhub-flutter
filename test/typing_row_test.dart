import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/typing_indicator.dart';
import 'package:monkeyhub/widgets/user_avatar.dart';

/// The typing row is a permanent item at the bottom of the transcript rather
/// than a conditional one, so an idle room depends on it collapsing to nothing
/// on its own. It also has to line up with the message rows above it: same
/// avatar width, same gap. Both are load-bearing and neither is visible from
/// the call site.
void main() {
  Widget host(Widget child, {double width = 400}) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );

  ChatUser user(String name) => ChatUser(id: name, username: name, name: name);

  testWidgets('an idle room gives the row no height at all', (tester) async {
    await tester.pumpWidget(host(const TypingRow(typists: [])));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(TypingRow)).height, 0);
  });

  testWidgets('one typist puts the bubble a message-avatar in from the edge', (
    tester,
  ) async {
    await tester.pumpWidget(host(TypingRow(typists: [user('mom')])));
    await tester.pump();

    expect(find.byType(TypingDots), findsOneWidget);
    // 28 avatar + 8 gap — the same leading indent MessageBubble reserves, so
    // the dots start exactly where the next incoming bubble will.
    final dots = tester.getTopLeft(find.byType(TypingDots));
    expect(dots.dx, greaterThan(36));
    expect(tester.getSize(find.byType(TypingRow)).height, greaterThan(0));
  });

  testWidgets('a DM drops the avatar and starts at the left edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(TypingRow(typists: [user('mom')], showAvatars: false)),
    );
    await tester.pump();

    expect(tester.getTopLeft(find.byType(TypingDots)).dx, lessThan(36));
  });

  testWidgets('stacked avatars stay inside the slot they are given', (
    tester,
  ) async {
    // The separator ring used to be a border, which grew each avatar to 31px
    // inside a 28px slot — the Stack then clipped every circle flat, top and
    // bottom, and shaved the rightmost one.
    await tester.pumpWidget(
      host(TypingRow(typists: [user('mom'), user('dad'), user('kid')])),
    );
    await tester.pump();

    final avatars = find.byType(UserAvatar);
    expect(avatars, findsNWidgets(3));
    final slot = tester.getRect(
      find.ancestor(of: avatars.first, matching: find.byType(SizedBox)).first,
    );
    expect(slot.height, 28);
    for (var i = 0; i < 3; i++) {
      final a = tester.getRect(avatars.at(i));
      expect(a.top, greaterThanOrEqualTo(slot.top));
      expect(a.bottom, lessThanOrEqualTo(slot.bottom));
      expect(a.right, lessThanOrEqualTo(slot.right));
    }
  });

  testWidgets('a lone typist gets the full avatar, no separator ring', (
    tester,
  ) async {
    await tester.pumpWidget(host(TypingRow(typists: [user('mom')])));
    await tester.pump();

    // Identical to the avatar on that person's messages — no inset.
    expect(tester.getSize(find.byType(UserAvatar)).height, 28);
  });

  testWidgets('avatars stay real through the fade-out', (tester) async {
    await tester.pumpWidget(host(TypingRow(typists: [user('mom')])));
    await tester.pump();
    final typing = tester.getSize(find.byType(TypingRow)).height;

    // Everyone stopped: the row must not blank its content mid-animation, it
    // has to keep rendering the retained set until it has finished leaving.
    await tester.pumpWidget(host(const TypingRow(typists: [])));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(TypingDots), findsOneWidget);
    expect(tester.getSize(find.byType(TypingRow)).height, typing);

    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(TypingRow)).height, 0);
  });
}
