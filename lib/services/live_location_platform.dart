import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import 'live_location_permission.dart';

/// The native half of background live sharing: everything `geolocator` does not
/// expose.
///
/// `geolocator` covers more of this than the previous decision assumed — the
/// `AppleSettings`/`AndroidSettings` flags in `location_service.dart` deliver
/// the whole of Tier 1 with no native code at all. What it does not cover, and
/// what this channel exists for, is exactly three things:
///
///  1. **Requesting Always.** `geolocator`'s `requestPermission()` calls
///     `requestWhenInUseAuthorization` whenever `NSLocationWhenInUseUsageDescription`
///     is present — which it is — and returns early without prompting at all
///     once the status is anything but `notDetermined`. Both of those are
///     correct for its purpose and fatal for ours: the Always escalation is by
///     definition a second prompt issued after When-In-Use was granted. There
///     is no argument to `requestPermission` that changes this, so the upgrade
///     needs its own `CLLocationManager.requestAlwaysAuthorization` call.
///  2. **Significant-change monitoring.** Not exposed by the plugin in any form.
///     It is the only iOS API that can relaunch a terminated app, so Tier 2 on
///     iOS is this or nothing.
///  3. **A notification the user can stop the share from.** `geolocator`'s
///     `ForegroundNotificationConfig` has a title, a body and an icon, and no
///     way to add an action button. A background tracker you can only stop by
///     finding the app, opening it, finding the room and finding the bubble is
///     the thing people are right to distrust, so the service and its
///     notification are ours.
///
/// Every method degrades to a no-op rather than throwing. This runs on web and
/// on desktop where none of it exists, and on a phone where a channel can be
/// missing for a build reason that has nothing to do with location; a live share
/// that refused to start because a notification could not be posted would be
/// trading the whole feature for one of its affordances.
class LiveLocationPlatform {
  LiveLocationPlatform();

  /// Swapped wholesale in tests. Same pattern as `LocationService.instance` —
  /// the fake overrides the methods it cares about and inherits the no-ops.
  static LiveLocationPlatform instance = LiveLocationPlatform();

  static const MethodChannel _channel =
      MethodChannel('monkeyhub/live_location');

  /// Fires when the user stops the share from outside the app — the Android
  /// notification's STOP action, or iOS's equivalent notification action.
  ///
  /// A broadcast stream because two objects legitimately want it: the publisher,
  /// which has to stop feeding, and the repository, which has to tell the server
  /// the share is over. Routing it through one listener that called the other
  /// would put the repository's knowledge of the publisher's internals into a
  /// third place.
  final StreamController<void> _stopRequests =
      StreamController<void>.broadcast();

  Stream<void> get onStopRequested => _stopRequests.stream;

  bool _handlerInstalled = false;

  /// Whether this platform has an Always tier at all.
  ///
  /// False on web and desktop, where "background location" is not a concept the
  /// OS has, and where offering the upgrade sheet would be offering a button
  /// that cannot do anything. Consumed by [decideLiveShareStart].
  bool get supportsAlways => _isMobile;

