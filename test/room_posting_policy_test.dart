@TestOn('vm')
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/models/room_posting_policy.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/attachment_menu.dart';
import 'package:monkeyhub/widgets/read_only_composer_footer.dart';

/// The client mirror of `backend/convex/roomPolicy.ts`: what a room offers its
/// members to post, and that the composer, the attachment menu and the message
/// menu follow it. The server refuses regardless; this pins what is OFFERED.

ChatRoom _room({String? systemRole, String? postingPolicy}) => ChatRoom(
      id: 'r1',
      name: systemRole == null ? 'general' : 'MonkeyHub Logs',
      createdBy: 'u0',
      createdAt: DateTime(2026),
      isPrivate: true,
      memberCount: 3,
      systemRole: systemRole,
      postingPolicy: postingPolicy,
      participantIds: const ['u0', 'u1', 'u2'],
    );

final _t0 = DateTime(2026, 3, 1, 12);

ChatMessage _msg({MessageType type = MessageType.text}) => ChatMessage(
      id: 'm1',
      roomId: 'r1',
      senderId: 'alice',
      senderName: 'alice',
      content: 'hello there friend',
      createdAt: _t0,
      type: type,
      status: MessageStatus.sent,
    );

MessageCapabilities _caps(ChatRoom room, {bool isMine = true}) =>
    messageCapabilitiesFor(
      message: _msg(),
      isMine: isMine,
      room: roomCapabilitiesFor(room),
      roomIsEphemeral: false,
      serverNow: _t0.add(const Duration(minutes: 1)),
    );

void main() {
  group('resolution', () {
    test('absent is open; a system room is read-only; a stamp wins', () {
      expect(roomPostingPolicyOf(_room()), same(RoomPostingPolicy.open));
      expect(roomPostingPolicyOf(_room(systemRole: 'logs')),
          same(RoomPostingPolicy.readOnly));
      expect(roomPostingPolicyOf(_room(postingPolicy: 'agent')),
          same(RoomPostingPolicy.agent));
      expect(
          roomPostingPolicyOf(
              _room(systemRole: 'agentBot', postingPolicy: 'agent')),
          same(RoomPostingPolicy.agent));
    });

    test('a preset this build has never heard of fails closed', () {
      expect(roomPostingPolicyOf(_room(postingPolicy: 'somethingNew')),
          same(RoomPostingPolicy.readOnly));
    });

    test('survives the room cache round trip', () {
      final back =
          ChatRoom.fromJson(_room(postingPolicy: 'readOnly').toJson());
      expect(back.postingPolicy, 'readOnly');
      expect(ChatRoom.fromJson(_room().toJson()).postingPolicy, isNull);
    });
  });

  group('room capabilities', () {
    test('an ordinary room is untouched', () {
      expect(roomCapabilitiesFor(_room()), same(RoomCapabilities.group));
    });

    test('the logs room: no posting, no call, no forwards in', () {
      final caps = roomCapabilitiesFor(_room(systemRole: 'logs'));
      expect(caps.posting.canPost, isFalse);
      expect(caps.canCall, isFalse);
      expect(caps.canReceiveForwards, isFalse);
      // Its roster is still shown — the policy narrows posting, nothing else.
      expect(caps.hasMembers, isTrue);
    });

    test('a group stamped read-only loses calls and forwards', () {
      final caps = roomCapabilitiesFor(_room(postingPolicy: 'readOnly'));
      expect(caps.posting.canPost, isFalse);
      expect(caps.canCall, isFalse);
      expect(caps.canReceiveForwards, isFalse);
      expect(caps.canLeave, isTrue);
    });

    test('agent: text and images, forwards yes, calls no', () {
      final caps = roomCapabilitiesFor(_room(postingPolicy: 'agent'));
      expect(caps.posting.allows(PostKind.text), isTrue);
      expect(caps.posting.allows(PostKind.image), isTrue);
      expect(caps.posting.allows(PostKind.game), isFalse);
      expect(caps.posting.allows(PostKind.file), isFalse);
      expect(caps.canReceiveForwards, isTrue);
      expect(caps.canCall, isFalse);
      // Kind-aware forward / share filtering.
      expect(caps.posting.allowsAll({PostKind.text, PostKind.image}), isTrue);
      expect(caps.posting.allowsAll({PostKind.image, PostKind.file}), isFalse);
    });
  });

  group('message menu', () {
    test('read-only takes away every row that adds something', () {
      final caps = _caps(_room(systemRole: 'logs'));
      expect(caps.canReply, isFalse);
      expect(caps.canReact, isFalse);
      expect(caps.canPin, isFalse);
      expect(caps.canEdit, isFalse);
      // ...and keeps the ones that take nothing in.
      expect(caps.canCopy, isTrue);
      expect(caps.canSelect, isTrue);
    });

    test('an open room offers them as before', () {
      final caps = _caps(_room());
      expect(caps.canReply, isTrue);
      expect(caps.canReact, isTrue);
      expect(caps.canPin, isTrue);
      expect(caps.canEdit, isTrue);
    });

    test('a hand-built capabilities object still offers reactions', () {
      // The pill is not a menu row; only the room's policy takes it away.
      expect(MessageCapabilities.none.canReact, isTrue);
      expect(MessageCapabilities.none.copyWith(canReact: false).canReact,
          isFalse);
    });
  });

  group('attachment menu', () {
    const anchor = Rect.fromLTWH(12, 780, 40, 40);

    Future<BuildContext> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext ctx;
      await tester.pumpWidget(ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (c) {
            ctx = c;
            return const Scaffold();
          }),
        ),
      ));
      return ctx;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      for (var t = 0; t < 800; t += 20) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    test('a read-only room has nothing to attach; open and agent do', () {
      expect(attachmentMenuHasRows(RoomPostingPolicy.readOnly), isFalse);
      expect(attachmentMenuHasRows(RoomPostingPolicy.open), isTrue);
      expect(attachmentMenuHasRows(RoomPostingPolicy.agent), isTrue);
    });

    testWidgets('agent offers the camera and photos, and nothing else',
        (tester) async {
      final ctx = await pump(tester);
      showAttachmentMenu(ctx,
          anchor: anchor, posting: RoomPostingPolicy.agent);
      await settle(tester);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Video'), findsNothing);
      expect(find.text('File'), findsNothing);
      expect(find.text('Poll'), findsNothing);
      expect(find.text('Location'), findsNothing);
    });

    testWidgets('open keeps every row', (tester) async {
      final ctx = await pump(tester);
      showAttachmentMenu(ctx, anchor: anchor);
      await settle(tester);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Poll'), findsOneWidget);
      expect(find.text('File'), findsOneWidget);
    });
  });

  testWidgets('the read-only footer says why there is no composer',
      (tester) async {
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ReadOnlyComposerFooter()),
      ),
    ));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(find.text(en.roomReadOnlyFooter), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lock_fill), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
