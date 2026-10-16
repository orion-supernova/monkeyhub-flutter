import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/photo_chrome.dart' show MediaDurationBadge;
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

  group('scrub geometry', () {
    test('the rate slows as the finger moves away from the circle', () {
      expect(videoNoteScrubRateFor(80, 100), VideoNoteScrubRate.full);
      expect(videoNoteScrubRateFor(160, 100), VideoNoteScrubRate.half);
      expect(videoNoteScrubRateFor(240, 100), VideoNoteScrubRate.fine);
    });

    test('a finger resting on a boundary keeps its rate', () {
      // Just past the full/half line: a fresh read says half, but a finger
      // already scrubbing at full stays there until it is clearly over.
      expect(videoNoteScrubRateFor(138, 100), VideoNoteScrubRate.half);
      expect(
        videoNoteScrubRateFor(138, 100, current: VideoNoteScrubRate.full),
        VideoNoteScrubRate.full,
      );
      expect(
        videoNoteScrubRateFor(186, 100, current: VideoNoteScrubRate.fine),
        VideoNoteScrubRate.fine,
      );
    });

    test('crossing 9 o\'clock is a small step, not a whole turn back', () {
      // atan2 jumps from π to -π there.
      final d = videoNoteAngleDelta(math.pi - 0.05, -math.pi + 0.05);
      expect(d, closeTo(0.1, 1e-9));
      expect(videoNoteAngleDelta(0.2, 0.1), closeTo(-0.1, 1e-9));
    });

    test('a full turn at full rate is the whole note; fine is a quarter', () {
      const total = Duration(seconds: 60);
      expect(
        videoNoteScrubBy(
          from: Duration.zero,
          turn: math.pi / 2,
          rate: VideoNoteScrubRate.full,
          total: total,
        ),
        const Duration(seconds: 15),
      );
      expect(
        videoNoteScrubBy(
          from: Duration.zero,
          turn: math.pi / 2,
          rate: VideoNoteScrubRate.fine,
          total: total,
        ),
        const Duration(milliseconds: 3750),
      );
    });

    test('a scrub never leaves the note', () {
      const total = Duration(seconds: 8);
      expect(
        videoNoteScrubBy(
          from: const Duration(seconds: 7),
          turn: math.pi,
          rate: VideoNoteScrubRate.full,
          total: total,
        ),
        total,
      );
      expect(
        videoNoteScrubBy(
          from: const Duration(seconds: 1),
          turn: -math.pi,
          rate: VideoNoteScrubRate.full,
          total: total,
        ),
        Duration.zero,
      );
    });
  });

  group('the bubble', () {
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await SettingsStore.instance.setVideoNoteAutoAdvance(true);
    });

    // ThemeScope above the app, as in `app.dart`: the focus is pushed on the
    // root navigator, outside anything `home` wraps.
    Widget host(Widget child) => ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Center(child: child)),
          ),
        );

    VideoNoteMessage build({
      required _FakePlayback playback,
      Future<(String, bool)?> Function(String)? resolve,
      int? durationMs = 8000,
      String storageId = 'note-1',
      Map<String, _FakePlayback> others = const {},
    }) {
      return VideoNoteMessage(
        api: _NullApi(),
        storageId: storageId,
        isMine: false,
        durationMs: durationMs,
        resolveSource: resolve ?? (id) async => (id, false),
        playbackFactory: (source, _) => others[source] ?? playback,
        upNext: () => [
          for (final id in others.keys)
            VideoNoteRef(storageId: id, durationMs: 8000),
        ],
      );
    }

    final focus = find.byType(VideoNoteFocus);

    /// A playing note ticks every frame, so nothing ever settles: pump past
    /// the flight instead.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    /// The focused circle, found by the countdown drawn inside it.
    Finder circle() => find.descendant(
          of: focus,
          matching: find.byType(MediaDurationBadge),
        );

    Future<void> open(WidgetTester tester, _FakePlayback playback) async {
      await tester.pumpWidget(host(build(playback: playback)));
      await settle(tester);
      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);
    }

    testWidgets('starts idle, showing the length and never opening a pipeline',
        (tester) async {
      final playback = _FakePlayback();
      await tester.pumpWidget(host(build(playback: playback)));
      await settle(tester);

      // A transcript with ten notes in it must not open ten video pipelines as
      // it scrolls — the regression `video_message.dart`'s header documents
      // having already been fixed once for plain videos.
      expect(playback.loads, 0);
      expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);
      expect(find.text('0:08'), findsOneWidget);
      expect(focus, findsNothing);
    });

    testWidgets('a tap loads, lifts the note into focus, and plays',
        (tester) async {
      final playback = _FakePlayback();
      await open(tester, playback);

      expect(playback.loads, 1);
      expect(playback.isPlaying, isTrue);
      expect(focus, findsOneWidget);
      expect(playback.speeds, [1.0]);
      // Playing: the pause button, and no play glyph over the picture.
      expect(find.byIcon(CupertinoIcons.pause_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.play_fill), findsNothing);
    });

    // Two separate one-frame bugs lived here: a PageRoute is held offstage by
    // the HeroController on its first frame, and a freshly swapped-in
    // placeholder has a size but no position yet. Either way the note
    // vanished or jumped to the corner as the flight began.
    testWidgets('the flight leaves from exactly where the bubble was',
        (tester) async {
      final playback = _FakePlayback();
      await tester.pumpWidget(host(build(playback: playback)));
      await settle(tester);
      final bubble = tester.getRect(find.byType(VideoNoteMessage));

      await tester.tap(find.byType(VideoNoteMessage));
      await tester.pump();
      final flying = tester.getRect(find.descendant(
        of: focus,
        matching: find.byType(ClipOval),
      ).first);
      expect(flying, bubble);
      await settle(tester);
    });

    testWidgets('in focus, a tap on the circle pauses and a second resumes',
        (tester) async {
      final playback = _FakePlayback();
      await open(tester, playback);

      await tester.tap(circle());
      await settle(tester);
      expect(playback.isPlaying, isFalse);
      expect(focus, findsOneWidget, reason: 'pausing is not closing');

      await tester.tap(circle());
      await settle(tester);
      expect(playback.isPlaying, isTrue);
      expect(playback.seeks, 0, reason: 'a pause is not an end');
    });

    testWidgets('the pause button pauses', (tester) async {
      final playback = _FakePlayback();
      await open(tester, playback);

      await tester.tap(find.byIcon(CupertinoIcons.pause_fill));
      await settle(tester);
      expect(playback.isPlaying, isFalse);
    });

    testWidgets('the speed pill cycles 1×, 1.5×, 2× and resets on close',
        (tester) async {
      final playback = _FakePlayback();
      await open(tester, playback);

      expect(find.text('1×'), findsOneWidget);
      await tester.tap(find.text('1×'));
      await settle(tester);
      expect(find.text('1.5×'), findsOneWidget);
      await tester.tap(find.text('1.5×'));
      await settle(tester);
      expect(find.text('2×'), findsOneWidget);
      expect(playback.speeds.last, 2.0);

      // A speed is for one sitting: the next time the note opens it is 1×.
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(playback.speeds.last, 1.0);
      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);
      expect(find.text('1×'), findsOneWidget);
      expect(playback.speeds.last, 1.0);
    });

    testWidgets('with autoplay on, a finished note carries on into the next',
        (tester) async {
      final first = _FakePlayback();
      final second = _FakePlayback();
      await tester.pumpWidget(host(build(
        playback: first,
        others: {'note-2': second},
      )));
      await settle(tester);
      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);

      // 2× on the first carries into the second: same sitting.
      await tester.tap(find.text('1×'));
      await settle(tester);
      await tester.tap(find.text('1.5×'));
      await settle(tester);

      first.complete();
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(focus, findsOneWidget, reason: 'advanced, not closed');
      expect(second.loads, 1);
      expect(second.isPlaying, isTrue);
      expect(second.speeds, [2.0]);
      expect(find.text('2×'), findsOneWidget);

      // Nothing after the second: it ends and the focus closes.
      second.complete();
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(focus, findsNothing);
      expect(second.disposed, isTrue,
          reason: 'a player the focus opened is the focus\'s to release');
      expect(first.disposed, isFalse, reason: 'the tapped note is its bubble\'s');
    });

    testWidgets('with autoplay off, a finished note just closes',
        (tester) async {
      final first = _FakePlayback();
      final second = _FakePlayback();
      await tester.pumpWidget(host(build(
        playback: first,
        others: {'note-2': second},
      )));
      await settle(tester);
      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);

      await tester.tap(find.text(AppLocalizationsEn().videoNoteAutoAdvanceOn));
      await settle(tester);
      expect(SettingsStore.instance.videoNoteAutoAdvance, isFalse);

      first.complete();
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(focus, findsNothing);
      expect(second.loads, 0);
    });

    testWidgets('the ring moves between position reports', (tester) async {
      final playback = _FakePlayback(duration: const Duration(seconds: 60));
      await open(tester, playback);
      // No report arrives; the ring coasts on the clock, up to its cap.
      Finder ring() => find.descendant(
            of: focus,
            matching: find.byType(MediaDurationBadge),
          );
      expect(find.descendant(of: ring(), matching: find.text('1:00')),
          findsOneWidget);
      playback.advance(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 200));
      // 0.9s reported + up to 0.2s coasted: 0:59, not still 1:00.
      expect(find.descendant(of: ring(), matching: find.text('0:59')),
          findsOneWidget);
    });

    testWidgets('the readout counts down while playing', (tester) async {
      final playback = _FakePlayback();
      await open(tester, playback);

      playback.advance(const Duration(seconds: 3));
      await settle(tester);
      expect(find.text('0:05'), findsOneWidget);
    });

    testWidgets('a tap outside the circle closes it, paused, back in place',
        (tester) async {
      final playback = _FakePlayback();
      await open(tester, playback);

      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(focus, findsNothing);
      expect(playback.isPlaying, isFalse);
      expect(find.byType(VideoNoteMessage), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);

      // Reopening carries on from where it was left, not from the top.
      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);
      expect(focus, findsOneWidget);
      expect(playback.isPlaying, isTrue);
      expect(playback.seeks, 0);
    });

    // The whole reason `videoNoteDisplayFor` exists, end to end: a finished
    // note must offer PLAY, not PAUSE, and the tap that follows must rewind
    // before it plays or it appears to do nothing.
    testWidgets('a finished note flies home and replays on one tap',
        (tester) async {
      final playback = _FakePlayback();
      await open(tester, playback);

      playback.complete();
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(focus, findsNothing, reason: 'the end closes the focus');
      expect(find.byIcon(CupertinoIcons.play_fill), findsOneWidget);
      expect(find.text('0:08'), findsOneWidget);

      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);
      expect(playback.seeks, 1, reason: 'rewound before replaying');
      expect(playback.isPlaying, isTrue);
      expect(focus, findsOneWidget);
    });

    testWidgets('a drag a quarter of the way round scrubs a quarter of the note',
        (tester) async {
      final playback = _FakePlayback();
      await open(tester, playback);

      final rect = tester.getRect(find.descendant(
        of: focus,
        matching: find.byType(ClipOval),
      ).first);
      final c = rect.center;
      final r = rect.width / 2 * 0.8;
      Offset at(double turns) {
        final a = -math.pi / 2 + turns * math.pi * 2;
        return c + Offset(math.cos(a), math.sin(a)) * r;
      }

      final g = await tester.startGesture(at(0));
      // Through the slop first, then round the clock to 3 o'clock.
      for (var i = 1; i <= 40; i++) {
        await g.moveTo(at(0.25 * i / 40));
        await tester.pump();
      }
      expect(playback.isPlaying, isFalse, reason: 'held while scrubbing');
      expect(find.text(AppLocalizationsEn().videoNoteScrubHint), findsOneWidget);
      await g.up();
      await settle(tester);

      // Slop eats the first sliver of the turn, so a touch under a quarter.
      expect(playback.position.inMilliseconds, inInclusiveRange(1700, 2000));
      expect(playback.isPlaying, isTrue, reason: 'resumes where it let go');
      expect(focus, findsOneWidget);
    });

    testWidgets('a note recycled while open keeps playing; the focus releases it',
        (tester) async {
      final playback = _FakePlayback();
      await open(tester, playback);
      expect(focus, findsOneWidget);

      // `message_bubble.dart` builds this with no key, so a row can be handed
      // a different message while its note is open — autoplay scrolling the
      // chat does exactly that.
      await tester.pumpWidget(host(build(
        playback: _FakePlayback(),
        storageId: 'note-2',
      )));
      await settle(tester);
      expect(focus, findsOneWidget);
      expect(playback.disposed, isFalse, reason: 'still on screen');
      expect(playback.isPlaying, isTrue);

      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      expect(focus, findsNothing);
      expect(playback.disposed, isTrue);
    });

    testWidgets('a source the backend no longer has offers no retry',
        (tester) async {
      final playback = _FakePlayback();
      await tester.pumpWidget(host(build(
        playback: playback,
        resolve: (_) async => null,
      )));
      await settle(tester);
      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);

      expect(find.byIcon(CupertinoIcons.slash_circle), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing,
          reason: 'a burned or swept blob cannot be retried into existence');
      expect(focus, findsNothing);
    });

    testWidgets('a source that will not open offers a retry that works',
        (tester) async {
      final playback = _FakePlayback(failFirstLoad: true);
      await tester.pumpWidget(host(build(playback: playback)));
      await settle(tester);

      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsOneWidget);
      expect(find.text(l10n.videoNoteMessageRetryHint), findsOneWidget);

      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsNothing);
      expect(playback.isPlaying, isTrue);
      expect(focus, findsOneWidget);
    });

    testWidgets('a message with no attachment is unavailable, not broken',
        (tester) async {
      await tester.pumpWidget(host(VideoNoteMessage(
        api: _NullApi(),
        storageId: null,
        isMine: true,
        playbackFactory: (_, _) => _FakePlayback(),
      )));
      await settle(tester);
      await tester.tap(find.byType(VideoNoteMessage));
      await settle(tester);
      expect(find.byIcon(CupertinoIcons.slash_circle), findsOneWidget);
    });
  });
}

/// A playback that plays nothing and remembers everything.
class _FakePlayback extends ChangeNotifier implements VideoNotePlayback {
  _FakePlayback({
    this.failFirstLoad = false,
    this.duration = const Duration(seconds: 8),
  });

  final bool failFirstLoad;

  @override
  final Duration duration;
  int loads = 0;
  int seeks = 0;
  final List<double> speeds = [];
  bool disposed = false;

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
    _position = position;
    _completed = position >= duration;
    notifyListeners();
  }

  @override
  Future<void> setSpeed(double speed) async => speeds.add(speed);

  @override
  Widget view() => const ColoredBox(color: Color(0xFF102030));

  /// Deliberately does NOT tear the notifier down. The widget disposes a
  /// playback that failed to load and then asks the factory for another, and
  /// this fake is that factory's only answer — a real `dispose` would make the
  /// retry throw "used after being disposed" and hide what the test is for.
  @override
  // ignore: must_call_super
  void dispose() => disposed = true;
}

/// The bubble resolves its source through the injected [resolveSource], so the
/// API is never reached. Present only because the constructor requires one.
class _NullApi implements ChatApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} must not be called');
}
