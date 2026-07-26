import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../media/image_raster.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/photo_chrome.dart';

/// Shape of the crop window. [circle] is for avatars — every avatar display
/// site clips to a circle, so the ghost ring shows exactly what will survive.
enum CropShape { circle, rect }

/// Pan/zoom/rotate an image into a fixed crop window before uploading it.
///
/// Pops a [CroppedImage] on confirm, `null` on cancel. (The chat editor pops a
/// richer `EditorOutcome`, because it also has to say whether the user asked to
/// retake — there is nothing to retake here.)
///
/// The whole screen rests on one invariant: **the child always covers the crop
/// window**. It is cover-sized (its shorter axis exactly fills the window) and
/// `minScale` is 1, which makes InteractiveViewer's own boundary clamping
/// sufficient to guarantee the crop rect can never include empty space. Break
/// that invariant — by allowing minScale below 1, or by contain-sizing the
/// child — and the user can frame background into their avatar.
class ImageCropScreen extends StatefulWidget {
  const ImageCropScreen({
    super.key,
    required this.source,
    this.shape = CropShape.circle,
    this.aspectRatio,
    this.maxOutputEdge = 1024,
    this.confirmLabel = 'USE PHOTO',
    this.title = 'adjust',
    this.mirrored = false,
  });

  /// The encoded photo. Bytes rather than a `dart:io` File so this screen works
  /// in a browser, where a picked image is a `blob:` URL with no file behind it.
  final Uint8List source;
  final CropShape shape;

  /// Whether [source] is a front-lens capture that still has to be reflected to
  /// match the preview the user framed it in.
  ///
  /// Applied to the decoded image in [_ImageCropScreenState._load], so it costs
  /// one flip of an already-downscaled raster and nothing at all at export —
  /// `_confirm()` draws from that same image. The alternative, flipping the
  /// encoded bytes at capture time, would put a full-resolution re-encode
  /// between the shutter and this screen.
  final bool mirrored;

  /// Width/height of the crop window. Ignored (forced to 1) for [CropShape.circle];
  /// null in rect mode means "keep the image's own aspect ratio".
  final double? aspectRatio;

  /// Longest edge of the encoded result. The crop is never upscaled past its
  /// own source pixels, so a tight crop of a small photo stays small.
  final int maxOutputEdge;
  final String confirmLabel;
  final String title;

