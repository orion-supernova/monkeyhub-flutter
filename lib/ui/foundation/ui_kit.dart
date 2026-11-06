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

  /// Android's own design language. Not built yet: [UiKits.available] says
  /// false, so it is never resolved and never offered.
  material,

  /// The low-end kit: no backdrop blur anywhere, opaque plates, no drop
  /// shadows. Same shapes, sizes and motion vocabulary, a fraction of the GPU
  /// cost. Offered everywhere; picked automatically on low-RAM phones.
  lite;

  /// The kit the nearest [UiKitScope] resolved, or the app-wide resolution
  /// where there is no scope (tests, previews, overlays built before the app).
  static UiKit of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_UiKitInherited>()?.kit ??
      UiKits.current;

  /// Whether this kit draws backdrop blur at all.
  bool get blurs => this == glass || this == liquid;

  /// The kit a component falls back to when it has no skin for this one.
  /// Every chain ends at [glass], the reference kit.
  UiKit get fallback => switch (this) {
    UiKit.glass => UiKit.glass,
    UiKit.liquid => UiKit.glass,
    UiKit.material => UiKit.glass,
    UiKit.lite => UiKit.glass,
  };
}

/// Resolution of the user's [UiKit] choice against what this device can do.
abstract final class UiKits {
  /// Flip to true once the Material kit has skins for the core components
  /// (button, icon button, field, search, switch, segmented, surface).
  static const bool materialReady = false;

  /// Whether [kit] can be drawn on this device right now.
  static bool available(UiKit kit) => switch (kit) {
    UiKit.glass => true,
    UiKit.lite => true,
    UiKit.liquid => Caps.nativeGlass,
    UiKit.material => materialReady,
  };

  /// The kits Settings offers, in display order.
  static List<UiKit> get offered => [
    for (final k in const [UiKit.liquid, UiKit.material, UiKit.glass, UiKit.lite])
      if (available(k)) k,
  ];

  /// What "Automatic" means on this device:
  /// iOS 26+ → [UiKit.liquid]; a low-RAM phone → [UiKit.lite]; Android once
  /// its kit ships → [UiKit.material]; everything else → [UiKit.glass].
  static UiKit get automatic => resolve(null);

  /// Pure resolution, so it can be tested without a device.
  @visibleForTesting
  static UiKit resolveWith(
    UiKit? choice, {
    required bool nativeGlass,
    required bool lowTier,
    required bool android,
    bool materialReady = UiKits.materialReady,
  }) {
    bool can(UiKit k) => switch (k) {
      UiKit.glass || UiKit.lite => true,
      UiKit.liquid => nativeGlass,
      UiKit.material => materialReady,
    };
    if (choice != null && can(choice)) return choice;
    if (nativeGlass) return UiKit.liquid;
    if (lowTier) return UiKit.lite;
    if (android && materialReady) return UiKit.material;
    return UiKit.glass;
  }

  /// [choice] (null = automatic) resolved for this device.
  static UiKit resolve(UiKit? choice) => resolveWith(
    choice,
    nativeGlass: Caps.nativeGlass,
    lowTier: Perf.low,
    android: Caps.android,
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
    if (pinned != null) return _UiKitInherited(kit: pinned, child: child);
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, child) =>
          _UiKitInherited(kit: UiKits.current, child: child!),
      child: child,
    );
  }
}

class _UiKitInherited extends InheritedWidget {
  const _UiKitInherited({required this.kit, required super.child});

  final UiKit kit;

  @override
  bool updateShouldNotify(_UiKitInherited old) => old.kit != kit;
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
  });

  final WidgetBuilder glass;
  final WidgetBuilder? liquid;
  final WidgetBuilder? material;
  final WidgetBuilder? lite;

  @override
  Widget build(BuildContext context) => kitValue<WidgetBuilder>(
    UiKit.of(context),
    glass: glass,
    liquid: liquid,
    material: material,
    lite: lite,
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
}) {
  var k = kit;
  while (true) {
    final v = switch (k) {
      UiKit.glass => glass,
      UiKit.liquid => liquid,
      UiKit.material => material,
      UiKit.lite => lite,
    };
    if (v != null || k == UiKit.glass) return v as T;
    k = k.fallback;
  }
}
