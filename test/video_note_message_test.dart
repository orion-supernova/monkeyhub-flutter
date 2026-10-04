import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/video_note_message.dart';

/// The circular video-note bubble.
///
/// Its playback is injected, so the whole state machine — loading, playing,
/// paused, ended, unavailable, failed — is exercised with no codec, no network
/// and no platform view. A `VideoPlayerController` cannot be initialized in a
/// widget test at all, so without the seam none of this would have a test and
/// the only way to find out that a finished note draws the wrong glyph would be
/// to watch one finish on a phone.
///
/// [videoNoteDisplayFor] gets its own group because the bug it exists to
/// prevent is arithmetic, not layout: `video_player` leaves `isPlaying` true
/// after a clip completes and the position stops a tick short of the duration,
/// so a note that has ended otherwise draws a pause glyph over a ring that
/// never closes and needs two taps to replay. `audio_message.dart` shipped
/// exactly that bug once; this is the version that does not.
void main() {
  final l10n = AppLocalizationsEn();

  group('videoNoteDisplayFor', () {
    test('a completed note is stopped, full, and rewound to its length', () {
      final d = videoNoteDisplayFor(
        // What the player actually reports at the end: still "playing".
        rawPlaying: true,
        completed: true,
        position: const Duration(seconds: 7, milliseconds: 900),
        total: const Duration(seconds: 8),
      );
      expect(d.playing, isFalse);
      expect(d.progress, 1);
      expect(d.remaining, const Duration(seconds: 8),
          reason: 'the readout goes back to the full length, ready to replay');
    });

    test('mid-playback counts down and fills proportionally', () {
      final d = videoNoteDisplayFor(
        rawPlaying: true,
        completed: false,
        position: const Duration(seconds: 3),
        total: const Duration(seconds: 12),
      );
      expect(d.playing, isTrue);
      expect(d.progress, closeTo(0.25, 0.001));
      expect(d.remaining, const Duration(seconds: 9));
    });

    test('an unknown duration draws an empty ring rather than dividing by zero',
        () {
      final d = videoNoteDisplayFor(
        rawPlaying: false,
        completed: false,
        position: Duration.zero,
        total: Duration.zero,
      );
      expect(d.progress, 0);
      expect(d.remaining, Duration.zero);
    });

    test('a position past the end never overfills the ring', () {
      final d = videoNoteDisplayFor(
        rawPlaying: true,
        completed: false,
        position: const Duration(seconds: 20),
        total: const Duration(seconds: 8),
      );
      expect(d.progress, 1);
      expect(d.remaining, Duration.zero);
    });
  });

  group('the bubble', () {
    Widget host(Widget child) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: Scaffold(body: Center(child: child)),
          ),
        );

    VideoNoteMessage build({
      required _FakePlayback playback,
      Future<(String, bool)?> Function(String)? resolve,
      int? durationMs = 8000,
    }) {
      return VideoNoteMessage(
        api: _NullApi(),
        storageId: 'note-1',
        isMine: false,
        durationMs: durationMs,
        resolveSource: resolve ?? (id) async => (id, false),
        playbackFactory: (_, _) => playback,
      );
    }

    testWidgets('starts idle, showing the length and never opening a pipeline',
        (tester) async {
      final playback = _FakePlayback();
      await tester.pumpWidget(host(build(playback: playback)));
      await tester.pumpAndSettle();

      // A transcript with ten notes in it must not open ten video pipelines as
      // it scrolls — the regression `video_message.dart`'s header documents
      // having already been fixed once for plain videos.
      expect(playback.loads, 0);
      expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);
      expect(find.text('0:08'), findsOneWidget);
    });

    testWidgets('a tap loads and plays', (tester) async {
      final playback = _FakePlayback();
      await tester.pumpWidget(host(build(playback: playback)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();

      expect(playback.loads, 1);
      expect(playback.isPlaying, isTrue);
      // Playing: no glyph over the picture, just the countdown.
      expect(find.byIcon(CupertinoIcons.play_fill), findsNothing);
    });

    testWidgets('a second tap pauses, a third resumes', (tester) async {
      final playback = _FakePlayback();
      await tester.pumpWidget(host(build(playback: playback)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();

      expect(playback.isPlaying, isFalse);
      expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);

      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();
      expect(playback.isPlaying, isTrue);
      expect(playback.seeks, 0, reason: 'a pause is not an end');
    });

    testWidgets('the readout counts down while playing', (tester) async {
      final playback = _FakePlayback();
      await tester.pumpWidget(host(build(playback: playback)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();

      playback.advance(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('0:05'), findsOneWidget);
    });

    // The whole reason `videoNoteDisplayFor` exists, end to end: a finished
    // note must offer PLAY, not PAUSE, and the tap that follows must rewind
    // before it plays or it appears to do nothing.
    testWidgets('a finished note replays on one tap', (tester) async {
      final playback = _FakePlayback();
      await tester.pumpWidget(host(build(playback: playback)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();

      playback.complete();
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);
      expect(find.text('0:08'), findsOneWidget);

      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();
      expect(playback.seeks, 1, reason: 'rewound before replaying');
      expect(playback.isPlaying, isTrue);
    });

    testWidgets('a source the backend no longer has offers no retry',
        (tester) async {
      final playback = _FakePlayback();
      await tester.pumpWidget(host(build(
        playback: playback,
        resolve: (_) async => null,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();

      expect(find.byIcon(CupertinoIcons.slash_circle), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing,
          reason: 'a burned or swept blob cannot be retried into existence');
    });

    testWidgets('a source that will not open offers a retry that works',
        (tester) async {
      final playback = _FakePlayback(failFirstLoad: true);
      await tester.pumpWidget(host(build(playback: playback)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsOneWidget);
      expect(find.text(l10n.videoNoteMessageRetryHint), findsOneWidget);

      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing);
      expect(playback.isPlaying, isTrue);
    });

    testWidgets('a message with no attachment is unavailable, not broken',
        (tester) async {
      await tester.pumpWidget(host(VideoNoteMessage(
        api: _NullApi(),
        storageId: null,
        isMine: true,
        playbackFactory: (_, _) => _FakePlayback(),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.slash_circle), findsOneWidget);
    });
  });
}

/// A playback that plays nothing and remembers everything.
class _FakePlayback extends ChangeNotifier implements VideoNotePlayback {
  _FakePlayback({this.failFirstLoad = false});

  final bool failFirstLoad;
  int loads = 0;
  int seeks = 0;

  Duration _position = Duration.zero;
  bool _playing = false;
  bool _completed = false;

  void advance(Duration by) {
    _position += by;
    notifyListeners();
  }

  void complete() {
    _completed = true;
    _position = duration;
    notifyListeners();
  }

  @override
  Future<void> load() async {
    loads++;
    if (failFirstLoad && loads == 1) throw StateError('cannot open');
  }

  @override
  Duration get position => _position;

  @override
  Duration get duration => const Duration(seconds: 8);

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
  Widget view() => const ColoredBox(color: Color(0xFF102030));

  /// Deliberately does NOT tear the notifier down. The widget disposes a
  /// playback that failed to load and then asks the factory for another, and
  /// this fake is that factory's only answer — a real `dispose` would make the
  /// retry throw "used after being disposed" and hide what the test is for.
  @override
  // ignore: must_call_super
  void dispose() {}
}

/// The bubble resolves its source through the injected [resolveSource], so the
/// API is never reached. Present only because the constructor requires one.
class _NullApi implements ChatApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} must not be called');
}
