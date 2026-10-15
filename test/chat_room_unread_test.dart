import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/push/message_alerts.dart';

/// A room whose newest message you sent from another device looked unread, and
/// made the Mac ping for it.
///
/// Two holes, one symptom. `hasUnread` fell back to `lastMessageTime >
/// lastReadAt` whenever the server's count was 0, and sending does not move the
/// sender's read cursor, so your own message tripped it. And MessageAlerts'
/// open-room branch never asked who sent the message at all.

Map<String, dynamic> _json({
  Object? unreadCount = 0,
  int? lastMessageTime = 2000,
  int? lastReadAt = 1000,
  Object? lastMessageSenderId,
}) => {
  '_id': 'r1',
  'name': 'general',
  'createdBy': 'u0',
  'createdAt': 0,
  'isPrivate': true,
  'memberCount': 2,
  'unreadCount': ?unreadCount,
  'lastMessageTime': ?lastMessageTime,
  'lastReadAt': ?lastReadAt,
  'lastMessageSenderId': ?lastMessageSenderId,
};

class _FakeRepo extends ChangeNotifier implements ChatRepository {
  _FakeRepo(this.rooms, {this.userId, this.activeRoomId});

  @override
  List<ChatRoom> rooms;

  @override
  final String? userId;

  @override
  String? activeRoomId;

  void fire(List<ChatRoom> next) {
    rooms = next;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// MessageAlerts only runs on web and desktop.
final _mac = TargetPlatformVariant.only(TargetPlatform.macOS);

void main() {
  group('ChatRoom.hasUnread', () {
    test('a server count of 0 means 0, even with a newer last message', () {
      // The own-message case: the server excludes your sends from the count,
      // and the cursor did not move when you sent.
      final r = ChatRoom.fromJson(_json(unreadCount: 0));
      expect(r.unreadCountFromServer, isTrue);
      expect(r.hasUnread, isFalse);
    });

    test('a positive server count is unread', () {
      expect(ChatRoom.fromJson(_json(unreadCount: 3)).hasUnread, isTrue);
    });

    test('no server count falls back to the timestamps', () {
      final r = ChatRoom.fromJson(_json(unreadCount: null));
      expect(r.unreadCountFromServer, isFalse);
      expect(r.hasUnread, isTrue);
      final read = ChatRoom.fromJson(
          _json(unreadCount: null, lastMessageTime: 1000, lastReadAt: 2000));
      expect(read.hasUnread, isFalse);
    });

    test('a cached room round-trips as a server count', () {
      final cached = ChatRoom.fromJson(
          ChatRoom.fromJson(_json(lastMessageSenderId: 'me')).toJson());
      expect(cached.unreadCountFromServer, isTrue);
      expect(cached.hasUnread, isFalse);
      expect(cached.lastMessageSenderId, 'me');
    });
  });

  group('ChatRoom.lastMessageSenderId', () {
    test('parses a string id', () {
      final r = ChatRoom.fromJson(_json(lastMessageSenderId: 'me'));
      expect(r.lastMessageSenderId, 'me');
      expect(r.isLastMessageFrom('me'), isTrue);
      expect(r.isLastMessageFrom('peer'), isFalse);
    });

    test('anything else is unknown, never a crash', () {
      expect(ChatRoom.fromJson(_json()).lastMessageSenderId, isNull);
      expect(ChatRoom.fromJson(_json(lastMessageSenderId: 42))
          .lastMessageSenderId, isNull);
      expect(ChatRoom.fromJson(_json(lastMessageSenderId: ''))
          .lastMessageSenderId, isNull);
    });

    test('an unknown sender or user is never "mine"', () {
      final r = ChatRoom.fromJson(_json());
      expect(r.isLastMessageFrom('me'), isFalse);
      expect(ChatRoom.fromJson(_json(lastMessageSenderId: 'me'))
          .isLastMessageFrom(null), isFalse);
    });
  });

  group('MessageAlerts', () {
    late int pings;

    setUp(() {
      pings = 0;
      MessageAlerts.debugOnPing = () => pings++;
    });

    tearDown(() {
      MessageAlerts.instance.unbind();
      MessageAlerts.debugOnPing = null;
      TestWidgetsFlutterBinding.instance
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    ChatRoom at(int t, {String? sender, int unread = 0}) => ChatRoom.fromJson(
        _json(lastMessageTime: t, lastMessageSenderId: sender,
            unreadCount: unread));

    testWidgets('the open room, window in the background: own message is quiet',
        (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final repo = _FakeRepo([at(2000)], userId: 'me', activeRoomId: 'r1');
      MessageAlerts.instance.bind(repo);

      repo.fire([at(3000, sender: 'me')]);
      expect(pings, 0, reason: 'sent from my phone: not news to me');

      repo.fire([at(4000, sender: 'peer')]);
      expect(pings, 1, reason: 'a peer in the open room still pings');
    }, variant: _mac);

    testWidgets('another room: own message is quiet, inbound pings',
        (tester) async {
      final repo = _FakeRepo([at(2000)], userId: 'me', activeRoomId: null);
      MessageAlerts.instance.bind(repo);

      repo.fire([at(3000, sender: 'me')]);
      expect(pings, 0);

      repo.fire([at(4000, sender: 'peer', unread: 1)]);
      expect(pings, 1);
    }, variant: _mac);
  });
}
