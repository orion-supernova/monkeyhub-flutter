import 'package:flutter/foundation.dart';

import '../l10n/generated/app_localizations.dart';

/// One tunable knob: its identity in storage, its range, and how to say what it
/// does.
///
/// Declared as data rather than as a field on [GlassConfig] so the settings
/// panel can render itself from a list. Adding a dial is one entry in a table
/// here plus one read at the call site — not another constructor parameter,
/// another `copyWith` argument, another JSON key and another slider widget,
/// which is four places to forget.
@immutable
class GlassKnob {
  const GlassKnob({
    required this.id,
    required this.label,
    required this.hint,
    required this.min,
    required this.max,
    required this.standard,
    this.decimals = 2,
  });

  /// Persisted key. Never rename one of these without a migration — an unknown
  /// key is dropped on read, which silently resets that dial.
  final String id;
  final String label;

  /// One line of prose under the slider. Says what the dial does to the look,
  /// not what it does to the number.
  final String hint;

  final double min;
  final double max;

  /// What the untuned recipe uses. A config stores only the dials moved away
  /// from this, so changing a standard later moves everyone who never touched
  /// that dial — which is what you want from a default.
  final double standard;

  final int decimals;

  double clampValue(double v) => v.clamp(min, max);

  /// Slider position in 0..1, and back.
  double toSlider(double v) =>
      max == min ? 0 : (clampValue(v) - min) / (max - min);
  double fromSlider(double t) => min + (max - min) * t.clamp(0, 1);

  String format(double v) => v.toStringAsFixed(decimals);
}

/// Localized display name for [knob], keyed by [GlassKnob.id] — the stable
/// persistence key — rather than by identity, so this stays a plain lookup
/// with no dependency on which const instance the caller happens to hold.
///
/// [GlassKnob.label] itself stays a hardcoded English field: it is a `const`
/// data table consumed in a lot of places, and localizing it in place would
/// mean threading a BuildContext through a compile-time constant. This
/// function is the one seam where the tuning panel actually displays it.
String glassKnobLabel(AppLocalizations l10n, GlassKnob knob) {
  switch (knob.id) {
    case 'frost':
      return l10n.glassKnobLabelFrost;
    case 'blur':
      return l10n.glassKnobLabelBlur;
    case 'saturation':
      return l10n.glassKnobLabelSaturation;
    case 'rimOpacity':
      return l10n.glassKnobLabelRimOpacity;
    case 'rimWidth':
      return l10n.glassKnobLabelRimWidth;
    case 'shadowOpacity':
      return l10n.glassKnobLabelShadowOpacity;
    case 'shadowBlur':
      return l10n.glassKnobLabelShadowBlur;
    case 'shadowY':
      return l10n.glassKnobLabelShadowY;
    case 'barMargin':
      return l10n.glassKnobLabelBarMargin;
    case 'barBottom':
      return l10n.glassKnobLabelBarBottom;
    case 'shellPadH':
      return l10n.glassKnobLabelShellPadH;
    case 'shellPadV':
      return l10n.glassKnobLabelShellPadV;
    case 'indicatorInset':
      return l10n.glassKnobLabelIndicatorInset;
    case 'segmentPadV':
      return l10n.glassKnobLabelSegmentPadV;
    case 'iconLabelGap':
      return l10n.glassKnobLabelIconLabelGap;
    case 'iconSize':
      return l10n.glassKnobLabelIconSize;
    case 'labelSize':
      return l10n.glassKnobLabelLabelSize;
    default:
      return knob.label;
  }
}

