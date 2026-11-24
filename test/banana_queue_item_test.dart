import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/family/banana_family_api.dart';
import 'package:monkeyhub/models/family.dart';

void main() {
  group('banana queue items', () {
    test('parses the kind: banana shape the guardian queue returns', () {
      final item = QueueItem.fromJson(const {
        'kind': 'banana',
        'requestId': 'r1',
        'childId': 'c1',
        'childName': 'Ela',
        'item': 'fighter.golem',
        'price': 90,
        'note': 'for Ali’s birthday fight',
        'sticker': '🙏',
        'createdAt': 1000,
      });
      expect(item, isNotNull);
      expect(item!.type, QueueItemType.bananaRequest);
      expect(item.relay, QueueRelay.banana);
      expect(item.id, 'r1');
      expect(item.child.id, 'c1');
      expect(item.child.displayName, 'Ela');
      expect(item.bananaItem, 'fighter.golem');
      expect(item.bananaPrice, 90);
      expect(item.sticker, '🙏');
      expect(item.note, contains('birthday'));
    });

    test('a note and sticker are optional', () {
      final item = QueueItem.fromJson(const {
        'kind': 'banana',
        'requestId': 'r2',
        'childId': 'c1',
        'childName': 'Ela',
        'item': 'stage.neon',
        'price': 40,
        'createdAt': 0,
      });
      expect(item!.note, '');
      expect(item.sticker, isNull);
    });

    test('a banana item without an item id is dropped, not crashed on', () {
      expect(
        QueueItem.fromJson(const {'kind': 'banana', 'requestId': 'r3', 'createdAt': 0}),
        isNull,
      );
    });

    test('existing item types still parse beside it', () {
      final room = QueueItem.fromJson(const {
        'type': 'joinRoom',
        '_id': 'a1',
        'createdAt': 0,
        'child': {'_id': 'c1', 'username': 'leo', 'name': 'Leo'},
        'room': {'_id': 'r1', 'name': 'minecraft'},
      });
      expect(room!.relay, QueueRelay.roomGrant);
    });
  });

  group('banana rules', () {
    test('reads the ask switch whichever way round the server spells it', () {
      expect(BananaRules.fromJson(const {'ask': false}).ask, isFalse);
      expect(BananaRules.fromJson(const {'askOff': true}).ask, isFalse);
      expect(BananaRules.fromJson(const {}).ask, isTrue);
    });

    test('an unknown spend policy falls back to the safe one', () {
      expect(BananaRules.fromJson(const {'spend': 'weird'}).spend, 'lifelines');
      expect(BananaRules.fromJson(const {'spend': 'all'}).spend, 'all');
    });
  });
}
