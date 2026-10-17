import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [child] blurred, as a still.
///
/// An [ImageFiltered] blur is redone on every frame its layer is composited,
/// and under a sealed spoiler that is every frame: the dust over it never
/// stops moving, and the raster backend does not keep the filtered result.
/// Over a chat of sealed pictures that was the frame's dearest work, for a
/// picture that is not changing at all.
///
/// This blurs once instead. It is its own repaint boundary, so it paints
/// only when something under it does (the picture arriving, a decode
/// finishing, a resize) or its own blur changes: then it paints [child] off
/// to the side, captures it at half the screen's pixel ratio (the blur
/// leaves nothing finer to keep), blurs that capture once, and from then on
/// draws the blurred still, scaled up. With [enabled] false it is [child]
/// as it is.
///
/// For a child that repaints through its own boundary (a video's texture),
/// the still would not see the change; give such a child a still frame.
class StillBlur extends SingleChildRenderObjectWidget {
  const StillBlur({
    super.key,
    required this.sigma,
    this.enabled = true,
    this.tileMode = TileMode.mirror,
    required Widget super.child,
  });

  /// The blur's sigma, in logical pixels, as [ImageFilter.blur] takes it.
  final double sigma;
  final bool enabled;
  final TileMode tileMode;

  @override
  RenderStillBlur createRenderObject(BuildContext context) => RenderStillBlur(
        sigma: sigma,
        enabled: enabled,
        tileMode: tileMode,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderStillBlur renderObject) {
    renderObject
      ..sigma = sigma
      ..enabled = enabled
      ..tileMode = tileMode
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

class RenderStillBlur extends RenderProxyBox {
  RenderStillBlur({
    required double sigma,
    required bool enabled,
    required TileMode tileMode,
    required double devicePixelRatio,
  })  : _sigma = sigma,
        _enabled = enabled,
        _tileMode = tileMode,
        _dpr = devicePixelRatio;

  double _sigma;
  set sigma(double v) {
    if (v == _sigma) return;
    _sigma = v;
    markNeedsPaint();
  }

  bool _enabled;
  set enabled(bool v) {
    if (v == _enabled) return;
    _enabled = v;
    markNeedsPaint();
  }

  TileMode _tileMode;
  set tileMode(TileMode v) {
    if (v == _tileMode) return;
    _tileMode = v;
    markNeedsPaint();
  }

  double _dpr;
  set devicePixelRatio(double v) {
    if (v == _dpr) return;
    _dpr = v;
    markNeedsPaint();
  }

  ui.Image? _still;

  /// The still being drawn. For tests.
  @visibleForTesting
  ui.Image? get debugStill => _still;

  static final Paint _drawPaint = Paint()..filterQuality = FilterQuality.low;

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (!_enabled || _sigma <= 0 || size.isEmpty) {
      _drop();
      context.paintChild(child, offset);
      return;
    }
    // Painted at all means something under us changed: blur it anew.
    final still = _capture(child);
    if (still == null) {
      context.paintChild(child, offset);
      return;
    }
    context.canvas.drawImageRect(
      still,
      Rect.fromLTWH(0, 0, still.width.toDouble(), still.height.toDouble()),
      offset & size,
      _drawPaint,
    );
  }

  ui.Image? _capture(RenderBox child) {
    final ratio = (_dpr * 0.5).clamp(0.5, 1.5);
    final bounds = Offset.zero & size;
    final layer = OffsetLayer();
    final capture = _CaptureContext(layer, bounds);
    capture.paintChild(child, Offset.zero);
    capture.finish();
    final raw = layer.toImageSync(bounds, pixelRatio: ratio);
    layer.dispose();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImage(
      raw,
      Offset.zero,
      Paint()
        ..filterQuality = FilterQuality.low
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: _sigma * ratio,
          sigmaY: _sigma * ratio,
          tileMode: _tileMode,
        ),
    );
    final picture = recorder.endRecording();
    final still = picture.toImageSync(raw.width, raw.height);
    picture.dispose();
    raw.dispose();
    _still?.dispose();
    _still = still;
    return still;
  }

  void _drop() {
    _still?.dispose();
    _still = null;
  }

  @override
  void detach() {
    _drop();
    super.detach();
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }
}

/// A painting context of our own, for painting the child off to the side.
class _CaptureContext extends PaintingContext {
  _CaptureContext(super.containerLayer, super.estimatedBounds);

  void finish() => stopRecordingIfNeeded();
}
