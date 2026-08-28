import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/widgets/message_arrivals.dart';

/// Which transcript rows are allowed to play an entrance.
///
/// The rule this replaced compared `createdAt` against the newest row already
/// drawn, and that comparison is between two different clocks: an optimistic
/// bubble is stamped by the device, its echo by the server. Under it the echo of
/// your own send is indistinguishable from news — new id, newer stamp — so every
/// send grew in twice, and a device running fast suppressed the entrance of
/// everything that arrived next. The tests below are that story: identity, then
/// position, then the three cases that must stay still.
void main() {
  final t0 = DateTime(2026, 3, 1, 12);

  ChatMessage msg(
    String id, {
    String senderId = 'them',
    String? clientId,
    int at = 0,
  }) =>
      ChatMessage(
        id: id,
        roomId: 'r',
        senderId: senderId,
        senderName: '',
        content: id,
        createdAt: t0.add(Duration(seconds: at)),
        clientId: clientId,
      );

  MessageArrivals ledger() => MessageArrivals(onSettled: () {});

  test('the first paint of a room animates nothing', () {
    final a = ledger();
    a.observe([msg('a'), msg('b'), msg('c')], myUserId: 'me', nearBottom: true);
    expect(a.isArriving('a'), isFalse);
    expect(a.isArriving('c'), isFalse);
  });

  test('a message that arrives at the tail animates', () {
    final a = ledger();
    a.observe([msg('a'), msg('b')], myUserId: 'me', nearBottom: true);
    a.observe([msg('a'), msg('b'), msg('c')], myUserId: 'me', nearBottom: true);
    expect(a.isArriving('c'), isTrue);
    expect(a.isArriving('b'), isFalse);
  });

  test('a page of older history is not an arrival', () {
    final a = ledger();
    a.observe([msg('c'), msg('d')], myUserId: 'me', nearBottom: true);
    // loadOlder splices a page in behind the reader. Older ids, same tail.
    a.observe(
      [msg('a'), msg('b'), msg('c'), msg('d')],
      myUserId: 'me',
      nearBottom: true,
    );
    expect(a.isArriving('a'), isFalse);
    expect(a.isArriving('b'), isFalse);
  });

  test('history spliced in behind the reader does not suppress the tail', () {
    final a = ledger();
    a.observe([msg('c')], myUserId: 'me', nearBottom: true);
    a.observe(
      [msg('a'), msg('b'), msg('c'), msg('d')],
      myUserId: 'me',
      nearBottom: true,
    );
    expect(a.isArriving('d'), isTrue);
    expect(a.isArriving('b'), isFalse);
  });

  test('your own send never animates, and its echo is the same row', () {
    final a = ledger();
    a.observe([msg('a')], myUserId: 'me', nearBottom: true);

    // Optimistic bubble.
    final pending = msg('tmp_1', senderId: 'me', at: 5);
    a.observe([msg('a'), pending], myUserId: 'me', nearBottom: true);
    expect(a.isArriving('tmp_1'), isFalse, reason: 'a send appears at once');
    expect(a.keyFor(pending), 'tmp_1');

    // The server's copy replaces it: different id, later stamp, same row.
    final echo = msg('srv_1', senderId: 'me', clientId: 'tmp_1', at: 9);
    a.observe([msg('a'), echo], myUserId: 'me', nearBottom: true);
    expect(a.keyFor(echo), 'tmp_1',
        reason: 'the confirmed send keeps the identity it was born with');
    expect(a.isArriving('tmp_1'), isFalse);
    expect(a.isArriving('srv_1'), isFalse);
  });

  test('a clock running ahead of the server does not mute the next arrival', () {
    final a = ledger();
    a.observe([msg('a')], myUserId: 'me', nearBottom: true);
    // The device stamps its own bubble an hour into the future.
    a.observe(
      [msg('a'), msg('tmp_1', senderId: 'me', at: 3600)],
      myUserId: 'me',
      nearBottom: true,
    );
    // Their reply carries an honest server stamp — older than ours, but news.
    a.observe(
      [msg('a'), msg('tmp_1', senderId: 'me', at: 3600), msg('b', at: 12)],
      myUserId: 'me',
      nearBottom: true,
    );
    expect(a.isArriving('b'), isTrue);
  });

  test('someone else\'s clientId is not borrowed as an identity', () {
    final a = ledger();
    a.observe([msg('a')], myUserId: 'me', nearBottom: true);
    // Their device minted `tmp_1` too. It names a row in THEIR transcript.
    final theirs = msg('srv_2', senderId: 'them', clientId: 'tmp_1', at: 4);
    a.observe([msg('a'), theirs], myUserId: 'me', nearBottom: true);
    expect(a.keyFor(theirs), 'srv_2');
    expect(a.isArriving('srv_2'), isTrue);
  });

  test('a burst bigger than the cap is a load, not news', () {
    final a = ledger();
    a.observe([msg('a')], myUserId: 'me', nearBottom: true);
    final many = [
      msg('a'),
      for (var i = 0; i < MessageArrivals.maxBurst + 1; i++)
        msg('n$i', at: i + 1),
    ];
    a.observe(many, myUserId: 'me', nearBottom: true);
    for (var i = 0; i < MessageArrivals.maxBurst + 1; i++) {
      expect(a.isArriving('n$i'), isFalse);
    }
  });

  test('own sends count toward the burst cap', () {
    final a = ledger();
    a.observe([msg('a')], myUserId: 'me', nearBottom: true);
    // A queue of stuck sends flushing on reconnect, with one reply among them.
    a.observe([
      msg('a'),
      for (var i = 0; i < MessageArrivals.maxBurst; i++)
        msg('mine$i', senderId: 'me', at: i + 1),
      msg('theirs', at: 20),
    ], myUserId: 'me', nearBottom: true);
    expect(a.isArriving('theirs'), isFalse);
  });

  test('nothing animates while the reader is scrolled away', () {
    final a = ledger();
    a.observe([msg('a')], myUserId: 'me', nearBottom: true);
    a.observe([msg('a'), msg('b')], myUserId: 'me', nearBottom: false);
    expect(a.isArriving('b'), isFalse);
    // …and it is not owed the entrance later, once it is finally scrolled to.
    a.observe([msg('a'), msg('b')], myUserId: 'me', nearBottom: true);
    expect(a.isArriving('b'), isFalse);
  });

  test('a jump into old history is a different transcript, not an arrival', () {
    final a = ledger();
    a.observe([msg('y'), msg('z')], myUserId: 'me', nearBottom: true);
    // The window swaps the list wholesale: no row in common.
    a.observe([msg('h1'), msg('h2')], myUserId: 'me', nearBottom: true);
    expect(a.isArriving('h1'), isFalse);
    expect(a.isArriving('h2'), isFalse);
    // And the window itself then behaves like any other transcript.
    a.observe(
      [msg('h1'), msg('h2'), msg('h3')],
      myUserId: 'me',
      nearBottom: true,
    );
    expect(a.isArriving('h3'), isTrue);
  });

  test('a row scrolled back into view is not an arrival', () {
    final a = ledger();
    final list = [msg('a'), msg('b'), msg('c')];
    a.observe(list, myUserId: 'me', nearBottom: true);
    // Same delivery, re-sent whole, as Convex does on every change.
    a.observe(list, myUserId: 'me', nearBottom: true);
    for (final m in list) {
      expect(a.isArriving(m.id), isFalse);
    }
  });

  test('both halves of a send in one delivery keep separate identities', () {
    final a = ledger();
    a.observe([msg('a')], myUserId: 'me', nearBottom: true);
    final pending = msg('tmp_1', senderId: 'me', at: 5);
    a.observe([msg('a'), pending], myUserId: 'me', nearBottom: true);
    // The echo lands before the optimistic bubble is reconciled away.
    final echo = msg('srv_1', senderId: 'me', clientId: 'tmp_1', at: 6);
    a.observe([msg('a'), pending, echo], myUserId: 'me', nearBottom: true);
    expect(a.keyFor(pending), 'tmp_1');
    expect(a.keyFor(echo), 'srv_1', reason: 'two rows cannot share one key');
    // Once the bubble goes, the row folds back onto the identity it was born
    // with rather than being rebuilt under a new one.
    a.observe([msg('a'), echo], myUserId: 'me', nearBottom: true);
    expect(a.keyFor(echo), 'tmp_1');
  });

  test('the entrance window closes on its own', () {
    fakeAsync((async) {
      var settled = 0;
      final a = MessageArrivals(onSettled: () => settled++);
      a.observe([msg('a')], myUserId: 'me', nearBottom: true);
      a.observe([msg('a'), msg('b')], myUserId: 'me', nearBottom: true);
      expect(a.isArriving('b'), isTrue);
      async.elapse(MessageArrivals.hold + const Duration(milliseconds: 1));
      expect(a.isArriving('b'), isFalse);
      expect(settled, 1);
      a.dispose();
    });
  });
}
