import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/models/message_preview.dart';

/// The one-line preview must never show what a spoiler hides. Every caller
/// of `messagePreviewLine` — pin banner, pin list, reply and edit cards, the
/// row action menu's quote — is a surface with no veil to touch, so the
/// words would otherwise sit in the open on a screen the bubble itself keeps
/// them off. Mirrors `maskSpoilers` in `backend/convex/messages.test.ts`.
void main() {
  ChatMessage msg(
    String content, {
    MessageType type = MessageType.text,
    List<FormattingEntity> formatting = const [],
  }) =>
      ChatMessage(
        id: 'm1',
        roomId: 'r',
        senderId: 'a',
        senderName: 'a',
        content: content,
        createdAt: DateTime(2026, 3, 1),
        type: type,
        formatting: formatting,
      );

  const spoil = FormattingType.spoiler;

  group('maskSpoilers', () {
    test('replaces the span with a fixed mask', () {
      expect(
        maskSpoilers('the winner is Ada', const [
          FormattingEntity(start: 14, end: 17, type: spoil),
        ]),
        'the winner is $spoilerMask',
      );
      // Length is part of what a spoiler hides.
      expect(
        maskSpoilers('a much longer secret', const [
          FormattingEntity(start: 0, end: 20, type: spoil),
        ]),
        spoilerMask,
      );
    });

    test('leaves other spans and unformatted text alone', () {
      const text = 'bold and italic';
      expect(
        maskSpoilers(text, const [
          FormattingEntity(start: 0, end: 4, type: FormattingType.bold),
          FormattingEntity(start: 9, end: 15, type: FormattingType.italic),
        ]),
        text,
      );
      expect(maskSpoilers(text, const []), text);
    });

    test('touching and overlapping spoilers collapse into one mask', () {
      expect(
        maskSpoilers('abcdefgh', const [
          FormattingEntity(start: 4, end: 6, type: spoil),
          FormattingEntity(start: 1, end: 3, type: spoil),
          FormattingEntity(start: 3, end: 5, type: spoil),
        ]),
        'a${spoilerMask}gh',
      );
      expect(
        maskSpoilers('abcdefgh', const [
          FormattingEntity(start: 1, end: 3, type: spoil),
          FormattingEntity(start: 5, end: 7, type: spoil),
        ]),
        'a${spoilerMask}de${spoilerMask}h',
      );
    });

    test('out-of-range offsets are clamped, never thrown on', () {
      expect(
        maskSpoilers('abc', const [
          FormattingEntity(start: 1, end: 99, type: spoil),
        ]),
        'a$spoilerMask',
      );
    });
  });

  group('messagePreviewLine', () {
    test('masks a spoiler in a text message', () {
      final line = messagePreviewLine(msg(
        'guess who: Ada',
        formatting: const [FormattingEntity(start: 11, end: 14, type: spoil)],
      ));
      expect(line, 'guess who: $spoilerMask');
    });

    test('masks a spoiler in a media caption', () {
      final line = messagePreviewLine(
        msg(
          'look at this Ada',
          type: MessageType.image,
          formatting: const [
            FormattingEntity(start: 13, end: 16, type: spoil),
          ],
        ),
        hasThumbnail: true,
      );
      expect(line, isNot(contains('Ada')));
      expect(line, contains(spoilerMask));
    });

    test('a message with no spoiler previews as before', () {
      expect(messagePreviewLine(msg('hello there')), 'hello there');
    });
  });
}
