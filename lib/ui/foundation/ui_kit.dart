import 'package:flutter/widgets.dart';

import '../../data/settings_store.dart';
import '../../theme/perf_tier.dart';
import 'caps.dart';

/// Which family of controls the app is drawn with.
///
/// ONE setting, resolved ONCE, read everywhere through [UiKit.of]. Every
/// shared component (buttons, fields, pills, surfaces, switches…) keeps its
/// behaviour — semantics, focus, hover hint, shortcut, haptic, disabled state
/// — in one place and only swaps its PIXELS per kit, via [KitSwitch] /
/// [kitValue]. Add logic once, and every kit gets it.
///
/// See `docs/architecture/ui-architecture.html` §4 before adding a kit or a
/// component.
enum UiKit {
  /// MonkeyHub's own frosted glass, the same on every platform and tunable in
  /// Settings › Glass. The reference kit: every other kit falls back to it for
  /// any component it does not draw itself.
  glass,

  /// Apple's Liquid Glass (iOS 26+). The OS draws what it can (the tab bar
  /// today, as a sibling `UITabBar`, never a platform view inside a list);
  /// app-drawn glass switches to the native-matched recipe.
  liquid,

  /// Android's own design language: Flutter's Material 3 widgets, dressed in
  /// the current app theme's colours and fonts (`lib/ui/kits/material/`).
  /// Android only: [UiKits.available] is false everywhere else. The one kit
  /// with ripples.
  material,

  /// The low-end kit: no backdrop blur anywhere, opaque plates, no drop
  /// shadows. Same shapes, sizes and motion vocabulary, a fraction of the GPU
  /// cost. Offered everywhere; picked automatically on low-RAM phones.
  lite,

  /// Glass drawn by a GPU fragment shader (the vendored `liquid_glass_widgets`
  /// engine): a real lens that refracts and splits light, tuned by its own
  /// dials in Settings › Glass. Android and iOS only, because the shader
  /// pipeline is a mobile-GPU path; never chosen by Automatic. If the shader
  /// cannot start, [UiKits.available] turns false and the app is drawn as
  /// [glass].
  shader;

  /// The kit the nearest [UiKitScope] resolved, or the app-wide resolution
  /// where there is no scope (tests, previews, overlays built before the app).
  /// Whether this subtree draws native iOS controls (see
  /// [UiKits.nativeControls]); only meaningful under [UiKit.liquid].
  static bool nativeControlsOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_UiKitInherited>()
          ?.nativeControls ??
      UiKits.nativeControls;

  static UiKit of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UiKitInherited>()?.kit ??
      UiKits.current;

  /// Whether this kit draws backdrop blur at all.
  bool get blurs => this == glass || this == liquid || this == shader;

  /// The kit a component falls back to when it has no skin for this one.
  /// Every chain ends at [glass], the reference kit.
  UiKit get fallback => switch (this) {
    UiKit.glass => UiKit.glass,
    UiKit.liquid => UiKit.glass,
    UiKit.material => UiKit.glass,
    UiKit.lite => UiKit.glass,
    UiKit.shader => UiKit.glass,
  };
}

/// Resolution of the user's [UiKit] choice against what this device can do.
abstract final class UiKits {
  /// Whether the [UiKit.liquid] kit draws REAL iOS controls (SwiftUI via
  /// `lib/ui/native/native_control.dart`) for every control with a native
  /// form, rather than only the tab bar: the user's Settings › Glass ›
  /// Native controls choice ([NativeScope]), on a device that has Liquid
  /// Glass. Components ask `NativeControl.readyIn(context)`.
  static bool get nativeControls =>
      debugNativeControls ??
      (Caps.nativeGlass &&
          SettingsStore.instance.nativeScope == NativeScope.everything);

  /// Forces [nativeControls] for a test or a preview. Null clears it.
  @visibleForTesting
  static bool? debugNativeControls;

  /// The Material kit has skins for the core components (button, icon button,
  /// field, search, switch, segmented, chip, check, slider, spinner, sheet,
  /// surface). It is drawn on Android only; see [available].
  static const bool materialReady = true;

  /// Whether [kit] can be drawn on this device right now.
  static bool available(UiKit kit) => switch (kit) {
    UiKit.glass => true,
    UiKit.lite => true,
    UiKit.liquid => Caps.nativeGlass,
    UiKit.material => materialReady && Caps.android,
    UiKit.shader => shaderUsable && (Caps.android || Caps.iOS),
  };

  /// Whether the shader engine started. Flipped off by `ShaderGlassEngine`
  /// when a shader fails to compile or load, which silently returns the app
  /// to [UiKit.glass]. Tests set it directly.
  static bool shaderUsable = true;

  /// The kits Settings offers, in display order.
  static List<UiKit> get offered => [
    for (final k in const [
      UiKit.liquid,
      UiKit.material,
      UiKit.glass,
      UiKit.shader,
      UiKit.lite,
    ])
      if (available(k)) k,
  ];

