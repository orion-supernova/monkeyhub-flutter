import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../ui/foundation/ui_kit.dart';

/// The page behind a modal overlay, captured once at press time and blurred
/// once.
///
/// A live `BackdropFilter` that fades in through an opacity (or whose sigma is
/// animated) is re-rendered offscreen every frame, and on the first frames
/// Impeller often has not produced it at all — so the blur arrived late and
/// stuttered in, behind content that was already up. A still image fades for
/// the cost of a texture draw. Shared by every "lift something out of the page
/// and blur the rest" overlay (message menu, chat-row menu, thread sheet).
///
/// Taken from the outermost [RenderRepaintBoundary] above the anchor — the
/// route's own, which every page has — at a quarter of device resolution: the
/// blur erases the detail that the downsampling would have cost, and a
/// quarter-size image blurs sixteen times cheaper.
class BlurSnapshot {
  BlurSnapshot(this.image, this.rect);
  final ui.Image image;

  /// Where the captured page sits, in window coordinates.
  final Rect rect;

  static const _scale = 0.25;

  /// Null when it could not be captured — and always null in a kit that does
  /// not blur (Lite), where [BlurScrim] draws a heavier plain dim instead.
  static BlurSnapshot? capture(BuildContext anchor, {double sigma = 22}) {
    try {
      if (!UiKit.of(anchor).blurs) return null;
      RenderRepaintBoundary? outer;
      RenderObject? node = anchor.findRenderObject();
      while (node != null) {
        if (node is RenderRepaintBoundary && node.attached) outer = node;
        node = node.parent;
      }
      final boundary = outer;
      if (boundary == null || !boundary.hasSize) return null;
      // Not `debugNeedsPaint` — it is debug-only and throws in release, which
      // the catch below would turn into "always fall back". toImageSync
      // asserts the same thing itself in debug.
      final raw = boundary.toImageSync(pixelRatio: _scale);
      final w = raw.width, h = raw.height;
      final recorder = ui.PictureRecorder();
      // Blur radius scales with the image: sigma 22 at full size is 5.5 here.
      Canvas(recorder).drawImage(
        raw,
        Offset.zero,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma * _scale,
            sigmaY: sigma * _scale,
            tileMode: TileMode.clamp,
          ),
      );
      final blurred = recorder.endRecording().toImageSync(w, h);
      raw.dispose();
      final origin = boundary.localToGlobal(Offset.zero);
      return BlurSnapshot(blurred, origin & boundary.size);
    } catch (_) {
      return null;
    }
  }
}

/// Blurs and dims everything behind an overlay: the [BlurSnapshot] fades in
/// (the blur itself is never animated), tinted by [dim]. Tap anywhere to
/// [onTap].
class BlurScrim extends StatelessWidget {
  const BlurScrim({
    super.key,
    required this.t,
    required this.backdrop,
    required this.onTap,
    this.dim = const Color(0x52000000),
    this.sigma = 22,
  });

  /// Drives the fade. Clamped: a springy entrance curve overshoots past 1,
  /// which an opacity cannot take.
  final Animation<double> t;
  final BlurSnapshot? backdrop;
  final VoidCallback onTap;

  /// The dim over the blur.
  final Color dim;

  /// Strength of the live fallback blur when no snapshot could be taken.
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final snap = backdrop;
    final blurs = UiKit.of(context).blurs;
    // No blur in Lite: the dim alone, a touch heavier so the page behind
    // still recedes.
    final dimColor = blurs
        ? dim
        : dim.withValues(alpha: (dim.a + 0.2).clamp(0.0, 0.8));
    final tint = AnimatedBuilder(
      animation: t,
      builder: (_, child) =>
          Opacity(opacity: t.value.clamp(0.0, 1.0), child: child),
      child: Stack(
        children: [
          if (snap != null)
            Positioned.fromRect(
              rect: snap.rect,
              child: RawImage(
                image: snap.image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.low,
              ),
            ),
          Positioned.fill(child: ColoredBox(color: dimColor)),
        ],
      ),
    );
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: snap != null || !blurs
            ? tint
            // No snapshot (a page that has not painted yet): the live blur,
            // present at full strength from the first frame rather than faded
            // — fading it is exactly what made it late.
            : Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Positioned.fill(child: tint),
                ],
              ),
      ),
    );
  }
}
