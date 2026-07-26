import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/pending_reconcile.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/pending_upload.dart';

/// Which optimistic bubbles a server echo is allowed to remove.
///
/// The rule this replaced asked `live.any(...)` and matched on
/// `(senderId, content, ±10 minutes)`. Every captionless photo has
/// `content == ''`, so ONE incoming empty-content message from the same sender
/// satisfied the predicate for EVERY pending empty-content message and deleted
/// all of them. With one photo in flight at a time that was rare and invisible.
/// Now that a photo's bubble appears the instant SEND is tapped and several can
/// be uploading at once, it would eat the lot — which is what the first test
/// here is about.
void main() {
  final t0 = DateTime(2026, 3, 1, 12);

  ChatMessage msg({
    required String id,
    String content = '',
    MessageType type = MessageType.image,
    MessageStatus status = MessageStatus.pending,
    String? storageId,
    bool viewOnce = false,
    String senderId = 'alice',
    Duration offset = Duration.zero,
    bool withBytes = false,
  }) =>
      ChatMessage(
        id: id,
        roomId: 'r',
        senderId: senderId,
        senderName: '',
        content: content,
        createdAt: t0.add(offset),
        type: type,
        status: status,
        mediaStorageId: storageId,
        viewOnce: viewOnce,
        upload: withBytes
            ? PendingUpload(
                bytes: Uint8List.fromList(const [1, 2, 3]),
                contentType: 'image/jpeg',
              )
            : null,
      );

  group('one-to-one claiming', () {
    test('a single echo removes exactly one of two captionless photos', () {
      final a = msg(id: 'tmp_1', storageId: 'sA');
      final b = msg(id: 'tmp_2', storageId: 'sB');
      // The echo of A only. Under the old `any` predicate both bubbles matched
      // it on (sender, '', within 10 minutes) and both vanished.
      final live = [msg(id: 'srv_1', storageId: 'sA')];

      final kept = survivingPending(live, [a, b]);

      expect(kept, [b]);
    });

    test('two echoes remove two pendings, not the same one twice', () {
      final a = msg(id: 'tmp_1', storageId: 'sA');
      final b = msg(id: 'tmp_2', storageId: 'sB');
      final live = [
        msg(id: 'srv_1', storageId: 'sA'),
        msg(id: 'srv_2', storageId: 'sB'),
      ];

      expect(survivingPending(live, [a, b]), isEmpty);
    });

    test('one text echo cannot claim two identical pending texts', () {
      final a = msg(id: 'tmp_1', content: 'ok', type: MessageType.text);
      final b = msg(id: 'tmp_2', content: 'ok', type: MessageType.text);
      final live = [msg(id: 'srv_1', content: 'ok', type: MessageType.text)];

      expect(survivingPending(live, [a, b]), [b]);
    });
  });

  group('uploading is never reconciled', () {
    test('bytes still going up survive an otherwise-matching echo', () {
      final pending = msg(
        id: 'tmp_1',
        status: MessageStatus.uploading,
        withBytes: true,
      );
      // Same sender, same empty content, same minute — everything the old rule
      // asked for.
      final live = [msg(id: 'srv_1')];

      expect(survivingPending(live, [pending]), [pending]);
    });
  });

  group('media matches on storage id', () {
    test('equal ids reconcile even far outside the ±10 minute window', () {
      final pending = msg(id: 'tmp_1', storageId: 'sA');
      final live = [
        msg(id: 'srv_1', storageId: 'sA', offset: const Duration(hours: 3)),
      ];

      expect(survivingPending(live, [pending]), isEmpty);
    });

    test('different ids do not reconcile even in the same second', () {
      final pending = msg(id: 'tmp_1', storageId: 'sA');
      final live = [msg(id: 'srv_1', storageId: 'sB')];

      expect(survivingPending(live, [pending]), [pending]);
    });
  });

  group('the content + window fallback', () {
    test('text still reconciles on content inside the window', () {
      final pending = msg(id: 'tmp_1', content: 'hi', type: MessageType.text);
      final live = [
        msg(
          id: 'srv_1',
          content: 'hi',
          type: MessageType.text,
          offset: const Duration(minutes: 4),
        ),
      ];

      expect(survivingPending(live, [pending]), isEmpty);
    });

    test('the window still closes — this is the metro-tunnel bound', () {
      final pending = msg(id: 'tmp_1', content: 'hi', type: MessageType.text);
      final live = [
        msg(
          id: 'srv_1',
          content: 'hi',
          type: MessageType.text,
          offset: const Duration(minutes: 11),
        ),
      ];

      expect(survivingPending(live, [pending]), [pending]);
    });

    test('a view-once photo falls back to the window, having no id to compare',
        () {
      // The server strips mediaStorageId from every read of an armed photo, so
      // the id branch can never fire for one — the fallback has to work.
      final pending = msg(id: 'tmp_1', viewOnce: true, storageId: 'sA');
      final live = [msg(id: 'srv_1', viewOnce: true)];

      expect(survivingPending(live, [pending]), isEmpty);
    });
  });

  group('the cheap discriminators', () {
    test('a different sender never reconciles', () {
      final pending = msg(id: 'tmp_1', storageId: 'sA');
      final live = [msg(id: 'srv_1', storageId: 'sA', senderId: 'bob')];

      expect(survivingPending(live, [pending]), [pending]);
    });

    test('a different type never reconciles', () {
      final pending = msg(id: 'tmp_1', type: MessageType.image);
      final live = [msg(id: 'srv_1', type: MessageType.video)];

      expect(survivingPending(live, [pending]), [pending]);
    });

    test('an armed photo is not the echo of an unarmed one', () {
      final pending = msg(id: 'tmp_1', viewOnce: true);
      final live = [msg(id: 'srv_1')];

      expect(survivingPending(live, [pending]), [pending]);
    });
  });

  // A send that acked knows the id of the row it created, and after the ack the
  // bubble is `sent` rather than `pending`. Matching on that id is what lets the
  // bubble survive a socket rebuild honestly: it stops drawing "sending" the
  // moment the mutation returns, and still collapses into exactly the right live
  // row whenever the subscription is re-registered and the echo finally lands.
  group('an acked send matches on its server id', () {
    ChatMessage acked(String tmpId, String serverId) =>
        msg(id: tmpId, status: MessageStatus.sent)..serverId = serverId;

    test('the echo of the acked row removes it', () {
      final pending = acked('tmp_1', 'srv_1');

      expect(survivingPending([msg(id: 'srv_1')], [pending]), isEmpty);
    });

    test('a different row does not, however alike it looks', () {
      // Same sender, same empty caption, same instant — everything the
      // content-and-window rule matches on. The id says otherwise.
      final pending = acked('tmp_1', 'srv_1');

      expect(survivingPending([msg(id: 'srv_2')], [pending]), [pending]);
    });

    test('two acked sends claim their own rows, not each other\'s', () {
      final a = acked('tmp_1', 'srv_1');
      final b = acked('tmp_2', 'srv_2');
      final live = [msg(id: 'srv_2')];

      expect(survivingPending(live, [a, b]), [a]);
    });
  });

  // The strongest signal, and the only one that survives a lost ack: the server
  // stores the sender's idempotency key and hands it back on the live row, so
  // the row says which bubble it came from. `messages:send` dedupes on the same
  // key, so a retried send cannot produce a second row to reconcile against in
  // the first place.
  group('the server echoes the idempotency key', () {
    test('the echo claims the bubble that minted the key', () {
      final pending = msg(id: 'tmp_1');
      final live = ChatMessage(
        id: 'srv_1',
        roomId: 'r',
        senderId: 'alice',
        senderName: '',
        content: '',
        createdAt: t0,
        type: MessageType.image,
        clientId: 'tmp_1',
      );

      expect(survivingPending([live], [pending]), isEmpty);
    });

    test('a row carrying another key is decisively not this bubble', () {
      // Identical on every heuristic — same sender, caption, type and instant.
      // The key overrules all of it.
      final pending = msg(id: 'tmp_1', storageId: 'sA');
      final live = ChatMessage(
        id: 'srv_1',
        roomId: 'r',
        senderId: 'alice',
        senderName: '',
        content: '',
        createdAt: t0,
        type: MessageType.image,
        mediaStorageId: 'sA',
        clientId: 'tmp_OTHER',
      );

      expect(survivingPending([live], [pending]), [pending]);
    });

    test('it outranks an ack that named a different row', () {
      // Both signals present and disagreeing. The echo is the later, more
      // direct evidence: it came from the row itself.
      final pending = msg(id: 'tmp_1', status: MessageStatus.sent)
        ..serverId = 'srv_STALE';
      final live = ChatMessage(
        id: 'srv_1',
        roomId: 'r',
        senderId: 'alice',
        senderName: '',
        content: '',
        createdAt: t0,
        type: MessageType.image,
        clientId: 'tmp_1',
      );

      expect(survivingPending([live], [pending]), isEmpty);
    });
  });

  test('nothing pending is a no-op', () {
    expect(survivingPending([msg(id: 'srv_1')], const []), isEmpty);
  });

  test('order is preserved among survivors', () {
    final a = msg(id: 'tmp_1', storageId: 'sA');
    final b = msg(id: 'tmp_2', storageId: 'sB');
    final c = msg(id: 'tmp_3', storageId: 'sC');
    final live = [msg(id: 'srv_2', storageId: 'sB')];

    expect(survivingPending(live, [a, b, c]).map((m) => m.id), ['tmp_1', 'tmp_3']);
  });
}
