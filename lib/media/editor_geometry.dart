import 'dart:math' as math;
import 'dart:ui';

/// Pure geometry for the image editor.
///
/// Kept out of the widget so it can be tested without a decoded image or a
/// pumped frame — `Picture.toImage()` never resolves under `flutter_test`'s
/// fake-async binding, so anything reachable only through the screen is
/// effectively untestable. It is also where the editor's old coordinate bug
/// lived: gestures were measured in one box and painted in another, so strokes
/// landed offset from the finger and the exported file disagreed with the
/// preview. One mapping, used by gestures, painter and export alike, makes that
/// class of mistake unrepresentable.
///
/// **Coordinate spaces.** Strokes and the crop rect are stored *normalized* —
/// each component a 0..1 fraction of the source image. That makes them
/// independent of layout, of the display downscale, and of the crop itself, so
/// none of those can silently relocate a stroke.

/// Which part of the crop rect a drag is manipulating.
enum CropHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,

  /// The whole rect, translated.
  move;

  bool get touchesLeft =>
      this == topLeft || this == left || this == bottomLeft;
  bool get touchesRight =>
      this == topRight || this == right || this == bottomRight;
  bool get touchesTop => this == topLeft || this == top || this == topRight;
  bool get touchesBottom =>
      this == bottomLeft || this == bottom || this == bottomRight;
  bool get isCorner =>
      this == topLeft || this == topRight || this == bottomLeft || this == bottomRight;
}

/// The centred rect of the given [aspect] (width / height) that fits inside
/// [box] — `BoxFit.contain` semantics, as a rect rather than a painted result.
Rect fitContain({required Size box, required double aspect}) {
  if (box.width <= 0 || box.height <= 0 || aspect <= 0 || !aspect.isFinite) {
    return Rect.zero;
  }
  if (aspect > box.width / box.height) {
    // Wider than the box: full width, letterboxed top and bottom.
    final h = box.width / aspect;
    return Rect.fromLTWH(0, (box.height - h) / 2, box.width, h);
  }
  final w = box.height * aspect;
  return Rect.fromLTWH((box.width - w) / 2, 0, w, box.height);
}

/// Maps a normalized image point to where it is painted on screen.
///
/// [viewport] is the normalized region currently displayed (the unit rect while
/// cropping, the crop rect otherwise); [stage] is the on-screen rect that region
/// occupies. Inverse of [stageToNorm].
Offset normToStage(Offset n, {required Rect viewport, required Rect stage}) {
  final u = (n.dx - viewport.left) / viewport.width;
  final v = (n.dy - viewport.top) / viewport.height;
  return Offset(stage.left + u * stage.width, stage.top + v * stage.height);
}

/// Maps an on-screen point back to normalized image coordinates.
/// Inverse of [normToStage].
Offset stageToNorm(Offset p, {required Rect viewport, required Rect stage}) {
  final u = (p.dx - stage.left) / stage.width;
  final v = (p.dy - stage.top) / stage.height;
  return Offset(
    viewport.left + u * viewport.width,
    viewport.top + v * viewport.height,
  );
}

/// Pixel aspect (width / height) of the normalized region [r] within an image
/// of [imageSize] pixels.
///
/// Normalized axes are *not* isotropic — a 0.5-wide region of a 4000×3000 photo
/// is 2000 px, a 0.5-tall one is 1500 px — so every aspect calculation has to
/// come back through the pixel dimensions.
double pixelAspect(Rect r, Size imageSize) =>
    (r.width * imageSize.width) / (r.height * imageSize.height);

/// The largest centred rect of pixel aspect [aspect] inside the unit rect, for
/// an image of [imageSize].
Rect centeredCrop({required double aspect, required Size imageSize}) {
  // nw / nh for the requested pixel aspect.
  final ratioN = aspect * imageSize.height / imageSize.width;
  var nw = 1.0;
  var nh = nw / ratioN;
  if (nh > 1.0) {
    nh = 1.0;
    nw = nh * ratioN;
  }
  return Rect.fromLTWH((1 - nw) / 2, (1 - nh) / 2, nw, nh);
}

