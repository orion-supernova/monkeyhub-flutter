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
import 'package:monkeyhub/widgets/remote_image.dart';

/// A member's own pending suggestion vanished when they left Room Info and
/// came back.
///
/// `_loadAdminState` opens the `roomAdmin:myPermissions` subscription and then
/// immediately runs `_refreshAdminLists`, which asks for the caller's pending
/// suggestions ONLY IF `_perms.canSuggestChanges`. At that instant `_perms` is
/// still `RoomPermissions.none` — every flag false — so it asks for nothing.
/// The subscription's first answer then arrived and the refresh behind it was
/// gated on `next.isAdmin != wasAdmin`, which for a plain member is
/// `false != false`. So the list was never fetched at all.
///
/// It looked like it worked because proposing something calls
/// `_refreshAdminLists` directly, with permissions by then in hand. Leaving
/// the screen and returning was the first moment anybody saw the real
/// behaviour, which is exactly how it was reported.
///
/// The ordering here is the whole test: permissions MUST arrive after the
/// first frame, because that is the race.

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
      'name': 'The Group',
      'createdBy': 'someone',
      'createdAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'isPrivate': false,
      'memberCount': 3,
      'participantIds': ['me', 'someone', 'third'],
    };

/// What the server sends a plain member of a group.
Map<String, dynamic> _memberPerms() => {
      'role': 'member',
      'isGroup': true,
      'canEditRoom': false,
      'canRemoveMembers': false,
      'canAssignAdmins': false,
      'canManageLink': false,
      'canReviewJoinRequests': false,
      'canReviewChangeRequests': false,
      'canSuggestChanges': true,
      'canInvite': true,
      'membersCanInvite': true,
      'linkJoinPolicy': 'open',
    };

RoomChangeRequest _photoSuggestion() => RoomChangeRequest.fromJson({
      'requestId': 'cr1',
      'field': 'avatar',
      'storageId': 'kg2thephoto',
      'createdAt': DateTime(2026, 1, 2).millisecondsSinceEpoch,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;

  setUp(() async {
    cv = _FakeCv();
    api = _FakeApi([_photoSuggestion()]);
    repo = ChatRepository(api: api, cv: cv);
    await repo.attach('me');
    repo.debugSeedRooms([ChatRoom.fromJson(_groupWire())]);
  });

  tearDown(() async => repo.detach());

  Future<void> pumpInfo(WidgetTester t) async {
    await t.pumpWidget(
      // A size, or the scroller lays out at zero height and nothing paints —
      // see the note in the repo about widget-test hosts needing one.
      MediaQuery(
        data: const MediaQueryData(size: Size(420, 900)),
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
  }

  /// `pumpAndSettle` never returns here: the member list draws `SkeletonRows`
  /// while the roster is pending and that shimmer animates forever. Pump a
  /// fixed number of frames instead, which is enough for the awaited refresh
  /// to land and rebuild.
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('a member\'s own suggestion survives the permissions race',
      (t) async {
    await pumpInfo(t);

    // The screen has mounted and done its one-shot load, and permissions have
    // NOT arrived. Nothing should have been asked for yet — this is the state
    // the bug was born in, and asserting it here is what makes the assertion
    // below meaningful rather than accidental.
    expect(
      api.mineCalls,
      0,
      reason: 'with no permissions yet, the screen cannot know it may ask',
    );

    // Now the subscription answers, exactly as it does a round trip after the
    // screen opens.
    cv.sinks['roomAdmin:myPermissions']!(_memberPerms());
    await settle(t);

    expect(
      api.mineCalls,
      greaterThan(0),
      reason: 'permissions arriving is the moment the screen learns it may '
          'ask — the refresh behind it must not be gated on isAdmin, which '
          'never changes for a plain member',
    );
    expect(find.text('Take back'), findsOneWidget);
  });

  testWidgets('and it shows WHAT was suggested, not just that something was',
      (t) async {
    await pumpInfo(t);
    cv.sinks['roomAdmin:myPermissions']!(_memberPerms());
    await settle(t);

    // The row used to be a generic camera glyph beside "A new group picture",
    // which tells the person who picked it nothing they did not already know
    // and gave them no way to check WHICH picture is pending before deciding
    // to take it back. The thumbnail is the answer, so it has to be drawn
    // from the proposal's own storage id.
    final images = t.widgetList<RemoteImage>(find.byType(RemoteImage));
    expect(
      images.any((i) => i.storageId == 'kg2thephoto'),
      isTrue,
      reason: 'the pending photo suggestion must render its own picture',
    );
  });

  testWidgets('nothing is drawn when there is nothing pending', (t) async {
    api.mine = const [];
    await pumpInfo(t);
    cv.sinks['roomAdmin:myPermissions']!(_memberPerms());
    await settle(t);

    expect(api.mineCalls, greaterThan(0));
    expect(find.text('Take back'), findsNothing);
  });
}
