import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/screens/room_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/pending_placeholder.dart';
import 'package:monkeyhub/widgets/skeleton_rows.dart';

/// Opening a room from a notification tap said "room gone" for a beat.
///
/// `RoomScreen.build` had one branch for two different facts — the room is not
/// in `_rooms` because it was deleted, and the room is not in `_rooms` because
/// the list has not arrived — and it printed the epitaph for both.
/// `_openRoomFromPush` waits for the session and the navigator and nothing
/// else, and `_bootstrap` mounts the UI early on purpose, so the push tap is
/// exactly the entry that arrives before the room list does.
///
/// The fix gates the epitaph on [ChatRepository.hasLiveRoomList] — the SERVER's
/// own list, not the disk snapshot, because the sharpest case (a group you were
/// added to an hour ago) is precisely a room the snapshot cannot contain.

class _FakeSub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCv extends Fake implements ConvexBackend {
  /// `onData` for the last subscription registered under each query name.
  final Map<String, void Function(dynamic)> sinks = {};

  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    sinks[name] = onData;
    return _FakeSub();
  }

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

/// Every seed call fails, which is the cold start this is about: nothing but
/// the (empty) disk cache until a subscription delivers.
class _OfflineApi extends Fake implements ChatApi {
  @override
  Future<List<ChatRoom>> listUserRooms(String userId) async =>
      throw StateError('offline');

  @override
  Future<List<ChatUser>> listFriends(String userId) async =>
      throw StateError('offline');

  @override
  Future<List<FriendRequest>> listIncomingDirectRequests(String userId) async =>
      throw StateError('offline');

  @override
  Future<List<FriendRequest>> listOutgoingDirectRequests(String userId) async =>
      throw StateError('offline');

  @override
  Future<String> ensureSavedMessagesRoom({required String userId}) async =>
      throw StateError('offline');

  @override
  Future<List<ChatMessage>> listMessages({
    required String roomId,
    int limit = 100,
    String? viewerUserId,
  }) async => throw StateError('offline');

  @override
  Future<void> markRoomRead({
    required String roomId,
    required String userId,
    DateTime? upTo,
  }) async {}

  @override
  Future<void> clearTyping({
    required String roomId,
    required String userId,
  }) async {}
}

