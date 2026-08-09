import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
// AppleSettings / AndroidSettings / ForegroundNotificationConfig are re-exported
// by this one entry point, so the platform-specific packages are not (and must
// not become) direct dependencies.
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
  ///
  /// [precision] exists for the live-share heartbeat, which takes a fresh fix
  /// every ninety seconds for as long as the share runs and is therefore the one
  /// caller where the difference between waking the GPS and not is worth several
  /// percent of a battery over an afternoon. See [LiveLocationMode]. Everything
  /// else wants the default.
  Future<LocationFix?> currentFix({
    Duration timeout = const Duration(seconds: 15),
    LocationPrecision precision = LocationPrecision.fine,
  }) async {
    try {
      final p = await _geo.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _accuracyFor(precision),
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
  /// [LiveLocationMode] for the three settings and what each costs; the interval
  /// ceiling that rides on top of them is [LiveLocationPublisher]'s.
  ///
  /// ## What makes this keep running in the background
  ///
  /// Everything, on both platforms, comes from the two settings objects below
  /// plus two declarations. There is no native code in this path.
  ///
  /// **iOS.** `allowBackgroundLocationUpdates` sets
  /// `CLLocationManager.allowsBackgroundLocationUpdates`, which is what stops
  /// the OS suspending us when the app leaves the screen. It is inert without
  /// `UIBackgroundModes: location` in Info.plist — `geolocator` checks the
  /// bundle itself and quietly forces the flag false if the key is missing, so a
  /// missing plist entry does not fail loudly, it just fails. It works on
  /// When-In-Use: Always is only needed for the *relaunch* path, which lives in
  /// `LiveLocationPlatform`.
  ///
  /// `showBackgroundLocationIndicator` puts the blue pill in the status bar for
  /// the whole time we are publishing. That is switched on deliberately and is
  /// not a cost to be minimised: a share the user cannot see running is the
  /// thing that makes background location frightening, and the pill is also the
  /// fastest route back into the app to stop it.
  ///
  /// `pauseLocationUpdatesAutomatically: false` is load-bearing and the least
  /// obvious of the three. Left at iOS's default the OS decides, from
  /// accelerometer data, that the device has stopped moving and *stops calling
  /// us back entirely* — and it never resumes on its own; the app is expected to
  /// notice and restart. For most apps that is a battery win. Here it is a share
  /// that silently dies the moment somebody sits down, which is exactly when
  /// somebody waiting for them starts watching.
  ///
  /// `ActivityType.other` rather than `.fitness` or `.automotiveNavigation` for
  /// the same reason: the specific types make iOS *more* eager to pause and to
  /// second-guess the fix against an expected movement profile, and a live share
  /// has no profile — it is a walk, then a bus, then a walk.
  ///
  /// **Android.** Background updates need the app to hold a foreground service
  /// whose type is `location` — without one, the process is an ordinary
  /// backgrounded app and Android throttles location to a few updates an hour
  /// before killing it outright.
  ///
  /// `geolocator` can provide that service itself, via
  /// `AndroidSettings.foregroundNotificationConfig`, and this deliberately does
  /// NOT use it. `LiveLocationService` in `android/app/src/main/kotlin/…` runs
  /// its own instead, for one reason: `ForegroundNotificationConfig` has a
  /// title, a body and an icon, and no way to add an action button. A background
  /// tracker that can only be stopped by finding the app, opening it, finding
  /// the room and finding the bubble is the thing people are right to distrust.
  ///
  /// Two services are not needed and would be wrong. While-in-use location
  /// access is granted per APP, not per service, so one location-typed
  /// foreground service anywhere in the process keeps this stream delivering —
  /// and the notification the user sees is then the one with STOP on it, rather
  /// than two notifications for one share.
  Stream<LocationFix> fixStream({
    LiveLocationMode mode = LiveLocationMode.foreground,
  }) {
    return _geo.getPositionStream(locationSettings: _settingsFor(mode)).map(_fix);
  }

  /// Builds the per-platform settings for [fixStream].
  ///
  /// `defaultTargetPlatform` rather than `dart:io`'s `Platform`, because this
  /// file is imported on web (the location sheet is hidden there, but the import
  /// graph does not know that) and `dart:io` is not available.
  LocationSettings _settingsFor(LiveLocationMode mode) {
    final accuracy = _accuracyFor(mode.precision);
    final distanceFilter = mode.distanceFilterMeters.round();
    if (kIsWeb) {
      return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
          pauseLocationUpdatesAutomatically: false,
          activityType: ActivityType.other,
        );
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
          // A floor under the distance filter, not a substitute for it. On a
          // motorway a 100 m filter fires every three seconds; without this the
          // publisher's own ceiling would be discarding most of that work after
          // the radio had already been woken to do it.
          intervalDuration: mode.minPublishInterval,
          // Null on purpose — see above. The foreground service is ours, and it
          // is the one with a STOP button.
          foregroundNotificationConfig: null,
        );
      default:
        return LocationSettings(
          accuracy: accuracy,
          distanceFilter: distanceFilter,
        );
    }
  }

  /// [LocationPrecision] in the plugin's vocabulary.
  ///
  /// `high` and not `best` for [LocationPrecision.fine]: `best` asks iOS to keep
  /// refining a fix indefinitely, which over an eight-hour share is a
  /// meaningful amount of radio spent improving 10 m to 5 m on a card that draws
  /// neither. `medium` for [LocationPrecision.coarse] maps to
  /// `kCLLocationAccuracyHundredMeters` on iOS and
  /// `PRIORITY_BALANCED_POWER_ACCURACY` on Android — both of which let the
  /// platform answer from cell and Wi-Fi and leave the GPS asleep, which is the
  /// entire saving.
  static LocationAccuracy _accuracyFor(LocationPrecision precision) =>
      switch (precision) {
        LocationPrecision.fine => LocationAccuracy.high,
        LocationPrecision.coarse => LocationAccuracy.medium,
      };

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
