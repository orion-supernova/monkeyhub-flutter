import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/camera_editor_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/dust/spoiler_dust.dart';
import 'package:monkeyhub/widgets/media_send_switches.dart';

/// Spoiler is seen in the editor, not just switched: the stage goes under
/// the chat's blur and dust, and the veil lifts while the pen is out.
///
/// Set MONKEYHUB_PNG_DIR to also write the frames as PNGs to look at.
void main() {
  Uint8List stripes() {
    final bitmap = img.Image(width: 600, height: 800);
    for (var y = 0; y < 800; y++) {
      for (var x = 0; x < 600; x++) {
        final band = (x ~/ 60 + y ~/ 80) % 3;
        bitmap.setPixelRgb(
          x,
          y,
          band == 0 ? 0xF0 : 0x30,
          band == 1 ? 0xC0 : 0x40,
          band == 2 ? 0xE0 : 0x50,
        );
      }
    }
    return img.encodePng(bitmap);
  }

  Finder spoilerSwitch() => find.byWidgetPredicate(
        (w) => w is SendSwitchGlyph && w.kind == SendSwitch.spoiler,
      );
  Finder penSwitch() => find.byWidgetPredicate(
        (w) => w is SendSwitchGlyph && w.kind == SendSwitch.pen,
      );

  const boundary = Key('shot');

  Widget host(Uint8List source) => RepaintBoundary(
        key: boundary,
        child: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CameraEditorScreen(
              source: source,
              allowSpoiler: true,
              allowDrawing: true,
              allowViewOnce: true,
            ),
          ),
        ),
      );

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

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 16);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    final dir = Platform.environment['MONKEYHUB_PNG_DIR'];
    if (dir == null) return;
    final render = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundary),
    );
    final image = render.toImageSync();
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.png),
    );
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  ImageFiltered stageBlur(WidgetTester tester) => tester.widget<ImageFiltered>(
        find
            .ancestor(
              of: find.byKey(cameraEditorStageImageKey),
              matching: find.byType(ImageFiltered),
            )
            .first,
      );

  testWidgets('spoiler veils the stage; the pen lifts it', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await settle(tester, host(stripes()));
    expect(stageBlur(tester).enabled, isFalse);
    expect(find.byType(SpoilerDust), findsNothing);
    await shoot(tester, 'editor_1_plain');

    await tester.tap(spoilerSwitch());
    await pumpFor(tester, const Duration(milliseconds: 96));
    // In flight: the veil swelling out from the middle over the sharp one.
    expect(find.byType(SpoilerDust), findsOneWidget);
    await shoot(tester, 'editor_2_veiling');
    await pumpFor(tester, const Duration(milliseconds: 700));
    expect(stageBlur(tester).enabled, isTrue);
    await shoot(tester, 'editor_3_veiled');

    // The pen: drawing happens on the real picture.
    await tester.tap(penSwitch());
    await pumpFor(tester, const Duration(milliseconds: 96));
    expect(find.byType(SpoilerDust), findsOneWidget);
    await shoot(tester, 'editor_4_lifting');
    await pumpFor(tester, const Duration(milliseconds: 700));
    expect(stageBlur(tester).enabled, isFalse);
    await shoot(tester, 'editor_5_pen_out');

    // Pen away: back under.
    await tester.tap(penSwitch());
    await pumpFor(tester, const Duration(milliseconds: 900));
    expect(stageBlur(tester).enabled, isTrue);

    // And off for good.
    await tester.tap(spoilerSwitch());
    await pumpFor(tester, const Duration(milliseconds: 900));
    expect(stageBlur(tester).enabled, isFalse);
    expect(find.byType(SpoilerDust), findsNothing);
  });
}
