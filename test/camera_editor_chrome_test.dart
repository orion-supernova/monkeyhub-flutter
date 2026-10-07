import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/screens/camera_editor_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

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
/// note in image_crop_geometry_test.dart. The way around that is
/// `tester.runAsync`, which image_mirror_test.dart uses to pin the selfie flip.
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

  Widget host(
    Uint8List source, {
    bool canRetake = false,
    bool allowDrawing = true,
    bool allowViewOnce = true,
    String? confirmLabel,
    EditorDraft? draft,
    bool allowCaptions = false,
    int maxPhotos = 1,
    bool galleryOverCamera = false,
    bool allowSchedule = false,
    String? scheduleRefusal,
  }) => ThemeScope(
    // Above the app, as in the real one, so a sheet the editor pushes (the
    // schedule sheet) can see the theme too.
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CameraEditorScreen(
        source: source,
        draft: draft,
        allowCaptions: allowCaptions,
        maxPhotos: maxPhotos,
        galleryOverCamera: galleryOverCamera,
        allowSchedule: allowSchedule,
        scheduleRefusal: scheduleRefusal,
        canRetake: canRetake,
        allowDrawing: allowDrawing,
        allowViewOnce: allowViewOnce,
        confirmLabel: confirmLabel,
      ),
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
      if (find.byKey(cameraEditorStageImageKey).evaluate().isNotEmpty) break;
    }
    // Bounded rather than pumpAndSettle: the loading spinner schedules frames
    // forever, so a settle loop would hang instead of failing if the decode
    // never arrived.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final photo = makePng(600, 800);

  testWidgets('the drawing tools stay hidden until the pen is picked up', (
    tester,
  ) async {
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

  // The feed shares this screen so its crop behaves like chat's — a rect you
  // drag by the edges, not a fixed window with the picture sliding underneath.
  // What it must NOT inherit is the rest of chat's vocabulary: a scribble on a
  // board post means nothing, and "view once" is meaningless on something
  // already public to your friends for a day.
  testWidgets('feed mode offers crop and rotate and nothing else', (
    tester,
  ) async {
    await settle(
      tester,
      host(
        photo,
        allowDrawing: false,
        allowViewOnce: false,
        confirmLabel: 'USE PHOTO',
      ),
    );

    expect(find.byIcon(CupertinoIcons.scribble), findsNothing);
    expect(find.bySemanticsLabel('Send'), findsNothing);
    expect(find.text('Use photo'), findsOneWidget);

    // Still a cropper, which is the entire reason the feed came here.
    expect(find.byIcon(CupertinoIcons.crop), findsOneWidget);
  });

  testWidgets('feed mode unmounts the draw gesture, not just its button', (
    tester,
  ) async {
    await settle(tester, host(photo, allowDrawing: false));

    await tester.drag(
      find.byKey(cameraEditorStageImageKey),
      const Offset(50, 40),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // Undo only appears when there is a stroke to undo. Without the pen button
    // there is no way to arm the pen, so a swipe must stay inert — a hidden
    // button over a live gesture would still scribble on the photo.
    expect(find.byIcon(CupertinoIcons.arrow_uturn_left), findsNothing);
  });

  testWidgets('crop is an icon at the top, not a labelled button in the rail', (
    tester,
  ) async {
    await settle(tester, host(photo));

    expect(find.byIcon(CupertinoIcons.crop), findsOneWidget);
    expect(find.text('CROP'), findsNothing);
    expect(find.text('Use photo'), findsNothing);
    // The round arrow, not a labelled pill.
    expect(find.bySemanticsLabel('Send'), findsOneWidget);
  });

  testWidgets(
    'retake is offered for a capture and absent for a library photo',
    (tester) async {
      await settle(tester, host(photo, canRetake: true));
      expect(
        find.byIcon(CupertinoIcons.camera),
        findsOneWidget,
      );

      await settle(tester, host(photo));
      expect(find.byIcon(CupertinoIcons.camera), findsNothing);
    },
  );

  testWidgets('a swipe across the photo only draws once the pen is out', (
    tester,
  ) async {
    await settle(tester, host(photo));

    // Undo appears only when there is a stroke to undo, which makes it a
    // reliable witness for "did that gesture draw anything".
    expect(find.byIcon(CupertinoIcons.arrow_uturn_left), findsNothing);

    await tester.drag(
      find.byKey(cameraEditorStageImageKey),
      const Offset(50, 40),
      // The draw layer sits on top of the image, which is the point.
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.arrow_uturn_left), findsNothing);

    await tester.tap(find.byIcon(CupertinoIcons.scribble));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(cameraEditorStageImageKey),
      const Offset(50, 40),
      // The draw layer sits on top of the image, which is the point.
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.arrow_uturn_left), findsOneWidget);
  });

  testWidgets('undo and redo keep their places, so repeated undo stays undo', (
    tester,
  ) async {
    await settle(tester, host(photo));
    await tester.tap(find.byIcon(CupertinoIcons.scribble));
    await tester.pumpAndSettle();

    final undo = find.byIcon(CupertinoIcons.arrow_uturn_left);
    final redo = find.byIcon(CupertinoIcons.arrow_uturn_right);
    // Out with the pen: both slots, before anything is drawn.
    expect(undo, findsOneWidget);
    expect(redo, findsOneWidget);
    final undoAt = tester.getCenter(undo);
    final redoAt = tester.getCenter(redo);
    expect(undoAt.dx, lessThan(redoAt.dx));

    await tester.drag(
      find.byKey(cameraEditorStageImageKey),
      const Offset(50, 40),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    // Undo the only stroke, then keep tapping where undo was. It must stay
    // undo — the old layout slid redo into this spot and redrew the stroke.
    await tester.tapAt(undoAt);
    await tester.pumpAndSettle();
    expect(tester.getCenter(undo), undoAt);
    expect(tester.getCenter(redo), redoAt);
    await tester.tapAt(undoAt);
    await tester.pumpAndSettle();
    await tester.tapAt(undoAt);
    await tester.pumpAndSettle();

    // Nothing drawn: redo is the only way back, and it is where it was.
    await tester.tapAt(redoAt);
    await tester.pumpAndSettle();
    await tester.tapAt(undoAt);
    await tester.pumpAndSettle();
    expect(tester.getCenter(undo), undoAt);
  });

  testWidgets('holding send opens the schedule sheet', (tester) async {
    await settle(tester, host(photo, allowSchedule: true));
    await tester.longPress(find.bySemanticsLabel('Send'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Schedule message'), findsOneWidget);
  });

  testWidgets('a room that refuses scheduling says why instead', (
    tester,
  ) async {
    await settle(
      tester,
      host(photo, allowSchedule: true, scheduleRefusal: 'Not in this room'),
    );
    await tester.longPress(find.bySemanticsLabel('Send'));
    await tester.pump();
    expect(find.text('Schedule message'), findsNothing);
    expect(find.text('Not in this room'), findsOneWidget);
    // Let the toast run out so no timer outlives the test.
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('without scheduling, holding send does nothing extra', (
    tester,
  ) async {
    await settle(tester, host(photo));
    await tester.longPress(find.bySemanticsLabel('Send'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Schedule message'), findsNothing);
  });

  testWidgets('disposing the draft while the composer animates away is safe', (
    tester,
  ) async {
    // The caller's `finally { draft.dispose(); }` runs the moment the route's
    // future completes — while the route is still painting its exit. That
    // used to empty the draft under it: RangeError on `_page`.
    final draft = EditorDraft()..add(photo);
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                try {
                  await CameraEditorScreen.open(
                    context,
                    draft: draft,
                    allowCaptions: true,
                    maxPhotos: 10,
                  );
                } finally {
                  draft.dispose();
                }
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    // Typing a caption: leaving then takes the keyboard focus away, and the
    // focus change rebuilds the screen mid-exit — the frame that crashed.
    await tester.tap(find.byKey(cameraEditorCaptionKey));
    await tester.pump();
    await tester.tap(find.byIcon(CupertinoIcons.xmark));
    // Frame by frame through the exit, where the crash was.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(draft.isEmpty, isTrue);
  });

  group('the multi-photo composer', () {
    EditorDraft three() => EditorDraft()
      ..add(makePng(600, 800))
      ..add(makePng(800, 600))
      ..add(makePng(500, 500))
      ..index = 0;

    String captionText(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(cameraEditorCaptionKey))
        .controller!
        .text;

    testWidgets('captions follow the photo on screen', (tester) async {
      final draft = three();
      addTearDown(draft.dispose);
      await settle(
        tester,
        host(photo, draft: draft, allowCaptions: true, maxPhotos: 10),
      );
      // No "3 photos" title: the rail is the count.
      expect(find.text('3 photos'), findsNothing);
      expect(find.bySemanticsLabel('Item 3 of 3'), findsOneWidget);

      await tester.enterText(find.byKey(cameraEditorCaptionKey), 'first');
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Item 2 of 3'));
      await tester.pump();
      expect(captionText(tester), isEmpty);

      await tester.enterText(find.byKey(cameraEditorCaptionKey), 'second');
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Item 1 of 3'));
      await tester.pump();
      expect(captionText(tester), 'first');
    });

    testWidgets('a sideways swipe moves between photos', (tester) async {
      final draft = three();
      addTearDown(draft.dispose);
      await settle(
        tester,
        host(photo, draft: draft, allowCaptions: true, maxPhotos: 10),
      );
      await tester.enterText(find.byKey(cameraEditorCaptionKey), 'first');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      final middle = tester.getCenter(find.byType(Scaffold));
      await tester.flingFrom(middle, const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(draft.index, 1);
      expect(captionText(tester), isEmpty);

      await tester.flingFrom(middle, const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(draft.index, 0);
      expect(captionText(tester), 'first');

      // Nothing before the first photo: the swipe gives, then settles back.
      await tester.flingFrom(middle, const Offset(300, 0), 1500);
      await tester.pumpAndSettle();
      expect(draft.index, 0);
    });

    testWidgets('view once turns captions off and says so', (tester) async {
      final draft = three();
      addTearDown(draft.dispose);
      await settle(
        tester,
        host(photo, draft: draft, allowCaptions: true, maxPhotos: 10),
      );
      await tester.tap(find.text('1'));
      await tester.pump();

      final field = tester.widget<TextField>(
        find.byKey(cameraEditorCaptionKey),
      );
      expect(field.enabled, isFalse);
      expect(find.text('No captions on view-once photos'), findsOneWidget);
    });

    testWidgets('over the camera it offers both ways to add a photo', (
      tester,
    ) async {
      final draft = three();
      addTearDown(draft.dispose);
      await settle(
        tester,
        host(
          photo,
          draft: draft,
          canRetake: true,
          allowCaptions: true,
          maxPhotos: 10,
          galleryOverCamera: true,
        ),
      );
      expect(find.bySemanticsLabel('Take another photo'), findsOneWidget);
      expect(find.bySemanticsLabel('Add more photos'), findsOneWidget);
    });

    testWidgets('a full draft stops offering more', (tester) async {
      final draft = three();
      addTearDown(draft.dispose);
      await settle(
        tester,
        host(
          photo,
          draft: draft,
          canRetake: true,
          allowCaptions: true,
          maxPhotos: 3,
          galleryOverCamera: true,
        ),
      );
      expect(find.bySemanticsLabel('Take another photo'), findsNothing);
      expect(find.bySemanticsLabel('Add more photos'), findsNothing);
    });

    testWidgets('removing a photo from the rail takes it out of the draft', (
      tester,
    ) async {
      final draft = three();
      addTearDown(draft.dispose);
      await settle(
        tester,
        host(photo, draft: draft, allowCaptions: true, maxPhotos: 10),
      );
      await tester.tap(find.bySemanticsLabel('Remove this photo').first);
      await tester.pump();
      expect(draft.length, 2);
      expect(find.bySemanticsLabel('Item 2 of 2'), findsOneWidget);
    });
  });
}
