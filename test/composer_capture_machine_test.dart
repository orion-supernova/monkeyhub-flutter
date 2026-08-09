import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/composer/capture_machine.dart';

/// The composer's input-mode and recording state machine.
///
/// Everything about this feature that is NOT hardware lives in
/// `capture_machine.dart` precisely so that it can be tested here: the camera
/// and the microphone cannot be exercised in a test at all, so the drag
/// arithmetic, the RTL mirror, the lock/cancel thresholds and every haptic have
/// to be verifiable without them or they are verifiable nowhere.
///
/// Haptics are asserted rather than assumed. They are the only feedback a user
/// gets for a mode switch their thumb is covering and for a lock that happens
/// mid-gesture, so a change that silently drops one is a change that makes the
/// control feel broken while every screenshot still looks right. They travel as
/// `HapticFeedback.vibrate` over `SystemChannels.platform`, which is the same
/// place `chat_row_long_press_test.dart` reads them from.
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

  ComposerCaptureMachine build({
    List<ComposerInputMode> modes = ComposerInputMode.values,
  }) =>
      ComposerCaptureMachine(modes: modes);

  group('travelAwayFromSend', () {
    // The sign here is the bug this control shipped with, so it is worth
    // stating what the numbers mean rather than only asserting them. The
    // button sits beside Send at the trailing edge; the room to drag is in the
    // other direction. Leftward in LTR must therefore be POSITIVE travel, or
    // `modeForTravel`'s clamp pins the mode on camera forever and the whole
    // control is dead to the only drag a thumb can actually perform.
    test('counts leftward travel as positive in a left-to-right layout', () {
      expect(travelAwayFromSend(-30, TextDirection.ltr), 30);
      expect(travelAwayFromSend(30, TextDirection.ltr), -30);
    });

    // The whole RTL story is this one sign flip, which is why every horizontal
    // decision in the machine goes through this function rather than reading
    // `dx`. Arabic mirrors the composer, so Send is the leading item and the
    // room to drag is to the right.
    test('is mirrored in a right-to-left layout', () {
      expect(travelAwayFromSend(30, TextDirection.rtl), 30);
      expect(travelAwayFromSend(-30, TextDirection.rtl), -30);
    });
  });

  group('modeForTravel', () {
    const modes = ComposerInputMode.values;

    test('stays put below half a step', () {
      expect(
        modeForTravel(
            from: ComposerInputMode.camera, travel: 20, modes: modes),
        ComposerInputMode.camera,
      );
    });

    test('advances one mode per step', () {
      expect(
        modeForTravel(
            from: ComposerInputMode.camera,
            travel: kModeSwitchStep,
            modes: modes),
        ComposerInputMode.voice,
      );
      expect(
        modeForTravel(
            from: ComposerInputMode.camera,
            travel: kModeSwitchStep * 2,
            modes: modes),
        ComposerInputMode.videoNote,
      );
    });

    // Clamped rather than wrapped. Wrapping would put the camera back under a
    // thumb that is dragging away from it, which is the one thing a detented
    // control must never do.
    test('clamps at both ends instead of wrapping', () {
      expect(
        modeForTravel(
            from: ComposerInputMode.camera,
            travel: kModeSwitchStep * 9,
            modes: modes),
        ComposerInputMode.videoNote,
      );
      expect(
        modeForTravel(
            from: ComposerInputMode.camera,
            travel: -kModeSwitchStep * 9,
            modes: modes),
        ComposerInputMode.camera,
      );
    });

    test('comes back on the return trip at the same halfway point', () {
      expect(
        modeForTravel(
            from: ComposerInputMode.videoNote,
            travel: -kModeSwitchStep,
            modes: modes),
        ComposerInputMode.voice,
      );
    });
  });

  group('mode drag', () {
    // Up is a NEGATIVE dy — Flutter's y grows downward — so every drag that
    // advances a mode here is written negative. Getting this backwards is the
    // bug this control shipped with, in its horizontal incarnation: the button
    // followed the finger while `modeForTravel`'s clamp pinned the mode on
    // camera, so the whole feature looked alive and did nothing.
    test('buzzes once per boundary crossed, not once per frame', () {
      final m = build();
      m.beginModeDrag();
      // Ten frames of upward drag that together cross exactly one boundary.
      for (var i = 0; i < 10; i++) {
        m.updateModeDrag(-kModeSwitchStep / 8);
      }
      expect(m.mode, ComposerInputMode.voice);
      expect(haptics, hasLength(1));
      m.endModeDrag();
    });

    test('crossing two boundaries buzzes twice', () {
      final m = build();
      m.beginModeDrag();
      m.updateModeDrag(-kModeSwitchStep);
      m.updateModeDrag(-kModeSwitchStep);
      expect(m.mode, ComposerInputMode.videoNote);
      expect(haptics, hasLength(2));
    });

    test('dragging back down returns to the previous mode', () {
      final m = build();
      m.beginModeDrag();
      m.updateModeDrag(-kModeSwitchStep * 2);
      expect(m.mode, ComposerInputMode.videoNote);
      // The return trip switches at the same halfway point it advanced on,
      // which is what `modeForTravel` rounds rather than truncates for.
      m.updateModeDrag(kModeSwitchStep);
      expect(m.mode, ComposerInputMode.voice);
      m.updateModeDrag(kModeSwitchStep);
      expect(m.mode, ComposerInputMode.camera);
    });

    test('downward drag from camera clamps rather than wrapping', () {
      final m = build();
      m.beginModeDrag();
      m.updateModeDrag(kModeSwitchStep * 3);
      expect(m.mode, ComposerInputMode.camera);
      expect(haptics, isEmpty);
    });

    test('a drag does nothing while a recording is live', () {
      final m = build();
      m.markRecording();
      haptics.clear();
      m.beginModeDrag();
      m.updateModeDrag(-kModeSwitchStep * 3);
      expect(m.mode, ComposerInputMode.camera);
      expect(haptics, isEmpty);
    });
  });

  group('non-gesture routes', () {
    // The accessibility contract: every mode has to be reachable without a
    // drag, or the video note is a feature a screen-reader user does not have.
    test('selectMode reaches any mode and buzzes', () {
      final m = build();
      m.selectMode(ComposerInputMode.videoNote);
      expect(m.mode, ComposerInputMode.videoNote);
      expect(haptics, hasLength(1));
    });

    test('selectMode refuses a mode this host does not offer', () {
      final m = build(modes: const [
        ComposerInputMode.voice,
        ComposerInputMode.videoNote,
      ]);
      m.selectMode(ComposerInputMode.camera);
      expect(m.mode, ComposerInputMode.voice);
      expect(haptics, isEmpty);
    });

    test('stepMode clamps at both ends', () {
      final m = build();
      m.stepMode(-1);
      expect(m.mode, ComposerInputMode.camera);
      m.stepMode(1);
      m.stepMode(1);
      m.stepMode(1);
      expect(m.mode, ComposerInputMode.videoNote);
    });
  });

  group('hold', () {
    ComposerCaptureMachine recording() {
      final m = build();
      m.selectMode(ComposerInputMode.voice);
      m.markRecording();
      haptics.clear();
      return m;
    }

    test('starting a recording buzzes', () {
      final m = build();
      m.markRecording();
      expect(m.stage, CaptureStage.holding);
      expect(haptics, hasLength(1));
    });

    test('sliding up past the threshold locks, and buzzes once', () {
      final m = recording();
      m.updateHold(const Offset(0, -kLockDragThreshold / 2), TextDirection.ltr);
      expect(m.stage, CaptureStage.holding);
      expect(m.lockProgress, closeTo(0.5, 0.01));
      expect(haptics, isEmpty);

      final locked =
          m.updateHold(const Offset(0, -kLockDragThreshold), TextDirection.ltr);
      expect(locked, isTrue);
      expect(m.stage, CaptureStage.locked);
      expect(haptics, hasLength(1));

      // Already locked: further movement must not buzz again.
      m.updateHold(const Offset(0, -200), TextDirection.ltr);
      expect(haptics, hasLength(1));
    });

    test('a locked recording survives the finger coming up', () {
      final m = recording();
      m.updateHold(const Offset(0, -kLockDragThreshold), TextDirection.ltr);
      expect(m.endHold(elapsed: const Duration(seconds: 3)),
          HoldOutcome.locked);
      expect(m.stage, CaptureStage.locked);
    });

    test('releasing after the minimum duration sends', () {
      final m = recording();
      expect(m.endHold(elapsed: const Duration(seconds: 3)), HoldOutcome.send);
      expect(m.stage, CaptureStage.finishing);
      // No buzz on the send path — the send has its own, and two in a row read
      // as a stutter.
      expect(haptics, isEmpty);
    });

    test('releasing too early cancels silently to the caller but buzzes', () {
      final m = recording();
      expect(
        m.endHold(elapsed: kMinRecordingDuration - const Duration(milliseconds: 1)),
        HoldOutcome.cancel,
      );
      expect(m.stage, CaptureStage.idle);
      expect(haptics, hasLength(1));
    });

    test('sliding away from send past the threshold cancels', () {
      final m = recording();
      m.updateHold(const Offset(-kCancelDragThreshold, 0), TextDirection.ltr);
      expect(m.wouldCancel, isTrue);
      expect(m.endHold(elapsed: const Duration(seconds: 5)), HoldOutcome.cancel);
      expect(m.stage, CaptureStage.idle);
      expect(haptics, hasLength(1));
    });

    test('the cancel direction is mirrored in RTL', () {
      final m = recording();
      // In a mirrored layout, away-from-send is a POSITIVE dx.
      m.updateHold(const Offset(-kCancelDragThreshold, 0), TextDirection.rtl);
      expect(m.wouldCancel, isFalse);
      m.updateHold(const Offset(kCancelDragThreshold, 0), TextDirection.rtl);
      expect(m.wouldCancel, isTrue);
    });

    // One diagonal drag can cross both thresholds at once. Of the two readings,
    // the destructive one has to win: a user who has dragged far enough to
    // cancel has said so, and latching them into a recording they were trying
    // to abandon is the worse failure.
    test('cancel beats lock on a drag that crosses both', () {
      final m = recording();
      final locked = m.updateHold(
        const Offset(-kCancelDragThreshold, -kLockDragThreshold),
        TextDirection.ltr,
      );
      expect(locked, isFalse);
      expect(m.stage, CaptureStage.holding);
      expect(m.wouldCancel, isTrue);
    });

    test('releasing outside the control cancels rather than sends', () {
      final m = recording();
      m.updateHold(Offset.zero, TextDirection.ltr, outside: true);
      expect(m.endHold(elapsed: const Duration(seconds: 5)), HoldOutcome.cancel);
      expect(m.stage, CaptureStage.idle);
    });

    test('markIdle is the silent way home, markCancelled the loud one', () {
      final m = recording();
      m.markIdle();
      expect(m.stage, CaptureStage.idle);
      expect(haptics, isEmpty);

      final n = recording();
      n.markCancelled();
      expect(n.stage, CaptureStage.idle);
      expect(haptics, hasLength(1));
    });
  });

  group('maxDurationFor', () {
    test('gives the big-corp minute to a video note', () {
      expect(maxDurationFor(ComposerInputMode.videoNote),
          const Duration(seconds: 60));
    });

    test('gives audio a longer but still finite ceiling', () {
      final voice = maxDurationFor(ComposerInputMode.voice);
      expect(voice, isNotNull);
      expect(voice! > const Duration(seconds: 60), isTrue);
    });

    test('gives the camera none — it does not record', () {
      expect(maxDurationFor(ComposerInputMode.camera), isNull);
    });
  });
}
