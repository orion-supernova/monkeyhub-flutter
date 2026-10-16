import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/view_once_media.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_preview.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/audio_message.dart';
import 'package:monkeyhub/widgets/dust_dissolve.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/remote_image.dart';
import 'package:monkeyhub/widgets/video_note_message.dart';
import 'package:monkeyhub/widgets/view_once_seal.dart';

/// Play-once voice messages and video notes: the sealed bubbles, the one
/// watch, and the invariant they share with view-once photos.
///
/// That invariant comes first again. A sealed voice message must never build
/// an [AudioMessage] (it resolves through `AudioFileCache`, a persistent disk
/// copy), and a sealed video note never a [VideoNoteMessage] or a [RemoteImage]
/// (`VideoFileCache`, `CachedNetworkImage`). Any of those would leave a
/// readable copy on the device after the server had burned it.
///
/// No `pumpAndSettle` anywhere near a sealed video note: its dust twinkles on
/// a repeating clock, so the frames here are pumped by hand.
void main() {
  final api = ChatApi(ConvexBackend.instance);

  ChatMessage note({
    MessageType type = MessageType.audio,
    bool opened = false,
    DateTime? burnedAt,
    String senderId = 'alice',
    int? durationMs = 12000,
    bool self = false,
  }) => ChatMessage(
    id: 'm1',
    roomId: 'r',
    senderId: senderId,
    senderName: 'alice',
    content: '',
    createdAt: DateTime(2026, 3, 1, 12),
    type: type,
    status: MessageStatus.sent,
    mediaDurationMs: durationMs,
    viewOnce: true,
    viewOnceOpened: opened,
    viewOnceBurnedAt: burnedAt,
    viewOnceSelf: self,
  );

  // ThemeScope above the app, as in `app.dart`: the focus is pushed on the
  // root navigator, outside anything `home` wraps.
  Widget host(Widget child) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 500, child: child),
        ),
      ),
    ),
  );

  Widget bubble(
    ChatMessage m, {
    String currentUserId = 'bob',
    Future<Uint8List?> Function()? onOpen,
  }) => MessageBubble(
    message: m,
    now: DateTime(2026, 3, 1, 12),
    currentUserId: currentUserId,
    api: api,
    onOpenViewOnce: onOpen,
  );

  Future<void> show(WidgetTester tester, Widget w) async {
    await tester.pumpWidget(host(w));
    await tester.pump();
  }

  group('voice message', () {
    testWidgets('sealed: the pill with its length and the badge, no cache', (
      tester,
    ) async {
      await show(tester, bubble(note()));
      expect(find.byType(ViewOnceAudioMessage), findsOneWidget);
      // The disk-caching player must not be anywhere near this bubble.
      expect(find.byType(AudioMessage), findsNothing);
      expect(find.byType(ViewOnceCornerBadge), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
    });

    testWidgets('played, expired, and the sender\'s own say why', (
      tester,
    ) async {
      await show(tester, bubble(note(opened: true)));
      expect(find.text('0:12 · Played'), findsOneWidget);
      expect(find.byType(ViewOnceCornerBadge), findsNothing);

      await show(tester, bubble(note(burnedAt: DateTime(2026, 3, 15))));
      expect(find.text('0:12 · Expired'), findsOneWidget);

      // The photo rule: the sender has no replay path, so nothing on their
      // copy suggests one.
      await show(tester, bubble(note(), currentUserId: 'alice'));
      expect(find.text('0:12 · Play once'), findsOneWidget);
      expect(find.byType(AudioMessage), findsNothing);
    });

    testWidgets('sealed, played and expired share one silhouette', (
      tester,
    ) async {
      Future<Size> sizeOf(ChatMessage m) async {
        await show(tester, bubble(m));
        return tester.getSize(find.byType(ViewOnceAudioMessage));
      }

      final sealed = await sizeOf(note());
      expect(await sizeOf(note(opened: true)), sealed);
      expect(await sizeOf(note(burnedAt: DateTime(2026, 3, 15))), sealed);
      // AudioMessage's own geometry: a 34pt disc, 10 of gap, a 120pt column.
      expect(sealed.width, 164);
    });

    testWidgets('an unplayed note can be opened once; spent ones cannot', (
      tester,
    ) async {
      var opens = 0;
      Future<Uint8List?> open() async {
        opens++;
        return null;
      }

      final disc = find.descendant(
        of: find.byType(ViewOnceAudioMessage),
        matching: find.byType(Container),
      );

      await show(tester, bubble(note(), onOpen: open));
      await tester.tap(disc.first);
      await tester.pump();
      expect(opens, 1);

      for (final m in [
        note(opened: true),
        note(burnedAt: DateTime(2026, 3, 15)),
      ]) {
        await show(tester, bubble(m, onOpen: open));
        await tester.tap(find.byType(ViewOnceAudioMessage), warnIfMissed: false);
        await tester.pump();
      }
      await show(tester, bubble(note(), currentUserId: 'alice', onOpen: open));
      await tester.tap(find.byType(ViewOnceAudioMessage), warnIfMissed: false);
      await tester.pump();
      expect(opens, 1);
    });

    testWidgets('Saved Messages: the sender\'s copy is sealed and opens once', (
      tester,
    ) async {
      var opens = 0;
      Future<Uint8List?> open() async {
        opens++;
        return null;
      }

      await show(
        tester,
        bubble(note(self: true), currentUserId: 'alice', onOpen: open),
      );
      expect(find.byType(ViewOnceCornerBadge), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byType(ViewOnceAudioMessage),
              matching: find.byType(Container),
            )
            .first,
      );
      await tester.pump();
      expect(opens, 1);

      // Elsewhere the sender's copy stays spent.
      await show(tester, bubble(note(), currentUserId: 'alice', onOpen: open));
      expect(find.text('0:12 · Play once'), findsOneWidget);
      await tester.tap(find.byType(ViewOnceAudioMessage), warnIfMissed: false);
      await tester.pump();
      expect(opens, 1);
    });
  });

  group('video note', () {
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await SettingsStore.instance.setVideoNoteAutoAdvance(true);
    });
    tearDown(() => ViewOnceMedia.debugStageOverride = null);

    ChatMessage vnote({
      bool opened = false,
      DateTime? burnedAt,
      String senderId = 'alice',
      bool self = false,
    }) => note(
      type: MessageType.videoNote,
      opened: opened,
      burnedAt: burnedAt,
      senderId: senderId,
      self: self,
      durationMs: 8000,
    );

    testWidgets('sealed: the circle, the badge, the length, no cache', (
      tester,
    ) async {
      await show(tester, bubble(vnote()));
      expect(find.byType(ViewOnceVideoNote), findsOneWidget);
      expect(find.byType(VideoNoteMessage), findsNothing);
      expect(find.byType(RemoteImage), findsNothing);
      expect(find.byType(ViewOnceCornerBadge), findsOneWidget);
      expect(find.text('0:08'), findsOneWidget);
    });

    testWidgets('a micro poster is drawn from memory, never RemoteImage', (
      tester,
    ) async {
      final jpeg = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 16, height: 12)),
      );
      var loads = 0;
      await show(
        tester,
        ViewOnceVideoNote(
          messageId: 'm-poster',
          isMine: false,
          durationMs: 8000,
          opened: false,
          burned: false,
          posterStorageId: 'micro-1',
          diameter: 200,
          posterLoader: (_) async {
            loads++;
            return jpeg;
          },
        ),
      );
      await tester.pump();
      expect(loads, 1);
      expect(find.byType(RemoteImage), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Image && w.image is MemoryImage,
        ),
        findsOneWidget,
      );
    });

    testWidgets('played, expired and the sender\'s own: one silhouette', (
      tester,
    ) async {
      Future<Size> sizeOf(ChatMessage m, {String me = 'bob'}) async {
        await show(tester, bubble(m, currentUserId: me));
        return tester.getSize(find.byType(ViewOnceVideoNote));
      }

      final sealed = await sizeOf(vnote());
      expect(await sizeOf(vnote(opened: true)), sealed);
      expect(find.text('Played'), findsOneWidget);
      expect(await sizeOf(vnote(burnedAt: DateTime(2026, 3, 15))), sealed);
      expect(find.text('Expired'), findsOneWidget);
      expect(await sizeOf(vnote(), me: 'alice'), sealed);
      expect(find.text('Play once'), findsOneWidget);
      expect(find.byType(ViewOnceCornerBadge), findsNothing);
      expect(sealed.width, sealed.height);
    });

    testWidgets('Saved Messages: the sender\'s circle is sealed and opens once', (
      tester,
    ) async {
      var opens = 0;
      Future<Uint8List?> open() async {
        opens++;
        return null;
      }

      await show(
        tester,
        bubble(vnote(self: true), currentUserId: 'alice', onOpen: open),
      );
      expect(find.byType(ViewOnceCornerBadge), findsOneWidget);
      expect(find.text('Play once'), findsNothing);
      await tester.tap(find.byType(ViewOnceVideoNote));
      await tester.pump(const Duration(milliseconds: 20));
      expect(opens, 1);

      await show(tester, bubble(vnote(), currentUserId: 'alice', onOpen: open));
      expect(find.text('Play once'), findsOneWidget);
      await tester.tap(find.byType(ViewOnceVideoNote), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20));
      expect(opens, 1);
    });

    testWidgets('one watch: focus in once mode, released and spent after', (
      tester,
    ) async {
      final playback = _FakePlayback();
      var released = 0;
      ViewOnceMedia.debugStageOverride =
          (bytes, {required contentType, required extension}) async {
        expect(contentType, 'video/mp4');
        expect(extension, 'mp4');
        return ViewOnceMedia.fake('mem://note', onRelease: () => released++);
      };
      var opens = 0;
      await show(
        tester,
        ViewOnceVideoNote(
          messageId: 'm-watch',
          isMine: false,
          durationMs: 8000,
          opened: false,
          burned: false,
          diameter: 200,
          onOpen: () async {
            opens++;
            return Uint8List.fromList([1, 2, 3]);
          },
          playbackFactory: (source, isFile) {
            expect(source, 'mem://note');
            return playback;
          },
        ),
      );

      await tester.tap(find.byType(ViewOnceVideoNote));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(opens, 1);
      final focus = tester.widget<VideoNoteFocus>(find.byType(VideoNoteFocus));
      expect(focus.once, isTrue);
      // Nothing to carry on into, so no autoplay toggle.
      expect(focus.open, isNull);
      expect(focus.upNext, isEmpty);
      expect(playback.isPlaying, isTrue);
      // No transport row in once mode: a Close pill, no pause.
      expect(find.bySemanticsLabel('Close'), findsWidgets);
      expect(find.byIcon(CupertinoIcons.pause_fill), findsNothing);

      // It plays to the end, and the end is a close, never a replay.
      playback.complete();
      // A beat on the last frame (250ms), then the burn.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      // The circle burns to dust in place; the bubble beneath already
      // reads as spent.
      expect(tester.widget<DustDissolve>(find.byType(DustDissolve)).active, isTrue);
      expect(find.byType(VideoNoteFocus), findsOneWidget);
      expect(find.text('Played'), findsOneWidget);
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(VideoNoteFocus), findsNothing);
      expect(playback.seeks, 0);
      expect(playback.disposed, isTrue);
      expect(released, 1);
      // Back in the transcript, spent, and not openable again.
      expect(find.text('Played'), findsOneWidget);
      await tester.tap(find.byType(ViewOnceVideoNote), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 20));
      expect(opens, 1);
    });

    testWidgets('a look that came back empty leaves the circle sealed', (
      tester,
    ) async {
      var opens = 0;
      await show(
        tester,
        bubble(
          vnote(),
          onOpen: () async {
            opens++;
            return null;
          },
        ),
      );
      await tester.tap(find.byType(ViewOnceVideoNote));
      await tester.pump(const Duration(milliseconds: 20));
      expect(opens, 1);
      expect(find.byType(VideoNoteFocus), findsNothing);
    });
  });

  group('sending', () {
    test('the micro poster is sixteen pixels and under the cap', () async {
      final frame = img.Image(width: 480, height: 360);
      img.fill(frame, color: img.ColorRgb8(200, 120, 60));
      final full = Uint8List.fromList(img.encodeJpg(frame, quality: 90));
      final micro = await viewOnceMicroPoster(full);
      expect(micro, isNotNull);
      expect(micro!.length, lessThanOrEqualTo(kViewOnceMicroPosterMaxBytes));
      final back = img.decodeJpg(micro)!;
      expect(back.width, kViewOnceMicroPosterSide);
      expect(back.height, lessThanOrEqualTo(kViewOnceMicroPosterSide));
    });

    test('no poster in, no poster out', () async {
      expect(await viewOnceMicroPoster(null), isNull);
      expect(await viewOnceMicroPoster(Uint8List(0)), isNull);
    });
  });

  test('previews name the kind', () {
    expect(messagePreviewLine(note()), 'voice message · play once');
    expect(
      messagePreviewLine(note(type: MessageType.videoNote)),
      'video note · play once',
    );
    expect(
      messagePreviewLine(note(type: MessageType.image)),
      'photo · view once',
    );
  });
}

class _FakePlayback extends ChangeNotifier implements VideoNotePlayback {
  @override
  final Duration duration = const Duration(seconds: 8);
  int seeks = 0;
  bool disposed = false;

  Duration _position = Duration.zero;
  bool _playing = false;
  bool _completed = false;

  void complete() {
    _completed = true;
    _position = duration;
    notifyListeners();
  }

  @override
  Future<void> load() async {}

  @override
  Duration get position => _position;

  @override
  bool get isPlaying => _playing;

  @override
  bool get isCompleted => _completed;

  @override
  Future<void> play() async {
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> seekToStart() async {
    seeks++;
    _position = Duration.zero;
    _completed = false;
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration position) async {
    seeks++;
    _position = position;
    notifyListeners();
  }

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Widget view() => const ColoredBox(color: Color(0xFF102030));

  @override
  // ignore: must_call_super
  void dispose() => disposed = true;
}