Map<String, dynamic> _roomWire(String id) => {
      '_id': id,
      'name': 'The Room',
      'createdBy': 'someone',
      'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'isPrivate': false,
      'memberCount': 2,
      'participantIds': ['me', 'someone'],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the repository knows what it has actually been told', () {
    late _FakeCv cv;
    late ChatRepository repo;

    setUp(() async {
      cv = _FakeCv();
      repo = ChatRepository(api: _OfflineApi(), cv: cv);
      await repo.attach('me');
    });

    tearDown(() async => repo.detach());

    test('a seed that failed is not the server having answered', () {
      // `listUserRooms` goes through `catchError((_) => <ChatRoom>[])`, so the
      // weak flag cannot tell a dead network from an account with no rooms.
      // That is the whole reason the strong one exists.
      expect(repo.roomsLoaded, isTrue);
      expect(repo.hasLiveRoomList, isFalse);
    });

    test('the subscription delivering is', () {
      cv.sinks['rooms:listUserRooms']!([_roomWire('r1')]);
      expect(repo.hasLiveRoomList, isTrue);
    });

    test('an empty delivery counts too — that is still an answer', () {
      cv.sinks['rooms:listUserRooms']!(const []);
      expect(repo.hasLiveRoomList, isTrue);
    });

    test('signing out takes it back', () async {
      cv.sinks['rooms:listUserRooms']!([_roomWire('r1')]);
      expect(repo.hasLiveRoomList, isTrue);

      await repo.detach();

      expect(
        repo.hasLiveRoomList,
        isFalse,
        reason: 'the next account must not be told a room is gone on the '
            'strength of a list belonging to somebody else',
      );
    });

    test('seeding in a test is an answer, both flags', () {
      // `debugSeedRooms` documents itself as an answer; a test that seeds
      // nothing and opens a room is describing a room that really is not
      // there, and has to reach "room gone" rather than the skeleton.
      final seeded = ChatRepository(api: _OfflineApi(), cv: _FakeCv());
      seeded.debugSeedRooms(const []);
      expect(seeded.roomsLoaded, isTrue);
      expect(seeded.hasLiveRoomList, isTrue);
    });
  });

  group('the screen', () {
    late _FakeCv cv;
    late ChatRepository repo;
    late ChatApi api;

    Widget host(String roomId) => MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ThemeScope(
              controller: ThemeController(BasicTheme.midnight()),
              child: RoomScreen(roomId: roomId, repo: repo, api: api),
            ),
          ),
        );

    setUp(() async {
      cv = _FakeCv();
      api = ChatApi(ConvexBackend.instance);
      repo = ChatRepository(api: _OfflineApi(), cv: cv);
      await repo.attach('me');
    });

    /// Hand the room list to the repository and let the clock run past the
    /// 1.2s `_scheduleDeliveryReport` debounce that delivery arms. The timer
    /// belongs to the repository rather than the widget, so disposing the tree
    /// does not cancel it and the binding fails the test for it still being
    /// pending. No room here carries an unread count, so nothing is actually
    /// reported — this only lets the timer retire.
    Future<void> deliverRooms(
      WidgetTester tester,
      List<Map<String, dynamic>> rooms,
    ) async {
      cv.sinks['rooms:listUserRooms']!(rooms);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
    }

    testWidgets('waits rather than saying the room is gone', (tester) async {
      // The notification tap: the screen is mounted before the room list has
      // landed. Nothing here has told this device the room does not exist.
      await tester.pumpWidget(host('r1'));
      await tester.pump();

      expect(find.byType(SkeletonBubbles), findsOneWidget);
      expect(find.text('room gone'), findsNothing);

      // Tear down before the ticker and the give-up timer outlive the test.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('and renders the room the moment it arrives', (tester) async {
      await tester.pumpWidget(host('r1'));
      await tester.pump();
      expect(find.text('The Room'), findsNothing);

      await deliverRooms(tester, [_roomWire('r1')]);

      // The room's own chrome, which only the non-null branch builds.
      expect(find.text('The Room'), findsAtLeastNWidgets(1));
      expect(find.text('room gone'), findsNothing);
      // A skeleton is still on screen here and that is correct — it is the
      // TRANSCRIPT's placeholder now, not this branch's. The screen has gone
      // from "we don't know what this room is" to "we know, and its messages
      // are coming", which is the layering working rather than a leftover.

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a room the server\'s own list does not have IS gone',
        (tester) async {
      await tester.pumpWidget(host('r1'));
      await tester.pump();

      // The server answered, and r1 is not in what it said.
      await deliverRooms(tester, [_roomWire('other')]);

      expect(find.text('room gone'), findsOneWidget);
      expect(find.byType(SkeletonBubbles), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an unanswered wait gives up rather than shimmering forever',
        (tester) async {
      // Offline. `PendingPlaceholder` bounds the wait on purpose — a skeleton
      // that never resolves is a worse lie than the empty state.
      await tester.pumpWidget(host('r1'));
      await tester.pump();
      expect(find.byType(SkeletonBubbles), findsOneWidget);

      await tester.pump(const Duration(seconds: 9));

      expect(find.text('room gone'), findsOneWidget);
      expect(find.byType(SkeletonBubbles), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the wait is the placeholder, not an unconditional skeleton',
        (tester) async {
      // Guards the shape: if the branch ever goes back to rendering one state
      // unconditionally, this notices even if the strings still line up.
      await tester.pumpWidget(host('r1'));
      await tester.pump();

      final placeholder = tester.widget<PendingPlaceholder>(
        find.byType(PendingPlaceholder).first,
      );
      expect(placeholder.pending, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  /// The sharpest case, and the whole reason the epitaph gates on
  /// [ChatRepository.hasLiveRoomList] rather than `roomsLoaded`: somebody added
  /// you to a group an hour ago and it pushed you. The disk snapshot is real,
  /// non-empty, and satisfies `roomsLoaded` — and it cannot possibly contain
  /// the room you are being sent to, because it was written before that room
  /// existed.
  ///
  /// Its own group because the setup does REAL file I/O, and real async inside
  /// a `testWidgets` body runs in a fake-async zone where it never completes.
  /// `setUp` is outside that zone, so the cache is on disk and the repository
  /// is attached before the fake clock starts.
  group('a cached list that predates the room', () {
    late Directory tmp;
    late ChatRepository repo;
    late ChatApi api;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('room_gone_cached');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => tmp.path,
          );
      final dir = Directory('${tmp.path}/cache/cold');
      await dir.create(recursive: true);
      await File('${dir.path}/rooms.json')
          .writeAsString(jsonEncode([_roomWire('an-older-room')]));

      api = ChatApi(ConvexBackend.instance);
      repo = ChatRepository(api: _OfflineApi(), cv: _FakeCv());
      await repo.attach('cold');
    });

    tearDown(() async {
      await repo.detach();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    testWidgets('is answered, and still not evidence the room is gone',
        (tester) async {
      expect(
        repo.roomsLoaded,
        isTrue,
        reason: 'the disk snapshot answered — which is exactly the trap',
      );
      expect(repo.hasLiveRoomList, isFalse);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ThemeScope(
              controller: ThemeController(BasicTheme.midnight()),
              child: RoomScreen(roomId: 'r1', repo: repo, api: api),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('room gone'),
        findsNothing,
        reason: 'a room absent from a snapshot written before it existed is '
            'not a room that has been deleted',
      );
      expect(find.byType(SkeletonBubbles), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
