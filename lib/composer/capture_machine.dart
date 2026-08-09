import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the composer's right-hand action button is currently for.
///
/// Ordered, and the order is the drag order: the button starts on [camera] and
/// travels toward the send button through [voice] to [videoNote]. Reversing
/// them would reverse the gesture, so nothing here may be reordered without
/// re-reading [ComposerCaptureMachine.updateModeDrag].
enum ComposerInputMode {
  /// One tap opens the in-app camera. The behaviour this button has always had.
  camera,

  /// Hold to record a voice note.
  voice,

  /// Hold to record a short circular video note.
  videoNote,
}

/// Where a recording is in its life.
///
/// [holding] and [locked] are both "recording"; they differ only in who ends
/// it. That distinction is the whole point of the lock gesture and is why this
/// is not a bool: a release under [holding] sends, a release under [locked] is
/// simply the user lifting a finger off a control that is no longer listening.
enum CaptureStage {
  idle,

  /// Recording with the finger still down. Releasing sends; sliding away from
  /// the send button cancels; sliding up locks.
  holding,

  /// Recording hands-free. Ends only through the explicit send or delete
  /// controls, the max duration, or an interruption.
  locked,

  /// Stop is in flight — the encoder is being closed and the bytes read. A
  /// distinct stage because the UI must not offer a second stop, and because a
  /// lifecycle event arriving here must not try to stop again.
  finishing,
}

/// How a hold ended.
enum HoldOutcome {
  /// Release past the minimum duration, inside the control: send it.
  send,

  /// Slid to cancel, released outside the control, or released too early.
  cancel,

  /// The finger came up but the recording is locked and carries on. Nothing to
  /// do — the explicit controls own it now.
  locked,
}

/// How far the button travels between two adjacent modes.
///
/// Deliberately shorter than a full "swipe": the button has at most two
/// neighbours and the whole gesture has to fit between the text field and the
/// send button on a small phone. 56 is roughly a thumb's comfortable arc and
/// leaves the third mode reachable without stretching.
const double kModeSwitchStep = 56;

/// Upward travel, during a hold, that latches the recording hands-free.
const double kLockDragThreshold = 64;

/// Travel away from the send button, during a hold, that aborts the recording.
///
/// Larger than [kLockDragThreshold] on purpose. Locking by accident costs a tap
/// to undo; cancelling by accident throws the recording away.
const double kCancelDragThreshold = 96;

/// Shorter than this and a hold was a mis-tap, not a message.
///
/// Both big-corp messengers do exactly this, and for the reason it looks like:
/// a 200 ms voice note is never something anyone meant to send, and a recorder
/// stopped that fast often has not written a playable container at all.
const Duration kMinRecordingDuration = Duration(milliseconds: 700);

/// Ceiling on a video note. The big-corp value, and it is the value for a
/// reason — a circular note is a glance, not a film, and the file has to fit
/// inside the send path's retained-bytes budget.
const Duration kVideoNoteMaxDuration = Duration(seconds: 60);

/// Ceiling on a voice note. Longer than a video note because audio is cheap,
/// but still finite: `ChatRepository` holds every unfinished upload's bytes in
/// memory against a 48 MB budget, and an unbounded recorder is a way to spend
/// all of it in one message.
const Duration kVoiceNoteMaxDuration = Duration(minutes: 5);

/// How long before the ceiling the countdown appears.
const Duration kMaxDurationWarning = Duration(seconds: 10);

/// The ceiling for [mode], or null where the mode does not record.
Duration? maxDurationFor(ComposerInputMode mode) => switch (mode) {
      ComposerInputMode.camera => null,
      ComposerInputMode.voice => kVoiceNoteMaxDuration,
      ComposerInputMode.videoNote => kVideoNoteMaxDuration,
    };

/// Converts a raw horizontal delta into travel *away from the send button* —
/// leftward in a left-to-right layout, rightward in Arabic.
///
/// Used by the slide-to-cancel gesture only. Every horizontal decision goes
/// through here rather than reading `dx`, so there is exactly one place that
/// knows where Send is and exactly one thing to test in both writing
/// directions.
double travelAwayFromSend(double dx, TextDirection direction) =>
    direction == TextDirection.rtl ? dx : -dx;

/// Converts a raw vertical delta into upward travel, which is what advances the
/// input mode: camera → voice → video note.
///
/// Up because there is room up. The button sits beside Send at the trailing
/// edge of the composer with barely a dozen points between it and the screen,
/// and [kModeSwitchStep] is 56 with the far mode two steps out — 112pt that do
/// not exist horizontally in the direction of Send. The first cut of this
/// control read the brief's "drag the camera button left to send button" as a
/// direction ("drag left, toward send") when it was describing the button's
/// placement (the one to the left OF send). Horizontally it was unreachable in
/// one direction and, once flipped, competed with slide-to-cancel in the other.
/// Vertical has the room and its own axis.
///
/// Flutter's y grows downward, so an upward drag arrives negative and this
/// flips it. No [TextDirection]: up is up in every script.
double travelUpward(double dy) => -dy;

