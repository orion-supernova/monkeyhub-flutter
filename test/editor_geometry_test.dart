import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/editor_geometry.dart';

/// Geometry for the image editor.
///
/// Pure-function tests on purpose. The screen's own failure mode was invisible
/// in a screenshot — strokes were being *recorded* correctly and simply never
/// painted — and the decode/rasterize path it sits on can't run under
/// flutter_test's fake-async binding anyway (see image_crop_geometry_test.dart).
/// So the contract lives here, where it's cheap to pin.
void main() {
  const unit = Rect.fromLTWH(0, 0, 1, 1);

  group('fitContain', () {
    test('a wide image letterboxes top and bottom', () {
      final r = fitContain(box: const Size(400, 400), aspect: 2);
      expect(r.width, closeTo(400, 0.01));
      expect(r.height, closeTo(200, 0.01));
      expect(r.top, closeTo(100, 0.01));
      expect(r.left, closeTo(0, 0.01));
    });

    test('a tall image pillarboxes left and right', () {
      final r = fitContain(box: const Size(400, 400), aspect: 0.5);
      expect(r.width, closeTo(200, 0.01));
      expect(r.height, closeTo(400, 0.01));
      expect(r.left, closeTo(100, 0.01));
      expect(r.top, closeTo(0, 0.01));
    });

    test('a degenerate box yields an empty rect rather than a NaN', () {
      expect(fitContain(box: Size.zero, aspect: 1), Rect.zero);
      expect(fitContain(box: const Size(10, 10), aspect: 0), Rect.zero);
      expect(
        fitContain(box: const Size(10, 10), aspect: double.nan),
        Rect.zero,
      );
    });
  });

  group('stage <-> normalized round trip', () {
    // The bug this whole module exists to prevent: the editor used to read
    // gestures in the outer container's box and paint inside a letterboxed
    // child, so strokes landed offset from the finger by the margin.
    test('is the identity for a letterboxed image', () {
      final stage = fitContain(box: const Size(400, 400), aspect: 2);
      for (final p in const [
        Offset(0, 100),
        Offset(400, 300),
        Offset(200, 200),
        Offset(37, 173),
      ]) {
        final n = stageToNorm(p, viewport: unit, stage: stage);
        final back = normToStage(n, viewport: unit, stage: stage);
        expect(back.dx, closeTo(p.dx, 1e-9), reason: '$p');
        expect(back.dy, closeTo(p.dy, 1e-9), reason: '$p');
      }
    });

    test('is the identity for a pillarboxed image', () {
      final stage = fitContain(box: const Size(400, 400), aspect: 0.5);
      for (final p in const [
        Offset(100, 0),
        Offset(300, 400),
        Offset(211, 89),
      ]) {
        final n = stageToNorm(p, viewport: unit, stage: stage);
        final back = normToStage(n, viewport: unit, stage: stage);
        expect(back.dx, closeTo(p.dx, 1e-9));
        expect(back.dy, closeTo(p.dy, 1e-9));
      }
    });

    test('maps the stage corners to the viewport corners', () {
      final stage = fitContain(box: const Size(400, 400), aspect: 2);
      final tl = stageToNorm(stage.topLeft, viewport: unit, stage: stage);
      final br = stageToNorm(stage.bottomRight, viewport: unit, stage: stage);
      expect(tl.dx, closeTo(0, 1e-9));
      expect(tl.dy, closeTo(0, 1e-9));
      expect(br.dx, closeTo(1, 1e-9));
      expect(br.dy, closeTo(1, 1e-9));
    });

    test('a stroke keeps its place on the image when a crop is applied', () {
      // Normalized storage is what makes this true: the point is anchored to
      // the image, so entering a crop only changes where the image is drawn.
      const point = Offset(0.6, 0.4);
      final full = fitContain(box: const Size(400, 400), aspect: 1);
      const crop = Rect.fromLTRB(0.5, 0.25, 1.0, 0.75);
      final cropped = fitContain(
        box: const Size(400, 400),
        aspect: pixelAspect(crop, const Size(1000, 1000)),
      );

      // Its offset within the crop region is the same fraction either way.
      final inFull = normToStage(point, viewport: unit, stage: full);
      final fractionOfCropFull =
          (inFull.dx -
              normToStage(crop.topLeft, viewport: unit, stage: full).dx) /
          (crop.width * full.width);
      final inCropped = normToStage(point, viewport: crop, stage: cropped);
      final fractionOfCropZoomed =
          (inCropped.dx - cropped.left) / cropped.width;
      expect(fractionOfCropZoomed, closeTo(fractionOfCropFull, 1e-9));
    });
  });

  group('pixelAspect', () {
    test('accounts for the image being non-square', () {
      // Normalized axes are not isotropic: half the width of a 4000x2000 image
      // is 2000 px, half the height is 1000 px.
      const half = Rect.fromLTWH(0, 0, 0.5, 0.5);
      expect(pixelAspect(half, const Size(4000, 2000)), closeTo(2, 1e-9));
      expect(pixelAspect(unit, const Size(4000, 2000)), closeTo(2, 1e-9));
    });
  });

  group('centeredCrop', () {
    test('a square crop of a wide image is height-limited and centred', () {
      final r = centeredCrop(aspect: 1, imageSize: const Size(4000, 2000));
      expect(r.height, closeTo(1.0, 1e-9));
      expect(r.width, closeTo(0.5, 1e-9));
      expect(r.center.dx, closeTo(0.5, 1e-9));
      expect(pixelAspect(r, const Size(4000, 2000)), closeTo(1, 1e-9));
    });

    test('a square crop of a tall image is width-limited', () {
      final r = centeredCrop(aspect: 1, imageSize: const Size(2000, 4000));
      expect(r.width, closeTo(1.0, 1e-9));
      expect(r.height, closeTo(0.5, 1e-9));
      expect(pixelAspect(r, const Size(2000, 4000)), closeTo(1, 1e-9));
    });
  });

  group('resizeCrop — free', () {
    const image = Size(1000, 1000);

    test('a corner drag moves only the edges it touches', () {
      final r = resizeCrop(
        crop: unit,
        handle: CropHandle.topLeft,
        delta: const Offset(0.2, 0.1),
        imageSize: image,
      );
      expect(r.left, closeTo(0.2, 1e-9));
      expect(r.top, closeTo(0.1, 1e-9));
      expect(r.right, closeTo(1.0, 1e-9));
      expect(r.bottom, closeTo(1.0, 1e-9));
    });

    test('an edge drag moves only that edge', () {
      final r = resizeCrop(
        crop: unit,
        handle: CropHandle.right,
        delta: const Offset(-0.3, 0.9),
        imageSize: image,
      );
      expect(r.right, closeTo(0.7, 1e-9));
      expect(r.top, closeTo(0, 1e-9));
      expect(r.bottom, closeTo(1, 1e-9));
      expect(r.left, closeTo(0, 1e-9));
    });

    test('cannot be dragged outside the image, however hard', () {
      for (final handle in CropHandle.values) {
        for (final delta in const [
          Offset(0, 40),
          Offset(0, -40),
          Offset(40, 0),
          Offset(-40, 0),
          Offset(-40, -40),
        ]) {
          final r = resizeCrop(
            crop: const Rect.fromLTRB(0.2, 0.2, 0.8, 0.8),
            handle: handle,
            delta: delta,
            imageSize: image,
          );
          final why = '$handle $delta';
          expect(r.left, greaterThanOrEqualTo(-1e-9), reason: why);
          expect(r.top, greaterThanOrEqualTo(-1e-9), reason: why);
          expect(r.right, lessThanOrEqualTo(1 + 1e-9), reason: why);
          expect(r.bottom, lessThanOrEqualTo(1 + 1e-9), reason: why);
        }
      }
    });

    test('never collapses below the minimum on either axis', () {
      for (final handle in CropHandle.values) {
        if (handle == CropHandle.move) continue;
        final r = resizeCrop(
          crop: const Rect.fromLTRB(0.2, 0.2, 0.8, 0.8),
          handle: handle,
          delta: const Offset(9, 9),
          imageSize: image,
          minFraction: 0.1,
        );
        expect(r.width, greaterThanOrEqualTo(0.1 - 1e-9), reason: '$handle');
        expect(r.height, greaterThanOrEqualTo(0.1 - 1e-9), reason: '$handle');
      }
    });

    test('move translates without resizing, and stops at the edge', () {
      const crop = Rect.fromLTRB(0.2, 0.2, 0.6, 0.6);
      final moved = resizeCrop(
        crop: crop,
        handle: CropHandle.move,
        delta: const Offset(0.1, -0.1),
        imageSize: image,
      );
      expect(moved.width, closeTo(crop.width, 1e-9));
      expect(moved.height, closeTo(crop.height, 1e-9));
      expect(moved.left, closeTo(0.3, 1e-9));
      expect(moved.top, closeTo(0.1, 1e-9));

      final pinned = resizeCrop(
        crop: crop,
        handle: CropHandle.move,
        delta: const Offset(5, 5),
        imageSize: image,
      );
      expect(pinned.width, closeTo(crop.width, 1e-9));
      expect(pinned.right, closeTo(1.0, 1e-9));
      expect(pinned.bottom, closeTo(1.0, 1e-9));
    });
  });

  group('resizeCrop — locked aspect', () {
    test('holds the ratio through a corner drag on a non-square image', () {
      const image = Size(4000, 2000);
      var crop = centeredCrop(aspect: 1, imageSize: image);
      for (final delta in const [
        Offset(0.05, 0),
        Offset(0, 0.05),
        Offset(-0.12, 0.03),
      ]) {
        crop = resizeCrop(
          crop: crop,
          handle: CropHandle.bottomRight,
          delta: delta,
          imageSize: image,
          aspect: 1,
        );
        expect(pixelAspect(crop, image), closeTo(1, 1e-6), reason: '$delta');
      }
    });

    test('holds the ratio for every handle and stays inside the image', () {
      const image = Size(3000, 4000);
      const aspect = 16 / 9;
      for (final handle in CropHandle.values) {
        if (handle == CropHandle.move) continue;
        final r = resizeCrop(
          crop: centeredCrop(aspect: aspect, imageSize: image),
          handle: handle,
          delta: const Offset(0.25, 0.25),
          imageSize: image,
          aspect: aspect,
        );
        expect(pixelAspect(r, image), closeTo(aspect, 1e-6), reason: '$handle');
        expect(r.left, greaterThanOrEqualTo(-1e-9), reason: '$handle');
        expect(r.top, greaterThanOrEqualTo(-1e-9), reason: '$handle');
        expect(r.right, lessThanOrEqualTo(1 + 1e-9), reason: '$handle');
        expect(r.bottom, lessThanOrEqualTo(1 + 1e-9), reason: '$handle');
      }
    });
  });

  group('rotation', () {
    test('carries a point around four turns back to where it started', () {
      const p = Offset(0.3, 0.8);
      var q = p;
      for (var i = 0; i < 4; i++) {
        q = rotateNormCW(q);
      }
      expect(q.dx, closeTo(p.dx, 1e-9));
      expect(q.dy, closeTo(p.dy, 1e-9));
    });

    test('sends the top-left corner to the top-right', () {
      final r = rotateNormCW(Offset.zero);
      expect(r.dx, closeTo(1, 1e-9));
      expect(r.dy, closeTo(0, 1e-9));
    });

    test('a rect stays normalized and swaps its extents', () {
      const r = Rect.fromLTRB(0.1, 0.2, 0.4, 0.9);
      final rotated = rotateRectCW(r);
      expect(rotated.width, closeTo(r.height, 1e-9));
      expect(rotated.height, closeTo(r.width, 1e-9));
      expect(rotated.left, greaterThanOrEqualTo(-1e-9));
      expect(rotated.bottom, lessThanOrEqualTo(1 + 1e-9));
    });
  });

  group('strokePath', () {
    test('a single point yields nothing to stroke — the caller draws a dot', () {
      // Both the old painter and the old exporter skipped anything under two
      // points, so a tap drew nothing anywhere. The dot is now the caller's job,
      // and this documents why the path is empty.
      expect(strokePath(const [Offset(1, 1)]).computeMetrics().isEmpty, isTrue);
      expect(strokePath(const []).computeMetrics().isEmpty, isTrue);
    });

    test('two points make a straight segment of the right length', () {
      final metrics = strokePath(const [
        Offset(0, 0),
        Offset(3, 4),
      ]).computeMetrics().toList();
      expect(metrics, hasLength(1));
      expect(metrics.first.length, closeTo(5, 1e-6));
    });

    test('a many-point stroke starts and ends on the samples it was given', () {
      const pts = [Offset(0, 0), Offset(10, 20), Offset(30, 5), Offset(50, 40)];
      final bounds = strokePath(pts).getBounds();
      // Quadratics through midpoints stay within the control polygon, so the
      // curve can never wander outside the samples' own bounding box.
      expect(bounds.left, greaterThanOrEqualTo(-1e-6));
      expect(bounds.top, greaterThanOrEqualTo(-1e-6));
      expect(bounds.right, lessThanOrEqualTo(50 + 1e-6));
      expect(bounds.bottom, lessThanOrEqualTo(40 + 1e-6));
    });
  });
}