  static Future<CroppedImage?> open(
    BuildContext context, {
    required Uint8List source,
    CropShape shape = CropShape.circle,
    double? aspectRatio,
    int maxOutputEdge = 1024,
    String confirmLabel = 'USE PHOTO',
    String title = 'adjust',
    bool mirrored = false,
  }) {
    return Navigator.of(context).push<CroppedImage>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageCropScreen(
          source: source,
          shape: shape,
          aspectRatio: aspectRatio,
          maxOutputEdge: maxOutputEdge,
          confirmLabel: confirmLabel,
          title: title,
          mirrored: mirrored,
        ),
      ),
    );
  }

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen>
    with SingleTickerProviderStateMixin {
  /// Decoding a 4032×3024 photo at full size costs ~48 MB of RGBA and makes pan
  /// stutter. 2048 is still 2× the default output edge, so nothing visible is
  /// lost to the downscale.
  static const _maxDecodeEdge = 2048;
  static const _maxScale = 6.0;

  final TransformationController _xform = TransformationController();
  late final AnimationController _animCtrl;
  Animation<Matrix4>? _animTween;

  ui.Image? _image;
  bool _loadFailed = false;
  bool _saving = false;

  /// Crop-window size in logical pixels. Null until the first layout pass.
  Size? _window;

  /// Cover-sized child extent, in the same logical pixels.
  double _childW = 0;
  double _childH = 0;

  /// Multiplier from child-widget coordinates to source-image pixels.
  double _imgPerChild = 1;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final t = _animTween;
        if (t != null) _xform.value = t.value;
      });
    _load();
  }

  @override
  void dispose() {
    _image?.dispose();
    _xform.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Was a hand-rolled copy of decodeImageBytes, and carried the same web
      // bug: ImageDescriptor.width throws UnsupportedError in a browser, so the
      // avatar cropper failed on every photo too. One decoder now, so the next
      // platform difference is only found once.
      var image = await decodeImageBytes(widget.source, maxEdge: _maxDecodeEdge);
      // A front-lens capture arrives the way the sensor saw it, reversed from
      // the preview it was framed in. Flipped here, on the already-downscaled
      // decode, rather than on the encoded bytes at capture time — `_confirm()`
      // rasterizes from this same image, so the export costs nothing extra.
      if (widget.mirrored) {
        final flipped = await flipImageHorizontally(image);
        image.dispose();
        image = flipped;
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
      _fit();
    } catch (e) {
      debugPrint('[image_crop] decode failed: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  // ---------------------------------------------------------------- geometry

  /// Recomputes the cover-sizing and re-centers. Safe to call whenever either
  /// the image or the window changes; no-op until both are known.
  void _fit() {
    final img = _image;
    final window = _window;
    if (img == null || window == null) return;

    final imgW = img.width.toDouble();
    final imgH = img.height.toDouble();
    // BoxFit.cover: the larger of the two ratios, so both axes are covered.
    final cover = math.max(window.width / imgW, window.height / imgH);
    _childW = imgW * cover;
    _childH = imgH * cover;
    _imgPerChild = 1 / cover;

    // InteractiveViewer with `constrained: false` wraps the child in an
    // OverflowBox aligned TOP-LEFT, so the identity matrix would open on the
    // image's corner. Seed the midpoint of the legal translation interval.
    _setMatrix(
      Matrix4.identity()
        ..translateByDouble(
          (window.width - _childW) / 2,
          (window.height - _childH) / 2,
          0.0,
          1.0,
        ),
    );
  }

  /// The legal translation interval, from `screen = s·child + t`:
  ///
  ///   tx ∈ [Vw − s·childW, 0]   ty ∈ [Vh − s·childH, 0]
  ///
  /// Both are non-empty exactly when the child still covers the window, which
  /// `s ≥ 1` guarantees.
  Matrix4 _clamp(Matrix4 m) {
    final window = _window;
    if (window == null) return m;
    final s = m.getMaxScaleOnAxis().clamp(1.0, _maxScale);
    final t = m.getTranslation();
    // Cover-sizing makes the child EXACTLY fit the window on one axis, so at
    // s == 1 that axis's interval collapses to {0} — and floating-point error
    // lands the bound a hair above zero, which makes `clamp` throw on a
    // reversed range. min() pins the degenerate case to exactly {0}.
    final minTx = math.min(window.width - s * _childW, 0.0);
    final minTy = math.min(window.height - s * _childH, 0.0);
    final tx = t.x.clamp(minTx, 0.0);
    final ty = t.y.clamp(minTy, 0.0);
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(s, s, s, 1.0);
  }

  /// InteractiveViewer only clamps matrices that came from a gesture — writing
  /// `TransformationController.value` directly bypasses `_matrixTranslate` and
  /// `_matrixScale` entirely. Every direct write goes through here instead.
  void _setMatrix(Matrix4 m) => _xform.value = _clamp(m);

  void _handleDoubleTap(TapDownDetails d) {
    final window = _window;
    if (window == null || _saving) return;
    final zoomed = _xform.value.getMaxScaleOnAxis() > 1.05;
    Matrix4 target;
    if (zoomed) {
      target = Matrix4.identity()
        ..translateByDouble(
          (window.width - _childW) / 2,
          (window.height - _childH) / 2,
          0.0,
          1.0,
        );
    } else {
      const scale = 2.5;
      final scene = _xform.toScene(d.localPosition);
      target = Matrix4.identity()
        ..translateByDouble(
          -scene.dx * scale + d.localPosition.dx,
          -scene.dy * scale + d.localPosition.dy,
          0.0,
          1.0,
        )
        ..scaleByDouble(scale, scale, scale, 1.0);
    }
    _animTween = Matrix4Tween(begin: _xform.value, end: _clamp(target)).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl
      ..value = 0
      ..forward();
  }

  /// Rotates the decoded image eagerly rather than folding a rotation into the
  /// transform matrix. InteractiveViewer hardcodes `_rotateEnabled = false` and
  /// its boundary math carries an explicit TODO that rotation is unhandled — a
  /// rotateZ in the controller would silently break the coverage invariant.
  Future<void> _rotate90() async {
    final src = _image;
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
      _image?.dispose();
      _image = rotated;
    });
    _fit();
  }

  // ----------------------------------------------------------------- confirm

  Future<void> _confirm() async {
    final img = _image;
    final window = _window;
    if (img == null || window == null || _saving) return;
    setState(() => _saving = true);
    try {
      // No rotation lives in the matrix, so two opposite corners define the
      // crop rect exactly.
      final tl = _xform.toScene(Offset.zero);
      final br = _xform.toScene(Offset(window.width, window.height));
      final imgW = img.width.toDouble();
      final imgH = img.height.toDouble();
      final src = Rect.fromLTRB(
        (tl.dx * _imgPerChild).clamp(0.0, imgW),
        (tl.dy * _imgPerChild).clamp(0.0, imgH),
        (br.dx * _imgPerChild).clamp(0.0, imgW),
        (br.dy * _imgPerChild).clamp(0.0, imgH),
      );

      // Never upscale: a tight crop of a small photo should stay small.
      final outW = math.min(widget.maxOutputEdge, src.width.round());
      final outH = math.max(1, (outW * src.height / src.width).round());
      final dst = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, dst);
      // Opaque backdrop so every alpha is 255 — rasterToJpegBytes reads
      // premultiplied rawRgba, which only equals straight RGBA at full alpha.
      canvas.drawRect(dst, Paint()..color = const Color(0xFF000000));
      canvas.drawImageRect(
        img,
        src,
        dst,
        Paint()
          ..isAntiAlias = true
          // Mipmapped bilinear. FilterQuality.high is bicubic WITHOUT mipmaps
          // and aliases visibly on the 3–5× downscale from a phone photo.
          ..filterQuality = FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final raster = await picture.toImage(outW, outH);
      picture.dispose();

      // Deliberately NOT masked to a circle: every avatar display site already
      // clips, so transparent corners would buy nothing and forfeit JPEG.
      final result = await rasterToJpegBytes(raster);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  // -------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(theme),
            Expanded(child: _stage(theme)),
            _bottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _topBar(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          LiquidGlass(
            shape: LiquidGlassShape.circle,
            size: const Size(38, 38),
            onTap: _saving ? null : () => Navigator.of(context).pop(),
            child: Icon(Icons.close, size: 18, color: theme.ink),
          ),
          Expanded(
            child: Center(
              child: Text(widget.title, style: theme.label),
            ),
          ),
          LiquidGlass(
            shape: LiquidGlassShape.circle,
            size: const Size(38, 38),
            onTap: _image == null || _saving ? null : _rotate90,
            child: Icon(
              Icons.rotate_90_degrees_ccw_outlined,
              size: 18,
              color: _image == null || _saving ? theme.inkMuted : theme.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stage(AppTheme theme) {
    if (_loadFailed) {
      // Same reasoning as the chat editor: a HEIC picked in a browser cannot be
      // decoded there, and saying so is more useful than a generic failure.
      final heic =
          kIsWeb && sniffImageContentType(widget.source) == 'image/heic';
      return Center(
        child: Text(
          heic
              ? 'this browser can\'t open HEIC photos'
              : 'couldn\'t open that image',
          style: theme.body.copyWith(color: theme.inkSoft),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final img = _image;
        if (img == null) {
          return Center(child: PhotoSpinner(color: theme.accent));
        }

        final available = Size(
          constraints.maxWidth - 32,
          constraints.maxHeight - 32,
        );
        final ratio = widget.shape == CropShape.circle
            ? 1.0
            : (widget.aspectRatio ?? img.width / img.height);
        var w = math.min(available.width, available.height * ratio);
        w = math.max(w, 1);
        final window = Size(w, w / ratio);

        // Deferred a frame because _fit() writes the controller, which cannot
        // happen during build. Also covers rotation and iPad split-view resize.
        if (_window == null ||
            (_window!.width - window.width).abs() > 0.5 ||
            (_window!.height - window.height).abs() > 0.5) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _window = window;
            _fit();
            setState(() {});
          });
          if (_window == null) return const SizedBox.shrink();
        }

        return Center(
          child: SizedBox(
            width: window.width,
            height: window.height,
            child: Stack(
              children: [
                GestureDetector(
                  onDoubleTapDown: _handleDoubleTap,
                  onDoubleTap: () {},
                  child: InteractiveViewer(
                    transformationController: _xform,
                    // REQUIRED. With the default `constrained: true` the child
                    // is handed this widget's own tight constraints, gets
                    // squashed to the window, and pan dies silently.
                    constrained: false,
                    boundaryMargin: EdgeInsets.zero,
                    minScale: 1,
                    maxScale: _maxScale,
                    // Not Clip.none: gestures hit-test against this widget's
                    // own box, so overflow painted outside would be visible but
                    // undraggable.
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _childW,
                      height: _childH,
                      child: RawImage(
                        image: _image,
                        width: _childW,
                        height: _childH,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CropMaskPainter(
                          shape: widget.shape,
                          dim: theme.background.withValues(alpha: 0.55),
                          stroke: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
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

  Widget _bottomBar(AppTheme theme) {
    final ready = _image != null && _window != null && !_saving;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.shape == CropShape.circle
                ? 'drag to move, pinch to zoom'
                : 'drag and pinch to frame',
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CropButton(
                  label: 'CANCEL',
                  onTap: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CropButton(
                  label: _saving ? 'SAVING…' : widget.confirmLabel,
                  filled: true,
                  onTap: ready ? _confirm : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dims everything outside the crop window and outlines it.
///
/// Uses `Path.combine` rather than a `saveLayer` + `BlendMode.clear` punch-out:
/// the overlay sits on top of the image and wants a tint, not a hole, and a
/// saveLayer would allocate an offscreen target on a surface that repaints on
/// every pan frame. The window itself never moves — only the image beneath it —
/// so `shouldRepaint` is false and the path is built exactly once.
class _CropMaskPainter extends CustomPainter {
  const _CropMaskPainter({
    required this.shape,
    required this.dim,
    required this.stroke,
  });

  final CropShape shape;
  final Color dim;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = stroke
      ..isAntiAlias = true;

    if (shape == CropShape.circle) {
      final hole = Path()
        ..addOval(
          Rect.fromCircle(
            center: full.center,
            radius: size.shortestSide / 2,
          ),
        );
      canvas.drawPath(
        Path.combine(PathOperation.difference, Path()..addRect(full), hole),
        Paint()..color = dim,
      );
      canvas.drawPath(hole, line);
      return;
    }

    // Rect mode: no dim (nothing is being discarded outside the window), just
    // rule-of-thirds guides and corner brackets.
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = stroke.withValues(alpha: 0.35);
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), thin);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), thin);
    }
    const arm = 22.0;
    for (final c in [
      (full.topLeft, 1.0, 1.0),
      (full.topRight, -1.0, 1.0),
      (full.bottomLeft, 1.0, -1.0),
      (full.bottomRight, -1.0, -1.0),
    ]) {
      final (corner, sx, sy) = c;
      canvas.drawLine(corner, corner.translate(arm * sx, 0), line);
      canvas.drawLine(corner, corner.translate(0, arm * sy), line);
    }
  }

  @override
  bool shouldRepaint(_CropMaskPainter old) =>
      old.shape != shape || old.dim != dim || old.stroke != stroke;
}

/// CANCEL / USE PHOTO. Bare GestureDetector + FocusableTap — this app renders
/// no ink anywhere.
class _CropButton extends StatefulWidget {
  const _CropButton({required this.label, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  State<_CropButton> createState() => _CropButtonState();
}

class _CropButtonState extends State<_CropButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = widget.onTap != null;
    final fg = widget.filled
        ? theme.accentInk
        : (enabled ? theme.ink : theme.inkMuted);
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.label,
      radius: theme.radiusMd,
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
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.filled
                  ? theme.accent.withValues(alpha: enabled ? 1 : 0.4)
                  : theme.surface,
              border: Border.all(
                color: widget.filled ? Colors.transparent : theme.divider,
              ),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Text(widget.label, style: theme.label.copyWith(color: fg)),
          ),
        ),
      ),
    );
  }
}
