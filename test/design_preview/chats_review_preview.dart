// Design review: every chats-area sheet / menu not already covered by
// sheets_preview / chat_sheets_preview / admin_sheets_preview, under Midnight,
// Daylight and Risograph Pop, plus a Turkish @1.3x pass of the busiest ones.
//
//   flutter test test/design_preview/chats_review_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/family.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/models/message_reaction.dart';
import 'package:monkeyhub/models/room_admin.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/models/room_pin.dart';
import 'package:monkeyhub/models/scheduled_message.dart';
import 'package:monkeyhub/share/shared_payload.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:monkeyhub/widgets/archived_chats_sheet.dart';
import 'package:monkeyhub/widgets/block_choice_sheet.dart';
import 'package:monkeyhub/widgets/chat_row_action_menu.dart';
import 'package:monkeyhub/widgets/destructive_sheet.dart';
import 'package:monkeyhub/widgets/forward_target_sheet.dart';
import 'package:monkeyhub/widgets/join_room_sheet.dart';
import 'package:monkeyhub/widgets/link_confirm_sheet.dart';
import 'package:monkeyhub/widgets/link_input_sheet.dart';
import 'package:monkeyhub/widgets/location_share_sheet.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:monkeyhub/widgets/mute_room_sheet.dart';
import 'package:monkeyhub/widgets/new_chat_menu.dart';
import 'package:monkeyhub/widgets/password_prompt_sheet.dart';
import 'package:monkeyhub/widgets/pinned_list_sheet.dart';
import 'package:monkeyhub/widgets/reaction_details_sheet.dart';
import 'package:monkeyhub/widgets/reaction_picker_sheet.dart';
import 'package:monkeyhub/widgets/remove_contact_sheet.dart';
import 'package:monkeyhub/widgets/report_sheet.dart';
import 'package:monkeyhub/widgets/room_invite_sheet.dart';
import 'package:monkeyhub/widgets/room_member_actions_sheet.dart';
import 'package:monkeyhub/widgets/scheduled_list_sheet.dart';
import 'package:monkeyhub/widgets/schedule_message_sheet.dart';
import 'package:monkeyhub/widgets/share_target_sheet.dart';
import 'package:monkeyhub/screens/create_room_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

final _now = DateTime.now();
ChatUser _u(String id, String name) =>
    ChatUser(id: id, username: id, name: name, lastSeen: _now);
final _people = [
  _u('ece', 'Ece Yıldız'),
  _u('deniz', 'Deniz Kaya'),
  _u('arda', 'Arda'),
  _u('selin', 'Selin Karaosmanoğlu'),
  _u('kerem', 'Kerem'),
  _u('mert', 'Mert'),
];

ChatRoom _room(String id, String name,
        {int members = 6, String? last, bool archived = false,
        int unread = 0}) =>
    ChatRoom(
      id: id,
      name: name,
      createdBy: 'me',
      createdAt: DateTime(2026),
      isPrivate: true,
      memberCount: members,
      lastMessage: last,
      lastMessageTime: _now.subtract(const Duration(hours: 3)),
      isArchived: archived,
      unreadCount: unread,
      isMember: true,
      participantIds: const [],
      description: 'Weekly picks, Sunday screenings, no spoilers.',
    );

final _rooms = [
  _room('crew', 'Weekend Crew', last: 'Deniz: who is driving?'),
  _room('film', 'Istanbul Film Club', members: 248, last: 'Sunday: Uzak'),
  _room('flat', 'Flat 4B', members: 4, last: 'who left the oven on'),
  _room('fam', 'Family', members: 5, last: 'Mom: did you eat?'),
  _room('work', 'Product team — Q4 planning and release coordination',
      members: 14, last: 'Retro moved to Friday'),
];
final _archived = [
  _room('old', 'Old flatmates', archived: true, last: 'see you around!'),
  _room('trip', 'Bodrum trip 2025', archived: true, unread: 3,
      last: 'photos are up'),
];

const _caps = RoomCapabilities(
  canCall: false,
  canLeave: true,
  canDelete: false,
  hasDescription: false,
  hasMembers: true,
  hasPeerHandle: false,
  canEditSettings: false,
  canOpenPeerProfile: false,
  canReceiveForwards: true,
  canSaveMessages: true,
  canMute: true,
);

ChatMessage _msg(String id, String who, String text, {int min = 0}) =>
    ChatMessage(
      id: id,
      roomId: 'crew',
      senderId: who,
      senderName: who == 'me' ? 'Murat' : who,
      content: text,
      createdAt: _now.subtract(Duration(minutes: min)),
      reactions: [
        for (final (i, p) in _people.take(4).indexed)
          MessageReaction(
            id: 'x$i',
            messageId: id,
            userId: p.id,
            emoji: i.isEven ? '❤️' : '😂',
            createdAt: _now,
          ),
      ],
    );

