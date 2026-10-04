import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/keyboard/focusable_tap.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_interaction.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/interaction_bubble.dart';
import 'package:monkeyhub/widgets/attachment_bubble_frame.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart' show SpecularRim;

final _day = DateTime(2026, 10, 4);

Widget _host(
  AppTheme theme,
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => ThemeScope(
  controller: ThemeController(theme),
  child: MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

Widget _card(AppTheme theme, MessageInteraction interaction) => Align(
  alignment: Alignment.topLeft,
  child: InteractionBubble(
    theme: theme,
    message: ChatMessage(
      id: 'm',
      roomId: 'r',
      senderId: 'ece',
      senderName: 'Ece',
      content: 'Where should we meet?',
      createdAt: _day,
      type: interaction.kind,
    ),
    interaction: interaction,
    isMine: false,
    width: 240,
    radius: BorderRadius.circular(20),
    actions: InteractionActions(onRespond: (_, _) {}),
    clock: () => _day,
  ),
);

MessageInteraction _poll({int count = 2}) => MessageInteraction(
  messageId: 'm',
  kind: MessageType.poll,
  createdBy: 'ece',
  createdAt: _day,
  choices: [
    InteractionChoice(id: 'a', label: 'By the sea', count: count),
    const InteractionChoice(id: 'b', label: 'In the city', count: 0),
  ],
  respondentCount: 2,
  myChoiceIds: const ['a'],
  anonymous: true,
  multiple: true,
);

void main() {
  testWidgets(
    'glass attachment lighting uses a painted rim without extra blur',
    (tester) async {
      final theme = BasicTheme.midnight();
      await tester.pumpWidget(_host(theme, _card(theme, _poll())));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .where((paint) => paint.foregroundPainter is SpecularRim),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'event RSVP replies are compact and retain open/closed behavior',
    (tester) async {
      final theme = BasicTheme.rose();
      var response = '';
      Widget event({bool closed = false}) => Align(
        alignment: Alignment.topLeft,
        child: InteractionBubble(
          theme: theme,
          message: ChatMessage(
            id: 'event',
            roomId: 'r',
            senderId: 'ece',
            senderName: 'Ece',
            content: 'Dinner with the crew',
            createdAt: _day,
            type: MessageType.event,
          ),
          interaction: MessageInteraction(
            messageId: 'event',
            kind: MessageType.event,
            createdBy: 'ece',
            createdAt: _day,
            choices: const [
              InteractionChoice(id: 'going', label: 'going', count: 2),
              InteractionChoice(id: 'maybe', label: 'maybe', count: 1),
              InteractionChoice(id: 'no', label: 'no', count: 0),
            ],
            respondentCount: 3,
            closedAt: closed ? _day : null,
          ),
          isMine: false,
          width: 280,
          radius: BorderRadius.circular(20),
          actions: InteractionActions(onRespond: (_, id) => response = id),
        ),
      );
      await tester.pumpWidget(_host(theme, event()));
      final control = find
          .ancestor(of: find.text('Going'), matching: find.byType(FocusableTap))
          .first;
      expect(
        tester.getSize(control).height,
        lessThan(60),
        reason: 'the native segmented reply replaces tall square choice tiles',
      );
      await tester.tap(find.text('Maybe'));
      expect(response, 'maybe');
      response = '';
      await tester.pumpWidget(_host(theme, event(closed: true)));
      await tester.tap(find.text('Going'));
      expect(response, isEmpty);
    },
  );

  testWidgets('a shared completed checklist item stays visibly ticked', (
    tester,
  ) async {
    final theme = BasicTheme.rose();
    final interaction = MessageInteraction(
      messageId: 'm',
      kind: MessageType.checklist,
      createdBy: 'ece',
      createdAt: _day,
      choices: const [
        InteractionChoice(id: 'a', label: 'Fresh bread', count: 1),
      ],
      respondentCount: 1,
    );
    await tester.pumpWidget(_host(theme, _card(theme, interaction)));
    final control = tester.widget<FocusableTap>(
      find
          .ancestor(
            of: find.text('Fresh bread'),
            matching: find.byType(FocusableTap),
          )
          .first,
    );
    expect(
      control.selected,
      isTrue,
      reason: 'a completed task belongs to the list, whoever ticked it',
    );
  });

  testWidgets('known poll results paint fully on their first frame', (
    tester,
  ) async {
    final theme = BasicTheme.midnight();
    await tester.pumpWidget(_host(theme, _card(theme, _poll())));
    final bar = tester.widget<FractionallySizedBox>(
      find
          .descendant(
            of: find.byType(InteractionBubble),
            matching: find.byType(FractionallySizedBox),
          )
          .first,
    );
    expect(
      bar.widthFactor,
      1,
      reason:
          'scrolling a cached poll into view must not replay its result fill',
    );
  });

  for (final theme in ThemeController.all) {
    test('${theme.id} small attachment text keeps readable contrast', () {
      final ground = attachmentRowFill(theme);
      for (final ink in [
        attachmentSecondaryInk(theme),
        attachmentActionInk(theme),
      ]) {
        final a = ink.computeLuminance();
        final b = ground.computeLuminance();
        final contrast = a > b
            ? (a + 0.05) / (b + 0.05)
            : (b + 0.05) / (a + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    });
    testWidgets('${theme.id} narrow large-text attachment controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          theme,
          _card(theme, _poll()),
          locale: const Locale('ar'),
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(InteractionBubble)).width, 240);
      final event = MessageInteraction(
        messageId: 'm',
        kind: MessageType.event,
        createdBy: 'ece',
        createdAt: _day,
        choices: const [
          InteractionChoice(id: 'going', label: 'going', count: 2),
          InteractionChoice(id: 'maybe', label: 'maybe', count: 1),
          InteractionChoice(id: 'no', label: 'no', count: 0),
        ],
        respondentCount: 3,
        startsAt: DateTime(2026, 10, 9, 20),
        place: 'Moda, Kadıköy',
      );
      await tester.pumpWidget(
        _host(
          theme,
          _card(theme, event),
          locale: const Locale('ar'),
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
