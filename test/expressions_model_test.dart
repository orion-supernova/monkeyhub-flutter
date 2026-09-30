import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/expressions/justified_rows.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/expression_item.dart';
import 'package:monkeyhub/models/message_preview.dart';

/// The GIF/sticker model: what a message carries, what recents remember, what
/// `messages:send` is told, and the grid layout the picker draws with.
void main() {
  const gif = ExpressionItem(
    kind: ExpressionKind.gif,
    source: ExpressionSource.klipy,
    url: 'https://static.klipy.com/ii/a/b.webp',
    previewUrl: 'https://static.klipy.com/ii/a/b.jpg',
    ref: 'hello-hi-662',
    width: 498,
    height: 374,
    title: 'Hello',
  );
  const sticker = ExpressionItem(
    kind: ExpressionKind.sticker,
    source: ExpressionSource.pack,
    stickerId: 'st1',
    storageId: 'blob1',
    format: StickerFormat.lottie,
    width: 512,
    height: 512,
    title: '😂',
  );

  group('ExpressionItem', () {
    test('round-trips through the recents shape', () {
      for (final item in [gif, sticker]) {
        final back = ExpressionItem.fromRefJson(item.toRefJson())!;
        expect(back.sameAs(item), isTrue);
        expect(back.url, item.url);
        expect(back.format, item.format);
        expect(back.title, item.title);
      }
    });

    test('an entry this build does not understand is skipped, not misdrawn', () {
      expect(
        ExpressionItem.fromRefJson({'kind': 'clip', 'source': 'klipy'}),
        isNull,
      );
    });

    test('a pack sticker names only its id to the server', () {
      final args = sticker.toSendArgs();
      expect(args['type'], 'sticker');
      expect(args['stickerId'], 'st1');
      // The server takes the blob off the sticker row; the client must not be
      // the one saying which blob it is.
      expect(args.containsKey('mediaUrl'), isFalse);
      expect(args.containsKey('stickerStorageId'), isFalse);
    });

    test('a KLIPY GIF sends its URLs verbatim', () {
      final args = gif.toSendArgs();
      expect(args['type'], 'gif');
      expect(args['mediaSource'], 'klipy');
      expect(args['mediaUrl'], gif.url);
      expect(args['mediaPreviewUrl'], gif.previewUrl);
      expect(args['mediaRef'], 'hello-hi-662');
    });

    test('sameness is by picture, not by title', () {
      const retitled = ExpressionItem(
        kind: ExpressionKind.gif,
        source: ExpressionSource.klipy,
        url: 'https://static.klipy.com/ii/a/b.webp',
        title: 'Hi there',
      );
      expect(retitled.sameAs(gif), isTrue);
    });
  });

  group('ChatMessage', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
          '_id': 'm1',
          'roomId': 'r1',
          'userId': 'u1',
          'content': 'Hello',
          'createdAt': 1700000000000,
          ...extra,
        };

    test('a GIF row parses into an expression', () {
      final m = ChatMessage.fromJson(row({
        'type': 'gif',
        'mediaSource': 'klipy',
        'mediaUrl': gif.url,
        'mediaPreviewUrl': gif.previewUrl,
        'mediaRef': 'hello-hi-662',
        'mediaWidth': 498,
        'mediaHeight': 374,
      }));
      expect(m.type, MessageType.gif);
      final e = m.expression!;
      expect(e.kind, ExpressionKind.gif);
      expect(e.url, gif.url);
      expect(e.title, 'Hello');
      expect(e.aspectRatio, closeTo(498 / 374, 0.001));
    });

    test('the disk cache keeps every expression field', () {
      final m = ChatMessage.fromJson(row({
        'type': 'sticker',
        'mediaSource': 'pack',
        'stickerId': 'st1',
        'stickerStorageId': 'blob1',
        'stickerFormat': 'lottie',
      }));
      final back = ChatMessage.fromJson(m.toJson());
      expect(back.stickerStorageId, 'blob1');
      expect(back.stickerFormat, StickerFormat.lottie);
      expect(back.expression!.isLottie, isTrue);
      // copyWith runs on the reaction path; a thumbs-up must not strip it.
      expect(m.copyWith(reactions: const []).expression, isNotNull);
    });

    test('an app too old for the type falls back to text with the alt text', () {
      // What an older build does with it: `parse` defaults unknown wire names
      // to text, and `content` is the alt text the server insisted on.
      expect(MessageTypeWire.parse('hologram'), MessageType.text);
    });

    test('a sticker row with nothing to draw has no expression', () {
      final m = ChatMessage.fromJson(row({'type': 'sticker'}));
      expect(m.expression, isNull);
    });

    test('preview lines never pass a GIF title off as typed text', () {
      final g = ChatMessage.fromJson(row({
        'type': 'gif',
        'mediaUrl': gif.url,
      }));
      expect(messagePreviewLine(g), 'GIF');
      final s = ChatMessage.fromJson(row({
        'type': 'sticker',
        'content': '😂',
        'stickerId': 'st1',
        'stickerStorageId': 'b',
      }));
      expect(messagePreviewLine(s), '😂 sticker');
      // A KLIPY sticker's alt text is a title — shown as the word alone.
      final k = ChatMessage.fromJson(row({
        'type': 'sticker',
        'content': 'Whatever Nevermind',
        'mediaSource': 'klipy',
        'mediaUrl': 'https://static.klipy.com/s.webp',
      }));
      expect(messagePreviewLine(k), 'sticker');
      expect(stickerEmojiOf('❤️'), '❤️');
      expect(stickerEmojiOf('Hello'), isNull);
    });
  });

  group('justifiedRows', () {
    test('fills the width exactly and keeps every item in order', () {
      final items = [
        for (final a in [1.5, 0.8, 1.0, 2.0, 1.2, 0.7, 1.33])
          RowInput.picture(a),
      ];
      final rows = justifiedRows(items, maxWidth: 360, spacing: 4);
      var next = 0;
      for (final r in rows) {
        expect(r.start, next, reason: 'order preserved');
        next += r.count;
      }
      expect(next, items.length);
      // Every full row lands on the width to the pixel.
      for (final r in rows.take(rows.length - 1)) {
        final used =
            r.widths.fold<double>(0, (a, w) => a + w) + 4 * (r.count - 1);
        expect(used, closeTo(360, 0.01));
      }
    });

    test('a lone straggler is not blown up to fill the row', () {
      final rows = justifiedRows(
        [const RowInput.picture(1)],
        maxWidth: 360,
        targetHeight: 110,
      );
      expect(rows.single.height, 110);
    });

    test('an ad gets a row of its own, at its own size', () {
      final rows = justifiedRows(
        [
          const RowInput.picture(1.2),
          const RowInput.fixed(300, 50),
          const RowInput.picture(1.0),
        ],
        maxWidth: 360,
      );
      final ad = rows.firstWhere((r) => r.start == 1);
      expect(ad.count, 1);
      expect(ad.widths.single, 300);
      expect(ad.height, 50);
    });

    test('an ad wider than the grid is scaled down to fit', () {
      final rows = justifiedRows([const RowInput.fixed(600, 100)], maxWidth: 300);
      expect(rows.single.widths.single, 300);
      expect(rows.single.height, 50);
    });
  });
}
