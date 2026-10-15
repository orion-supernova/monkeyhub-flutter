import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/family.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:monkeyhub/widgets/report_sheet.dart';
import 'package:monkeyhub/widgets/terms_consent.dart';

/// The client half of the Guideline 1.2 moderation pack: which rooms offer
/// Report and moderator actions, what the report sheet promises before it
/// sends, and the EULA box.

ChatRoom _room({String name = 'general', String? systemRole}) => ChatRoom(
      id: 'r1',
      name: name,
      createdBy: 'u0',
      createdAt: DateTime(2026),
      isPrivate: true,
      memberCount: 2,
      systemRole: systemRole,
      participantIds: const ['u0', 'u1'],
    );

ChatMessage _msg({ModerationCard? card}) => ChatMessage(
      id: 'm1',
      roomId: 'r1',
      senderId: 'bot',
      senderName: 'Monkey Reporter',
      content: 'REPORT',
      createdAt: DateTime(2026, 3, 1),
      moderationCard: card,
    );

const _card = ModerationCard(reportId: 'rep1', hasMessage: true, hasUser: true);

MessageCapabilities _caps(ChatMessage m, RoomCapabilities room) =>
    messageCapabilitiesFor(
      message: m,
      isMine: false,
      room: room,
      roomIsEphemeral: false,
      serverNow: DateTime(2026, 3, 1),
    );

class _ReportApi extends Fake implements ChatApi {
  final calls = <Map<String, Object?>>[];

  @override
  Future<bool> report({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    String? note,
    bool alsoBlock = false,
  }) async {
    calls.add({
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'alsoBlock': alsoBlock,
    });
    return alsoBlock;
  }
}