/// Which mode a cumulative drag of [travel] from [from] lands on.
///
/// Pure, and separated from the machine so the arithmetic can be tested without
/// a widget, a pointer or a haptic channel. Clamped rather than wrapped: a
/// drag that runs off the end of the list should rest on the last mode, not
/// silently cycle back to the camera the user was dragging away from.
ComposerInputMode modeForTravel({
  required ComposerInputMode from,
  required double travel,
  required List<ComposerInputMode> modes,
  double step = kModeSwitchStep,
}) {
  if (modes.isEmpty) return from;
  final origin = modes.indexOf(from);
  if (origin < 0) return modes.first;
  // Rounded, not truncated: the button should settle on whichever mode it is
  // nearest, so the halfway point is where the switch happens in both
  // directions. Truncating would make the return trip need a full extra step
  // before it gave the previous mode back.
  final steps = (travel / step).round();
  final index = (origin + steps).clamp(0, modes.length - 1);
  return modes[index];
}

/// The composer's input-mode and recording state, with the haptics that belong
/// to each transition.
///
/// A [ChangeNotifier] rather than widget state so that:
///
///  * both composer variants can share one instance — see the header of
///    `chat_composer.dart` for why those two widgets are deliberately not
///    unified, and why neither may become stateful;
///  * every transition here is testable with no camera, no microphone and no
///    pointer, which is the only way any of this is testable at all.
///
/// It owns no plugin, no timer and no file. The widget drives it and a
/// [CaptureRecorder] does the work; this only says what state we are in and
/// buzzes when that changes.
class ComposerCaptureMachine extends ChangeNotifier {
  ComposerCaptureMachine({
    List<ComposerInputMode> modes = ComposerInputMode.values,
    ComposerInputMode initial = ComposerInputMode.camera,
  })  : modes = List.unmodifiable(modes),
        _mode = modes.contains(initial) ? initial : modes.first;

  /// Which modes this host offers, in drag order. The thread overlay omits
  /// [ComposerInputMode.camera] because the camera is a full-screen route and
  /// the overlay is a root `OverlayEntry` that a route would fight; see
  /// `thread_overlay.dart`.
  final List<ComposerInputMode> modes;

  ComposerInputMode _mode;
  ComposerInputMode get mode => _mode;

  CaptureStage _stage = CaptureStage.idle;
  CaptureStage get stage => _stage;

  bool get isRecording =>
      _stage == CaptureStage.holding || _stage == CaptureStage.locked;

  /// Cumulative horizontal travel of the live mode drag, toward the send
  /// button, for the button's own offset. Zero when no drag is in progress.
  double _modeDrag = 0;
  double get modeDrag => _modeDrag;

  /// The mode the button sat on when the current drag began, so the drag is
  /// measured from where it started rather than accumulating rounding error.
  ComposerInputMode _dragOrigin = ComposerInputMode.camera;
  bool _dragging = false;
  bool get draggingMode => _dragging;

  /// Live 0..1 progress toward the lock and cancel thresholds, for the
  /// affordances that grow as the finger approaches them.
  double _lockProgress = 0;
  double get lockProgress => _lockProgress;
  double _cancelProgress = 0;
  double get cancelProgress => _cancelProgress;

  /// Whether the finger has left the control's own hit area. A release there
  /// cancels rather than sends — the safe outcome for a gesture that ended
  /// somewhere the user was not aiming.
  bool _outside = false;

  // ─────────────────────────────── mode drag ───────────────────────────────

  void beginModeDrag() {
    if (isRecording) return;
    _dragging = true;
    _dragOrigin = _mode;
    _modeDrag = 0;
    notifyListeners();
  }

  /// Feeds the drag a raw vertical delta. Buzzes once per mode crossed.
  ///
  /// Vertical, and takes no [TextDirection]: up is up in every script, so
  /// unlike the cancel gesture this axis has no mirror image to get wrong.
  void updateModeDrag(double dy) {
    if (!_dragging) return;
    _modeDrag += travelUpward(dy);
    final next = modeForTravel(
      from: _dragOrigin,
      travel: _modeDrag,
      modes: modes,
    );
    if (next != _mode) {
      _mode = next;
      // One buzz per mode boundary, not one per frame — the guard above is what
      // makes that true, and it is the whole difference between a control that
      // feels detented and one that feels like a stuck motor.
      HapticFeedback.selectionClick();
    }
    notifyListeners();
  }

  void endModeDrag() {
    if (!_dragging) return;
    _dragging = false;
    _modeDrag = 0;
    notifyListeners();
  }

