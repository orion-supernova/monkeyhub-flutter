import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, listEquals, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../composer/capture_machine.dart';
import '../composer/capture_permissions.dart';
import '../composer/capture_recorder.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/room_items.dart' show formatClockDuration;
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show quietFill;
import 'destructive_sheet.dart';
import 'liquid_glass.dart';

/// Which composer this capture control is drawn inside.
///
/// The two composers are deliberately not unified — see the header of
/// `chat_composer.dart` — so the control cannot pick one look. It takes the
/// style as a parameter instead, which is the same shape the rest of the
/// composer's chrome already has: one behaviour, two skins, chosen by the call
/// site that already knows which composer it is building.
enum ComposerCaptureStyle { classic, liquid }

/// A handle for driving the capture control from outside the composer.
///
/// Exists for exactly one reason: the attachment sheet has to be able to reach
/// the two recording modes. A control whose only route is a horizontal drag is
/// a control a screen-reader user, a keyboard user and anyone who has not
/// discovered the gesture cannot use at all — and the sheet is the one place in
/// this app where every attachment already has a name and a tap target.
///
/// Deliberately one-shot rather than a bound mode: the host is asking for
/// something to happen now, not declaring state, and a `ValueNotifier<Mode>`
/// would re-fire the request on every rebuild.
class ComposerCaptureController extends ChangeNotifier {
  ComposerInputMode? _pending;

  /// Switch to [mode] and, when it records, start immediately and hands-free.
  void requestMode(ComposerInputMode mode) {
    _pending = mode;
    notifyListeners();
  }

  /// Reads and clears the request. Called by the control; nothing else should.
  ComposerInputMode? takePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }
}

/// What the host lets the composer capture, and where the results go.
///
/// Passing null for the whole thing leaves both composers exactly as they were:
/// the plain camera button, no drag, no recorder, no lifecycle observer. That
/// is what the tests and any host that has no media path get.
@immutable
class ComposerCapture {
  const ComposerCapture({
    required this.modes,
    required this.onCaptured,
    required this.onProblem,
    this.onCamera,
    this.controller,
    this.recorderFactory,
  });

  /// The non-gesture route into each mode. See [ComposerCaptureController].
  final ComposerCaptureController? controller;

  /// Which modes this host offers, in drag order. Must be non-empty.
  ///
  /// The room offers all three. A host with no full-screen route available
  /// omits [ComposerInputMode.camera] and keeps the two that record inline.
  final List<ComposerInputMode> modes;

  /// A finished recording, ready to send. Called on the frame the bytes are
  /// read, not when the upload finishes — the send path is optimistic and owns
  /// everything after this.
  final void Function(ComposerInputMode mode, CaptureOutcome outcome) onCaptured;

  /// Something went wrong, or was refused. The host decides how to say so,
  /// because the two hosts have different surfaces for it — a `SnackBar` in a
  /// `Scaffold`, a toast inside a root overlay. [showCaptureProblem] is the
  /// shared implementation both of them can call.
  final void Function(CaptureFailure failure) onProblem;

  /// Opens the camera. Required when [modes] contains
  /// [ComposerInputMode.camera]; the mode is dropped when it is null, so a host
  /// cannot accidentally ship a camera button that does nothing.
  final VoidCallback? onCamera;

  /// Builds the recorder for a mode. Null uses the real microphone and camera.
  ///
  /// The seam that makes the *gesture* testable. Hold-to-record, slide-to-lock,
  /// slide-to-cancel and the recording strip they produce are all pure UI on
  /// top of a recorder, and none of them could be exercised at all if the only
  /// recorder were one that opens a microphone. With this, everything except
  /// the bytes themselves has a test.
  ///
  /// Also suppresses the video-note preview: a fake recorder has no camera
  /// session to warm.
  @visibleForTesting
  final CaptureRecorder Function(ComposerInputMode mode)? recorderFactory;
}

/// Wraps a composer's row so it can record.
///
/// Everything stateful about the feature lives here rather than in either
/// composer, which is what lets both of them stay `StatelessWidget` and keeps
/// the rebuild-on-style-change contract in `chat_composer.dart` intact: the
/// hosts still listen to `SettingsStore` and still choose the composer, and
/// this widget's state is rebuilt from scratch when they swap — which is
/// correct, because a style change mid-recording is not a thing that can
/// happen (the settings screen is a different route).
///
/// [builder] is handed the mode button to place where the camera button used to
/// go, or null when the host wired no capture up. While a recording is live the
/// builder is not called at all: the row is replaced by the recording strip,
/// the way every messenger does it, which is also what keeps the drag gesture
/// from ever having to share an arena with the text field.
class ComposerCaptureHost extends StatefulWidget {
  const ComposerCaptureHost({
    super.key,
    required this.capture,
    required this.style,
    required this.builder,
    this.openHintRoomId,
  });

  final ComposerCapture? capture;
  final ComposerCaptureStyle style;
  final Widget Function(BuildContext context, Widget? modeButton) builder;

  /// The room this composer belongs to, or null to never play the
  /// mode-switch hint (bump + tooltip) on mount.
  ///
  /// Non-null only for the room's own composer — the thread overlay builds
  /// this same widget for its own mode button and passes null: a thread is
  /// opened far more often than any one chatroom, and firing there too
  /// turned "teach the gesture once per room" into "play a bounce every time
  /// someone opens a thread," which is a bug, not a feature.
  ///
  /// The bump itself plays every time a room's composer mounts. Only the
  /// tooltip is gated per room, via [SettingsStore.shouldShowComposerModeHint]
  /// keyed on this id — a room already taught the user nothing the second
  /// time it is opened, but a room they have never opened shows it fresh
  /// regardless of what they've already learned elsewhere.
  final String? openHintRoomId;

  @override
  State<ComposerCaptureHost> createState() => _ComposerCaptureHostState();
}

