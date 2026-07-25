import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../media/image_raster.dart';
import 'image_crop_screen.dart';

/// Post-capture editor. Loads the image, optionally crops it, lets the user
/// draw colored strokes on top, then rasterizes everything back down and pops
/// the result as a [CroppedImage].
///
/// Crop is an opt-in button rather than a forced step: this screen is the choke
/// point for both chat image entries, and most sends don't want a framing pass.
class CameraEditorScreen extends StatefulWidget {
  const CameraEditorScreen({super.key, required this.source});
  final File source;

  @override
  State<CameraEditorScreen> createState() => _CameraEditorScreenState();
}

class _Stroke {
  _Stroke({required this.color, required this.width});
  final Color color;
  final double width;
  final List<Offset> points = [];
}

class _CameraEditorScreenState extends State<CameraEditorScreen> {
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

  final List<_Stroke> _strokes = [];
  _Stroke? _current;
  Color _color = _palette.first;
  final double _width = 6;
  ui.Image? _image;
  Object? _loadError;
  bool _saving = false;

  /// Set once the user crops. Holds an already-encoded JPEG, which lets a
  /// crop-only edit skip a second, pointless rasterize on save.
  CroppedImage? _cropped;

  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.source.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _image = frame.image);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  void _onPanStart(DragStartDetails d) {
    HapticFeedback.selectionClick();
    setState(() {
      _current = _Stroke(color: _color, width: _width)..points.add(d.localPosition);
      _strokes.add(_current!);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final s = _current;
    if (s == null) return;
    setState(() => s.points.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    _current = null;
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _strokes.removeLast());
  }

  /// Only reachable while [_strokes] is empty. Strokes are stored in
  /// canvas-widget coordinates and mapped to image space at save time via
  /// [_fittedRect], so replacing the image under them would silently relocate
  /// every stroke. Crop first, then draw.
  Future<void> _crop() async {
    if (_saving || _strokes.isNotEmpty) return;
    final result = await ImageCropScreen.open(
      context,
      source: _cropped?.file ?? widget.source,
      shape: CropShape.rect,
      maxOutputEdge: 2048,
      confirmLabel: 'CROP',
    );
    if (result == null || !mounted) return;
    try {
      final codec = await ui.instantiateImageCodec(await result.file.readAsBytes());
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = frame.image;
        _cropped = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _save() async {
    final img = _image;
    if (img == null) return;

    // Crop-only edit: the crop screen already encoded exactly this image, so
    // re-rasterizing it would only lose a generation of quality.
    final cropped = _cropped;
    if (_strokes.isEmpty && cropped != null) {
      Navigator.of(context).pop(cropped);
      return;
    }

    final canvasBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (canvasBox == null) return;
    final canvasSize = canvasBox.size;

    setState(() => _saving = true);
    try {
      // Map strokes from canvas-space → image-space, then rasterize.
      final imgSize = Size(img.width.toDouble(), img.height.toDouble());
      final fitted =
          _fittedRect(canvasSize: canvasSize, imageSize: imgSize); // BoxFit.contain

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, imgSize.width, imgSize.height));
      // Opaque backdrop: rasterToJpegFile reads premultiplied rawRgba, which
      // only equals straight RGBA where alpha is 255.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, imgSize.width, imgSize.height),
        Paint()..color = const Color(0xFF000000),
      );
      // Draw original image first.
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, imgSize.width, imgSize.height),
        Rect.fromLTWH(0, 0, imgSize.width, imgSize.height),
        Paint(),
      );
      // Map and draw each stroke.
      for (final s in _strokes) {
        if (s.points.length < 2) continue;
        final mapped = s.points
            .map((p) => _canvasToImage(p, fitted, imgSize))
            .toList();
        final paint = Paint()
          ..color = s.color
          ..strokeWidth = s.width * (imgSize.width / fitted.width)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
        final path = Path()..moveTo(mapped.first.dx, mapped.first.dy);
        for (var i = 1; i < mapped.length; i++) {
          path.lineTo(mapped[i].dx, mapped[i].dy);
        }
        canvas.drawPath(path, paint);
      }
      final pic = recorder.endRecording();
      final rendered = await pic.toImage(img.width, img.height);
      pic.dispose();
      final result = await rasterToJpegFile(rendered, prefix: 'edit');
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  /// Computes the rect where the image is drawn inside the canvas given
  /// `BoxFit.contain` semantics.
  Rect _fittedRect({required Size canvasSize, required Size imageSize}) {
    final imgAspect = imageSize.width / imageSize.height;
    final canAspect = canvasSize.width / canvasSize.height;
    if (imgAspect > canAspect) {
      // Letterbox top/bottom.
      final h = canvasSize.width / imgAspect;
      final y = (canvasSize.height - h) / 2;
      return Rect.fromLTWH(0, y, canvasSize.width, h);
    } else {
      // Pillarbox left/right.
      final w = canvasSize.height * imgAspect;
      final x = (canvasSize.width - w) / 2;
      return Rect.fromLTWH(x, 0, w, canvasSize.height);
    }
  }

  Offset _canvasToImage(Offset p, Rect fitted, Size imgSize) {
    final rx = ((p.dx - fitted.left) / fitted.width).clamp(0.0, 1.0);
    final ry = ((p.dy - fitted.top) / fitted.height).clamp(0.0, 1.0);
    return Offset(rx * imgSize.width, ry * imgSize.height);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _canvas()),
            _toolBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(null),
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
          ),
          const Spacer(),
          IconButton(
            onPressed:
                _image == null || _saving || _strokes.isNotEmpty ? null : _crop,
            icon: Icon(
              Icons.crop_rotate,
              color: _image == null || _strokes.isNotEmpty
                  ? Colors.white24
                  : Colors.white,
              size: 22,
            ),
            tooltip: _strokes.isEmpty ? 'crop' : 'crop before drawing',
          ),
          IconButton(
            onPressed: _strokes.isEmpty || _saving ? null : _undo,
            icon: Icon(
              Icons.undo,
              color: _strokes.isEmpty ? Colors.white24 : Colors.white,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvas() {
    final img = _image;
    if (_loadError != null) {
      return const Center(
        child: Text('failed to load image', style: TextStyle(color: Colors.white70)),
      );
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Container(
          key: _canvasKey,
          alignment: Alignment.center,
          child: AspectRatio(
            aspectRatio: img.width / img.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RawImage(
                  image: img,
                  fit: BoxFit.contain,
                ),
                CustomPaint(painter: _StrokesPainter(_strokes)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolBar() {
    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == c ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _btn(
                  label: 'RETAKE',
                  filled: false,
                  onTap:
                      _saving ? null : () => Navigator.of(context).pop(null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _btn(
                  label: _saving ? 'SAVING…' : 'USE PHOTO',
                  filled: true,
                  onTap: _saving || _image == null ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn({required String label, required bool filled, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? const Color(0xFF2D7CF7)
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes);
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.length < 2) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (var i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx, s.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter old) =>
      !identical(old.strokes, strokes) || old.strokes.length != strokes.length;
}