final _pins = [
  RoomPin(
    message: _msg('p1', 'ece', 'Address: Moda Cd. 112, ring twice', min: 600),
    pinnedAt: _now,
    pinnedBy: 'ece',
  ),
  RoomPin(
    message: _msg('p2', 'deniz',
        'Reminder: tickets are €25 each, pay Arda before Friday or he will not stop asking', min: 90),
    pinnedAt: _now,
    pinnedBy: 'me',
  ),
];

final _scheduled = [
  ScheduledMessage(
    id: 's1',
    roomId: 'crew',
    content: 'happy birthday! 🎂 can’t wait for tonight',
    sendAt: _now.add(const Duration(hours: 9)),
    createdAt: _now,
  ),
  ScheduledMessage(
    id: 's2',
    roomId: 'crew',
    content: 'don’t forget the tickets',
    sendAt: _now.add(const Duration(days: 3)),
    createdAt: _now,
  ),
  ScheduledMessage(
    id: 's3',
    roomId: 'crew',
    content: 'reminder: rent is due',
    sendAt: _now.subtract(const Duration(hours: 1)),
    createdAt: _now,
    pending: false,
    failedReason: 'NOT_A_MEMBER',
    failedAt: _now,
  ),
];

class _FakeApi extends Fake implements ChatApi {
  @override
  Future<List<ChatUser>> getMembers(String roomId, {String? viewerUserId}) async =>
      _people;
}

class _FakeRepo extends Fake implements ChatRepository {
  @override
  String? get userId => 'me';
  @override
  List<ChatUser> get friends => _people;
  @override
  List<ChatRoom> get rooms => _rooms;
  @override
  bool get roomsLoaded => true;
  @override
  List<ChatRoom> get archivedRooms => _archived;
  @override
  ChatApi get api => _FakeApi();
  @override
  RoomCapabilities capabilitiesFor(ChatRoom room) => _caps;
  @override
  ChatUser? otherUserFor(ChatRoom room) => null;
  @override
  ChatUser? userById(String id) =>
      _people.where((p) => p.id == id).firstOrNull;
  @override
  List<ChatUser> typingIn(String roomId) => const [];
  @override
  List<ChatMessage> messagesFor(String roomId) => const [];
  @override
  List<RoomPin> pinsFor(String roomId) => _pins;
  @override
  List<ScheduledMessage> scheduledFor(String roomId) => _scheduled;
  @override
  ChatMessage? findMessageInRoom(String roomId, String id) =>
      _msg(id, 'ece', 'hi');
  @override
  Future<RoomInviteLink?> roomInviteLink(String roomId) async => RoomInviteLink(
        inviteId: 'i1',
        code: 'K7M2XQ94RB',
        formattedCode: 'K7M2-XQ94-RB',
        createdAt: _now,
        useCount: 3,
        expiresAt: _now.add(const Duration(days: 6)),
        maxUses: 25,
      );
  @override
  Future<List<ChatUser>> invitableFriends(String roomId) async => _people;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

final _repo = _FakeRepo();
final _api = _FakeApi();

const _owner = RoomPermissions(
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

final _bubbleKey = GlobalKey();
final _rowKey = GlobalKey();

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
            const SizedBox(height: 20),
            Container(
              key: _rowKey,
              height: 72,
              color: theme.surface,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(12),
              child: Text('Weekend Crew', style: theme.bodyEmph),
            ),
            const SizedBox(height: 120),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                key: _bubbleKey,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.surfaceRaised,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text('are you still coming tonight?',
                    style: theme.body),
              ),
            ),
            for (var i = 0; i < 6; i++)
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

Widget _bubble(BuildContext c) {
  final theme = ThemeScope.of(c);
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.surfaceRaised,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text('are you still coming tonight?', style: theme.body),
  );
}

