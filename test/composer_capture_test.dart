import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/composer/capture_machine.dart';
import 'package:monkeyhub/composer/capture_recorder.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_composer.dart';
import 'package:monkeyhub/widgets/composer_capture.dart';

/// The composer's capture control, through both composers.
///
/// **Both are covered on purpose, and every test runs twice.** Which composer
/// is built is a call-site decision keyed off the user's chat style — see the
/// header of `chat_composer.dart` — so a feature that reached only one of them
/// would ship broken for half the users and look perfect in every screenshot
/// taken by the other half. That is exactly the trap `chat_composer_test.dart`
/// already exists to catch for the camera button.
///
/// No microphone and no camera are touched anywhere here: the recorder is
/// injected through [ComposerCapture.recorderFactory]. What is being tested is
/// the gesture, the state it produces and the chrome that state draws — which
/// is everything about this feature that is not hardware.
void main() {
  late List<String> haptics;

  setUp(() {
    haptics = <String>[];
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add('${call.arguments}');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget host(Widget composer, {TextDirection direction = TextDirection.ltr}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Directionality(
        textDirection: direction,
        child: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: composer),
          ),
        ),
      ),
    );
  }

  final builders =
      <String, Widget Function({ComposerCapture? capture, VoidCallback? onCamera})>{
    'classic': ({capture, onCamera}) => ChatComposerClassic(
          controller: TextEditingController(),
          ephemeral: false,
          onSend: () {},
          onAttach: () {},
          onCamera: onCamera,
          capture: capture,
        ),
    'liquid': ({capture, onCamera}) => ChatComposerLiquid(
          controller: TextEditingController(),
          ephemeral: false,
          onSend: () {},
          onAttach: () {},
          onCamera: onCamera,
          capture: capture,
        ),
  };

  builders.forEach((name, build) {
    group(name, () {
      testWidgets('with no capture wired up, the composer is untouched',
          (tester) async {
        var taps = 0;
        await tester
            .pumpWidget(host(build(onCamera: () => taps++)));
        await tester.pumpAndSettle();

        // Both composers draw iOS's camera glyph.
        final camera = find.byIcon(CupertinoIcons.camera);
        expect(camera, findsOneWidget);
        expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
        await tester.tap(camera);
        expect(taps, 1);
      });

      testWidgets('starts on the camera, and a tap still opens it',
          (tester) async {
        var opened = 0;
        await tester.pumpWidget(host(build(
          onCamera: () => opened++,
          capture: _capture(onCamera: () => opened++),
        )));
        await tester.pumpAndSettle();

        // The button a user who never drags sees is the one they always had.
        expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
        await tester.tap(find.byIcon(Icons.photo_camera_outlined));
        await tester.pump();
        expect(opened, 1);
      });

      testWidgets('dragging up walks camera → voice → video note',
          (tester) async {
        await tester.pumpWidget(
            host(build(onCamera: () {}, capture: _capture())));
        await tester.pumpAndSettle();

        final button = find.byIcon(Icons.photo_camera_outlined);
        await tester.drag(button, const Offset(0, -kModeSwitchStep));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
        expect(haptics, hasLength(1), reason: 'one detent, one buzz');

        await tester.drag(find.byIcon(Icons.mic_none_outlined),
            const Offset(0, -kModeSwitchStep));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
        expect(haptics, hasLength(2));
      });

      // The switch axis is vertical precisely so it has no mirror image: the
      // button sits beside Send at the trailing edge with no room to travel
      // horizontally, and the horizontal axis already belongs to
      // slide-to-cancel. Up must therefore mean the same thing in Arabic.
      testWidgets('the drag is NOT mirrored in RTL — up is up', (tester) async {
        await tester.pumpWidget(host(
          build(onCamera: () {}, capture: _capture()),
          direction: TextDirection.rtl,
        ));
        await tester.pumpAndSettle();

        await tester.drag(find.byIcon(Icons.photo_camera_outlined),
            const Offset(0, -kModeSwitchStep));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget,
            reason: 'an upward drag advances in every writing direction');

        await tester.drag(find.byIcon(Icons.mic_none_outlined),
            const Offset(0, kModeSwitchStep));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget,
            reason: 'and downward walks back, mirrored or not');
      });

      // A drag-to-switch control is invisible to a screen reader and
      // unreachable from a keyboard. The arrow keys are one of the two routes
      // that fix that; the attachment sheet is the other.
      testWidgets('arrow keys switch modes without a pointer', (tester) async {
        await tester.pumpWidget(
            host(build(onCamera: () {}, capture: _capture())));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        // Walk focus onto the capture button, wherever it lands in the row.
        for (var i = 0; i < 6; i++) {
          // Up, matching the drag axis — the keyboard route should describe the
          // same gesture rather than introduce a second one.
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          if (find.byIcon(Icons.photo_camera_outlined).evaluate().isEmpty) break;
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
        }
        expect(find.byIcon(Icons.photo_camera_outlined), findsNothing,
            reason: 'the mode must be reachable with no pointer at all');
      });

      testWidgets('holding records, and the strip replaces the row',
          (tester) async {
        final recorder = _FakeRecorder();
        await tester.pumpWidget(host(build(
          onCamera: () {},
          capture: _capture(recorder: recorder),
        )));
        await tester.pumpAndSettle();

        await _toVoice(tester);
        haptics.clear();

        final gesture = await tester.startGesture(
            tester.getCenter(find.byIcon(Icons.mic_none_outlined)));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await tester.pump();
        await tester.pump();

        expect(recorder.started, isTrue);
        expect(haptics, isNotEmpty, reason: 'recording start must be felt');
        // The text field is gone: the strip owns the whole row while a
        // recording is live, which is also what keeps the drag out of the
        // field's gesture arena.
        expect(find.byType(TextField), findsNothing);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        // Never pumpAndSettle while anything here is live: the recording strip
        // pulses on a repeating controller and the elapsed readout runs off a
        // periodic timer, so there is no frame at which the tree goes quiet.
        // Bounded pumps throughout.
        await gesture.up();
        await _frames(tester);
        expect(recorder.cancelled, isTrue,
            reason: 'a release the gesture recognizer never saw is how this '
                'shipped broken once — the button is reparented into the strip '
                'under a GlobalKey precisely so onLongPressEnd still arrives');
        expect(find.byType(TextField), findsOneWidget,
            reason: 'a release before the minimum duration discards and the '
                'composer comes back');
      });

      testWidgets('sliding up locks, and the strip grows a send button',
          (tester) async {
        final recorder = _FakeRecorder();
        await tester.pumpWidget(host(build(
          onCamera: () {},
          capture: _capture(recorder: recorder),
        )));
        await tester.pumpAndSettle();
        await _toVoice(tester);

        final start = tester.getCenter(find.byIcon(Icons.mic_none_outlined));
        final gesture = await tester.startGesture(start);
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await tester.pump();
        haptics.clear();

        await tester.pump();
        await gesture.moveBy(const Offset(0, -kLockDragThreshold - 8));
        await tester.pump();
        expect(haptics, hasLength(1), reason: 'the lock must be felt');
        expect(find.byIcon(Icons.north_east), findsWidgets);

        await gesture.up();
        await _frames(tester);
        // Still recording after the finger came up — that is what "locked"
        // means, and the test that proves the lock does anything.
        expect(recorder.stopped, isFalse);
        expect(recorder.cancelled, isFalse);

        await tester.tap(find.byIcon(Icons.delete_outline));
        await _frames(tester);
        expect(recorder.cancelled, isTrue);
      });

      testWidgets('the delete control discards and never sends',
          (tester) async {
        final recorder = _FakeRecorder();
        final captured = <ComposerInputMode>[];
        await tester.pumpWidget(host(build(
          onCamera: () {},
          capture: _capture(
            recorder: recorder,
            onCaptured: (mode, _) => captured.add(mode),
          ),
        )));
        await tester.pumpAndSettle();
        await _toVoice(tester);

        final gesture = await tester.startGesture(
            tester.getCenter(find.byIcon(Icons.mic_none_outlined)));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await tester.pump();
        await gesture.moveBy(const Offset(0, -kLockDragThreshold - 8));
        await tester.pump();
        await gesture.up();
        await tester.pump();
        haptics.clear();

        await tester.tap(find.byIcon(Icons.delete_outline));
        await _frames(tester);

        expect(recorder.cancelled, isTrue);
        expect(recorder.stopped, isFalse);
        expect(captured, isEmpty, reason: 'a discard must never reach the send path');
        expect(haptics, isNotEmpty, reason: 'a discard must be felt');
        expect(find.byType(TextField), findsOneWidget,
            reason: 'the composer must come back');
      });

      testWidgets('a locked recording sends through its own button',
          (tester) async {
        final recorder = _FakeRecorder();
        final captured = <ComposerInputMode>[];
        await tester.pumpWidget(host(build(
          onCamera: () {},
          capture: _capture(
            recorder: recorder,
            onCaptured: (mode, _) => captured.add(mode),
          ),
        )));
        await tester.pumpAndSettle();
        await _toVoice(tester);

        final gesture = await tester.startGesture(
            tester.getCenter(find.byIcon(Icons.mic_none_outlined)));
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await tester.pump();
        await gesture.moveBy(const Offset(0, -kLockDragThreshold - 8));
        await tester.pump();
        await gesture.up();
        await _frames(tester);

        // Unambiguous: the strip replaces the whole row while recording, so
        // the composer's own send button is not in the tree to collide with.
        expect(find.byIcon(Icons.north_east), findsOneWidget);
        await tester.tap(find.byIcon(Icons.north_east));
        await _frames(tester);

        expect(recorder.stopped, isTrue);
        expect(recorder.cancelled, isFalse);
        expect(captured, [ComposerInputMode.voice]);
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('a voice note from the attachment sheet starts straight away',
          (tester) async {
        final controller = ComposerCaptureController();
        final recorder = _FakeRecorder();
        await tester.pumpWidget(host(build(
          onCamera: () {},
          capture: _capture(recorder: recorder, controller: controller),
        )));
        await tester.pumpAndSettle();

        controller.requestMode(ComposerInputMode.voice);
        await tester.pump();
        await tester.pump();

        // Requested AND started, hands-free: nobody taps "voice message" in a
        // sheet to be shown a button they then have to hold.
        expect(recorder.started, isTrue);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);

        await tester.tap(find.byIcon(Icons.delete_outline));
        await _frames(tester);
      });

      // A tap used to start a video note recording on the spot, and people
      // were caught mid-sentence by it. It stages the big preview instead;
      // only its record button records.
      testWidgets('a video note from the sheet waits for the record button',
          (tester) async {
        final l10n = AppLocalizationsEn();
        final controller = ComposerCaptureController();
        final recorder = _FakeRecorder();
        await tester.pumpWidget(host(build(
          onCamera: () {},
          capture: _capture(recorder: recorder, controller: controller),
        )));
        await tester.pumpAndSettle();

        controller.requestMode(ComposerInputMode.videoNote);
        await _frames(tester);
        expect(recorder.started, isFalse);
        expect(find.text(l10n.glassScreenPreviewBadge), findsOneWidget);
        final record = find.bySemanticsLabel(l10n.composerCaptureStartRecordingLabel);
        expect(record, findsOneWidget);

        await tester.tap(record);
        await _frames(tester);
        expect(recorder.started, isTrue);
        // Recording: the circle says so, and no longer says "preview".
        expect(find.text(l10n.glassScreenPreviewBadge), findsNothing);
        expect(find.text('0:00'), findsWidgets);
        expect(record, findsNothing);

        await tester.tap(find.byIcon(Icons.delete_outline));
        await _frames(tester);
        expect(recorder.cancelled, isTrue);
      });

      testWidgets('a tap on the video-note button stages, and closing un-stages',
          (tester) async {
        final l10n = AppLocalizationsEn();
        final controller = ComposerCaptureController();
        final recorder = _FakeRecorder();
        await tester.pumpWidget(host(build(
          onCamera: () {},
          capture: _capture(recorder: recorder, controller: controller),
        )));
        await tester.pumpAndSettle();
        controller.requestMode(ComposerInputMode.videoNote);
        await _frames(tester);

        await tester.tap(find.bySemanticsLabel(l10n.photoChromeCloseSemanticLabel));
        await _frames(tester);
        expect(find.text(l10n.glassScreenPreviewBadge), findsNothing);

        await tester.tap(find.byIcon(Icons.videocam_outlined));
        await _frames(tester);
        expect(recorder.started, isFalse, reason: 'a tap is not a recording');
        expect(find.text(l10n.glassScreenPreviewBadge), findsOneWidget);
      });
    });
  });
}

