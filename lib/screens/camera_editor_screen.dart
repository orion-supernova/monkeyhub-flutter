import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../media/editor_geometry.dart';
import '../media/image_raster.dart';

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
///    rotation means the caller gets the original file — not a re-encode of it.
///
/// Pops a [CroppedImage] on confirm, `null` on cancel.
class CameraEditorScreen extends StatefulWidget {
  const CameraEditorScreen({super.key, required this.source});
  final File source;

  @override
  State<CameraEditorScreen> createState() => _CameraEditorScreenState();
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
    Color(0xFFEF5350),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFFFA726),
    Color(0xFFAB47BC),
    Colors.white,
    Colors.black,
  ];

  /// Brush sizes as a fraction of image width.
  static const _widths = <double>[0.005, 0.010, 0.020, 0.035];

  static const _accent = Color(0xFF2D7CF7);

  ui.Image? _display;
  Object? _loadError;
  bool _saving = false;

  /// Quarter-turns clockwise the user has applied. Replayed against the
  /// full-resolution decode at export; the display image is rotated eagerly so
  /// what's on screen is always the truth.
  int _rotations = 0;

  final List<_EditorStroke> _strokes = [];
  final List<_EditorStroke> _redo = [];
  _EditorStroke? _current;

  Color _color = _palette.first;
  double _width = _widths[1];

  _Tool _tool = _Tool.draw;

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
          await decodeImageFile(widget.source, maxEdge: _maxDisplayEdge);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _display = image);
    } catch (e) {
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
      }
      _tool = tool;
      _activeHandle = null;
    });
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

    // Untouched photo: hand back the original file. Re-encoding it would cost a
    // JPEG generation and a full-resolution rasterize to produce something
    // meant to be identical to what we were given.
    if (!_hasEdits) {
      // The decoded image on screen is capped at _maxDisplayEdge, so its size
      // is not the file's size — read the real one from the header.
      final size = await imageFileSize(widget.source);
      if (!mounted) return;
      Navigator.of(context).pop(
        CroppedImage(
          file: widget.source,
          contentType: _contentTypeOf(widget.source),
          width: size.width.round(),
          height: size.height.round(),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    ui.Image? full;
    try {
      // Full resolution, deliberately uncapped: the file the user sends is the
      // one they gave us, at the size they gave it to us. A tall photo stays
      // tall.
      full = await decodeImageFile(widget.source);
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
      // Opaque backdrop: rasterToJpegFile reads PREMULTIPLIED rawRgba, which
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

      final result = await rasterToJpegFile(raster, prefix: 'edit');
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
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

  static String _contentTypeOf(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.heic') || path.endsWith('.heif')) return 'image/heic';
    if (path.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _stage()),
            if (_tool == _Tool.crop) _cropBar() else _drawBar(),
            _actionBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final cropping = _tool == _Tool.crop;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.close,
            label: 'discard',
            onTap: _saving
                ? null
                : () => cropping
                    ? _cancelCrop()
                    : Navigator.of(context).pop(null),
          ),
          const Spacer(),
          if (cropping) ...[
            _IconBtn(
              icon: Icons.rotate_90_degrees_ccw_outlined,
              label: 'rotate',
              onTap: _display == null || _saving ? null : _rotate90,
            ),
            _IconBtn(
              icon: Icons.settings_backup_restore,
              label: 'reset crop',
              onTap: _saving || _crop == const Rect.fromLTWH(0, 0, 1, 1)
                  ? null
                  : _resetCrop,
            ),
          ] else ...[
            _IconBtn(
              icon: Icons.undo,
              label: 'undo',
              onTap: _strokes.isEmpty || _saving ? null : _undo,
            ),
            _IconBtn(
              icon: Icons.redo,
              label: 'redo',
              onTap: _redo.isEmpty || _saving ? null : _redoStroke,
            ),
            _IconBtn(
              icon: Icons.layers_clear_outlined,
              label: 'clear drawing',
              onTap: _strokes.isEmpty || _saving ? null : _clearStrokes,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stage() {
    if (_loadError != null) {
      return const Center(
        child: Text(
          'couldn\'t open that image',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final img = _display;
    if (img == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
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
              if (_tool == _Tool.draw)
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
      ),
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

  // ---------------------------------------------------------------- toolbars

  Widget _cropBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final preset in _AspectPreset.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Chip(
                label: preset.label,
                selected: preset == _preset,
                onTap: _saving ? null : () => _selectPreset(preset),
              ),
            ),
        ],
      ),
    );
  }

  Widget _drawBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in _palette)
                    GestureDetector(
                      onTap: _saving ? null : () => setState(() => _color = c),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c
                                  ? Colors.white
                                  : Colors.white24,
                              width: _color == c ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 26, color: Colors.white24),
          const SizedBox(width: 8),
          for (final w in _widths)
            GestureDetector(
              onTap: _saving ? null : () => setState(() => _width = w),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 26,
                height: 30,
                child: Center(
                  child: Container(
                    // Scaled to read as a size ladder, not to match the true
                    // on-screen width — 0.035 of a photo is far wider than a
                    // toolbar row.
                    width: 4 + w * 240,
                    height: 4 + w * 240,
                    decoration: BoxDecoration(
                      color: _width == w ? Colors.white : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    final cropping = _tool == _Tool.crop;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _Btn(
              label: cropping ? 'CANCEL' : 'RETAKE',
              onTap: _saving
                  ? null
                  : () => cropping
                      ? _cancelCrop()
                      : Navigator.of(context).pop(null),
            ),
          ),
          const SizedBox(width: 10),
          if (!cropping) ...[
            Expanded(
              child: _Btn(
                label: 'CROP',
                icon: Icons.crop_rotate,
                onTap: _display == null || _saving
                    ? null
                    : () => _selectTool(_Tool.crop),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: _Btn(
              label: cropping
                  ? 'DONE'
                  : (_saving ? 'SAVING…' : 'USE PHOTO'),
              filled: true,
              onTap: _saving || _display == null
                  ? null
                  : () => cropping ? _selectTool(_Tool.draw) : _save(),
            ),
          ),
        ],
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

/// Bare tappable icon. No `IconButton` anywhere in this screen — that widget
/// renders an ink ripple, and this app renders no ink.
class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: enabled ? Colors.white : Colors.white24,
          ),
        ),
      ),
    );
  }
}

/// Aspect-ratio chip in the crop toolbar.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// RETAKE / CROP / USE PHOTO.
class _Btn extends StatefulWidget {
  const _Btn({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final IconData? icon;

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final fg = enabled ? Colors.white : Colors.white38;
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.label,
      radius: 12,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.filled
                  ? _CameraEditorScreenState._accent
                      .withValues(alpha: enabled ? 1 : 0.35)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 15, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
