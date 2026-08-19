import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/services/map_apps.dart';

/// The maps-app catalogue and the URLs it builds.
///
/// Two kinds of test here, and the first is the one that earns its keep.
///
/// **The plist test** exists because iOS detection depends on one list stored
/// in two files — `kMapAppCatalog` and `LSApplicationQueriesSchemes` in
/// `ios/Runner/Info.plist` — and because getting that wrong produces no error
/// of any kind. `canOpenURL` returns false for an undeclared scheme exactly as
/// it does for an app that isn't installed, so a forgotten plist entry ships as
/// "nobody has that app", forever, on every device. Nothing in the compiler,
/// the analyzer or a running app would say otherwise. This test is the only
/// thing standing between that mistake and the App Store.
///
/// **The URL tests** pin coordinate order. Half these vendors take `lat,lng`
/// and half take `lng,lat`, and a transposed pair is not a crash — it is a pin
/// in the wrong hemisphere, which looks like working software. Every coordinate
/// below is deliberately asymmetric (latitude 41, longitude 28, and neither
/// near the other) so a swap cannot pass by coincidence, and they are on
/// opposite sides of zero from each other in sign-sensitive cases.
void main() {
  // Istanbul. Asymmetric in both magnitude and shape, so `41.0138,28.9497`
  // reversed reads as obviously wrong rather than plausibly different.
  const lat = 41.0138;
  const lng = 28.9497;

  group('catalogue integrity', () {
    test('every probe scheme is declared in Info.plist', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      // Read only the LSApplicationQueriesSchemes array, not the whole file.
      // Matching against the entire plist would let an unrelated string
      // elsewhere — a URL type, a bundle name — satisfy the assertion and hide
      // exactly the bug this test exists to catch.
      final start = plist.indexOf('<key>LSApplicationQueriesSchemes</key>');
      expect(
        start,
        isNot(-1),
        reason: 'Info.plist declares no LSApplicationQueriesSchemes array, so '
            'no maps app can ever be detected on iOS.',
      );
      final open = plist.indexOf('<array>', start);
      final close = plist.indexOf('</array>', open);
      final declared = RegExp(r'<string>([^<]+)</string>')
          .allMatches(plist.substring(open, close))
          .map((m) => m.group(1)!)
          .toSet();

      for (final app in kMapAppCatalog) {
        // `probe` is a scheme with its separator; the plist wants the bare name.
        final scheme = app.probe.replaceAll('://', '');
        expect(
          declared,
          contains(scheme),
          reason: '${app.name} (${app.id}) probes "$scheme", which is missing '
              'from LSApplicationQueriesSchemes. It will never be detected on '
              'any device, silently. Add it to ios/Runner/Info.plist.',
        );
      }
    });

    test('iOS caps the queries array at 50 entries', () {
      // Not a style rule — the 51st entry and beyond are ignored by the OS,
      // so exceeding this reintroduces the silent-undetectable failure for
      // whichever apps happen to fall off the end.
      expect(kMapAppCatalog.length, lessThanOrEqualTo(50));
    });

    test('ids are unique', () {
      final ids = kMapAppCatalog.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('the browser fallback is not in the catalogue', () {
      // It is never probed and is not a maps app; if it leaked into the
      // catalogue, `installed()` would report a browser as a detected map.
      expect(
        kMapAppCatalog.map((a) => a.id),
        isNot(contains(kBrowserFallback.id)),
      );
    });
  });

  group('coordinate order', () {
    MapApp app(String id) => kMapAppCatalog.firstWhere((a) => a.id == id);

    test('Apple Maps puts lat,lng in ll', () {
      final uri = app('apple').build(lat, lng, 'ada');
      expect(uri.toString(), contains('ll=41.013800,28.949700'));
      expect(uri.scheme, 'maps');
    });

    test('Google Maps names the pin in parentheses', () {
      final uri = app('google').build(lat, lng, 'ada');
      expect(uri.toString(), contains('q=41.013800,28.949700(ada)'));
      expect(uri.toString(), contains('center=41.013800,28.949700'));
    });

    test('Yandex Maps takes lng,lat — reversed from everything else', () {
      final uri = app('yandexMaps').build(lat, lng, 'ada');
      expect(uri.toString(), contains('pt=28.949700,41.013800'));
    });

    test('Yandex Navigator takes them apart, lat then lon', () {
      final uri = app('yandexNavi').build(lat, lng, 'ada');
      expect(uri.toString(), contains('lat=41.013800'));
      expect(uri.toString(), contains('lon=28.949700'));
    });

    test('2GIS takes lng,lat in the path', () {
      final uri = app('doubleGis').build(lat, lng, 'ada');
      expect(uri.toString(), endsWith('/geo/28.949700,41.013800'));
    });

    test('TMap takes x=lng, y=lat', () {
      final uri = app('tmap').build(lat, lng, 'ada');
      expect(uri.toString(), contains('x=28.949700'));
      expect(uri.toString(), contains('y=41.013800'));
    });

    test('Organic Maps and MAPS.ME differ only in scheme', () {
      final om = app('organic').build(lat, lng, 'ada');
      final mm = app('mapswithme').build(lat, lng, 'ada');
      expect(om.scheme, 'om');
      expect(mm.scheme, 'mapsme');
      expect(om.toString().substring(om.scheme.length),
          mm.toString().substring(mm.scheme.length));
    });

    test('every entry carries both coordinates somewhere', () {
      for (final a in kMapAppCatalog) {
        final s = a.build(lat, lng, 'ada').toString();
        expect(s, contains('41.0138'), reason: '${a.id} drops the latitude');
        expect(s, contains('28.9497'), reason: '${a.id} drops the longitude');
      }
    });
  });

  group('labels', () {
    MapApp app(String id) => kMapAppCatalog.firstWhere((a) => a.id == id);

    test('a name with characters that break a URL is encoded', () {
      // Sender names are free text and routinely contain spaces, ampersands
      // and non-Latin scripts. Any of them unescaped truncates the URL at best.
      final uri = app('google').build(lat, lng, 'ada & çınar');
      expect(uri.toString(), contains('ada%20%26%20%C3%A7%C4%B1nar'));
    });

    test('an empty label is omitted rather than sent as empty', () {
      final uri = app('osmand').build(lat, lng, '   ');
      expect(uri.toString(), isNot(contains('title=')));
    });

    test('Apple Maps names an unlabelled pin rather than leaving it blank', () {
      // Apple drops the pin at `ll` but shows `q` as its caption; an empty one
      // renders as an unnamed marker, which is worse than a generic word.
      final uri = app('apple').build(lat, lng, null);
      expect(uri.toString(), contains('q=Shared%20location'));
    });

    test('apps with no label field simply drop it', () {
      expect(app('waze').build(lat, lng, 'ada').toString(), isNot(contains('ada')));
      expect(app('kakao').build(lat, lng, 'ada').toString(), isNot(contains('ada')));
    });
  });

  group('probe', () {
    tearDown(() => MapAppProbe.debugCanLaunch = null);

    test('returns only what the OS says it can open, in catalogue order', () {
      MapAppProbe.debugCanLaunch = (uri) async =>
          uri.scheme == 'comgooglemaps' || uri.scheme == 'maps';

      expect(
        MapAppProbe.installed().then((a) => a.map((e) => e.id).toList()),
        completion(['apple', 'google']),
      );
    });

    test('an OS that answers no to everything yields no chooser', () {
      MapAppProbe.debugCanLaunch = (_) async => false;
      expect(MapAppProbe.installed(), completion(isEmpty));
    });

    test('a throwing probe is treated as absent, not as a crash', () {
      MapAppProbe.debugCanLaunch = (uri) async {
        if (uri.scheme == 'waze') throw StateError('channel is gone');
        return uri.scheme == 'maps';
      };
      expect(
        MapAppProbe.installed().then((a) => a.map((e) => e.id).toList()),
        completion(['apple']),
      );
    });
  });

  group('web fallback', () {
    test('points at OpenStreetMap with a marker and a matching hash', () {
      final uri = webMapUri(lat, lng);
      expect(uri.host, 'www.openstreetmap.org');
      expect(uri.toString(), contains('mlat=41.013800&mlon=28.949700'));
      expect(uri.toString(), contains('#map=$kMapAppZoom/41.013800/28.949700'));
    });
  });
}
