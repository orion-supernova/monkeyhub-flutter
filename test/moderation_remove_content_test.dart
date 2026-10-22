import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:monkeyhub/widgets/moderation_actions.dart';

/// Phase 4G: Remove for a reported moment or comment, on the moderation card.

class _Api extends Fake implements ChatApi {
  final calls = <Map<String, String>>[];

  @override
  Future<void> moderationAct({
    required String reportId,
    required String action,
  }) async {
    calls.add({'reportId': reportId, 'action': action});
  }
}

const _contentCard = ModerationCard(
  reportId: 'rep1',
  hasMessage: false,
  hasContent: true,
  hasUser: true,
);

ChatMessage _msg(ModerationCard card) => ChatMessage(
      id: 'm1',
      roomId: 'r1',
      senderId: 'bot',
      senderName: 'Monkey Reporter',
      content: 'REPORT',
      createdAt: DateTime(2026, 3, 1),
      moderationCard: card,
    );

final _modRoom = roomCapabilitiesFor(ChatRoom(
  id: 'r1',
  name: 'mod',
  createdBy: 'u0',
  createdAt: DateTime(2026),
  isPrivate: true,
  memberCount: 2,
  systemRole: 'moderation',
  participantIds: const ['u0', 'u1'],
));

Future<List<MessageAction>> _rows(ModerationCard card) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  final caps = messageCapabilitiesFor(
    message: _msg(card),
    isMine: false,
    room: _modRoom,
    roomIsEphemeral: false,
    serverNow: DateTime(2026, 3, 1),
  );
  return messageActionSpecs(
    l10n: l10n,
    capabilities: caps,
    isPinned: false,
    isSaved: false,
    isTranslated: false,
    hasFileName: false,
  ).map((s) => s.action).where((a) => a.name.startsWith('mod')).toList();
}

void main() {
  test('a moment or comment card offers Remove content, not Remove message',
      () async {
    final rows = await _rows(_contentCard);
    expect(rows, contains(MessageAction.modRemoveContent));
    expect(rows, isNot(contains(MessageAction.modRemoveMessage)));
  });

  test('once it is removed the card stops offering it', () async {
    const gone = ModerationCard(
        reportId: 'rep1', hasMessage: false, hasContent: false, hasUser: true);
    expect(await _rows(gone), isNot(contains(MessageAction.modRemoveContent)));
  });

  test('hasContent survives the disk cache and defaults off', () {
    final back = ChatMessage.fromJson(_msg(_contentCard).toJson());
    expect(back.moderationCard?.hasContent, isTrue);
    expect(ModerationCard.tryParse({'reportId': 'x'})?.hasContent, isFalse);
  });

  testWidgets('Remove asks first, then calls removeContent', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = _Api();
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => runModeratorAction(
                  context,
                  api: api,
                  card: _contentCard,
                  action: MessageAction.modRemoveContent,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this moment or comment?'), findsOneWidget);
    expect(api.calls, isEmpty);

    await tester.tap(find.text('Remove moment or comment'));
    await tester.pumpAndSettle();
    expect(api.calls, [
      {'reportId': 'rep1', 'action': 'removeContent'},
    ]);
  });
}
