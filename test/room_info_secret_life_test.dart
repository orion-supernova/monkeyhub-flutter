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
import 'package:monkeyhub/models/room_admin.dart';
import 'package:monkeyhub/screens/room_info_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_life_picker.dart';

/// A secret room's info screen edits its message life through the shared
/// [MessageLifePicker]: the clock (after seen / after sent) and the timer are
/// both editable, there is no way back to a regular room, and a change is
/// saved with the clock it was made on. Same harness as the suggestion test.
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

/// Answers the four admin-list reads and nothing else. Everything the seed
/// path wants is refused the way an offline launch refuses it — the room is
/// seeded directly, so none of it is needed.
class _FakeApi extends Fake implements ChatApi {
  _FakeApi(this.mine);

  final List<Map<String, Object?>> updates = [];

  @override
  Future<void> updateRoom({
    required String roomId,
    required String userId,
    required String name,
    String? description,
    bool? isPrivate,
    Duration? messageLifetime,
    String? messageClock,
  }) async {
    updates.add({
      'name': name,
      'messageLifetime': messageLifetime,
      'messageClock': messageClock,
    });
  }


  /// What `roomChangeRequests:mine` returns. Counted, so the test can tell
  /// "asked and got nothing" from "never asked" — which is the entire bug.
  List<RoomChangeRequest> mine;
  int mineCalls = 0;

  @override
  Future<List<RoomChangeRequest>> myRoomChangeRequests({
    required String roomId,
    required String userId,
  }) async {
    mineCalls++;
    return mine;
  }

  @override
  Future<List<RoomChangeRequest>> listRoomChangeRequests({
    required String roomId,
    required String userId,
  }) async => const [];

  @override
  Future<List<RoomJoinRequest>> listJoinRequests({
    required String roomId,
    required String userId,
  }) async => const [];

  @override
  Future<List<PendingRoomInvite>> listRoomInvitations({
    required String roomId,
    required String userId,
  }) async => const [];

  /// `RemoteImage` resolves every storage id through this on mount. Answering
  /// null is the "no URL yet" path, which draws the placeholder and asks for
  /// nothing over the network — enough for `byType(RemoteImage)` to find the
  /// widget and read the id it was given, which is all this test is about.
  ///
  /// Unstubbed, `Fake` throws from inside `initState`, Flutter swaps in an
  /// `ErrorWidget`, and THAT is what produces the 99,000-pixel RenderFlex
  /// overflow further down the log — a cascade, not a layout bug.
  @override
  Future<String?> getFileUrl(String storageId) async => null;

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
}


Map<String, dynamic> _secretWire({String? clock}) => {
      '_id': 'r1',
      'name': 'Hush',
      'createdBy': 'me',
      'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'isPrivate': true,
      'memberCount': 3,
      'type': 'secret',
      'messageLifetime': 30,
      if (clock != null) 'messageClock': clock,
      'participantIds': ['me', 'someone', 'third'],
    };

Map<String, dynamic> _ownerPerms() => {
      'role': 'owner',
      'isGroup': true,
      'canEditRoom': true,
      'canRemoveMembers': true,
      'canAssignAdmins': true,
      'canManageLink': true,
      'canReviewJoinRequests': true,
      'canReviewChangeRequests': true,
      'canSuggestChanges': false,
      'canInvite': true,
      'membersCanInvite': true,
      'linkJoinPolicy': 'open',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;

  setUp(() async {
    cv = _FakeCv();
    api = _FakeApi(const []);
    repo = ChatRepository(api: api, cv: cv);
    await repo.attach('me');
    repo.debugSeedRooms([ChatRoom.fromJson(_secretWire())]);
  });

  tearDown(() async => repo.detach());

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(420, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(420, 3000)),
        child: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RoomInfoScreen(roomId: 'r1', repo: repo, api: api),
          ),
        ),
      ),
    );
    await t.pump();
    cv.sinks['roomAdmin:myPermissions']!(_ownerPerms());
    await settle(t);
  }

  testWidgets('a secret room shows the shared picker, never an off switch',
      (t) async {
    await open(t);
    expect(find.byType(MessageLifePicker), findsOneWidget);
    expect(find.text('After seen'), findsOneWidget);
    expect(find.text('After sent'), findsOneWidget);
  });

  testWidgets('changing the clock saves it with a timer that clock offers',
      (t) async {
    await open(t);
    await t.tap(find.text('After seen'));
    // _pushRoom is debounced/awaited; give it a few frames.
    await t.pump(const Duration(milliseconds: 100));
    await settle(t);
    expect(api.updates, isNotEmpty);
    final last = api.updates.last;
    expect(last['messageClock'], 'seen');
    // 30s is not a "seen" timer, so it lands on the nearest one (10s).
    expect(last['messageLifetime'], const Duration(seconds: 10));
  });
}
