import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../media/editor_geometry.dart';
import '../media/image_raster.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/photo_chrome.dart';

/// Post-capture editor: draw on the photo, frame it, send it.
///
/// Everything the user does is held as *state over the original file* rather
/// than baked into pixels as they go — strokes are normalized 0..1 points, the
/// crop is a normalized rect. Nothing is rasterized until save. Three things
/// fall out of that, all of which the previous version got wrong:
///
///  * **Crop is reversible and can be re-entered at any time.** It used to push
///    a separate screen that re-encoded the image, which is why it had to be
///    disabled the moment you drew anything ("crop before drawing") — replacing
///    the pixels underneath widget-space strokes would have relocated them.
///  * **Preview and export agree by construction.** Both read the same
///    normalized data through the same mapping, instead of the painter using one
///    coordinate space and the exporter reconstructing another.
///  * **An unedited photo is passed through untouched.** No crop, no strokes, no
///    rotation means the caller gets the original bytes — not a re-encode.
///
/// Pops an [EditorOutcome] on send or retake, `null` on discard.
class CameraEditorScreen extends StatefulWidget {
  const CameraEditorScreen({
    super.key,
    required this.source,
    this.canRetake = false,
  });

  /// The encoded photo. Bytes rather than a `dart:io` File so this screen works
  /// in a browser, where a picked image is a `blob:` URL with no file behind it.
  final Uint8List source;

  /// Whether there is a camera to go back to. False for a photo chosen from the
  /// library — "retake" would have nothing to retake — and the control is then
  /// absent rather than disabled.
  final bool canRetake;

  static Future<EditorOutcome?> open(
    BuildContext context, {
    required Uint8List source,
    bool canRetake = false,
  }) {
    return Navigator.of(context).push<EditorOutcome>(
      MaterialPageRoute(
        builder: (_) => CameraEditorScreen(source: source, canRetake: canRetake),
      ),
    );
  }

  @override
  State<CameraEditorScreen> createState() => _CameraEditorScreenState();
}

/// How the user left the editor.
sealed class EditorOutcome {
  const EditorOutcome();
}

/// Send this picture. The wrapper exists rather than another field on
/// [CroppedImage] because that type is shared with `ImageCropScreen` (the
/// avatar cropper), where "view once" is meaningless — keeping the send-time
/// decision out here means the raster types stay about rasters.
class EditorSend extends EditorOutcome {
  const EditorSend({required this.image, required this.viewOnce});

  final CroppedImage image;

  /// Armed with the circled "1": the recipient may open it exactly once, and
  /// the file is deleted from the server afterwards.
  final bool viewOnce;
}

/// Throw this one away and open the camera again.
///
/// A distinct outcome rather than a null pop, because the two mean opposite
/// things to the caller and the old screen conflated them — its RETAKE button
/// popped null, which dropped the user back in the chat instead of back at the
/// camera.
class EditorRetake extends EditorOutcome {
  const EditorRetake();
}

/// A freehand stroke, in normalized image coordinates.
class _EditorStroke {
  _EditorStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final Color color;

  /// Fraction of the image's width, so a stroke keeps its visual weight
  /// whatever resolution the image is displayed or exported at.
  final double width;

  /// 0..1 fractions of the source image, in its current rotation.
  final List<Offset> points;
}

enum _Tool { draw, crop }

/// Selectable crop ratios. `null` aspect is freeform.
class _AspectPreset {
  const _AspectPreset(this.label, this.aspect);
  final String label;

  /// Width / height in pixels. Null means free; [_original] is resolved from
  /// the image at use time.
  final double? aspect;

  static const free = _AspectPreset('FREE', null);
  static const original = _AspectPreset('ORIG', -1);
  static const values = <_AspectPreset>[
    free,
    original,
    _AspectPreset('1:1', 1),
    _AspectPreset('4:5', 4 / 5),
    _AspectPreset('16:9', 16 / 9),
  ];

  bool get isOriginal => aspect == -1;
}

class _CameraEditorScreenState extends State<CameraEditorScreen> {
  /// Cap for the on-screen decode. A 4032×3024 photo is ~48 MB of RGBA at full
  /// size and makes every drawn frame stutter; 2048 is comfortably past any
  /// phone screen, so the downscale is invisible. Export re-decodes at full
  /// resolution — the sent file is never limited by this.
  static const _maxDisplayEdge = 2048;

