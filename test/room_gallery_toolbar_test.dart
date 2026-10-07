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
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/fullscreen_image_viewer.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/screens/room_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/steady_hero.dart';
import 'package:monkeyhub/widgets/viewer_chrome.dart';

/// The chat is where most pictures are opened from, so the gallery it opens
/// must carry the toolbar. It once did only from room info: the transcript's
/// `MediaPagerScreen.open` was the one call site that never passed actions,
/// and the preview harness — which passes its own — could not show it.

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
  Future<void> markRoomRead({required String roomId, required String userId, DateTime? upTo}) async {}
  @override
  Future<void> clearTyping({required String roomId, required String userId}) async {}
  @override
  Future<void> markRoomDelivered({required String roomId, required String userId, DateTime? upTo}) async {}
}

final t0 = DateTime.fromMillisecondsSinceEpoch(
    DateTime(2026, 3, 1, 12, 0).millisecondsSinceEpoch);

Map<String, dynamic> photoWire(String id, DateTime at) => {
      '_id': id,
      'roomId': 'r1',
      'userId': 'someone',
      'content': '',
      'type': 'image',
      'mediaStorageId': 'blob_$id',
      'mediaWidth': 800,
      'mediaHeight': 600,
      'createdAt': at.millisecondsSinceEpoch,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a photo tapped in the transcript opens a gallery WITH a toolbar',
      (t) async {
    final cv = _FakeCv();
    final repo = ChatRepository(api: _OfflineApi(), cv: cv);
    await t.runAsync(() => repo.attach('me'));
    cv.sinks['rooms:listUserRooms']!([
      {
        '_id': 'r1',
        'name': 'The Room',
        'createdBy': 'someone',
        'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'isPrivate': false,
        'memberCount': 2,
        'participantIds': ['me', 'someone'],
        'isMember': true,
        'unreadCount': 0,
      },
    ]);

    // The scope sits ABOVE the app: the pager is a root-navigator route.
    await t.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RoomScreen(
              roomId: 'r1', repo: repo, api: ChatApi(ConvexBackend.instance)),
        ),
      ),
    ));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();
    cv.sinks['messages:list']!([
      photoWire('p1', t0),
      photoWire('p2', t0.add(const Duration(minutes: 1))),
    ]);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(repo.timelineFor('r1'), hasLength(2));
    expect(find.byType(SteadyHero), findsWidgets);
    await t.tap(find.byType(SteadyHero).first);
    // Bounded: an unresolved image's shimmer schedules frames forever.
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }

    expect(find.byType(MediaPagerScreen), findsOneWidget);
    expect(find.byType(ViewerToolbar), findsOneWidget,
        reason: 'Share, Save and Forward belong to the chat gallery too');
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('a lone photo (no room behind it) still gets Share and Save',
      (t) async {
    // The thread sheet and the lifted actions preview build bubbles outside
    // the room's gallery scope, so they open the single viewer — which used
    // to have no toolbar at all.
    final m = ChatMessage(
      id: 'm1',
      roomId: 'r',
      senderId: 'alice',
      senderName: 'alice',
      content: '',
      createdAt: DateTime(2026, 3, 1, 12),
      type: MessageType.image,
      mediaStorageId: 'blob_m1',
      mediaWidth: 800,
      mediaHeight: 600,
    );
    await t.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 500,
              child: MessageBubble(
                message: m,
                now: DateTime(2026, 3, 1, 12),
                currentUserId: 'bob',
                api: ChatApi(ConvexBackend.instance),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.byType(SteadyHero));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(FullscreenImageViewer), findsOneWidget);
    final bar = t.widget<ViewerToolbar>(find.byType(ViewerToolbar));
    expect(bar.actions, hasLength(2), reason: 'Share and Save');
  });
}
