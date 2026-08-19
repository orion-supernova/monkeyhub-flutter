import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart' as launcher;

import 'map_apps.dart';

/// Hands a coordinate pair to whatever the user already uses for maps.
///
/// This is the whole of this app's involvement in navigation, and that is a
/// decision rather than an omission. Turn-by-turn is a product, not a feature:
/// it needs routing data, traffic, voice, re-routing, offline tiles and a
/// licence for all of it. The user already has an application that does those
/// things, has already granted it whatever it needs, and already prefers it.
/// So a tap on a location bubble ends here, in their app, at their pin.
///
/// Three routes, tried in order, because each platform has exactly one right
/// answer and one honest fallback:
///
///  * **Android — `geo:`**. The platform intent, which raises the app chooser
///    if the user has more than one maps app and goes straight through if they
///    have one. Preferred over a Google Maps URL specifically because it does
///    *not* presume Google Maps: Organic Maps, OsmAnd and Waze all register for
///    it.
///  * **iOS — the user's answer, then `maps://`**. Apple Maps' scheme is the
///    only one third-party apps cannot claim, and iOS offers no chooser intent,
///    so [open] alone would silently mean "Apple Maps" on every iPhone. That is
///    why [installedApps] and [openIn] exist: the caller asks what is there,
///    puts the answer to the user, and hands the coordinate to what they picked.
///    `maps://` remains the floor when nothing else is installed.
///  * **Everywhere else, and as a last resort — an OpenStreetMap web URL**.
///    Reached on web, Linux and Windows, and on a phone whose maps app has been
///    removed. See [webMapUri] for why OpenStreetMap and not somewhere else.
class MapsHandoff {
  /// Opens [latitude],[longitude] in the platform's maps application.
  ///
  /// [label] is what the pin is called where the platform supports naming one
  /// (Android's `geo:` query, Apple's `q`). Passing the sender's name is what
  /// makes three shared locations in one afternoon distinguishable once they
  /// are open in a maps app that has forgotten which chat they came from.
  ///
  /// Returns false when nothing could be opened at all — every route refused —
  /// so the caller can say so rather than leaving a tap that appears to do
  /// nothing.
  static Future<bool> open({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    for (final uri in candidateUris(
      latitude: latitude,
      longitude: longitude,
      label: label,
    )) {
      if (await _tryLaunch(uri)) return true;
    }
    return false;
  }

  /// The URIs [open] will try, in order.
  ///
  /// Exposed (and pure) so the scheme construction — the part with the
  /// platform-specific escaping and the easily-transposed lat/lng pairs — can be
  /// tested without launching anything.
  static List<Uri> candidateUris({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    // Six decimal places here rather than the five the bubble prints. This
    // string is consumed by software, not read by a person, so the rounding
    // that keeps a UI honest only loses precision.
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    final name = (label ?? '').trim();

    final web = webMapUri(latitude, longitude);

    if (kIsWeb) return [web];

    // `Platform` is only touched behind the kIsWeb guard above — reading it in
    // a browser throws.
    if (Platform.isAndroid) {
      // `geo:lat,lng?q=lat,lng(Label)`. The `q` repeats the coordinates on
      // purpose: without it some handlers treat the path as a map centre and
      // drop no pin at all, and the pair inside `q` is what actually gets
      // marked. The label goes in parentheses per the intent's format, and is
      // encoded because a sender's name may contain anything.
      final q = name.isEmpty
          ? '$lat,$lng'
          : '$lat,$lng(${Uri.encodeComponent(name)})';
      return [Uri.parse('geo:$lat,$lng?q=$q'), web];
    }
    if (Platform.isIOS || Platform.isMacOS) {
      // `ll` centres the map, `q` names the pin. Apple Maps drops the pin at
      // `ll` when `q` is not itself an address, which is why the label may be
      // free text here and must not be on Android.
      final q = name.isEmpty ? 'Shared location' : name;
      return [
        Uri.parse('maps://?ll=$lat,$lng&q=${Uri.encodeComponent(q)}'),
        web,
      ];
    }
    return [web];
  }

  /// Which of [kMapAppCatalog] this device actually has.
  ///
  /// Empty everywhere except iOS, and empty there too on a phone with nothing
  /// but Apple Maps' scheme unavailable. Callers must treat empty as "don't
  /// offer a choice" rather than as "no maps app" — [open] still works, and on
  /// Android it is the better answer anyway. See MapAppProbe for why the
  /// question is only worth asking on one platform, and for the limit on how
  /// complete the answer can be.
  static Future<List<MapApp>> installedApps() => MapAppProbe.installed();

  /// Opens [app] at [latitude],[longitude] — the chooser's counterpart to
  /// [open].
  ///
  /// Falls back to the web URL if the app refuses the launch, which is not
  /// merely defensive: the user picked this app from a list, so failing
  /// silently here would look like the app they chose is broken. Returns false
  /// only when the fallback refused too.
  static Future<bool> openIn(
    MapApp app, {
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    if (await _tryLaunch(app.build(latitude, longitude, label))) return true;
    return _tryLaunch(webMapUri(latitude, longitude));
  }

  static Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await launcher.launchUrl(
        uri,
        // External, always. A coordinate handed to an in-app browser is a
        // coordinate that has gone nowhere useful — the point is to leave.
        mode: launcher.LaunchMode.externalApplication,
      );
    } catch (_) {
      // A scheme with no handler throws on some platforms and returns false on
      // others. Both mean "try the next one" — the same shape LinkOpener uses.
      return false;
    }
  }
}
