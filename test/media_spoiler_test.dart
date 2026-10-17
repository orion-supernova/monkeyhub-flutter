import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/spoiler_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/media_send_options.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/camera_editor_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/dust/spoiler_dust.dart';
import 'package:monkeyhub/widgets/media_send_switches.dart';
import 'package:monkeyhub/widgets/media_spoiler.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/still_blur.dart';

/// Photo spoilers end to end on the client: the wire field, the shared send
/// preview that arms it (from both the camera and the gallery), and the dust
/// cover that hides it until a tap.
void main() {
  Uint8List makePng(int width, int height) {
    final bitmap = img.Image(width: width, height: height);
    img.fill(bitmap, color: img.ColorRgb8(0x44, 0x55, 0x77));
    return img.encodePng(bitmap);
  }

  Widget app(Widget home) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  Finder switchOf(SendSwitch kind) => find.byWidgetPredicate(
        (w) => w is SendSwitchGlyph && w.kind == kind,
      );

  /// Decodes are real background work: interleave runAsync and pump, and
  /// never pumpAndSettle (the spinner and the dust both run forever).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byKey(cameraEditorStageImageKey).evaluate().isNotEmpty) break;
    }
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('ChatMessage.mediaSpoiler', () {
    Map<String, dynamic> row({bool? spoiler, Map<String, dynamic>? reply}) => {
          '_id': 'm1',
          'roomId': 'r',
          'userId': 'alice',
          'content': '',
          'createdAt': 1767225600000,
          'type': 'image',
          'mediaStorageId': 's1',
          'mediaSpoiler': ?spoiler,
          'replyToPreview': ?reply,
        };

    test('parses, survives the cache and copyWith', () {
      final m = ChatMessage.fromJson(row(spoiler: true));
      expect(m.mediaSpoiler, isTrue);
      expect(ChatMessage.fromJson(m.toJson()).mediaSpoiler, isTrue);
      expect(m.copyWith(status: MessageStatus.sent).mediaSpoiler, isTrue);
    });

    test('absent is false, and is not written', () {
      final m = ChatMessage.fromJson(row());
      expect(m.mediaSpoiler, isFalse);
      expect(m.toJson().containsKey('mediaSpoiler'), isFalse);
    });

    test('a reply quote of a spoiler says so', () {
      final m = ChatMessage.fromJson(row(reply: {
        'senderId': 'bob',
        'senderName': 'bob',
        'contentPreview': '',
        'type': 'image',
        'mediaStorageId': 's0',
        'mediaSpoiler': true,
      }));
      expect(m.replyToPreview!.mediaSpoiler, isTrue);
      expect(
        ReplyPreview.fromJson(m.replyToPreview!.toJson()).mediaSpoiler,
        isTrue,
      );
    });
  });

  group('the shared send preview', () {
    final photo = makePng(600, 800);

    testWidgets('from the camera: view once, spoiler and HD are offered', (
      tester,
    ) async {
      final draft = EditorDraft()..add(photo);
      await tester.pumpWidget(app(CameraEditorScreen(
        draft: draft,
        allowCaptions: true,
        allowSpoiler: true,
        maxPhotos: 10,
        canRetake: true,
      )));
      await settle(tester);
      expect(switchOf(SendSwitch.viewOnce), findsOneWidget);
      expect(switchOf(SendSwitch.spoiler), findsOneWidget);
      expect(switchOf(SendSwitch.hd), findsOneWidget);
      expect(switchOf(SendSwitch.pen), findsOneWidget);
      expect(find.byKey(cameraEditorCaptionKey), findsOneWidget);

      await tester.tap(switchOf(SendSwitch.spoiler));
      await tester.pump(const Duration(milliseconds: 600));
      expect(draft.options.spoiler, isTrue);
      // The armed switch says so in words, above the rail.
      expect(find.text('Hidden until tapped'), findsOneWidget);
      // Let the first-time tip finish so nothing is left ticking.
      await tester.pump(const Duration(seconds: 3));
      draft.dispose();
    });

    testWidgets('from the gallery: the same switches, on the picker\'s options',
        (tester) async {
      final options = MediaSendOptions(hd: false);
      EditorOutcome? outcome;
      await tester.pumpWidget(app(Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async {
              outcome = await CameraEditorScreen.open(
                context,
                source: photo,
                allowCaptions: true,
                allowSpoiler: true,
                options: options,
                closeKeeps: true,
                initialCaption: 'hello',
              );
            },
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      expect(switchOf(SendSwitch.viewOnce), findsOneWidget);
      expect(switchOf(SendSwitch.spoiler), findsOneWidget);
      expect(switchOf(SendSwitch.hd), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);

      await tester.tap(switchOf(SendSwitch.viewOnce));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(switchOf(SendSwitch.spoiler));
      await tester.pump(const Duration(milliseconds: 600));
      // Flipped on the caller's model: what the strip sends with.
      expect(options.viewOnce, isTrue);
      expect(options.spoiler, isTrue);
      await tester.pump(const Duration(seconds: 3));

      // The × goes back to the picks keeping the caption; nothing to confirm.
      await tester.tap(find.bySemanticsLabel('Close').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(outcome, isA<EditorKeep>());
      expect((outcome! as EditorKeep).caption, 'hello');
      expect((outcome! as EditorKeep).image, isNull);
    });
  });

  group('MediaSpoilerCover', () {
    setUp(SpoilerStore.instance.clear);

    Widget cover({bool interactive = true}) => app(Center(
          child: MediaSpoilerCover(
            revealKey: 'm1',
            interactive: interactive,
            child: const SizedBox(
              width: 200,
              height: 150,
              child: ColoredBox(color: Colors.orange),
            ),
          ),
        ));

    bool blurred(WidgetTester tester) => tester
        .widget<StillBlur>(find.descendant(
          of: find.byType(MediaSpoilerCover),
          matching: find.byType(StillBlur),
        ))
        .enabled;

    testWidgets('sealed until tapped, then the wavefront opens it', (
      tester,
    ) async {
      await tester.pumpWidget(cover());
      await tester.pump(const Duration(milliseconds: 100));
      expect(blurred(tester), isTrue);
      expect(find.byType(SpoilerDust), findsOneWidget);

      await tester.tap(find.byType(MediaSpoilerCover));
      await tester.pump(const Duration(milliseconds: 200));
      // Mid-wave: the sharp picture is masked in over the still blur.
      expect(
        find.descendant(
          of: find.byType(MediaSpoilerCover),
          matching: find.byType(ShaderMask),
        ),
        findsWidgets,
      );
      await tester.pump(kMediaSpoilerReveal + const Duration(milliseconds: 50));
      await tester.pump();
      expect(blurred(tester), isFalse);
      expect(find.byType(SpoilerDust), findsNothing);
      expect(
        SpoilerStore.instance.isRevealed(MediaSpoilerCover.storeKey('m1')),
        isTrue,
      );
    });

    testWidgets('a tapped picture covers over again after its hold', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(app(Center(
        child: MediaSpoilerCover(
          revealKey: 'm1',
          child: GestureDetector(
            onTap: () => opened++,
            child: const SizedBox(
              width: 200,
              height: 150,
              child: ColoredBox(color: Colors.orange),
            ),
          ),
        ),
      )));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(MediaSpoilerCover));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(kMediaSpoilerReveal + const Duration(milliseconds: 50));
      await tester.pump();
      expect(blurred(tester), isFalse);
      // Open for the hold: a tap now is the picture's (the viewer's).
      await tester.tap(find.byType(MediaSpoilerCover));
      expect(opened, 1);
      // Past the hold: the dust gathers back over it as a line of text's
      // does, the blur returning behind its front.
      await tester.pump(kMediaSpoilerHold);
      await tester.pump();
      expect(blurred(tester), isTrue);
      expect(find.byType(SpoilerDust), findsOneWidget);
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Gathered: the reveal is forgotten.
      expect(
        SpoilerStore.instance.isRevealed(MediaSpoilerCover.storeKey('m1')),
        isFalse,
      );
      // Sealed again: the next tap reveals rather than opens.
      await tester.tap(find.byType(MediaSpoilerCover));
      await tester.pump(const Duration(milliseconds: 200));
      expect(opened, 1);
      await tester.pump(kMediaSpoilerReveal);
      await tester.pump(kMediaSpoilerHold);
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });

    testWidgets('a short rub shows only what it touched, then heals', (
      tester,
    ) async {
      await tester.pumpWidget(cover());
      await tester.pump(const Duration(milliseconds: 100));
      final at = tester.getTopLeft(find.byType(MediaSpoilerCover));
      final g = await tester.startGesture(at + const Offset(20, 75));
      for (var i = 1; i <= 8; i++) {
        await g.moveTo(at + Offset(20.0 + i * 6, 75));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 16));
      // A partial reveal: still sealed, nothing remembered.
      expect(blurred(tester), isTrue);
      expect(find.byType(SpoilerDust), findsOneWidget);
      expect(
        SpoilerStore.instance.isRevealed(MediaSpoilerCover.storeKey('m1')),
        isFalse,
      );
      // The dust settles back over the holes after the glimpse.
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(blurred(tester), isTrue);
      expect(
        SpoilerStore.instance.isRevealed(MediaSpoilerCover.storeKey('m1')),
        isFalse,
      );
    });

    testWidgets('a held finger keeps the dust boiling off the rim', (
      tester,
    ) async {
      await tester.pumpWidget(cover());
      await tester.pump(const Duration(milliseconds: 100));
      final at = tester.getTopLeft(find.byType(MediaSpoilerCover));
      final g = await tester.startGesture(at + const Offset(60, 75));
      for (var i = 1; i <= 4; i++) {
        await g.moveTo(at + Offset(60.0 + i * 4, 75));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Still, but down: the rim's own dust is up and stays up.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const ValueKey('rubField')), findsOneWidget);
      await g.up();
      // Through the glimpse and the heal: shut again, nothing remembered.
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(blurred(tester), isTrue);
      expect(
        SpoilerStore.instance.isRevealed(MediaSpoilerCover.storeKey('m1')),
        isFalse,
      );
      // And once the last blown-in grain has settled, the field lets go of
      // its buffers: a sealed picture at rest holds nothing extra.
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.byKey(const ValueKey('rubField')), findsNothing);
    });

    testWidgets('rubbing most of it away opens the rest', (tester) async {
      await tester.pumpWidget(cover());
      await tester.pump(const Duration(milliseconds: 100));
      final at = tester.getTopLeft(find.byType(MediaSpoilerCover));
      final g = await tester.startGesture(at + const Offset(5, 5));
      for (var row = 0; row < 6; row++) {
        for (var i = 0; i <= 14; i++) {
          final x = row.isEven ? 5.0 + i * 14 : 195.0 - i * 14;
          await g.moveTo(at + Offset(x, 5.0 + row * 28));
          await tester.pump(const Duration(milliseconds: 8));
        }
      }
      await g.up();
      await tester.pump(kMediaSpoilerReveal + const Duration(milliseconds: 50));
      await tester.pump();
      expect(blurred(tester), isFalse);
      expect(
        SpoilerStore.instance.isRevealed(MediaSpoilerCover.storeKey('m1')),
        isTrue,
      );
    });

    testWidgets('a thumbnail never opens', (tester) async {
      await tester.pumpWidget(cover(interactive: false));
      await tester.tap(find.byType(MediaSpoilerCover), warnIfMissed: false);
      await tester.pump(kMediaSpoilerReveal * 2);
      expect(blurred(tester), isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the spoiler bubble', () {
    final api = ChatApi(ConvexBackend.instance);
    setUp(SpoilerStore.instance.clear);

    ChatMessage photo({bool spoiler = true}) => ChatMessage(
          id: 'p1',
          roomId: 'r',
          senderId: 'alice',
          senderName: 'alice',
          content: '',
          createdAt: DateTime(2026, 3, 1, 12),
          type: MessageType.image,
          mediaStorageId: 's1',
          mediaWidth: 400,
          mediaHeight: 300,
          mediaSpoiler: spoiler,
        );

    Widget bubble(ChatMessage m) => app(Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 500,
              child: MessageBubble(
                message: m,
                now: DateTime(2026, 3, 1, 12),
                currentUserId: 'bob',
                api: api,
              ),
            ),
          ),
        ));

    testWidgets('a spoiler photo arrives sealed and a tap reveals it', (
      tester,
    ) async {
      await tester.pumpWidget(bubble(photo()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MediaSpoilerCover), findsOneWidget);
      expect(find.byType(SpoilerDust), findsOneWidget);

      await tester.tap(find.byType(MediaSpoilerCover));
      await tester.pump();
      await tester.pump(kMediaSpoilerReveal + const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.byType(SpoilerDust), findsNothing);
      expect(
        SpoilerStore.instance.isRevealed(MediaSpoilerCover.storeKey('p1')),
        isTrue,
      );
    });

    testWidgets('an ordinary photo wears no cover at all', (tester) async {
      await tester.pumpWidget(bubble(photo(spoiler: false)));
      await tester.pump();
      expect(find.byType(MediaSpoilerCover), findsNothing);
    });
  });
}
