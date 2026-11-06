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

  /// The engine settings. [isLight] is the page's brightness (tint is white on
  /// light pages and smoke on dark), [boost] scales the tint (a pressed or
  /// `tinted` control), [lowPower] drops the optional extras.
  LiquidGlassSettings settings({
    required bool isLight,
    Color? color,
    double tintBoost = 0,
    bool lowPower = false,
  }) {
    final tint = of(kShaderTint);
    final base = color ??
        (isLight
            ? const Color(0xFFFFFFFF).withValues(alpha: (tint * 0.8).clamp(0, 1))
            : const Color(0xFFFFFFFF).withValues(alpha: (tint * 0.35).clamp(0, 1)));
    return LiquidGlassSettings(
      glassColor: tintBoost > 0 && color == null
          ? base.withValues(alpha: (base.a + tintBoost).clamp(0.0, 1.0))
          : base,
      thickness: of(kShaderThickness),
      blur: of(kShaderBlur),
      refractiveIndex: of(kShaderRefraction),
      chromaticAberration: lowPower ? 0 : of(kShaderChromatic),
      lightIntensity: of(kShaderLight),
      lightAngle: of(kShaderAngle) * math.pi / 180,
      saturation: of(kShaderSaturation),
      rimLight: of(kShaderRim),
      bodyMode: color != null ? GlassBodyMode.clear : GlassBodyMode.adaptive,
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