class _ComposerCaptureHostState extends State<ComposerCaptureHost>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late ComposerCaptureMachine _machine = _buildMachine();
  late final AnimationController _modeBumpController;

  /// Drives the same rubbery bump as [_modeBumpController], at half amplitude,
  /// played every time the composer mounts with a room — so a chatroom that
  /// just opened nudges the mode button rather than leaving a
  /// screen-reader-only control to be discovered by accident. Unlike the
  /// tooltip, this is not gated on whether the room has been opened before.
  late final AnimationController _entranceBumpController;

  CaptureRecorder? _recorder;

  /// Held separately from [_recorder] because the preview needs the concrete
  /// type, and because the preview outlives any one recording: it is warmed
  /// when the button switches to video-note mode and released when it leaves.
  VideoNoteCaptureRecorder? _video;

  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;

  Timer? _tooltipTimer;
  bool _tooltipVisible = false;

  Timer? _entranceTimer;

  void _triggerTooltip() {
    _tooltipTimer?.cancel();
    if (!mounted) return;
    setState(() => _tooltipVisible = true);
    _tooltipTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _tooltipVisible = false);
    });
  }

  /// Guards the whole start/stop path against re-entry. A second long-press
  /// arriving while `start()` is still awaiting the platform would otherwise
  /// open two recorders onto one microphone.
  bool _busy = false;

  /// Where the finger went down, so hold movement is measured from the press
  /// rather than from the button's centre.
  Offset _holdOrigin = Offset.zero;

  /// Size of the button, for the released-outside test.
  Size _buttonSize = const Size(44, 44);

  /// Keeps the mode button's element — and therefore its gesture recognizers —
  /// alive across the swap from the composer row to the recording strip.
  ///
  /// This is load-bearing and was a real bug before it existed. Starting a
  /// recording replaces the whole row, which moves the button to a completely
  /// different position in the tree; without a global key Flutter rebuilds it
  /// from scratch, the `RawGestureDetector`'s state is disposed, and the
  /// long-press recognizer holding the live pointer dies with it. The symptom
  /// on a device is the worst kind: the hold starts a recording and then
  /// *releasing does nothing at all*, because `onLongPressEnd` is never
  /// delivered to a recognizer that no longer exists. A global key reparents
  /// the element instead, so the gesture that started the recording is the same
  /// gesture that ends it.
  final _modeButtonKey = GlobalKey();

  ComposerCaptureMachine _buildMachine() {
    final capture = widget.capture;
    final modes = _availableModes(capture);
    return ComposerCaptureMachine(modes: modes, initial: modes.first);
  }

  /// The modes this host can actually deliver.
  ///
  /// Camera is dropped without an `onCamera`, and both recording modes are
  /// dropped on the web — `record_web` writes a container the send path
  /// mislabels, and `camera_web` implements none of the video-recording API.
  /// Filtering here rather than at the call sites means a host cannot offer a
  /// mode that silently does nothing, which is the failure this whole feature
  /// is most likely to ship with.
  static List<ComposerInputMode> _availableModes(ComposerCapture? capture) {
    if (capture == null) return const [ComposerInputMode.camera];
    final out = [
      for (final m in capture.modes)
        if (m != ComposerInputMode.camera || capture.onCamera != null)
          if (!kIsWeb || m == ComposerInputMode.camera) m,
    ];
    return out.isEmpty ? const [ComposerInputMode.camera] : out;
  }

  @override
  void initState() {
    super.initState();

    _modeBumpController = AnimationController(vsync: this, duration: const Duration(milliseconds: 440));
    _entranceBumpController = AnimationController(vsync: this, duration: const Duration(milliseconds: 640));

    WidgetsBinding.instance.addObserver(this);
    // Orphans from a previous run, deleted before this one can add to them.
    unawaited(CaptureTempFiles.sweep());
    widget.capture?.controller?.addListener(_onExternalRequest);

    // Post-frame, not here: `_triggerTooltip` calls `setState`, which cannot
    // run while this element is still being mounted for the first time. The
    // extra delay on top of that is for the room's own push transition —
    // firing the instant the composer mounts plays the bump underneath a
    // still-sliding screen, where nobody is looking at it yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomId = widget.openHintRoomId;
      if (!mounted || widget.capture == null || roomId == null) return;
      // The tooltip still teaches the gesture once per room; the bump below
      // is not gated on that, so it decides nothing here beyond whether the
      // tooltip fires alongside it.
      final showTooltip = SettingsStore.instance.shouldShowComposerModeHint(roomId);
      _entranceTimer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        _entranceBumpController.forward(from: 0.0);
        if (showTooltip) {
          _triggerTooltip();
          unawaited(SettingsStore.instance.markComposerModeHintShown(roomId));
        }
      });
    });
  }

  /// The attachment sheet (or anything else holding the controller) asked for a
  /// mode. Switching *and* starting is deliberate: nobody taps "voice message"
  /// in a sheet to be shown a button they then have to hold.
  void _onExternalRequest() {
    final mode = widget.capture?.controller?.takePending();
    if (mode == null || !mounted || _machine.isRecording) return;
    if (!_machine.modes.contains(mode)) return;
    _machine.selectMode(mode);
    _onModeChanged();
    if (mode == ComposerInputMode.camera) {
      widget.capture?.onCamera?.call();
    } else {
      unawaited(_startRecording(locked: true));
    }
  }

  @override
  void didUpdateWidget(covariant ComposerCaptureHost old) {
    super.didUpdateWidget(old);
    // A host can change which modes it offers (a room whose media permission
    // was revoked). Rebuild rather than mutate: the machine's mode may no
    // longer exist, and a live recording under a changed mode list is not a
    // state worth preserving.
    if (old.capture?.controller != widget.capture?.controller) {
      old.capture?.controller?.removeListener(_onExternalRequest);
      widget.capture?.controller?.addListener(_onExternalRequest);
    }
    final before = _availableModes(old.capture);
    final now = _availableModes(widget.capture);
    if (listEquals(before, now)) return;
    unawaited(_abort(silent: true));
    _machine.dispose();
    _machine = _buildMachine();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.capture?.controller?.removeListener(_onExternalRequest);
    _ticker?.cancel();
    _tooltipTimer?.cancel();
    _entranceTimer?.cancel();
    // Fire-and-forget, because dispose cannot await: both implementations stop
    // the device and delete their temp file, and neither needs this widget to
    // still exist to finish doing it.
    final recorder = _recorder;
    final video = _video;
    _recorder = null;
    _video = null;
    unawaited(recorder?.dispose());
    if (!identical(video, recorder)) unawaited(video?.dispose());
    _modeBumpController.dispose();
    _entranceBumpController.dispose();
    _machine.dispose();
    super.dispose();
  }

  // ────────────────────────────── lifecycle ───────────────────────────────

  /// Two different rules, because "the app went away" means two different
  /// things depending on whether anything is being recorded.
  ///
  ///  * **Not recording.** Release the camera session on `inactive`, exactly as
  ///    `camera_screen.dart` does and for the same reason: the OS tears the
  ///    session down underneath a backgrounded app and the controller never
  ///    notices, so the preview comes back frozen forever. Re-acquired on
  ///    `resumed`.
  ///  * **Recording.** Only a real backgrounding (`paused`, `hidden`,
  ///    `detached`) aborts. `inactive` alone fires for things that are not a
  ///    backgrounding at all — the control centre pulled halfway down, an
  ///    incoming-call banner, the app switcher previewed — and throwing away a
  ///    recording for those would be maddening. A genuine seizure of the
  ///    microphone or camera arrives separately, through `onSessionLost`.
  ///
  /// A recording that is aborted is **discarded**, not sent. Auto-sending a
  /// half-finished message because a phone rang is a worse outcome than losing
  /// it, and it cannot be undone. Preserving it in a review state was the third
  /// option and was rejected: it adds a stage to the machine that exists only
  /// for this case, and a recording the user cannot see is one they have
  /// already stopped thinking about.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final backgrounded =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached;

    if (_machine.isRecording || _busy) {
      if (backgrounded) {
        unawaited(_abort(kind: CaptureFailureKind.interrupted));
      }
      return;
    }

    if (state == AppLifecycleState.inactive || backgrounded) {
      unawaited(_releasePreview());
    } else if (state == AppLifecycleState.resumed) {
      if (_machine.mode == ComposerInputMode.videoNote) {
        unawaited(_warmPreview());
      }
    }
  }

  // ──────────────────────────────── preview ───────────────────────────────

  /// Brings the video-note preview up. Lazy by construction: nothing calls this
  /// until the button is actually on [ComposerInputMode.videoNote], so a user
  /// who never touches the control never opens a capture session.
  Future<void> _warmPreview() async {
    // A test-supplied recorder has no session to warm, and warming one would
    // reach for a camera that is not there.
    if (!mounted || _video != null || widget.capture?.recorderFactory != null) {
      return;
    }
    final recorder = VideoNoteCaptureRecorder()..onSessionLost = _onSessionLost;
    _video = recorder;
    try {
      await recorder.warm();
    } catch (e) {
      final f = e is CaptureFailure ? e : const CaptureFailure(CaptureFailureKind.unavailable);
      if (!identical(_video, recorder)) return;
      _video = null;
      await recorder.dispose();
      if (!mounted) return;
      // Back to the mode before this one, so the button is never sitting on a
      // mode that cannot work. Silent — the problem itself is about to be
      // reported, and a second buzz on top of it reads as a stutter.
      _machine.selectMode(
        _machine.modes.firstWhere((m) => m != ComposerInputMode.videoNote, orElse: () => _machine.mode),
        haptic: false,
      );
      widget.capture?.onProblem(f);
      return;
    }
    if (!mounted) {
      await recorder.dispose();
      return;
    }
    setState(() {});
  }

  Future<void> _releasePreview() async {
    final recorder = _video;
    if (recorder == null) return;
    await recorder.release();
    if (mounted) setState(() {});
  }

  /// Drops the whole video recorder, not just its session — used when the
  /// button leaves video-note mode, where the preview is not coming back.
  Future<void> _dropVideoRecorder() async {
    final recorder = _video;
    if (recorder == null) return;
    _video = null;
    await recorder.dispose();
    if (mounted) setState(() {});
  }

  void _onModeChanged() {
    _modeBumpController.forward(from: 0.0);
    _triggerTooltip();

    if (_machine.mode == ComposerInputMode.videoNote) {
      unawaited(_warmPreview());
    } else {
      unawaited(_dropVideoRecorder());
    }
  }

  void _onSessionLost() {
    if (!mounted || !_machine.isRecording) return;
    unawaited(_abort(kind: CaptureFailureKind.interrupted));
  }

  // ─────────────────────────────── recording ──────────────────────────────

  Duration? get _maxDuration => maxDurationFor(_machine.mode);

  Future<void> _startRecording({required bool locked}) async {
    final capture = widget.capture;
    if (capture == null || _busy || _machine.isRecording) return;
    final mode = _machine.mode;
    if (mode == ComposerInputMode.camera) return;
    _busy = true;
    try {
      final CaptureRecorder recorder;
      final injected = capture.recorderFactory?.call(mode);
      if (injected != null) {
        recorder = injected;
      } else if (mode == ComposerInputMode.videoNote) {
        await _warmPreview();
        final video = _video;
        if (video == null) return; // _warmPreview already reported why
        recorder = video;
      } else {
        recorder = VoiceCaptureRecorder()..onSessionLost = _onSessionLost;
      }
      _recorder = recorder;
      recorder.onSessionLost = _onSessionLost;
      try {
        await recorder.start();
      } catch (e) {
        // Anything at all, not only [CaptureFailure]. A plugin that is not
        // installed throws `MissingPluginException`, a platform that refuses
        // the session throws its own type, and neither may be allowed to escape
        // as an unhandled async error and leave the UI claiming to record.
        _recorder = null;
        if (!identical(recorder, _video)) await recorder.dispose();
        if (mounted) {
          capture.onProblem(e is CaptureFailure ? e : const CaptureFailure(CaptureFailureKind.unavailable));
        }
        return;
      }
      if (!mounted) {
        // Cleared first: `dispose` cancels whatever [_recorder] holds, and a
        // second cancel on a recorder already torn down here is a platform call
        // against a session that no longer exists.
        _recorder = null;
        await recorder.cancel();
        if (!identical(recorder, _video)) await recorder.dispose();
        return;
      }
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _machine.markRecording();
      if (locked) _machine.updateHold(const Offset(0, -kLockDragThreshold), TextDirection.ltr);
      _announce(
        locked
            ? AppLocalizations.of(context).composerCaptureLockedAnnouncement
            : AppLocalizations.of(context).composerCaptureRecordingAnnouncement,
      );
      _startTicker();
    } finally {
      _busy = false;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    // 100 ms rather than a frame callback: the readout is `m:ss` and the ring
    // is a coarse arc, so sixty rebuilds a second would be spending battery to
    // redraw the same pixels.
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final started = _startedAt;
      if (!mounted || started == null) return;
      final elapsed = DateTime.now().difference(started);
      setState(() => _elapsed = elapsed);
      final max = _maxDuration;
      if (max != null && elapsed >= max) {
        // The ceiling sends rather than discards, and the countdown in the last
        // ten seconds is what makes that fair: by the time this fires the user
        // has watched it coming.
        unawaited(_finish());
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
  }

  /// Stop, read the bytes, hand them to the host.
  Future<void> _finish() async {
    final capture = widget.capture;
    final recorder = _recorder;
    if (capture == null || recorder == null || _busy) return;
    _busy = true;
    HapticFeedback.mediumImpact();
    final mode = _machine.mode;
    _machine.markFinishing();
    _stopTicker();
    try {
      final outcome = await _stopSafely(recorder);
      if (outcome.duration < kMinRecordingDuration) {
        // Can only happen on the locked path, where there is no release to
        // check the floor at. Silent: a note this short was a mis-tap.
        _machine.markIdle();
        return;
      }
      capture.onCaptured(mode, outcome);
      if (mounted) {
        _announce(AppLocalizations.of(context).composerCaptureSentAnnouncement);
      }
      _machine.markIdle();
    } on CaptureFailure catch (f) {
      _machine.markIdle();
      if (mounted && f.kind != CaptureFailureKind.tooShort) {
        capture.onProblem(f);
      }
    } finally {
      _busy = false;
      _recorder = null;
      if (!identical(recorder, _video)) unawaited(recorder.dispose());
      if (mounted) setState(() => _elapsed = Duration.zero);
    }
  }

  /// Normalises anything the recorder throws into a [CaptureFailure], for the
  /// same reason [_startRecording] does.
  Future<CaptureOutcome> _stopSafely(CaptureRecorder recorder) async {
    try {
      return await recorder.stop();
    } on CaptureFailure {
      rethrow;
    } catch (e) {
      debugPrint('capture stop failed: $e');
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
  }

  /// Throw the recording away. [silent] suppresses both the buzz and the
  /// message — used when the widget itself is going away.
  Future<void> _abort({CaptureFailureKind? kind, bool silent = false}) async {
    final recorder = _recorder;
    _stopTicker();
    _recorder = null;
    if (silent) {
      _machine.markIdle();
    } else {
      _machine.markCancelled();
    }
    if (recorder != null) {
      // Guarded: cancel is the path every other failure falls back to, so a
      // throw from here would be a failure with nothing left to catch it.
      try {
        await recorder.cancel();
      } catch (e) {
        debugPrint('capture cancel failed: $e');
      }
      if (!identical(recorder, _video)) {
        await recorder.dispose();
      } else if (recorder is VideoNoteCaptureRecorder) {
        // A canceled video note must not keep holding the camera+microphone
        // (the OS mic indicator stays lit) just because the button is still
        // on video mode. Release the session — the recorder object survives,
        // and the next hold-to-record re-warms it through start(); the cost
        // is that warm-up latency, not a leak.
        try {
          await recorder.release();
        } catch (e) {
          debugPrint('capture release after cancel failed: $e');
        }
        if (mounted) setState(() {});
      }
    }
    if (!mounted) return;
    if (!silent) {
      _announce(AppLocalizations.of(context).composerCaptureCancelledAnnouncement);
      if (kind != null) widget.capture?.onProblem(CaptureFailure(kind));
    }
    setState(() => _elapsed = Duration.zero);
  }

  void _announce(String message) {
    // Screen readers are the only audience: a drag-to-switch control and a
    // recording that starts on a hold are both completely invisible otherwise.
    //
    // `sendAnnouncement`, not the deprecated `announce`: the latter reads
    // `PlatformDispatcher.implicitView` and asserts when there isn't one, which
    // is every multi-window embedding.
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  }

  // ─────────────────────────────── gestures ───────────────────────────────

  TextDirection get _direction => Directionality.of(context);

  void _onTap() {
    final capture = widget.capture;
    if (capture == null || _machine.isRecording) return;
    _triggerTooltip();
    switch (_machine.mode) {
      case ComposerInputMode.camera:
        capture.onCamera?.call();
      case ComposerInputMode.voice:
      case ComposerInputMode.videoNote:
        // A tap starts a *locked* recording. This is the whole accessible
        // story for the hold gesture: a hold cannot be performed by a keyboard
        // and is not discoverable by a screen reader, so the same control has
        // to work as a plain button — and hands-free is the only sensible
        // reading of a button press that starts a recording nobody is holding.
        unawaited(_startRecording(locked: true));
    }
  }

  void _onLongPressStart(LongPressStartDetails d) {
    if (_machine.mode == ComposerInputMode.camera) return;
    _holdOrigin = d.localPosition;
    unawaited(_startRecording(locked: false));
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    if (!_machine.isRecording) return;
    final offset = d.localPosition - _holdOrigin;
    final locked = _machine.updateHold(offset, _direction, outside: _isOutsideCorridor(d.localPosition));
    if (locked) {
      _announce(AppLocalizations.of(context).composerCaptureLockedAnnouncement);
    }
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    if (!_machine.isRecording) return;
    // Fed one last time so a release that has never produced a move update —
    // a flick straight off the edge — is still judged on where it ended.
    _machine.updateHold(d.localPosition - _holdOrigin, _direction, outside: _isOutsideCorridor(d.localPosition));
    final outcome = _machine.endHold(elapsed: _elapsed);
    switch (outcome) {
      case HoldOutcome.send:
        unawaited(_finish());
      case HoldOutcome.cancel:
        unawaited(_abort());
      case HoldOutcome.locked:
        break; // carries on; the strip's own controls own it now
    }
  }

  void _onLongPressCancel() {
    // The recognizer gave up before the press became a long press. Nothing was
    // started, so there is nothing to stop — but if a start is in flight it
    // must not be left running under a finger that is gone.
    if (_machine.stage == CaptureStage.holding) unawaited(_abort());
  }

  /// Whether [local] is outside the region a release may still count as "on the
  /// control".
  ///
  /// Not simply the button's own rect. The lock gesture *requires* the finger
  /// to travel up and off the button, so treating the button's bounds as the
  /// whole control would cancel every recording anybody tried to lock. The
  /// corridor is the button plus the lane above it that the lock affordance
  /// occupies, plus a generous horizontal margin; a release beyond that — the
  /// finger flung down the screen, or off to the far side — is a gesture that
  /// ended somewhere the user was not aiming, and the safe reading of that is
  /// cancel.
  bool _isOutsideCorridor(Offset local) {
    const margin = 40.0;
    final corridor = Rect.fromLTRB(
      -margin,
      -(kLockDragThreshold + 56),
      _buttonSize.width + margin,
      _buttonSize.height + margin,
    );
    return !corridor.contains(local);
  }

  void _onArrow(int towardSend) {
    // Right-arrow means "toward send" in LTR and "away from send" in RTL, the
    // same mirror the drag goes through.
    _machine.stepMode(_direction == TextDirection.rtl ? -towardSend : towardSend);
    // Every route into a mode has to go through here, not just the drag —
    // otherwise arriving by keyboard leaves the camera unwarmed and the first
    // hold spends its first half-second opening a session.
    _onModeChanged();
    _announceMode();
  }

  void _announceMode() {
    _announce(AppLocalizations.of(context).composerCaptureModeAnnouncement(_modeLabel(_machine.mode)));
  }

  String _modeLabel(ComposerInputMode mode) {
    final l10n = AppLocalizations.of(context);
    return switch (mode) {
      ComposerInputMode.camera => l10n.composerCaptureCameraModeLabel,
      ComposerInputMode.voice => l10n.composerCaptureVoiceModeLabel,
      ComposerInputMode.videoNote => l10n.composerCaptureVideoNoteModeLabel,
    };
  }

  IconData _modeIcon(ComposerInputMode mode) => switch (mode) {
    // Unchanged from the button this replaces. A user who never drags must
    // see exactly the control they had.
    ComposerInputMode.camera => Icons.photo_camera_outlined,
    ComposerInputMode.voice => Icons.mic_none_outlined,
    ComposerInputMode.videoNote => Icons.videocam_outlined,
  };

  // ──────────────────────────────── build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (widget.capture == null) return widget.builder(context, null);
    return ListenableBuilder(
      listenable: _machine,
      builder: (context, _) {
        if (_machine.isRecording || _machine.stage == CaptureStage.finishing) {
          return _recordingBody(context);
        }
        final row = widget.builder(context, _keyedModeButton(context));
        // The idle preview. Shown for as long as the button sits on video-note
        // mode, and that is not decoration — it is what justifies holding a
        // capture session at all. Warming the camera on mode entry is what
        // makes the first hold instant and puts the permission prompt before
        // the gesture rather than in the middle of it, but a session held with
        // nothing on screen is battery, heat and a recording indicator the user
        // cannot account for. Either show the preview or let the camera go;
        // this shows it.
        if (_machine.mode != ComposerInputMode.videoNote || _video?.controller == null) {
          return row;
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(right: _previewTrailingGap(recording: false)),
              child: Align(
                alignment: Alignment.centerRight,
                child: _previewWithBadge(ThemeScope.of(context), idle: true),
              ),
            ),
            const SizedBox(height: 12),
            row,
          ],
        );
      },
    );
  }

  /// The button, keyed so it survives being reparented into the strip.
  Widget _keyedModeButton(BuildContext context) => KeyedSubtree(key: _modeButtonKey, child: _modeButton(context));

  double get _buttonDiameter => widget.style == ComposerCaptureStyle.classic ? 38 : 44;

  Widget _modeButton(BuildContext context) {
    final theme = ThemeScope.of(context);
    final mode = _machine.mode;
    final l10n = AppLocalizations.of(context);
    final diameter = _buttonDiameter;
    _buttonSize = Size(diameter, diameter);

    final glyph = _animatedGlyph(
      mode: mode,
      icon: _modeIcon(mode),
      size: 18,
      color: widget.style == ComposerCaptureStyle.classic
          ? (mode == ComposerInputMode.camera ? theme.inkSoft : theme.accent)
          : theme.accent,
    );

    // The button does NOT travel with the finger, deliberately.
    //
    // It used to, on the theory that a drag wants something to follow. On the
    // horizontal axis that was at least survivable — the button slid along the
    // row it already lives in. Lifted vertically it slides up out of the
    // composer and hangs over the transcript, and what a user reads is "I
    // dragged the button somewhere", not "I chose a mode": the movement is
    // louder than the icon swap that is the actual result. So the mode change
    // *is* the feedback — the glyph swaps, the detent buzzes, and the button
    // stays exactly where a thumb expects to find it for the hold that follows.

    Widget body = widget.style == ComposerCaptureStyle.classic
        ? Container(
            width: diameter,
            height: diameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.surfaceRaised,
              shape: BoxShape.circle,
              border: Border.all(
                color: mode == ComposerInputMode.camera ? theme.divider : theme.accent.withValues(alpha: 0.55),
              ),
            ),
            child: glyph,
          )
        : LiquidGlass(shape: LiquidGlassShape.circle, size: Size(diameter, diameter), child: glyph);

    // The gesture detector is INSIDE FocusableTap and carries the same onTap —
    // FocusableTap registers no recognizer of its own, so a wrapper without
    // this inner detector is a control that looks right and cannot be tapped.
    //
    // RawGestureDetector, not GestureDetector: a plain GestureDetector's long
    // press always uses Flutter's built-in half-second timeout with no way to
    // shorten it. This button starts recording someone's voice, and 500ms of
    // holding it before anything happens reads as unresponsive rather than
    // deliberate — see [kCaptureHoldDuration].
    body = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(() => TapGestureRecognizer(), (
          instance,
        ) {
          instance.onTap = _onTap;
        }),
        // Vertical, not horizontal: dragging up is what switches mode. The
        // horizontal axis belongs to slide-to-cancel during a hold, and the
        // button has no room to travel toward Send anyway — see [travelUpward].
        VerticalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
          (instance) {
            instance.onStart = (_) => _machine.beginModeDrag();
            instance.onUpdate = (d) {
              final before = _machine.mode;
              _machine.updateModeDrag(d.delta.dy);
              if (_machine.mode != before) _announceMode();
            };
            instance.onEnd = (_) {
              _machine.endModeDrag();
              _onModeChanged();
            };
            instance.onCancel = () {
              _machine.endModeDrag();
              _onModeChanged();
            };
          },
        ),
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: kCaptureHoldDuration),
          (instance) {
            instance.onLongPressStart = _onLongPressStart;
            instance.onLongPressMoveUpdate = _onLongPressMove;
            instance.onLongPressEnd = _onLongPressEnd;
            instance.onLongPressCancel = _onLongPressCancel;
          },
        ),
      },
      child: _modeMicroAnimation(body),
    );

    body = FocusableTap(
      onTap: _onTap,
      semanticLabel: l10n.composerCaptureModeButtonLabel(_modeLabel(mode)),
      shape: FocusRingShape.circle,
      child: body,
    );

    // The keyboard route to every mode. Bound outside FocusableTap so the
    // shortcut fires while the button's own node holds focus.
    body = CallbackShortcuts(
      bindings: {
        // Up/down rather than left/right, matching the drag axis — the
        // keyboard route should describe the same gesture, not a second one.
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _onArrow(1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _onArrow(-1),
      },
      child: body,
    );

    // The screen-reader route to every mode. A rotor action per mode, so a
    // VoiceOver user reaches the video note without ever performing a drag
    // they cannot see the target of.
    body = Semantics(
      customSemanticsActions: {
        for (final m in _machine.modes)
          if (m != mode)
            CustomSemanticsAction(label: _modeLabel(m)): () {
              _machine.selectMode(m);
              _onModeChanged();
              _announceMode();
            },
      },
      child: body,
    );

    final String tooltipHint = mode == ComposerInputMode.camera
        ? l10n.composerCaptureTapForCameraHint
        : l10n.composerCaptureHoldToRecordHint;

    body = Tooltip(
      message: tooltipHint,
      preferBelow: false,
      verticalOffset: 24,
      child: body,
    );

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    body = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          bottom: diameter + 10,
          right: isRtl ? null : 0,
          left: isRtl ? 0 : null,
          child: _ModeHintTooltipBubble(
            visible: _tooltipVisible && !_machine.isRecording,
            message: tooltipHint,
            theme: theme,
            isRtl: isRtl,
          ),
        ),
        body,
      ],
    );

    return body;
  }

  Widget _modeMicroAnimation(Widget child) {
    return AnimatedBuilder(
      animation: Listenable.merge([_modeBumpController, _entranceBumpController, _machine]),
      child: child,
      builder: (context, child) {
        final t = _modeBumpController.value;

        // --- 1. Multi-phase damped rubbery spring oscillation (Mode switch impact) ---
        final decay = math.exp(-t * 5.5);
        final oscillation = decay * math.sin(t * math.pi * 3.5);
        final initialImpulse = math.sin(math.pow(t, 0.6) * math.pi);

        final bumpScaleX = 1.0 + initialImpulse * 0.16 * (1.0 - t) + oscillation * 0.08;
        final bumpScaleY = 1.0 - initialImpulse * 0.14 * (1.0 - t) - oscillation * 0.08;

        final dir = _machine.lastStepDirection.toDouble();
        final bumpSkew = dir * oscillation * 0.045;

        // --- 1b. The same squash/stretch shape as the mode-switch bump above,
        // played once when the composer opens — sized up well past that one
        // (0.16/0.14/0.08) since this fires alone, with nothing else on
        // screen competing for attention, and is the user's one chance to
        // notice the control exists at all. ---
        final et = _entranceBumpController.value;
        final eDecay = math.exp(-et * 4.5);
        final eOscillation = eDecay * math.sin(et * math.pi * 3.0);
        final eImpulse = math.sin(math.pow(et, 0.6) * math.pi);

        final entranceScaleX = 1.0 + eImpulse * 0.46 * (1.0 - et * 0.4) + eOscillation * 0.20;
        final entranceScaleY = 1.0 - eImpulse * 0.40 * (1.0 - et * 0.4) - eOscillation * 0.20;

        // --- 2. Live Gesture Deformation (Drag, Lock, Cancel) ---
        final dragRatio = (_machine.modeDrag / kModeSwitchStep).clamp(-1.0, 1.0);
        final dragStretchY = 1.0 + dragRatio.abs() * 0.12;
        final dragStretchX = 1.0 - dragRatio.abs() * 0.06;
        final dragSkew = -dragRatio * 0.035;

        final cancelProgress = _machine.cancelProgress.clamp(0.0, 1.0);
        final cancelScaleX = 1.0 + cancelProgress * 0.14;
        final cancelScaleY = 1.0 - cancelProgress * 0.08;
        final cancelSkew = -cancelProgress * 0.04;

        final lockProgress = _machine.lockProgress.clamp(0.0, 1.0);
        final lockScaleY = 1.0 + lockProgress * 0.16;
        final lockScaleX = 1.0 - lockProgress * 0.08;

        // --- 3. Combined Scale & Matrix Transformation ---
        final totalScaleX = bumpScaleX * entranceScaleX * dragStretchX * cancelScaleX * lockScaleX;
        final totalScaleY = bumpScaleY * entranceScaleY * dragStretchY * cancelScaleY * lockScaleY;
        final totalSkew = bumpSkew + dragSkew + cancelSkew;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(0, 1, totalSkew)
            ..scale(totalScaleX, totalScaleY, 1.0),
          child: child,
        );
      },
    );
  }

  /// The mode glyph, cross-fading and sliding between icons instead of
  /// snapping — the instant swap read as broken rather than deliberate, which
  /// a control this is the *entire visible feedback* for cannot afford (see
  /// the note in [_modeButton] on why the button itself never moves).
  ///
  /// Directional, not a generic cross-fade: [ComposerCaptureMachine.mode]
  /// keys the `AnimatedSwitcher`, so a change is always a swap, but which way
  /// the new glyph slides in from — and the old one slides out toward —
  /// follows [ComposerCaptureMachine.lastStepDirection], so the animation
  /// reads as the wheel actually turning in the direction the finger (or the
  /// arrow key) just moved it, not as a generic dissolve.
  ///
  /// `animation.status` is what tells the incoming glyph from the outgoing
  /// one inside one shared `transitionBuilder`: `AnimatedSwitcher` drives the
  /// entering child's controller forward and the leaving child's in reverse,
  /// so a status of [AnimationStatus.reverse] is the exiting glyph and
  /// everything else is the entering one. The bounce (`easeOutBack`) is
  /// applied only to the slide, never to the fade — overshooting past 1.0 is
  /// fine for an `Offset`, but `FadeTransition.opacity` asserts if it ever
  /// sees a value outside 0..1.
  Widget _animatedGlyph({
    required ComposerInputMode mode,
    required IconData icon,
    required double size,
    required Color color,
  }) {
    final forward = _machine.lastStepDirection >= 0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 160),
      transitionBuilder: (child, animation) {
        final entering = animation.status != AnimationStatus.reverse;
        final startOffset = entering == forward ? const Offset(0, 0.45) : const Offset(0, -0.45);
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: entering ? Curves.easeOut : Curves.easeIn),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: startOffset,
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: entering ? Curves.easeOutBack : Curves.easeIn)),
            child: child,
          ),
        );
      },
      child: Icon(icon, key: ValueKey(mode), size: size, color: color),
    );
  }

  // ───────────────────────────── recording UI ─────────────────────────────

  Widget _recordingBody(BuildContext context) {
    final theme = ThemeScope.of(context);
    final showPreview = _machine.mode == ComposerInputMode.videoNote;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPreview) ...[
          Padding(
            padding: EdgeInsets.only(right: _previewTrailingGap(recording: true)),
            child: Align(alignment: Alignment.centerRight, child: _previewWithBadge(theme, idle: false)),
          ),
          const SizedBox(height: 12),
        ],
        _strip(theme),
      ],
    );
  }

  /// Horizontal gap between the preview's right edge and the composer's right
  /// edge, so the circle lines up with the mode button that owns it instead of
  /// sitting dead-centre over the whole composer row — a full-width text field
  /// away from the button that actually produces it, which is what made it
  /// read as a stray, possibly-broken shape rather than a viewfinder.
  ///
  /// The button's own position differs by state. In the idle row it sits one
  /// Send-button-and-gap in from the row's right edge, because Send is always
  /// the last control (see `chat_composer.dart`, where the mode button and
  /// Send are drawn at the same diameter in both styles). In the recording
  /// strip it — or the Send control it turns into once locked — IS the last
  /// control, flush against the strip's own inset. Either way this lines the
  /// preview's centre up with the button's centre, clamped at zero so a
  /// preview wider than that reach just hugs the edge instead of overshooting
  /// past it.
  double _previewTrailingGap({required bool recording}) {
    final diameter = _buttonDiameter;
    final stripInset = widget.style == ComposerCaptureStyle.classic ? 0.0 : 4.0;
    final rowGap = widget.style == ComposerCaptureStyle.classic ? 10.0 : 12.0;
    final buttonCenterFromRight = recording ? stripInset + diameter / 2 : diameter * 1.5 + rowGap;
    final previewRadius = (recording ? 168.0 : 108.0) / 2;
    return math.max(0.0, buttonCenterFromRight - previewRadius);
  }

  /// The preview circle, tagged with the same "PREVIEW" badge the theme
  /// screen uses for its own live preview — so a first-time video note reads
  /// as a deliberate viewfinder instead of something rendering by mistake.
  Widget _previewWithBadge(AppTheme theme, {required bool idle}) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        _preview(theme, idle: idle),
        Positioned(
          top: -8,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: theme.surfaceRaised.withValues(alpha: 0.92),
              shape: StadiumBorder(side: BorderSide(color: theme.divider, width: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                l10n.glassScreenPreviewBadge,
                style: theme.monoTiny.copyWith(color: theme.inkSoft, letterSpacing: 1.2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The circular live preview.
  ///
  /// Grows the composer upward rather than floating over the transcript: the
  /// classic composer is a `Column` child and the thread overlay's is inside a
  /// root `OverlayEntry`, and a `Positioned` escaping either would be clipped
  /// by something different in each. Both hosts already wrap the composer in an
  /// `AnimatedSize`, so the growth animates for free.
  Widget _preview(AppTheme theme, {bool idle = false}) {
    // Smaller when idle: it is a viewfinder the user has not committed to yet,
    // and a full-size circle sitting over the transcript while somebody types
    // would be the feature shouting rather than waiting.
    final size = idle ? 108.0 : 168.0;
    final controller = _video?.controller;
    final max = _maxDuration ?? kVideoNoteMaxDuration;
    final progress = idle || max.inMilliseconds == 0
        ? 0.0
        : (_elapsed.inMilliseconds / max.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: controller != null && controller.value.isInitialized
                // Cover, so the sensor's 4∶3 frame fills the circle instead of
                // being letterboxed inside it. This is the same crop the sent
                // bubble applies, so what the sender frames is what lands.
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller.value.previewSize?.height ?? size,
                      height: controller.value.previewSize?.width ?? size,
                      child: CameraPreview(controller),
                    ),
                  )
                : ColoredBox(color: theme.surfaceSunken),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                track: theme.ink.withValues(alpha: 0.15),
                ink: _elapsed >= max - kMaxDurationWarning ? theme.danger : theme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The bar that replaces the composer's row while recording.
  Widget _strip(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final locked = _machine.stage == CaptureStage.locked;
    final finishing = _machine.stage == CaptureStage.finishing;
    final max = _maxDuration;
    final remaining = max == null ? null : max - _elapsed;
    final counting = remaining != null && remaining <= kMaxDurationWarning;

    final hint = finishing
        ? l10n.composerCaptureSendingLabel
        : counting
        ? l10n.composerCaptureTimeLeft(math.max(0, remaining.inSeconds))
        : locked
        ? l10n.composerCaptureTapToSendHint
        : _machine.wouldCancel
        ? l10n.composerCaptureReleaseToCancelHint
        : l10n.composerCaptureSlideToCancelHint;

    final row = Row(
      children: [
        _stripTrashButton(
          theme,
          label: l10n.composerCaptureCancelLabel,
          cancelProgress: _machine.cancelProgress,
          wouldCancel: _machine.wouldCancel,
          onTap: finishing ? null : () => unawaited(_abort()),
        ),
        const SizedBox(width: 12),
        _RecordingPulse(color: theme.danger),
        const SizedBox(width: 10),
        Text(
          formatClockDuration(_elapsed),
          style: theme.body.copyWith(color: theme.ink, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _machine.stage == CaptureStage.holding && !finishing
              ? _SlidingCancelHint(
                  hint: hint,
                  cancelProgress: _machine.cancelProgress,
                  wouldCancel: _machine.wouldCancel,
                  counting: counting,
                  theme: theme,
                )
              : Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.monoTiny.copyWith(color: _machine.wouldCancel || counting ? theme.danger : theme.inkMuted),
                ),
        ),
        const SizedBox(width: 12),
        if (locked || finishing)
          _stripButton(
            theme,
            icon: Icons.north_east,
            label: l10n.composerCaptureSendLabel,
            tint: theme.accent,
            filled: true,
            onTap: finishing ? null : () => unawaited(_finish()),
          )
        else
          // The button the finger is still on, reparented here rather than
          // rebuilt — see [_modeButtonKey]. The lock affordance stacks directly
          // above it in the lane the finger travels up.
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: _buttonDiameter + 8,
                child: _LockAffordance(
                  progress: _machine.lockProgress,
                  theme: theme,
                  label: l10n.composerCaptureLockLabel,
                ),
              ),
              _keyedModeButton(context),
            ],
          ),
      ],
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.composerCaptureRecordingLabel(formatClockDuration(_elapsed)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.style == ComposerCaptureStyle.classic ? 0 : 4, vertical: 2),
        child: row,
      ),
    );
  }

  Widget _stripTrashButton(
    AppTheme theme, {
    required String label,
    required double cancelProgress,
    required bool wouldCancel,
    required VoidCallback? onTap,
  }) {
    final diameter = _buttonDiameter;
    final color = wouldCancel ? theme.danger : theme.danger.withValues(alpha: 0.85);

    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: wouldCancel ? theme.danger.withValues(alpha: 0.15) : theme.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(
              color: wouldCancel ? theme.danger : theme.danger.withValues(alpha: 0.5),
              width: wouldCancel ? 1.5 : 1.0,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.001,
                child: Icon(Icons.delete_outline, size: 18, color: color),
              ),
              IgnorePointer(
                child: _AnimatedTrashCan(
                  cancelProgress: cancelProgress,
                  wouldCancel: wouldCancel,
                  color: color,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stripButton(
    AppTheme theme, {
    required IconData icon,
    required String label,
    required Color tint,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final diameter = _buttonDiameter;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? tint : theme.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(color: filled ? tint : tint.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, size: 18, color: filled ? theme.accentInk : tint),
        ),
      ),
    );
  }
}

