@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_reaction.dart';
import 'package:monkeyhub/screens/room_items.dart';
import 'package:monkeyhub/widgets/photo_mosaic.dart';

/// Consecutive photographs are drawn as one album rather than as a column of
/// bubbles, which is a claim about two things that have to agree: which run of
/// messages counts as an album, and how that run packs into a block.
///
/// The first is [collapseAlbums] and is the interesting half. A photograph is
/// only a tile if an 80-pixel square can carry everything it is holding, and
/// the run is only a block if nothing interrupted it — a sentence, a day, a
/// different sender, a fold, a five-minute gap. Everything below is one of
/// those interruptions, or the absence of one.
final _epoch = DateTime(2026, 3, 1, 12, 0);

ChatMessage photo(
  String id, {
  required int t,
  String sender = 'alice',
  String caption = '',
  bool viewOnce = false,
  String? replyTo,
  MessageStatus status = MessageStatus.sent,
  Duration? expiresIn,
  List<MessageReaction>? reactions,
}) =>
    ChatMessage(
      id: id,
      roomId: 'room',
      senderId: sender,
      senderName: sender,
      content: caption,
      createdAt: _epoch.add(Duration(minutes: t)),
      type: MessageType.image,
      mediaStorageId: 'st_$id',
      status: status,
      viewOnce: viewOnce,
      replyToId: replyTo,
      replyToPreview: replyTo == null
          ? null
          : const ReplyPreview(
              senderId: 'alice',
              senderName: 'alice',
              contentPreview: 'parent',
              type: MessageType.text,
            ),
      expiresAt: expiresIn == null ? null : _epoch.add(expiresIn),
      reactions: reactions,
    );

ChatMessage text(String id, {required int t, String sender = 'alice'}) =>
    ChatMessage(
      id: id,
      roomId: 'room',
      senderId: sender,
      senderName: sender,
      content: id,
      createdAt: _epoch.add(Duration(minutes: t)),
    );

List<RoomItem> build(List<ChatMessage> messages) => buildRoomItems(
      messages: messages,
      roomIsEphemeral: false,
      mustKeepOwnRow: (_) => false,
      dayLabel: (d) => '${d.year}-${d.month}-${d.day}',
    ).items;

List<MessageItem> rows(List<ChatMessage> messages) =>
    build(messages).whereType<MessageItem>().toList();

/// What each row draws, as ids: a lone bubble is one id, an album is all of
/// the ids it carries.
List<List<String>> drawn(List<ChatMessage> messages) => [
      for (final r in rows(messages))
        r.album.isEmpty
            ? [r.message.id]
            : [for (final p in r.album) p.id],
    ];

