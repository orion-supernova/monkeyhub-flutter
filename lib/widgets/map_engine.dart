import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../ui/foundation/caps.dart';

/// Which renderer draws a shared location: the bubble's picture and the
/// full-screen map always come from the same one, so the two never disagree.
enum MapEngine {
  /// MapKit (iOS, macOS): `MapSnapshot.swift`, `MapViewFactory.swift`.
  appleMaps,

  /// Google Maps SDK (Android with Play Services and a key):
  /// `MapSnapshotBridge.kt`, `MapViewFactory.kt`.
  googleMaps,

  /// OpenStreetMap tiles from openfreemap.org, drawn in Dart. Everywhere, and
  /// the fallback whenever the OS maps are unavailable.
  openFreeMap,
}

/// Picks the [MapEngine] from the platform and [SettingsStore.mapSource].
abstract final class MapEngines {
  static const _channel = MethodChannel('monkeyhub/map_snapshot');

  static Future<bool>? _googleProbe;
  static bool? _googleReady;

  /// The OS maps' name for the settings choice, or null where there are none.
  /// Brand names, so not translated.
  static String? get systemName => Caps.nativeApple
      ? 'Apple Maps'
      : Caps.android
      ? 'Google Maps'
      : null;

  /// False on Android without Play Services or without a Maps key; null
  /// until the first check has answered.
  static bool? get googleReady => _googleReady;

  /// The engine to use now, if it can be known without waiting.
  static MapEngine? get current {
    if (!Caps.systemMaps ||
        SettingsStore.instance.mapSource == MapSource.openFreeMap) {
      return MapEngine.openFreeMap;
    }
    if (Caps.nativeApple) return MapEngine.appleMaps;
    final ready = _googleReady;
    if (ready == null) return null;
    return ready ? MapEngine.googleMaps : MapEngine.openFreeMap;
  }

  static Future<MapEngine> resolve() async {
    final known = current;
    if (known != null) return known;
    final ready = await (_googleProbe ??= _probeGoogle());
    return ready ? MapEngine.googleMaps : MapEngine.openFreeMap;
  }

  static Future<bool> _probeGoogle() async {
    try {
      return _googleReady =
          await _channel.invokeMethod<bool>('available') ?? false;
    } catch (_) {
      return _googleReady = false;
    }
  }

  @visibleForTesting
  static void debugReset() {
    _googleProbe = null;
    _googleReady = null;
  }
}
