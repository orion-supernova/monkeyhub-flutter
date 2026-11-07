import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../l10n/generated/app_localizations.dart';
import 'glass_config.dart' show GlassKnob;

/// The shader glass kit's own dials (Settings › Glass, when "Shader glass" is
/// chosen). Same [GlassKnob] vocabulary as the Frosted kit's dials so the
/// panel renders itself from the table, but a separate store key and a
/// separate config: the two engines do not share optics.
const kShaderThickness = GlassKnob(
  id: 'thickness',
  label: 'Thickness',
  hint: 'How thick the lens is. Thicker glass bends what is behind it more.',
  min: 0,
  max: 60,
  standard: 20,
  decimals: 0,
);
const kShaderBlur = GlassKnob(
  id: 'blur',
  label: 'Blur',
  hint: 'How much the backdrop is softened behind the glass.',
  min: 0,
  max: 24,
  standard: 6,
  decimals: 1,
);
const kShaderRefraction = GlassKnob(
  id: 'refraction',
  label: 'Refraction',
  hint: 'Refractive index of the glass. 1 is air, higher bends light harder.',
  min: 1,
  max: 2,
  standard: 1.2,
);
const kShaderChromatic = GlassKnob(
  id: 'chromatic',
  label: 'Chromatic aberration',
  hint: 'Splits colours at the rim into a faint rainbow fringe.',
  min: 0,
  max: 0.12,
  standard: 0.01,
  decimals: 3,
);
const kShaderLight = GlassKnob(
  id: 'light',
  label: 'Light intensity',
  hint: 'How bright the specular highlight on the rim is.',
  min: 0,
  max: 1.5,
  standard: 0.5,
);
const kShaderAngle = GlassKnob(
  id: 'angle',
  label: 'Light angle',
  hint: 'Where the light comes from, in degrees round the glass.',
  min: 0,
  max: 360,
  standard: 135,
  decimals: 0,
);
const kShaderSaturation = GlassKnob(
  id: 'saturation',
  label: 'Saturation',
  hint: 'Colour boost on what shows through. 1 leaves it unchanged.',
  min: 0.5,
  max: 2.5,
  standard: 1.3,
);
const kShaderTint = GlassKnob(
  id: 'tint',
  label: 'Tint',
  hint: 'How strongly the glass is washed with white, or smoke on dark pages.',
  min: 0,
  max: 1,
  standard: 0.15,
);
const kShaderRim = GlassKnob(
  id: 'rim',
  label: 'Rim light',
  hint: 'A thin lit edge, brightest along the top.',
  min: 0,
  max: 1,
  standard: 0.2,
);

/// Every dial, in panel order.
const kShaderKnobs = <GlassKnob>[
  kShaderThickness,
  kShaderBlur,
  kShaderRefraction,
  kShaderChromatic,
  kShaderLight,
  kShaderAngle,
  kShaderRim,
  kShaderSaturation,
  kShaderTint,
];

String shaderKnobLabel(AppLocalizations l10n, GlassKnob knob) =>
    switch (knob.id) {
      'thickness' => l10n.shaderKnobLabelThickness,
      'blur' => l10n.shaderKnobLabelBlur,
      'refraction' => l10n.shaderKnobLabelRefraction,
      'chromatic' => l10n.shaderKnobLabelChromatic,
      'light' => l10n.shaderKnobLabelLight,
      'angle' => l10n.shaderKnobLabelAngle,
      'saturation' => l10n.shaderKnobLabelSaturation,
      'tint' => l10n.shaderKnobLabelTint,
      'rim' => l10n.shaderKnobLabelRim,
      _ => knob.label,
    };

String shaderKnobHint(AppLocalizations l10n, GlassKnob knob) =>
    switch (knob.id) {
      'thickness' => l10n.shaderKnobHintThickness,
      'blur' => l10n.shaderKnobHintBlur,
      'refraction' => l10n.shaderKnobHintRefraction,
      'chromatic' => l10n.shaderKnobHintChromatic,
      'light' => l10n.shaderKnobHintLight,
      'angle' => l10n.shaderKnobHintAngle,
      'saturation' => l10n.shaderKnobHintSaturation,
      'tint' => l10n.shaderKnobHintTint,
      'rim' => l10n.shaderKnobHintRim,
      _ => knob.hint,
    };

/// The shader glass look: a sparse map of the dials moved off standard, plus
/// the one switch ([fullLens]). Value type, stored as one JSON string.
@immutable
class ShaderGlassConfig {
  const ShaderGlassConfig({
    this.values = const {},
    this.fullLens = false,
  });

  /// Only dials moved off [GlassKnob.standard]; unknown ids are dropped on read.
  final Map<String, double> values;

  /// Full lens refraction (the library's premium multi-pass shader) instead of
  /// the lightweight one. Prettier, much more GPU: off by default, and forced
  /// off on low-tier devices and in Power Saving.
  final bool fullLens;

  double of(GlassKnob k) => values[k.id] ?? k.standard;

  bool get isStandard => values.isEmpty && !fullLens;

  ShaderGlassConfig with_(GlassKnob k, double v) {
    final c = k.clampValue(v);
    final next = Map<String, double>.of(values);
    if ((c - k.standard).abs() < 1e-9) {
      next.remove(k.id);
    } else {
      next[k.id] = c;
    }
    return ShaderGlassConfig(values: next, fullLens: fullLens);
  }

  ShaderGlassConfig withFullLens(bool v) =>
      ShaderGlassConfig(values: values, fullLens: v);

  String encode() => jsonEncode({'v': values, 'fullLens': fullLens});

