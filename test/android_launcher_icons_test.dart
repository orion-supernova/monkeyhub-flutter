// Pins the set of launcher-icon alias ids across every place that has to agree
// on it, and that each Android alias ships a complete adaptive icon.
//
// A mismatch is not a cosmetic bug: an alias missing from the manifest makes
// `setComponentEnabledSetting` throw, and an id missing from MainActivity's
// list can never be switched off again.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monkeyhub/services/launcher_icon_names.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/monkey_collection.dart';

const _res = 'android/app/src/main/res';
const _densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

Set<String> _dartIds() {
  GoogleFonts.config.allowRuntimeFetching = false;
  return {
    for (final t in ThemeController.all)
      if (!kBorrowedIconThemeIds.contains(t.id)) launcherIconNameForThemeId(t.id),
    ...monkeyCollectionIds,
  };
}

Set<String> _manifestIds() {
  final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  return {
    for (final m in RegExp(
      r'<activity-alias[^>]*?android:name="\.(\w+)"',
      dotAll: true,
    ).allMatches(xml))
      m.group(1)!,
  };
}

Set<String> _kotlinIds() {
  final kt = File(
    'android/app/src/main/kotlin/com/walhallaa/chattest20241220/MainActivity.kt',
  ).readAsStringSync();
  final list = RegExp(
    r'val aliasIds = listOf\((.*?)\n\s*\)',
    dotAll: true,
  ).firstMatch(kt)!.group(1)!;
  return {for (final m in RegExp(r'"(\w+)"').allMatches(list)) m.group(1)!};
}

Set<String> _plistIds() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  // The iPhone block comes first; its keys sit one level below
  // CFBundleAlternateIcons, at three tabs.
  final start = plist.indexOf('<key>CFBundleAlternateIcons</key>');
  final end = plist.indexOf('\n\t\t</dict>', start);
  return {
    for (final m in RegExp(
      r'^\t\t\t<key>(\w+)</key>',
      multiLine: true,
    ).allMatches(plist.substring(start, end)))
      m.group(1)!,
  };
}

bool _drawableExists(String name) {
  for (final dir in Directory(_res).listSync().whereType<Directory>()) {
    if (!dir.path.split('/').last.startsWith('drawable')) continue;
    for (final ext in ['png', 'webp', 'xml']) {
      if (File('${dir.path}/$name.$ext').existsSync()) return true;
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('alias ids agree across Dart, manifest, MainActivity and Info.plist', () {
    final dart = _dartIds();
    expect(dart, isNotEmpty);
    expect(_manifestIds(), dart, reason: 'AndroidManifest activity-aliases');
    expect(_kotlinIds(), dart, reason: 'MainActivity.kt aliasIds');
    expect(_plistIds(), dart, reason: 'Info.plist CFBundleAlternateIcons');
  });

  test('every manifest alias points at its own launcher icon', () {
    final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    for (final id in _dartIds()) {
      final block = RegExp(
        '<activity-alias[^>]*?android:name="\\.$id"[^>]*>',
        dotAll: true,
      ).firstMatch(xml)!.group(0)!;
      expect(block, contains('android:icon="@mipmap/ic_launcher_$id"'), reason: id);
      expect(block, contains('android:roundIcon="@mipmap/ic_launcher_$id"'), reason: id);
      expect(block, contains('android:enabled="false"'), reason: id);
    }
  });

  test('every alias ships an adaptive icon and its flat fallback', () {
    final colors = File('$_res/values/ic_launcher_alias_colors.xml').readAsStringSync();
    for (final id in _dartIds()) {
      final f = File('$_res/mipmap-anydpi-v26/ic_launcher_$id.xml');
      expect(f.existsSync(), isTrue, reason: 'adaptive xml for $id');
      final xml = f.readAsStringSync();
      for (final layer in ['background', 'foreground', 'monochrome']) {
        expect(xml, contains('<$layer'), reason: '$id has no $layer layer');
      }
      for (final d in _densities) {
        expect(
          File('$_res/mipmap-$d/ic_launcher_$id.png').existsSync(),
          isTrue,
          reason: 'legacy $d PNG for $id',
        );
      }
      for (final m in RegExp(r'@(drawable|color)/(\w+)').allMatches(xml)) {
        final name = m.group(2)!;
        if (m.group(1) == 'color') {
          expect(colors, contains('name="$name"'), reason: '$id -> $name');
          continue;
        }
        expect(_drawableExists(name), isTrue, reason: '$id -> $name');
        // Raster layers must exist at every density, or the launcher scales a
        // neighbour and the icon blurs or crops differently per device.
        final isDensityLayer = name.startsWith('ic_launcher_fg_') ||
            name.startsWith('ic_launcher_bg_') && !monkeyCollectionIds.contains(id) ||
            name.startsWith('ic_launcher_mono_');
        if (isDensityLayer) {
          for (final d in _densities) {
            expect(
              File('$_res/drawable-$d/$name.png').existsSync(),
              isTrue,
              reason: '$name at $d',
            );
          }
        }
      }
    }
  });

  test('adaptive layers keep the mark inside the 66dp safe zone', () {
    // Foreground PNGs are 108dp square; the launcher guarantees only the
    // centre 66dp (61%). Read the xxxhdpi PNG header for size, and make sure
    // the generator's mark fraction (0.60) has not crept past that.
    final src = File('test/generate_launcher_icons.dart').readAsStringSync();
    final fraction = double.parse(
      RegExp(r'_markFraction = ([0-9.]+);').firstMatch(src)!.group(1)!,
    );
    expect(fraction, lessThanOrEqualTo(66 / 108));
    for (final id in _dartIds().where((i) => !monkeyCollectionIds.contains(i))) {
      final png = File('$_res/drawable-xxxhdpi/ic_launcher_mono_$id.png')
          .readAsBytesSync();
      final w = (png[16] << 24) | (png[17] << 16) | (png[18] << 8) | png[19];
      expect(w, 432, reason: '$id mono layer is 108dp at xxxhdpi');
    }
  });
}