/// The dot that says "live". A separate widget so its ticker rebuilds one
/// 10pt circle rather than the whole strip, which is redrawn from a 100 ms
/// timer already.
class _RecordingPulse extends StatefulWidget {
  const _RecordingPulse({required this.color});
  final Color color;

  @override
  State<_RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<_RecordingPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// The chevron-and-padlock that fills as the finger travels up, positioned
/// directly above the recording button.
class _LockAffordance extends StatelessWidget {
  const _LockAffordance({required this.progress, required this.theme, required this.label});

  final double progress;
  final AppTheme theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    // Rubbery spring upward motion as finger travels up toward lock
    final dy = -math.sin(t * math.pi / 2.0) * 14.0;
    final scale = 1.0 + t * 0.14;
    final isLocked = t >= 1.0;

    return Semantics(
      label: label,
      value: '${(t * 100).round()}%',
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: isLocked ? quietFill(theme) : theme.surfaceRaised.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Color.lerp(theme.divider, theme.accent, t)!,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: (1.0 - t * 0.7).clamp(0.2, 1.0),
                  child: Icon(Icons.keyboard_arrow_up, size: 14, color: Color.lerp(theme.inkMuted, theme.accent, t)),
                ),
                const SizedBox(height: 2),
                Icon(
                  isLocked ? Icons.lock : Icons.lock_outline,
                  size: 16,
                  color: Color.lerp(theme.inkMuted, theme.accent, t),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An animated garbage/trash icon that opens its mouth/lid as [cancelProgress] increases
/// or when [wouldCancel] is active.
class _AnimatedTrashCan extends StatelessWidget {
  const _AnimatedTrashCan({
    required this.cancelProgress,
    required this.wouldCancel,
    required this.color,
    this.size = 20.0,
  });

  final double cancelProgress;
  final bool wouldCancel;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = cancelProgress.clamp(0.0, 1.0);
    final openFactor = wouldCancel ? 1.0 : t;
    // Rotate lid open counter-clockwise up to ~45 degrees (math.pi / 4)
    final lidAngle = -openFactor * (math.pi / 4.0);
    final lidLift = openFactor * 2.5;
    final scale = 1.0 + openFactor * 0.15;

    return Transform.scale(
      scale: scale,
      child: CustomPaint(
        size: Size(size, size),
        painter: _TrashCanPainter(
          color: color,
          lidAngle: lidAngle,
          lidLift: lidLift,
          openFactor: openFactor,
        ),
      ),
    );
  }
}

class _TrashCanPainter extends CustomPainter {
  const _TrashCanPainter({
    required this.color,
    required this.lidAngle,
    required this.lidLift,
    required this.openFactor,
  });

