import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/message_formatting.dart';

/// The formatting sidecar's wire tolerance, and the disk-cache round-trip that
/// keeps it.
///
/// Two properties carry the whole design. First, parsing NEVER throws: a span
/// from a future client — an unknown type, a malformed offset — is dropped and
/// the text renders plain, because one bad span must not take a transcript
/// down. Second, everything that survives parsing survives `toJson`, because
/// that map IS the disk cache's whole record of a message — what fails to
/// round-trip here is what a cold boot silently loses.
void main() {
  group('FormattingType.parse', () {
    test('every known name round-trips through its wire form', () {
      for (final type in FormattingType.values) {
        expect(FormattingType.parse(type.wire), type);
      }
    });

    test('an unknown name is null, never a throw', () {
      // The closed set mirrors the backend's FORMATTING_TYPES; a name from a
      // newer client renders plain rather than breaking the transcript.
      expect(FormattingType.parse('blink'), isNull);
      expect(FormattingType.parse(null), isNull);
    });
  });

  group('FormattingEntity.fromJson', () {
    test('an unknown type drops the span', () {
      expect(
        FormattingEntity.fromJson({'type': 'blink', 'start': 0, 'end': 3}),
        isNull,
      );
    });

    test('a negative start drops the span', () {
      // Offsets index into `content`; a negative one would throw at render.
      expect(
        FormattingEntity.fromJson({'type': 'bold', 'start': -1, 'end': 3}),
        isNull,
      );
    });

    test('a span that ends where it starts, or before, drops', () {
      // Half-open [start, end): an empty or inverted run styles nothing and
      // is only ever a sign of a producer gone wrong.
      expect(
        FormattingEntity.fromJson({'type': 'bold', 'start': 3, 'end': 3}),
        isNull,
      );
      expect(
        FormattingEntity.fromJson({'type': 'bold', 'start': 5, 'end': 2}),
        isNull,
      );
    });

    test('a link keeps its url', () {
      final link = FormattingEntity.fromJson({
        'type': 'link',
        'start': 0,
        'end': 7,
        'url': 'https://example.com',
      });
      expect(link, isNotNull);
      expect(link!.type, FormattingType.link);
      expect(link.url, 'https://example.com');
    });

    test('a non-link drops a url even when the json carries one', () {
      // A url is only meaningful on a link; carried on bold it would be a tap
      // destination the renderer never shows and never confirms.
      final bold = FormattingEntity.fromJson({
        'type': 'bold',
        'start': 0,
        'end': 4,
        'url': 'https://example.com',
      });
      expect(bold, isNotNull);
      expect(bold!.url, isNull);
    });
  });

  group('FormattingEntity.parseList', () {
    test('keeps the good spans and drops the garbage, in order', () {
      final parsed = FormattingEntity.parseList([
        {'type': 'bold', 'start': 0, 'end': 4},
        'not even a map',
        42,
        {'type': 'blink', 'start': 0, 'end': 2}, // unknown type
        {'type': 'italic', 'start': -1, 'end': 2}, // malformed offset
        {'type': 'link', 'start': 5, 'end': 9, 'url': 'https://x.dev'},
      ]);
      expect(parsed, const [
        FormattingEntity(start: 0, end: 4, type: FormattingType.bold),
        FormattingEntity(
          start: 5,
          end: 9,
          type: FormattingType.link,
          url: 'https://x.dev',
        ),
      ]);
    });

    test('anything that is not a list parses as the empty list', () {
      // `const []` rather than null, so no caller ever branches on absence.
      expect(FormattingEntity.parseList(null), isEmpty);
      expect(FormattingEntity.parseList('bold'), isEmpty);
      expect(FormattingEntity.parseList({'type': 'bold'}), isEmpty);
    });
  });

  group('FormattingEntity.toJson', () {
    test('url is sparse: written on links, absent everywhere else', () {
      const link = FormattingEntity(
        start: 0,
        end: 7,
        type: FormattingType.link,
        url: 'https://example.com',
      );
      expect(link.toJson()['url'], 'https://example.com');

      const bold = FormattingEntity(start: 0, end: 4, type: FormattingType.bold);
      expect(bold.toJson().containsKey('url'), isFalse);
    });
  });

  group('the ChatMessage round-trip', () {
    // `toJson` is not just the wire shape — this map IS the disk cache's whole
    // record of a message, so this round-trip is the cold-boot guarantee: what
    // fails it is what a relaunch silently strips before the subscription
    // lands.
    test('formatting, edited and editedAt all survive a cold boot', () {
      final entities = [
        const FormattingEntity(start: 0, end: 4, type: FormattingType.bold),
        const FormattingEntity(
          start: 5,
          end: 24,
          type: FormattingType.link,
          url: 'https://example.com',
        ),
      ];
      final message = ChatMessage(
        id: 'm1',
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: 'look https://example.com',
        createdAt: DateTime(2026, 3, 1, 12, 0),
        formatting: entities,
        edited: true,
        editedAt: DateTime(2026, 3, 1, 12, 5),
      );

      // Through actual JSON text, exactly as the cache stores it — a Dart map
      // handed straight back would paper over any type the encoder refuses.
      final restored = ChatMessage.fromJson(
        jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
      );

      expect(restored.formatting, entities);
      expect(restored.edited, isTrue);
      expect(restored.editedAt, DateTime(2026, 3, 1, 12, 5));
    });

    test('empty formatting writes no formatting key at all', () {
      // The sparse rule: most messages carry no spans, and the cache should
      // not grow an empty list on every one of them. Absence parses back to
      // `const []`, so nothing is lost by omitting it.
      final plain = ChatMessage(
        id: 'm2',
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: 'hey',
        createdAt: DateTime(2026, 3, 1, 12, 0),
      );
      expect(plain.toJson().containsKey('formatting'), isFalse);
    });
  });
}
