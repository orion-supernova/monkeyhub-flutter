import 'dart:async';

import 'package:flutter/material.dart';
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

/// The UNREAD MESSAGES divider, end to end, on the three entries a notification
/// tap actually takes. `room_unread_anchor_test.dart` pins the repository rule
/// underneath; this mounts the real screen and looks for the label, because
/// every one of these bugs was a disagreement between the two.
///
/// The tap is the hard case for one reason: it opens the room BEFORE the room
/// list has caught up with the push that caused it. A cold start has no list at
/// all; a warm one holds the counts as they stood when the app went away. The
/// gate that used to arm this read `unreadCount > 0` off exactly that list, so
/// it answered "nothing unread" on precisely the entries the divider exists for
/// — which is why the label only ever appeared off a chat-list tap.
///
/// Note the `runAsync` calls. `openRoom` reads the disk cache, and a widget
/// test's fake clock will not carry real file I/O across a `pump` — without
/// them `messages:list` is never even subscribed and the test passes or fails
/// for the wrong reason.

class _FakeSub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCv extends Fake implements ConvexBackend {
  final Map<String, void Function(dynamic)> sinks = {};
  @override
  Future<Subscription> subscribe(String name, Map<String, dynamic> args,
      {required void Function(dynamic) onData,
      void Function(Object error)? onError}) async {
    sinks[name] = onData;
    return _FakeSub();
  }
  @override
  bool get isConnected => true;
  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _OfflineApi extends Fake implements ChatApi {
  final List<({String roomId, DateTime? upTo})> reads = [];
  @override
  Future<List<ChatRoom>> listUserRooms(String u) async => throw StateError('offline');
  @override
  Future<List<ChatUser>> listFriends(String u) async => throw StateError('offline');
  @override
  Future<List<FriendRequest>> listIncomingDirectRequests(String u) async => throw StateError('offline');
  @override
  Future<List<FriendRequest>> listOutgoingDirectRequests(String u) async => throw StateError('offline');
  @override
  Future<List<ChatMessage>> listMessages({required String roomId, int limit = 100, String? viewerUserId}) async =>
      throw StateError('offline');
  @override
  Future<void> markRoomRead({required String roomId, required String userId, DateTime? upTo}) async {
    reads.add((roomId: roomId, upTo: upTo));
  }
  @override
  Future<void> clearTyping({required String roomId, required String userId}) async {}
  @override
  Future<void> markRoomDelivered({required String roomId, required String userId}) async {}
}

final t0 = DateTime.fromMillisecondsSinceEpoch(
    DateTime(2026, 3, 1, 12, 0).millisecondsSinceEpoch);
final t1 = t0.add(const Duration(minutes: 30));

Map<String, dynamic> roomWire(String id,
        {DateTime? lastReadAt, DateTime? lastMessageTime, int unreadCount = 0}) =>
    {
      '_id': id,
      'name': 'The Room',
      'createdBy': 'someone',
      'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'isPrivate': false,
      'memberCount': 2,
      'participantIds': ['me', 'someone'],
      'isMember': true,
      if (lastReadAt != null) 'lastReadAt': lastReadAt.millisecondsSinceEpoch,
      if (lastMessageTime != null) 'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
    };

Map<String, dynamic> msgWire(String id, String sender, DateTime at) => {
      '_id': id,
      'roomId': 'r1',
      'userId': sender,
      'content': 'msg $id',
      'type': 'text',
      'createdAt': at.millisecondsSinceEpoch,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _OfflineApi api;
  late ChatRepository repo;

  Widget host() => MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: RoomScreen(roomId: 'r1', repo: repo, api: ChatApi(ConvexBackend.instance)),
          ),
        ),
      );

  setUp(() async {
    cv = _FakeCv();
    api = _OfflineApi();
    repo = ChatRepository(api: api, cv: cv);
    await repo.attach('me');
  });

  testWidgets('COLD tap: screen mounts before the room list exists', (t) async {
    // A fresh process: nothing attached, nothing in _rooms. This is what
    // _bootstrap does on a notification tap.
    final cold = ChatRepository(api: api, cv: cv);
    Widget coldHost() => MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ThemeScope(
              controller: ThemeController(BasicTheme.midnight()),
              child: RoomScreen(
                  roomId: 'r1', repo: cold, api: ChatApi(ConvexBackend.instance)),
            ),
          ),
        );

    await t.pumpWidget(coldHost());
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    expect(
      cold.unreadAnchorSettled('r1'),
      isFalse,
      reason: 'there is no room list to answer from yet — and no answer is '
          'not the same as "nothing unread"',
    );

    // attach lands (the seed throws offline, so only the subscription answers).
    await t.runAsync(() => cold.attach('me'));
    await t.pump();
    cv.sinks['rooms:listUserRooms']!([
      roomWire('r1', lastReadAt: t0, lastMessageTime: t1, unreadCount: 1),
    ]);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump();
    expect(cold.unreadAnchorFor('r1'), t0,
        reason: 'the cursor arrives with the list, a beat after the screen');

    cv.sinks['messages:list']!([
      msgWire('m0', 'someone', t0),
      msgWire('m1', 'someone', t1),
    ]);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('UNREAD MESSAGES'), findsOneWidget);
    expect(api.reads.map((r) => r.upTo), contains(t1),
        reason:
            'a room opened before `attach` published a user id used to stay '
            'subscribed read-blind for the rest of the session');
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('TAP on the room already on screen (pop + push, same roomId)', (t) async {
    cv.sinks['rooms:listUserRooms']!([
      roomWire('r1', lastReadAt: t0, lastMessageTime: t0, unreadCount: 0),
    ]);
    await t.pump();

    // A real navigator, because the ordering IS the test. `_openRoomFromPush`
    // pops to the shell and pushes in the same breath, so the replacement
    // screen's `initState` runs while the outgoing screen is still mounted —
    // its `dispose` (and the `closeRoom` inside it) lands a frame or more
    // later. Tearing the first screen down first, as a bare `pumpWidget`
    // swap does, hands the second one a repository that has already reset
    // itself, which is the one state this can never be in.
    final nav = GlobalKey<NavigatorState>();
    final themes = ThemeController(BasicTheme.midnight());
    Widget screen() => RoomScreen(
        roomId: 'r1', repo: repo, api: ChatApi(ConvexBackend.instance));
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: MaterialApp(
        navigatorKey: nav,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Above the navigator, not inside `home`: a pushed route is a sibling
        // of the home route, not a descendant of it.
        builder: (_, child) => ThemeScope(controller: themes, child: child!),
        home: const Scaffold(body: SizedBox()),
      ),
    ));

    // Screen 1: reading the room, everything read.
    unawaited(nav.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => screen())));
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump();
    cv.sinks['messages:list']!([msgWire('m0', 'someone', t0)]);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await t.pumpAndSettle();
    expect(find.text('UNREAD MESSAGES'), findsNothing,
        reason: 'nothing was unread when this screen opened');
    api.reads.clear();

    // Backgrounded. NOTHING is delivered here, and that is the whole point:
    // iOS suspends the process, the socket freezes, and the message that
    // raises the banner never reaches this device over the wire. It arrives
    // only once the tap has woken everything back up.

    // The tap, exactly as `_openRoomFromPush` does it.
    nav.currentState!.popUntil((r) => r.isFirst);
    unawaited(nav.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => screen())));
    await t.pumpAndSettle();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pumpAndSettle();

    // Now the socket comes back and the transcript catches up.
    cv.sinks['messages:list']!([
      msgWire('m0', 'someone', t0),
      msgWire('m1', 'someone', t1),
    ]);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await t.pumpAndSettle();

    expect(
      repo.unreadAnchorFor('r1'),
      t0,
      reason:
          'the replacement screen pins its own reading session; the anchor is '
          'not inherited from the screen it is replacing',
    );
    expect(
      find.text('UNREAD MESSAGES'),
      findsOneWidget,
      reason:
          'a new screen is a new reading session even when the room did not '
          'change, so nothing the previous one had already settled may be '
          'carried into it',
    );
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('WARM tap: room list already known, transcript arrives after', (t) async {
    // The stale-but-true room list the backgrounded app is holding.
    cv.sinks['rooms:listUserRooms']!([
      roomWire('r1', lastReadAt: t0, lastMessageTime: t0, unreadCount: 0),
    ]);
    await t.pump();

    await t.pumpWidget(host());
    // The disk-cache read inside openRoom is real file I/O, which a widget
    // test's fake clock will not advance past — see [runAsync].
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(
      repo.unreadAnchorFor('r1'),
      t0,
      reason:
          'the backgrounded list has a stale unreadCount but a true cursor, '
          'and the cursor is the half the divider is drawn from',
    );

    expect(
      find.text('UNREAD MESSAGES'),
      findsNothing,
      reason: 'nothing past the cursor is loaded yet, so there is no row to mark',
    );

    // The transcript lands with the message the banner was for.
    cv.sinks['messages:list']!([
      msgWire('m0', 'someone', t0),
      msgWire('m1', 'someone', t1),
    ]);
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(seconds: 2));

    expect(
      find.text('UNREAD MESSAGES'),
      findsOneWidget,
      reason:
          'this is the tap the label never used to appear on: the old gate '
          'read `unreadCount > 0` off the frozen list and saw the pre-push zero',
    );
    expect(api.reads.map((r) => r.upTo), contains(t1),
        reason: 'and the room the reader just read has to stop being unread');

    await t.pump(const Duration(seconds: 2));
  });
}
