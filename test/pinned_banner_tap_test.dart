import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/room_pin.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/pinned_banner.dart';

/// [FocusableTap] registers NO gesture recognizer of its own — it adds the
/// focus node, the Enter/Space binding and the semantics, and nothing else. So
/// every tappable in this app is a `FocusableTap` wrapping a bare
/// `GestureDetector`, with BOTH carrying the handler. Wrapping alone produces a
/// control that looks correct and does nothing on tap.
///
/// That mistake has shipped here twice; `connection_banner_tap_test.dart` and
/// `call_controls_tap_test.dart` exist to stop it recurring, and this is the
/// pin banner's copy.
///
/// It also pins the two things the banner's contract promises its call site:
/// zero height with no pins (so the room layout can hold it unconditionally,
/// the same deal [GroupCallBanner] offers), and that the trailing list button
/// does not also fire the row's jump.
void main() {
  ChatMessage msg(String id, String content) => ChatMessage(
    id: id,
    roomId: 'r',
    senderId: 'alice',
    senderName: 'alice',
    content: content,
    createdAt: DateTime(2026, 3, 1, 12),
    type: MessageType.text,
  );

  RoomPin pin(String id, String content) => RoomPin(
    message: msg(id, content),
    pinnedAt: DateTime(2026, 3, 1, 13),
    pinnedBy: 'bob',
  );

  Widget host(Widget child) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 500, child: child),
        ),
      ),
    ),
  );

  testWidgets('tapping the row fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        PinnedMessageBanner(
          pins: [pin('m1', 'deploy at 4pm')],
          activeIndex: 0,
          onTap: () => taps++,
          onOpenList: () {},
        ),
      ),
    );
    // Past the AnimatedSize/AnimatedSwitcher entrance before touching anything.
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('alice  deploy at 4pm'));
    await tester.pump();

    expect(taps, 1, reason: 'FocusableTap alone registers no recognizer');
  });

  testWidgets('tapping the list button opens the list, and does not jump', (
    tester,
  ) async {
    var taps = 0;
    var opens = 0;
    await tester.pumpWidget(
      host(
        PinnedMessageBanner(
          pins: [pin('m1', 'a'), pin('m2', 'b')],
          activeIndex: 0,
          onTap: () => taps++,
          onOpenList: () => opens++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(CupertinoIcons.list_bullet));
    await tester.pump();

    expect(opens, 1);
    expect(taps, 0, reason: 'the button must win the hit test over the row');
  });

  testWidgets('renders no ink', (tester) async {
    await tester.pumpWidget(
      host(
        PinnedMessageBanner(
          pins: [pin('m1', 'a')],
          activeIndex: 0,
          onTap: () {},
          onOpenList: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(InkResponse), findsNothing);
  });

  testWidgets('collapses to zero height with no pins', (tester) async {
    await tester.pumpWidget(
      host(
        PinnedMessageBanner(
          pins: const [],
          activeIndex: 0,
          onTap: () {},
          onOpenList: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.getSize(find.byType(PinnedMessageBanner)).height,
      0,
      reason: 'the room layout holds this unconditionally',
    );
  });

  testWidgets('a stale cursor past the end renders rather than throwing', (
    tester,
  ) async {
    // Two pins expired between subscription frames; the cursor has not caught
    // up yet. The strip clamps on read.
    await tester.pumpWidget(
      host(
        PinnedMessageBanner(
          pins: [pin('m1', 'survivor')],
          activeIndex: 4,
          onTap: () {},
          onOpenList: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('alice  survivor'), findsOneWidget);
  });

  testWidgets('the position counter only appears with more than one pin', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PinnedMessageBanner(
          pins: [pin('m1', 'a')],
          activeIndex: 0,
          onTap: () {},
          onOpenList: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pinned message'), findsOneWidget);

    await tester.pumpWidget(
      host(
        PinnedMessageBanner(
          pins: [pin('m1', 'a'), pin('m2', 'b'), pin('m3', 'c')],
          activeIndex: 1,
          onTap: () {},
          onOpenList: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pinned message  2/3'), findsOneWidget);
  });
}
