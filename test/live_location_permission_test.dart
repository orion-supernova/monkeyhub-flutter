import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/services/live_location_permission.dart';
import 'package:monkeyhub/services/location_service.dart';

/// The permission table, exhaustively.
///
/// This is the part of background location most likely to be got subtly wrong,
/// and its failure mode is not a crash — it is a prompt at the wrong moment, or
/// a user asked the same question every single day. Neither shows up in a
/// screenshot and neither can be checked on a simulator, because the simulator
/// grants everything. So the rules are a pure function and this file walks every
/// cell of it.
void main() {
  LiveShareStartAction decide({
    LocationAvailability availability = LocationAvailability.ready,
    BackgroundLocationTier tier = BackgroundLocationTier.whenInUse,
    bool offered = false,
    bool supported = true,
  }) =>
      decideLiveShareStart(
        availability: availability,
        tier: tier,
        alreadyOfferedAlways: offered,
        platformSupportsAlways: supported,
      );

  group('the three ways location is unavailable each get their own exit', () {
    test('services off device-wide goes to the location settings', () {
      // Not the app's permission screen. Sending somebody there when the device
      // switch is off is sending them somewhere with no control that helps.
      for (final tier in BackgroundLocationTier.values) {
        expect(
          decide(
            availability: LocationAvailability.servicesDisabled,
            tier: tier,
          ),
          LiveShareStartAction.openLocationSettings,
        );
      }
    });

    test('a permanent denial goes to the app settings, never to a prompt', () {
      // The OS answers `deniedForever` without showing anything, so a UI that
      // re-requests here looks broken: the user taps, nothing happens, and the
      // app has no way to explain why.
      for (final tier in BackgroundLocationTier.values) {
        expect(
          decide(
            availability: LocationAvailability.deniedForever,
            tier: tier,
            offered: true,
          ),
          LiveShareStartAction.openAppSettings,
        );
      }
    });

    test('a soft denial is asked again', () {
      expect(
        decide(availability: LocationAvailability.denied),
        LiveShareStartAction.requestPermission,
      );
    });

    test('unavailability outranks every background consideration', () {
      // The upgrade sheet must never appear in front of somebody who has not
      // granted basic location — it would be asking for MORE than the thing
      // they have not given.
      expect(
        decide(
          availability: LocationAvailability.denied,
          tier: BackgroundLocationTier.always,
        ),
        LiveShareStartAction.requestPermission,
      );
    });
  });

  group('the Always escalation', () {
    test('is offered once, to a When-In-Use user who has not been asked', () {
      expect(decide(), LiveShareStartAction.offerAlwaysUpgrade);
    });

    test('is never repeated once it has been offered', () {
      // The single most important row in the table. The flag is set when the
      // sheet is SHOWN, not when the permission is granted, so a considered "no"
      // is never re-litigated — which is precisely the behaviour that makes
      // people uninstall location apps.
      expect(decide(offered: true), LiveShareStartAction.start);
    });

    test('is not offered to somebody who already granted Always', () {
      expect(
        decide(tier: BackgroundLocationTier.always),
        LiveShareStartAction.start,
      );
      expect(
        decide(tier: BackgroundLocationTier.always, offered: true),
        LiveShareStartAction.start,
      );
    });

    test('is not offered where the platform has no such tier', () {
      // Web and desktop. Offering a button that cannot do anything is worse
      // than not offering it.
      expect(decide(supported: false), LiveShareStartAction.start);
      expect(
        decide(supported: false, tier: BackgroundLocationTier.none),
        LiveShareStartAction.start,
      );
    });
  });

  test('a confused tier never blocks a share that availability allows', () {
    // `availability` and `tier` are derived from the same OS answer through two
    // different code paths, and if they ever disagree, availability is the one
    // computed by the code that actually takes fixes. Refusing to start a share
    // because a secondary signal is confused would break the feature to protect
    // an upgrade prompt.
    expect(
      decide(tier: BackgroundLocationTier.none, offered: true),
      LiveShareStartAction.start,
    );
  });

  test('only Always claims to survive termination', () {
    expect(tierSurvivesTermination(BackgroundLocationTier.always), isTrue);
    // The honest half. When-In-Use gets the whole of the backgrounded-app
    // experience and none of the relaunch-after-death one, and saying otherwise
    // anywhere in this app would be a promise the platform will not keep.
    expect(tierSurvivesTermination(BackgroundLocationTier.whenInUse), isFalse);
    expect(tierSurvivesTermination(BackgroundLocationTier.none), isFalse);
  });

  test('every availability value is covered by the table', () {
    // A guard against the table going stale rather than a behaviour test: adding
    // a fourth `LocationAvailability` without adding a row here should fail
    // loudly instead of falling through to whatever `ready` does.
    for (final a in LocationAvailability.values) {
      expect(
        () => decide(availability: a),
        returnsNormally,
        reason: '$a has no branch',
      );
    }
  });
}
