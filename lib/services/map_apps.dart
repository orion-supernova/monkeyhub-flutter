import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show immutable, kIsWeb;
import 'package:url_launcher/url_launcher.dart' as launcher;

/// The maps applications this app knows how to hand a coordinate to, and how to
/// find out which of them the user actually has.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS EXISTS ON iOS AND NOT ON ANDROID
/// ─────────────────────────────────────────────────────────────────────────
///
/// Android already solves this. A `geo:` intent raises the system chooser,
/// which lists *every* installed handler — including ones nobody has heard of —
/// and remembers the user's default if they set one. Replacing that with an
/// in-app sheet would list fewer apps than the OS does and quietly override a
/// choice the user already made in Settings. So [MapsHandoff] keeps handing
/// Android its `geo:` intent, and this file is not consulted there.
///
/// iOS has no equivalent. `maps://` is Apple Maps' own scheme, third-party maps
/// apps cannot claim it, and the OS offers no chooser intent to fall back on.
/// The only way a tap on a location bubble can reach Google Maps or Yandex on
/// an iPhone is if this app asks, one scheme at a time, what is installed and
/// then presents the answers itself. That is what this file does.
///
/// ─────────────────────────────────────────────────────────────────────────
/// THE LIMIT, STATED UP FRONT
/// ─────────────────────────────────────────────────────────────────────────
///
/// **This cannot detect "all map apps", and no iOS app can.** `canOpenURL` only
/// answers for schemes declared in `LSApplicationQueriesSchemes` in
/// `Info.plist`, the list is capped at 50 entries, and the OS gives an app no
/// way to read back its own declarations. So a scheme missing from the plist is
/// indistinguishable, at runtime, from an app the user has not installed — it
/// simply never appears, silently, with no error anywhere.
///
/// The practical consequence: [catalog] and the plist array are one fact stored
/// in two files, and they must be edited together. Adding an entry here without
/// adding its [MapApp.probe] scheme to `ios/Runner/Info.plist` produces an app
/// that is never detected on any device, and nothing in the build will say so.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHAT IS DELIBERATELY ABSENT
/// ─────────────────────────────────────────────────────────────────────────
///
/// **Amap, Baidu and Tencent are not here**, despite this app shipping Chinese
/// localisation, and their absence is a correctness decision rather than an
/// oversight. Those three do not accept WGS-84: Baidu reads BD-09 and the other
/// two read GCJ-02, the deliberately-offset datums used inside China. Handing
/// them a raw GPS fix puts the pin somewhere between a few hundred metres and
/// half a kilometre from the place that was actually shared. A location bubble
/// whose preview is documented as drawing only measured things must not open a
/// maps app at the wrong building; the conversion is real work and needs
/// verification on a device inside China, so these are left out until that can
/// be done rather than shipped approximately.
///
/// The web fallback in [MapsHandoff] covers every one of them in the meantime.
@immutable
class MapApp {
  const MapApp({
    required this.id,
    required this.name,
    required this.probe,
    required this.build,
  });

  /// Stable key. Used by tests and, if a remembered default is ever added, by
  /// whatever persists it — which is why it must not be derived from [name].
  final String id;

  /// Shown in the chooser exactly as written. **Never localised**: these are
  /// brand names, and a Turkish user looking for the app whose icon says
  /// "Yandex Haritalar" is still looking for the row that says Yandex Maps in
  /// the language the App Store listed it under.
  final String name;

  /// The scheme handed to `canOpenURL`. Must appear in
  /// `LSApplicationQueriesSchemes` — see the class comment on why a missing
  /// entry fails silently.
  final String probe;

  /// Builds the URL that actually opens this app at a pin.
  ///
  /// Separate from [probe] because the two are frequently different strings:
  /// MAPS.ME registers `mapswithme://` but takes its coordinates on `mapsme://`,
  /// and Apple's probe scheme carries no query at all.
  final Uri Function(double lat, double lng, String? label) build;
}

/// Formats a coordinate for a URL.
///
/// Six decimal places, matching [MapsHandoff]: this string is parsed by
/// software rather than read by a person, so the rounding that keeps the bubble
/// honest would only throw away precision here.
String _n(double v) => v.toStringAsFixed(6);

// ── URL builders ────────────────────────────────────────────────────────────
//
// Each of these is one vendor's documented scheme. They were taken from
// map_launcher 3.5.0 (MIT, © 2020 Alex Miller), whose templates have years of
// field use behind them — reimplemented rather than depended on because this
// app needs eleven entries and a chooser, not a plugin with a bundled icon set
// and its own manifest entries merging into ours.
//
// The shapes genuinely differ, which is why this is a table of functions and
// not one format string: some want `lat,lng`, some want `lng,lat`, some carry
// the label in a query parameter and some in a path segment.

Uri _apple(double lat, double lng, String? label) => Uri.parse(
  'maps://?ll=${_n(lat)},${_n(lng)}'
  '&q=${Uri.encodeComponent(label?.trim().isNotEmpty == true ? label!.trim() : 'Shared location')}',
);

