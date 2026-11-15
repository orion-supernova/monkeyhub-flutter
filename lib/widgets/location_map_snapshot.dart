import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../ui/foundation/caps.dart';

/// The OS map picture behind a location bubble — Apple's `MKMapSnapshotter`
/// on iOS and macOS (`ios/Runner/MapSnapshot.swift` and its macOS twin).
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

  static final Map<String, Future<ImageProvider?>> _cache = {}; // insertion-ordered
  static final _done = <String, ImageProvider?>{};

  static bool get supported => Caps.mapSnapshots;

  static String keyFor({
    required double latitude,
    required double longitude,
    required double spanMeters,
    required Size size,
    required double scale,
    required bool dark,
  }) =>
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)},'
      '${spanMeters.round()},${size.width.round()}x${size.height.round()},'
      '${scale.toStringAsFixed(1)},${dark ? 'd' : 'l'}';

  /// A finished result for [key], if there is one: lets a rebuilt bubble show
  /// its map on the first frame instead of flashing the fallback.
  static ImageProvider? ready(String key) => _done[key];

  static Future<ImageProvider?> load({
    required String key,
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
    final future = _fetch(latitude, longitude, spanMeters, size, scale, dark)
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

  static Future<ImageProvider?> _fetch(
    double latitude,
    double longitude,
    double spanMeters,
    Size size,
    double scale,
    bool dark,
  ) async {
    if (!supported) return null;
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