  /// Switches modes without a drag: the keyboard's arrow keys, a screen
  /// reader's custom action, or the attachment sheet picking one directly.
  ///
  /// This is the accessible route the drag can never be. A mode reachable only
  /// by dragging is a mode a VoiceOver user does not have.
  void selectMode(ComposerInputMode next, {bool haptic = true}) {
    if (isRecording || !modes.contains(next) || next == _mode) return;
    _mode = next;
    if (haptic) HapticFeedback.selectionClick();
    notifyListeners();
  }

  /// Steps [delta] modes along, clamped. Bound to arrow keys, where [delta] is
  /// already resolved for direction by the caller.
  void stepMode(int delta) {
    final i = modes.indexOf(_mode);
    if (i < 0) return;
    selectMode(modes[(i + delta).clamp(0, modes.length - 1)]);
  }

  // ──────────────────────────────── recording ──────────────────────────────

  /// The recorder has started. Called by the widget only once bytes are
  /// actually being written, so the UI never claims to be recording a stream
  /// that failed to open.
  void markRecording() {
    if (_stage != CaptureStage.idle) return;
    _stage = CaptureStage.holding;
    _lockProgress = 0;
    _cancelProgress = 0;
    _outside = false;
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  /// Feeds the hold a movement, in the control's local coordinates, measured
  /// from where the finger went down. Returns true when this movement latched
  /// the lock, so the caller can announce it.
  bool updateHold(Offset offset, TextDirection direction, {bool outside = false}) {
    if (_stage != CaptureStage.holding) return false;
    _outside = outside;
    // Up is negative dy. A drag that goes down is not "un-locking", it is just
    // no progress toward locking — hence the clamp rather than a signed value.
    final up = (-offset.dy).clamp(0.0, double.infinity);
    // Away from send — the same axis and the same sign as the mode drag, not
    // its mirror, so no negation here. See [travelAwayFromSend].
    final away = travelAwayFromSend(offset.dx, direction).clamp(0.0, double.infinity);

    _lockProgress = (up / kLockDragThreshold).clamp(0.0, 1.0);
    _cancelProgress = (away / kCancelDragThreshold).clamp(0.0, 1.0);

    // Cancel is checked first. Both thresholds can be crossed by one diagonal
    // drag, and of the two possible readings the destructive one must win: a
    // user who has dragged far enough to cancel has said so, and locking them
    // into a recording they were trying to abandon is the worse failure.
    if (_cancelProgress >= 1) {
      notifyListeners();
      return false;
    }
    if (_lockProgress >= 1) {
      _stage = CaptureStage.locked;
      _lockProgress = 1;
      _cancelProgress = 0;
      HapticFeedback.heavyImpact();
      notifyListeners();
      return true;
    }
    notifyListeners();
    return false;
  }

  /// Whether the live hold has been dragged past the cancel threshold.
  bool get wouldCancel => _cancelProgress >= 1;

  /// The finger came up. Says what should happen to the recording; the caller
  /// owns actually stopping it, because only the caller knows how long it ran.
  ///
  /// [elapsed] is checked here rather than by the caller so that the minimum
  /// duration is one rule in one place, applied identically to a release, a
  /// slide-to-cancel and a lifecycle abort.
  HoldOutcome endHold({required Duration elapsed}) {
    if (_stage == CaptureStage.locked) return HoldOutcome.locked;
    if (_stage != CaptureStage.holding) return HoldOutcome.cancel;
    final cancelled = _cancelProgress >= 1 ||
        _outside ||
        elapsed < kMinRecordingDuration;
    if (cancelled) {
      markCancelled();
      return HoldOutcome.cancel;
    }
    _stage = CaptureStage.finishing;
    notifyListeners();
    return HoldOutcome.send;
  }

  /// A locked recording was sent by its explicit control.
  void markFinishing() {
    if (_stage == CaptureStage.idle || _stage == CaptureStage.finishing) return;
    _stage = CaptureStage.finishing;
    notifyListeners();
  }

  /// Aborted: slid to cancel, the delete control, a revoked permission, a
  /// backgrounded app. Buzzes, because a discard the user cannot see happening
  /// (their finger is over the control) has to be felt.
  void markCancelled() {
    if (_stage == CaptureStage.idle) return;
    _stage = CaptureStage.idle;
    _lockProgress = 0;
    _cancelProgress = 0;
    _outside = false;
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  /// Back to rest with no buzz — the recording has already been handed to the
  /// send path, and a second haptic on top of the send's own reads as a
  /// stutter. Same reasoning as `room_screen.dart`'s `_jumpToLatest`.
  void markIdle() {
    if (_stage == CaptureStage.idle) return;
    _stage = CaptureStage.idle;
    _lockProgress = 0;
    _cancelProgress = 0;
    _outside = false;
    notifyListeners();
  }
}