// `q` carries the label in parentheses the way the geo: intent does; `center`
// and `zoom` frame it. Without `q` the app centres the map and drops no pin.
Uri _google(double lat, double lng, String? label) {
  final name = label?.trim() ?? '';
  final q = name.isEmpty
      ? '${_n(lat)},${_n(lng)}'
      : '${_n(lat)},${_n(lng)}(${Uri.encodeComponent(name)})';
  return Uri.parse(
    'comgooglemaps://?q=$q&center=${_n(lat)},${_n(lng)}&zoom=$kMapAppZoom',
  );
}

// Waze shows a pin and offers to navigate to it. It takes no label — the app
// has no concept of a named drop — so the sender's name is dropped rather than
// smuggled into a field that would display it somewhere unintended.
Uri _waze(double lat, double lng, String? label) =>
    Uri.parse('waze://?ll=${_n(lat)},${_n(lng)}&z=$kMapAppZoom');

// Note the order: Yandex Maps takes `pt` as longitude,latitude — the reverse of
// almost everything else here, and the single easiest thing in this file to get
// backwards. `map_app_test.dart` pins it with an asymmetric coordinate.
Uri _yandexMaps(double lat, double lng, String? label) => Uri.parse(
  'yandexmaps://maps.yandex.ru/?pt=${_n(lng)},${_n(lat)}&z=$kMapAppZoom&l=map',
);

Uri _yandexNavi(double lat, double lng, String? label) {
  final name = label?.trim() ?? '';
  return Uri.parse(
    'yandexnavi://show_point_on_map?lat=${_n(lat)}&lon=${_n(lng)}'
    '&zoom=$kMapAppZoom&no-balloon=0'
    '${name.isEmpty ? '' : '&desc=${Uri.encodeComponent(name)}'}',
  );
}

// Organic Maps is a MAPS.ME fork and inherited its URL handler wholesale, so
// the parameters are identical and only the scheme differs. Kept as two
// separate entries rather than one probing both schemes, because a user with
// both installed should see both rather than whichever this file guessed at.
Uri _organicMaps(double lat, double lng, String? label) =>
    _mapsMeStyle('om', lat, lng, label);

Uri _mapsMe(double lat, double lng, String? label) =>
    _mapsMeStyle('mapsme', lat, lng, label);

Uri _mapsMeStyle(String scheme, double lat, double lng, String? label) {
  final name = label?.trim() ?? '';
  return Uri.parse(
    '$scheme://map?v=1&ll=${_n(lat)},${_n(lng)}'
    '${name.isEmpty ? '' : '&n=${Uri.encodeComponent(name)}'}',
  );
}

Uri _osmand(double lat, double lng, String? label) {
  final name = label?.trim() ?? '';
  return Uri.parse(
    'osmandmaps://?lat=${_n(lat)}&lon=${_n(lng)}&z=$kMapAppZoom'
    '${name.isEmpty ? '' : '&title=${Uri.encodeComponent(name)}'}',
  );
}

// 2GIS puts the pair in the path, longitude first, and takes no label.
Uri _doubleGis(double lat, double lng, String? label) =>
    Uri.parse('dgis://2gis.ru/geo/${_n(lng)},${_n(lat)}');

// The one entry that launches over https rather than its probe scheme, because
// `here-location://` is documented for detection but not for dropping a pin.
// The universal link opens the app when it is installed — which, here, it
// demonstrably is, since this URL is only ever built after the probe succeeded.
Uri _here(double lat, double lng, String? label) {
  final name = label?.trim() ?? '';
  final tail = name.isEmpty ? '' : ',${Uri.encodeComponent(name)}';
  return Uri.parse(
    'https://share.here.com/l/${_n(lat)},${_n(lng)}$tail?z=$kMapAppZoom',
  );
}

// Citymapper is a transit planner with no "show me this point" mode, so the
// honest mapping of "open this location" is "route me to it".
Uri _citymapper(double lat, double lng, String? label) {
  final name = label?.trim() ?? '';
  return Uri.parse(
    'citymapper://directions?endcoord=${_n(lat)},${_n(lng)}'
    '${name.isEmpty ? '' : '&endname=${Uri.encodeComponent(name)}'}',
  );
}

// Naver and Kakao earn their place despite being one country's apps: Google
// Maps is legally restricted in South Korea and renders there without driving
// directions, so for a Korean user these are not an alternative to the default
// — they are the only ones that work.
Uri _naver(double lat, double lng, String? label) {
  final name = label?.trim() ?? '';
  return Uri.parse(
    'nmap://place?lat=${_n(lat)}&lng=${_n(lng)}&zoom=$kMapAppZoom'
    '${name.isEmpty ? '' : '&name=${Uri.encodeComponent(name)}'}',
  );
}

Uri _kakao(double lat, double lng, String? label) =>
    Uri.parse('kakaomap://look?p=${_n(lat)},${_n(lng)}');

