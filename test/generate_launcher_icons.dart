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
//     across mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi (48/72/96/144/192 px). These flat
//     PNGs are the pre-Android-8 fallback only.
//
//   - Android 8+ adaptive icons, one set per alias id, so the launcher never
//     has to plate or shrink a legacy PNG:
//       res/mipmap-anydpi-v26/ic_launcher_{id}.xml  (background, foreground,
//                                                    monochrome)
//     Themed marks:
//       res/values/ic_launcher_alias_colors.xml     background colour per id
//       res/drawable-{d}/ic_launcher_fg_{id}.png    108dp layer, mark inside
//                                                   the 66dp safe zone
//       res/drawable-{d}/ic_launcher_mono_{id}.png  single-colour silhouette
//     Monkey Collection (full-bleed illustrations):
//       res/drawable-nodpi/ic_launcher_bg_{id}.webp the bundled 512px art,
//                                                   copied as-is, inset 6%
//       res/drawable/ic_launcher_monochrome_monkey.xml is shared by them.
//
// Notes:
//   - Each brandMark is composited onto its theme's `background` color so the
//     icon is opaque (iOS rejects transparent alternate icons).
//   - Themes that use Google Fonts may render with fallback fonts under the
//     test harness; rerun on a machine with network access if the rendered
//     fonts look wrong.

import 'dart:async';
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
import 'package:monkeyhub/widgets/monkey_collection.dart';

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
      final colors = <String, Color>{};

      for (final theme in ThemeController.all) {
        // A borrowed icon belongs to another theme; rendering this one under
        // its name would overwrite the owner's art.
        if (kBorrowedIconThemeIds.contains(theme.id)) continue;
        // The PNG filename uses the PLATFORM alt-icon name, which differs from
        // the theme id for a few themes (see launcher_icon_names.dart).
        final iconName = launcherIconNameForThemeId(theme.id);
        final masterPng = await _renderMaster(tester, theme);
        await _writeAllSizes(tester, masterPng, iconName, iosDir);
        await _writeAdaptive(tester, theme, iconName, colors, masterPng);
        // ignore: avoid_print
        print(
          '[generate_launcher_icons] wrote $iconName (theme.id=${theme.id})',
        );
      }

      _writeColors(colors);

      // The Monkey Collection's flat PNGs are not rendered here: its icons are
      // photos, cut and compressed straight from the originals by
      // tool/brand_images.py. Its adaptive layers reuse the bundled WebP.
      for (final v in monkeyCollection) {
        _writeMonkeyAdaptive(v);
        // ignore: avoid_print
        print('[generate_launcher_icons] wrote adaptive ${v.id}');
      }
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

// Adaptive layer sizes: 108dp at each density.
const _adaptiveSizes = {
  108: 'mdpi',
  162: 'hdpi',
  216: 'xhdpi',
  324: 'xxhdpi',
  432: 'xxxhdpi',
};

/// Fraction of the 108dp layer the mark box may occupy. The launcher mask
/// guarantees only the centre 66dp (61%); 0.60 keeps every pixel of the mark
/// inside it.
const double _markFraction = 0.60;

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