/// Localized one-line caption for [knob], or '' for the two dials
/// ([kIconSize], [kLabelSize]) that never had one. See [glassKnobLabel] for
/// why this is a lookup rather than a field on [GlassKnob].
String glassKnobHint(AppLocalizations l10n, GlassKnob knob) {
  switch (knob.id) {
    case 'frost':
      return l10n.glassKnobHintFrost;
    case 'blur':
      return l10n.glassKnobHintBlur;
    case 'saturation':
      return l10n.glassKnobHintSaturation;
    case 'rimOpacity':
      return l10n.glassKnobHintRimOpacity;
    case 'rimWidth':
      return l10n.glassKnobHintRimWidth;
    case 'shadowOpacity':
      return l10n.glassKnobHintShadowOpacity;
    case 'shadowBlur':
      return l10n.glassKnobHintShadowBlur;
    case 'shadowY':
      return l10n.glassKnobHintShadowY;
    case 'barMargin':
      return l10n.glassKnobHintBarMargin;
    case 'barBottom':
      return l10n.glassKnobHintBarBottom;
    case 'shellPadH':
      return l10n.glassKnobHintShellPadH;
    case 'shellPadV':
      return l10n.glassKnobHintShellPadV;
    case 'indicatorInset':
      return l10n.glassKnobHintIndicatorInset;
    case 'segmentPadV':
      return l10n.glassKnobHintSegmentPadV;
    case 'iconLabelGap':
      return l10n.glassKnobHintIconLabelGap;
    default:
      return '';
  }
}

// ---------------------------------------------------------------- glass dials

const kFrost = GlassKnob(
  id: 'frost',
  label: 'FROST',
  hint: 'how much white sits on the glass. down for see-through',
  min: 0,
  max: 1,
  standard: 1,
);

const kBlur = GlassKnob(
  id: 'blur',
  label: 'BLUR',
  hint: 'frosted at the top of the range, clear glass at the bottom',
  min: 0,
  max: 30,
  standard: 18,
  decimals: 1,
);

const kSaturation = GlassKnob(
  id: 'saturation',
  label: 'COLOUR BLEED',
  hint: 'how much colour survives the blur. past 2 it posterizes',
  min: 0,
  max: 2,
  standard: 1,
);

const kRimOpacity = GlassKnob(
  id: 'rimOpacity',
  label: 'RIM',
  hint: 'the accent outline. zero for a borderless surface',
  min: 0,
  max: 1,
  standard: 0.30,
);

const kRimWidth = GlassKnob(
  id: 'rimWidth',
  label: 'RIM WIDTH',
  hint: 'thickness of that outline',
  min: 0,
  max: 4,
  standard: 1.5,
  decimals: 1,
);

const kShadowOpacity = GlassKnob(
  id: 'shadowOpacity',
  label: 'SHADOW',
  hint: 'how far the surface floats above what is behind it',
  min: 0,
  max: 0.5,
  standard: 0.08,
);

const kShadowBlur = GlassKnob(
  id: 'shadowBlur',
  label: 'SHADOW SPREAD',
  hint: 'soft and wide, or tight and hard',
  min: 0,
  max: 40,
  standard: 14,
  decimals: 1,
);

const kShadowY = GlassKnob(
  id: 'shadowY',
  label: 'SHADOW DROP',
  hint: 'how far below the surface it falls',
  min: 0,
  max: 20,
  standard: 5,
  decimals: 1,
);

/// Every dial on a glass surface, in panel order.
const glassKnobs = <GlassKnob>[
  kFrost,
  kBlur,
  kSaturation,
  kRimOpacity,
  kRimWidth,
  kShadowOpacity,
  kShadowBlur,
  kShadowY,
];

// ------------------------------------------------------------- nav geometry

const kBarMargin = GlassKnob(
  id: 'barMargin',
  label: 'SIDE MARGIN',
  hint: 'gap between the bar and the edge of the screen',
  min: 0,
  max: 40,
  standard: 16,
  decimals: 0,
);

const kBarBottom = GlassKnob(
  id: 'barBottom',
  label: 'BOTTOM GAP',
  hint: 'how high the bar floats off the bottom',
  min: 0,
  max: 40,
  standard: 12,
  decimals: 0,
);

const kShellPadH = GlassKnob(
  id: 'shellPadH',
  label: 'END PADDING',
  hint: 'bar edge to the first pill. small, or the ends look marooned',
  min: 0,
  max: 16,
  standard: 3,
  decimals: 0,
);

const kShellPadV = GlassKnob(
  id: 'shellPadV',
  label: 'TOP PADDING',
  hint: 'bar edge to the top of the pill',
  min: 0,
  max: 16,
  standard: 6,
  decimals: 0,
);

const kIndicatorInset = GlassKnob(
  id: 'indicatorInset',
  label: 'PILL INSET',
  hint: 'how far the selection pill sits inside its slot',
  min: 0,
  max: 24,
  standard: 4,
  decimals: 0,
);

