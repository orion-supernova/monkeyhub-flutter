import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/screens/camera_editor_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// Where the photograph actually lands on the send-preview screen.
///
/// The complaint this answers, in the reporter's words: "send photo preview has
/// weird left and right spaces... I'm viewing my screenshot on my screen
/// already, isn't it a bit weird?" A screenshot is by definition the exact
/// shape of the display it was taken on, so on the phone that took it there is
/// no honest reason for a gutter down either side — `contain` and `cover` agree
/// at that one aspect ratio, and the answer must be the full width of the
/// screen.
///
/// Measured rather than eyeballed: `_stage` fits the picture with `fitContain`
/// against whatever box the layout hands it, so a gutter means either the box
/// is not the screen or the aspect is not the file's.
void main() {
  Uint8List makePng(int width, int height) {
    final bitmap = img.Image(width: width, height: height);
    img.fill(bitmap, color: img.ColorRgb8(0x44, 0x55, 0x77));
    return img.encodePng(bitmap);
  }

  Widget host(Uint8List source) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: CameraEditorScreen(source: source),
    ),
  );

  /// See camera_editor_chrome_test.dart — codecs are real background work the
  /// fake-async zone never advances, so runAsync and pump must interleave.
  Future<void> settle(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byKey(cameraEditorStageImageKey).evaluate().isNotEmpty) break;
    }
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// An iPhone 15 Pro: 393x852 logical, 1179x2556 physical — which is exactly
  /// the size of a screenshot taken on one.
  void asPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('a screenshot fills the stage edge to edge', (tester) async {
    asPhone(tester);
    await settle(tester, host(makePng(1179, 2556)));

    final stage = tester.getRect(find.byKey(cameraEditorStageImageKey));
    expect(stage.left, moreOrLessEquals(0, epsilon: 0.5),
        reason: 'no gutter on the left');
    expect(stage.width, moreOrLessEquals(393, epsilon: 0.5),
        reason: 'the picture is as wide as the screen');
    expect(stage.height, moreOrLessEquals(852, epsilon: 1.0),
        reason: 'and as tall');
  });

  testWidgets('no app-level chrome is allowed to shorten the stage', (
    tester,
  ) async {
    // The bug this file was written for, kept as the thing that must not come
    // back. A bar across the top of the app — the self-host marker, as it was
    // — took the status inset plus 26pt out of the layout for EVERY route.
    // The editor was still full-bleed inside the box it was given; the box had
    // just stopped being the screen.
    //
    // A photograph of any other shape does not notice. A SCREENSHOT does,
    // because its whole claim on the screen is being exactly its shape: take
    // 73pt off the height and `contain` scales it down to the shorter box, and
    // the width it loses becomes a gutter down both sides — ~17pt on an
    // iPhone 16e, the ~4% visible in the report. The marker is a corner ribbon
    // now and takes no height (see `self_host_badge_test.dart`), so this is
    // what the geometry has to come to.
    const barHeight = 47.0 + 26.0;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await settle(tester, host(makePng(1170, 2532)));

    final stage = tester.getRect(find.byKey(cameraEditorStageImageKey));
    expect(stage.width, moreOrLessEquals(390, epsilon: 0.5));

    // And explicitly: NOT what a shortened viewport would have produced.
    const screenshotAspect = 1170 / 2532;
    final shortened = (844 - barHeight) * screenshotAspect;
    expect(stage.width, greaterThan(shortened + 15),
        reason: 'a bar-shortened stage would be ~33pt narrower than this');
  });

  testWidgets('a 4:3 photo letterboxes, it does not pillarbox', (tester) async {
    // The control. A photograph that is NOT the shape of the phone must lose
    // its space top and bottom — where the rails float — and keep the full
    // width, which is the whole reason the stage is full-bleed.
    asPhone(tester);
    await settle(tester, host(makePng(3024, 4032)));

    final stage = tester.getRect(find.byKey(cameraEditorStageImageKey));
    expect(stage.width, moreOrLessEquals(393, epsilon: 0.5));
    expect(stage.height, lessThan(852));
  });
}