  final Color color;
  final double lidAngle;
  final double lidLift;
  final double openFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final binTopY = h * 0.38;
    final binBottomY = h * 0.88;
    final binLeftX = w * 0.26;
    final binRightX = w * 0.74;
    final binBottomLeftX = w * 0.32;
    final binBottomRightX = w * 0.68;

    final binPath = Path()
      ..moveTo(binLeftX, binTopY)
      ..lineTo(binBottomLeftX, binBottomY)
      ..arcToPoint(Offset(binBottomRightX, binBottomY), radius: const Radius.circular(2.0))
      ..lineTo(binRightX, binTopY);

    canvas.drawPath(binPath, paint);

    if (w >= 18) {
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;

      final midYTop = binTopY + 2.5;
      final midYBottom = binBottomY - 2.0;
      canvas.drawLine(Offset(w * 0.42, midYTop), Offset(w * 0.44, midYBottom), linePaint);
      canvas.drawLine(Offset(w * 0.58, midYTop), Offset(w * 0.56, midYBottom), linePaint);
    }

    final pivotX = w * 0.74;
    final pivotY = binTopY;

    canvas.save();
    canvas.translate(0, -lidLift);
    canvas.translate(pivotX, pivotY);
    canvas.rotate(lidAngle);
    canvas.translate(-pivotX, -pivotY);

