// Renders a group's Room Info page under a few themes. Not a test — run by
// path:
//
//   flutter test test/design_preview/room_info_preview.dart
//
// The fakes are lifted from test/room_suggestion_visibility_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/models/room_admin.dart';
import 'package:monkeyhub/screens/room_info_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

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

Map<String, dynamic> _groupWire() => {
      '_id': 'r1',
      'name': 'Weekend Crew',
      'createdBy': 'someone',
      'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'isPrivate': false,
      'memberCount': 3,
      'description': 'Weekend plans, recipes and terrible puns.',
      'participantIds': ['me', 'someone', 'third'],
    };

/// What the server sends a plain member of a group.
Map<String, dynamic> _memberPerms() => {
      'role': 'admin',
      'isGroup': true,
      'canEditRoom': true,
      'canRemoveMembers': false,
      'canAssignAdmins': false,
      'canManageLink': true,
      'canReviewJoinRequests': false,
      'canReviewChangeRequests': false,
      'canSuggestChanges': true,
      'canInvite': true,
      'membersCanInvite': true,
      'linkJoinPolicy': 'open',
    };


void main() {
  setUpAll(loadPreviewFonts);

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cv = _FakeCv();
    api = _FakeApi(const []);
    repo = ChatRepository(api: api, cv: cv);
    await repo.attach('me');
    repo.debugSeedRooms([ChatRoom.fromJson(_groupWire())]);
  });

  tearDown(() async => repo.detach());

  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    testWidgets('room info preview: $id', (tester) async {
      await snap(
        tester,
        previewApp(
          ThemeController.byId(id),
          RoomInfoScreen(roomId: 'r1', repo: repo, api: api),
        ),
        'room_info_$id.png',
        size: const Size(393, 1500),
        dpr: 2,
        act: () async {
          // Permissions arrive a round trip after the page mounts.
          cv.sinks['roomAdmin:myPermissions']?.call(_memberPerms());
        },
      );
    });
  }
}
