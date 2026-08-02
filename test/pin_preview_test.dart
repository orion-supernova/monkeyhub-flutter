import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_preview.dart';

/// The pin banner, the pin list and the composer's reply card all describe a
/// message they are not rendering. They used to do it three different ways, so
/// the same voice note read as "voice message" in one place and as an empty row
/// in another.
///
/// What this pins:
///
///  * a view-once photo is identified as one BEFORE its content is consulted —
///    the caption of a burn-after-reading photo is not a safe thing to leak
///    into a banner, and there is never a thumbnail to fall back on;
///  * the output is always ONE line. `maxLines: 1` keeps the first line, so a
///    message that opens with a blank line rendered as an empty banner;
///  * `hasThumbnail` is the only difference between callers, and it only
///    matters for uncaptioned media.
void main() {
  ChatMessage msg({
    MessageType type = MessageType.text,
    String content = '',
    bool viewOnce = false,
  }) => ChatMessage(
    id: 'm1',
    roomId: 'r',
    senderId: 'alice',
    senderName: 'alice',
    content: content,
    createdAt: DateTime(2026, 3, 1, 12),
    type: type,
    viewOnce: viewOnce,
  );

  group('view-once wins', () {
    test('is labelled before content is consulted', () {
      final m = msg(
        type: MessageType.image,
        content: 'the safe combination',
        viewOnce: true,
      );
      expect(messagePreviewLine(m), 'photo · view once');
    });

    test('stays labelled even where a thumbnail would be drawn', () {
      // The server withholds the storage id for these, so the sheet has no
      // picture to show — the words have to carry it in both callers.
      final m = msg(type: MessageType.image, viewOnce: true);
      expect(messagePreviewLine(m, hasThumbnail: true), 'photo · view once');
    });
  });

  group('text', () {
    test('is passed through', () {
      expect(
        messagePreviewLine(msg(content: 'deploy at 4pm')),
        'deploy at 4pm',
      );
    });

    test('empty renders as an ellipsis, never as nothing', () {
      expect(messagePreviewLine(msg()), '…');
    });

    test('a url is treated as text', () {
      final m = msg(type: MessageType.url, content: 'https://example.com');
      expect(messagePreviewLine(m), 'https://example.com');
    });
  });

  group('media', () {
    test('an uncaptioned photo needs the word without a thumbnail', () {
      expect(messagePreviewLine(msg(type: MessageType.image)), 'photo');
      expect(messagePreviewLine(msg(type: MessageType.video)), 'video');
    });

    test('an uncaptioned photo says nothing beside a thumbnail', () {
      final m = msg(type: MessageType.image);
      expect(messagePreviewLine(m, hasThumbnail: true), '');
    });

    test('a caption wins over the type label either way', () {
      final m = msg(type: MessageType.image, content: 'the whiteboard');
      expect(messagePreviewLine(m), 'the whiteboard');
      expect(messagePreviewLine(m, hasThumbnail: true), 'the whiteboard');
    });

    test('audio is named, having nothing else to show', () {
      expect(messagePreviewLine(msg(type: MessageType.audio)), 'voice message');
    });
  });

  group('one line, always', () {
    test('a leading blank line does not render an empty banner', () {
      final m = msg(content: '\n\nthe actual point');
      expect(messagePreviewLine(m), 'the actual point');
    });

    test('interior newlines collapse to single spaces', () {
      final m = msg(content: 'first\nsecond\n\nthird');
      expect(messagePreviewLine(m), 'first second third');
    });

    test('tabs and runs of spaces collapse too', () {
      expect(messagePreviewLine(msg(content: 'a \t  b')), 'a b');
    });

    test('long content is truncated with an ellipsis', () {
      final m = msg(content: 'x' * 400);
      final out = messagePreviewLine(m);
      expect(out.length, lessThan(400));
      expect(out.endsWith('…'), isTrue);
    });

    test('content at the limit is not truncated', () {
      final m = msg(content: 'y' * 120);
      expect(messagePreviewLine(m), 'y' * 120);
      expect(messagePreviewLine(m).endsWith('…'), isFalse);
    });
  });
}
