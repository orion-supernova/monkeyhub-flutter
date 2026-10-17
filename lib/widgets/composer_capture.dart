import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, listEquals, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../composer/capture_machine.dart';
import '../composer/capture_permissions.dart';
import '../composer/capture_compose.dart';
import '../composer/capture_recorder.dart';
import '../composer/recording_haptics.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../screens/room_items.dart' show formatClockDuration;
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'capture_bloom.dart';
import 'capture_glyphs.dart';
import 'capture_review.dart';
import 'destructive_sheet.dart';
import 'glass_buttons.dart';
import 'glass_reveal.dart' show GlassStill;
import 'liquid_glass.dart';
import 'send_flight.dart';

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

  /// The voice's loudness, 0..1, while a voice note records: what the bloom
  /// behind the button breathes with. Raw, every 120 ms; the bloom smooths
  /// it. Stays 0 for a video note, which has no meter.
  final _level = ValueNotifier<double>(0);
  StreamSubscription<double>? _levelSub;
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

  /// A tap (or the attachment sheet) asked for a video note: the big preview
  /// is up with its record button, and nothing is recording yet.
  ///
  /// A tap used to start a hands-free recording on the spot, and people were
  /// caught mid-sentence by it ("aah, it started"). A voice note is still
  /// tap-to-record — there is nothing to frame — but a video note is a picture
  /// of you, and you get to see it before it goes.
  bool _staged = false;

  /// The big centred circle, drawn over the chat while a video note is staged
  /// or recording. Always shown; it draws nothing the rest of the time.
  final _bigPreview = OverlayPortalController();

  /// The composer itself, measured so the big preview's dim stops at its top
  /// edge and the strip under it stays lit and tappable.
  final _composerKey = GlobalKey();

  /// The small preview's place over the composer: where the big circle lifts
  /// from and lands back on. Kept, empty, while the circle is flying home.
  final _slotKey = GlobalKey();

  /// [_slotKey]'s last rect in the overlay. The slot is gone from the layout
  /// once the circle is up, and the lift still has to know where it left.
  Rect? _slotRect;

  /// 0 the small preview over the composer, 1 the big circle over the chat.
  /// One circle travelling between the two, never two swapped: the picture
  /// you were already looking at is the one that grows.
  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 300),
  )..addStatusListener((status) {
      // Landed: the inline preview takes the picture back from the overlay.
      if (status != AnimationStatus.dismissed || !mounted) return;
      // Put away (its X, or a note just sent): the camera goes once the
      // circle has.
      if (_idlePreviewHidden) unawaited(_releasePreview());
      setState(() {});
    });

  /// A thrown-away recording being swept into the trash: the strip stays up
  /// for this, the dot and the frozen clock fly into the bin, and the lid
  /// shuts on them. The composer's row comes back when it ends.
  late final AnimationController _discard = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });

  /// The hold was accepted and the recorder is still opening: the bloom is
  /// already up (it answers the finger, not the microphone) and the strip
  /// shows 0:00,00 until bytes flow.
  bool _arming = false;

  /// A finger is on the record button (a hold, before or after it locked).
  bool _fingerDown = false;

  /// The small preview was put away with its X. Still on video notes; a tap
  /// brings it back.
  bool _idlePreviewHidden = false;

  /// This recording goes as play-once. Per recording: each one starts off.
  bool _viewOnce = false;

  /// The parts of a paused recording so far. Pause finishes a segment file;
  /// resume starts the next; send joins them (see `composeCapture`). Empty
  /// for a recording that was never paused, which keeps the old fast path.
  final _segments = <CaptureSegment>[];

  /// Paused: the strip is the review (see [_review]) and nothing records.
  bool _paused = false;

  /// The paused recording's review: playback and the trim window.
  CaptureReviewController? _review;

  /// Flips so far, for the flip glyph's half turn per tap.
  int _flips = 0;

  /// The front camera's "flash": the screen behind the circle goes white.
  bool _screenFlashOn = false;
  bool get _screenFlash => _screenFlashOn;

  /// Every change goes through here so the screen's brightness follows: full
  /// while the white flash is up, the user's own the moment it is not.
  set _screenFlash(bool on) {
    if (on == _screenFlashOn) return;
    _screenFlashOn = on;
    unawaited(setFlashBrightness(on));
  }

  /// How the bloom leaves when this recording ends.
  CaptureBloomExit _bloomExit = CaptureBloomExit.send;

  /// Where the bloom sits: the mode button's centre in the overlay, kept
  /// from the last frame it was laid out.
  Offset? _bloomAnchor;

  /// The clock as it read when the recording was thrown away, for the sweep.
  Duration _discardedAt = Duration.zero;

  /// The lid shutting is felt, once per sweep.
  bool _gulped = false;

  /// A sent video note's circle on its way down into its bubble (see
  /// `send_flight.dart`). Open from the hand-over until it lands; while it is,
  /// the lift holds at 1 so the camera and the circle stay up.
  SendFlightTicket? _flight;

  /// Gives up on a landing that never shows (the list was far up in history,
  /// the room went away): the circle shrinks where it is, as before.
  Timer? _flightWait;

  /// 0 the big circle where it recorded, 1 on the bubble. A tick under half
  /// a second: long enough to follow, short enough that the chat is yours.
  late final AnimationController _flightAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  )
    ..addListener(() {
      // The bubble fades in under the last stretch as the circle fades out
      // over it: one picture handing over to the other, never two.
      _flight?.reveal.value = ((_flightAnim.value - 0.7) / 0.3).clamp(0.0, 1.0);
    })
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        HapticFeedback.lightImpact();
        _endFlight();
      }
    });

  /// Decelerates into both ends, as a received note's focus does.
  late final CurvedAnimation _liftCurve = CurvedAnimation(
    parent: _lift,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

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

    _bigPreview.show();
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
  /// mode. Voice switches *and* starts: nobody taps "voice message" in a sheet
  /// to be shown a button they then have to hold. A video note stops at the
  /// staged preview instead — see [_staged].
  void _onExternalRequest() {
    final mode = widget.capture?.controller?.takePending();
    if (mode == null || !mounted || _machine.isRecording) return;
    if (!_machine.modes.contains(mode)) return;
    _machine.selectMode(mode);
    _onModeChanged();
    switch (mode) {
      case ComposerInputMode.camera:
        widget.capture?.onCamera?.call();
      case ComposerInputMode.voice:
        unawaited(_startRecording(locked: true));
      case ComposerInputMode.videoNote:
        _stage();
    }
  }

  void _stage() {
    if (widget.capture == null || _machine.isRecording) return;
    HapticFeedback.selectionClick();
    _rememberSlot();
    setState(() => _staged = true);
    unawaited(_warmPreview());
  }

  void _unstage() {
    if (!_staged) return;
    setState(() {
      _staged = false;
      _screenFlash = false;
    });
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
    _liftCurve.dispose();
    _lift.dispose();
    _flightWait?.cancel();
    _flight?.close();
    _flightAnim.dispose();
    _discard.dispose();
    _screenFlash = false;
    unawaited(_levelSub?.cancel());
    _level.dispose();
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
      // Not while the small preview is put away: it stays away, camera off.
      if (_machine.mode == ComposerInputMode.videoNote && !_idlePreviewHidden) {
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
    if (!mounted || widget.capture?.recorderFactory != null) return;
    // A recorder whose session was released (the preview put away, the app
    // backgrounded, a cancelled take) opens a fresh one; returning early here
    // left a dead circle.
    final existing = _video;
    if (existing != null) {
      if (existing.controller != null) return;
      try {
        await existing.warm();
      } catch (e) {
        debugPrint('capture re-warm failed: $e');
      }
      if (mounted) setState(() {});
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
    // Arriving on video notes always shows the small preview again.
    _idlePreviewHidden = false;
    _modeBumpController.forward(from: 0.0);
    _triggerTooltip();
    if (_machine.mode != ComposerInputMode.videoNote) _unstage();

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
    _rememberSlot();
    // The bloom answers the finger now; the recorder catches up. Felt now
    // too: before the microphone opens, iOS plays it unconditionally.
    setState(() {
      _arming = true;
      _bloomExit = CaptureBloomExit.send;
      _viewOnce = false;
    });
    HapticFeedback.mediumImpact();
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
      // Before the start haptic below, which iOS would otherwise swallow now
      // that the microphone is live.
      await allowHapticsWhileRecording();
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
      _staged = false;
      _machine.markRecording();
      if (locked) _machine.updateHold(const Offset(0, -kLockDragThreshold), TextDirection.ltr);
      _announce(
        locked
            ? AppLocalizations.of(context).composerCaptureLockedAnnouncement
            : AppLocalizations.of(context).composerCaptureRecordingAnnouncement,
      );
      _startTicker();
      _levelSub = recorder.levels?.listen((v) => _level.value = v);
    } finally {
      _busy = false;
      if (_arming && mounted) {
        // Started (the machine has it now) or failed (the bloom collapses).
        if (!_machine.isRecording) _bloomExit = CaptureBloomExit.discard;
        setState(() => _arming = false);
      }
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
    unawaited(_levelSub?.cancel());
    _levelSub = null;
    _level.value = 0;
  }

  /// Stop, read the bytes, hand them to the host.
  Future<void> _finish() async {
    final capture = widget.capture;
    final recorder = _recorder;
    if (capture == null || recorder == null || _busy) return;
    _busy = true;
    HapticFeedback.mediumImpact();
    _bloomExit = CaptureBloomExit.send;
    final mode = _machine.mode;
    _machine.markFinishing();
    _stopTicker();
    try {
      final review = _review;
      final outcome = _segments.isEmpty && !(review?.trimmed ?? false)
          ? await _stopSafely(recorder)
          : await _composeSafely(recorder, video: mode == ComposerInputMode.videoNote);
      if (outcome.duration < kMinRecordingDuration) {
        // Can only happen on the locked path, where there is no release to
        // check the floor at. Silent: a note this short was a mis-tap.
        _machine.markIdle();
        return;
      }
      // Opened before the hand-over, so the bubble the host builds for it,
      // a frame or two from now, is the one that claims the circle.
      if (mode == ComposerInputMode.videoNote && mounted && !MotionScope.of(context).calm && _lift.value > 0) {
        _beginFlight();
      }
      capture.onCaptured(mode, outcome.withViewOnce(_viewOnce));
      // Sent: the viewfinder does not come back on its own. Flying the circle
      // back into a live preview read as still recording; it shrinks away
      // instead and the camera goes. A tap on the button brings it back.
      if (mode == ComposerInputMode.videoNote && mounted) {
        setState(() => _idlePreviewHidden = true);
      }
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
      _endReview();
      _screenFlash = false;
      if (!identical(recorder, _video)) unawaited(recorder.dispose());
      if (mounted) setState(() => _elapsed = Duration.zero);
    }
  }

  /// Joins the segments (and the one still recording, if any), trims to the
  /// review's window, and hands back the finished note. On failure the parts
  /// are thrown away: a send that cannot be built must not leave files.
  Future<CaptureOutcome> _composeSafely(CaptureRecorder recorder, {required bool video}) async {
    final review = _review;
    if (!_paused) _segments.add(await recorder.stopSegment());
    final parts = List.of(_segments);
    _segments.clear();
    try {
      return await composeCapture(
        segments: parts,
        video: video,
        trimStart: review != null && review.trimmed ? review.trimStart : null,
        trimEnd: review != null && review.trimmed ? review.trimEnd : null,
      );
    } catch (e) {
      unawaited(discardSegments(parts));
      if (e is CaptureFailure) rethrow;
      debugPrint('capture compose failed: $e');
      throw const CaptureFailure(CaptureFailureKind.unavailable);
    }
  }

  /// Pause and resume. Pausing finishes the current part and turns the
  /// strip into its review; resuming drops the review (and any trim) and
  /// records the next part, the clock carrying on from where it stopped.
  Future<void> _togglePause() async {
    final recorder = _recorder;
    if (recorder == null || _busy || !_machine.isRecording) return;
    _busy = true;
    final video = _machine.mode == ComposerInputMode.videoNote;
    HapticFeedback.mediumImpact();
    try {
      if (!_paused) {
        final part = await recorder.stopSegment();
        _segments.add(part);
        _stopTicker();
        final review = CaptureReviewController(segments: List.of(_segments), video: video);
        if (!mounted) return;
        setState(() {
          _paused = true;
          _review = review;
          _elapsed = totalDuration(_segments);
        });
        unawaited(review.load());
      } else {
        _endReview();
        await recorder.start();
        await allowHapticsWhileRecording();
        if (!mounted) return;
        setState(() {
          _paused = false;
          _startedAt = DateTime.now().subtract(totalDuration(_segments));
        });
        _startTicker();
        _levelSub = recorder.levels?.listen((v) => _level.value = v);
      }
    } on CaptureFailure catch (f) {
      if (mounted) widget.capture?.onProblem(f);
    } catch (e) {
      debugPrint('capture pause/resume failed: $e');
    } finally {
      _busy = false;
    }
  }

  void _endReview() {
    final review = _review;
    _review = null;
    _paused = false;
    review?.dispose();
  }

  Future<void> _flipCamera() async {
    final video = _video;
    if (video == null || !video.canFlip) return;
    HapticFeedback.selectionClick();
    setState(() => _flips++);
    try {
      await video.flip();
    } on CaptureFailure catch (f) {
      if (mounted) widget.capture?.onProblem(f);
    }
    // The white screen is the front camera's flash; the back one has a torch.
    if (mounted) setState(() => _screenFlash = _screenFlash && video.frontFacing);
  }

  Future<void> _toggleFlash() async {
    final video = _video;
    if (video == null) return;
    HapticFeedback.selectionClick();
    if (video.frontFacing) {
      setState(() => _screenFlash = !_screenFlash);
    } else if (video.hasTorch) {
      await video.setTorch(!video.torchOn);
      if (mounted) setState(() {});
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
    final startedAt = _startedAt;
    final wasPaused = _paused;
    _bloomExit = CaptureBloomExit.discard;
    if (_segments.isNotEmpty) {
      unawaited(discardSegments(List.of(_segments)));
      _segments.clear();
    }
    _endReview();
    _screenFlash = false;
    // Thrown away from the strip the user is looking at: sweep it into the
    // bin rather than snapping the row back.
    // `startedAt`, not the machine: a release that cancels has already put the
    // machine back to idle by the time this runs.
    if (!silent && mounted && (startedAt != null || wasPaused) && !MotionScope.of(context).calm) {
      _discardedAt = startedAt != null ? DateTime.now().difference(startedAt) : _elapsed;
      _gulped = false;
      _discard.forward(from: 0);
    }
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
        // The session a cancelled recording ran on is released, not reused:
        // the recorder object survives and warms a fresh one below.
        try {
          await recorder.release();
        } catch (e) {
          debugPrint('capture release after cancel failed: $e');
        }
        // A fresh session straight back, while the button is still on video
        // notes and the app is in front: without it the idle preview stays
        // gone until the next recording. The session the cancelled recording
        // ran on is never reused.
        if (mounted &&
            identical(_video, recorder) &&
            _machine.mode == ComposerInputMode.videoNote &&
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
          try {
            await recorder.warm();
          } catch (e) {
            debugPrint('capture re-warm after cancel failed: $e');
          }
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
        // A tap starts a *locked* recording. This is the whole accessible
        // story for the hold gesture: a hold cannot be performed by a keyboard
        // and is not discoverable by a screen reader, so the same control has
        // to work as a plain button — and hands-free is the only sensible
        // reading of a button press that starts a recording nobody is holding.
        unawaited(_startRecording(locked: true));
      case ComposerInputMode.videoNote:
        // The same accessible story, one step later: a tap stages the big
        // preview, and its record button (a plain button again) starts the
        // hands-free recording. A second tap on this button puts it away.
        // With the small preview put away, the first tap only brings it
        // back; the next one opens the big preview from it.
        if (_staged) {
          _unstage();
        } else if (_idlePreviewHidden) {
          HapticFeedback.selectionClick();
          setState(() => _idlePreviewHidden = false);
          unawaited(_warmPreview());
        } else {
          _stage();
        }
    }
  }

  void _onLongPressStart(LongPressStartDetails d) {
    if (_machine.mode == ComposerInputMode.camera) return;
    _holdOrigin = d.localPosition;
    setState(() => _fingerDown = true);
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
    if (_fingerDown) setState(() => _fingerDown = false);
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
    if (_fingerDown) setState(() => _fingerDown = false);
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
    final motion = MotionScope.of(context);
    _lift
      ..duration = motion.d(const Duration(milliseconds: 360))
      ..reverseDuration = motion.d(const Duration(milliseconds: 300));
    return ListenableBuilder(
      listenable: _machine,
      builder: (context, _) {
        // After layout: the slot's rect is only true once this frame has
        // placed it, and the lift starts from the frame that hid it.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _rememberSlot();
          _syncLift();
          _rememberBloomAnchor();
        });
        return OverlayPortal(
          controller: _bigPreview,
          overlayChildBuilder: (context) => Positioned.fill(
            child: Stack(
              children: [
                _bigPreviewLayer(context),
                _bloomLayer(context),
              ],
            ),
          ),
          child: KeyedSubtree(key: _composerKey, child: _body(context)),
        );
      },
    );
  }

  /// Whether the circle belongs big over the chat: staged, or recording.
  bool get _wantsBig =>
      _machine.mode == ComposerInputMode.videoNote &&
      (_staged || _machine.isRecording || _machine.stage == CaptureStage.finishing);

  void _syncLift() {
    final flight = _flight;
    if (flight != null) {
      // The circle is flying to its bubble; it lands on its own. A new
      // recording before it has lands it at once.
      if (!_wantsBig) return;
      _flightAnim.stop();
      _endFlight();
    }
    if (_wantsBig) {
      if (_lift.status != AnimationStatus.forward && _lift.value < 1) _lift.forward();
    } else if (_lift.status != AnimationStatus.reverse && _lift.value > 0) {
      _lift.reverse();
    }
  }

  void _beginFlight() {
    _flightWait?.cancel();
    final ticket = _flight = SendFlight.open();
    _flightAnim.value = 0;
    ticket.addListener(_onFlightClaimed);
    _flightWait = Timer(const Duration(milliseconds: 450), () {
      if (identical(_flight, ticket) && !ticket.claimed) _endFlight();
    });
  }

  void _onFlightClaimed() {
    final ticket = _flight;
    if (ticket == null || !ticket.claimed || ticket.closed || _flightAnim.isAnimating) return;
    _flightWait?.cancel();
    // From the frame after the bubble's first layout, so there is a rect to
    // aim at; re-aimed every frame after that, as the list settles.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_flight, ticket) || ticket.closed) return;
      _flightAnim
        ..duration = MotionScope.of(context).d(const Duration(milliseconds: 480))
        ..forward(from: 0);
    });
  }

  /// Landed (the bubble is fully shown) or given up (it shrinks in place).
  void _endFlight() {
    final ticket = _flight;
    if (ticket == null) return;
    _flightWait?.cancel();
    _flightWait = null;
    ticket.removeListener(_onFlightClaimed);
    final landed = _flightAnim.value > 0;
    ticket.close();
    _flight = null;
    if (!mounted) return;
    if (landed) {
      // Already on the bubble: no flight home. Snapping the lift down takes
      // the camera away, as a finished lift does.
      _flightAnim.value = 0;
      _lift.value = 0;
    } else {
      _syncLift();
    }
    setState(() {});
  }

  /// The arc down into the bubble: across first, then down, so it swoops in
  /// rather than sliding along a ruler.
  static Rect _flightRect(Rect from, Rect to, double f) {
    final across = Curves.easeOutCubic.transform(f);
    final down = Curves.easeInOutCubic.transform(f);
    final size = Curves.easeInOutCubic.transform(f);
    final center = Offset(
      from.center.dx + (to.center.dx - from.center.dx) * across,
      from.center.dy + (to.center.dy - from.center.dy) * down,
    );
    final w = from.width + (to.width - from.width) * size;
    final h = from.height + (to.height - from.height) * size;
    return Rect.fromCenter(center: center, width: w, height: h);
  }

  /// The small preview's rect in the overlay, or null while it is not laid
  /// out.
  Rect? _slotNow() {
    final slot = _slotKey.currentContext?.findRenderObject();
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (slot is! RenderBox || !slot.attached || !slot.hasSize) return null;
    if (overlay is! RenderBox || !overlay.hasSize) return null;
    return overlay.globalToLocal(slot.localToGlobal(Offset.zero)) & slot.size;
  }

  void _rememberSlot() => _slotRect = _slotNow() ?? _slotRect;

  /// The mode button's centre in the overlay, read after layout (mid-build
  /// the button may be waiting for its own), and a rebuild only when it has
  /// actually moved: the keyboard, a rotation, the strip replacing the row.
  void _rememberBloomAnchor() {
    final overlayBox = Overlay.maybeOf(context)?.context.findRenderObject();
    final button = _modeButtonKey.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox || button is! RenderBox || !button.attached || !button.hasSize) return;
    final at = overlayBox.globalToLocal(button.localToGlobal(button.size.center(Offset.zero)));
    final was = _bloomAnchor;
    if (was != null && (was - at).distance < 0.5) return;
    setState(() => _bloomAnchor = at);
  }

  Widget _body(BuildContext context) {
    if (_arming || _machine.isRecording || _machine.stage == CaptureStage.finishing || _discard.isAnimating) {
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
    if (_machine.mode != ComposerInputMode.videoNote || _video?.controller == null || _wantsBig || _idlePreviewHidden) {
      return row;
    }
    // Still flying home: the slot holds its place, empty, for the circle
    // drawn over the chat to land in.
    final landing = _lift.value > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(right: _previewTrailingGap()),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox.square(
              key: _slotKey,
              dimension: _idlePreviewSize,
              child: landing ? null : _previewWithBadge(ThemeScope.of(context)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        row,
      ],
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


        // --- 1b. The same squash/stretch shape as the mode-switch bump above,
        // played once when the composer opens — sized up well past that one
        // (0.16/0.14/0.08) since this fires alone, with nothing else on
        // screen competing for attention, and is the user's one chance to
        // notice the control exists at all. ---
        final et = _entranceBumpController.value;
        final eDecay = math.exp(-et * 4.5);
        final eOscillation = eDecay * math.sin(et * math.pi * 3.0);
        final eImpulse = math.sin(math.pow(et, 0.6) * math.pi);

        // Calmer than it was (0.46/0.40/0.20): the jelly read as cheap next
        // to the bloom it now leads into.
        final entranceScaleX = 1.0 + eImpulse * 0.18 * (1.0 - et * 0.4) + eOscillation * 0.08;
        final entranceScaleY = 1.0 - eImpulse * 0.15 * (1.0 - et * 0.4) - eOscillation * 0.08;

        // --- 2. Live Gesture Deformation (Drag, Lock, Cancel) ---
        final dragRatio = (_machine.modeDrag / kModeSwitchStep).clamp(-1.0, 1.0);
        final dragStretchY = 1.0 + dragRatio.abs() * 0.12;
        final dragStretchX = 1.0 - dragRatio.abs() * 0.06;
        final dragSkew = -dragRatio * 0.035;

        // No squash for lock or cancel: while recording the bloom disc covers
        // the button, and it is the disc that answers the finger.

        // --- 3. Combined Scale & Matrix Transformation ---
        final totalScaleX = bumpScaleX * entranceScaleX * dragStretchX;
        final totalScaleY = bumpScaleY * entranceScaleY * dragStretchY;
        // Skew only follows a mode drag the finger is making; a bump never
        // leans, it read as wobble.
        final totalSkew = dragSkew;

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

  /// Just the strip: a video note's picture is in the big preview over the
  /// chat (see [_bigPreviewLayer]), not squeezed into the composer.
  Widget _recordingBody(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (!_arming && !_machine.isRecording && _machine.stage != CaptureStage.finishing && _discard.isAnimating) {
      return AnimatedBuilder(animation: _discard, builder: (context, _) => _discardStrip(theme));
    }
    return _strip(theme);
  }

  /// The strip while a thrown-away recording is swept into the bin. The lid
  /// is already open (the slide or the tap opened it); the dot and the clock
  /// fall in, the lid shuts on them with a small overshoot, the bin squashes,
  /// and the row comes back. The mode button stays exactly where it was: it
  /// is the same button the row will hand back.
  Widget _discardStrip(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final d = _discard.value;
    final sweep = Curves.easeInCubic.transform((d / 0.5).clamp(0.0, 1.0));
    // The glyph's own one-shot: the lid slams, bounces, the can squashes.
    final gulp = ((d - 0.48) / 0.4).clamp(0.0, 1.0);
    if (d >= 0.55 && !_gulped) {
      _gulped = true;
      HapticFeedback.lightImpact();
    }
    final fade = 1 - ((d - 0.85) / 0.15).clamp(0.0, 1.0);
    final clockStyle = theme.body.copyWith(color: theme.ink, fontFeatures: const [FontFeature.tabularFigures()]);
    final hundredths = (_discardedAt.inMilliseconds ~/ 10) % 100;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.style == ComposerCaptureStyle.classic ? 0 : 4, vertical: 2),
      child: Row(
        children: [
          Opacity(
            opacity: fade,
            child: _stripTrashButton(
              theme,
              label: l10n.composerCaptureCancelLabel,
              cancelProgress: 1,
              wouldCancel: false,
              gulp: gulp,
              onTap: null,
            ),
          ),
          const SizedBox(width: 12),
          // Falls toward the bin's mouth: left, shrinking, gone by the time
          // the lid shuts.
          Opacity(
            opacity: (1 - sweep).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(-sweep * (_buttonDiameter * 0.5 + 22), -math.sin(math.pi * sweep) * 10),
              child: Transform.scale(
                scale: 1 - sweep * 0.75,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: theme.danger, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${formatClockDuration(_discardedAt)}${recordingDecimalSeparator(Localizations.localeOf(context))}'
                      '${hundredths.toString().padLeft(2, '0')}',
                      style: clockStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          _keyedModeButton(context),
        ],
      ),
    );
  }

  /// Horizontal gap between the preview's right edge and the composer's right
  /// edge, so the circle lines up with the mode button that owns it instead of
  /// sitting dead-centre over the whole composer row — a full-width text field
  /// away from the button that actually produces it, which is what made it
  /// read as a stray, possibly-broken shape rather than a viewfinder.
  ///
  /// In the idle row the button sits one Send-button-and-gap in from the
  /// row's right edge, because Send is always the last control (see
  /// `chat_composer.dart`, where the mode button and Send are drawn at the
  /// same diameter in both styles). This lines the preview's centre up with
  /// the button's centre, clamped at zero so a preview wider than that reach
  /// just hugs the edge instead of overshooting past it.
  double _previewTrailingGap() {
    final diameter = _buttonDiameter;
    final rowGap = widget.style == ComposerCaptureStyle.classic ? 10.0 : 12.0;
    final buttonCenterFromRight = diameter * 1.5 + rowGap;
    return math.max(0.0, buttonCenterFromRight - _idlePreviewSize / 2);
  }

  static const _idlePreviewSize = 108.0;

  /// The preview circle, tagged with the same "PREVIEW" badge the theme
  /// screen uses for its own live preview — so a first-time video note reads
  /// as a deliberate viewfinder instead of something rendering by mistake.
  Widget _previewWithBadge(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // A tap lifts it into the big preview: the same circle, flying up.
        Semantics(
          button: true,
          label: l10n.composerCaptureVideoNoteModeLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _stage,
            child: SizedBox.square(dimension: _idlePreviewSize, child: _cameraFace(theme)),
          ),
        ),
        // Closes the preview: back to the composer's first mode, which lets
        // the camera go. Top left, where every close in the app sits, on the
        // rim just below the "Preview" badge's line so the two never touch
        // (the badge is centred on the top edge).
        Positioned(
          top: 12,
          left: 0,
          child: ChromeDisc(
            size: 26,
            still: true,
            onTap: _closeIdlePreview,
            child: Semantics(
              label: l10n.photoChromeCloseSemanticLabel,
              button: true,
              child: Icon(Icons.close_rounded, size: 15, color: theme.ink),
            ),
          ),
        ),
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

  /// The small preview's X: off video notes, back to the composer's first
  /// mode. [_onModeChanged] drops the camera with it.
  void _closeIdlePreview() {
    HapticFeedback.selectionClick();
    // Stays on video notes (switching mode under the user was confusing);
    // only the viewfinder goes, and the camera with it. A tap on the button
    // brings it back, and holding still records.
    setState(() => _idlePreviewHidden = true);
    unawaited(_releasePreview());
  }

  /// The live camera, cropped to a circle. Sized by its parent: the small
  /// idle viewfinder over the composer, or the big one over the chat.
  Widget _cameraFace(AppTheme theme) {
    final controller = _video?.controller;
    return ClipOval(
      child: controller != null && controller.value.isInitialized
          // Cover, so the sensor's 4∶3 frame fills the circle instead of
          // being letterboxed inside it. This is the same crop the sent
          // bubble applies, so what the sender frames is what lands.
          ? FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.previewSize?.height ?? 1,
                height: controller.value.previewSize?.width ?? 1,
                child: CameraPreview(controller),
              ),
            )
          : ColoredBox(color: theme.surfaceSunken),
    );
  }

  void _toggleViewOnce() {
    HapticFeedback.selectionClick();
    setState(() => _viewOnce = !_viewOnce);
  }

  /// The bloom over the mode button: the disc, its halo and the lock pill
  /// (see [CaptureBloom]). Always mounted while capture is wired, painting
  /// nothing at rest, so its springs carry straight through a recording's
  /// end into the exit.
  Widget _bloomLayer(BuildContext context) {
    final mode = _machine.mode;
    if (mode == ComposerInputMode.camera && !_machine.isRecording) return const SizedBox.shrink();
    final anchor = _bloomAnchor;
    if (anchor == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final active = _arming || _machine.isRecording;
    return Positioned(
      left: anchor.dx - CaptureBloom.center.dx,
      top: anchor.dy - CaptureBloom.center.dy,
      width: CaptureBloom.boxSize.width,
      height: CaptureBloom.boxSize.height,
      child: Material(
        type: MaterialType.transparency,
        child: CaptureBloom(
          theme: ThemeScope.of(context),
          active: active,
          locked: _machine.stage == CaptureStage.locked,
          holding: _fingerDown,
          lockProgress: _machine.lockProgress,
          cancelProgress: _machine.cancelProgress,
          video: mode == ComposerInputMode.videoNote,
          level: mode == ComposerInputMode.voice ? _level : null,
          exit: _bloomExit,
          onSend: _machine.stage == CaptureStage.locked ? () => unawaited(_finish()) : null,
          sendLabel: l10n.composerCaptureSendLabel,
          lockLabel: l10n.composerCaptureLockLabel,
          viewOnce: _viewOnce,
          onToggleViewOnce: _machine.stage == CaptureStage.locked ? _toggleViewOnce : null,
          viewOnceLabel: l10n.composerCaptureViewOnceLabel,
          viewOnceHint: mode == ComposerInputMode.videoNote
              ? l10n.composerCaptureViewOnceVideoHint
              : l10n.composerCaptureViewOnceVoiceHint,
          pauseLabel: l10n.composerCapturePauseLabel,
          resumeLabel: l10n.composerCaptureResumeLabel,
          paused: _paused,
          onPause: _machine.stage == CaptureStage.locked && captureComposeSupported ? () => unawaited(_togglePause()) : null,
        ),
      ),
    );
  }

  /// The big circle over the chat while a video note is staged or recording —
  /// the same size and place a received note plays at, so what you frame is
  /// what they will see.
  ///
  /// It is the small preview, lifted: the circle flies from its place over
  /// the composer to the middle of the chat, and back down when it is put
  /// away or the recording ends. With no small preview to leave from (no
  /// camera yet, or another mode) it grows and fades in place.
  ///
  /// A dim over the chat, stopping short of the composer so the strip's
  /// controls stay lit and live; it fades out over the band just above the
  /// composer, which is where the hold's slide-up-to-lock affordance travels.
  /// The dim is a plain colour, never a blur — see `VideoNoteFocus`.
  Widget _bigPreviewLayer(BuildContext context) => Positioned.fill(
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: Listenable.merge([_liftCurve, _flightAnim]),
            builder: (context, _) => _bigPreviewFrame(context),
          ),
        ),
      );

  Widget _bigPreviewFrame(BuildContext context) {
    final t = _liftCurve.value;
    final up = _wantsBig;
    final flight = _flight;
    if (t == 0 && !up && flight == null) return const SizedBox.shrink();
    final recording = _machine.isRecording || _machine.stage == CaptureStage.finishing;
    final overlayBox = Overlay.of(context).context.findRenderObject();
    final composerBox = _composerKey.currentContext?.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize || composerBox is! RenderBox || !composerBox.hasSize) {
      return const SizedBox.shrink();
    }
    final composerTop = math.max(0.0, overlayBox.globalToLocal(composerBox.localToGlobal(Offset.zero)).dy);
    final width = overlayBox.size.width;
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final pad = MediaQuery.paddingOf(context);
    const fadeBand = 140.0;
    const controlsHeight = 64.0;
    const controlsGap = 24.0;
    final staged = _staged && !recording;

    // Staged leaves room under the circle for its controls; recording does
    // not. The circle eases between the two instead of jumping on Record.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: staged ? controlsGap + controlsHeight : 0.0),
      duration: MotionScope.of(context).d(const Duration(milliseconds: 280)),
      curve: Curves.easeOutCubic,
      builder: (context, reserve, _) {
        final usable = composerTop - pad.top - fadeBand / 2;
        final diameter = math.max(0.0, math.min(math.min(width - 24, usable - reserve - 24), 460.0));
        final top = pad.top + math.max(0.0, (usable - diameter - reserve) / 2);
        final target = Rect.fromLTWH((width - diameter) / 2, top, diameter, diameter);

        // From the slot while it is on screen (flying home), else from where
        // it last was (the slot left the layout as the circle went up).
        // A put-away preview has no slot to land in: the circle shrinks and
        // fades where it is instead of flying back to a live viewfinder.
        final source = _machine.mode == ComposerInputMode.videoNote && _video?.controller != null && !_idlePreviewHidden
            ? _slotNow() ?? _slotRect
            : null;
        final circle = source == null
            ? Rect.fromCenter(
                center: target.center,
                width: diameter * (0.7 + 0.3 * t),
                height: diameter * (0.7 + 0.3 * t),
              )
            : Rect.lerp(source, target, t)!;
        // Sent: from where it recorded down onto its bubble, re-aimed every
        // frame (the bubble rises out of the composer and the list settles
        // under it). Waiting for the bubble, it holds where it is.
        final f = _flightAnim.value;
        final landing = flight?.rectIn(overlayBox);
        final flying = flight != null;
        final shown = flying && landing != null && f > 0 ? _flightRect(target, landing, f) : circle;
        final dim = flying ? t * (1 - Curves.easeOutCubic.transform(f)) : t;
        final controlsOpacity = ((t - 0.5) / 0.5).clamp(0.0, 1.0);

        final video = _video;
        final showCameraControls =
            !flying && video != null && video.controller != null && !_paused && _machine.mode == ComposerInputMode.videoNote;
        return IgnorePointer(
          // Flying home: nothing here is a target any more.
          ignoring: !up,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: composerTop,
                child: Opacity(
                  opacity: dim,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Staged, a tap outside puts the preview away. Recording,
                    // a stray tap on the chat must not do anything at all.
                    onTap: staged ? _unstage : null,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xB8000000), Color(0xB8000000), Color(0x00000000)],
                          stops: [0, 0.72, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // The front camera's flash: the screen itself, white and solid,
              // over the dim and everything above the strip, lighting the face
              // the way Telegram's does; a soft white glow rings the circle
              // so its edge does not cut a dark line through the light.
              if (_screenFlash) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: composerTop,
                  child: IgnorePointer(
                    child: Opacity(opacity: t.clamp(0.0, 1.0), child: const ColoredBox(color: Color(0xFFFFFFFF))),
                  ),
                ),
                Positioned.fromRect(
                  rect: circle.inflate(28),
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0xFFFFF4E0), blurRadius: 40, spreadRadius: 6)],
                      ),
                    ),
                  ),
                ),
              ],
              Positioned.fromRect(
                rect: shown,
                child: Opacity(
                  opacity: flying ? 1 - (flight.reveal.value) : (source == null ? t : 1),
                  // In flight it is neither a preview nor recording: no
                  // badge, no ring, only the picture.
                  child: _bigCircle(theme, l10n, recording: recording || flying, lift: t),
                ),
              ),
              // Flip and flash, above the strip's leading end, as Telegram's.
              if (showCameraControls)
                Positioned(
                  left: 16,
                  top: composerTop - 12 - 36,
                  child: Opacity(
                    opacity: controlsOpacity,
                    child: Row(
                      children: [
                        if (video.canFlip)
                          ChromeDisc(
                            size: 36,
                            still: true,
                            onTap: () => unawaited(_flipCamera()),
                            child: Semantics(
                              label: l10n.cameraScreenSwitchCameraLabel,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(end: _flips.toDouble()),
                                duration: MotionScope.of(context).d(const Duration(milliseconds: 360)),
                                curve: Curves.easeInOutCubic,
                                builder: (context, spin, _) => FlipCameraGlyph(color: theme.ink, spin: spin, size: 22),
                              ),
                            ),
                          ),
                        if (video.frontFacing || video.hasTorch) ...[
                          const SizedBox(width: 10),
                          ChromeDisc(
                            size: 36,
                            still: true,
                            tint: (video.frontFacing ? _screenFlash : video.torchOn) ? const Color(0xFFFFD60A) : null,
                            onTap: () => unawaited(_toggleFlash()),
                            child: Semantics(
                              label: l10n.composerCaptureFlashLabel,
                              toggled: video.frontFacing ? _screenFlash : video.torchOn,
                              child: Icon(
                                (video.frontFacing ? _screenFlash : video.torchOn) ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                size: 18,
                                color: (video.frontFacing ? _screenFlash : video.torchOn) ? Colors.black : theme.ink,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              // A real close for the preview: 44pt, top left, where every
              // camera on the phone keeps it. The small one that sat beside
              // Record was easy to miss and easy to hit by accident.
              if (staged)
                Positioned(
                  left: 16,
                  top: pad.top + 8,
                  child: Opacity(
                    opacity: controlsOpacity,
                    child: ChromeDisc(
                      size: 44,
                      still: true,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _unstage();
                      },
                      child: Semantics(
                        label: l10n.photoChromeCloseSemanticLabel,
                        button: true,
                        child: Icon(Icons.close_rounded, size: 22, color: theme.ink),
                      ),
                    ),
                  ),
                ),
              if (staged)
                Positioned(
                  top: top + diameter + controlsGap,
                  left: 0,
                  right: 0,
                  height: controlsHeight,
                  child: Opacity(
                    opacity: controlsOpacity,
                    child: GlassStill(still: true, child: _stagedControls(theme, l10n)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// [lift] is the flight: at 0 the circle is still the small preview, so
  /// its ring is not drawn yet and its badge sits as the small one does.
  Widget _bigCircle(AppTheme theme, AppLocalizations l10n, {required bool recording, double lift = 1}) {
    final max = _maxDuration ?? kVideoNoteMaxDuration;
    final startedAt = _startedAt;
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        _cameraFace(theme),
        // Paused, the circle plays the recording back over the live camera.
        if (_review != null)
          ListenableBuilder(
            listenable: _review!,
            builder: (context, _) {
              final player = _review?.videoPlayer;
              if (player == null || !player.value.isInitialized) return const SizedBox.shrink();
              return ClipOval(
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: player.value.size.width,
                    height: player.value.size.height,
                    child: VideoPlayer(player),
                  ),
                ),
              );
            },
          ),
        IgnorePointer(
          child: Opacity(
            opacity: lift,
            child: recording && startedAt != null
                // Telegram's: a thin white arc on the edge, no track. A track
                // read as a border drawn round the picture.
                ? _LiveRing(
                    startedAt: startedAt,
                    max: max,
                    track: const Color(0x00FFFFFF),
                    ink: Colors.white.withValues(alpha: 0.92),
                    warn: theme.danger,
                  )
                : const SizedBox.shrink(),
          ),
        ),
        Positioned(
          top: -8 - 6 * lift,
          left: 0,
          right: 0,
          child: Center(
            // Recording, the strip's clock is the one clock; the circle only
            // says "preview" while it is one.
            child: recording ? const SizedBox.shrink() : _previewBadge(theme, l10n, lift: lift),
          ),
        ),
      ],
    );
  }

  /// What the big circle says while it is only a viewfinder.
  Widget _previewBadge(AppTheme theme, AppLocalizations l10n, {double lift = 1}) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.surfaceRaised.withValues(alpha: 0.92),
        shape: StadiumBorder(side: BorderSide(color: theme.divider, width: 0.5)),
      ),
      child: Padding(
        // The small preview's badge at 0, so the lift carries it without a
        // jump in size.
        padding: EdgeInsets.symmetric(horizontal: 8 + 2 * lift, vertical: 3 + lift),
        child: Text(
          l10n.glassScreenPreviewBadge,
          style: theme.monoTiny.copyWith(color: theme.inkSoft, letterSpacing: 1.2),
        ),
      ),
    );
  }

  /// Under the staged preview: put it away, or record.
  Widget _stagedControls(AppTheme theme, AppLocalizations l10n) {
    // Record alone, dead centre; closing is the X in the corner.
    return Center(
      child: _RecordButton(
        label: l10n.composerCaptureStartRecordingLabel,
        color: theme.danger,
        onTap: _busy ? null : () => unawaited(_startRecording(locked: true)),
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

    final cancel = _machine.cancelProgress.clamp(0.0, 1.0);
    // The bin is only there while a slide is heading for it: it grows in over
    // the first stretch of the slide and its lid opens over the rest.
    final binIn = locked || finishing ? 0.0 : ((cancel - 0.1) / 0.3).clamp(0.0, 1.0);
    final textStyle = theme.body.copyWith(fontSize: 16, fontWeight: FontWeight.w400);
    final clockStyle = textStyle.copyWith(color: theme.ink, fontFeatures: const [FontFeature.tabularFigures()]);

    final Widget middle;
    if (locked && !counting) {
      // Locked, the disc is the send button; this is the way out.
      middle = _CancelTextButton(
        label: l10n.composerCaptureLockedCancel,
        style: textStyle.copyWith(fontSize: 17, color: theme.accent),
        onTap: () => unawaited(_abort()),
      );
    } else if (_machine.stage == CaptureStage.holding && !finishing && !counting) {
      middle = _SlidingCancelHint(
        hint: sentenceCaseOf(context, hint),
        cancelProgress: cancel,
        style: textStyle.copyWith(color: theme.inkSoft),
        chevronColor: theme.inkSoft,
      );
    } else {
      middle = Text(
        sentenceCaseOf(context, hint),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: textStyle.copyWith(color: counting ? theme.danger : theme.inkMuted),
      );
    }

    final review = _review;
    final row = _paused && review != null
        // Paused: the recording itself, to play and trim. The bin throws it
        // all away; the disc beside it still sends.
        ? Row(
            children: [
              _stripTrashButton(
                theme,
                label: l10n.composerCaptureCancelLabel,
                cancelProgress: 0,
                wouldCancel: false,
                onTap: finishing ? null : () => unawaited(_abort()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SlideIn(
                  dx: 16,
                  duration: const Duration(milliseconds: 220),
                  child: CaptureReviewStrip(
                    controller: review,
                    theme: theme,
                    playLabel: l10n.composerCaptureReviewPlayLabel,
                    pauseLabel: l10n.composerCaptureReviewStopLabel,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Opacity(opacity: 0, child: _keyedModeButton(context)),
            ],
          )
        : Row(
      children: [
        SizedBox.square(
          dimension: _buttonDiameter,
          child: binIn <= 0
              ? null
              : Opacity(
                  opacity: binIn,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * binIn + (_machine.wouldCancel ? 0.08 : 0),
                    child: _stripTrashButton(
                      theme,
                      label: l10n.composerCaptureCancelLabel,
                      cancelProgress: ((cancel - 0.4) / 0.6).clamp(0.0, 1.0),
                      wouldCancel: _machine.wouldCancel,
                      onTap: null,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        _RecordingPulse(color: theme.danger),
        const SizedBox(width: 10),
        _SlideIn(
          dx: 22,
          duration: const Duration(milliseconds: 220),
          // Until the recorder is live (the bloom fires on the gesture) the
          // clock sits at zero, as Telegram's does.
          child: _startedAt == null
              ? Text('0:00${recordingDecimalSeparator(Localizations.localeOf(context))}00', style: clockStyle)
              : _RecordingClock(startedAt: _startedAt!, style: clockStyle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SlideIn(
            dx: 32,
            delay: const Duration(milliseconds: 40),
            duration: const Duration(milliseconds: 300),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(locked && !counting), child: middle),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // The button the finger is still on, reparented here rather than
        // rebuilt (see [_modeButtonKey]), and hidden: the bloom disc sits on
        // it and is what the user sees and, once locked, taps. Its gestures
        // still own the hold.
        Opacity(opacity: 0, child: _keyedModeButton(context)),
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
    double gulp = 0,
  }) {
    final diameter = _buttonDiameter;
    final color = theme.danger;

    // Chrome, never a red fill: the bin's open lid is the warning, and a
    // colour flood on top of it read as an error state, not a gesture.
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
          decoration: BoxDecoration(color: chromeDiscFill(theme), shape: BoxShape.circle),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.001,
                child: Icon(Icons.delete_outline, size: 18, color: color),
              ),
              IgnorePointer(
                child: TrashGlyph(
                  open: wouldCancel ? 1 : cancelProgress.clamp(0.0, 1.0),
                  gulp: gulp,
                  color: color,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dot that says "live", on Telegram's rhythm: a 1 s cycle that holds
/// on for 450 ms, fades out over 200, stays off 150 and fades back over 200.
/// A blink, not a breathing fade, which is what reads as a camera's tally
/// light. A separate widget so its ticker rebuilds one 10pt circle.
class _RecordingPulse extends StatefulWidget {
  const _RecordingPulse({required this.color});
  final Color color;

  @override
  State<_RecordingPulse> createState() => _RecordingPulseState();
}

class _RecordingPulseState extends State<_RecordingPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _blink(double t) {
    final ms = t * 1000;
    if (ms < 450) return 1;
    if (ms < 650) return 1 - (ms - 450) / 200;
    if (ms < 800) return 0;
    return (ms - 800) / 200;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(opacity: _blink(_c.value), child: child),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Slides its child in from [dx] to the right and fades it in, once, when it
/// first appears: the strip's clock and hint arriving as the bloom lands.
class _SlideIn extends StatelessWidget {
  const _SlideIn({required this.dx, required this.duration, required this.child, this.delay = Duration.zero});

  final double dx;
  final Duration duration;
  final Duration delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    final total = duration + delay;
    final lead = total.inMicroseconds == 0 ? 0.0 : delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.d(total),
      builder: (context, v, child) {
        final t = Curves.easeOutCubic.transform(lead >= 1 ? 1 : ((v - lead) / (1 - lead)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(dx * (1 - t), 0), child: child),
        );
      },
      child: child,
    );
  }
}

/// The locked strip's way out: a plain accent "Cancel", as Telegram's. A
/// bare GestureDetector plus [FocusableTap]; pressed, it dims.
class _CancelTextButton extends StatefulWidget {
  const _CancelTextButton({required this.label, required this.style, required this.onTap});

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  State<_CancelTextButton> createState() => _CancelTextButtonState();
}

class _CancelTextButtonState extends State<_CancelTextButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        // Height factor 1: a bare Center in the strip's row would take every
        // pixel of height it is offered and blow the strip up to the screen.
        child: Center(
          heightFactor: 1,
          child: AnimatedOpacity(
            opacity: _down ? 0.5 : 1,
            duration: const Duration(milliseconds: 90),
            child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: widget.style),
          ),
        ),
      ),
    );
  }
}

/// "‹ Slide to cancel". The chevron alone nudges toward the bin while the
/// finger has not moved (a 1.4 s nudge, then a rest); once it moves, the
/// hint follows at 0.6 of its travel and fades out well before the line, as
/// Telegram's does: by then the bin and its open lid are the message.
class _SlidingCancelHint extends StatefulWidget {
  const _SlidingCancelHint({
    required this.hint,
    required this.cancelProgress,
    required this.style,
    required this.chevronColor,
  });

  final String hint;
  final double cancelProgress;
  final TextStyle style;
  final Color chevronColor;

  @override
  State<_SlidingCancelHint> createState() => _SlidingCancelHintState();
}

class _SlidingCancelHintState extends State<_SlidingCancelHint> with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_SlidingCancelHint old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// The nudge only while the finger is still: a loop that keeps going under
  /// a moving finger fights it.
  void _sync() {
    final idle = widget.cancelProgress < 0.05 && !MediaQuery.disableAnimationsOf(context);
    if (idle && !_nudge.isAnimating) {
      _nudge.repeat();
    } else if (!idle && _nudge.isAnimating) {
      _nudge
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cancelProgress;
    final away = c * kCancelDragThreshold;
    final fadeT = ((c - 0.15) / 0.3).clamp(0.0, 1.0);
    final opacity = 1 - fadeT * fadeT * (3 - 2 * fadeT);
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(-0.6 * away, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _nudge,
              builder: (context, child) {
                // 1.4 s out and back, then 400 ms of rest.
                final t = (_nudge.value * 1800 / 1400).clamp(0.0, 1.0);
                final dx = -4 * math.sin(math.pi * t);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: ChevronGlyph(direction: AxisDirection.left, size: 14, color: widget.chevronColor),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: widget.style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The progress ring around the video-note preview.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.track, required this.ink, this.stroke = 3});

  final double progress;
  final Color track;
  final Color ink;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
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
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ink != ink || old.track != track || old.stroke != stroke;
}

/// The recording ring on the big circle, advanced every frame from the start
/// time rather than from the strip's 100ms timer: on a circle this size a
/// 100ms step is a visible jump. Its own ticker, so the frames repaint one
/// ring and nothing else.
class _LiveRing extends StatefulWidget {
  const _LiveRing({
    required this.startedAt,
    required this.max,
    required this.track,
    required this.ink,
    required this.warn,
  });

  final DateTime startedAt;
  final Duration max;
  final Color track;
  final Color ink;

  /// The ring's colour in the last [kMaxDurationWarning] — the strip's
  /// countdown, said in the circle too.
  final Color warn;

  @override
  State<_LiveRing> createState() => _LiveRingState();
}

class _LiveRingState extends State<_LiveRing> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}))..start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final max = widget.max;
    final progress = max.inMilliseconds == 0 ? 0.0 : (elapsed.inMilliseconds / max.inMilliseconds).clamp(0.0, 1.0);
    return CustomPaint(
      painter: _RingPainter(
        progress: progress,
        track: widget.track,
        ink: elapsed >= max - kMaxDurationWarning ? widget.warn : widget.ink,
        stroke: 3,
      ),
    );
  }
}

/// The strip's clock, to the hundredth: "0:03,86". Hundredths are what make
/// a recording look alive the instant it starts, where whole seconds sit on
/// "0:00" for the first second and read as nothing happening. Its own ticker,
/// like [_LiveRing], so a frame repaints one line of text.
class _RecordingClock extends StatefulWidget {
  const _RecordingClock({required this.startedAt, required this.style});

  final DateTime startedAt;
  final TextStyle style;

  @override
  State<_RecordingClock> createState() => _RecordingClockState();
}

class _RecordingClockState extends State<_RecordingClock> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}))..start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final hundredths = (elapsed.inMilliseconds ~/ 10) % 100;
    return Text(
      '${formatClockDuration(elapsed)}${recordingDecimalSeparator(Localizations.localeOf(context))}'
      '${hundredths.toString().padLeft(2, '0')}',
      style: widget.style,
    );
  }
}

/// The decimal mark the recording clock uses for [locale]: a comma where the
/// language writes one ("0:03,86"), a point elsewhere. Our languages only;
/// Arabic keeps Latin digits in this clock, so a Latin comma.
@visibleForTesting
String recordingDecimalSeparator(Locale locale) => switch (locale.languageCode) {
  'en' || 'ja' || 'ko' || 'zh' || 'hi' => '.',
  _ => ',',
};

/// The shutter-style record button under a staged video note: a red disc in
/// a white ring, the button every camera app uses for "start". A bare
/// GestureDetector plus [FocusableTap], like every other control here.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
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