    final lidLeftX = w * 0.18;
    final lidRightX = w * 0.82;
    final lidY = binTopY - 1.0;

    canvas.drawLine(Offset(lidLeftX, lidY), Offset(lidRightX, lidY), paint);

    final handleLeftX = w * 0.40;
    final handleRightX = w * 0.60;
    final handleTopY = lidY - 3.0;

    final handlePath = Path()
      ..moveTo(handleLeftX, lidY)
      ..lineTo(handleLeftX, handleTopY)
      ..lineTo(handleRightX, handleTopY)
      ..lineTo(handleRightX, lidY);

    canvas.drawPath(handlePath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrashCanPainter old) =>
      old.color != color ||
      old.lidAngle != lidAngle ||
      old.lidLift != lidLift ||
      old.openFactor != openFactor;
}

/// Animated sliding cancel hint cue with chevrons.
class _SlidingCancelHint extends StatefulWidget {
  const _SlidingCancelHint({
    required this.hint,
    required this.cancelProgress,
    required this.wouldCancel,
    required this.counting,
    required this.theme,
  });

  final String hint;
  final double cancelProgress;
  final bool wouldCancel;
  final bool counting;
  final AppTheme theme;

  @override
  State<_SlidingCancelHint> createState() => _SlidingCancelHintState();
}

class _SlidingCancelHintState extends State<_SlidingCancelHint> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final color = widget.wouldCancel || widget.counting ? theme.danger : theme.inkMuted;

