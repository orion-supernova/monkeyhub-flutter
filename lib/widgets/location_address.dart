import 'package:flutter/services.dart';

import '../ui/foundation/caps.dart';

/// A street address for a coordinate, from the OS geocoder (Apple's
/// CLGeocoder on iOS and macOS, Android's Geocoder), shared by the location
/// bubbles and the full-screen map.
///
/// Cached in memory by position rounded to about 10 m, and deduplicated
/// while in flight, so a transcript of location bubbles asks once per place
/// (Apple rate-limits reverse geocoding per app). Windows, Linux and web have
/// no OS geocoder and get null; the callers show coordinates instead.
abstract final class LocationAddress {
  static const _channel = MethodChannel('monkeyhub/map_snapshot');
  static final Map<String, Future<({String title, String subtitle})?>> _cache =
      {};

  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  /// A finished lookup, if there is one, for a first frame without flicker.
  static final _done = <String, ({String title, String subtitle})?>{};

  static ({String title, String subtitle})? peek(double lat, double lng) =>
      _done[_key(lat, lng)];

  static Future<({String title, String subtitle})?> lookup(
    double lat,
    double lng,
  ) {
    if (!Caps.systemMaps) return Future.value();
    final key = _key(lat, lng);
    return _cache[key] ??= _fetch(lat, lng).then((r) {
      if (r == null) {
        _cache.remove(key); // Offline now may be online later.
      } else {
        _done[key] = r;
      }
      if (_cache.length > 200) {
        final oldest = _cache.keys.first;
        _cache.remove(oldest);
        _done.remove(oldest);
      }
      return r;
    });
  }

  static Future<({String title, String subtitle})?> _fetch(
    double lat,
    double lng,
  ) async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('geocode', {
        'latitude': lat,
        'longitude': lng,
      });
      if (r == null) return null;
      final title = (r['title'] as String?) ?? '';
      final subtitle = (r['subtitle'] as String?) ?? '';
      if (title.isEmpty && subtitle.isEmpty) return null;
      return (title: title, subtitle: subtitle);
    } catch (_) {
      return null;
    }
  }
}