  /// What "Automatic" means on this device:
  /// iOS 26+ → [UiKit.liquid]; a low-RAM phone → [UiKit.lite]; Android →
  /// [UiKit.material]; everything else → [UiKit.glass]. Never [UiKit.shader]:
  /// that one is an explicit opt-in.
  static UiKit get automatic => resolve(null);

  /// Pure resolution, so it can be tested without a device.
  @visibleForTesting
  static UiKit resolveWith(
    UiKit? choice, {
    required bool nativeGlass,
    required bool lowTier,
    required bool android,
    bool materialReady = UiKits.materialReady,
    bool mobile = false,
  }) {
    bool can(UiKit k) => switch (k) {
      UiKit.glass || UiKit.lite => true,
      UiKit.liquid => nativeGlass,
      UiKit.material => materialReady && android,
      UiKit.shader => mobile && UiKits.shaderUsable,
    };
    if (choice != null && can(choice)) return choice;
    if (nativeGlass) return UiKit.liquid;
    if (lowTier) return UiKit.lite;
    if (android && materialReady) return UiKit.material;
    return UiKit.glass;
  }

  /// What Automatic resolves to under test. `flutter_test` reports android,
  /// so without this every widget test would draw the Material kit;
  /// test/flutter_test_config.dart sets it to [UiKit.glass], the reference
  /// kit. An explicit choice in the store still wins, so kit tests work.
  @visibleForTesting
  static UiKit? debugAutomatic;

  /// [choice] (null = automatic) resolved for this device.
  static UiKit resolve(UiKit? choice) {
    final auto = debugAutomatic;
    if (auto != null && (choice == null || !available(choice))) return auto;
    return _resolveHere(choice);
  }

  static UiKit _resolveHere(UiKit? choice) => resolveWith(
    choice,
    nativeGlass: Caps.nativeGlass,
    lowTier: Perf.low,
    android: Caps.android,
    mobile: Caps.android || Caps.iOS,
  );

  static UiKit? _debugOverride;

  /// Forces a kit for a test or a design preview. Null clears it.
  @visibleForTesting
  static set debugKit(UiKit? kit) => _debugOverride = kit;

  /// The kit the app is drawn with right now.
  static UiKit get current =>
      _debugOverride ?? resolve(SettingsStore.instance.uiKit);
}

/// Publishes the resolved [UiKit] to the tree. Sits once near the app root;
/// rebuilds dependants only when the RESOLVED kit changes, not on every
/// settings write.
class UiKitScope extends StatelessWidget {
  const UiKitScope({super.key, required this.child, this.kit});

  final Widget child;

  /// Pins a kit for this subtree (a settings preview of another kit).
  final UiKit? kit;

  @override
  Widget build(BuildContext context) {
    final pinned = kit;
    if (pinned != null) {
      return _UiKitInherited(
        kit: pinned,
        nativeControls: UiKits.nativeControls,
        child: child,
      );
    }
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, child) => _UiKitInherited(
        kit: UiKits.current,
        nativeControls: UiKits.nativeControls,
        child: child!,
      ),
      child: child,
    );
  }
}

class _UiKitInherited extends InheritedWidget {
  const _UiKitInherited({
    required this.kit,
    required this.nativeControls,
    required super.child,
  });

  final UiKit kit;
  final bool nativeControls;

  @override
  bool updateShouldNotify(_UiKitInherited old) =>
      old.kit != kit || old.nativeControls != nativeControls;
}

/// Builds the skin for the current kit, walking [UiKit.fallback] until a skin
/// exists. [glass] is required: it is the reference every kit falls back to.
///
/// ```dart
/// return KitSwitch(
///   glass: (context) => _GlassSkin(spec),
///   lite: (context) => _LiteSkin(spec),
/// );
/// ```
class KitSwitch extends StatelessWidget {
  const KitSwitch({
    super.key,
    required this.glass,
    this.liquid,
    this.material,
    this.lite,
    this.shader,
  });

  final WidgetBuilder glass;
  final WidgetBuilder? liquid;
  final WidgetBuilder? material;
  final WidgetBuilder? lite;
  final WidgetBuilder? shader;

  @override
  Widget build(BuildContext context) => kitValue<WidgetBuilder>(
    UiKit.of(context),
    glass: glass,
    liquid: liquid,
    material: material,
    lite: lite,
    shader: shader,
  )(context);
}

/// A per-kit VALUE (a radius, a size, a duration, a colour) with the same
/// fallback walk as [KitSwitch].
T kitValue<T>(
  UiKit kit, {
  required T glass,
  T? liquid,
  T? material,
  T? lite,
  T? shader,
}) {
  var k = kit;
  while (true) {
    final v = switch (k) {
      UiKit.glass => glass,
      UiKit.liquid => liquid,
      UiKit.material => material,
      UiKit.lite => lite,
      UiKit.shader => shader,
    };
    if (v != null || k == UiKit.glass) return v as T;
    k = k.fallback;
  }
}