    final rubberDx = -math.pow(widget.cancelProgress.clamp(0.0, 1.0), 0.8) * 36.0;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final slideDx = -((1.0 - _anim.value) * 6.0);

        return Transform.translate(
          offset: Offset(rubberDx, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(slideDx, 0),
                child: Icon(Icons.chevron_left, size: 16, color: color),
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  widget.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.monoTiny.copyWith(color: color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The progress ring around the video-note preview.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.track, required this.ink});

  final double progress;
  final Color track;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Offset.zero & size;
    final circle = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(circle, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = ink;
    // From twelve o'clock, clockwise — the direction every recording timer in
    // every app on the phone already runs.
    canvas.drawArc(circle, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.ink != ink || old.track != track;
}

/// Says what went wrong, with a route out of it.
///
/// Shared by both hosts rather than written twice: a permission dead end is
/// exactly the kind of thing that gets a Settings button in one place and a
/// bare snackbar in the other, and the two hosts differ only in which surface
/// they show messages on — not in what a refused microphone means.
Future<void> showCaptureProblem(
  BuildContext context,
  CaptureFailure failure, {

  /// How to show a plain message. A `Scaffold` host passes its `SnackBar`;
  /// the thread overlay passes its toast.
  required void Function(String message) onMessage,
}) async {
  final l10n = AppLocalizations.of(context);
  switch (failure.kind) {
    case CaptureFailureKind.permission:
      final camera = failure.device == CaptureDevice.camera;
      if (failure.grant == CaptureGrant.restricted) {
        // Nothing in Settings to turn on — a managed device or Screen Time.
        // Offering the button anyway would send them to a page with no switch.
        onMessage(l10n.composerCaptureRestrictedBody);
        return;
      }
      final go = await showConfirmSheet(
        context,
        headline: camera ? l10n.composerCaptureCameraPermissionTitle : l10n.composerCaptureMicPermissionTitle,
        body: camera ? l10n.composerCaptureCameraPermissionBody : l10n.composerCaptureMicPermissionBody,
        confirmLabel: l10n.composerCaptureOpenSettingsLabel,
      );
      if (!go) return;
      await CapturePermissions.openSettings();
    case CaptureFailureKind.unavailable:
      onMessage(l10n.composerCaptureUnavailableSnack);
    case CaptureFailureKind.interrupted:
      onMessage(l10n.composerCaptureInterruptedSnack);
    case CaptureFailureKind.storage:
      onMessage(l10n.composerCaptureStorageSnack);
    case CaptureFailureKind.tooShort:
      break; // a mis-tap is not an error
    case CaptureFailureKind.unknown:
      onMessage(l10n.composerCaptureUnavailableSnack);
  }
}

/// Animated floating pop-up bubble shown directly above the mode button
/// on mode change or tap, displaying the localized gesture hint.
class _ModeHintTooltipBubble extends StatelessWidget {
  const _ModeHintTooltipBubble({
    required this.visible,
    required this.message,
    required this.theme,
    this.isRtl = false,
  });

  final bool visible;
  final String message;
  final AppTheme theme;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        opacity: visible ? 1.0 : 0.0,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 260),
          curve: visible ? Curves.easeOutBack : Curves.easeIn,
          scale: visible ? 1.0 : 0.8,
          alignment: isRtl ? Alignment.bottomLeft : Alignment.bottomRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: ShapeDecoration(
                color: theme.surfaceRaised.withValues(alpha: 0.96),
                shape: const StadiumBorder(),
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.monoTiny.copyWith(
                  color: theme.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