  /// `kIsWeb` first, as everywhere else in this codebase: on web
  /// `defaultTargetPlatform` is derived from the user agent, so Chrome on
  /// Android reports `android` and would otherwise claim a foreground service
  /// this build has no way to start.
  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Starts listening for native → Dart calls. Idempotent.
  ///
  /// Called from the repository rather than from a constructor because the
  /// stream has to exist before the first share and the platform object is
  /// built at import time, when a `MethodChannel` handler would be installed on
  /// an engine that may not have finished starting.
  void ensureStarted() {
    if (_handlerInstalled || !_isMobile) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'stopRequested':
          // Deliberately carries no message id. The notification is posted for
          // whichever share is running and there is only ever one, so an id here
          // would be a second source of truth that could disagree with the
          // publisher's — and the loser of that disagreement is a share the user
          // pressed STOP on and which kept running.
          _stopRequests.add(null);
        default:
          break;
      }
      return null;
    });
  }

  /// How much location authorization the app holds, as the OS sees it.
  ///
  /// Distinct from `geolocator`'s answer, which collapses Always and
  /// When-In-Use into one "granted". See the class comment.
  Future<BackgroundLocationTier> authorizationTier() async {
    if (!supportsAlways) return BackgroundLocationTier.none;
    return _tier(await _invoke<String>('authorizationTier'));
  }

  /// Shows the system's Always prompt and resolves with the answer.
  ///
  /// The iOS reality this returns into: `requestAlwaysAuthorization` on a device
  /// that already holds When-In-Use often resolves *immediately with the old
  /// value* and shows the user nothing until the app next uses location in the
  /// background — at which point iOS asks on its own terms ("Keep Only While
  /// Using" / "Change to Always"). So a [BackgroundLocationTier.whenInUse]
  /// answer here does not mean refused; it means not yet decided. Callers must
  /// treat it as "carry on with Tier 1", never as a failure worth reporting,
  /// and must not re-ask.
  Future<BackgroundLocationTier> requestAlwaysAuthorization() async {
    if (!supportsAlways) return BackgroundLocationTier.none;
    return _tier(await _invoke<String>('requestAlwaysAuthorization'));
  }

  /// Puts the platform into "a share is running" state.
  ///
  /// On Android this starts the location foreground service, which is what keeps
  /// the process alive and the position stream delivering once the app leaves
  /// the screen — and it is started from here, while the app is demonstrably in
  /// the foreground, which is what makes it legal without
  /// `ACCESS_BACKGROUND_LOCATION`.
  ///
  /// On iOS the process is kept alive by the `location` background mode instead,
  /// and this posts the stoppable notification and (with Always) starts
  /// significant-change monitoring.
  ///
  /// [expiresAtMs] is passed down so the native side can stop itself on time
  /// even if Dart never speaks to it again — a foreground service that outlived
  /// its share would be a permanent notification for something that ended.
  Future<void> startSharing({
    required String messageId,
    required String roomId,
    required int expiresAtMs,
    required String notificationTitle,
    required String notificationBody,
    required String stopActionLabel,
    required bool monitorSignificantChanges,
  }) async {
    await _invoke<void>('startSharing', {
      'messageId': messageId,
      'roomId': roomId,
      'expiresAtMs': expiresAtMs,
      'title': notificationTitle,
      'body': notificationBody,
      'stopLabel': stopActionLabel,
      'significantChanges': monitorSignificantChanges,
    });
  }

  /// Tears all of that down. Safe to call when nothing is running, and called
  /// that way on purpose — the publisher stops for reasons that have nothing to
  /// do with the platform (a superseded share, a sign-out) and asking "was it
  /// started?" first would be a state duplicate that can drift.
  Future<void> stopSharing() => _invoke<void>('stopSharing');

  /// Whether this process was started BY the OS because of location, rather
  /// than by the user.
  ///
  /// iOS only, and consumed once — the flag is cleared natively on read. It is
  /// not used to decide whether to resume (the persisted handle decides that);
  /// it is used to decide whether to stay quiet. A launch the user did not ask
  /// for must not put anything on screen, and must not, for example, mark a room
  /// as read because a route was restored.
  Future<bool> wasLaunchedForLocation() async =>
      await _invoke<bool>('wasLaunchedForLocation') ?? false;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (!_isMobile) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      // A build without the native half — a unit test host, a platform this was
      // never wired for. Silent by design: this is the expected answer there,
      // not an error, and logging it would put a line in every test run.
      return null;
    } catch (e) {
      debugPrint('LiveLocationPlatform.$method: $e');
      return null;
    }
  }

  static BackgroundLocationTier _tier(String? raw) => switch (raw) {
        'always' => BackgroundLocationTier.always,
        'whenInUse' => BackgroundLocationTier.whenInUse,
        // Anything else — 'none', 'denied', a null from a channel that isn't
        // there, a value a future OS invents — is treated as no background
        // capability. The share still runs; it just makes no promises about
        // outliving the app.
        _ => BackgroundLocationTier.none,
      };
}
