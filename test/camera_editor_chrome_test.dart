import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/screens/camera_editor_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// The editor's chrome contract.
///
/// Three behaviours that a screenshot cannot tell you about, and that the
/// previous version of this screen got wrong:
///
///  * the drawing tools were always on screen, taking a row of chrome from
///    every user who only wanted to look at their photo and send it;
///  * the draw gesture was mounted unconditionally, so any swipe across the
///    picture left a scribble on it;
///  * RETAKE existed even for a photo chosen from the library, where there is
///    no camera to go back to.
///
/// Nothing here touches the export path. `Picture.toImage()` is real raster
/// work that never resolves under flutter_test's fake-async binding — see the
/// note in image_crop_geometry_test.dart — which also rules out a unit test for
/// `mirrorImageBytes`; that one is verified on a device.
void main() {
  /// A solid PNG for the screen to decode.
  ///
  /// Encoded in pure Dart for the same reason: a PictureRecorder round-trip
  /// would hang the suite before the first test ran.
  Uint8List makePng(int width, int height) {
    final bitmap = img.Image(width: width, height: height);
    img.fill(bitmap, color: img.ColorRgb8(0x44, 0x55, 0x77));
    return img.encodePng(bitmap);
  }

  Widget host(Uint8List source, {bool canRetake = false}) => MaterialApp(
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: CameraEditorScreen(source: source, canRetake: canRetake),
        ),
      );

  /// Drives the screen until its image is decoded and laid out.
  ///
  /// Image codecs are real background work the fake-async zone never advances,
  /// so `runAsync` is required — but their continuations are registered in the
  /// fake zone and only run when `pump` drains it. The two have to be
  /// interleaved, and kept separate: a pump *inside* runAsync deadlocks.
  Future<void> settle(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(RawImage).evaluate().isNotEmpty) break;
    }
    // Bounded rather than pumpAndSettle: the loading spinner schedules frames
    // forever, so a settle loop would hang instead of failing if the decode
    // never arrived.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final photo = makePng(600, 800);

  testWidgets('the drawing tools stay hidden until the pen is picked up',
      (tester) async {
    await settle(tester, host(photo));

    expect(find.byIcon(CupertinoIcons.scribble), findsOneWidget);
    // The tray, and everything only reachable through it.
    expect(find.byIcon(CupertinoIcons.trash), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.scribble));
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.trash), findsOneWidget);

    // And it puts away again.
    await tester.tap(find.byIcon(CupertinoIcons.scribble));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.trash), findsNothing);
  });

  testWidgets('crop is an icon at the top, not a labelled button in the rail',
      (tester) async {
    await settle(tester, host(photo));

    expect(find.byIcon(CupertinoIcons.crop), findsOneWidget);
    expect(find.text('CROP'), findsNothing);
    expect(find.text('USE PHOTO'), findsNothing);
    expect(find.text('SEND'), findsOneWidget);
  });

  testWidgets('retake is offered for a capture and absent for a library photo',
      (tester) async {
    await settle(tester, host(photo, canRetake: true));
    expect(find.byIcon(CupertinoIcons.arrow_counterclockwise), findsOneWidget);

    await settle(tester, host(photo));
    expect(find.byIcon(CupertinoIcons.arrow_counterclockwise), findsNothing);
  });

  testWidgets('a swipe across the photo only draws once the pen is out',
      (tester) async {
    await settle(tester, host(photo));

    // Undo appears only when there is a stroke to undo, which makes it a
    // reliable witness for "did that gesture draw anything".
    expect(find.byIcon(CupertinoIcons.arrow_uturn_left), findsNothing);

    await tester.drag(
      find.byType(RawImage),
      const Offset(50, 40),
      // The draw layer sits on top of the image, which is the point.
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.arrow_uturn_left), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.scribble));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(RawImage),
      const Offset(50, 40),
      // The draw layer sits on top of the image, which is the point.
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.arrow_uturn_left), findsOneWidget);
  });
}
