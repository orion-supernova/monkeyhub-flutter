import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/share/shared_payload.dart';

/// What this pins: the boundary between two native implementations and Dart.
///
/// `SharedPayload.fromChannel` is the only thing standing between what
/// `ShareIntake.kt` and `ShareViewController.swift` decide to send and a
/// `File(path)` call in `RoomScreen._deliverShare`. Neither platform can be
/// exercised from the VM, so this pins the SHAPE of the contract instead —
/// every field either survives the crossing intact or is dropped on purpose.
void main() {
  Map<String, Object?> item({
    String path = '/tmp/a.jpg',
    String mime = 'image/jpeg',
    int size = 10,
    String? name,
    bool oversize = false,
  }) => {
        'path': path,
        'mimeType': mime,
        'size': size,
        'fileName': name,
        'oversize': oversize,
      };

  group('fromChannel', () {
    test('refuses anything that is not a map', () {
      expect(SharedPayload.fromChannel(null), isNull);
      expect(SharedPayload.fromChannel('a photo'), isNull);
      expect(SharedPayload.fromChannel(const <Object>[]), isNull);
    });

    test('refuses an empty envelope', () {
      // Both platforms would rather hand over an envelope than nothing when a
      // share sheet is dismissed mid-flight. Turning that into a payload would
      // raise a chat picker offering to send nothing.
      expect(SharedPayload.fromChannel(const {'items': [], 'text': null}), isNull);
      expect(SharedPayload.fromChannel(const {'items': [], 'text': '   '}), isNull);
    });

    test('keeps items in the order the sender chose', () {
      final payload = SharedPayload.fromChannel({
        'items': [
          item(path: '/tmp/1.jpg'),
          item(path: '/tmp/2.jpg'),
          item(path: '/tmp/3.jpg'),
        ],
      })!;
      expect(
        payload.items.map((i) => i.path),
        ['/tmp/1.jpg', '/tmp/2.jpg', '/tmp/3.jpg'],
        reason: 'five photos arriving shuffled is the first thing a user sees',
      );
    });

    test('drops an item with no path unless it is oversize', () {
      // A pathless, non-oversize item is a platform bug. Letting it through
      // would put `File('')` in the send path.
      final payload = SharedPayload.fromChannel({
        'items': [item(path: ''), item(path: '/tmp/ok.jpg')],
      })!;
      expect(payload.items.map((i) => i.path), ['/tmp/ok.jpg']);
    });

    test('keeps an oversize item, which never has a path', () {
      // Nothing was copied — that is the point of reporting it. It exists so
      // the app can say WHY fewer things arrived than were shared.
      final payload = SharedPayload.fromChannel({
        'items': [item(path: '', size: 999999999, oversize: true)],
      })!;
      expect(payload.items, hasLength(1));
      expect(payload.oversized, hasLength(1));
      expect(payload.sendable, isEmpty);
      expect(payload.oversized.single.size, 999999999);
    });

    test('trims text and treats whitespace as absent', () {
      expect(SharedPayload.fromChannel(const {'text': '  hi  '})!.text, 'hi');
      final withItems = SharedPayload.fromChannel({
        'items': [item()],
        'text': '   ',
      })!;
      expect(withItems.text, isNull);
    });

    test('reads a suggestion tap as a target, and a blank one as none', () {
      expect(
        SharedPayload.fromChannel({'items': [item()], 'targetId': 'room_7'})!
            .targetRoomId,
        'room_7',
      );
      expect(
        SharedPayload.fromChannel({'items': [item()], 'targetId': '  '})!
            .targetRoomId,
        isNull,
      );
      expect(
        SharedPayload.fromChannel({'items': [item()]})!.targetRoomId,
        isNull,
      );
    });

    test('falls back to a usable MIME type rather than dropping the item', () {
      final payload = SharedPayload.fromChannel({
        'items': [
          {'path': '/tmp/x', 'size': 1},
        ],
      })!;
      expect(payload.items.single.mimeType, 'application/octet-stream');
      expect(payload.items.single.messageType, MessageType.file);
    });
  });

  group('messageType', () {
    // Only the TOP-LEVEL type is consulted. A share sheet is where unusual
    // subtypes turn up — image/heic, image/avif, video/quicktime — and treating
    // an unfamiliar one as a document sends somebody's photo as a blob.
    test('routes by top-level type, not by a known-subtype list', () {
      expect(
        const SharedItem(path: 'a', mimeType: 'image/avif', size: 1).messageType,
        MessageType.image,
      );
      expect(
        const SharedItem(path: 'a', mimeType: 'video/quicktime', size: 1)
            .messageType,
        MessageType.video,
      );
      expect(
        const SharedItem(path: 'a', mimeType: 'audio/mpeg', size: 1).messageType,
        MessageType.file,
      );
      expect(
        const SharedItem(path: 'a', mimeType: 'application/pdf', size: 1)
            .messageType,
        MessageType.file,
      );
    });
  });

  group('loneImage', () {
    // One photo gets the editor; anything else goes straight up. The editor has
    // no carousel, and a document has nothing to edit.
    test('is the single sendable image', () {
      final payload = SharedPayload.fromChannel({'items': [item()]})!;
      expect(payload.loneImage, isNotNull);
    });

    test('is null for two images', () {
      final payload = SharedPayload.fromChannel({
        'items': [item(path: '/tmp/1.jpg'), item(path: '/tmp/2.jpg')],
      })!;
      expect(payload.loneImage, isNull);
    });

    test('is null for a single non-image', () {
      final payload = SharedPayload.fromChannel({
        'items': [item(mime: 'application/pdf')],
      })!;
      expect(payload.loneImage, isNull);
    });

    test('ignores oversize siblings when deciding', () {
      // One photo plus one refused video is still the one-photo case: the
      // refused one has no bytes and is never sent.
      final payload = SharedPayload.fromChannel({
        'items': [
          item(),
          item(path: '', mime: 'video/mp4', oversize: true),
        ],
      })!;
      expect(payload.loneImage, isNotNull);
      expect(payload.oversized, hasLength(1));
    });
  });

  test('withTarget keeps everything else', () {
    final payload = SharedPayload.fromChannel({
      'items': [item()],
      'text': 'look',
    })!;
    final retargeted = payload.withTarget('room_1');
    expect(retargeted.targetRoomId, 'room_1');
    expect(retargeted.text, 'look');
    expect(retargeted.items, payload.items);
  });
}
