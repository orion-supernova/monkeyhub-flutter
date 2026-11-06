import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../data/shader_glass_config.dart';
import '../../../data/settings_store.dart';
import '../../../theme/low_power.dart';
import '../../../theme/perf_tier.dart';
import 'shader_engine.dart';

/// The [UiKit.shader] surface: [content] laid over glass drawn by the
/// `liquid_glass_widgets` engine, tuned by [ShaderGlassConfig].
///
/// Pure paint. Press, tap, focus, semantics, padding and size stay in
/// `LiquidGlass`, which owns them for every kit.
///
/// Performance: the default is the library's lightweight shader (one
/// `BackdropFilter` plus a small fragment pass per surface). The premium
/// multi-pass lens is used only when the user turned on full lens refraction
/// AND the device is not the low tier AND the app is not saving power.
/// Chromatic aberration is dropped in power saving. Any shader failure is
/// handled by the library's own fallback chain (frosted fallback), so a bad
/// GPU shows plain frosted glass, never a crash.
class ShaderGlassSurface extends StatelessWidget {
  const ShaderGlassSurface({
    super.key,
    required this.shape,
    required this.isLight,
    required this.content,
    this.color,
    this.pressed = false,
    this.shadow = true,
    this.config,
  });

  final LiquidShape shape;
  final bool isLight;
  final Widget content;

  /// A solid tint (a control that is on). Null is plain glass.
  final Color? color;
  final bool pressed;
  final bool shadow;

  /// Dials for this surface; null reads the user's, live.
  final ShaderGlassConfig? config;

  /// The quality tier the current device and power state allow.
  static GlassQuality qualityFor(ShaderGlassConfig cfg, {bool? saving}) {
    final calm = saving ?? LowPowerMode.active;
    if (cfg.fullLens && !Perf.low && !calm) return GlassQuality.premium;
    return GlassQuality.standard;
  }

  @override
  Widget build(BuildContext context) {
    // Idempotent; starts the shader pre-warm the first time a shader surface
    // is built (a no-op off Android and iOS).
    ShaderGlassEngine.ensureStarted();
    final cfg = config ?? SettingsStore.instance.shaderGlass;
    final calm = LowPowerMode.active;
    final settings = cfg.settings(
      isLight: isLight,
      color: color,
      tintBoost: pressed ? 0.12 : 0,
      lowPower: calm || Perf.low,
    );
    return AdaptiveGlass(
      shape: shape,
      settings: settings,
      quality: qualityFor(cfg, saving: calm),
      allowElevation: shadow,
      isInteractive: true,
      child: content,
    );
  }
}