  static const _palette = <Color>[
    Color(0xFFFFFFFF),
    // Not pure black: at 0.045 of an image's width a #000 stroke over a dark
    // photo reads as a hole punched in it rather than as ink.
    Color(0xFF121212),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF0A84FF),
    Color(0xFFBF5AF2),
    Color(0xFFFF2D95),
  ];

  /// Brush size as a fraction of image width — continuous, so the slider can
  /// land anywhere between a fine line and a marker.
  static const _minWidth = 0.004;
  static const _maxWidth = 0.045;

  /// Bends the slider so the thin half of the range gets most of the travel.
  /// Linear, the bottom two thirds of the useful sizes live in the first tenth
  /// of the track and cannot be picked apart with a thumb.
  static const _widthGamma = 1.8;

  static double _widthForSlider(double t) =>
      _minWidth + (_maxWidth - _minWidth) * math.pow(t.clamp(0.0, 1.0), _widthGamma);

  static double _sliderForWidth(double w) => math.pow(
        ((w - _minWidth) / (_maxWidth - _minWidth)).clamp(0.0, 1.0),
        1 / _widthGamma,
      ).toDouble();

  ui.Image? _display;
  Object? _loadError;
  bool _saving = false;

  /// Armed with the circled "1" in the action bar. Survives crop mode and every
  /// edit — it is a decision about the *send*, not about the picture, so
  /// nothing in the editing model touches it.
  bool _viewOnce = false;

  /// Quarter-turns clockwise the user has applied. Replayed against the
  /// full-resolution decode at export; the display image is rotated eagerly so
  /// what's on screen is always the truth.
  int _rotations = 0;

  final List<_EditorStroke> _strokes = [];
  final List<_EditorStroke> _redo = [];
  _EditorStroke? _current;

  Color _color = _palette.first;
  double _width = 0.010;

  _Tool _tool = _Tool.draw;

  /// Whether the pen is out. The drawing gesture only exists while it is, which
  /// is the whole reason the tray is a toggle: the old screen listened for pans
  /// over the photo unconditionally, so every attempt to swipe the picture left
  /// a scribble on it.
  bool _penArmed = false;

  /// True between the start and end of a stroke. Fades the chrome out of the
  /// way so the picture is unobstructed while it is being drawn on.
  bool _drawing = false;

  /// Normalized crop, in the image's current rotation. The unit rect means
  /// uncropped, and is compared exactly — it is only ever set by [_resetCrop].
  Rect _crop = const Rect.fromLTWH(0, 0, 1, 1);
  _AspectPreset _preset = _AspectPreset.free;

  /// The crop as it was when crop mode was entered, so CANCEL can restore it.
  Rect? _cropOnEnter;
  _AspectPreset? _presetOnEnter;

  CropHandle? _activeHandle;

  /// Repaint signals. Painting is driven by these rather than `setState` so a
  /// drag repaints one layer instead of rebuilding the toolbar, palette and
  /// decoded image on every pointer move.
  final ValueNotifier<int> _committedRev = ValueNotifier(0);
  final ValueNotifier<int> _liveRev = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _display?.dispose();
    _committedRev.dispose();
    _liveRev.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final image =
          await decodeImageBytes(widget.source, maxEdge: _maxDisplayEdge);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _display = image);
    } catch (e) {
      // Said out loud. Swallowed into _loadError alone, a decode that failed on
      // every image in the browser looked identical in the console to one that
      // never ran — which is how it survived a build and a deploy.
      debugPrint('[camera_editor] decode failed: $e');
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  // ---------------------------------------------------------------- geometry

  Size get _imageSize {
    final img = _display;
    if (img == null) return const Size(1, 1);
    return Size(img.width.toDouble(), img.height.toDouble());
  }

  /// The normalized region currently on screen.
  ///
  /// Crop mode shows the whole image so the handles have somewhere to go;
  /// everything else shows the crop, which is what the user is actually making.
  Rect get _viewport =>
      _tool == _Tool.crop ? const Rect.fromLTWH(0, 0, 1, 1) : _crop;

  bool get _hasEdits =>
      _strokes.isNotEmpty ||
      _rotations != 0 ||
      _crop != const Rect.fromLTWH(0, 0, 1, 1);

  double? _resolvedAspect() {
    if (_preset.aspect == null) return null;
    if (_preset.isOriginal) return _imageSize.width / _imageSize.height;
    return _preset.aspect;
  }

  // ------------------------------------------------------------------- tools

  void _selectTool(_Tool tool) {
    if (_tool == tool || _saving) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (tool == _Tool.crop) {
        _cropOnEnter = _crop;
        _presetOnEnter = _preset;
        // Framing and drawing are different jobs; carrying the pen into crop
        // mode would only put a tray over the handles.
        _penArmed = false;
      }
      _tool = tool;
      _activeHandle = null;
    });
  }

  void _togglePen() {
    if (_saving) return;
    HapticFeedback.selectionClick();
    setState(() => _penArmed = !_penArmed);
  }

  void _cancelCrop() {
    setState(() {
      _crop = _cropOnEnter ?? const Rect.fromLTWH(0, 0, 1, 1);
      _preset = _presetOnEnter ?? _AspectPreset.free;
      _tool = _Tool.draw;
    });
  }

  void _resetCrop() {
    HapticFeedback.lightImpact();
    setState(() {
      _crop = const Rect.fromLTWH(0, 0, 1, 1);
      _preset = _AspectPreset.free;
    });
  }

  void _selectPreset(_AspectPreset preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _preset = preset;
      final aspect = _resolvedAspect();
      if (aspect != null) {
        _crop = centeredCrop(aspect: aspect, imageSize: _imageSize);
      }
    });
  }

  /// Rotates the decoded image eagerly and carries the annotations with it.
  ///
  /// Same reasoning as the avatar cropper: folding rotation into a transform
  /// matrix would leave every downstream rect axis-unaligned, so the image is
  /// re-rasterized and the normalized geometry rotated to match. `_rotations`
  /// records it so export can reproduce the same turn on the full-resolution
  /// decode.
  Future<void> _rotate90() async {
    final src = _display;
    if (src == null || _saving) return;
    HapticFeedback.selectionClick();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(src.height.toDouble(), 0);
    canvas.rotate(math.pi / 2);
    canvas.drawImage(
      src,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final rotated = await picture.toImage(src.height, src.width);
    picture.dispose();
    if (!mounted) {
      rotated.dispose();
      return;
    }

    setState(() {
      _display?.dispose();
      _display = rotated;
      _rotations = (_rotations + 1) % 4;
      _crop = rotateRectCW(_crop);
      for (final s in _strokes) {
        for (var i = 0; i < s.points.length; i++) {
          s.points[i] = rotateNormCW(s.points[i]);
        }
      }
      // A preset locked to the source's own ratio flips with it.
      if (_preset.isOriginal) {
        final aspect = _resolvedAspect();
        if (aspect != null) {
          _crop = centeredCrop(aspect: aspect, imageSize: _imageSize);
        }
      }
    });
    _committedRev.value++;
  }

  // ---------------------------------------------------------------- drawing

  Offset _clampUnit(Offset n) =>
      Offset(n.dx.clamp(0.0, 1.0), n.dy.clamp(0.0, 1.0));

  void _drawStart(Offset local, Rect stage) {
    if (_saving) return;
    if (!stage.contains(local)) return;
    HapticFeedback.selectionClick();
    setState(() => _drawing = true);
    _current = _EditorStroke(
      color: _color,
      width: _width,
      points: [
        _clampUnit(stageToNorm(local, viewport: _viewport, stage: stage)),
      ],
    );
    _liveRev.value++;
  }

  void _drawUpdate(Offset local, Rect stage) {
    final stroke = _current;
    if (stroke == null) return;
    stroke.points
        .add(_clampUnit(stageToNorm(local, viewport: _viewport, stage: stage)));
    _liveRev.value++;
  }

  void _drawEnd() {
    final stroke = _current;
    _current = null;
    _liveRev.value++;
    // Twice per stroke, not once per pointer move — the live stroke itself is
    // still driven by the repaint notifier, not by rebuilding.
    if (_drawing) setState(() => _drawing = false);
    if (stroke == null) return;
    _commit(stroke);
  }

  void _drawDot(Offset local, Rect stage) {
    if (_saving || !stage.contains(local)) return;
    HapticFeedback.selectionClick();
    _commit(
      _EditorStroke(
        color: _color,
        width: _width,
        points: [
          _clampUnit(stageToNorm(local, viewport: _viewport, stage: stage)),
        ],
      ),
    );
  }

  void _commit(_EditorStroke stroke) {
    _strokes.add(stroke);
    // A new stroke forks the history — anything that was undone is gone.
    _redo.clear();
    _committedRev.value++;
    // Enables/disables undo, redo and USE PHOTO.
    setState(() {});
  }

  void _undo() {
    if (_strokes.isEmpty || _saving) return;
    HapticFeedback.lightImpact();
    _redo.add(_strokes.removeLast());
    _committedRev.value++;
    setState(() {});
  }

  void _redoStroke() {
    if (_redo.isEmpty || _saving) return;
    HapticFeedback.lightImpact();
    _strokes.add(_redo.removeLast());
    _committedRev.value++;
    setState(() {});
  }

  void _clearStrokes() {
    if (_strokes.isEmpty || _saving) return;
    HapticFeedback.mediumImpact();
    // Moved rather than dropped, and in reverse, so redo rebuilds them in the
    // order they were drawn.
    while (_strokes.isNotEmpty) {
      _redo.add(_strokes.removeLast());
    }
    _committedRev.value++;
    setState(() {});
  }

  // ------------------------------------------------------------------ export

  Future<void> _save() async {
    if (_saving || _display == null) return;

    // Untouched photo: hand back the original bytes. Re-encoding would cost a
    // JPEG generation and a full-resolution rasterize to produce something
    // meant to be identical to what we were given.
    if (!_hasEdits) {
      // The decoded image on screen is capped at _maxDisplayEdge, so its size
      // is not the source's size — read the real one from the header.
      //
      // A header we cannot read is not a reason to lose the send. Falling
      // through costs one re-encode of a picture we meant to pass through
      // untouched, and the export path below takes its dimensions from a real
      // decode, so the photo still goes out at the size the user gave us.
      try {
        final size = await imageBytesSize(widget.source);
        if (!mounted) return;
        Navigator.of(context).pop(
          EditorSend(
            image: CroppedImage(
              bytes: widget.source,
              contentType: sniffImageContentType(widget.source),
              width: size.width.round(),
              height: size.height.round(),
            ),
            viewOnce: _viewOnce,
          ),
        );
        return;
      } catch (e) {
        debugPrint('[camera_editor] header read failed, re-encoding: $e');
      }
    }

    setState(() => _saving = true);
    ui.Image? full;
    try {
      // Full resolution, deliberately uncapped: the file the user sends is the
      // one they gave us, at the size they gave it to us. A tall photo stays
      // tall.
      full = await decodeImageBytes(widget.source);
      final srcW = full.width.toDouble();
      final srcH = full.height.toDouble();
      // Rotation swaps the axes an odd number of times.
      final rotated = _rotations.isOdd ? Size(srcH, srcW) : Size(srcW, srcH);

      final cropPx = Rect.fromLTRB(
        _crop.left * rotated.width,
        _crop.top * rotated.height,
        _crop.right * rotated.width,
        _crop.bottom * rotated.height,
      );
      final outW = math.max(1, cropPx.width.round());
      final outH = math.max(1, cropPx.height.round());
      final dst = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, dst);
      // Opaque backdrop: rasterToJpegBytes reads PREMULTIPLIED rawRgba, which
      // only equals straight RGBA where alpha is 255.
      canvas.drawRect(dst, Paint()..color = const Color(0xFF000000));

      canvas.save();
      // Shift the crop's origin to the canvas origin, then place the image in
      // rotated space. Composing the two means the crop rect needs no rotation
      // maths of its own — it is already expressed in the rotated frame.
      canvas.translate(-cropPx.left, -cropPx.top);
      _applyRotation(canvas, srcW, srcH);
      canvas.drawImage(
        full,
        Offset.zero,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.medium,
      );
      canvas.restore();

      for (final stroke in _strokes) {
        _paintStroke(
          canvas,
          stroke,
          viewport: _crop,
          stage: dst,
          // Stroke width is a fraction of image width, and `dst` is 1:1 with
          // rotated pixels, so this is the same visual weight as on screen.
          strokeWidth: stroke.width * rotated.width,
        );
      }

      final picture = recorder.endRecording();
      final raster = await picture.toImage(outW, outH);
      picture.dispose();

      final result = await rasterToJpegBytes(raster);
      if (!mounted) return;
      Navigator.of(context).pop(
        EditorSend(image: result, viewOnce: _viewOnce),
      );
    } catch (e) {
      debugPrint('[camera_editor] export failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
    } finally {
      full?.dispose();
    }
  }

  /// Places the unrotated image into the rotated frame, for [_rotations]
  /// quarter-turns clockwise of a [w]×[h] image.
  void _applyRotation(Canvas canvas, double w, double h) {
    switch (_rotations) {
      case 1:
        canvas.translate(h, 0);
        canvas.rotate(math.pi / 2);
      case 2:
        canvas.translate(w, h);
        canvas.rotate(math.pi);
      case 3:
        canvas.translate(0, w);
        canvas.rotate(3 * math.pi / 2);
      default:
        break;
    }
  }

  /// Paints one stroke, mapping its normalized points into [stage].
  ///
  /// Shared by the on-screen painters and the exporter — the single reason the
  /// two can't drift apart.
  static void _paintStroke(
    Canvas canvas,
    _EditorStroke stroke, {
    required Rect viewport,
    required Rect stage,
    required double strokeWidth,
  }) {
    final pts = [
      for (final n in stroke.points)
        normToStage(n, viewport: viewport, stage: stage),
    ];
    if (pts.isEmpty) return;

    if (pts.length == 1) {
      // A tap is a dot. The old renderer skipped anything under two points, in
      // both the preview and the export, so a tap drew nothing at all.
      canvas.drawCircle(
        pts.first,
        strokeWidth / 2,
        Paint()
          ..color = stroke.color
          ..isAntiAlias = true,
      );
      return;
    }

    canvas.drawPath(
      strokePath(pts),
      Paint()
        ..color = stroke.color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  // -------------------------------------------------------------------- view

  /// The photo is the screen. Chrome floats over it on glass rather than
  /// sitting in bars beside it — the old layout stacked four rows of solid
  /// black and left the picture in a letterbox in the middle of them.
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final cropping = _tool == _Tool.crop;
    final safe = MediaQuery.paddingOf(context);

    // Full-bleed while drawing. Crop is the exception: its handles live on the
    // picture's edges, so the picture is pulled clear of the chrome for as long
    // as the user is framing.
    final stagePad = cropping
        ? EdgeInsets.fromLTRB(24, safe.top + 64, 24, safe.bottom + 132)
        : EdgeInsets.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: BackdropGroup(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              padding: stagePad,
              duration: theme.motionMed,
              curve: Curves.easeOutCubic,
              child: _stage(),
            ),
            // Nothing here sets an opaque hit-test behaviour except the controls
            // themselves, so the gaps between them stay drawable.
            IgnorePointer(
              ignoring: _drawing,
              child: AnimatedOpacity(
                opacity: _drawing ? 0.16 : 1,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 6,
                        child: _topRail(theme, cropping),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 10,
                        child: _bottomRail(theme, cropping),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topRail(AppTheme theme, bool cropping) {
    final ready = _display != null && !_saving;
    return Row(
      children: [
        PhotoGlassButton(
          icon: CupertinoIcons.xmark,
          semanticLabel: cropping ? 'cancel crop' : 'discard photo',
          onTap: _saving
              ? null
              : () => cropping ? _cancelCrop() : Navigator.of(context).pop(),
        ),
        const Spacer(),
        // Undo and redo earn their place only once there is history to move
        // through; a permanently greyed pair is just noise over a photograph.
        if (!cropping && _strokes.isNotEmpty) ...[
          PhotoGlassButton(
            icon: CupertinoIcons.arrow_uturn_left,
            semanticLabel: 'undo',
            onTap: _saving ? null : _undo,
          ),
          const SizedBox(width: 8),
        ],
        if (!cropping && _redo.isNotEmpty) ...[
          PhotoGlassButton(
            icon: CupertinoIcons.arrow_uturn_right,
            semanticLabel: 'redo',
            onTap: _saving ? null : _redoStroke,
          ),
          const SizedBox(width: 8),
        ],
        if (cropping && _crop != const Rect.fromLTWH(0, 0, 1, 1)) ...[
          PhotoGlassButton(
            icon: CupertinoIcons.arrow_2_circlepath,
            semanticLabel: 'reset crop',
            onTap: _saving ? null : _resetCrop,
          ),
          const SizedBox(width: 8),
        ],
        PhotoGlassButton(
          icon: CupertinoIcons.rotate_left,
          semanticLabel: 'rotate',
          onTap: ready ? _rotate90 : null,
        ),
        // Crop lives up here, icon only, as the second of the two things you
        // can do to the frame itself.
        if (!cropping) ...[
          const SizedBox(width: 8),
          PhotoGlassButton(
            icon: CupertinoIcons.crop,
            semanticLabel: 'crop',
            onTap: ready ? () => _selectTool(_Tool.crop) : null,
          ),
        ],
      ],
    );
  }

  Widget _stage() {
    if (_loadError != null) {
      // No browser decodes HEIC, and image_picker_for_web hands the original
      // blob straight through when its own canvas resize fails on one — so a
      // HEIC picked on the web lands here every time. Naming the reason beats
      // "couldn't open that image", which reads as our bug and leaves the user
      // with nothing to try.
      final heic = kIsWeb && sniffImageContentType(widget.source) == 'image/heic';
      return Center(
        child: Text(
          heic
              ? 'this browser can\'t open HEIC photos'
              : 'couldn\'t open that image',
          style: const TextStyle(
            color: PhotoChrome.inkDim,
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    final img = _display;
    if (img == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PhotoChrome.inkDim,
          ),
        ),
      );
    }

    return LayoutBuilder(
        builder: (context, constraints) {
          final box = Size(constraints.maxWidth, constraints.maxHeight);
          final viewport = _viewport;
          final stage = fitContain(
            box: box,
            aspect: pixelAspect(viewport, _imageSize),
          );
          if (stage.isEmpty) return const SizedBox.shrink();

          // Where the WHOLE image lands, which equals `stage` while cropping and
          // overflows it once a crop is applied. One expression covers both, so
          // the clip does the work instead of a branch.
          final imageRect = Rect.fromPoints(
            normToStage(Offset.zero, viewport: viewport, stage: stage),
            normToStage(const Offset(1, 1), viewport: viewport, stage: stage),
          );
          final strokeScale = stage.width / viewport.width;

          return Stack(
            children: [
              // Positioned.fill, so the clip and the layers inside it are
              // handed tight box-sized constraints. Left as a loose child, the
              // inner Stack would have only positioned children and would have
              // to infer its size from the constraints it happened to get.
              Positioned.fill(
                child: ClipRect(
                  clipper: _StageClip(stage),
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: imageRect,
                        child: RawImage(
                          image: img,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                      // Committed strokes and the in-progress one paint on
                      // separate boundaries: dragging then re-rasterizes only
                      // the live layer, leaving the decoded photo and the
                      // finished strokes alone.
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _StrokesPainter(
                              strokes: _strokes,
                              viewport: viewport,
                              stage: stage,
                              strokeScale: strokeScale,
                              revision: _committedRev,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _LiveStrokePainter(
                              current: () => _current,
                              viewport: viewport,
                              stage: stage,
                              strokeScale: strokeScale,
                              revision: _liveRev,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_tool == _Tool.crop) ..._cropLayers(stage, viewport),
              // Only while the pen is out. Mounted unconditionally, as it used
              // to be, every stray swipe across the photo left a mark on it.
              if (_tool == _Tool.draw && _penArmed)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _drawDot(d.localPosition, stage),
                    onPanStart: (d) => _drawStart(d.localPosition, stage),
                    onPanUpdate: (d) => _drawUpdate(d.localPosition, stage),
                    onPanEnd: (_) => _drawEnd(),
                    onPanCancel: _drawEnd,
                  ),
                ),
            ],
          );
        },
    );
  }

  // --------------------------------------------------------------- crop mode

  List<Widget> _cropLayers(Rect stage, Rect viewport) {
    final cropStage = Rect.fromPoints(
      normToStage(_crop.topLeft, viewport: viewport, stage: stage),
      normToStage(_crop.bottomRight, viewport: viewport, stage: stage),
    );
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _CropOverlayPainter(stage: stage, crop: cropStage),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            _activeHandle = _hitHandle(d.localPosition, cropStage);
            if (_activeHandle != null) HapticFeedback.selectionClick();
          },
          onPanUpdate: (d) {
            final handle = _activeHandle;
            if (handle == null) return;
            // Screen delta → normalized delta, through the same mapping
            // everything else uses.
            final delta = Offset(
              d.delta.dx / stage.width * viewport.width,
              d.delta.dy / stage.height * viewport.height,
            );
            setState(() {
              _crop = resizeCrop(
                crop: _crop,
                handle: handle,
                delta: delta,
                imageSize: _imageSize,
                aspect: _resolvedAspect(),
              );
            });
          },
          onPanEnd: (_) => _activeHandle = null,
          onPanCancel: () => _activeHandle = null,
        ),
      ),
    ];
  }

  /// Which handle a touch at [p] grabs.
  ///
  /// Corners win over edges so the two never fight in the overlap, and the slop
  /// is a finger's worth rather than the hairline the handles are drawn at.
  static CropHandle? _hitHandle(Offset p, Rect crop) {
    const slop = 30.0;
    bool near(double a, double b) => (a - b).abs() <= slop;
    final withinX = p.dx >= crop.left - slop && p.dx <= crop.right + slop;
    final withinY = p.dy >= crop.top - slop && p.dy <= crop.bottom + slop;
    if (!withinX || !withinY) return null;

    final onLeft = near(p.dx, crop.left);
    final onRight = near(p.dx, crop.right);
    final onTop = near(p.dy, crop.top);
    final onBottom = near(p.dy, crop.bottom);

    if (onLeft && onTop) return CropHandle.topLeft;
    if (onRight && onTop) return CropHandle.topRight;
    if (onLeft && onBottom) return CropHandle.bottomLeft;
    if (onRight && onBottom) return CropHandle.bottomRight;
    if (onLeft) return CropHandle.left;
    if (onRight) return CropHandle.right;
    if (onTop) return CropHandle.top;
    if (onBottom) return CropHandle.bottom;
    return crop.contains(p) ? CropHandle.move : null;
  }

  // ------------------------------------------------------------ bottom chrome

  /// Everything along the bottom edge. [AnimatedSize] carries the height change
  /// when the pen tray opens or the view-once note appears, so the rail rises
  /// rather than jumping.
  Widget _bottomRail(AppTheme theme, bool cropping) {
    return AnimatedSize(
      duration: theme.motionMed,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: cropping ? _cropRail(theme) : _drawRail(theme),
    );
  }

  Widget _cropRail(AppTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhotoGlassSurface(
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final preset in _AspectPreset.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _Chip(
                      label: preset.label,
                      selected: preset == _preset,
                      accent: theme.accent,
                      accentInk: theme.accentInk,
                      onTap: _saving ? null : () => _selectPreset(preset),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Spacer(),
            PhotoGlassPill(
              label: 'DONE',
              icon: CupertinoIcons.checkmark,
              tint: theme.accent,
              onTap: _saving || _display == null
                  ? null
                  : () => _selectTool(_Tool.draw),
            ),
          ],
        ),
      ],
    );
  }

  Widget _drawRail(AppTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only while armed — in crop mode the rail means "commit the frame",
        // and a note about sending would answer a question the user isn't
        // asking yet.
        if (_viewOnce) _viewOnceNote(theme),
        if (_penArmed) _penTray(theme),
        Row(
          children: [
            // Small and icon-only: it is the way back, not one of three equal
            // choices, which is what the old full-width RETAKE button implied.
            if (widget.canRetake) ...[
              PhotoGlassButton(
                icon: CupertinoIcons.arrow_counterclockwise,
                semanticLabel: 'retake',
                size: 38,
                iconSize: 17,
                onTap: _saving
                    ? null
                    : () => Navigator.of(context).pop(const EditorRetake()),
              ),
              const SizedBox(width: 8),
            ],
            PhotoGlassButton(
              icon: CupertinoIcons.scribble,
              semanticLabel: _penArmed ? 'put the pen away' : 'draw on the photo',
              size: 38,
              iconSize: 18,
              tint: _penArmed ? theme.accent : null,
              iconColor: _penArmed ? theme.accentInk : null,
              onTap: _saving ? null : _togglePen,
            ),
            const SizedBox(width: 8),
            _ViewOnceToggle(
              active: _viewOnce,
              accent: theme.accent,
              accentInk: theme.accentInk,
              onTap: _saving
                  ? null
                  : () => setState(() => _viewOnce = !_viewOnce),
            ),
            const Spacer(),
            PhotoGlassPill(
              label: _saving ? 'SENDING…' : 'SEND',
              icon: _saving ? null : CupertinoIcons.arrow_up,
              tint: theme.accent,
              onTap: _saving || _display == null ? null : _save,
            ),
          ],
        ),
      ],
    );
  }

  Widget _viewOnceNote(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PhotoGlassSurface(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.flame_fill, size: 12, color: theme.accent),
              const SizedBox(width: 6),
              const Text(
                'disappears after it\'s opened once',
                style: TextStyle(
                  color: PhotoChrome.inkDim,
                  fontSize: 11.5,
                  letterSpacing: 0.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Colours and brush size — hidden until the pen is out, which is the point:
  /// the old screen showed the whole palette permanently, to a user who most of
  /// the time only wanted to look at their photo and send it.
  Widget _penTray(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PhotoGlassSurface(
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final c in _palette)
                            _Swatch(
                              color: c,
                              selected: _color == c,
                              onTap: _saving
                                  ? null
                                  : () => setState(() => _color = c),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PhotoGlassButton(
                    // Not CupertinoIcons.clear — that is the same glyph as
                    // xmark, which is the discard button at the top of the
                    // screen. Two controls that throw away very different
                    // amounts of work must not look identical.
                    icon: CupertinoIcons.trash,
                    semanticLabel: 'clear drawing',
                    size: 32,
                    iconSize: 15,
                    onTap: _strokes.isEmpty || _saving ? null : _clearStrokes,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  // A live dot, at the colour and roughly the weight the stroke
                  // will land at. Scaled to read as a preview, not to match the
                  // true on-screen width — 0.045 of a photo is far wider than
                  // this tray.
                  SizedBox(
                    width: 24,
                    child: Center(
                      child: Container(
                        width: 5 + _width * 300,
                        height: 5 + _width * 300,
                        decoration: BoxDecoration(
                          color: _color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PhotoChrome.stroke,
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WidthSlider(
                      value: _sliderForWidth(_width),
                      accent: theme.accent,
                      enabled: !_saving,
                      onChanged: (t) =>
                          setState(() => _width = _widthForSlider(t)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// The circled "1" — arms burn-after-reading for this photo.
///
/// Sized to the 38pt glass buttons beside it so the rail sits on one baseline.
/// Kept hand-drawn rather than swapped for an icon: nothing in any icon set
/// says "they get one look at this", and the numeral does.
class _ViewOnceToggle extends StatelessWidget {
  const _ViewOnceToggle({
    required this.active,
    required this.accent,
    required this.accentInk,
    required this.onTap,
  });

  final bool active;
  final Color accent;
  final Color accentInk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = active
        ? accentInk
        : (enabled ? PhotoChrome.ink : PhotoChrome.inkDisabled);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: active ? 'view once: on' : 'view once: off',
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: PhotoGlassSurface(
          shape: BoxShape.circle,
          tint: active ? accent : null,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: Text(
                '1',
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ painters

/// Clips the stage to the region the image actually occupies, so strokes and
/// cropped-away pixels don't paint into the letterbox margins.
class _StageClip extends CustomClipper<Rect> {
  const _StageClip(this.stage);
  final Rect stage;

  @override
  Rect getClip(Size size) => stage;

  @override
  bool shouldReclip(_StageClip old) => old.stage != stage;
}

/// Paints the finished strokes.
///
/// `repaint: revision` is what actually drives this. The previous painter's
/// `shouldRepaint` was `!identical(old.strokes, strokes) || old.strokes.length
/// != strokes.length` against a single `final List` that never changed
/// identity — so the first clause was always false and the second compared the
/// list's length to its own. It returned false unconditionally, and the strokes
/// were never drawn. Hence a repaint signal that cannot be satisfied by the
/// object it is watching, plus a `shouldRepaint` that compares values.
class _StrokesPainter extends CustomPainter {
  _StrokesPainter({
    required this.strokes,
    required this.viewport,
    required this.stage,
    required this.strokeScale,
    required this.revision,
  })  : _revision = revision.value,
        super(repaint: revision);

  final List<_EditorStroke> strokes;
  final Rect viewport;
  final Rect stage;
  final double strokeScale;
  final ValueNotifier<int> revision;
  final int _revision;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _CameraEditorScreenState._paintStroke(
        canvas,
        stroke,
        viewport: viewport,
        stage: stage,
        strokeWidth: stroke.width * strokeScale,
      );
    }
  }

  @override
  bool shouldRepaint(_StrokesPainter old) =>
      old._revision != _revision ||
      old.viewport != viewport ||
      old.stage != stage ||
      old.strokeScale != strokeScale;
}

/// Paints only the stroke under the finger, on its own layer.
class _LiveStrokePainter extends CustomPainter {
  _LiveStrokePainter({
    required this.current,
    required this.viewport,
    required this.stage,
    required this.strokeScale,
    required this.revision,
  })  : _revision = revision.value,
        super(repaint: revision);

  /// Read through a closure rather than captured by value: the stroke is
  /// mutated in place as points arrive, and the painter is not rebuilt for each
  /// one — the repaint notifier is what fires.
  final _EditorStroke? Function() current;
  final Rect viewport;
  final Rect stage;
  final double strokeScale;
  final ValueNotifier<int> revision;
  final int _revision;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = current();
    if (stroke == null) return;
    _CameraEditorScreenState._paintStroke(
      canvas,
      stroke,
      viewport: viewport,
      stage: stage,
      strokeWidth: stroke.width * strokeScale,
    );
  }

  @override
  bool shouldRepaint(_LiveStrokePainter old) =>
      old._revision != _revision ||
      old.viewport != viewport ||
      old.stage != stage ||
      old.strokeScale != strokeScale;
}

/// Dims everything outside the crop, and draws the grab affordances.
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.stage, required this.crop});

  final Rect stage;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    // Difference path rather than a saveLayer punch-out: the overlay wants a
    // tint over the discarded area, not a hole, and a saveLayer would allocate
    // an offscreen target on a surface that repaints on every drag frame.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(stage),
        Path()..addRect(crop),
      ),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.6),
    );

    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRect(crop, hairline);

    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 1; i < 3; i++) {
      final dx = crop.left + crop.width * i / 3;
      final dy = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(dx, crop.top), Offset(dx, crop.bottom), thin);
      canvas.drawLine(Offset(crop.left, dy), Offset(crop.right, dy), thin);
    }

    // Corner brackets and edge ticks — the visible half of what `_hitHandle`
    // makes grabbable.
    final heavy = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..color = Colors.white;
    final arm = math.min(24.0, math.min(crop.width, crop.height) / 3);
    for (final (corner, sx, sy) in [
      (crop.topLeft, 1.0, 1.0),
      (crop.topRight, -1.0, 1.0),
      (crop.bottomLeft, 1.0, -1.0),
      (crop.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner.translate(arm * sx, 0), heavy);
      canvas.drawLine(corner, corner.translate(0, arm * sy), heavy);
    }
    final tick = arm * 0.6;
    canvas.drawLine(
      Offset(crop.center.dx - tick / 2, crop.top),
      Offset(crop.center.dx + tick / 2, crop.top),
      heavy,
    );
    canvas.drawLine(
      Offset(crop.center.dx - tick / 2, crop.bottom),
      Offset(crop.center.dx + tick / 2, crop.bottom),
      heavy,
    );
    canvas.drawLine(
      Offset(crop.left, crop.center.dy - tick / 2),
      Offset(crop.left, crop.center.dy + tick / 2),
      heavy,
    );
    canvas.drawLine(
      Offset(crop.right, crop.center.dy - tick / 2),
      Offset(crop.right, crop.center.dy + tick / 2),
      heavy,
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.stage != stage || old.crop != crop;
}

// ------------------------------------------------------------------- controls

/// Aspect-ratio chip in the crop rail.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.accentInk,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color accentInk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accent : PhotoChrome.fill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accentInk : PhotoChrome.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// One ink colour.
///
/// [FocusableTap], unlike the bare `GestureDetector` this replaces — the
/// swatches and the width control were the only two things on this screen a
/// keyboard or a screen reader could not reach.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      semanticLabel: 'ink colour',
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 38,
          height: 34,
          child: Center(
            // The selected swatch grows and gains a ring, rather than only
            // changing its border weight — at 28pt a 1px border difference is
            // not a signal anyone reads.
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              width: selected ? 30 : 24,
              height: selected ? 30 : 24,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? PhotoChrome.ink : PhotoChrome.stroke,
                  width: selected ? 2.5 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Continuous brush-size control.
///
/// Hand-rolled rather than a Material [Slider]: that widget paints a hover and
/// focus overlay and carries a theme this screen deliberately does not use.
/// Reports a 0..1 position; the caller decides what width that means.
class _WidthSlider extends StatelessWidget {
  const _WidthSlider({
    required this.value,
    required this.accent,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final Color accent;
  final bool enabled;
  final ValueChanged<double> onChanged;

  static const _track = 3.0;
  static const _thumb = 18.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The thumb's centre can only travel between its own two radii, so the
        // position maps into that inner span rather than the full width.
        final span = math.max(1.0, width - _thumb);

        void report(double dx) {
          if (!enabled) return;
          onChanged(((dx - _thumb / 2) / span).clamp(0.0, 1.0));
        }

        final t = value.clamp(0.0, 1.0);
        final centre = _thumb / 2 + span * t;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => report(d.localPosition.dx),
          onHorizontalDragStart: (d) => report(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => report(d.localPosition.dx),
          child: SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: _track,
                    decoration: BoxDecoration(
                      color: PhotoChrome.fill,
                      borderRadius: BorderRadius.circular(_track),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  width: centre,
                  child: Container(
                    height: _track,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: enabled ? 1 : 0.4),
                      borderRadius: BorderRadius.circular(_track),
                    ),
                  ),
                ),
                Positioned(
                  left: centre - _thumb / 2,
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: const BoxDecoration(
                      color: PhotoChrome.ink,
                      shape: BoxShape.circle,
                      boxShadow: [PhotoChrome.shadow],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
