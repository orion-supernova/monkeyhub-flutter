// Design review renders for camera & media: the post-capture editor, the
// photo tray, the avatar cropper, the voice recorder, the view-once viewer,
// the shared viewer bar under a character theme, an outbound video note's
// failed state, and the desktop drop cards.
//
//   flutter test test/design_preview/media_review_preview.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/drop/drop_classifier.dart';
import 'package:monkeyhub/drop/drop_item.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/camera_editor_screen.dart';
import 'package:monkeyhub/screens/image_crop_screen.dart';
import 'package:monkeyhub/screens/photo_tray_screen.dart';
import 'package:monkeyhub/screens/view_once_viewer.dart';
import 'package:monkeyhub/screens/voice_recorder_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/drop/drop_cards.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';
import 'package:monkeyhub/widgets/video_note_message.dart';
import 'package:monkeyhub/widgets/viewer_chrome.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;

import 'preview_kit.dart';

/// A bright sky over darker ground, as an encoded PNG — the worst case for
/// white chrome, and real bytes for the screens that decode their source.
Future<Uint8List> _photo(WidgetTester tester, {int w = 900, int h = 1200}) async {
  return (await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    c.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, const [
          Color(0xFFBFE3FF),
          Color(0xFFFFE2B0),
          Color(0xFF3D6B3A),
        ], const [0, 0.55, 1]),
    );
    c.drawCircle(Offset(w * 0.7, h * 0.25), w * 0.12, Paint()..color = const Color(0xFFFFFBEA));
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }))!;
}

Future<void> Function() _decode(WidgetTester tester) => () async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    };

const _themes = ['basic', 'basic_daylight', 'risograph_pop'];

class _ViewerScene extends StatelessWidget {
  const _ViewerScene();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFBFE3FF), Color(0xFFFFD9A0), Color(0xFF3D6B3A)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ViewerTopBar(
            onClose: () {},
            title: 'Dua Karaosmanoğlu',
            subtitle: '3 / 12',
            actions: [
              GlassIconButton(tone: GlassTone.media, icon: CupertinoIcons.chat_bubble, onTap: () {}),
              const SizedBox(width: 8),
              GlassIconButton(tone: GlassTone.media, icon: CupertinoIcons.share, onTap: () {}),
            ],
          ),
        ),
        // The ×: viewer bar vs. the shared GlassCloseButton, side by side.
        Positioned(
          top: 200,
          left: 8,
          child: Row(children: [
            GlassIconButton(tone: GlassTone.media, icon: CupertinoIcons.xmark, onTap: () {}),
            const SizedBox(width: 16),
            GlassCloseButton(tone: GlassTone.media, onTap: () {}),
          ]),
        ),
      ]),
    );
  }
}

class _NotesAndDrops extends StatelessWidget {
  const _NotesAndDrops();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    DropAssessment a(String? name, int? size, DropKind k, {DropRefusal? r}) =>
        DropAssessment(
          candidate: DropCandidate(name: name, size: size),
          kind: k,
          refusal: r,
        );
    return Scaffold(
      backgroundColor: theme.background,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              OutboundVideoNote(
                theme: theme,
                diameter: 200,
                failed: true,
                progress: null,
                onRetry: () async {},
                onDiscard: () {},
              ),
              const SizedBox(width: 20),
              OutboundVideoNote(
                theme: theme,
                diameter: 120,
                failed: false,
                progress: 0.4,
              ),
            ]),
            const SizedBox(height: 30),
            DropCard(
              assessment: a('Q3-deck-final-final.key', 4400000, DropKind.document),
              theme: theme,
              l10n: l10n,
              tone: DropTone.accept,
            ),
            const SizedBox(height: 14),
            DropCard(
              assessment: a('IMG_2041.HEIC', 3100000, DropKind.photo),
              theme: theme,
              l10n: l10n,
              tone: DropTone.accept,
              overflowCount: 4,
            ),
            const SizedBox(height: 14),
            DropCard(
              assessment: a('Movies', null, DropKind.folder, r: DropRefusal.folder),
              theme: theme,
              l10n: l10n,
              tone: DropTone.refuse,
            ),
            const SizedBox(height: 14),
            DropCard(
              assessment: a(null, null, DropKind.photo),
              theme: theme,
              l10n: l10n,
              tone: DropTone.caution,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    m.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => call.method == 'hasPermission' ? false : null,
    );
    m.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });
  const locales = {'en': Locale('en'), 'tr': Locale('tr')};

  for (final id in _themes) {
    for (final lc in ['en', 'tr']) {
      testWidgets('media: editor $id $lc', (tester) async {
        final bytes = await _photo(tester);
        await snap(
          tester,
          previewApp(ThemeController.byId(id), CameraEditorScreen(source: bytes, canRetake: true),
              locale: locales[lc]!),
          'media_editor_${id}_$lc.png',
          act: _decode(tester),
        );
      });
      testWidgets('media: crop $id $lc', (tester) async {
        final bytes = await _photo(tester);
        await snap(
          tester,
          previewApp(ThemeController.byId(id), ImageCropScreen(source: bytes),
              locale: locales[lc]!),
          'media_crop_${id}_$lc.png',
          act: _decode(tester),
        );
      });
      testWidgets('media: tray $id $lc', (tester) async {
        final bytes = await _photo(tester, w: 300, h: 400);
        await snap(
          tester,
          previewApp(ThemeController.byId(id), PhotoTrayScreen(photos: [bytes, bytes, bytes]),
              locale: locales[lc]!),
          'media_tray_${id}_$lc.png',
          act: _decode(tester),
        );
      });
      testWidgets('media: recorder $id $lc', (tester) async {
        await snap(
          tester,
          previewApp(ThemeController.byId(id), const VoiceRecorderScreen(), locale: locales[lc]!),
          'media_recorder_${id}_$lc.png',
        );
      });
      testWidgets('media: view once $id $lc', (tester) async {
        final bytes = await _photo(tester);
        await snap(
          tester,
          previewApp(ThemeController.byId(id), ViewOnceViewer(bytes: bytes), locale: locales[lc]!),
          'media_viewonce_${id}_$lc.png',
          act: _decode(tester),
        );
      });
    }
    testWidgets('media: viewer bar $id', (tester) async {
      await snap(tester, previewApp(ThemeController.byId(id), const _ViewerScene()),
          'media_viewerbar_$id.png');
    });
    testWidgets('media: notes & drops $id', (tester) async {
      await snap(tester, previewApp(ThemeController.byId(id), const _NotesAndDrops()),
          'media_notes_drops_$id.png');
    });
  }
  testWidgets('media: crop tr 1.3', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final bytes = await _photo(tester);
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), ImageCropScreen(source: bytes),
          locale: const Locale('tr')),
      'media_crop_basic_tr_x13.png',
      act: _decode(tester),
    );
  });
  testWidgets('media: editor tr 1.3', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final bytes = await _photo(tester);
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), CameraEditorScreen(source: bytes, canRetake: true),
          locale: const Locale('tr')),
      'media_editor_basic_tr_x13.png',
      act: _decode(tester),
    );
  });
}
