import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/preview_luminance.dart';
import '../theme/theme_scope.dart';
import '../widgets/photo_chrome.dart';

/// In-app camera. Shutter → the photo, immediately.
///
/// This used to be a 44-line shim around `ImagePicker.pickImage(source:
/// camera)`, which presents `UIImagePickerController`. That bought a small file
/// at two costs that turned out to be the whole problem:
///
///  * **A confirmation nobody asked for.** iOS's camera insists on its own
///    Retake / Use Photo step, and there is no flag to skip it. Both callers
///    then push a *second* review surface — the circle cropper for avatars, the
///    editor for chat — so the user confirmed the same photograph twice.
///  * **Selfies came out reversed.** Correcting that needs to know which lens
///    fired, and `image_picker` never says: it opens on the rear lens and the
///    user can flip inside a UI we don't control.
///
/// Owning the preview fixes both. It also means owning the failure modes, so
/// [CameraUnavailable] exists: if the hardware or the plugin will not start,
/// the caller falls back to the system camera rather than dead-ending.
///
/// The photo is reviewed *over* this route, not after it — see [review].
///
/// Pops a [CameraResult], or null if the user backed out.
class CameraScreen<T> extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.review,
    this.initialLens = CameraLensDirection.back,
  });

  /// Which lens to open on. Avatars open front — you are photographing
  /// yourself; chat opens back.
  final CameraLensDirection initialLens;

  /// Shows the caller's review surface for a fresh capture, and says what to do
  /// with the result. Chat reviews in the editor, avatars in the circle cropper.
  ///
  /// Called while the camera is still mounted, and expected to push on top of
  /// it. The shutter used to pop this route and let the caller push the review
  /// afterwards, which is two route animations overlapping: the camera slid
  /// away revealing the chat, and the editor presented itself over that. What
  /// looked like a bug was the chat showing through the seam. Reviewing on top
  /// of a route that is still there removes the seam, and makes
  /// [ReviewRetake] free — there is no camera to reopen, it never left.
  final CameraReviewer<T> review;

  static Future<CameraResult<T>?> open<T>(
    BuildContext context, {
    required CameraReviewer<T> review,
    CameraLensDirection initialLens = CameraLensDirection.back,
  }) {
    return Navigator.of(context).push<CameraResult<T>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CameraScreen<T>(
          review: review,
          initialLens: initialLens,
        ),
      ),
    );
  }

  /// Starts the camera-list lookup without opening anything.
  ///
  /// `availableCameras()` is a platform round-trip whose answer cannot change
  /// during a session. Calling this when a camera button first appears on
  /// screen takes it off the critical path of the tap that follows.
  static void warmUp() {
    if (kIsWeb) return; // Enumerating devices in a browser prompts for access.
    unawaited(_CameraScreenState._availableCameras());
  }

  @override
  State<CameraScreen<T>> createState() => _CameraScreenState<T>();
}

/// Reviews a capture on top of the camera. See [CameraScreen.review].
typedef CameraReviewer<T> = Future<ReviewDecision<T>> Function(
  BuildContext context,
  CameraPhoto photo,
);

/// What the review surface decided about a capture.
sealed class ReviewDecision<T> {
  const ReviewDecision();
}

/// Done with this photo. The camera closes and [value] becomes the result of
/// [CameraScreen.open] — null when the user threw the picture away, which ends
/// the flow just as surely as keeping it does.
class ReviewDone<T> extends ReviewDecision<T> {
  const ReviewDone(this.value);
  final T? value;
}

/// Throw this one away and shoot again.
///
/// Costs a controller restart rather than a route: the camera is still on the
/// stack under the review surface, so RETAKE is that surface popping.
class ReviewRetake<T> extends ReviewDecision<T> {
  const ReviewRetake();
}

/// How the camera screen finished.
sealed class CameraResult<T> {
  const CameraResult();
}

/// The user reviewed a photograph and left. [value] is whatever their review
/// surface produced, or null if they discarded it.
class CameraReviewed<T> extends CameraResult<T> {
  const CameraReviewed(this.value);
  final T? value;
}

