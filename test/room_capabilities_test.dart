import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/room_capabilities.dart';

ChatRoom _room({
  String id = 'r1',
  String name = 'general',
  String? systemRole,
}) =>
    ChatRoom(
      id: id,
      name: name,
      createdBy: 'u0',
      createdAt: DateTime(2026),
      isPrivate: true,
      memberCount: 2,
      systemRole: systemRole,
      participantIds: const ['u0', 'u1'],
    );

ChatRoom _dm({String? systemRole}) =>
    _room(id: 'd1', name: 'dm:regular:u0:u1', systemRole: systemRole);

ChatRoom _savedMessages() => _room(id: 's1', name: 'dm:self:u0');

/// The `MonkeyHub Logs` room as it arrives today: a named group stamped
/// `system: "logs"` by `problemReports.ensureReportRoom`, with the bot and the
/// staff who read the reports in it.
ChatRoom _logsRoom() => _room(
      id: 'l1',
      name: 'MonkeyHub Logs',
      systemRole: 'logs',
    );

/// The same room before `problemReports.repairLogRoom` renamed it — still a
/// `dm:` name, because the room predates the staff room it became. Any install
/// that has not filed a report since the rename sees this.
ChatRoom _legacyLogsDm() => _dm(systemRole: 'logs');

ChatUser _user({bool isSystem = false}) => ChatUser(
      id: 'u1',
      username: isSystem ? 'monkeyhub_logs' : 'someone',
      name: isSystem ? 'MonkeyHub Logs' : 'Someone',
      isSystem: isSystem,
    );

