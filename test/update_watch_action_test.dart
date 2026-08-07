import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/app_release.dart';
import 'package:monkeyhub/update/release_channel.dart';
import 'package:monkeyhub/update/update_availability.dart';
import 'package:monkeyhub/update/update_watch_action.dart';

/// The update badge is now driven by a live subscription rather than a
/// once-per-launch check, and every failure mode of that is quiet: a delivery
/// mishandled one way leaves users on a build we've stopped supporting, and
/// the other way throws a non-dismissible sheet over a conversation because a
/// release happened to land. [decideWatchAction] is where that judgement lives,
/// so it's pinned here.

AppRelease _release(String version, {String? minSupported}) => AppRelease(
  channel: 'ios-appstore',
  version: version,
  minSupported: minSupported,
  publishedAt: 0,
);

void main() {
  group('deliveries that say nothing', () {
    test('null — nothing published for this channel yet', () {
      final d = decideWatchAction(
        release: null,
        currentVersion: '1.3.62',
        isFirstDelivery: true,
      );
      expect(d.action, UpdateWatchAction.ignore);
    });

    test('a row with no version is a malformed row, not an answer', () {
      final d = decideWatchAction(
        release: _release(''),
        currentVersion: '1.3.62',
        isFirstDelivery: false,
      );
      expect(d.action, UpdateWatchAction.ignore);
    });
  });

  group('badge, silently', () {
    test('a newer build on the first delivery lights the badge only', () {
      // ensure() already owns the cold-start sheet; this must not race it.
      final d = decideWatchAction(
        release: _release('1.3.63'),
        currentVersion: '1.3.62',
        isFirstDelivery: true,
      );
      expect(d.action, UpdateWatchAction.badgeOnly);
      expect(d.mandatory, isFalse);
    });

    test('a newer build published mid-session still never prompts', () {
      final d = decideWatchAction(
        release: _release('1.3.63'),
        currentVersion: '1.3.62',
        isFirstDelivery: false,
      );
      expect(d.action, UpdateWatchAction.badgeOnly);
    });

    test('the double-digit case that a string compare gets wrong', () {
      final d = decideWatchAction(
        release: _release('1.3.100'),
        currentVersion: '1.3.99',
        isFirstDelivery: false,
      );
      expect(d.action, UpdateWatchAction.badgeOnly);
    });
  });

  group('mandatory', () {
    test('below minSupported mid-session interrupts', () {
      final d = decideWatchAction(
        release: _release('1.4.0', minSupported: '1.3.63'),
        currentVersion: '1.3.62',
        isFirstDelivery: false,
      );
      expect(d.action, UpdateWatchAction.badgeAndPrompt);
      expect(d.mandatory, isTrue);
    });

    test(
      'mandatory on the FIRST delivery still only badges — but records '
      'mandatory, so the row and the cold-start sheet agree',
      () {
        final d = decideWatchAction(
          release: _release('1.4.0', minSupported: '1.3.63'),
          currentVersion: '1.3.62',
          isFirstDelivery: true,
        );
        expect(d.action, UpdateWatchAction.badgeOnly);
        expect(d.mandatory, isTrue);
      },
    );

    test('at minSupported exactly is supported, not mandatory', () {
      final d = decideWatchAction(
        release: _release('1.4.0', minSupported: '1.3.62'),
        currentVersion: '1.3.62',
        isFirstDelivery: false,
      );
      expect(d.action, UpdateWatchAction.badgeOnly);
      expect(d.mandatory, isFalse);
    });

    test('an empty minSupported is not a floor', () {
      final d = decideWatchAction(
        release: _release('1.4.0', minSupported: ''),
        currentVersion: '1.3.62',
        isFirstDelivery: false,
      );
      expect(d.mandatory, isFalse);
    });
  });

  group('retraction', () {
    test('a release we are already on clears the badge', () {
      final d = decideWatchAction(
        release: _release('1.3.62'),
        currentVersion: '1.3.62',
        isFirstDelivery: false,
      );
      expect(d.action, UpdateWatchAction.clearBadge);
    });

    test('a rollback to a lower version clears too', () {
      final d = decideWatchAction(
        release: _release('1.3.61'),
        currentVersion: '1.3.62',
        isFirstDelivery: false,
      );
      expect(d.action, UpdateWatchAction.clearBadge);
    });
  });

  group('UpdateAvailability.clear', () {
    setUp(UpdateAvailability.instance.resetForTest);

    test('retracts a reported update', () {
      UpdateAvailability.instance.report(
        release: _release('1.3.63'),
        channel: ReleaseChannel.iosAppstore,
        currentVersion: '1.3.62',
        mandatory: false,
      );
      expect(UpdateAvailability.instance.available, isTrue);

      UpdateAvailability.instance.clear();
      expect(UpdateAvailability.instance.available, isFalse);
      expect(UpdateAvailability.instance.mandatory, isFalse);
      expect(UpdateAvailability.instance.release, isNull);
    });

    test('does not notify when there was nothing to clear', () {
      // A steady stream of "still up to date" deliveries would otherwise
      // rebuild all three nav chromes for nothing.
      var notifications = 0;
      void listener() => notifications++;
      UpdateAvailability.instance.addListener(listener);
      addTearDown(() => UpdateAvailability.instance.removeListener(listener));

      UpdateAvailability.instance.clear();
      UpdateAvailability.instance.clear();
      expect(notifications, 0);
    });
  });
}