Widget _host(void Function(BuildContext) onOpen) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => onOpen(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  group('room capabilities', () {
    test('the moderation room is a read-only feed staff can act in', () {
      final caps = roomCapabilitiesFor(_room(systemRole: 'moderation'));
      expect(caps.canModerate, isTrue);
      expect(caps.hasMembers, isTrue);
      expect(caps.canReport, isFalse);
      expect(caps.canLeave, isFalse);
      expect(caps.canDelete, isFalse);
    });

    test('the logs room grants no moderation', () {
      expect(roomCapabilitiesFor(_room(systemRole: 'logs')).canModerate, isFalse);
    });

    test('groups and DMs can be reported; Saved Messages cannot', () {
      expect(roomCapabilitiesFor(_room()).canReport, isTrue);
      expect(roomCapabilitiesFor(_room(name: 'dm:regular:a:b')).canReport, isTrue);
      expect(roomCapabilitiesFor(_room(name: 'dm:self:a')).canReport, isFalse);
      expect(roomCapabilitiesFor(_room()).canModerate, isFalse);
    });
  });

  group('message capabilities', () {
    final modRoom = roomCapabilitiesFor(_room(systemRole: 'moderation'));
    final group = roomCapabilitiesFor(_room());

    test('a card in the moderation room offers the moderator rows', () {
      final c = _caps(_msg(card: _card), modRoom);
      expect(c.canModerate, isTrue);
      expect(c.canModerateMessage, isTrue);
      expect(c.canModerateUser, isTrue);
      // Nobody reports a report, or opens the bot's dead-end profile.
      expect(c.canReport, isFalse);
      expect(c.canViewProfile, isFalse);
    });

    test('a card anywhere else, or a plain message, offers none', () {
      expect(_caps(_msg(card: _card), group).canModerate, isFalse);
      expect(_caps(_msg(), modRoom).canModerate, isFalse);
      expect(_caps(_msg(), group).canReport, isTrue);
      expect(_caps(_msg(), group).canViewProfile, isTrue);
      // The bot posting into an ordinary room has no profile to open either.
      final fromBot = messageCapabilitiesFor(
        message: _msg(),
        isMine: false,
        room: group,
        roomIsEphemeral: false,
        serverNow: DateTime(2026, 3, 1),
        senderIsSystem: true,
      );
      expect(fromBot.canViewProfile, isFalse);
    });

    test('a filter-hit card has a person to ban but no message to remove', () {
      const hit = ModerationCard(reportId: 'r', hasMessage: false, hasUser: true);
      final c = _caps(_msg(card: hit), modRoom);
      expect(c.canModerateMessage, isFalse);
      expect(c.canModerateUser, isTrue);
    });

    Future<List<MessageActionSpec>> specsFor(ModerationCard card) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      return messageActionSpecs(
        l10n: l10n,
        capabilities: _caps(_msg(card: card), modRoom),
        isPinned: false,
        isSaved: false,
        isTranslated: false,
        hasFileName: false,
      );
    }

    List<MessageAction> modRows(List<MessageActionSpec> specs) => specs
        .map((s) => s.action)
        .where((a) => a.name.startsWith('mod'))
        .toList();

    test('a card about someone not banned offers Ban, not Unban', () async {
      final specs = await specsFor(_card);
      expect(modRows(specs), [
        MessageAction.modDismiss,
        MessageAction.modRemoveMessage,
        MessageAction.modBanUser,
      ]);
      // Every destructive row comes after every neutral one.
      final firstRed = specs.indexWhere((s) => s.destructive);
      expect(specs.skip(firstRed).every((s) => s.destructive), isTrue);
    });

    test('a card about someone banned offers Unban, not Ban', () async {
      const banned = ModerationCard(
          reportId: 'rep1', hasMessage: true, hasUser: true, userBanned: true);
      expect(modRows(await specsFor(banned)), [
        MessageAction.modUnbanUser,
        MessageAction.modDismiss,
        MessageAction.modRemoveMessage,
      ]);
    });

    test('the card survives the disk cache', () {
      final back = ChatMessage.fromJson(_msg(card: _card).toJson());
      expect(back.moderationCard?.reportId, 'rep1');
      expect(back.moderationCard?.hasMessage, isTrue);
      expect(back.moderationCard?.hasUser, isTrue);
      expect(back.moderationCard?.userBanned, isFalse);
    });
  });

  group('the filter refusal', () {
    test('travels the child-gate road but is told apart', () {
      final e = StateError(kMessageFilterBlocked);
      expect(isChildGateError(e), isTrue);
      expect(isFilterBlockedError(e), isTrue);
      expect(isFilterBlockedError(StateError(kChildNotAllowed)), isFalse);
    });
  });

  group('report sheet', () {
    testWidgets('says what is sent before sending, and blocks by default',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final api = _ReportApi();
      await tester.pumpWidget(_host((context) => fileReport(
            context,
            api: api,
            reporterId: 'me',
            target: ReportTarget.message,
            targetId: 'm9',
          )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('last few messages in this chat to MonkeyHub moderators'),
        findsOneWidget,
      );
      expect(find.text('Also block this person'), findsOneWidget);

      await tester.tap(find.text('Harassment'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(api.calls, hasLength(1));
      expect(api.calls.single['targetType'], 'message');
      expect(api.calls.single['reason'], 'HARASSMENT');
      expect(api.calls.single['alsoBlock'], isTrue);
      expect(
        find.textContaining('review reports within 24 hours'),
        findsOneWidget,
      );
    });

    testWidgets('a group report offers no block', (tester) async {
      await tester.pumpWidget(_host((context) => showReportSheet(
            context,
            target: ReportTarget.room,
          )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Also block this person'), findsNothing);
      expect(find.textContaining('No one here will know'), findsOneWidget);
    });
  });

  group('terms consent', () {
    testWidgets('the whole row toggles the box', (tester) async {
      var value = false;
      await tester.pumpWidget(ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TermsConsentRow(
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      ));
      expect(find.textContaining('zero tolerance', findRichText: true), findsOneWidget);
      await tester.tap(find.byType(TermsConsentRow));
      await tester.pump();
      expect(value, isTrue);
    });
  });
}
