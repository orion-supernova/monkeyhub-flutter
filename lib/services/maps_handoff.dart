import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

@immutable
class MapApp {
  const MapApp(this.id, this.name);
  final String id;
  final String name;
}

/// App discovery never launches an app or sends coordinates. Android discovers
/// geo-intent handlers; iOS probes the supported apps' declared URL schemes.
class MapsHandoff {
  static const _channel = MethodChannel('monkeyhub/maps');
  static const browser = MapApp('browser', 'Browser');
  static const _iosApps = [
    MapApp('apple', 'Apple Maps'),
    MapApp('google', 'Google Maps'),
    MapApp('yandex', 'Yandex Maps'),
    MapApp('waze', 'Waze'),
  ];

  static Future<List<MapApp>> availableApps() async {
    final apps = <MapApp>[];
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final rows = await _channel.invokeListMethod<dynamic>('available');
        for (final row in rows ?? []) {
          if (row is Map && row['id'] is String && row['name'] is String) {
            apps.add(MapApp('android:${row['id']}', row['name'] as String));
          }
        }
      } catch (_) {
        /* Browser remains available if native discovery fails. */
      }
    } else if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      for (final app in _iosApps) {
        if (defaultTargetPlatform == TargetPlatform.macOS &&
            app.id != 'apple') {
          continue;
        }
        try {
          if (await launcher.canLaunchUrl(
            appUri(app.id, latitude: 0, longitude: 0),
          )) {
            apps.add(app);
          }
        } catch (_) {
          /* An uninstalled app is not offered. */
        }
      }
    }
    return [...apps, browser];
  }

  static bool validCoordinates(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  static Uri appUri(
    String id, {
    required double latitude,
    required double longitude,
    String? label,
  }) {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    final name = (label ?? '').trim();
    return switch (id) {
      'apple' => Uri(
        scheme: 'maps',
        host: '',
        queryParameters: {
          'll': '$lat,$lng',
          'q': name.isEmpty ? 'Shared location' : name,
        },
      ),
      'google' => Uri(
        scheme: 'comgooglemaps',
        host: '',
        queryParameters: {
          'q': '$lat,$lng',
          'center': '$lat,$lng',
          'zoom': '17',
        },
      ),
      // Yandex takes LONGITUDE first. pt adds a pin; ll centres the view.
      'yandex' => Uri(
        scheme: 'yandexmaps',
        host: 'maps.yandex.ru',
        path: '/',
        queryParameters: {'ll': '$lng,$lat', 'pt': '$lng,$lat', 'z': '17'},
      ),
      'waze' => Uri(
        scheme: 'waze',
        host: '',
        queryParameters: {'ll': '$lat,$lng', 'navigate': 'no', 'zoom': '17'},
      ),
      _ => Uri.parse(
        'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=17/$lat/$lng',
      ),
    };
  }

  static Future<bool> launch(
    MapApp app, {
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    if (!validCoordinates(latitude, longitude)) return false;
    try {
      if (app.id.startsWith('android:')) {
        return await _channel.invokeMethod<bool>('open', {
              'id': app.id.substring(8),
              'latitude': latitude,
              'longitude': longitude,
              'label': label ?? '',
            }) ??
            false;
      }
      return await launcher.launchUrl(
        appUri(app.id, latitude: latitude, longitude: longitude, label: label),
        mode: launcher.LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  // Compatibility for pure URI callers. Interactive location cards use the
  // app picker instead of silently opening the platform's first maps app.
  static List<Uri> candidateUris({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    final web = appUri('browser', latitude: latitude, longitude: longitude);
    if (kIsWeb) return [web];
    if (defaultTargetPlatform == TargetPlatform.android) {
      final lat = latitude.toStringAsFixed(6),
          lng = longitude.toStringAsFixed(6);
      final q = (label ?? '').trim().isEmpty
          ? '$lat,$lng'
          : '$lat,$lng(${label!.trim()})';
      return [
        Uri.parse('geo:$lat,$lng').replace(queryParameters: {'q': q}),
        web,
      ];
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return [
        appUri('apple', latitude: latitude, longitude: longitude, label: label),
        web,
      ];
    }
    return [web];
  }
}