const _res = 'android/app/src/main/res';

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Themed icon. Three shapes, picked from the mark itself:
///
///  - Boxed mark (a ball, a seal, a star, or a glyph on the surface colour):
///    surface colour as the background layer, the mark alone inside the 66dp
///    safe zone as the foreground.
///  - Flat mark (an opaque square of one colour with a glyph on it): the
///    colour becomes the background layer and the mark sits in the safe zone
///    over it, so the square seamlessly melts into the plate instead of
///    showing as a smaller square with slivers around it.
///  - Gradient mark (an opaque square that fills its canvas but is not one
///    colour): can't melt into a flat plate, so the whole master becomes the
///    background layer (inset 12%: the glyphs are drawn large) and the
///    foreground is empty.
///
/// Either way the monochrome layer is derived from the same pixels.
Future<void> _writeAdaptive(
  WidgetTester tester,
  AppTheme theme,
  String id,
  Map<String, Color> colors,
  Uint8List masterPng,
) async {
  final mark = await _renderMark(tester, theme);
  final probe = await _probe(tester, mark);
  final bleed = probe.fullBleed && probe.flat == null;
  // ignore: avoid_print
  print(
    '[generate_launcher_icons] $id fullBleed=${probe.fullBleed} '
    'flat=${probe.flat != null}',
  );
  final mono = await _silhouette(
    tester,
    bleed ? masterPng : mark,
    theme.surface,
    glyphOnly: probe.fullBleed,
  );
  for (final entry in _adaptiveSizes.entries) {
    final dir = Directory('$_res/drawable-${entry.value}')
      ..createSync(recursive: true);
    final main = bleed ? masterPng : mark;
    final name = bleed ? 'bg' : 'fg';
    File('${dir.path}/ic_launcher_${name}_$id.png')
        .writeAsBytesSync(await _downsample(tester, main, entry.key));
    File('${dir.path}/ic_launcher_mono_$id.png')
        .writeAsBytesSync(await _downsample(tester, mono, entry.key));
  }
  if (bleed) {
    _writeAnydpi(
      id,
      background: '@drawable/ic_launcher_bg_$id',
      foreground: '@android:color/transparent',
      monochrome: '@drawable/ic_launcher_mono_$id',
      backgroundInset: '12%',
      monochromeInset: '12%',
    );
  } else {
    colors[id] = probe.flat ?? theme.surface;
    _writeAnydpi(
      id,
      background: '@color/ic_bg_$id',
      foreground: '@drawable/ic_launcher_fg_$id',
      monochrome: '@drawable/ic_launcher_mono_$id',
    );
  }
}

/// What the mark's box looks like: does it paint all four inner corners (a
/// circle, seal or star never does, a (rounded) square always does), and if so
/// is it one flat colour all the way to its edge.
Future<({bool fullBleed, Color? flat})> _probe(
  WidgetTester tester,
  Uint8List markPng,
) async {
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(markPng);
    final img = (await codec.getNextFrame()).image;
    final px = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    final lo = (_masterSize * (0.5 - _markFraction / 2)).round();
    final span = (_masterSize * _markFraction).round();
    int at(double fx, double fy) {
      final x = lo + (span * fx).round();
      final y = lo + (span * fy).round();
      return (y * img.width + x) * 4;
    }

    final corners = [
      at(.1, .1),
      at(.9, .1),
      at(.1, .9),
      at(.9, .9),
    ];
    final fullBleed = corners.every((i) => px[i + 3] > 250);
    if (!fullBleed) return (fullBleed: false, flat: null);
    final points = [
      ...corners,
      at(.5, 0),
      at(0, .5),
      at(.9985, .5),
      at(.5, .9985),
    ];
    final r = px[points[0]], g = px[points[0] + 1], b = px[points[0] + 2];
    final flat = points.every(
      (i) =>
          px[i + 3] > 250 &&
          (px[i] - r).abs() < 8 &&
          (px[i + 1] - g).abs() < 8 &&
          (px[i + 2] - b).abs() < 8,
    );
    return (
      fullBleed: true,
      flat: flat ? Color.fromARGB(255, r, g, b) : null,
    );
  }))!;
}

void _writeMonkeyAdaptive(MonkeyVariant v) {
  final dir = Directory('$_res/drawable-nodpi')..createSync(recursive: true);
  File(v.assetPath).copySync('${dir.path}/ic_launcher_bg_${v.id}.webp');
  // 6% inset: the 72dp visible area stays inside the picture (it covers 95dp),
  // with slack for launcher parallax, while the subject stays as large as the
  // original framing allows. The foreground is empty on purpose.
  _writeAnydpi(
    v.id,
    background:
        '@drawable/ic_launcher_bg_${v.id}',
    foreground: '@android:color/transparent',
    monochrome: '@drawable/ic_launcher_monochrome_monkey',
    backgroundInset: '6%',
  );
}

