import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/glass_pill.dart';
import 'package:monkeyhub/widgets/jump_back.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// The back trail is the only thing standing between a reader and being lost
/// three tethers deep, so its rules are worth pinning down: it must be strictly
/// LIFO (a trail that reorders takes you somewhere you never were), it must not
/// grow without bound, and it must expire on a clock the reader can't see —
/// which is exactly the kind of behaviour that rots silently.
final _epoch = DateTime(2026, 3, 1, 12, 0);

ChatMessage msg(String id, {String? root}) => ChatMessage(
  id: id,
  roomId: 'room',
  senderId: 'alice',
  senderName: 'alice',
  content: id,
  createdAt: _epoch,
  type: MessageType.text,
  status: MessageStatus.sent,
  rootId: root,
);

void main() {
  group('JumpBackStack', () {
    test('walks hops off in the reverse of the order they went on', () {
      final s = JumpBackStack();
      addTearDown(s.dispose);

      expect(s.isEmpty, isTrue);
      expect(s.pop(), isNull);

      s.push(msg('a'));
      s.push(msg('b'));
      s.push(msg('c'));
      expect(s.depth, 3);
      expect(s.top?.id, 'c');
      expect(s.trail.map((m) => m.id), ['a', 'b', 'c']);

      expect(s.pop()?.id, 'c');
      expect(s.pop()?.id, 'b');
      expect(s.pop()?.id, 'a');
      expect(s.isEmpty, isTrue);
      expect(s.pop(), isNull);
    });

    test('a tether tapped twice leaves one hop, not two', () {
      // Two identical hops would need two taps of the back pill to walk off,
      // and the first would appear to do nothing.
      final s = JumpBackStack();
      addTearDown(s.dispose);

      s.push(msg('a'));
      s.push(msg('a'));
      s.push(msg('a'));
      expect(s.depth, 1);

      // Only *consecutive* duplicates collapse — a → b → a is a real path.
      s.push(msg('b'));
      s.push(msg('a'));
      expect(s.trail.map((m) => m.id), ['a', 'b', 'a']);
    });

    test('past maxDepth the oldest hop is dropped, not the newest', () {
      final s = JumpBackStack();
      addTearDown(s.dispose);

      for (var i = 0; i < JumpBackStack.maxDepth + 5; i++) {
        s.push(msg('m$i'));
      }
      expect(s.depth, JumpBackStack.maxDepth);
      // The hop just taken must always be the one the pill goes back to.
      expect(s.top?.id, 'm${JumpBackStack.maxDepth + 4}');
      expect(s.trail.first.id, 'm5');
    });

    test('trail is a copy — a caller cannot reach in and reorder it', () {
      final s = JumpBackStack();
      addTearDown(s.dispose);
      s.push(msg('a'));
      expect(() => s.trail.add(msg('b')), throwsUnsupportedError);
    });

    test('notifies on every change and on nothing else', () {
      final s = JumpBackStack();
      addTearDown(s.dispose);
      var notifications = 0;
      s.addListener(() => notifications++);

      s.push(msg('a'));
      s.push(msg('b'));
      expect(notifications, 2);

      // A deduped push changed nothing, so there is nothing to announce.
      s.push(msg('b'));
      expect(notifications, 2);

      s.pop();
      expect(notifications, 3);

      s.clear();
      expect(notifications, 4);

      // …and clearing an already-empty trail is silent.
      s.clear();
      expect(notifications, 4);
    });

    test('clear empties the trail', () {
      final s = JumpBackStack();
      addTearDown(s.dispose);
      s.push(msg('a'));
      s.push(msg('b'));
      s.clear();
      expect(s.isEmpty, isTrue);
      expect(s.top, isNull);

      // Silence on an already-empty trail is not a nicety: the transcript
      // clears on every arrival at the newest message, and a notification there
      // would rebuild the whole list on an ordinary scroll to the bottom.
      var notifications = 0;
      s.addListener(() => notifications++);
      s.clear();
      expect(notifications, 0);
    });
  });

  // Driven through the test binding's fake clock rather than real delays.
  //
  // Waits are fractions of the shipped window rather than literal seconds: the
  // number is a feel decision that gets retuned, and a suite that has to be
  // edited every time it moves teaches people to edit the suite.
  group('JumpBackStack expiry', () {
    const window = JumpBackStack.defaultIdleTimeout;
    final inside = window * 0.8;
    final past = window * 1.4;

    testWidgets('the default window is short, and it is what you get', (
      tester,
    ) async {
      // Not pinned to an exact value — only to the band that makes the feature
      // work: long enough to be a backstop, short enough that the pill isn't
      // still sitting there minutes after the reader moved on. Scrolling back
      // to the newest message is the main way a trail retires; this only
      // catches a reader who lands and then does nothing at all.
      expect(window, greaterThan(const Duration(seconds: 2)));
      expect(window, lessThanOrEqualTo(const Duration(seconds: 20)));
      expect(JumpBackStack().idleTimeout, window);
    });

    testWidgets('an untouched trail clears itself once the window is up', (
      tester,
    ) async {
      final s = JumpBackStack();
      addTearDown(s.dispose);
      s.push(msg('a'));

      await tester.pump(inside);
      expect(s.isEmpty, isFalse, reason: 'still inside the window');

      await tester.pump(past - inside);
      expect(s.isEmpty, isTrue);
    });

    testWidgets('every jump restarts the window', (tester) async {
      final s = JumpBackStack();
      addTearDown(s.dispose);
      s.push(msg('a'));

      await tester.pump(inside);
      s.push(msg('b'));
      // Well past the window measured from the first push, but not from the
      // second — which is the one that counts.
      await tester.pump(inside);
      expect(s.depth, 2);

      // …and walking one back restarts it again, so a chain can be retraced at
      // tapping speed however deep it goes.
      s.pop();
      await tester.pump(inside);
      expect(s.isEmpty, isFalse);

      await tester.pump(past);
      expect(s.isEmpty, isTrue);
    });

    testWidgets('a deduped push counts as activity too', (tester) async {
      // It announces nothing, but the reader did just tap something.
      final s = JumpBackStack();
      addTearDown(s.dispose);
      s.push(msg('a'));

      await tester.pump(inside);
      s.push(msg('a'));
      await tester.pump(inside);
      expect(s.isEmpty, isFalse);
      // The window is still open, so the timer is still armed — and the binding
      // fails a test that ends with one pending. Cancelling it is what the room
      // does on JUMP TO LATEST, so this is the real path, not a test-only out.
      s.clear();
    });

    testWidgets('walking the trail to empty leaves no timer behind', (
      tester,
    ) async {
      // A timer outliving the trail would fire into a disposed notifier. The
      // binding fails the test on a pending timer, so reaching the end of this
      // one is the assertion.
      final s = JumpBackStack();
      addTearDown(s.dispose);
      s.push(msg('a'));
      s.pop();
      expect(s.isEmpty, isTrue);
    });

    testWidgets('a zero timeout means no expiry at all', (tester) async {
      final s = JumpBackStack(idleTimeout: Duration.zero);
      addTearDown(s.dispose);
      s.push(msg('a'));
      await tester.pump(const Duration(minutes: 10));
      expect(s.isEmpty, isFalse);
    });
  });

  group('JumpBackPill', () {
    Widget host(int depth, {VoidCallback? onTap}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(
          body: Center(
            child: JumpBackPill(depth: depth, onTap: onTap ?? () {}),
          ),
        ),
      ),
    );

    testWidgets('one hop reads plainly, a deeper trail says how deep', (
      tester,
    ) async {
      await tester.pumpWidget(host(1));
      expect(find.text('Back'), findsOneWidget);

      await tester.pumpWidget(host(3));
      expect(find.text('Back · 3'), findsOneWidget);
    });

    testWidgets('never names a mechanism the reader may not have used', (
      tester,
    ) async {
      // This read BACK TO REPLY from when a reply tether was the only way to
      // jump. A pin banner and the shared-content browser's "show in chat" now
      // push onto the same trail, and neither involves a reply — so the label
      // was sending readers to look for one they never tapped.
      await tester.pumpWidget(host(1));
      expect(find.textContaining('REPLY'), findsNothing);
    });

    testWidgets('is the same glass capsule as the pill below it', (
      tester,
    ) async {
      await tester.pumpWidget(host(1));
      expect(find.byType(GlassPill), findsOneWidget);
    });

    testWidgets('a tap fires exactly once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(1, onTap: () => taps++));
      await tester.tap(find.byType(JumpBackPill));
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('TransientPillSlot', () {
    testWidgets('mounts nothing at all while hidden', (tester) async {
      // The gate the back pill borrows from the scroll-to-latest one: a
      // BackdropFilter parked at zero opacity still costs a rasterization pass
      // every frame of every chat.
      Widget host({required bool visible}) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: Center(
              child: TransientPillSlot(
                visible: visible,
                child: JumpBackPill(depth: 1, onTap: () {}),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(host(visible: false));
      expect(find.byType(JumpBackPill), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.pumpWidget(host(visible: true));
      await tester.pumpAndSettle();
      expect(find.byType(JumpBackPill), findsOneWidget);
    });
  });
}