// TMap takes x/y rather than lat/lon — x is longitude.
Uri _tmap(double lat, double lng, String? label) {
  final name = label?.trim() ?? '';
  return Uri.parse(
    'tmap://viewmap?x=${_n(lng)}&y=${_n(lat)}'
    '${name.isEmpty ? '' : '&name=${Uri.encodeComponent(name)}'}',
  );
}

/// Street level — high enough to see which building, low enough that a fix with
/// 100 m of error doesn't imply a doorway. Every entry above uses it, so a
/// location opens at the same scale wherever it lands.
const int kMapAppZoom = 17;

/// Where a location goes when it isn't going to an installed app.
///
/// OpenStreetMap because it is the one map host that needs no key and no
/// account to *link* to, and because a link is the one place a third party
/// unavoidably learns the coordinates, so it should at least be a party that is
/// not selling them.
Uri webMapUri(double lat, double lng, [String? label]) => Uri.parse(
  'https://www.openstreetmap.org/?mlat=${_n(lat)}&mlon=${_n(lng)}'
  '#map=$kMapAppZoom/${_n(lat)}/${_n(lng)}',
);

/// The browser row the chooser shows beneath the installed apps.
///
/// Deliberately **not** in [kMapAppCatalog]: it is never probed (there is
/// always a browser) and it is never the answer to "which maps apps does this
/// device have". It is a separate constant so the chooser can offer it without
/// the catalogue having to carry a member that isn't a maps app.
const MapApp kBrowserFallback = MapApp(
  id: 'web',
  name: 'OpenStreetMap',
  probe: 'https://',
  build: webMapUri,
);

/// Every maps app this build can detect and open.
///
/// Order is what the chooser shows, and it is editorial rather than
/// alphabetical: the two apps most people have sit at the top so the common
/// case needs no reading, and the regional ones sit below them where they cost
/// a Korean or Russian user one glance and everyone else nothing.
///
/// **Adding one is a two-file change** — this list and
/// `ios/Runner/Info.plist`. See the class comment on why forgetting the second
/// half fails without a single warning.
const List<MapApp> kMapAppCatalog = [
  MapApp(id: 'apple', name: 'Apple Maps', probe: 'maps://', build: _apple),
  MapApp(
    id: 'google',
    name: 'Google Maps',
    probe: 'comgooglemaps://',
    build: _google,
  ),
  MapApp(id: 'waze', name: 'Waze', probe: 'waze://', build: _waze),
  MapApp(
    id: 'organic',
    name: 'Organic Maps',
    probe: 'om://',
    build: _organicMaps,
  ),
  MapApp(id: 'osmand', name: 'OsmAnd', probe: 'osmandmaps://', build: _osmand),
  MapApp(
    id: 'mapswithme',
    name: 'MAPS.ME',
    probe: 'mapswithme://',
    build: _mapsMe,
  ),
  MapApp(
    id: 'yandexMaps',
    name: 'Yandex Maps',
    probe: 'yandexmaps://',
    build: _yandexMaps,
  ),
  MapApp(
    id: 'yandexNavi',
    name: 'Yandex Navigator',
    probe: 'yandexnavi://',
    build: _yandexNavi,
  ),
  MapApp(id: 'doubleGis', name: '2GIS', probe: 'dgis://', build: _doubleGis),
  MapApp(id: 'here', name: 'HERE WeGo', probe: 'here-location://', build: _here),
  MapApp(
    id: 'citymapper',
    name: 'Citymapper',
    probe: 'citymapper://',
    build: _citymapper,
  ),
  MapApp(id: 'naver', name: 'Naver Map', probe: 'nmap://', build: _naver),
  MapApp(id: 'kakao', name: 'KakaoMap', probe: 'kakaomap://', build: _kakao),
  MapApp(id: 'tmap', name: 'TMap', probe: 'tmap://', build: _tmap),
];

/// Asks the OS which of [kMapAppCatalog] is installed.
///
/// Returns an empty list off iOS — see the class comment on why Android is not
/// asked. Callers treat empty as "no chooser", not as "no maps app": the
/// existing [MapsHandoff.open] fallback chain still runs.
class MapAppProbe {
  /// Overridable for tests, which must not call into the platform channel.
  /// Set it, run, and set it back to null in `addTearDown`.
  static Future<bool> Function(Uri)? debugCanLaunch;

  static Future<List<MapApp>> installed() async {
    final can = debugCanLaunch ?? _canLaunch;
    if (debugCanLaunch == null) {
      if (kIsWeb) return const [];
      if (!Platform.isIOS) return const [];
    }

    final found = <MapApp>[];
    for (final app in kMapAppCatalog) {
      try {
        if (await can(Uri.parse(app.probe))) found.add(app);
      } catch (_) {
        // A scheme the platform refuses to answer for throws on some versions
        // and returns false on others. Both mean "not available", and one
        // uncooperative entry must not cost the user the whole chooser — the
        // remaining apps are still perfectly openable.
      }
    }
    return found;
  }

  static Future<bool> _canLaunch(Uri uri) => launcher.canLaunchUrl(uri);
}
