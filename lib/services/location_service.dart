import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/location_share.dart';

/// Why this app can ask for a position at all, or why it cannot.
///
/// Three refusals rather than one boolean, because the three have completely
/// different remedies and offering the wrong one is a dead end:
///
///  * [denied] — asking again is legitimate; iOS will show the sheet, Android
///    will show it until the user checks "don't ask again".
///  * [deniedForever] — asking again does nothing at all. The OS returns the
///    same answer without showing anything, so a UI that retries here looks
///    broken. The only route out is the app's own Settings page.
///  * [servicesDisabled] — the permission may well be granted; location is off
///    *device-wide*. Requesting permission is not the fix and on Android does
///    not even prompt.
enum LocationAvailability { ready, denied, deniedForever, servicesDisabled }

/// A single position fix, decoupled from the plugin's own type.
///
/// Exists so everything above this file — the repository, the publisher, the
/// bubble — can be built and tested without `geolocator` in scope, and so
/// swapping the plugin is one file's problem.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;

  /// Horizontal accuracy in metres, or null where the platform reported none
  /// or reported a non-positive value (which some desktop backends do to mean
  /// "no idea"). Null travels all the way to the bubble, which then draws no
  /// accuracy ring rather than inventing a radius.
  final double? accuracyM;

  final DateTime timestamp;

  double distanceMetersTo(LocationFix other) =>
      haversineMeters(latitude, longitude, other.latitude, other.longitude);
}

/// Everything this app does with the device's own position.
///
/// Deliberately thin: one fix, or a stream of fixes, plus the permission
/// question and the two deep links out of a refusal. It holds no state about
/// *shares* — that is `LiveLocationPublisher`'s job — because permission and
/// sharing have different lifetimes and mixing them is how a "stop sharing"
/// ends up unable to run while a permission dialog is open.
class LocationService {
  LocationService({GeolocatorPlatform? platform})
      : _geo = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _geo;

  /// The shared instance the app wires up. Injectable for tests, which pass a
  /// fake `GeolocatorPlatform` and never touch real hardware.
  static LocationService instance = LocationService();

  /// Whether a fix can be obtained right now, and if not, why.
  ///
  /// Checks the *device* switch before the app permission, which is the order
  /// the remedies need: an app that says "grant location access" while the
  /// phone has location switched off entirely has sent the user to a Settings
  /// page whose toggle will not help them.
  ///
  /// Never requests anything. [ensureAvailable] is the one that prompts, so a
  /// caller that only wants to decide whether to *show* a control can ask
  /// without producing a system dialog nobody asked for.
  Future<LocationAvailability> check() async {
    if (!await _geo.isLocationServiceEnabled()) {
      return LocationAvailability.servicesDisabled;
    }
    return _map(await _geo.checkPermission());
  }

  /// [check], and then ask once if the answer was a soft no.
  ///
  /// Returns the state *after* asking, so a caller can branch on the outcome
  /// without a second round trip. A [LocationAvailability.deniedForever] result
  /// is returned rather than prompted, because on both platforms the prompt for
  /// that state is a no-op that resolves instantly — the user would see nothing
  /// happen and conclude the button is broken.
  Future<LocationAvailability> ensureAvailable() async {
    final initial = await check();
    if (initial != LocationAvailability.denied) return initial;
    return _map(await _geo.requestPermission());
  }

  /// Opens the OS page where the user can grant this app location access.
  /// The only route out of [LocationAvailability.deniedForever].
  Future<bool> openAppSettings() => _geo.openAppSettings();

  /// Opens the OS page where the user can switch location services back on.
  /// The only route out of [LocationAvailability.servicesDisabled].
  Future<bool> openLocationSettings() => _geo.openLocationSettings();

  /// One fix, for a static "send my location now".
  ///
  /// [LocationAccuracy.high] rather than `best`: `best` asks the OS to keep
  /// refining, which on iOS can spend several seconds and a lot of radio to
  /// improve a fix from 20 m to 5 m — a distinction invisible on a preview card
  /// this size and not worth the wait when the user has already tapped send.
  ///
  /// The timeout is a hard bound and not a hint. Indoors, or in a car park, a
  /// request for a fresh fix can simply never complete, and the failure this
  /// prevents is the worst kind: a send that hangs with no error and no result.
  /// A [TimeoutException] surfaces as "couldn't get your location", which is
  /// both true and actionable.
  Future<LocationFix?> currentFix({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final p = await _geo.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return _fix(p);
    } on TimeoutException {
      return null;
    } catch (_) {
      // A revoked permission, a hardware failure, a platform channel that went
      // away with the activity. All of them mean the same thing to the caller,
      // and none of them should throw out of a send the user made.
      return null;
    }
  }

  /// The last fix the OS already has, without asking the hardware for a new one.
  ///
  /// Free — no GPS, no delay. Used to put a plausible position on screen while
  /// [currentFix] resolves, and for nothing else: it can be minutes old and
  /// kilometres wrong, so it is never what gets sent.
  Future<LocationFix?> lastKnownFix() async {
    try {
      final p = await _geo.getLastKnownPosition();
      return p == null ? null : _fix(p);
    } catch (_) {
      return null;
    }
  }

  /// A stream of fixes for a running live share.
  ///
  /// The distance filter is the battery decision and it is made here rather
  /// than by throttling downstream, because a filter the OS understands is the
  /// difference between a sleeping GPS and a spinning one. See
  /// [kLiveDistanceFilterMeters]; the interval ceiling that rides on top of it
  /// is [LiveLocationPublisher]'s.
  ///
  /// Foreground only. Nothing here asks for `Always`, and the app declares no
  /// background location capability on either platform — see the header of
  /// live_location_publisher.dart.
  Stream<LocationFix> fixStream({
    double distanceFilterMeters = kLiveDistanceFilterMeters,
  }) {
    return _geo
        .getPositionStream(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: distanceFilterMeters.round(),
          ),
        )
        .map(_fix);
  }

  LocationFix _fix(Position p) => LocationFix(
        latitude: p.latitude,
        longitude: p.longitude,
        // Non-positive means "not reported" on several backends, and passing it
        // through would have the bubble draw a zero-metre accuracy ring —
        // a claim of perfect precision, which is the one thing it is not.
        accuracyM: p.accuracy > 0 ? p.accuracy : null,
        timestamp: p.timestamp,
      );

  LocationAvailability _map(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationAvailability.ready;
      case LocationPermission.deniedForever:
        return LocationAvailability.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        // `unableToDetermine` is grouped with `denied` on purpose: it is what
        // the web backend returns before the user has answered, and the correct
        // response to "we don't know yet" is to ask.
        return LocationAvailability.denied;
    }
  }
}
