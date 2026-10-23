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
import 'package:monkeyhub/widgets/timeline_list_view.dart';

class _FakeSub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCv extends Fake implements ConvexBackend {
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

class _OfflineApi extends Fake implements ChatApi {
  @override
  Future<List<ChatRoom>> listUserRooms(String u) async =>
      throw StateError('offline');
  @override
  Future<List<ChatUser>> listFriends(String u) async =>
      throw StateError('offline');
  @override
  Future<List<FriendRequest>> listIncomingDirectRequests(String u) async =>
      throw StateError('offline');
  @override
  Future<List<FriendRequest>> listOutgoingDirectRequests(String u) async =>
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
  @override
  Future<void> markRoomDelivered({
    required String roomId,
    required String userId,
    DateTime? upTo,
  }) async {}
}

/// Lets real async work (isolates, microtask chains, the repository's
/// subscriptions) finish, polling [done] instead of sleeping a fixed time. A
/// fixed 100 ms was enough alone and not under a loaded full-suite run, where
/// `cv.sinks['messages:list']` could still be unregistered.
Future<void> _until(
  WidgetTester tester,
  bool Function() done, {
  String what = 'condition',
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for $what');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('Saved Messages date scrolling does not rebuild the transcript', (
    tester,
  ) async {
    final cv = _FakeCv();
    final api = _OfflineApi();
    final repo = ChatRepository(api: api, cv: cv);
    await tester.runAsync(() => repo.attach('me'));
    cv.sinks['rooms:listUserRooms']!([
      {
        '_id': 'saved',
        'name': 'Saved Messages',
        'createdBy': 'me',
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'isPrivate': true,
        'memberCount': 1,
        'participantIds': ['me'],
        'isMember': true,
        'unreadCount': 0,
      },
    ]);
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RoomScreen(
            roomId: 'saved',
            repo: repo,
            api: ChatApi(ConvexBackend.instance),
          ),
        ),
      ),
    );
    await _until(
      tester,
      () => cv.sinks.containsKey('messages:list'),
      what: 'the transcript subscription',
    );
    cv.sinks['messages:list']!([
      for (var i = 0; i < 30; i++)
        {
          '_id': 'm$i',
          'roomId': 'saved',
          'userId': 'me',
          'content': 'Saved text $i\nAnother line\nA third line',
          'type': 'text',
          'createdAt': DateTime(2026, 9, i + 1).millisecondsSinceEpoch,
        },
    ]);
    await _until(
      tester,
      () => find.textContaining('Saved text').evaluate().isNotEmpty,
      what: 'the saved messages to render',
    );
    await tester.pump(const Duration(milliseconds: 300));
    final finder = find.byType(TimelineListView);
    expect(finder, findsOneWidget);
    final transcript = tester.widget<TimelineListView>(finder);
    transcript.controller.jumpTo(600);
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      identical(tester.widget(finder), transcript),
      isTrue,
      reason: 'starting the date overlay must not rebuild every message',
    );
    final gesture = await tester.startGesture(const Offset(400, 250));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        identical(tester.widget(finder), transcript),
        isTrue,
        reason:
            'divider overlap at scroll frame $i must update only the overlay',
      );
    }
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    expect(
      identical(tester.widget(finder), transcript),
      isTrue,
      reason: 'static saved history must not rebuild on the one-second clock',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repo.detach);
    await tester.pump(const Duration(seconds: 1));
  });
}
