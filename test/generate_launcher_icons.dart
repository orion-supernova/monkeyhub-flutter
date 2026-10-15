// One-shot generator: renders each theme's brandMark into PNG files at the
// sizes iOS and Android need for alternate launcher icons, then writes them
// into the native build paths.
//
// Run with:
//   flutter test test/generate_launcher_icons.dart
//
// Outputs:
//   - iOS:     ios/Runner/AlternateIcons/{themeId}@2x.png  (120x120)
//              ios/Runner/AlternateIcons/{themeId}@3x.png  (180x180)
//     After running, drag `ios/Runner/AlternateIcons/` into the Runner target
//     in Xcode once, choosing "Create folder references" — see the package
//     README.
//
//   - Android: android/app/src/main/res/mipmap-{density}/ic_launcher_{id}.png
//     across mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi (48/72/96/144/192 px).
//     Picked up automatically by the AndroidManifest activity-aliases.
//
// Notes:
//   - Each brandMark is composited onto its theme's `background` color so the
//     icon is opaque (iOS rejects transparent alternate icons).
//   - Themes that use Google Fonts may render with fallback fonts under the
//     test harness; rerun on a machine with network access if the rendered
//     fonts look wrong.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monkeyhub/services/launcher_icon_names.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/brand_icon_canvas.dart';

const _iosSizes = {120: '@2x', 180: '@3x'};
const _androidSizes = {
  48: 'mdpi',
  72: 'hdpi',
  96: 'xhdpi',
  144: 'xxhdpi',
  192: 'xxxhdpi',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Runtime fetching off: the four affected themes (Neon Night/Anta,
  // Cyberpunk/JetBrains Mono, Deep Ocean/Spectral, Retro Wave/Audiowide) are
  // satisfied from bundled assets at `assets/google_fonts/*.ttf` — the
  // google_fonts package prefers bundled files over the network. Test harness
  // has no outbound HTTP, so a fetch here would always fail.
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'generate launcher icons for every theme',
    (tester) async {
      final iosDir = Directory('ios/Runner/AlternateIcons');
      iosDir.createSync(recursive: true);

      for (final theme in ThemeController.all) {
        // A borrowed icon belongs to another theme; rendering this one under
        // its name would overwrite the owner's art.
        if (kBorrowedIconThemeIds.contains(theme.id)) continue;
        // The PNG filename uses the PLATFORM alt-icon name, which differs from
        // the theme id for a few themes (see launcher_icon_names.dart).
        final iconName = launcherIconNameForThemeId(theme.id);
        final masterPng = await _renderMaster(tester, theme);
        await _writeAllSizes(tester, masterPng, iconName, iosDir);
        // ignore: avoid_print
        print(
          '[generate_launcher_icons] wrote $iconName (theme.id=${theme.id})',
        );
      }

      // The Monkey Collection is not rendered here: its icons are photos, cut
      // and compressed straight from the originals by tool/brand_images.py.
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _writeAllSizes(
  WidgetTester tester,
  Uint8List masterPng,
  String iconName,
  Directory iosDir,
) async {
  for (final entry in _iosSizes.entries) {
    final px = entry.key;
    final suffix = entry.value;
    final bytes = await _downsample(tester, masterPng, px);
    File('${iosDir.path}/$iconName$suffix.png').writeAsBytesSync(bytes);
  }
  for (final entry in _androidSizes.entries) {
    final px = entry.key;
    final density = entry.value;
    final dir = Directory('android/app/src/main/res/mipmap-$density');
    dir.createSync(recursive: true);
    final bytes = await _downsample(tester, masterPng, px);
    File('${dir.path}/ic_launcher_$iconName.png').writeAsBytesSync(bytes);
  }
}

const double _masterSize = 1024;

Future<Uint8List> _renderMaster(WidgetTester tester, AppTheme theme) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(_masterSize, _masterSize));
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(_masterSize, _masterSize)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          // Same widget the in-app preview tile uses → preview == launcher PNG
          // by construction. Owns its own opaque backdrop.
          child: BrandIconCanvas(theme: theme, size: _masterSize),
        ),
      ),
    ),
  );
  // Give the asset-backed Google Fonts loader real-time async to register the
  // bundled .ttf with Flutter's font system, then re-pump so the next paint
  // uses the loaded face. Without this, the first paint renders with the
  // fallback font and toImage() captures that.
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // Skia work has to run on the real async loop, not the test's fake clock —
  // otherwise toImage's future never completes and the test times out.
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }))!;
}

Future<Uint8List> _downsample(
  WidgetTester tester,
  Uint8List masterPng,
  int targetPx,
) async {
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(
      masterPng,
      targetWidth: targetPx,
      targetHeight: targetPx,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }))!;
}
