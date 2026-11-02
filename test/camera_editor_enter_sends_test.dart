import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/camera_editor_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// On a desktop the photo editor sends on Enter, like the chat composer does.
/// It used to answer Enter with nothing, so the round send button was the only
/// way out after adding a photo.
void main() {
  Uint8List png() {
    final b = img.Image(width: 400, height: 500);
    img.fill(b, color: img.ColorRgb8(0x44, 0x55, 0x77));
    return img.encodePng(b);
  }

  Future<void> open(WidgetTester tester, void Function(Object?) done) async {
    final draft = EditorDraft()
      ..add(png())
      ..add(png());
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => done(await CameraEditorScreen.open(
                c,
                draft: draft,
                allowCaptions: true,
                maxPhotos: 10,
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Enter sends the photos on a desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
    Object? result;
    await open(tester, (r) => result = r);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(result, isA<EditorSend>());
    expect((result! as EditorSend).photos, hasLength(2));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Enter in the caption sends, Shift+Enter does not', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
    Object? result;
    await open(tester, (r) => result = r);
    await tester.tap(find.byKey(cameraEditorCaptionKey));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 200));
    expect(result, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(result, isA<EditorSend>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Enter does nothing on a phone', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
    Object? result;
    await open(tester, (r) => result = r);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(result, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
