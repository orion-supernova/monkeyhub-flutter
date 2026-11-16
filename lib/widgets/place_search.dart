import 'package:flutter/services.dart';

import '../ui/foundation/caps.dart';

/// A place found by [PlaceSearch].
class PlaceResult {
  const PlaceResult({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  static PlaceResult? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['latitude'];
    final lng = raw['longitude'];
    if (lat is! num || lng is! num) return null;
    return PlaceResult(
      title: (raw['title'] as String?) ?? '',
      subtitle: (raw['subtitle'] as String?) ?? '',
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
    );
  }
}

/// Place search for the location picker, using only what the OS gives away:
///
///  * iOS and macOS: MapKit's MKLocalSearch for search, and points of
///    interest around the pin for "Nearby places". Free, no key.
///  * Android: the system Geocoder for address search. Nearby places would
///    need Google Places, which is billed per request, so there are none.
///  * Windows, Linux, web: no OS search; the picker is pin-and-send.
abstract final class PlaceSearch {
  static const _channel = MethodChannel('monkeyhub/map_snapshot');

  static bool get searchSupported => Caps.systemMaps;
  static bool get nearbySupported => Caps.nativeApple;

  static Future<List<PlaceResult>> search(
    String query,
    double latitude,
    double longitude,
  ) => _list('search', {
    'query': query,
    'latitude': latitude,
    'longitude': longitude,
  }, enabled: searchSupported && query.trim().isNotEmpty);

  static Future<List<PlaceResult>> nearby(double latitude, double longitude) =>
      _list('nearby', {
        'latitude': latitude,
        'longitude': longitude,
        'radius': 300.0,
      }, enabled: nearbySupported);

  static Future<List<PlaceResult>> _list(
    String method,
    Map<String, Object?> args, {
    required bool enabled,
  }) async {
    if (!enabled) return const [];
    try {
      final raw = await _channel.invokeListMethod<Object?>(method, args);
      return [
        for (final r in raw ?? const <Object?>[])
          ?PlaceResult.fromMap(r),
      ];
    } catch (_) {
      return const [];
    }
  }
}
