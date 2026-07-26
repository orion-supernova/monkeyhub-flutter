import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
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
/// Pops a [CameraResult], or null if the user backed out.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.initialLens = CameraLensDirection.back});

  /// Which lens to open on. Avatars open front — you are photographing
  /// yourself; chat opens back.
  final CameraLensDirection initialLens;

  static Future<CameraResult?> open(
    BuildContext context, {
    CameraLensDirection initialLens = CameraLensDirection.back,
  }) {
    return Navigator.of(context).push<CameraResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CameraScreen(initialLens: initialLens),
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
  State<CameraScreen> createState() => _CameraScreenState();
}

/// How the camera screen finished.
sealed class CameraResult {
  const CameraResult();
}

/// A photograph.
class CameraPhoto extends CameraResult {
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
class CameraPickLibrary extends CameraResult {
  const CameraPickLibrary();
}

/// The camera could not be started, for a reason that is not the user saying
/// no. Callers should fall back to `ImagePicker(source: camera)`.
class CameraUnavailable extends CameraResult {
  const CameraUnavailable();
}

class _CameraScreenState extends State<CameraScreen>
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

  /// Where the last tap-to-focus landed, in this widget's local coordinates.
  /// Null once the reticle has faded out.
  Offset? _focusPoint;
  int _focusToken = 0;

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
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller = null;
      controller.removeListener(_onControllerUpdate);
      controller.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _select(_lens);
    }
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
        // The flash mode does not survive a controller swap, so re-assert it.
        if (description.lensDirection == CameraLensDirection.back) {
          await controller.setFlashMode(_flash);
        }
        // Fetched together, once: both are platform round-trips and neither
        // changes for the life of this controller.
        final range = await Future.wait([
          controller.getMinZoomLevel(),
          controller.getMaxZoomLevel(),
        ]);
        _minZoom = range[0];
        _maxZoom = range[1];
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

  Future<void> _cycleFlash() async {
    final controller = _controller;
    if (controller == null || _capturing || !_lensControls) return;
    HapticFeedback.selectionClick();
    final next = switch (_flash) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await controller.setFlashMode(next);
    } on CameraException {
      return; // This lens has no flash. Leave the mode where it was.
    }
    if (mounted) setState(() => _flash = next);
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
    try {
      final shot = await controller.takePicture();
      // XFile.readAsBytes, not File(shot.path): on web `takePicture` hands back
      // a `blob:` URL, and cross_file fetches it. On mobile it reads the temp
      // file the plugin just wrote.
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop<CameraResult>(
        CameraPhoto(
          bytes: bytes,
          // Not mirrored here — the screen that receives this rasterizes once
          // anyway and folds the flip into that pass, so the shutter returns
          // immediately instead of stalling on a full-resolution re-encode.
          mirrored: _isFront && _captureNeedsMirroring,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _pop(CameraResult result) {
    if (_capturing) return;
    Navigator.of(context).pop<CameraResult>(result);
  }

  // --------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BackdropGroup(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_fault != null) _faultBody() else _previewBody(),
            SafeArea(child: _chrome()),
          ],
        ),
      ),
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
        'camera access is off.\nturn it on in Settings to take a photo.',
      _Fault.unavailable => 'opening the system camera…',
      _Fault.failed => 'opening the system camera…',
    };
    // Anything that is not the user saying no hands off to the system camera
    // rather than stranding them on an error. Deferred a frame so this build
    // completes before the route pops.
    if (_fault != _Fault.denied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(const CameraUnavailable());
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
                semanticLabel: 'close camera',
                onTap: _capturing ? null : () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              // Front cameras have no flash unit; offering the control would be
              // offering something that cannot happen.
              if (_ready && !_isFront && _lensControls)
                PhotoGlassButton(
                  icon: switch (_flash) {
                    FlashMode.auto => CupertinoIcons.bolt_badge_a_fill,
                    FlashMode.off => CupertinoIcons.bolt_slash_fill,
                    _ => CupertinoIcons.bolt_fill,
                  },
                  semanticLabel: 'flash: ${_flash.name}',
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
                      semanticLabel: 'choose from library',
                      size: 38,
                      iconSize: 17,
                      onTap: _capturing
                          ? null
                          : () => _pop(const CameraPickLibrary()),
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
                            semanticLabel: 'switch camera',
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
      semanticLabel: 'take photo',
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