void main() {
  group('roomKindOf', () {
    test('sorts the four kinds by name alone when nothing is stamped', () {
      expect(roomKindOf(_room()), RoomKind.group);
      expect(roomKindOf(_dm()), RoomKind.dm);
      expect(roomKindOf(_savedMessages()), RoomKind.savedMessages);
    });

    test('the system stamp beats the dm: name prefix', () {
      // The whole trap: the report room WAS a DM, and on any deployment that
      // has not filed a report since the rename it still is one by name. A kind
      // resolved from the name alone would hand it the full DM affordance set.
      expect(_legacyLogsDm().isDm, isTrue);
      expect(roomKindOf(_legacyLogsDm()), RoomKind.system);
    });

    test('the stamp is also what survives the rename to a group', () {
      // The other half of the same guarantee, and the one that matters now:
      // once the room is a plain named group, nothing about its NAME says
      // "system" any more. Only the slug does.
      expect(_logsRoom().isDm, isFalse);
      expect(_logsRoom().isSavedMessages, isFalse);
      expect(roomKindOf(_logsRoom()), RoomKind.system);
    });

    test('a bot peer is enough on a room the server never stamped', () {
      final unstamped = _dm();
      expect(roomKindOf(unstamped), RoomKind.dm);
      expect(
        roomKindOf(unstamped, peer: _user(isSystem: true)),
        RoomKind.system,
      );
    });

    test('an ordinary peer leaves a DM a DM', () {
      expect(roomKindOf(_dm(), peer: _user()), RoomKind.dm);
    });
  });

  group('capabilities', () {
    test('a system room affords nothing a bot cannot answer', () {
      final caps = roomCapabilitiesFor(_room(systemRole: 'support-2027'));
      expect(caps.canCall, isFalse);
      expect(caps.canDelete, isFalse);
      expect(caps.canLeave, isFalse);
      expect(caps.hasDescription, isFalse);
      expect(caps.hasPeerHandle, isFalse);
      expect(caps.canEditSettings, isFalse);
      expect(caps.canOpenPeerProfile, isFalse);
      expect(caps.canReceiveForwards, isFalse);
      expect(caps.canSaveMessages, isFalse);
    });

    test('an unknown slug still shows its roster', () {
      // Every stamped system room is a staff group the bot posts into. A build
      // that predates the slug used to hide who else reads it, which is how
      // the moderation room shipped with no member list on older installs.
      final caps = roomCapabilitiesFor(_room(systemRole: 'support-2027'));
      expect(caps.hasMembers, isTrue);
    });

    test('the logs room gets its roster back, and nothing else', () {
      // It stopped being "you and a bot" the day a second staff account was
      // added, so the roster went from saying nothing to answering the only
      // question anybody asks of that room: who else can see the reports.
      final caps = roomCapabilitiesFor(_logsRoom());
      expect(caps.hasMembers, isTrue);
      // The opt-in is one flag. Everything else still tracks the locked-down
      // floor — a room the app writes into is not one anybody renames, leaves,
      // deletes, calls or forwards into.
      expect(caps.canCall, isFalse);
      expect(caps.canLeave, isFalse);
      expect(caps.canDelete, isFalse);
      expect(caps.canEditSettings, isFalse);
      expect(caps.hasDescription, isFalse);
      expect(caps.hasPeerHandle, isFalse);
      expect(caps.canReceiveForwards, isFalse);
      expect(caps.canSaveMessages, isFalse);
      expect(caps.canMute, isTrue);
    });

    test('an install that predates the rename gets the same table', () {
      // The override is keyed off the slug, not the name, so the room a stale
      // deployment still calls `dm:regular:…` affords exactly what the renamed
      // one does.
      expect(
        roomCapabilitiesFor(_legacyLogsDm()).hasMembers,
        roomCapabilitiesFor(_logsRoom()).hasMembers,
      );
    });

    test('an unknown slug falls back to the most restricted set', () {
      // A backend that ships a new kind of system room before this client
      // knows what it is must not produce a call button.
      final future = _dm(systemRole: 'announcements-2027');
      expect(roomKindOf(future), RoomKind.system);
      expect(roomCapabilitiesFor(future), same(RoomCapabilities.system));
    });

    test('an empty slug is not a system room', () {
      // `v.optional(v.string())` permits "", and a room that merely round-tripped
      // through an empty string should stay an ordinary DM.
      expect(_dm(systemRole: '').isSystemRoom, isFalse);
      expect(roomKindOf(_dm(systemRole: '')), RoomKind.dm);
    });

    test('ordinary rooms are unchanged by the new table', () {
      final group = roomCapabilitiesFor(_room());
      expect(group.canCall, isTrue);
      expect(group.canLeave, isTrue);
      expect(group.canEditSettings, isTrue);
      expect(group.hasMembers, isTrue);

      final dm = roomCapabilitiesFor(_dm(), peer: _user());
      expect(dm.canCall, isTrue);
      expect(dm.canDelete, isTrue, reason: 'either side may end a DM');
      expect(dm.canLeave, isFalse, reason: 'leaving a DM strands you');
      expect(dm.canEditSettings, isFalse);
      expect(dm.canOpenPeerProfile, isTrue);
    });

    test('a DM has no description and no roster', () {
      final dm = roomCapabilitiesFor(_dm(), peer: _user());
      expect(
        dm.hasDescription,
        isFalse,
        reason: 'a description is a notice to people who arrive later, and '
            'a pair has no later',
      );
      expect(
        dm.hasMembers,
        isFalse,
        reason: '"you and the person this screen is titled after" is not a list',
      );
    });

    test('a DM still names the other person, though', () {
      // The trap in taking the roster away: `@handle` used to ride on
      // hasMembers, and it is the one thing the display name above it leaves
      // out — it is how you tell two people called "Sam" apart.
      expect(roomCapabilitiesFor(_dm(), peer: _user()).hasPeerHandle, isTrue);
      // A group counts its members instead; there is no single peer to name.
      expect(roomCapabilitiesFor(_room()).hasPeerHandle, isFalse);
      expect(roomCapabilitiesFor(_room()).hasMembers, isTrue);
      // And a bot DM says neither, which is the case that makes these two
      // separate flags rather than one renamed one.
      final bot = roomCapabilitiesFor(_dm(), peer: _user(isSystem: true));
      expect(bot.hasPeerHandle, isFalse);
      expect(bot.hasMembers, isFalse);
    });

    test('Saved Messages keeps its one affordance: being forwarded to', () {
      final caps = roomCapabilitiesFor(_savedMessages());
      expect(caps.canCall, isFalse);
      expect(caps.canDelete, isFalse);
      expect(caps.hasMembers, isFalse);
      expect(caps.hasDescription, isFalse);
      expect(caps.canReceiveForwards, isTrue);
      // The one place the two "saved" features touch, and the polarity is
      // opposite on purpose: this room is the best target to forward INTO and
      // a meaningless place to bookmark, because it already is the pile of
      // things you kept.
      expect(caps.canSaveMessages, isFalse);
    });
  });

  group('wire', () {
    test('the system slug survives a JSON round trip', () {
      final restored = ChatRoom.fromJson(_logsRoom().toJson());
      expect(restored.systemRole, 'logs');
      expect(roomKindOf(restored), RoomKind.system);
    });

    test('a room from a backend that predates the field is not a system room', () {
      final legacy = Map<String, dynamic>.from(_dm().toJson())..remove('system');
      final restored = ChatRoom.fromJson(legacy);
      expect(restored.systemRole, isNull);
      expect(restored.isSystemRoom, isFalse);
    });

    test('isSystem is sent only when true, and absent reads as a person', () {
      expect(ChatUser.fromJson({'_id': 'u1', 'username': 'a', 'name': 'A'}).isSystem, isFalse);
      expect(
        ChatUser.fromJson({'_id': 'u1', 'username': 'a', 'name': 'A', 'isSystem': true}).isSystem,
        isTrue,
      );
    });

    test('copyWith carries isSystem, so a profile refetch cannot demote a bot', () {
      // ProfileScreen re-grafts friendship state onto every fresh fetch; a
      // dropped flag there would put the call button back.
      expect(_user(isSystem: true).copyWith(name: 'Renamed').isSystem, isTrue);
    });
  });
}
