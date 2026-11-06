import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/vanish_controller.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/vanish_card.dart';
import 'package:monkeyhub/widgets/vanish_scope.dart';

/// The vanish widgets in isolation: system lines (and their Change), the card's
/// two copy variants, the sealed bubble and the reply quote.
void main() {
  final api = ChatApi(ConvexBackend.instance);
  final t0 = DateTime(2026, 11, 6, 12);

  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  ChatMessage sys(String content, {String sender = 'murat'}) => ChatMessage(
        id: 's',
        roomId: 'r',
        senderId: sender,
        senderName: 'Murat',
        content: content,
        createdAt: t0,
        type: MessageType.system,
      );

  VanishController controller() => VanishController(cv: ConvexBackend.instance, api: api);

  Widget lineHost(
    ChatMessage m, {
    String me = 'zeynep',
    bool canChange = true,
    bool on = true,
    void Function(BuildContext, int)? onChange,
  }) =>
      host(VanishScope(
        controller: controller(),
        roomVanishOn: on,
        canChange: canChange,
        currentSeconds: 10,
        onChangeTimer: onChange ?? (_, _) {},
        child: MessageBubble(
          message: m,
          now: t0,
          currentUserId: me,
          api: api,
          author: ChatUser(id: 'murat', username: 'murat', name: 'Murat'),
        ),
      ));

  testWidgets('"on" line names the actor and offers Change', (t) async {
    int? changed;
    await t.pumpWidget(lineHost(sys('vanish:on:10'),
        onChange: (_, current) => changed = current));
    expect(
      find.textContaining('Murat turned on vanish mode. New messages disappear '
          '10 seconds after everyone has seen them, or after 24 hours at most. '
          'Screenshots are blocked.', findRichText: true),
      findsOneWidget,
    );
    await t.tap(find.text('Change'));
    expect(changed, 10);
  });

  testWidgets('"You" for yourself', (t) async {
    await t.pumpWidget(lineHost(sys('vanish:on:60', sender: 'zeynep')));
    expect(find.textContaining('You turned on vanish mode', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('1 minute after everyone', findRichText: true),
        findsOneWidget);
  });

  testWidgets('"change" line, and no Change for someone who cannot', (t) async {
    await t.pumpWidget(lineHost(sys('vanish:change:3600'), canChange: false));
    expect(find.textContaining('changed vanish mode', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('1 hour after everyone', findRichText: true),
        findsOneWidget);
    expect(find.text('Change'), findsNothing);
  });

  testWidgets('"off" line has no Change and no dashes', (t) async {
    await t.pumpWidget(lineHost(sys('vanish:off'), on: false));
    expect(find.textContaining('turned off vanish mode', findRichText: true),
        findsOneWidget);
    expect(find.text('Change'), findsNothing);
  });

  testWidgets('an old "on" line stops offering Change once vanish is off',
      (t) async {
    await t.pumpWidget(lineHost(sys('vanish:on:10'), on: false));
    expect(find.text('Change'), findsNothing);
  });

  testWidgets('the timer picker returns the pick', (t) async {
    int? picked;
    await t.pumpWidget(host(Builder(
      builder: (context) => GestureDetector(
        onTap: () async => picked = await showVanishTimerPicker(context, 10),
        child: const Text('open'),
      ),
    )));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('10 seconds'), findsOneWidget);
    expect(find.text('1 minute'), findsOneWidget);
    expect(find.text('1 hour'), findsOneWidget);
    await t.tap(find.text('1 minute'));
    await t.pumpAndSettle();
    expect(picked, 60);
  });

  testWidgets('the card: DM copy, group copy, always the Settings line',
      (t) async {
    final answers = <bool>[];
    await t.pumpWidget(host(HiddenSeenCard(
      isDm: true,
      name: 'Zeynep',
      afterSeen: 10,
      onAnswer: answers.add,
    )));
    expect(
      find.text("You don't share Seen, so Zeynep's messages to you last 24 hours. "
          'Yours still vanish 10 seconds after Zeynep sees them. '
          'Share your reads here so theirs vanish too?'),
      findsOneWidget,
    );
    expect(find.text('You can change this anytime in Settings › Privacy.'),
        findsOneWidget);
    await t.tap(find.text('Share my reads here'));
    await t.tap(find.text("Don't share here"));
    expect(answers, [true, false]);

    await t.pumpWidget(host(HiddenSeenCard(
      isDm: false,
      name: '',
      afterSeen: 3600,
      onAnswer: answers.add,
    )));
    expect(
      find.text("You don't share Seen, so messages sent to you here last 24 hours. "
          'Share your reads here so they vanish 1 hour after everyone has seen them?'),
      findsOneWidget,
    );
    expect(find.text('You can change this anytime in Settings › Privacy.'),
        findsOneWidget);
  });

  testWidgets('dismissing the card is "Don\'t share here"', (t) async {
    final answers = <bool>[];
    await t.pumpWidget(host(HiddenSeenCard(
      isDm: false,
      name: '',
      afterSeen: 10,
      onAnswer: answers.add,
    )));
    await t.tap(find.bySemanticsLabel("Don't share here").first);
    expect(answers, [false]);
  });

  testWidgets('the answer note always ends with the Settings pointer', (t) async {
    for (final shared in [true, false]) {
      await t.pumpWidget(host(HiddenSeenNote(shared: shared, afterSeen: 60)));
      expect(find.textContaining('Settings › Privacy.'), findsOneWidget);
    }
  });

  testWidgets('the long-message hint appears past 160 characters only',
      (t) async {
    final text = ValueNotifier(const TextEditingValue());
    await t.pumpWidget(host(VanishLongHint(text: text, enabled: true)));
    expect(find.text("Long messages may vanish before they're finished"),
        findsNothing);
    text.value = TextEditingValue(text: 'a' * 160);
    await t.pumpAndSettle();
    expect(find.textContaining('Long messages'), findsNothing);
    text.value = TextEditingValue(text: 'a' * 161);
    await t.pumpAndSettle();
    expect(find.text("Long messages may vanish before they're finished"),
        findsOneWidget);
    await t.pumpWidget(host(VanishLongHint(text: text, enabled: false)));
    expect(find.textContaining('Long messages'), findsNothing);
  });

  ChatMessage reply({DateTime? vanishUntil}) => ChatMessage(
        id: 'r1',
        roomId: 'r',
        senderId: 'murat',
        senderName: 'Murat',
        content: 'yes',
        createdAt: t0,
        replyToId: 'gone',
        replyToPreview: ReplyPreview(
          senderId: 'zeynep',
          senderName: 'Zeynep',
          contentPreview: '__DELETED__',
          type: MessageType.text,
        ),
        vanishUntil: vanishUntil,
      );

  testWidgets('a reply to a vanished parent says Vanished', (t) async {
    await t.pumpWidget(host(MessageBubble(
      message: reply(vanishUntil: t0.add(const Duration(hours: 24))),
      now: t0,
      currentUserId: 'zeynep',
      api: api,
    )));
    expect(find.textContaining('Vanished', findRichText: true), findsOneWidget);
    expect(find.textContaining('Message removed', findRichText: true), findsNothing);
  });

  testWidgets('an ordinary reply to a deleted parent still says removed',
      (t) async {
    await t.pumpWidget(host(MessageBubble(
      message: reply(),
      now: t0,
      currentUserId: 'zeynep',
      api: api,
    )));
    expect(find.textContaining('Message removed', findRichText: true), findsOneWidget);
    expect(find.textContaining('Vanished', findRichText: true), findsNothing);
  });
}
