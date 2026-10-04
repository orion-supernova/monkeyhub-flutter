import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_interaction.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/widgets/interaction_bubble.dart';

import 'preview_kit.dart';

final _day = DateTime(2026, 10, 4, 17);

InteractionChoice _choice(
  String id,
  String label,
  int count, [
  List<String> names = const [],
]) => InteractionChoice(
  id: id,
  label: label,
  count: count,
  respondents: [
    for (final name in names)
      InteractionRespondent(userId: name, name: name, at: _day),
  ],
);

Widget _bubble(
  AppTheme theme,
  MessageType kind,
  String title,
  List<InteractionChoice> choices,
  List<String> selected, {
  int count = 3,
  bool anonymous = false,
}) {
  final message = ChatMessage(
    id: kind.name,
    roomId: 'weekend',
    senderId: 'ece',
    senderName: 'Ece',
    type: kind,
    content: title,
    createdAt: _day,
  );
  return Align(
    alignment: kind == MessageType.checklist
        ? Alignment.centerRight
        : Alignment.centerLeft,
    child: InteractionBubble(
      theme: theme,
      message: message,
      interaction: MessageInteraction(
        messageId: message.id,
        kind: kind,
        createdBy: 'ece',
        createdAt: _day,
        choices: choices,
        respondentCount: count,
        myChoiceIds: selected,
        anonymous: anonymous,
        startsAt: kind == MessageType.event ? DateTime(2026, 10, 9, 20) : null,
        endsAt: kind == MessageType.event ? DateTime(2026, 10, 9, 22) : null,
        place: kind == MessageType.event ? 'Moda, Kadıköy' : null,
      ),
      isMine: kind == MessageType.checklist,
      width: 310,
      radius: BorderRadius.circular(22),
      currentUserId: 'me',
      actions: InteractionActions(
        onRespond: (_, _) {},
        onAddItem: (_, _) {},
        onShowRespondents: (_) {},
      ),
      clock: () => _day,
    ),
  );
}

class _AttachmentSamples extends StatelessWidget {
  const _AttachmentSamples(this.theme);
  final AppTheme theme;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekend crew', style: theme.bodyEmph),
            const SizedBox(height: 6),
            Text('Ece', style: theme.caption),
            const SizedBox(height: 8),
            _bubble(
              theme,
              MessageType.poll,
              'Where should we meet?',
              [
                _choice('coffee', 'Coffee by the sea', 2),
                _choice('dinner', 'Dinner in Moda', 1),
                _choice('home', 'A quiet night at home', 0),
              ],
              ['coffee'],
              anonymous: true,
            ),
            const SizedBox(height: 18),
            _bubble(
              theme,
              MessageType.checklist,
              'Bring for the picnic',
              [
                _choice('bread', 'Fresh bread', 1, ['Murat']),
                _choice('fruit', 'Fruit and something sweet', 0),
                _choice('blanket', 'A blanket', 1, ['Ece']),
              ],
              ['bread'],
              count: 2,
            ),
            const SizedBox(height: 18),
            _bubble(
              theme,
              MessageType.event,
              'Dinner with the crew',
              [
                _choice('going', 'going', 2, ['Ece', 'Murat']),
                _choice('maybe', 'maybe', 1, ['Deniz']),
                _choice('no', 'no', 0),
              ],
              ['going'],
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadPreviewFonts);
  for (final theme in [
    BasicTheme.midnight(),
    BasicTheme.rose(),
    BasicTheme.daylight(),
  ]) {
    testWidgets('${theme.id} attachment bubbles', (tester) async {
      await snap(
        tester,
        previewApp(theme, _AttachmentSamples(theme)),
        'attachment_bubbles_${theme.id}.png',
        size: const Size(393, 1210),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
