import 'package:flutter/material.dart';

/// One entry in the curated "Monkey Collection" section of the logo picker.
///
/// Each variant is a self-contained illustration shipped as a PNG asset
/// (`branding/monkey/*.png`). `MonkeyIconCanvas` renders the asset filling
/// the canvas — same widget runs in the picker tile AND the launcher-icon
/// PNG generator so preview ≡ launcher.
@immutable
class MonkeyVariant {
  const MonkeyVariant({
    required this.id,
    required this.displayName,
    required this.assetPath,
  });

  /// Used as the platform-side alternate-icon name (`CFBundleAlternateIcons`
  /// key on iOS, `<activity-alias android:name>` on Android, and the PNG
  /// filename the generator writes). The `mh_` prefix sidesteps iOS 26's
  /// silent-fail name cache — same reason `basic_daylight` had to become
  /// `mh_daylight`.
  final String id;

  /// Display label in the picker tile.
  final String displayName;

  /// Path to the source PNG asset (must be declared in `pubspec.yaml`).
  final String assetPath;
}

const List<MonkeyVariant> monkeyCollection = <MonkeyVariant>[
  MonkeyVariant(
    id: 'mh_monkey_hmm',
    displayName: 'Monkey Hmm',
    assetPath: 'branding/monkey/monkey-hmm.png',
  ),
  MonkeyVariant(
    id: 'mh_monkey_fields',
    displayName: 'Monkey Fields',
    assetPath: 'branding/monkey/monkey-fields.png',
  ),
  MonkeyVariant(
    id: 'mh_monkey_hiking',
    displayName: 'Monkey Hiking',
    assetPath: 'branding/monkey/monkey-hiking.png',
  ),
  MonkeyVariant(
    id: 'mh_monkey_astronaut',
    displayName: 'Monkey Astronaut',
    assetPath: 'branding/monkey/monkey-astronaut.png',
  ),
];

/// Set of every monkey-collection id for O(1) membership checks in the
/// icon-resolution code paths (LauncherIconService, AppBrandMark, etc.).
final Set<String> monkeyCollectionIds = {
  for (final v in monkeyCollection) v.id,
};

MonkeyVariant? monkeyVariantById(String id) {
  for (final v in monkeyCollection) {
    if (v.id == id) return v;
  }
  return null;
}

/// Renders the variant's PNG filling the [size]×[size] canvas. The source
/// PNGs are already self-contained illustrations (full-bleed, opaque), so
/// no backdrop colour is needed — iOS/Android apply their own masks.
class MonkeyIconCanvas extends StatelessWidget {
  const MonkeyIconCanvas({
    super.key,
    required this.variant,
    required this.size,
  });

  final MonkeyVariant variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      variant.assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
  }
}
