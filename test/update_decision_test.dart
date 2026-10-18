import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/app_release.dart';
import 'package:monkeyhub/update/apple_store.dart';
import 'package:monkeyhub/update/store_answer.dart';
import 'package:monkeyhub/update/update_watch_action.dart';

/// Store channels stopped trusting the release row's version: it says what
/// deploy.sh uploaded, and an upload in review or certification is not
/// something the install can get. [decideUpdate] is where the store's answer
/// and the row's minSupported/notes meet, and both of its failure modes are
/// quiet: a prompt for a build the store doesn't have, or a mandatory sheet
/// whose button can't get the user out. Pinned here.

AppRelease _row(String version, {String? minSupported, String? notes}) =>
    AppRelease(
      channel: 'ios-appstore',
      version: version,
      minSupported: minSupported,
      notes: notes,
      publishedAt: 0,
    );

void main() {
  group('the store decides whether there is an update', () {
    test('a row ahead of the store (upload in review) prompts nobody', () {
      final d = decideUpdate(
        release: _row('1.3.140'),
        store: StoreAnswer.upToDate,
        currentVersion: '1.3.133',
        isFirstDelivery: true,
      );
      expect(d.action, UpdateWatchAction.clearBadge);
    });

    test('the offered version is the store\'s, not the upload\'s', () {
      final d = decideUpdate(
        release: _row('1.3.140'),
        store: const StoreAnswer(StoreVerdict.available, version: '1.3.135'),
        currentVersion: '1.3.133',
        isFirstDelivery: true,
      );
      expect(d.action, UpdateWatchAction.badgeOnly);
      expect(d.release!.version, '1.3.135');
    });

    test('a store with no answer leaves everything alone', () {
      final d = decideUpdate(
        release: _row('1.3.140', minSupported: '1.3.140'),
        store: StoreAnswer.noAnswer,
        currentVersion: '1.3.133',
        isFirstDelivery: false,
      );
      expect(d.action, UpdateWatchAction.ignore);
    });

    test('a store version no newer than the running one is not an update', () {
      final d = decideUpdate(
        release: null,
        store: const StoreAnswer(StoreVerdict.available, version: '1.3.133'),
        currentVersion: '1.3.133',
        isFirstDelivery: true,
      );
      expect(d.action, UpdateWatchAction.clearBadge);
    });

    test('works with no release row at all', () {
      final d = decideUpdate(
        release: null,
        store: const StoreAnswer(StoreVerdict.available, version: '1.3.134'),
        currentVersion: '1.3.133',
        isFirstDelivery: true,
      );
      expect(d.action, UpdateWatchAction.badgeOnly);
      expect(d.release!.version, '1.3.134');
      expect(d.mandatory, isFalse);
    });

    test('Play names no version, so the row\'s stands in for display', () {
      final d = decideUpdate(
        release: _row('1.3.134'),
        store: const StoreAnswer(StoreVerdict.available),
        currentVersion: '1.3.133',
        isFirstDelivery: true,
      );
      expect(d.release!.version, '1.3.134');
    });
  });

  group('mandatory only when updating actually gets the user out', () {
    test('a minimum raised ahead of approval does not lock anyone in', () {
      // Store still serves 1.3.135; the minimum is the build in review.
      final d = decideUpdate(
        release: _row('1.3.140', minSupported: '1.3.140'),
        store: const StoreAnswer(StoreVerdict.available, version: '1.3.135'),
        currentVersion: '1.3.133',
        isFirstDelivery: false,
      );
      expect(d.mandatory, isFalse);
      expect(d.action, UpdateWatchAction.badgeOnly);
    });

    test('a store version that clears the minimum is mandatory', () {
      final d = decideUpdate(
        release: _row('1.3.140', minSupported: '1.3.135'),
        store: const StoreAnswer(StoreVerdict.available, version: '1.3.135'),
        currentVersion: '1.3.133',
        isFirstDelivery: false,
      );
      expect(d.mandatory, isTrue);
      expect(d.action, UpdateWatchAction.badgeAndPrompt);
    });

    test('the first delivery never prompts, mandatory or not', () {
      final d = decideUpdate(
        release: _row('1.3.135', minSupported: '1.3.135'),
        store: const StoreAnswer(StoreVerdict.available, version: '1.3.135'),
        currentVersion: '1.3.133',
        isFirstDelivery: true,
      );
      expect(d.mandatory, isTrue);
      expect(d.action, UpdateWatchAction.badgeOnly);
    });

    test('an unknown store version (Play) trusts the store\'s yes', () {
      final d = decideUpdate(
        release: _row('1.3.135', minSupported: '1.3.135'),
        store: const StoreAnswer(StoreVerdict.available),
        currentVersion: '1.3.133',
        isFirstDelivery: false,
      );
      expect(d.mandatory, isTrue);
    });
  });

  group('notes describe one build', () {
    test('shown when the row is about the offered build', () {
      final d = decideUpdate(
        release: _row('1.3.135', notes: 'Fixes ringing'),
        store: const StoreAnswer(StoreVerdict.available, version: '1.3.135'),
        currentVersion: '1.3.133',
        isFirstDelivery: true,
      );
      expect(d.release!.notes, 'Fixes ringing');
    });

    test('dropped when the row is about a build still in review', () {
      final d = decideUpdate(
        release: _row('1.3.140', notes: 'Fixes ringing'),
        store: const StoreAnswer(StoreVerdict.available, version: '1.3.135'),
        currentVersion: '1.3.133',
        isFirstDelivery: true,
      );
      expect(d.release!.notes, isNull);
    });
  });

  test('channels with no store fall through to the row, unchanged', () {
    final d = decideUpdate(
      release: _row('1.3.134', minSupported: '1.3.134'),
      store: StoreAnswer.notApplicable,
      currentVersion: '1.3.133',
      isFirstDelivery: false,
    );
    expect(d.action, UpdateWatchAction.badgeAndPrompt);
    expect(d.release!.version, '1.3.134');
  });

  group('App Store lookup', () {
    const body = '''
{"resultCount":2,"results":[
 {"kind":"software","trackId":6739744338,"version":"1.3.135"},
 {"kind":"mac-software","trackId":6739744338,"version":"1.3.131"}]}''';

    test('picks the record for the asking platform', () {
      expect(parseAppStoreLookup(body, mac: false), '1.3.135');
      expect(parseAppStoreLookup(body, mac: true), '1.3.131');
    });

    test('a record of the wrong kind is no answer, never a version', () {
      const iosOnly =
          '{"results":[{"kind":"software","trackId":6739744338,"version":"1.3.135"}]}';
      expect(parseAppStoreLookup(iosOnly, mac: true), isNull);
    });

    test('another app\'s record is ignored', () {
      const other =
          '{"results":[{"kind":"software","trackId":1,"version":"9.9.9"}]}';
      expect(parseAppStoreLookup(other, mac: false), isNull);
    });

    test('an empty or malformed body is no answer', () {
      expect(parseAppStoreLookup('{"resultCount":0,"results":[]}', mac: false),
          isNull);
      expect(parseAppStoreLookup('<html>', mac: false), isNull);
    });

    test('StoreKit\'s alpha-3 storefront maps to the lookup\'s alpha-2', () {
      expect(alpha3ToAlpha2('TUR'), 'tr');
      expect(alpha3ToAlpha2('usa'), 'us');
      expect(alpha3ToAlpha2('XXX'), isNull);
    });
  });
}
