// Throwaway design-preview kit: renders real widgets to PNG under any theme so
// a design change can be LOOKED AT, not just asserted about.
//
// Not a test of anything. `home_preview.dart` is the first consumer; any
// other screen can reuse [loadPreviewFonts], [previewApp] and [snap].
//
// Fonts are the whole trick. flutter_test draws every unknown family as Ahem
// boxes, so this registers, before anything is pumped:
//   * every font in the app's FontManifest.json (MaterialIcons, CupertinoIcons,
//     Google Sans, ...), the same way the engine would on device;
//   * every bundled google_fonts file under the exact family string the
//     package asks the engine for (`<Family>_<variant>`, e.g. `Inter_500`,
//     `Inter_regular`), plus the bare family it lists as fallback;
//   * macOS's SF Pro (`/System/Library/Fonts/SFNS.ttf`) under the two
//     CupertinoSystem* names the Basic themes use, and under Roboto, the
//     default family Material text resolves to.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// Where every preview PNG lands: under the gitignored `build/`, relative to
/// the package root `flutter test` runs from.
const String kPreviewDir = 'build/design_preview';

/// iPhone 16 Pro, in logical points.
const Size kIphone16Pro = Size(393, 852);
const double kIphoneTopInset = 59;
const double kIphoneBottomInset = 34;

const Map<String, int> _weightByName = {
  'Thin': 100,
  'ExtraLight': 200,
  'Light': 300,
  'Regular': 400,
  'Medium': 500,
  'SemiBold': 600,
  'Bold': 700,
  'ExtraBold': 800,
  'Black': 900,
};

bool _fontsLoaded = false;

Future<void> _load(String family, List<Future<ByteData>> data) async {
  final loader = FontLoader(family);
  for (final d in data) {
    loader.addFont(d);
  }
  await loader.load();
}

ByteData _fileBytes(String path) {
  final bytes = File(path).readAsBytesSync();
  return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
}

/// Registers every real font the app can draw with. Call once from setUpAll.
Future<void> loadPreviewFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  GoogleFonts.config.allowRuntimeFetching = false;

  // 1. The app's own font manifest — icon fonts and `fonts:` entries.
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final fonts = (entry['fonts'] as List<dynamic>)
        .map((f) => rootBundle.load((f as Map<String, dynamic>)['asset'] as String))
        .toList();
    await _load(family, fonts);
    // Material's Icons use the bare family; packaged ones are prefixed.
    if (family.endsWith('/MaterialIcons')) await _load('MaterialIcons', fonts);
  }

  // 2. Bundled google fonts, under the names google_fonts resolves to.
  final dir = Directory('assets/google_fonts');
  final byFamily = <String, List<ByteData>>{};
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (!name.endsWith('.ttf') && !name.endsWith('.otf')) continue;
    final stem = name.substring(0, name.lastIndexOf('.'));
    final dash = stem.lastIndexOf('-');
    if (dash < 0) continue;
    final family = stem.substring(0, dash);
    final part = stem.substring(dash + 1);
    final italic = part.endsWith('Italic');
    final weightName = italic ? part.substring(0, part.length - 6) : part;
    final weight = _weightByName[weightName.isEmpty ? 'Regular' : weightName];
    if (weight == null) continue;
    final data = _fileBytes(f.path);
    final variant = weight == 400
        ? (italic ? 'italic' : 'regular')
        : '$weight${italic ? 'italic' : ''}';
    await _load('${family}_$variant', [Future.value(data)]);
    byFamily.putIfAbsent(family, () => []).add(data);
  }
  for (final e in byFamily.entries) {
    await _load(e.key, [for (final d in e.value) Future.value(d)]);
  }

  // 3. SF Pro for the Basic themes and for default (Roboto) text.
  const sfPath = '/System/Library/Fonts/SFNS.ttf';
  if (File(sfPath).existsSync()) {
    final sf = _fileBytes(sfPath);
    for (final family in const [
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF UI Text',
      '.SF UI Display',
      'Roboto',
    ]) {
      await _load(family, [Future.value(sf)]);
    }
  } else {
    // No SF Pro (Linux): Inter, the nearest thing, under the same names, with
    // its weights, so text renders as text and not as Ahem boxes.
    const inter = {
      400: 'assets/google_fonts/Inter-Regular.ttf',
      500: 'assets/google_fonts/Inter-Medium.ttf',
      600: 'assets/google_fonts/Inter-SemiBold.ttf',
      700: 'assets/google_fonts/Inter-Bold.ttf',
    };
    for (final family in const [
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
      '.SF UI Text',
      '.SF UI Display',
      'Roboto',
    ]) {
      final loader = FontLoader(family);
      for (final e in inter.entries) {
        if (File(e.value).existsSync()) {
          loader.addFont(Future.value(_fileBytes(e.value)));
        }
      }
      await loader.load();
    }
  }
  const sfMono = '/System/Library/Fonts/SFNSMono.ttf';
  if (File(sfMono).existsSync()) {
    await _load('SF Mono', [Future.value(_fileBytes(sfMono))]);
  }
}