void main() {
  group('a run becomes one album', () {
    test('an album id groups exactly its members, gaps and all', () {
      ChatMessage tagged(String id, {required int t, String? album}) =>
          ChatMessage(
            id: id,
            roomId: 'room',
            senderId: 'alice',
            senderName: 'alice',
            content: '',
            createdAt: _epoch.add(Duration(minutes: t)),
            type: MessageType.image,
            mediaStorageId: 'st_$id',
            albumId: album,
          );
      expect(
          drawn([
            tagged('a', t: 0, album: 'x'),
            // Twenty minutes later: the timing rule alone would split here.
            tagged('b', t: 20, album: 'x'),
            tagged('c', t: 21, album: 'y'),
            tagged('d', t: 22, album: 'y'),
            tagged('e', t: 23),
          ]),
          [
            ['a', 'b'],
            ['c', 'd'],
            ['e'],
          ]);
    });

    test('photos and videos together', () {
      ChatMessage video(String id, {required int t}) => ChatMessage(
            id: id,
            roomId: 'room',
            senderId: 'alice',
            senderName: 'alice',
            content: '',
            createdAt: _epoch.add(Duration(minutes: t)),
            type: MessageType.video,
            mediaStorageId: 'st_$id',
          );
      expect(
          drawn([
            photo('a', t: 0),
            video('b', t: 1),
            photo('c', t: 2),
            video('d', t: 3),
          ]),
          [
            ['a', 'b', 'c', 'd']
          ]);
    });

    test('two photographs in a row', () {
      expect(drawn([photo('a', t: 0), photo('b', t: 1)]), [
        ['a', 'b']
      ]);
    });

    test('and the row stands for the LAST of them', () {
      final row = rows([photo('a', t: 0), photo('b', t: 1)]).single;
      // The stamp, the ticks and the avatar all come off `message`, and the
      // moment an album finished arriving is the moment its newest picture
      // did.
      expect(row.message.id, 'b');
      expect(row.album.map((p) => p.id), ['a', 'b']);
    });

    test('ten of them, which is the cap', () {
      final run = [for (var i = 0; i < 10; i++) photo('p$i', t: i)];
      expect(drawn(run).single.length, 10);
    });

    test('and an eleventh starts a second block rather than a wider one', () {
      final run = [for (var i = 0; i < 12; i++) photo('p$i', t: i)];
      // Twelve is ten and two, not twelve — a block that grew without limit
      // would be a wall no reader asked for.
      expect(drawn(run).map((r) => r.length), [10, 2]);
    });

    test('a lone photograph is left as the bubble it always was', () {
      final row = rows([photo('a', t: 0)]).single;
      expect(row.album, isEmpty);
    });
  });

  group('what interrupts a run', () {
    test('a sentence between two photographs', () {
      expect(
        drawn([photo('a', t: 0), text('says', t: 1), photo('b', t: 2)]),
        [
          ['a'],
          ['says'],
          ['b']
        ],
      );
    });

    test('a different sender', () {
      expect(drawn([photo('a', t: 0), photo('b', t: 1, sender: 'bob')]), [
        ['a'],
        ['b']
      ]);
    });

    test('a gap wider than the grouping window', () {
      expect(drawn([photo('a', t: 0), photo('b', t: 30)]), [
        ['a'],
        ['b']
      ]);
    });

    test('a day boundary, even inside the window', () {
      final late = ChatMessage(
        id: 'a',
        roomId: 'room',
        senderId: 'alice',
        senderName: 'alice',
        content: '',
        createdAt: DateTime(2026, 3, 1, 23, 59),
        type: MessageType.image,
        mediaStorageId: 'st_a',
      );
      final justAfter = ChatMessage(
        id: 'b',
        roomId: 'room',
        senderId: 'alice',
        senderName: 'alice',
        content: '',
        createdAt: DateTime(2026, 3, 2, 0, 0, 30),
        type: MessageType.image,
        mediaStorageId: 'st_b',
      );
      expect(drawn([late, justAfter]), [
        ['a'],
        ['b']
      ]);
    });
  });

  group('what a tile cannot carry, so keeps its own bubble', () {
    test('a caption', () {
      expect(
        drawn([photo('a', t: 0), photo('b', t: 1, caption: 'at the beach')]),
        [
          ['a'],
          ['b']
        ],
      );
    });

    test('a view-once seal', () {
      expect(drawn([photo('a', t: 0), photo('b', t: 1, viewOnce: true)]), [
        ['a'],
        ['b']
      ]);
    });

    test('a quote card', () {
      expect(drawn([photo('a', t: 0), photo('b', t: 1, replyTo: 'a')]), [
        ['a'],
        ['b']
      ]);
    });

    test('a dissolve — an ephemeral photo keeps its frame', () {
      expect(
        drawn([
          photo('a', t: 0),
          photo('b', t: 1, expiresIn: const Duration(hours: 1))
        ]),
        [
          ['a'],
          ['b']
        ],
      );
    });

    test('a failed send, which needs its retry and discard controls', () {
      expect(
        drawn([photo('a', t: 0), photo('b', t: 1, status: MessageStatus.error)]),
        [
          ['a'],
          ['b']
        ],
      );
    });
  });

  test('reactions do NOT break a block — the tile draws its own', () {
    // Otherwise the block would rearrange itself under the reader's finger the
    // moment anybody reacted to one of its pictures.
    final reacted = photo(
      'b',
      t: 1,
      reactions: [
        MessageReaction(
          id: 'r1',
          messageId: 'b',
          userId: 'bob',
          emoji: '🔥',
          createdAt: _epoch,
        ),
      ],
    );
    expect(drawn([photo('a', t: 0), reacted]), [
      ['a', 'b']
    ]);
  });

  group('the run a block inherits', () {
    test('opens where the first photograph opened it', () {
      // `newSender` is what prints the name, and the name belongs above the
      // whole block rather than above its newest tile.
      final row = rows([
        text('hi', t: 0, sender: 'bob'),
        photo('a', t: 1),
        photo('b', t: 2),
      ]).last;
      expect(row.newSender, isTrue);
      expect(row.grouped, isFalse);
    });

    test('and closes where the last one closed it', () {
      final withTail = rows([
        photo('a', t: 0),
        photo('b', t: 1),
        text('and that was that', t: 2),
      ]);
      // The avatar rides the row that closes the sender's run, which is the
      // sentence under the block rather than the block.
      expect(withTail.first.album.length, 2);
      expect(withTail.first.lastInRun, isFalse);
      expect(withTail.last.lastInRun, isTrue);
    });

    test('a block that continues a sentence stays grouped to it', () {
      final r = rows([text('look', t: 0), photo('a', t: 1), photo('b', t: 2)]);
      expect(r.last.grouped, isTrue);
      expect(r.first.lastInRun, isFalse);
    });
  });

  group('the mosaic plan', () {
    test('accounts for every photograph exactly once', () {
      for (var n = 4; n <= kMaxAlbumPhotos; n++) {
        expect(mosaicRows(n).reduce((a, b) => a + b), n,
            reason: '$n photographs');
      }
    });

    test('is rows of two and three only', () {
      for (var n = 2; n <= kMaxAlbumPhotos; n++) {
        expect(mosaicRows(n).every((k) => k == 2 || k == 3), isTrue,
            reason: '$n photographs');
      }
    });

    test('opens on its biggest tiles and tapers, never the other way', () {
      // Fewest tiles in a row means the largest tiles, because a row's tiles
      // are square and share the block's width.
      for (var n = 4; n <= kMaxAlbumPhotos; n++) {
        final plan = mosaicRows(n);
        expect(plan.first, plan.reduce((a, b) => a < b ? a : b),
            reason: '$n photographs');
        for (var i = 1; i < plan.length; i++) {
          expect(plan[i], greaterThanOrEqualTo(plan[i - 1]),
              reason: '$n photographs');
        }
      }
    });

    test('three is featured instead — three across is three thumbnails', () {
      expect(mosaicFeatured(3), isTrue);
      expect(mosaicFeatured(2), isFalse);
      expect(mosaicFeatured(4), isFalse);
    });
  });
}