const kSegmentPadV = GlassKnob(
  id: 'segmentPadV',
  label: 'ROW PADDING',
  hint: 'air above and below the icon and its label',
  min: 0,
  max: 20,
  standard: 6,
  decimals: 0,
);

const kIconLabelGap = GlassKnob(
  id: 'iconLabelGap',
  label: 'ICON GAP',
  hint: 'space between an icon and the word under it',
  min: 0,
  max: 14,
  standard: 2,
  decimals: 0,
);

const kIconSize = GlassKnob(
  id: 'iconSize',
  label: 'ICON SIZE',
  hint: '',
  min: 14,
  max: 32,
  standard: 22,
  decimals: 0,
);

const kLabelSize = GlassKnob(
  id: 'labelSize',
  label: 'LABEL SIZE',
  hint: '',
  min: 6,
  max: 16,
  standard: 10,
  decimals: 0,
);

/// Every dial on the bottom bar's layout, in panel order.
const navGeometryKnobs = <GlassKnob>[
  kBarMargin,
  kBarBottom,
  kShellPadH,
  kShellPadV,
  kIndicatorInset,
  kSegmentPadV,
  kIconLabelGap,
  kIconSize,
  kLabelSize,
];

// ------------------------------------------------------------------- config

/// A set of dial positions, stored as *overrides* on the standard recipe.
///
/// Sparse on purpose. A dial never touched is absent, so it keeps following
/// [GlassKnob.standard] if that standard is later retuned, and a knob added in
/// a future version reads as standard in an old saved slot rather than as zero.
@immutable
class GlassConfig {
  const GlassConfig([this.overrides = const <String, double>{}]);

  final Map<String, double> overrides;

  /// This config's value for [k], clamped — a hand-edited or corrupt keychain
  /// entry should not be able to set a blur of 4000.
  double of(GlassKnob k) => k.clampValue(overrides[k.id] ?? k.standard);

  bool isStandard(GlassKnob k) => !overrides.containsKey(k.id);

  /// True when nothing has been moved off the standard recipe — which is what
  /// makes a reset control a no-op, and so what disables it.
  bool get isUntouched => overrides.isEmpty;

  GlassConfig set(GlassKnob k, double v) => GlassConfig({
    ...overrides,
    k.id: k.clampValue(v),
  });

  GlassConfig reset(GlassKnob k) =>
      GlassConfig({...overrides}..remove(k.id));

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(overrides);

