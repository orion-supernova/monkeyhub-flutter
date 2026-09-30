import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/expressions/expression_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/expression_item.dart';
import 'package:monkeyhub/models/sticker_pack.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_composer.dart';
import 'package:monkeyhub/widgets/expressions/expression_bubble.dart';
import 'package:monkeyhub/widgets/expressions/expression_media.dart';
import 'package:monkeyhub/widgets/expressions/expression_panel.dart';
import 'package:monkeyhub/widgets/expressions/sticker_suggestions.dart';

/// The GIF/sticker surfaces a user touches: the composer's smiley, the panel's
/// tabs, the suggestion strip, and the two bubbles.
///
/// Network images never load in a widget test (every request answers 400), so
/// these assert structure and fallbacks — which is also exactly what a user on
/// a dead connection sees.
void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: Scaffold(
              body: Align(alignment: Alignment.bottomCenter, child: child),
            ),
          ),
        ),
      );

  const sticker = PackSticker(
    id: 'st1',
    storageId: 'blob1',
    url: 'https://example.invalid/1.json',
    format: StickerFormat.image,
    emoji: '😂',
    width: 512,
    height: 512,
    personal: false,
  );
  const pack = StickerPack(
    id: 'p1',
    slug: 'noto-moods',
    title: 'Moods',
    personal: false,
    author: 'Google',
    license: 'CC BY 4.0',
    stickers: [sticker],
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    ExpressionStore.instance.debugSeed(packs: const [pack]);
  });
  tearDown(() => ExpressionStore.instance.debugSeed(
      packs: const [], recents: const [], favorites: const []));

  group('composer smiley', () {
    testWidgets('present only when the host offers a panel, and toggles',
        (tester) async {
      var toggles = 0;
      await tester.pumpWidget(host(ChatComposerClassic(
        controller: TextEditingController(),
        ephemeral: false,
        onSend: () {},
      )));
      expect(find.byIcon(Icons.emoji_emotions_outlined), findsNothing);

      await tester.pumpWidget(host(ChatComposerLiquid(
        controller: TextEditingController(),
        ephemeral: false,
        onSend: () {},
        onExpressions: () => toggles++,
      )));
      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      expect(toggles, 1);

      await tester.pumpWidget(host(ChatComposerLiquid(
        controller: TextEditingController(),
        ephemeral: false,
        onSend: () {},
        onExpressions: () {},
        expressionsOpen: true,
      )));
      expect(find.byIcon(Icons.keyboard_alt_outlined), findsOneWidget);
    });
  });

  group('panel', () {
    testWidgets('no GIF tab where the server has no KLIPY key', (tester) async {
      await tester.pumpWidget(host(ExpressionPanel(
        composer: TextEditingController(),
        onSend: (_, {query}) {},
        height: 320,
      )));
      await tester.pump();
      expect(find.text('Emoji'), findsOneWidget);
      expect(find.text('Stickers'), findsOneWidget);
      expect(find.text('GIFs'), findsNothing);
      // The emoji picker loads its recents on a timer; let it land.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a tapped pack sticker is sent as a pack sticker',
        (tester) async {
      ExpressionItem? sent;
      await tester.pumpWidget(host(ExpressionPanel(
        composer: TextEditingController(),
        onSend: (item, {query}) => sent = item,
        height: 320,
      )));
      await tester.tap(find.text('Stickers'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The pack's credit line, which CC BY 4.0 requires.
      expect(find.textContaining('CC BY 4.0'), findsOneWidget);
      // The pack strip's cover is a StickerArt too; the grid tile comes after it.
      await tester.tap(find.byType(StickerArt).last);
      await tester.pump(const Duration(milliseconds: 200));
      expect(sent?.stickerId, 'st1');
      expect(sent?.source, ExpressionSource.pack);
    });
  });

  group('panel levels', () {
    ExpressionPanelController levels() => ExpressionPanelController()
      ..setLayout(expanded: 600, aboveKeyboard: 250);

    test('a slow release snaps to whichever level is nearer', () {
      final c = levels();
      final collapsed = c.currentHeight;
      c.dragBy(-100); // up a little
      c.dragEnd(0);
      expect(c.expanded, isFalse);
      expect(c.currentHeight, collapsed);
      c.dragBy(-(600 - collapsed) * 0.7); // most of the way
      c.dragEnd(0);
      expect(c.expanded, isTrue);
      expect(c.currentHeight, 600);
    });

    test('a flick decides by direction, however short', () {
      final c = levels();
      c.dragBy(-10);
      c.dragEnd(-900);
      expect(c.expanded, isTrue);
      c.dragBy(10);
      c.dragEnd(900);
      expect(c.expanded, isFalse);
    });

    test('a drag never leaves the two levels', () {
      final c = levels();
      c.dragBy(-5000);
      expect(c.currentHeight, 600);
      c.dragBy(5000);
      expect(c.currentHeight, c.height);
      c.dragEnd(0);
    });

    test('putting the panel away resets it to collapsed', () {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final c = levels()
        ..open(focus)
        ..toggleExpanded();
      expect(c.expanded, isTrue);
      c.hide();
      expect(c.isOpen, isFalse);
      expect(c.expanded, isFalse);
    });

    test('a send from the expanded panel brings it back down, but open', () {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final c = levels()
        ..open(focus)
        ..toggleExpanded();
      c.noteSent();
      expect(c.isOpen, isTrue);
      expect(c.expanded, isFalse);
    });

    test('opens at the height the host asks for, within bounds', () {
      final c = ExpressionPanelController()
        ..setLayout(expanded: 600, aboveKeyboard: 250, resting: 422);
      expect(c.currentHeight, 422);
      c.setLayout(expanded: 600, aboveKeyboard: 250, resting: 100);
      expect(c.height, 240, reason: 'never too short to browse');
      c.setLayout(expanded: 300, aboveKeyboard: 250, resting: 500);
      expect(c.height, 300, reason: 'never taller than expanded');
    });

    test('search takes the room above the keyboard', () {
      final c = levels()..setSearching(true);
      expect(c.currentHeight, 250);
    });
  });

  testWidgets('the close button puts the panel away', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final c = ExpressionPanelController()..open(focus);
    await tester.pumpWidget(host(ExpressionPanel(
      controller: c,
      composer: TextEditingController(),
      onSend: (_, {query}) {},
      height: 320,
    )));
    await tester.tap(find.byIcon(CupertinoIcons.chevron_down));
    expect(c.isOpen, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  group('sticker suggestions', () {
    testWidgets('appear for a lone emoji, and only then', (tester) async {
      final composer = TextEditingController();
      ExpressionItem? sent;
      await tester.pumpWidget(host(StickerSuggestions(
        composer: composer,
        onSend: (i) => sent = i,
      )));
      expect(find.byType(StickerArt), findsNothing);

      composer.text = '😂';
      await tester.pump();
      expect(find.byType(StickerArt), findsOneWidget);

      composer.text = '😂 lol';
      await tester.pump();
      expect(find.byType(StickerArt), findsNothing);

      composer.text = '😂';
      await tester.pump();
      await tester.tap(find.byType(StickerArt));
      expect(sent?.stickerId, 'st1');
    });
  });

  group('bubbles', () {
    testWidgets('a sticker whose art cannot load still says its emoji',
        (tester) async {
      await tester.pumpWidget(host(const StickerArt(
        item: ExpressionItem(
          kind: ExpressionKind.sticker,
          source: ExpressionSource.pack,
          stickerId: 'st9',
          storageId: 'gone',
          title: '🐶',
        ),
        size: 150,
      )));
      await tester.pump();
      expect(find.text('🐶'), findsOneWidget);
    });

    testWidgets('a GIF lays out at its own ratio, capped', (tester) async {
      await tester.pumpWidget(host(GifMessageTile(
        item: const ExpressionItem(
          kind: ExpressionKind.gif,
          source: ExpressionSource.klipy,
          url: 'https://static.klipy.com/x.webp',
          width: 400,
          height: 200,
        ),
        maxWidth: 600,
        radius: BorderRadius.circular(12),
      )));
      final size = tester.getSize(find.byType(GifMessageTile));
      expect(size.width, kGifMessageMaxWidth);
      expect(size.height, kGifMessageMaxWidth / 2);
    });
  });
}
