import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/screens/image_crop_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// The crop screen rests on one invariant: **the cover-sized child always
/// covers the crop window**, so the rect the user confirms can never include
/// empty space. Two things make that fragile enough to pin down here:
///
///  * `InteractiveViewer` must be `constrained: false`, otherwise the child is
///    handed the viewer's own tight constraints, gets squashed to the window,
///    and pan dies silently — the screen still renders, it just stops moving.
///  * `constrained: false` aligns the child TOP-LEFT, so the identity matrix
///    opens on the image's corner and every direct write to the controller
///    bypasses InteractiveViewer's own boundary clamping.
///
/// Both failures look like a working screen in a screenshot, hence tests.
void main() {
  /// A solid PNG of the given size for the screen to decode.
  ///
  /// Encoded in pure Dart rather than via PictureRecorder: `Picture.toImage()`
  /// is real raster work that never resolves under flutter_test's fake-async
  /// binding, so calling it from a test body hangs forever — and hangs before
  /// the first test starts, which means even `--timeout` can't rescue it.
  Uint8List makePng(int width, int height) {
    final bitmap = img.Image(width: width, height: height);
    img.fill(bitmap, color: img.ColorRgb8(0x33, 0x66, 0xAA));
    return img.encodePng(bitmap);
  }

  Widget host(Uint8List source, {CropShape shape = CropShape.circle}) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: ImageCropScreen(source: source, shape: shape),
        ),
      );

  /// Bounded instead of pumpAndSettle: the screen re-fits its geometry from a
  /// post-frame callback, and a settle loop would hang rather than fail if that
  /// ever failed to converge.
  Future<void> pumpFrames(WidgetTester tester, {int frames = 6}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Drives the screen until its image is decoded and laid out.
  ///
  /// Image codecs are real background work that the fake-async test zone never
  /// advances, so `runAsync` is required — but the continuations are registered
  /// in the fake zone and only run when `pump` drains it. Neither alone gets
  /// there: the decode chain needs the two interleaved, once per await in it.
  /// (A pump *inside* runAsync deadlocks, so they have to stay separate.)
  Future<void> settle(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(InteractiveViewer).evaluate().isNotEmpty) break;
    }
    await pumpFrames(tester);
  }

  InteractiveViewer viewer(WidgetTester tester) =>
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));

  testWidgets(
    'the viewer is unconstrained, so the child can exceed the window',
    (tester) async {
      final file = makePng(400, 800);
      await settle(tester, host(file));

      // The load-bearing flag. With the default `true` the SizedBox below would
      // be squashed to the window and nothing would pan.
      expect(viewer(tester).constrained, isFalse);
      expect(viewer(tester).minScale, 1);
      expect(viewer(tester).boundaryMargin, EdgeInsets.zero);
    },
  );

  testWidgets('a portrait image opens centered, not on its top-left corner', (
    tester,
  ) async {
    final file = makePng(400, 800);
    await settle(tester, host(file));

    final window = tester.getSize(find.byType(InteractiveViewer));
    final child = tester.getSize(find.byType(RawImage));

    // Circle mode forces a square window, and cover-sizing puts the SHORTER
    // child axis flush against it: a 1:2 portrait is window-wide and 2× tall.
    expect(window.width, closeTo(window.height, 0.5));
    expect(child.width, closeTo(window.width, 0.5));
    expect(child.height, closeTo(window.height * 2, 1.0));

    // Centered means the midpoint of the legal translation interval.
    final t = viewer(tester).transformationController!.value.getTranslation();
    expect(t.x, closeTo((window.width - child.width) / 2, 0.5));
    expect(t.y, closeTo((window.height - child.height) / 2, 0.5));
    // Not the corner — the failure mode `constrained: false` introduces.
    expect(t.y, lessThan(-1));
  });

  testWidgets('the window stays inside the image however hard you drag', (
    tester,
  ) async {
    final file = makePng(400, 800);
    await settle(tester, host(file));

    final window = tester.getSize(find.byType(InteractiveViewer));
    final child = tester.getSize(find.byType(RawImage));
    final ctrl = viewer(tester).transformationController!;

    // Well past either edge, on both axes, in both directions.
    for (final drag in const [
      Offset(0, 4000),
      Offset(0, -8000),
      Offset(4000, 0),
      Offset(-8000, 0),
    ]) {
      await tester.drag(find.byType(InteractiveViewer), drag);
      await pumpFrames(tester);

      final topLeft = ctrl.toScene(Offset.zero);
      final bottomRight = ctrl.toScene(Offset(window.width, window.height));
      expect(topLeft.dx, greaterThanOrEqualTo(-0.5), reason: 'drag $drag');
      expect(topLeft.dy, greaterThanOrEqualTo(-0.5), reason: 'drag $drag');
      expect(
        bottomRight.dx,
        lessThanOrEqualTo(child.width + 0.5),
        reason: 'drag $drag',
      );
      expect(
        bottomRight.dy,
        lessThanOrEqualTo(child.height + 0.5),
        reason: 'drag $drag',
      );
    }
  });

  testWidgets('a landscape image covers the window on the other axis', (
    tester,
  ) async {
    final file = makePng(1200, 400);
    await settle(tester, host(file));

    final window = tester.getSize(find.byType(InteractiveViewer));
    final child = tester.getSize(find.byType(RawImage));

    expect(child.height, closeTo(window.height, 0.5));
    expect(child.width, closeTo(window.width * 3, 1.5));

    final t = viewer(tester).transformationController!.value.getTranslation();
    expect(t.x, closeTo((window.width - child.width) / 2, 0.5));
    expect(t.y, closeTo(0, 0.5));
  });

  testWidgets('rect mode keeps the source aspect ratio and needs no panning', (
    tester,
  ) async {
    final file = makePng(400, 800);
    await settle(tester, host(file, shape: CropShape.rect));

    final window = tester.getSize(find.byType(InteractiveViewer));
    final child = tester.getSize(find.byType(RawImage));

    // Window matches the image, so cover-sizing is a no-op and the whole photo
    // is already framed.
    expect(window.height / window.width, closeTo(2.0, 0.02));
    expect(child.width, closeTo(window.width, 0.5));
    expect(child.height, closeTo(window.height, 0.5));
  });
}