  /// Tolerates unknown keys and non-numeric junk so a config written by a
  /// newer build, or a half-corrupt keychain value, degrades to the standard
  /// recipe instead of failing to parse and wiping the whole profile.
  factory GlassConfig.fromJson(Object? raw) {
    if (raw is! Map) return const GlassConfig();
    final out = <String, double>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is num) out[key] = value.toDouble();
    }
    return GlassConfig(out);
  }

  /// Interpolates dial for dial.
  ///
  /// Walks the union of both sides' keys and resolves each through [of], so a
  /// dial set on one side and standard on the other still travels between two
  /// real values rather than snapping from nothing.
  static GlassConfig lerp(GlassConfig a, GlassConfig b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    final ids = <String>{...a.overrides.keys, ...b.overrides.keys};
    if (ids.isEmpty) return a;
    final out = <String, double>{};
    for (final knob in [...glassKnobs, ...navGeometryKnobs]) {
      if (!ids.contains(knob.id)) continue;
      out[knob.id] = a.of(knob) + (b.of(knob) - a.of(knob)) * t;
    }
    return GlassConfig(out);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GlassConfig) return false;
    if (other.overrides.length != overrides.length) return false;
    for (final e in overrides.entries) {
      if (other.overrides[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    overrides.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// One complete look: the bottom bar's glass, every other glass surface's
/// glass, and the bar's layout.
///
/// The bar and the rest of the app are separate configs because the bar is the
/// one surface that sits over moving content for its whole life. A setting that
/// makes it read well as a lens tends to be too thin for a composer or a header
/// that has text directly behind it.
@immutable
class GlassProfile {
  const GlassProfile({
    this.nav = const GlassConfig(),
    this.app = const GlassConfig(),
    this.geometry = const GlassConfig(),
  });

  final GlassConfig nav;
  final GlassConfig app;
  final GlassConfig geometry;

  /// True when every dial in every panel is standard.
  bool get isUntouched =>
      nav.isUntouched && app.isUntouched && geometry.isUntouched;

  GlassProfile copyWith({
    GlassConfig? nav,
    GlassConfig? app,
    GlassConfig? geometry,
  }) => GlassProfile(
    nav: nav ?? this.nav,
    app: app ?? this.app,
    geometry: geometry ?? this.geometry,
  );

  Map<String, dynamic> toJson() => {
    'nav': nav.toJson(),
    'app': app.toJson(),
    'geometry': geometry.toJson(),
  };

  factory GlassProfile.fromJson(Object? raw) {
    if (raw is! Map) return const GlassProfile();
    return GlassProfile(
      nav: GlassConfig.fromJson(raw['nav']),
      app: GlassConfig.fromJson(raw['app']),
      geometry: GlassConfig.fromJson(raw['geometry']),
    );
  }

  static GlassProfile lerp(GlassProfile a, GlassProfile b, double t) =>
      GlassProfile(
        nav: GlassConfig.lerp(a.nav, b.nav, t),
        app: GlassConfig.lerp(a.app, b.app, t),
        geometry: GlassConfig.lerp(a.geometry, b.geometry, t),
      );

  @override
  bool operator ==(Object other) =>
      other is GlassProfile &&
      other.nav == nav &&
      other.app == app &&
      other.geometry == geometry;

  @override
  int get hashCode => Object.hash(nav, app, geometry);
}

/// A named look — one of the two shipped ones, or a slot the user saved.
@immutable
class GlassPreset {
  const GlassPreset({
    required this.id,
    required this.name,
    required this.profile,
    this.builtIn = false,
  });

  final String id;
  final String name;
  final GlassProfile profile;

  /// Built-ins can be selected but not renamed, overwritten or deleted.
  final bool builtIn;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'profile': profile.toJson(),
  };

  /// Returns null for anything that isn't a usable slot, so one bad entry
  /// drops out of the list instead of taking the other slots with it.
  static GlassPreset? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    return GlassPreset(
      id: id,
      name: sanitizeSlotName(name),
      profile: GlassProfile.fromJson(raw['profile']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GlassPreset &&
      other.id == id &&
      other.name == name &&
      other.profile == profile &&
      other.builtIn == builtIn;

  @override
  int get hashCode => Object.hash(id, name, profile, builtIn);
}

/// Most slots a user can keep.
///
/// Capped because the whole list lives in one keychain value, and an unbounded
/// one is a slow way to make every cold start worse.
const kMaxGlassSlots = 8;

/// Longest slot name kept. Trimmed rather than rejected — a long name is a
/// user being expressive, not a user making a mistake.
const kMaxSlotNameLength = 24;

String sanitizeSlotName(String raw) {
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (collapsed.length <= kMaxSlotNameLength) return collapsed;
  return collapsed.substring(0, kMaxSlotNameLength).trimRight();
}

/// The look the app ships with, and the one it ships as an alternative.
///
/// `frosted` is the default: readable over anything, no colour trickery, the
/// bar clearly a surface. `clear` is the see-through tuning — thin fill, barely
/// any blur, and the colour behind boosted so it actually reads as content
/// rather than as haze. It is deliberately not the default; it looks its best
/// over busy, colourful content and its worst over a plain one.
const kBuiltInGlassPresets = <GlassPreset>[
  GlassPreset(
    id: 'frosted',
    name: 'Frosted',
    builtIn: true,
    profile: GlassProfile(
      nav: GlassConfig(<String, double>{'frost': 0.45, 'blur': 10}),
    ),
  ),
  GlassPreset(
    id: 'clear',
    name: 'Clear',
    builtIn: true,
    profile: GlassProfile(
      nav: GlassConfig(<String, double>{
        'frost': 0.3,
        'blur': 5,
        'saturation': 1.7,
      }),
    ),
  ),
];

/// The preset a fresh install starts on.
const kDefaultGlassPresetId = 'frosted';
