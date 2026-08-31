import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/widgets/message_departures.dart';

/// The departures ledger: what keeps a Chamber of Secrets row in the list
/// while its exit plays, and what rasters the bubble for it.
void main() {
  final born = DateTime(2026, 3, 1, 12);

  ChatMessage msg(String id, {int minute = 0, bool ephemeral = true}) =>
      ChatMessage(
        id: id,
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: 'm $id',
        createdAt: born.add(Duration(minutes: minute)),
        expiresAt: ephemeral ? born.add(Duration(minutes: minute + 10)) : null,
        type: MessageType.text,
        status: MessageStatus.sent,
      );

  const outline = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  /// A row with a capturable bubble in it, under the ledger's keys.
  Widget host(MessageDepartures ledger, String rowKey) {
    final rowBox = GlobalKey();
    ledger.registerRowBox(rowKey, rowBox);
    return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              KeyedSubtree(
                key: rowBox,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, left: 8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: RepaintBoundary(
                      key: ledger.anchorKeyFor(rowKey),
                      child: const SizedBox(
                        width: 120,
                        height: 40,
                        child: ColoredBox(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  test('withGhosts hands back the very same list while nothing departs', () {
    final ledger = MessageDepartures(onChanged: () {});
    addTearDown(ledger.dispose);
    final timeline = [msg('a'), msg('b', minute: 1)];
    expect(identical(ledger.withGhosts(timeline), timeline), isTrue);
  });

  testWidgets('a clock expiry rasters the bubble after the frame', (
    tester,
  ) async {
    var changes = 0;
    final ledger = MessageDepartures(onChanged: () => changes++);
    addTearDown(ledger.dispose);
    await tester.pumpWidget(host(ledger, 'k'));

    ledger.requestLocalDeparture('k', msg('a'), isMine: true, outline: outline);
    // Twice on the same tick is one capture.
    ledger.requestLocalDeparture('k', msg('a'), isMine: true, outline: outline);
    expect(ledger.isDeparting('k'), isFalse, reason: 'not until the frame ends');
    await tester.pump();

    expect(ledger.isDeparting('k'), isTrue);
    expect(changes, 1);
    final cap = ledger.captureFor('k')!;
    expect(cap.image, isNotNull);
    expect(cap.bubbleSize, const Size(120, 40));
    expect(cap.rowSize.height, 50, reason: 'the row is the bubble plus its gap');
    expect(cap.bubbleInRow, const Offset(8, 10));
    expect(cap.isMine, isTrue);
    expect(cap.outline.contains(const Offset(60, 20)), isTrue);
    expect(cap.outline.contains(const Offset(0.5, 0.5)), isFalse,
        reason: 'the corner is outside the rounded outline');

    // A later request for the same row changes nothing.
    ledger.requestLocalDeparture('k', msg('a'), isMine: true, outline: outline);
    await tester.pump();
    expect(changes, 1);
  });

  testWidgets('a row still on its optimistic id never departs', (tester) async {
    final ledger = MessageDepartures(onChanged: () {});
    addTearDown(ledger.dispose);
    await tester.pumpWidget(host(ledger, 'tmp_1'));
    ledger.requestLocalDeparture('tmp_1', msg('tmp_1'),
        isMine: true, outline: outline);
    await tester.pump();
    expect(ledger.isDeparting('tmp_1'), isFalse);
  });

  testWidgets('a message that has blown away stays away until the server '
      'drops it', (tester) async {
    final ledger = MessageDepartures(onChanged: () {});
    addTearDown(ledger.dispose);
    await tester.pumpWidget(host(ledger, 'a'));
    final live = [msg('a'), msg('b', minute: 1)];
    ledger.requestLocalDeparture('a', msg('a'),
        isMine: false, outline: outline);
    await tester.pump();
    expect(ledger.isDeparting('a'), isTrue);
    ledger.end('a');
    expect(ledger.hasDeparted('a'), isTrue);
    // The server still lists it — the delete is a round trip away — so the
    // row stays hidden rather than coming back as an expired bubble that
    // would blow up again.
    expect(ledger.withGhosts(live).map((m) => m.id), ['b']);
    // The server dropped it: forgotten, and the list is handed back as is.
    final after = [msg('b', minute: 1)];
    expect(identical(ledger.withGhosts(after), after), isTrue);
    expect(ledger.hasDeparted('a'), isFalse);
  });

  testWidgets('a server removal is captured synchronously, once', (
    tester,
  ) async {
    var changes = 0;
    final ledger = MessageDepartures(onChanged: () => changes++);
    addTearDown(ledger.dispose);
    await tester.pumpWidget(host(ledger, 'a'));

    final previous = [msg('a'), msg('b', minute: 1), msg('p', minute: 2, ephemeral: false)];
    final current = [msg('b', minute: 1)];
    void observe() => ledger.observeRemoval(
          previous,
          current,
          keyFor: (m) => m.id,
          isMine: (_) => false,
          outlineFor: (_) => outline,
        );
    observe();
    expect(ledger.isDeparting('a'), isTrue, reason: 'taken before any frame');
    expect(ledger.captureFor('a')!.image, isNotNull);
    expect(ledger.isDeparting('p'), isFalse,
        reason: 'a plain message leaving is not an exit');
    expect(changes, 1);
    observe();
    expect(changes, 1, reason: 'the same removal seen twice is one departure');
  });

  testWidgets('a ghost is spliced back in at its place, then ends', (
    tester,
  ) async {
    final ledger = MessageDepartures(onChanged: () {});
    addTearDown(ledger.dispose);
    await tester.pumpWidget(host(ledger, 'b'));

    final b = msg('b', minute: 1);
    ledger.observeRemoval(
      [msg('a'), b, msg('c', minute: 2)],
      [msg('a'), msg('c', minute: 2)],
      keyFor: (m) => m.id,
      isMine: (_) => false,
      outlineFor: (_) => outline,
    );
    final timeline = [msg('a'), msg('c', minute: 2)];
    final merged = ledger.withGhosts(timeline);
    expect(merged.map((m) => m.id), ['a', 'b', 'c']);
    expect(identical(ledger.withGhosts(timeline), merged), isTrue,
        reason: 'memoised on the timeline instance');

    // Still present in the delivery — no duplicate.
    final withB = [msg('a'), b, msg('c', minute: 2)];
    expect(ledger.withGhosts(withB).map((m) => m.id), ['a', 'b', 'c']);

    final image = ledger.captureFor('b')!.image!;
    ledger.end('b');
    expect(ledger.isDeparting('b'), isFalse);
    expect(image.debugDisposed, isTrue, reason: 'the raster is freed');
    expect(identical(ledger.withGhosts(timeline), timeline), isTrue);
  });
}
