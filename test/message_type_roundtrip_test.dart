import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_reaction.dart';

/// What this pins: `ChatMessage.toJson` and `copyWith` both hand-enumerate
/// their fields, and neither is a `switch` — so a field added to the class and
/// forgotten in either one compiles clean and fails silently.
///
/// For a document that failure is total rather than cosmetic. `toJson` is the
/// disk cache's entire record of a message, so a dropped `fileName` means a
/// cold boot renders an anonymous grey plate; and because
/// `MessageTypeWire.parse` defaults anything unknown to `text` (enums.dart),
/// a dropped `type` comes back as an empty text bubble rather than as an error.
/// `copyWith` runs on the reaction and view-once paths, neither of which knows
/// documents exist — so reacting to a document could anonymise it.
///
/// Siblings: `file_meta_test.dart` (what the name means), `view_once_test.dart`
/// (the fields this deliberately drops).
void main() {
  ChatMessage doc({String? name = 'q3 report.pdf', int? size = 84210}) =>
      ChatMessage(
        id: 'm1',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: 'here you go',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1750000000000),
        type: MessageType.file,
        mediaStorageId: 'stor_1',
        fileName: name,
        fileSize: size,
        mimeType: 'application/pdf',
      );

  group('wire enum', () {
    test('file survives a round trip through the wire string', () {
      expect(MessageType.file.wire, 'file');
      expect(MessageTypeWire.parse('file'), MessageType.file);
    });

    test('every type round-trips, so none can be quietly swallowed', () {
      // The default-to-text branch in `parse` is what makes a missed case
      // invisible, so assert the whole enum rather than the new member alone.
      for (final t in MessageType.values) {
        expect(MessageTypeWire.parse(t.wire), t, reason: 'round trip for $t');
      }
    });

    test('an unknown type still degrades to text rather than throwing', () {
      expect(MessageTypeWire.parse('hologram'), MessageType.text);
      expect(MessageTypeWire.parse(null), MessageType.text);
    });
  });

  group('toJson → fromJson', () {
    test('a document keeps its identity across the disk cache', () {
      final back = ChatMessage.fromJson(doc().toJson());

      expect(back.type, MessageType.file);
      expect(
        back.fileName,
        'q3 report.pdf',
        reason: 'the name IS the document — there is no thumbnail behind it',
      );
      expect(back.fileSize, 84210);
      expect(back.mimeType, 'application/pdf');
      expect(back.mediaStorageId, 'stor_1');
      expect(back.content, 'here you go');
    });

    test('a document with no name survives as a document', () {
      // A send whose pick reported no name still has to come back as a file
      // bubble, not as an empty text one.
      final back = ChatMessage.fromJson(doc(name: null, size: null).toJson());
      expect(back.type, MessageType.file);
      expect(back.fileName, isNull);
      expect(back.fileSize, isNull);
    });

    test('the fields are omitted, not written null, on a non-document', () {
      final text = ChatMessage(
        id: 'm2',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: 'hi',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1750000000000),
      );
      final json = text.toJson();
      expect(json.containsKey('fileName'), isFalse);
      expect(json.containsKey('fileSize'), isFalse);
      expect(json.containsKey('mimeType'), isFalse);
    });

    test('a server payload using num for fileSize still parses', () {
      // Convex numbers arrive as `num`, and JSON round trips can widen an int
      // to a double. A raw `as int?` here would throw on the wire.
      final back = ChatMessage.fromJson({
        '_id': 'm3',
        'roomId': 'r1',
        'userId': 'u1',
        'senderName': 'ada',
        'content': '',
        'createdAt': 1750000000000,
        'type': 'file',
        'fileName': 'a.pdf',
        'fileSize': 2048.0,
      });
      expect(back.fileSize, 2048);
    });
  });

  group('copyWith', () {
    test('a reaction does not anonymise the document it landed on', () {
      final reacted = doc().copyWith(
        reactions: [
          MessageReaction(
            id: 'rx1',
            messageId: 'm1',
            userId: 'u2',
            emoji: '👍',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1750000001000),
          ),
        ],
      );
      expect(reacted.fileName, 'q3 report.pdf');
      expect(reacted.fileSize, 84210);
      expect(reacted.mimeType, 'application/pdf');
      expect(reacted.type, MessageType.file);
    });

    test('the id swap on send-ack keeps the document intact', () {
      final acked = doc().copyWith(id: 'server_1');
      expect(acked.id, 'server_1');
      expect(acked.fileName, 'q3 report.pdf');
      expect(acked.mimeType, 'application/pdf');
    });
  });

  group('isMedia', () {
    test('covers a document, or the unsendable-attachment guard misses it', () {
      // Both call sites are the same guard: an attachment-shaped message with
      // no `mediaStorageId` references nothing and must never be posted. This
      // is a `||` chain, not a switch, so nothing else would report a gap.
      expect(doc().isMedia, isTrue);
    });

    test('still excludes text', () {
      final text = ChatMessage(
        id: 'm4',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: 'hi',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1750000000000),
      );
      expect(text.isMedia, isFalse);
    });
  });
}
