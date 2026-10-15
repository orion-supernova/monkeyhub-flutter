import 'package:flutter/material.dart';

/// One entry in the curated "Monkey Collection" section of the logo picker.
///
/// Each variant is a self-contained illustration shipped as a 512px WebP
/// (`branding/monkey/*.webp`), cut from the full-size original in
/// `branding/source/`, which is not bundled. `MonkeyIconCanvas` renders the
/// asset filling the canvas in the picker tile; the native launcher icons are
/// cut from the same original by `tool/brand_images.py`.
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

  /// Path to the bundled WebP asset (declared in `pubspec.yaml`).
  final String assetPath;
}

/// The ids of the last four (`mh_monkey_astronaut`, `_hiking`, `_fields`,
/// `_hmm`) predate their current names and must not change: an id is the
/// Android activity-alias a user may have enabled, and shipping an update
/// without that alias leaves the app with no launcher entry at all.
///
/// After adding or changing one, run `python3 tool/brand_images.py`, which
/// reads this list and writes the bundled WebP and every native icon size.
const List<MonkeyVariant> monkeyCollection = <MonkeyVariant>[
  MonkeyVariant(
    id: 'mh_monkey_bubble_head',
    displayName: 'Bubble Head',
    assetPath: 'branding/monkey/bubble-head.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_bubble_peek',
    displayName: 'Bubble Peek',
    assetPath: 'branding/monkey/bubble-peek.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_bubble_hang',
    displayName: 'Bubble Hang',
    assetPath: 'branding/monkey/bubble-hang.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_neon_hang',
    displayName: 'Neon Hang',
    assetPath: 'branding/monkey/neon-hang.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_tail_bubble',
    displayName: 'Tail Bubble',
    assetPath: 'branding/monkey/tail-bubble.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_typing',
    displayName: 'Typing',
    assetPath: 'branding/monkey/typing.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_ops_tech',
    displayName: 'Ops Tech',
    assetPath: 'branding/monkey/ops-tech.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_detective',
    displayName: 'Detective',
    assetPath: 'branding/monkey/detective.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_safety_spotter',
    displayName: 'Safety Spotter',
    assetPath: 'branding/monkey/safety-spotter.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_control_room',
    displayName: 'Control Room',
    assetPath: 'branding/monkey/control-room.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_case_board',
    displayName: 'Case Board',
    assetPath: 'branding/monkey/case-board.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_astronaut',
    displayName: 'Astronaut',
    assetPath: 'branding/monkey/astronaut.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_hiking',
    displayName: 'Hiker',
    assetPath: 'branding/monkey/hiker.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_fields',
    displayName: 'Goggles',
    assetPath: 'branding/monkey/goggles.webp',
  ),
  MonkeyVariant(
    id: 'mh_monkey_hmm',
    displayName: 'Thinker',
    assetPath: 'branding/monkey/thinker.webp',
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

/// Renders the variant's image filling the [size]×[size] canvas. The source
/// images are already self-contained illustrations (full-bleed, opaque), so
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