  static ShaderGlassConfig decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ShaderGlassConfig();
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return const ShaderGlassConfig();
      final v = <String, double>{};
      final src = m['v'];
      if (src is Map) {
        for (final k in kShaderKnobs) {
          final x = src[k.id];
          if (x is num) {
            final c = k.clampValue(x.toDouble());
            if ((c - k.standard).abs() > 1e-9) v[k.id] = c;
          }
        }
      }
      return ShaderGlassConfig(values: v, fullLens: m['fullLens'] == true);
    } catch (_) {
      return const ShaderGlassConfig();
    }
  }

  /// The engine settings for every control and surface: Swirl's chrome
  /// recipe (`tintedGlass(Colors.transparent)` there). The package's own
  /// glass, not the iOS 27 preset: a clear body, a light blur (5, plus 4 at
  /// Swirl's mid glass level), thickness 20, the adaptive body that keeps
  /// text behind readable, and no drawn rim. The iOS 27 preset's rim light
  /// and shade read as a white outline on a dark page; Swirl keeps that
  /// preset for the tab bar alone ([nativeSettings]).
  ///
  /// The dials scale this the same way they scale [nativeSettings].
  LiquidGlassSettings settings({
    required bool isLight,
    Color? color,
    double tintBoost = 0,
    bool lowPower = false,
  }) {
    double scale(GlassKnob k, double preset) =>
        k.standard == 0 ? preset : preset * of(k) / k.standard;
    bool moved(GlassKnob k) => values.containsKey(k.id);
    const level = 0.5;
    final wash = color ??
        Color.fromRGBO(
          255,
          255,
          255,
          ((0x14 / 0xFF) * of(kShaderTint) / kShaderTint.standard * level +
                  tintBoost)
              .clamp(0.0, 1.0),
        );
    const base = LiquidGlassSettings();
    return base.copyWith(
      glassColor: wash,
      blur: scale(kShaderBlur, 5 + 4 * level),
      thickness: scale(kShaderThickness, 20),
      saturation: moved(kShaderSaturation) ? of(kShaderSaturation) : base.saturation,
      lightIntensity:
          moved(kShaderLight) ? of(kShaderLight) : base.lightIntensity,
      lightAngle: moved(kShaderAngle)
          ? of(kShaderAngle) * math.pi / 180
          : base.lightAngle,
      refractiveIndex:
          moved(kShaderRefraction) ? of(kShaderRefraction) : base.refractiveIndex,
      chromaticAberration: lowPower
          ? 0
          : (moved(kShaderChromatic)
              ? of(kShaderChromatic)
              : base.chromaticAberration),
      bodyMode: color != null ? GlassBodyMode.clear : GlassBodyMode.adaptive,
    );
  }

  /// The tab bar's settings: the package's iOS 27 glass in Swirl's "clear
  /// native" form (a light wash, a light frost, the paraxial lens that bends
  /// only in a soft band at the rim), so the kit reads as clear refracting
  /// glass and not as frost.
  ///
  /// The dials move that look. A dial at its standard leaves the preset
  /// alone; moved, it scales (thickness, blur as frost, tint, rim, light,
  /// saturation) or replaces (refraction, chromatic aberration, light angle)
  /// the preset's own value. [isLight] picks `ios27Light` or `ios27Dark`;
  /// [tintBoost] adds wash (a pressed control); [lowPower] drops the colour
  /// split.
  LiquidGlassSettings nativeSettings({
    required bool isLight,
    Color? color,
    double tintBoost = 0,
    bool lowPower = false,
  }) {
    double scale(GlassKnob k, double preset) =>
        k.standard == 0 ? preset : preset * of(k) / k.standard;
    bool moved(GlassKnob k) => values.containsKey(k.id);
    final base =
        isLight ? LiquidGlassSettings.ios27Light : LiquidGlassSettings.ios27Dark;
    final washAlpha = (0x14 / 0xFF * of(kShaderTint) / kShaderTint.standard)
        .clamp(0.0, 1.0);
    // Swirl's glass level at its shipped default (0.5, between Clear and
    // Tinted): halfway to a milky wash in light, a smoky one in dark, with
    // extra frost. iOS 26's own glass is not fully Clear, and pure Clear
    // glass over a dark page reads as a white outline.
    const level = 0.5;
    final clear = Color.fromRGBO(255, 255, 255, washAlpha);
    final tinted = isLight ? const Color(0x80FFFFFF) : const Color(0x73000000);
    final wash = color ?? Color.lerp(clear, tinted, level)!;
    return base.copyWith(
      glassColor: tintBoost > 0 && color == null
          ? wash.withValues(alpha: (wash.a + tintBoost).clamp(0.0, 1.0))
          : wash,
      thickness: scale(kShaderThickness, 32),
      frost: scale(kShaderBlur, 1.5 + 10 * 0.5),
      saturation: scale(kShaderSaturation, 1.6),
      rimLight: scale(kShaderRim, 0.5).clamp(0.0, 2.0),
      rimShade: 0.5,
      lightIntensity:
          moved(kShaderLight) ? of(kShaderLight) : base.lightIntensity,
      lightAngle: moved(kShaderAngle)
          ? of(kShaderAngle) * math.pi / 180
          : base.lightAngle,
      refractiveIndex:
          moved(kShaderRefraction) ? of(kShaderRefraction) : base.refractiveIndex,
      chromaticAberration: lowPower
          ? 0
          : (moved(kShaderChromatic) ? of(kShaderChromatic) : 0),
      bodyMode: color != null ? GlassBodyMode.clear : base.bodyMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShaderGlassConfig &&
      other.fullLens == fullLens &&
      mapEquals(other.values, values);

  @override
  int get hashCode => Object.hash(fullLens, Object.hashAllUnordered(
        values.entries.map((e) => Object.hash(e.key, e.value)),
      ));
}