final Map<String, _Opener> _sheets = {
  'newchat': (c) => showNewChatMenu(c,
      repo: _repo, api: _api, canCreateRoom: true, canJoinByCode: true),
  'create': (c) => showAdaptiveSheet(c,
      useSafeArea: true,
      builder: (_) => CreateRoomSheet(repo: _repo, api: _api)),
  'joinroom': (c) => showJoinRoomSheet(c, _rooms[1], _api),
  'archived': (c) => showArchivedChatsSheet(c, repo: _repo, api: _api),
  'reactpick': (c) => showReactionPicker(c),
  'reactdetails': (c) => showReactionDetailsSheet(
        c,
        repo: _repo,
        api: _api,
        roomId: 'crew',
        messageId: 'm1',
        fallback: const [],
        currentUserId: 'me',
        initialEmoji: '❤️',
        resolveUser: (id) => _people.where((p) => p.id == id).firstOrNull,
        onOpenProfile: (_) {},
      ),
  'pinned': (c) => showPinnedListSheet(c,
      repo: _repo, api: _api, roomId: 'crew', onJump: (_) {}),
  'scheduled': (c) => showScheduledListSheet(c, repo: _repo, roomId: 'crew'),
  'schededit': (c) => showScheduledEditSheet(c,
      initial: 'happy birthday! 🎂 can’t wait for tonight'),
  'schedule': (c) => showScheduleMessageSheet(c,
      preview: 'happy birthday! 🎂 can’t wait for tonight', queuedCount: 2),
  'forward': (c) => showForwardTargetSheet(c,
      repo: _repo, messageCount: 3, excludeRoomId: 'none'),
  'share': (c) => showShareTargetSheet(c,
      repo: _repo,
      api: _api,
      payload: const SharedPayload(text: 'https://example.com/a-long-article')),
  'linkinput': (c) => showLinkInputSheet(c),
  'linkconfirm': (c) => showLinkConfirmSheet(c,
      url: 'https://very-long-domain-name.example.com/path/to/something?ref=abc'),
  'location': (c) => showLocationShareSheet(c),
  'locbg': (c) => showLiveShareBackgroundSheet(c),
  'mute': (c) => showMuteRoomSheet(c, repo: _repo, room: _rooms[0]),
  'report': (c) => showReportSheet(c),
  'block': (c) => showBlockChoiceSheet(c,
      displayName: 'Deniz Kaya',
      isFriend: true,
      sharedGroupRooms: _rooms.take(2).toList(),
      hasDm: true,
      api: _api),
  'removecontact': (c) => showRemoveContactSheet(c,
      contactName: 'Deniz Kaya',
      childName: 'Ada',
      preview: ContactRemovalPreview(
        dmCount: 1,
        messageCount: 342,
        lastMessageAt: _now,
        sharedGroupRooms: [
          RoomBrief(id: 'crew', name: 'Weekend Crew', memberCount: 6),
        ],
      ),
      api: _api),
  'password': (c) => askPassword(c,
      title: 'Room password',
      actionLabel: 'Join',
      subtitle: 'Istanbul Film Club is locked'),
  'memberactions': (c) => showRoomMemberActions(c,
      member: _people[3],
      memberRole: RoomRole.member,
      permissions: _owner,
      api: _api,
      isSelf: false),
  'invite': (c) => showRoomInviteSheet(c,
      repo: _repo, roomId: 'crew', permissions: _owner),
  'confirm': (c) => showConfirmSheet(c,
      headline: 'Leave Weekend Crew?',
      body: 'You will stop getting its messages.',
      confirmLabel: 'Leave'),
  'msgmenu': (c) => showMessageActionMenu(
        context: c,
        anchorKey: _bubbleKey,
        bubbleBuilder: _bubble,
        isMine: false,
        capabilities: const MessageCapabilities(
          canReply: true,
          canEdit: false,
          canForward: true,
          canViewThread: true,
          canCopy: true,
          canCopyName: false,
          canCopyCoordinates: false,
          canTranslate: true,
          canPin: true,
          canSave: true,
          canSelect: true,
          canViewProfile: true,
          canDelete: true,
          canReport: true,
        ),
      ),
  'rowmenu': (c) => showChatRowActionMenu(
        context: c,
        anchorKey: _rowKey,
        previewBuilder: (_) => const SizedBox(height: 200, width: 300),
        isPinned: false,
        isArchived: false,
        isMuted: false,
        canMute: true,
      ),
};

/// Re-rendered in Turkish at 1.3x text — the truncation / wrapping pass.
const _stress = {
  'newchat', 'create', 'joinroom', 'archived', 'pinned', 'scheduled',
  'schedule', 'forward', 'mute', 'block', 'memberactions', 'invite',
  'msgmenu', 'rowmenu', 'reactdetails', 'linkconfirm', 'removecontact',
  'password', 'report', 'share',
};

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    SharedPreferences.setMockInitialValues({});
  });
  Future<void> run(WidgetTester tester, String id, MapEntry<String, _Opener> e,
      {Locale locale = const Locale('en'), double scale = 1, String suffix = ''}) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final anchor = GlobalKey();
    await snap(
      tester,
      previewApp(ThemeController.byId(id), _Backdrop(anchor: anchor),
          locale: locale),
      'cr_${e.key}_$id$suffix.png',
      act: () async {
        e.value(anchor.currentContext!);
        await tester.pump();
      },
    );
  }

  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    for (final e in _sheets.entries) {
      testWidgets('cr ${e.key}: $id', (tester) => run(tester, id, e));
    }
  }
  for (final e in _sheets.entries.where((e) => _stress.contains(e.key))) {
    testWidgets('cr ${e.key}: tr 1.3', (tester) =>
        run(tester, 'basic', e,
            locale: const Locale('tr'), scale: 1.3, suffix: '_tr13'));
  }
}