/// Applies a handle drag to the normalized crop rect.
///
/// [delta] is in normalized units. [aspect] locks the result to a pixel
/// width/height ratio; null leaves it free. The result is always inside the unit
/// rect and at least [minFraction] on each axis, so the crop can never select
/// area the image doesn't have — the same coverage guarantee the avatar cropper
/// gets from cover-sizing, enforced arithmetically instead.
Rect resizeCrop({
  required Rect crop,
  required CropHandle handle,
  required Offset delta,
  required Size imageSize,
  double minFraction = 0.08,
  double? aspect,
}) {
  const unit = Rect.fromLTWH(0, 0, 1, 1);

  if (handle == CropHandle.move) {
    final dx = delta.dx.clamp(-crop.left, 1 - crop.right);
    final dy = delta.dy.clamp(-crop.top, 1 - crop.bottom);
    return crop.translate(dx, dy);
  }

  var l = crop.left;
  var t = crop.top;
  var r = crop.right;
  var b = crop.bottom;
  if (handle.touchesLeft) l += delta.dx;
  if (handle.touchesRight) r += delta.dx;
  if (handle.touchesTop) t += delta.dy;
  if (handle.touchesBottom) b += delta.dy;

  // Clamp to the image, then enforce the minimum by pushing back the edge the
  // drag is NOT holding, so the anchored side stays where the user put it.
  l = l.clamp(0.0, 1.0);
  r = r.clamp(0.0, 1.0);
  t = t.clamp(0.0, 1.0);
  b = b.clamp(0.0, 1.0);
  if (r - l < minFraction) {
    if (handle.touchesLeft) {
      l = math.max(0.0, r - minFraction);
      r = math.max(r, l + minFraction);
    } else {
      r = math.min(1.0, l + minFraction);
      l = math.min(l, r - minFraction);
    }
  }
  if (b - t < minFraction) {
    if (handle.touchesTop) {
      t = math.max(0.0, b - minFraction);
      b = math.max(b, t + minFraction);
    } else {
      b = math.min(1.0, t + minFraction);
      t = math.min(t, b - minFraction);
    }
  }

  final free = Rect.fromLTRB(l, t, r, b);
  if (aspect == null) return free;
  return _lockAspect(
    free,
    original: crop,
    handle: handle,
    aspect: aspect,
    imageSize: imageSize,
    minFraction: minFraction,
    bounds: unit,
  );
}

/// Rewrites [rect] to the requested pixel [aspect], anchored so the edge the
/// user is dragging is the one that moves.
Rect _lockAspect(
  Rect rect, {
  required Rect original,
  required CropHandle handle,
  required double aspect,
  required Size imageSize,
  required double minFraction,
  required Rect bounds,
}) {
  final ratioN = aspect * imageSize.height / imageSize.width; // nw / nh

  double w;
  double h;
  if (handle == CropHandle.top || handle == CropHandle.bottom) {
    // Vertical edge drag: height leads, width follows.
    h = rect.height;
    w = h * ratioN;
  } else {
    // Corners and horizontal edges: width leads.
    w = rect.width;
    h = w / ratioN;
  }

  // Shrink to fit the image if the derived axis overflowed.
  final maxW = bounds.width;
  final maxH = bounds.height;
  if (w > maxW) {
    w = maxW;
    h = w / ratioN;
  }
  if (h > maxH) {
    h = maxH;
    w = h * ratioN;
  }
  w = math.max(w, minFraction);
  h = math.max(h, minFraction);

  // Anchor: the corner/edge opposite the one being dragged stays put; a free
  // axis stays centred on where it already was.
  double left;
  if (handle.touchesLeft) {
    left = rect.right - w;
  } else if (handle.touchesRight) {
    left = rect.left;
  } else {
    left = original.center.dx - w / 2;
  }
  double top;
  if (handle.touchesTop) {
    top = rect.bottom - h;
  } else if (handle.touchesBottom) {
    top = rect.top;
  } else {
    top = original.center.dy - h / 2;
  }

  // Slide (don't shrink) back inside the image, so a locked ratio survives a
  // drag that runs off an edge instead of collapsing.
  left = left.clamp(bounds.left, math.max(bounds.left, bounds.right - w));
  top = top.clamp(bounds.top, math.max(bounds.top, bounds.bottom - h));
  return Rect.fromLTWH(left, top, w, h);
}

/// Rotates a normalized point 90° clockwise, to follow the image when it is
/// re-rasterized by a rotate. Top-left becomes top-right.
Offset rotateNormCW(Offset n) => Offset(1 - n.dy, n.dx);

/// Rotates a normalized rect 90° clockwise.
Rect rotateRectCW(Rect r) {
  final a = rotateNormCW(r.topLeft);
  final b = rotateNormCW(r.bottomRight);
  return Rect.fromLTRB(
    math.min(a.dx, b.dx),
    math.min(a.dy, b.dy),
    math.max(a.dx, b.dx),
    math.max(a.dy, b.dy),
  );
}

/// A smooth path through [points].
///
/// Quadratic segments anchored on the midpoints between successive samples,
/// which is the cheap standard for freehand: every sample becomes a control
/// point, so the curve passes smoothly *near* the touch samples rather than
/// kinking at each one. The old renderer used raw `lineTo` and drew visibly
/// faceted strokes.
///
/// Returns an empty path for a single point — a lone tap is a dot and the caller
/// draws it as a circle, since a zero-length path with a round cap paints
/// nothing.
Path strokePath(List<Offset> points) {
  final path = Path();
  if (points.length < 2) return path;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 2) {
    path.lineTo(points[1].dx, points[1].dy);
    return path;
  }
  for (var i = 1; i < points.length - 1; i++) {
    final mid = Offset(
      (points[i].dx + points[i + 1].dx) / 2,
      (points[i].dy + points[i + 1].dy) / 2,
    );
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}
