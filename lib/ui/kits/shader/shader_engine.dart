import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../foundation/caps.dart';
import '../../foundation/ui_kit.dart';

/// Starts the vendored `liquid_glass_widgets` shader engine, once, on Android
/// and iOS only. Any failure (a shader that will not compile, an unsupported
/// GPU) turns [UiKits.shaderUsable] off, so [UiKit.shader] stops being
/// offered and the app is drawn as [UiKit.glass]. Never throws.
abstract final class ShaderGlassEngine {
  static bool _started = false;

  /// Idempotent. Safe to call unawaited; desktop and web return at once.
  static Future<void> ensureStarted() async {
    if (_started) return;
    _started = true;
    if (!(Caps.android || Caps.iOS)) return;
    // Under flutter_test the app's bundle has the shaders under
    // `packages/liquid_glass_widgets/`, where the library (which assumes it is
    // the package under test) does not look: its pre-warm would throw. The
    // surfaces still load their shader on demand and fall back by themselves.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
    } catch (e) {
      markFailed(e);
    }
  }

  /// Records that the engine cannot draw; the app falls back to glass.
  static void markFailed([Object? why]) {
    UiKits.shaderUsable = false;
    if (kDebugMode) debugPrint('[shaderGlass] unavailable, using glass: $why');
  }
}
