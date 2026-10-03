// Renders the room-admin and call sheets restyled in round 2.
//
//   flutter test test/design_preview/admin_sheets_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/calls/call_options_sheet.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/group_call_sheets.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/room_admin.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:monkeyhub/widgets/room_change_requests_sheet.dart';
import 'package:monkeyhub/widgets/room_invite_friends_sheet.dart';
import 'package:monkeyhub/widgets/room_join_requests_sheet.dart';
import 'package:monkeyhub/widgets/room_member_actions_sheet.dart';
import 'package:monkeyhub/widgets/server_role_sheet.dart';

import 'preview_kit.dart';

final _now = DateTime.now();
ChatUser _u(String id, String name) =>
    ChatUser(id: id, username: id, name: name, lastSeen: _now);
final _people = [
  _u('ece', 'Ece Yıldız'),
  _u('deniz', 'Deniz Kaya'),
  _u('arda', 'Arda'),
  _u('selin', 'Selin'),
  _u('kerem', 'Kerem'),
];

class _FakeApi extends Fake implements ChatApi {
  @override
  Future<List<ChatUser>> getMembers(String roomId, {String? viewerUserId}) async =>
      _people;
}

class _FakeRepo extends Fake implements ChatRepository {
  @override
  Future<List<RoomJoinRequest>> listJoinRequests(String roomId) async => [
        for (final p in _people.take(3))
          RoomJoinRequest(requestId: p.id, user: p, createdAt: _now),
      ];

  @override
  Future<List<RoomChangeRequest>> listRoomChangeRequests(String roomId) async =>
      [
        RoomChangeRequest(
          requestId: 'n',
          field: RoomChangeField.name,
          createdAt: _now,
          value: 'Weekend Crew 🏕',
          currentValue: 'Weekend Crew',
          user: _people[1],
        ),
        RoomChangeRequest(
          requestId: 'd',
          field: RoomChangeField.description,
          createdAt: _now,
          value: 'Plans, recipes and terrible puns.',
          currentValue: 'Weekend plans',
          user: _people[0],
        ),
      ];

  @override
  Future<List<ChatUser>> invitableFriends(String roomId) async => _people;
}

class _FakeCall extends Fake implements CallService {}

class _FakeGroupCall extends Fake implements GroupCallService {}

const _admin = RoomPermissions(
  role: RoomRole.owner,
  isGroup: true,
  canEditRoom: true,
  canRemoveMembers: true,
  canAssignAdmins: true,
  canManageLink: true,
  canReviewJoinRequests: true,
  canReviewChangeRequests: true,
  canSuggestChanges: true,
  canInvite: true,
  membersCanInvite: true,
  linkJoinPolicy: RoomJoinPolicy.open,
);

/// A plain page behind the sheet, so the dim and the corner read.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.anchor});
  final GlobalKey anchor;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      key: anchor,
      backgroundColor: theme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Weekend Crew', style: theme.displayLarge),
            for (var i = 0; i < 8; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text('Message $i', style: theme.body),
              ),
          ],
        ),
      ),
    );
  }
}

typedef _Opener = void Function(BuildContext context);

final api = _FakeApi();
final repo = _FakeRepo();

final Map<String, _Opener> _sheets = {
  'members': (c) => showRoomMemberActions(
        c,
        member: _people[0],
        memberRole: RoomRole.admin,
        permissions: _admin,
        api: api,
        isSelf: false,
      ),
  'join': (c) =>
      showRoomJoinRequestsSheet(c, repo: repo, api: api, roomId: 'r'),
  'change': (c) =>
      showRoomChangeRequestsSheet(c, repo: repo, api: api, roomId: 'r'),
  'invite': (c) =>
      showRoomInviteFriendsSheet(c, repo: repo, api: api, roomId: 'r'),
  'server': (c) => showServerRoleInfo(c),
  'callopts': (c) => showAdaptiveSheet<void>(
        c,
        builder: (_) =>
            CallOptionsSheet(service: _FakeCall(), showVideoQuality: true),
      ),
  'groupcall': (c) => showStartGroupCallSheet(
        c,
        service: _FakeGroupCall(),
        api: api,
        roomId: 'r',
        myUserId: 'me',
      ),
};

void main() {
  setUpAll(loadPreviewFonts);
  for (final id in ['basic', 'basic_daylight', 'paper']) {
    for (final entry in _sheets.entries) {
      testWidgets('admin sheet ${entry.key}: $id', (tester) async {
        final anchor = GlobalKey();
        await snap(
          tester,
          previewApp(ThemeController.byId(id), _Backdrop(anchor: anchor)),
          'adm_${entry.key}_$id.png',
          act: () async {
            entry.value(anchor.currentContext!);
            await tester.pump();
          },
        );
      });
    }
  }
}