/// Advances a bounded number of frames. Never `pumpAndSettle` around a live
/// recording — the pulse repeats forever and the elapsed timer is periodic, so
/// settling is a state this UI deliberately never reaches.
Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Drags the capture button up one detent, onto voice.
Future<void> _toVoice(WidgetTester tester) async {
  await tester.drag(find.byIcon(Icons.photo_camera_outlined),
      const Offset(0, -kModeSwitchStep));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
}

ComposerCapture _capture({
  VoidCallback? onCamera,
  CaptureRecorder? recorder,
  void Function(ComposerInputMode, CaptureOutcome)? onCaptured,
  ComposerCaptureController? controller,
}) {
  return ComposerCapture(
    modes: ComposerInputMode.values,
    onCamera: onCamera ?? () {},
    controller: controller,
    onCaptured: onCaptured ?? (_, _) {},
    onProblem: (_) {},
    recorderFactory: recorder == null ? null : (_) => recorder,
  );
}

/// A recorder that records nothing and remembers being asked.
class _FakeRecorder implements CaptureRecorder {
  bool started = false;
  bool stopped = false;
  bool cancelled = false;

  @override
  VoidCallback? onSessionLost;

  @override
  Stream<double>? get levels => null;

  @override
  Future<void> start() async => started = true;

  @override
  Future<CaptureOutcome> stop() async {
    stopped = true;
    return CaptureOutcome(
      bytes: Uint8List.fromList(const [1, 2, 3]),
      contentType: 'audio/mp4',
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> dispose() async {}
}