void _writeAnydpi(
  String id, {
  required String background,
  required String foreground,
  required String monochrome,
  String? backgroundInset,
  String? monochromeInset,
}) {
  final dir = Directory('$_res/mipmap-anydpi-v26')..createSync(recursive: true);
  final bg = backgroundInset == null
      ? '  <background android:drawable="$background"/>\n'
      : '  <background>\n'
          '    <inset\n'
          '        android:drawable="$background"\n'
          '        android:inset="$backgroundInset" />\n'
          '  </background>\n';
  final mono = monochromeInset == null
      ? '  <monochrome android:drawable="$monochrome"/>\n'
      : '  <monochrome>\n'
          '    <inset\n'
          '        android:drawable="$monochrome"\n'
          '        android:inset="$monochromeInset" />\n'
          '  </monochrome>\n';
  File('${dir.path}/ic_launcher_$id.xml').writeAsStringSync(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<!-- Generated by test/generate_launcher_icons.dart. -->\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '$bg'
    '  <foreground android:drawable="$foreground"/>\n'
    '$mono'
    '</adaptive-icon>\n',
  );
}

void _writeColors(Map<String, Color> colors) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<!-- Generated by test/generate_launcher_icons.dart. -->')
    ..writeln('<resources>');
  for (final e in colors.entries) {
    b.writeln('    <color name="ic_bg_${e.key}">${_hex(e.value)}</color>');
  }
  b.writeln('</resources>');
  File('$_res/values/ic_launcher_alias_colors.xml')
      .writeAsStringSync(b.toString());
}

/// The mark alone on a transparent 1024px canvas, boxed to [_markFraction].
Future<Uint8List> _renderMark(WidgetTester tester, AppTheme theme) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(_masterSize, _masterSize));
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(_masterSize, _masterSize)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: _masterSize,
            height: _masterSize,
            child: Center(
              child: theme.iconMark(size: _masterSize * _markFraction),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }))!;
}

/// White-on-transparent monochrome layer.
///
/// "Glyph" pixels are the ones whose brightness departs from the mark's median
/// brightness (the letter on a seal, the highlight on a ball). Full-bleed
/// marks (glyphOnly) show just the glyph. Boxed marks show their outline, found as the
/// distance from the surface colour, with the glyph cut out of it.
Future<Uint8List> _silhouette(
  WidgetTester tester,
  Uint8List markPng,
  Color surface, {
  required bool glyphOnly,
}) async {
  return (await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(markPng);
    final img = (await codec.getNextFrame()).image;
    final raw = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final px = raw.buffer.asUint8List();
    double lum(int i) =>
        (0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2]) / 255;
    final hist = List<int>.filled(256, 0);
    var n = 0;
    for (var i = 0; i < px.length; i += 4) {
      if (px[i + 3] < 250) continue;
      hist[(lum(i) * 255).round()]++;
      n++;
    }
    var acc = 0;
    var median = 0.0;
    for (var b = 0; b < 256; b++) {
      acc += hist[b];
      if (acc >= n / 2) {
        median = b / 255;
        break;
      }
    }
    final sr = (surface.r * 255).round();
    final sg = (surface.g * 255).round();
    final sb = (surface.b * 255).round();
    double smooth(double e0, double e1, double x) {
      final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    for (var i = 0; i < px.length; i += 4) {
      final a = px[i + 3] / 255;
      final glyph = smooth(0.18, 0.4, (lum(i) - median).abs());
      final dist = smooth(
        0.03,
        0.15,
        ((px[i] - sr).abs() + (px[i + 1] - sg).abs() + (px[i + 2] - sb).abs()) /
            (3 * 255),
      );
      final alpha = glyphOnly ? a * glyph : a * dist * (1 - glyph);
      px[i] = 255;
      px[i + 1] = 255;
      px[i + 2] = 255;
      px[i + 3] = (alpha * 255).round();
    }
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      px,
      img.width,
      img.height,
      ui.PixelFormat.rgba8888,
      c.complete,
    );
    final out = await c.future;
    return (await out.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }))!;
}