/// A photograph, on its way to [CameraScreen.review]. Never a [CameraResult] —
/// a raw capture no longer leaves this screen, it is reviewed on top of it.
class CameraPhoto {
  const CameraPhoto({required this.bytes, required this.mirrored});

  final Uint8List bytes;

  /// Whether these bytes still need mirroring to match the preview the user was
  /// looking at when they pressed the shutter.
  ///
  /// Carried rather than applied here on purpose. Mirroring costs a full
  /// decode-rasterize-re-encode, and both screens downstream already rasterize
  /// once — so the flip rides along with work that was happening anyway instead
  /// of stalling the shutter. See `CameraEditorScreen` and `ImageCropScreen`.
  final bool mirrored;
}

/// The user asked for the photo library instead. The caller owns the picker.
class CameraPickLibrary<T> extends CameraResult<T> {
  const CameraPickLibrary();
}

/// The camera could not be started, for a reason that is not the user saying
/// no. Callers should fall back to `ImagePicker(source: camera)`.
class CameraUnavailable<T> extends CameraResult<T> {
  const CameraUnavailable();
}

class _CameraScreenState<T> extends State<CameraScreen<T>>
    with WidgetsBindingObserver {
  /// Front-lens *captures* come back un-mirrored on every platform: iOS gives
  /// `AVCapturePhotoOutput` an auto-formed connection that `isVideoMirrored`
  /// never touches, CameraX's `ImageCapture` defaults to `MIRROR_MODE_OFF`, and
  /// `camera_web` mirrors the `<video>` element's CSS but not the grabbed frame.
  ///
  /// The **preview** is the opposite — every platform mirrors it for you, at
  /// its own layer (iOS on the video-data connection, web in CSS, Android in
  /// the preview delegate or the surface producer depending on the rendering
  /// backend). That asymmetry is the whole bug, and it is why there is no
  /// `Transform` around [CameraPreview] below: an app-side flip cancels the
  /// platform's and hands the user a preview that is backwards.
  static const _captureNeedsMirroring = true;

  /// Whether flash, focus and zoom can be driven at all.
  ///
  /// `camera_web` implements none of them, and signals that with a bare
  /// `UnimplementedError` — not the `CameraException` every catch on this
  /// screen is written for. An unguarded `setFlashMode` would therefore escape
  /// and the camera would never open in a browser at all. The controls are
  /// simply absent there rather than present and inert.
  static const _lensControls = !kIsWeb;

  /// Memoized because the answer cannot change while the app is running, and
  /// the round-trip is otherwise paid on every single open.
  static Future<List<CameraDescription>>? _camerasOnce;

  static Future<List<CameraDescription>> _availableCameras() {
    return _camerasOnce ??= availableCameras().catchError((Object _) {
      // Don't cache a failure: a denied permission can be granted in Settings
      // and the next open should find the cameras.
      _camerasOnce = null;
      return <CameraDescription>[];
    });
  }

  List<CameraDescription> _cameras = const [];
  CameraController? _controller;

  CameraLensDirection _lens = CameraLensDirection.back;
  FlashMode _flash = FlashMode.off;

  _Fault? _fault;
  bool _capturing = false;

  /// The capture being reviewed on top of this route, or null when the camera
  /// is the thing on screen.
  ///
  /// Doubles as the backdrop while it is set: this screen paints the photo
  /// instead of a preview it has already let go of. Nothing of it is visible
  /// under the review surface — it is for the frame either side. Going in,
  /// releasing the session would otherwise flash black behind a route that has
  /// not painted yet; coming out, the route dismisses carrying the picture the
  /// user was just looking at rather than the black of a dead camera.
  CameraPhoto? _reviewing;

  /// Where the last tap-to-focus landed, in this widget's local coordinates.
  /// Null once the reticle has faded out.
  Offset? _focusPoint;
  int _focusToken = 0;

  /// Whether *this* lens can drive a real flash.
  ///
  /// Probed rather than assumed. The plugin gates every flash mode on
  /// `captureDevice.hasFlash` (`DefaultCamera.swift:1089`), and whether that is
  /// true for a selfie camera is a per-device question — an iPhone with Retina
  /// Flash may accept it, most Android front cameras will not. Asking the
  /// device beats hardcoding a guess that is wrong on half the hardware.
  bool _nativeFlash = false;

  /// True while the screen is being used as the flash. See [_usesScreenFlash].
  bool _screenFlash = false;

  /// Whether the metered preview is dark enough that auto should fire.
  bool _previewIsDark = false;
  bool _metering = false;
  DateTime? _lastMeterAt;

  /// Exposure-compensation range this lens actually supports, in EV.
  double _minEv = 0;
  double _maxEv = 0;
  bool _boost = false;

  /// How far to push exposure when the boost is on. Deliberately modest: the
  /// range a device reports often runs to +8 EV, which is a white rectangle,
  /// not a photograph.
  static const _boostEv = 1.5;

  double _minZoom = 1;
  double _maxZoom = 1;
  double _zoom = 1;
  double _zoomAtGestureStart = 1;
  bool _zoomPillVisible = false;
  int _zoomPillToken = 0;

  /// Live pointer count. `onScaleUpdate` fires for one-finger drags too, where
  /// `scale` is pinned at 1 — without this a pan would fight tap-to-focus for
  /// the arena and neither would feel right.
  int _pointers = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lens = widget.initialLens;
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  /// Without this the preview freezes permanently the first time the app is
  /// backgrounded — the OS tears the capture session down underneath us and the
  /// controller never notices. This is the pattern the plugin's own README
  /// prescribes; lifecycle has not been the plugin's job since 0.5.0.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_release());
    } else if (state == AppLifecycleState.resumed) {
      // Not while the review surface is up: the user is looking at a photo, and
      // starting a capture session behind it would light the recording
      // indicator for a camera nobody is pointing at anything. _review binds a
      // controller again if they ask to retake.
      if (_reviewing == null) _select(_lens);
    }
  }

  /// Lets go of the capture session, leaving the screen mounted.
  ///
  /// Used for backgrounding and while a photo is being reviewed on top of this
  /// route — both are "someone else has the screen now", and a session held
  /// through either is battery, heat, and a recording indicator with nothing
  /// behind it.
  Future<void> _release() async {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    // The stream dies with the controller; leaving the flag set would make
    // _syncMetering believe it was already running on the next resume.
    _metering = false;
    controller.removeListener(_onControllerUpdate);
    if (mounted) setState(() {});
    await controller.dispose();
  }

  // ------------------------------------------------------------------ startup

  Future<void> _boot() async {
    _cameras = await _availableCameras();
    if (!mounted) return;
    if (_cameras.isEmpty) {
      // No cameras, or the enumeration itself failed. Either way this screen
      // has nothing to show and the system camera might.
      setState(() => _fault = _Fault.unavailable);
      return;
    }
    await _select(widget.initialLens);
  }

  /// Binds a controller to the first camera matching [lens], falling back to
  /// whatever the device actually has — a tablet with only a front camera should
  /// still open, not show an error.
  Future<void> _select(CameraLensDirection lens) async {
    if (_cameras.isEmpty) return;
    final description = _cameras.firstWhere(
      (c) => c.lensDirection == lens,
      orElse: () => _cameras.first,
    );

    final previous = _controller;
    _controller = null;
    _metering = false; // dies with the controller below
    if (mounted) setState(() {});
    previous?.removeListener(_onControllerUpdate);
    await previous?.dispose();

    final controller = CameraController(
      description,
      // The session preset caps the *photo* output too, and the plugin never
      // uses AVCaptureSessionPreset.photo — so this is a 1920×1080 JPEG, which
      // is the right size for a sent photo and leaves headroom for the 1024px
      // avatar crop. `high` would be 720p; `max` would trade a full-sensor
      // capture for materially worse shutter latency.
      ResolutionPreset.veryHigh,
      // Stills only. Requesting audio would trigger a microphone permission
      // prompt the user has no reason to connect with taking a photo, and adds
      // a second capture session to start.
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (_lensControls) {
        // None of this survives a controller swap, so it is all re-asserted
        // whenever a lens is bound — including on the flip, where the user
        // expects their flash and boost choices to carry over.
        _nativeFlash = await _trySetFlash(controller, _flash);
        final range = await Future.wait([
          controller.getMinZoomLevel(),
          controller.getMaxZoomLevel(),
          controller.getMinExposureOffset(),
          controller.getMaxExposureOffset(),
        ]);
        _minZoom = range[0];
        _maxZoom = range[1];
        _minEv = range[2];
        _maxEv = range[3];
        await _applyBoost(controller);
      }
    } on CameraException catch (e) {
      await controller.dispose();
      _fail(e);
      return;
    } catch (_) {
      // camera_web throws bare UnimplementedErrors rather than CameraException.
      await controller.dispose();
      if (mounted) setState(() => _fault = _Fault.failed);
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onControllerUpdate);
    setState(() {
      _controller = controller;
      _lens = description.lensDirection;
      _zoom = _minZoom;
      _fault = null;
    });
    await _syncMetering();
  }

  /// A session can die mid-flight — thermal shutdown, another app seizing the
  /// camera. Without this the preview simply freezes with no explanation.
  void _onControllerUpdate() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    if (controller.value.hasError && _fault == null) {
      setState(() => _fault = _Fault.failed);
    }
  }

  void _fail(CameraException e) {
    if (!mounted) return;
    setState(() {
      _fault = switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          _Fault.denied,
        _ => _Fault.failed,
      };
    });
  }

  bool get _isFront => _lens == CameraLensDirection.front;
  bool get _ready => _controller?.value.isInitialized ?? false;

  // ------------------------------------------------------------------ actions

  Future<void> _flip() async {
    if (_cameras.length < 2 || _capturing) return;
    HapticFeedback.selectionClick();
    await _select(
      _isFront ? CameraLensDirection.back : CameraLensDirection.front,
    );
  }

  // -------------------------------------------------------------------- flash

  /// Whether a flash control makes sense on this lens at all.
  ///
  /// A selfie camera almost never has a flash unit, but it always has a screen
  /// pointed at the subject — which is the whole trick, and why the control is
  /// offered on both lenses now instead of only the back one. The reverse does
  /// not hold: a screen flash on the rear lens would light up the photographer,
  /// so a back camera with no flash unit simply has no flash.
  bool get _flashAvailable => _nativeFlash || _isFront;

  /// Whether firing the flash means lighting the screen rather than asking the
  /// platform. True exactly when the lens faces the user and has no flash of
  /// its own to use.
  bool get _usesScreenFlash => _isFront && !_nativeFlash;

  /// Whether the flash should actually fire for the shot about to be taken.
  /// Only consulted on the screen-flash path — where the platform owns the
  /// flash, it decides `auto` for itself.
  bool get _flashWillFire => switch (_flash) {
        FlashMode.off => false,
        FlashMode.auto => _previewIsDark,
        _ => true,
      };

  /// Asks the platform for [mode] and reports whether it took.
  ///
  /// A device without a flash unit rejects every mode including `off`, so this
  /// doubles as the capability probe — one call that both configures the lens
  /// and tells us which kind of flash we have.
  Future<bool> _trySetFlash(CameraController c, FlashMode mode) async {
    try {
      await c.setFlashMode(mode);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null || _capturing || !_lensControls) return;
    HapticFeedback.selectionClick();
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    // Told to the platform whenever it will listen, even on the screen-flash
    // path: a lens can gain a real flash on the next swap, and the mode should
    // already be right when it does.
    final took = await _trySetFlash(controller, next);
    if (!mounted) return;
    setState(() {
      _flash = next;
      if (took) _nativeFlash = true;
    });
    await _syncMetering();
  }

  // ------------------------------------------------------------- light meter

  /// Starts or stops preview metering to match the current mode.
  ///
  /// Streaming preview frames is the single most expensive thing this screen
  /// can do, so it runs in exactly one situation: a selfie lens, with no flash
  /// of its own, set to auto — the only case where nothing else can answer "is
  /// it dark in here". Every other mode leaves the stream stopped.
  Future<void> _syncMetering() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final want = _lensControls &&
        _usesScreenFlash &&
        _flash == FlashMode.auto &&
        !_capturing;
    if (want == _metering) return;
    try {
      if (want) {
        await controller.startImageStream(_onPreviewFrame);
      } else {
        await controller.stopImageStream();
      }
      _metering = want;
    } catch (_) {
      // Not every platform streams. Auto then behaves as off, which is the
      // conservative half of the choice.
      _metering = false;
    }
  }

  void _onPreviewFrame(CameraImage image) {
    // Frames arrive at the preview's frame rate; four readings a second is
    // plenty for a decision about the light in a room, and the other twenty-six
    // are dropped before anything is touched.
    final now = DateTime.now();
    final last = _lastMeterAt;
    if (last != null && now.difference(last).inMilliseconds < 250) return;
    _lastMeterAt = now;

    final plane = image.planes.first;
    final luminance = meanPreviewLuminance(
      bytes: plane.bytes,
      width: image.width,
      height: image.height,
      // yuv420's first plane is Y — luminance already. iOS delivers packed
      // BGRA by default, which is four bytes a pixel and gets weighted.
      bytesPerPixel: image.format.group == ImageFormatGroup.bgra8888 ? 4 : 1,
      bytesPerRow: plane.bytesPerRow,
    );

    // Hysteresis: one threshold to become dark, a higher one to stop being it,
    // so a reading sitting on the line doesn't strobe the icon.
    final dark = _previewIsDark
        ? luminance < darkExitLuminance
        : luminance < darkEnterLuminance;
    if (dark != _previewIsDark && mounted) {
      setState(() => _previewIsDark = dark);
    }
  }

  // ------------------------------------------------------------------- boost

  /// Whether this lens reports any headroom to brighten into.
  bool get _boostAvailable => _lensControls && _maxEv > 0;

  Future<void> _applyBoost(CameraController c) async {
    if (!_boostAvailable) return;
    try {
      await c.setExposureOffset(
        _boost ? _boostEv.clamp(_minEv, _maxEv) : 0.0,
      );
    } catch (_) {
      // Some lenses report a range and then refuse to move within it.
    }
  }

  Future<void> _toggleBoost() async {
    final controller = _controller;
    if (controller == null || _capturing || !_boostAvailable) return;
    HapticFeedback.selectionClick();
    setState(() => _boost = !_boost);
    await _applyBoost(controller);
  }

  // --------------------------------------------------------------------- zoom

  void _onScaleStart(ScaleStartDetails _) => _zoomAtGestureStart = _zoom;

  Future<void> _onScaleUpdate(ScaleUpdateDetails d) async {
    final controller = _controller;
    if (controller == null || !_lensControls || _pointers != 2) return;
    final next = (_zoomAtGestureStart * d.scale).clamp(_minZoom, _maxZoom);
    if ((next - _zoom).abs() < 0.01) return;
    _zoom = next;
    _showZoomPill();
    try {
      await controller.setZoomLevel(next);
    } catch (_) {
      // Some browsers and some fixed-focal lenses simply don't zoom.
    }
  }

  void _showZoomPill() {
    final token = ++_zoomPillToken;
    setState(() => _zoomPillVisible = true);
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && token == _zoomPillToken) {
        setState(() => _zoomPillVisible = false);
      }
    });
  }

  // -------------------------------------------------------------------- focus

  /// Drives autofocus and metering at the tapped point, and shows a reticle
  /// there. [local] is in this widget's coordinates; [preview] is where the
  /// preview is actually painted, which after cover-cropping is larger than the
  /// screen and offset.
  Future<void> _focusAt(Offset local, Rect preview) async {
    final controller = _controller;
    if (controller == null || _capturing || preview.isEmpty) return;
    // No reticle either: acknowledging a tap the hardware cannot act on is a
    // promise the browser has no way to keep.
    if (!_lensControls) return;

    var nx = (local.dx - preview.left) / preview.width;
    final ny = (local.dy - preview.top) / preview.height;
    if (nx < 0 || nx > 1 || ny < 0 || ny > 1) return;
    // The front preview is mirrored, so a tap on the left of the screen is the
    // sensor's right — and the plugin will not do this for us. Its
    // `cgPoint(for:withOrientation:)` compensates for device orientation only.
    if (_isFront) nx = 1 - nx;

    HapticFeedback.selectionClick();
    final token = ++_focusToken;
    setState(() => _focusPoint = local);

    try {
      await controller.setFocusPoint(Offset(nx, ny));
      await controller.setExposurePoint(Offset(nx, ny));
    } on CameraException {
      // Fixed-focus lens. The reticle already acknowledged the tap; that the
      // hardware can't act on it is not worth an error.
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted && token == _focusToken) setState(() => _focusPoint = null);
  }

  // ------------------------------------------------------------------ capture

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();

    // Streaming frames and taking a still at the same time is a known way to
    // make Android's capture fail, and the reading is not needed once the
    // decision has been made.
    if (_metering) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
      _metering = false;
    }

    final screenFlash = _usesScreenFlash && _flashWillFire;
    if (screenFlash) {
      setState(() => _screenFlash = true);
      // The preview keeps running underneath, so auto-exposure sees the lit
      // face and adapts. Firing the shutter immediately would capture the frame
      // metered for the dark room and produce a blown-out white face.
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
    }

    final Uint8List bytes;
    try {
      final shot = await controller.takePicture();
      // XFile.readAsBytes, not File(shot.path): on web `takePicture` hands back
      // a `blob:` URL, and cross_file fetches it. On mobile it reads the temp
      // file the plugin just wrote.
      bytes = await shot.readAsBytes();
    } catch (_) {
      if (!mounted) return;
      await _recover();
      return;
    }
    if (!mounted) return;
    await _review(
      CameraPhoto(
        bytes: bytes,
        // Not mirrored here — the screen that receives this rasterizes once
        // anyway and folds the flip into that pass, so the shutter returns
        // immediately instead of stalling on a full-resolution re-encode.
        mirrored: _isFront && _captureNeedsMirroring,
      ),
    );
  }

  /// Hands [photo] to the caller's review surface and does what it says.
  ///
  /// The review is pushed on top of this route while it is still live — see
  /// [CameraScreen.review] for why — so the two things that follow are not a
  /// pop and a push but a pop and *nothing*: RETAKE reveals the camera that was
  /// there all along, and finishing closes it with the reviewed value.
  Future<void> _review(CameraPhoto photo) async {
    setState(() => _reviewing = photo);
    // Started, not awaited, before the session is let go: the review surface
    // pushes its route synchronously, so the frame that swaps the preview for
    // the still is the same frame the review covers it.
    final decision = widget.review(context, photo);
    final released = _release();

    final outcome = await decision;
    if (!mounted) return;

    switch (outcome) {
      case ReviewDone(:final value):
        // _reviewing deliberately left set — this route is about to dismiss and
        // should carry the photo out with it. See the field.
        Navigator.of(context).pop<CameraResult<T>>(CameraReviewed<T>(value));
      case ReviewRetake():
        // The old session has to be all the way down before the next one is
        // built, or the two overlap on the platform and the second is refused
        // the camera. Long done in practice — nobody reviews a photo in the
        // time a dispose takes — but not something to leave to the user's
        // reflexes.
        await released;
        if (!mounted) return;
        setState(() => _reviewing = null);
        await _recover();
        await _select(_lens);
    }
  }

  /// Back to a usable camera rather than a stuck shutter: drop the flash and
  /// clear the busy state. The caller restores the session — [_syncMetering]
  /// after a failed capture, which still holds its controller, or a fresh
  /// [_select] after a retake, which let go of it.
  Future<void> _recover() async {
    setState(() {
      _capturing = false;
      _screenFlash = false;
    });
    if (_controller != null) await _syncMetering();
  }

  void _pop(CameraResult<T> result) {
    if (_capturing) return;
    Navigator.of(context).pop<CameraResult<T>>(result);
  }

  // --------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final reviewing = _reviewing;
    return Scaffold(
      backgroundColor: Colors.black,
      body: BackdropGroup(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (reviewing != null)
              _stillBody(reviewing)
            else if (_fault != null)
              _faultBody()
            else
              _previewBody(),
            // No camera chrome over a still: the shutter and the flash toggle
            // belong to a preview, and this screen is not showing one.
            if (reviewing == null) SafeArea(child: _chrome()),
            // Above everything, including the chrome: a selfie camera with no
            // flash unit uses the screen itself as the light. Warm rather than
            // pure white, which renders skin as a lamp does instead of as a
            // fluorescent tube.
            if (_screenFlash)
              const IgnorePointer(
                child: ColoredBox(color: Color(0xFFFFF1DE)),
              ),
          ],
        ),
      ),
    );
  }

  /// The capture, laid out the way the review surface lays it out: contained on
  /// black, mirrored if it is a selfie that has not been flipped yet. Matching
  /// that is the whole point — this is what shows in the seam either side of the
  /// review, and a different fit would make the seam visible again.
  Widget _stillBody(CameraPhoto photo) {
    final image = Image.memory(
      photo.bytes,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
    );
    if (!photo.mirrored) return image;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
      child: image,
    );
  }

  Widget _previewBody() {
    final controller = _controller;
    // Deliberately not a centred spinner. `initialize()` is two platform
    // round-trips ending in startRunning(), commonly a few hundred ms; black
    // with live chrome over it reads as a camera warming up, where a spinner
    // reads as a page that has not loaded.
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final preview = _previewRect(controller, box);

        return Listener(
          onPointerDown: (_) => _pointers++,
          onPointerUp: (_) => _pointers = math.max(0, _pointers - 1),
          onPointerCancel: (_) => _pointers = math.max(0, _pointers - 1),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _focusAt(d.localPosition, preview),
            onDoubleTap: _cameras.length < 2 ? null : _flip,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ClipRect, because the cover-sized preview deliberately
                // overflows this box on its longer axis.
                ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: preview,
                        // No Transform. Every platform already mirrors the front
                        // preview itself — flipping again here is what made the
                        // selfie view come out backwards.
                        child: CameraPreview(controller),
                      ),
                    ],
                  ),
                ),
                if (_focusPoint != null)
                  Positioned(
                    left: _focusPoint!.dx - 36,
                    top: _focusPoint!.dy - 36,
                    child: const IgnorePointer(child: _FocusReticle()),
                  ),
                // A brief white wash on the shutter, so the capture is felt as
                // well as heard.
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _capturing ? 1 : 0,
                    duration: const Duration(milliseconds: 110),
                    child: const ColoredBox(color: Color(0x33FFFFFF)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Where to paint the preview so it *covers* [box].
  ///
  /// `previewSize` is reported in the sensor's own landscape frame whatever way
  /// up the phone is, so it is transposed for a portrait window before the
  /// cover scale is worked out.
  Rect _previewRect(CameraController controller, Size box) {
    final sensor = controller.value.previewSize;
    if (sensor == null || sensor.isEmpty || box.isEmpty) {
      return Offset.zero & box;
    }
    final portrait = box.height >= box.width;
    final natural = portrait
        ? Size(sensor.height, sensor.width)
        : Size(sensor.width, sensor.height);

    final cover =
        math.max(box.width / natural.width, box.height / natural.height);
    final w = natural.width * cover;
    final h = natural.height * cover;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  Widget _faultBody() {
    final message = switch (_fault!) {
      _Fault.denied =>
        AppLocalizations.of(context).cameraScreenAccessDeniedMessage,
      _Fault.unavailable =>
        AppLocalizations.of(context).cameraScreenOpeningSystemCamera,
      _Fault.failed =>
        AppLocalizations.of(context).cameraScreenOpeningSystemCamera,
    };
    // Anything that is not the user saying no hands off to the system camera
    // rather than stranding them on an error. Deferred a frame so this build
    // completes before the route pops.
    if (_fault != _Fault.denied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop<CameraResult<T>>(CameraUnavailable<T>());
        }
      });
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: PhotoChrome.inkDim,
            fontSize: 14,
            height: 1.5,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- chrome

  Widget _chrome() {
    return Stack(
      children: [
        Positioned(
          left: 12,
          right: 12,
          top: 8,
          child: Row(
            children: [
              PhotoGlassButton(
                icon: CupertinoIcons.xmark,
                semanticLabel:
                    AppLocalizations.of(context).cameraScreenCloseButtonLabel,
                onTap: _capturing ? null : () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              // Brightens a dark scene by pushing exposure compensation. Not
              // Apple's Night Mode — no plugin exposes that — so it is labelled
              // for what it does rather than for what it resembles.
              if (_ready && _boostAvailable) ...[
                PhotoGlassButton(
                  icon: _boost ? CupertinoIcons.moon_fill : CupertinoIcons.moon,
                  semanticLabel: _boost
                      ? AppLocalizations.of(context)
                          .cameraScreenLowLightBoostOnLabel
                      : AppLocalizations.of(context)
                          .cameraScreenLowLightBoostOffLabel,
                  onTap: _capturing ? null : _toggleBoost,
                  tint: _boost
                      ? const Color(0xFF7FA8FF).withValues(alpha: 0.85)
                      : null,
                  iconColor: _boost ? Colors.black : null,
                ),
                const SizedBox(width: 8),
              ],
              // Offered on the selfie lens too. It has no flash unit, but it
              // has a screen pointed straight at the subject, which is what
              // fires instead — see [_usesScreenFlash].
              if (_ready && _lensControls && _flashAvailable)
                PhotoGlassButton(
                  icon: switch (_flash) {
                    FlashMode.auto => CupertinoIcons.bolt_badge_a_fill,
                    FlashMode.off => CupertinoIcons.bolt_slash_fill,
                    _ => CupertinoIcons.bolt_fill,
                  },
                  semanticLabel: AppLocalizations.of(context)
                      .cameraScreenFlashStatusLabel(_flash.name),
                  onTap: _capturing ? null : _cycleFlash,
                  tint: _flash == FlashMode.off
                      ? null
                      : const Color(0xFFFFC531).withValues(alpha: 0.85),
                  iconColor: _flash == FlashMode.off ? null : Colors.black,
                ),
            ],
          ),
        ),
        if (_fault == null) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 108,
            child: Center(child: _zoomPill()),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 22,
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PhotoGlassButton(
                      icon: CupertinoIcons.photo_on_rectangle,
                      semanticLabel: AppLocalizations.of(context)
                          .cameraScreenChooseFromLibraryLabel,
                      size: 38,
                      iconSize: 17,
                      onTap: _capturing
                          ? null
                          : () => _pop(CameraPickLibrary<T>()),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _ShutterButton(
                      // Present from the first frame, so the screen has a shape
                      // while the session starts rather than appearing piecemeal.
                      onTap: _ready && !_capturing ? _capture : null,
                      busy: _capturing || !_ready,
                    ),
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: _cameras.length < 2
                      ? null
                      : Align(
                          alignment: Alignment.centerRight,
                          child: PhotoGlassButton(
                            icon: CupertinoIcons.camera_rotate,
                            semanticLabel: AppLocalizations.of(context)
                                .cameraScreenSwitchCameraLabel,
                            onTap: _capturing ? null : _flip,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _zoomPill() {
    return AnimatedOpacity(
      opacity: _zoomPillVisible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: IgnorePointer(
        child: PhotoGlassSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '${_zoom.toStringAsFixed(1)}×',
              style: const TextStyle(
                color: PhotoChrome.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Why the camera isn't showing, when it isn't.
enum _Fault { denied, unavailable, failed }

/// The shutter. A ring with an inner disc, the way every camera has looked
/// since the first one shipped with a touchscreen — deliberately the one
/// control on this screen that is not glass, because it is the only one you
/// should be able to find without looking.
class _ShutterButton extends StatefulWidget {
  const _ShutterButton({required this.onTap, required this.busy});

  final VoidCallback? onTap;
  final bool busy;

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: AppLocalizations.of(context).cameraScreenTakePhotoLabel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 78,
          height: 78,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: PhotoChrome.ink, width: 3.5),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOut,
                  width: _pressed ? 50 : 58,
                  height: _pressed ? 50 : 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PhotoChrome.ink.withValues(
                      alpha: widget.busy ? 0.4 : 1,
                    ),
                  ),
                ),
                if (widget.busy)
                  const PhotoSpinner(size: 22, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The square that blinks where you tapped to focus.
class _FocusReticle extends StatefulWidget {
  const _FocusReticle();

  @override
  State<_FocusReticle> createState() => _FocusReticleState();
}

class _FocusReticleState extends State<_FocusReticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ThemeScope.of(context).accent;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(_c.value);
        return Transform.scale(
          // Snaps in from slightly oversized, the way a real focus square does.
          scale: 1.25 - 0.25 * t,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: accent.withValues(alpha: 0.35 + 0.55 * _c.value),
                width: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }
}
