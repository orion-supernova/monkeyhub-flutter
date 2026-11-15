import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'map_engine.dart';
import 'open_free_map_snapshot.dart';

/// The street-map picture behind a location bubble, from the [MapEngine] in
/// use: Apple's `MKMapSnapshotter` (`ios/Runner/MapSnapshot.swift` and its
/// macOS twin), Google's lite-mode map on Android (`MapSnapshotBridge.kt`, same
/// channel), or OpenFreeMap tiles drawn in Dart ([OpenFreeMapSnapshot]). When
/// the OS maps fail, OpenFreeMap is tried before giving up.
///
/// Returns an [ImageProvider] rather than bytes, and hands back the SAME
/// provider for the same request, so Flutter's image cache decodes each map
/// once however many times the bubble is rebuilt (the live pulse rebuilds it
/// every frame).
///
/// In memory only, by design: MapKit already caches its tiles on disk, and a
/// snapshot is a few hundred milliseconds to remake, so persisting rendered
/// maps would just keep shared positions on disk for no visible gain.
abstract final class LocationMapSnapshot {
  static const _channel = MethodChannel('monkeyhub/map_snapshot');

  /// About a long transcript's worth of distinct places, each a few hundred KB.
  static const _capacity = 48;

  static final Map<String, Future<MapPicture?>> _cache = {}; // insertion-ordered
  static final _done = <String, MapPicture>{};

  static String keyFor({
    required double latitude,
    required double longitude,
    required double spanMeters,
    required Size size,
    required double scale,
    required bool dark,
    required MapEngine engine,
  }) =>
      '${engine.name},${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)},'
      '${spanMeters.round()},${size.width.round()}x${size.height.round()},'
      '${scale.toStringAsFixed(1)},${dark ? 'd' : 'l'}';

  /// A finished result for [key], if there is one: lets a rebuilt bubble show
  /// its map on the first frame instead of flashing the fallback.
  static MapPicture? ready(String key) => _done[key];

  static Future<MapPicture?> load({
    required String key,
    required MapEngine engine,
    required double latitude,
    required double longitude,
    required double spanMeters,
    required Size size,
    required double scale,
    required bool dark,
  }) {
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // Most recently used goes last.
      return hit;
    }
    final future =
        _fetch(engine, latitude, longitude, spanMeters, size, scale, dark)
            .then((provider) {
          if (provider == null) {
            // Don't remember a failure: offline now may be online next scroll.
            _cache.remove(key);
          } else if (_cache.containsKey(key)) {
            _done[key] = provider;
          }
          return provider;
        });
    _cache[key] = future;
    while (_cache.length > _capacity) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      _done.remove(oldest);
    }
    return future;
  }

  static Future<MapPicture?> _fetch(
    MapEngine engine,
    double latitude,
    double longitude,
    double spanMeters,
    Size size,
    double scale,
    bool dark,
  ) async {
    if (engine != MapEngine.openFreeMap) {
      final native = await _native(
        latitude,
        longitude,
        spanMeters,
        size,
        scale,
        dark,
      );
      if (native != null) return MapPicture(native, null);
    }
    final image = await OpenFreeMapSnapshot.render(
      latitude: latitude,
      longitude: longitude,
      spanMeters: spanMeters,
      size: size,
      scale: scale,
      dark: dark,
    );
    if (image == null) return null;
    // Encoded once so it rides the same ImageProvider cache as the OS PNGs.
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (png == null) return null;
    return MapPicture(
      MemoryImage(png.buffer.asUint8List(), scale: scale),
      OpenFreeMapSnapshot.attribution,
    );
  }

  static Future<ImageProvider?> _native(
    double latitude,
    double longitude,
    double spanMeters,
    Size size,
    double scale,
    bool dark,
  ) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('snapshot', {
        'latitude': latitude,
        'longitude': longitude,
        'spanMeters': spanMeters,
        'width': size.width.roundToDouble(),
        'height': size.height.roundToDouble(),
        'scale': scale,
        'dark': dark,
      });
      if (bytes == null || bytes.isEmpty) return null;
      return MemoryImage(bytes, scale: scale);
    } catch (_) {
      return null;
    }
  }
}

/// A rendered map and the credit its source requires drawn on it (null when
/// the OS map carries its own or needs none).
class MapPicture {
  const MapPicture(this.image, this.credit);
  final ImageProvider image;
  final String? credit;
}