/// Wraps [child] the way the app does: ThemeScope over a MaterialApp with the
/// real localizations, and the theme's own background behind everything.
Widget previewApp(AppTheme theme, Widget child, {Locale locale = const Locale('en')}) =>
    ThemeScope(
      controller: ThemeController(theme),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          brightness: theme.background.computeLuminance() < 0.4
              ? Brightness.dark
              : Brightness.light,
          scaffoldBackgroundColor: theme.background,
        ),
        // The app's root paints `theme.background` under every route; a
        // screen's own `backgroundLayer` sits over it (and may be sized to
        // nothing, e.g. a bare ColoredBox in a non-positioned Stack slot).
        home: ColoredBox(
          color: theme.background,
          child: DefaultTextStyle(
            style: theme.body,
            child: child,
          ),
        ),
      ),
    );

/// Pumps [widget] full-screen at [size] (logical) and [dpr], with a fake notch
/// and home-indicator inset, then writes it to [path] as a PNG.
///
/// [path] may be a bare file name, in which case it lands in [kPreviewDir].
/// Animations are not settled (several widgets loop forever); the frame is
/// captured [settle] after the first pump — and, when [act] is given, [settle]
/// after [act] has driven the screen into the state to capture.
///
/// Shadows are drawn with their real blur: flutter_test turns them into
/// hard-edged shapes by default, which makes every soft shadow look like a
/// stacked card. The flag goes back before this returns, as the framework's
/// invariant check requires.
Future<void> snap(
  WidgetTester tester,
  Widget widget,
  String path, {
  Size size = kIphone16Pro,
  double dpr = 3,
  double topInset = kIphoneTopInset,
  double bottomInset = kIphoneBottomInset,
  Duration settle = const Duration(seconds: 2),
  Future<void> Function()? act,
}) async {
  debugDisableShadows = false;
  try {
    await _snap(tester, widget, path, size, dpr, topInset, bottomInset, settle, act);
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> _snap(
  WidgetTester tester,
  Widget widget,
  String path,
  Size size,
  double dpr,
  double topInset,
  double bottomInset,
  Duration settle,
  Future<void> Function()? act,
) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  final pad = FakeViewPadding(top: topInset * dpr, bottom: bottomInset * dpr);
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: widget));
  // Let any lazily-started font / asset futures finish on the real clock,
  // then advance the fake clock so entrance animations land.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pump(settle);
  await tester.pump(const Duration(milliseconds: 16));
  // Drive the UI into the state worth looking at — a swiped row, an open
  // menu — then let it come to rest before the capture.
  //
  // Frame by frame, not one long pump: a simulation started by the action
  // only begins on the next tick, so a single 2 s pump captures its first
  // frame, not its last.
  if (act != null) {
    await act();
    for (var t = Duration.zero; t < settle; t += const Duration(milliseconds: 16)) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final out = File(path.contains('/') ? path : '$kPreviewDir/$path');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes!);
}
