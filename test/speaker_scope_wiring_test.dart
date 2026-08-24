import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/speaker_color_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/speaker_scope.dart';
import 'package:monkeyhub/widgets/user_avatar.dart';

/// The plumbing between a room's [SpeakerSlots] and the pixels.
///
/// `speaker_colors_test.dart` proves the colours are right; this proves they
/// actually arrive — that two senders in one room come out different, that a
/// DM comes out exactly as it did before the feature existed, and that each
/// rung of [SpeakerTint] paints what its name says and nothing more.
void main() {
  final theme = BasicTheme.midnight();
  final api = ChatApi(ConvexBackend.instance);

  const alice = 'u_alice';
  const bob = 'u_bob';

  ChatMessage msg(String sender, String name) => ChatMessage(
        id: 'm_$sender',
        roomId: 'r',
        senderId: sender,
        senderName: name,
        content: 'hello from $name',
        createdAt: DateTime(2026, 3, 1, 12),
        type: MessageType.text,
        status: MessageStatus.sent,
      );

  Widget host({
    required SpeakerSlots slots,
    required String sender,
    required String name,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(theme),
          child: Scaffold(
            body: SpeakerScope(
              slots: slots,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 500,
                  child: MessageBubble(
                    message: msg(sender, name),
                    now: DateTime(2026, 3, 1, 12),
                    currentUserId: 'u_me',
                    api: api,
                    author:
                        ChatUser(id: sender, username: name, name: name),
                    senderName: name,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  final room = SpeakerSlots.forMembers(
    [(id: alice, joinedAt: 1), (id: bob, joinedAt: 2)],
    exclude: 'u_me',
  );

  Color nameInk(WidgetTester tester, String name) =>
      tester.widget<Text>(find.text(name)).style!.color!;

  Color bubbleFill(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(LinkifiedText),
            matching: find.byType(Container),
          )
          .first,
    );
    return (container.decoration as ShapeDecoration).color!;
  }

  setUp(() {
    // SettingsStore persists to the platform keychain; a widget test has no
    // keychain, and the write's future would never complete.
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
  });

  testWidgets('two senders in one room do not share an ink', (tester) async {
    await SettingsStore.instance.setSpeakerTint(SpeakerTint.bubble);

    await tester.pumpWidget(host(slots: room, sender: alice, name: 'alice'));
    final aliceInk = nameInk(tester, 'alice');
    final aliceFill = bubbleFill(tester);

    await tester.pumpWidget(host(slots: room, sender: bob, name: 'bob'));
    final bobInk = nameInk(tester, 'bob');
    final bobFill = bubbleFill(tester);

    expect(aliceInk, isNot(bobInk));
    expect(aliceFill, isNot(bobFill));
    expect(aliceInk, isNot(theme.accent),
        reason: 'still the one accent every sender used to share');
  });

  testWidgets('a DM is untouched — no slots, nothing to tint', (tester) async {
    await SettingsStore.instance.setSpeakerTint(SpeakerTint.bubble);

    await tester.pumpWidget(
        host(slots: SpeakerSlots.none, sender: alice, name: 'alice'));

    expect(nameInk(tester, 'alice'),
        theme.accent.withValues(alpha: 0.95));
    expect(
      bubbleFill(tester),
      theme.messageBubbleDecoration(isMine: false, ephemeral: false).color,
    );
    expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).ring, isFalse);
  });

  testWidgets('NAMES colours the label and the ring, and stops there',
      (tester) async {
    await SettingsStore.instance.setSpeakerTint(SpeakerTint.name);
    await tester.pumpWidget(host(slots: room, sender: alice, name: 'alice'));

    expect(nameInk(tester, 'alice'), isNot(theme.accent));
    expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).ring, isTrue);
    expect(
      bubbleFill(tester),
      theme.messageBubbleDecoration(isMine: false, ephemeral: false).color,
      reason: 'the bubble is the rung ABOVE this one',
    );
  });

  testWidgets('OFF is the app as it was', (tester) async {
    await SettingsStore.instance.setSpeakerTint(SpeakerTint.off);
    await tester.pumpWidget(host(slots: room, sender: alice, name: 'alice'));

    expect(nameInk(tester, 'alice'), theme.accent.withValues(alpha: 0.95));
    expect(
      bubbleFill(tester),
      theme.messageBubbleDecoration(isMine: false, ephemeral: false).color,
    );
    expect(tester.widget<UserAvatar>(find.byType(UserAvatar)).ring, isFalse);

    // Put the default back for whatever runs next in this process.
    await SettingsStore.instance.setSpeakerTint(SpeakerTint.bubble);
  });

  testWidgets('the picker draws three live previews and one of them takes',
      (tester) async {
    await SettingsStore.instance.setSpeakerTint(SpeakerTint.bubble);
    // Tall enough for all three cards: the list is lazy, and on the default
    // 800px viewport the third one is never built at all.
    tester.view.physicalSize = const Size(600, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeScope(
        controller: ThemeController(theme),
        child: const SpeakerColorScreen(),
      ),
    ));
    await tester.pump();

    // Each card previews the same three speakers, so every name appears once
    // per card. The preview is the whole argument for the setting; a card that
    // silently rendered nothing would still look like a working picker.
    expect(find.text('ada'), findsNWidgets(3));
    expect(find.text('mira'), findsNWidgets(3));

    await tester.tap(find.text('OFF'));
    await tester.pump();
    expect(SettingsStore.instance.speakerTint, SpeakerTint.off);

    await SettingsStore.instance.setSpeakerTint(SpeakerTint.bubble);
  });
}
