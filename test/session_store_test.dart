import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/session_store.dart';
import 'package:monkeyhub/models/family.dart';

/// Keychain stand-in that behaves the way the real one does on the two points
/// this file is about.
///
///  * **Reads see one accessibility class.** An item written under `unlocked`
///    is invisible to a read issued under `first_unlock_this_device`, which is
///    what makes the legacy fallback necessary at all.
///  * **Writes collide ACROSS classes.** `kSecAttrAccessible` is not part of a
///    generic password's primary key, so `SecItemAdd` for a key that already
///    exists on another shelf fails with `errSecDuplicateItem`. The plugin
///    only probes its own shelf first, so it takes the `SecItemAdd` branch and
///    the write throws.
///  * **Deletes ignore the class.** `performDelete` nils the accessibility
///    attribute, so it matches whichever shelf the item is on.
///  * **A read with no class matches every class** — the query simply has no
///    `kSecAttrAccessible` to filter on.
///
/// The package's own double gets all of them wrong, and every one of them is
/// load-bearing here.
class _KeychainDouble extends FlutterSecureStoragePlatform {
  /// accessibility class → (key → value).
  final Map<String, Map<String, String>> shelves = {};

  /// Set to make every `write` fail, standing in for a locked device.
  bool failWrites = false;

  String _shelf(Map<String, String> options) =>
      options['accessibility'] ?? 'unspecified';

  Map<String, String> flat() => {
    for (final shelf in shelves.values) ...shelf,
  };

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (!options.containsKey('accessibility')) return flat()[key];
    return shelves[_shelf(options)]?[key];
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (failWrites) throw StateError('errSecInteractionNotAllowed');
    final mine = _shelf(options);
    for (final entry in shelves.entries) {
      if (entry.key != mine && entry.value.containsKey(key)) {
        throw StateError('errSecDuplicateItem');
      }
    }
    (shelves[mine] ??= {})[key] = value;
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => shelves[_shelf(options)]?.containsKey(key) ?? false;

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    for (final shelf in shelves.values) {
      shelf.remove(key);
    }
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      shelves.clear();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => shelves[_shelf(options)] ?? {};
}

const _legacyShelf = 'unlocked';
const _blobKey = 'mh.session';

void main() {
  late _KeychainDouble keychain;
  final store = SessionStore.instance;

  /// Seed a session in the pre-blob, five-separate-items layout, on the old
  /// accessibility shelf — i.e. an install that upgraded and never re-signed-in.
  void seedLegacy({
    required String userId,
    required String username,
    String? token,
  }) {
    keychain.shelves[_legacyShelf] = {
      'mh.userId': userId,
      'mh.username': username,
      'mh.name': username,
      'mh.accountType': AccountType.adult.wire,
      'mh.hasSignedIn': 'true',
    };
    // Separately, because one of these tests seeds an identity with no token
    // at all — the shape a pre-token install left behind.
    if (token != null) {
      keychain.shelves[_legacyShelf]!['mh.sessionToken'] = token;
    }
  }

  setUp(() async {
    keychain = _KeychainDouble();
    FlutterSecureStoragePlatform.instance = keychain;
    // The legacy fallback only runs on iOS, and the plugin picks its options
    // off the same value.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    // SessionStore is a singleton with in-memory caches; a load against the
    // fresh keychain is what resets it between tests.
    await store.loadSession();
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
  });

  group('the session is one item', () {
    test('saving writes the blob and nothing else', () async {
      await store.saveSession(
        userId: 'u-lulu',
        username: 'lulu',
        name: 'Lulu',
        token: 't-lulu',
      );

      final stored = keychain.flat();
      expect(stored.keys, contains(_blobKey));
      // The five that used to be written one at a time. Their absence IS the
      // fix: there is no longer a window where half of one session and half of
      // another are both on disk.
      expect(stored.keys, isNot(contains('mh.userId')));
      expect(stored.keys, isNot(contains('mh.sessionToken')));
      expect(stored.keys, isNot(contains('mh.username')));

      final blob = jsonDecode(stored[_blobKey]!) as Map<String, dynamic>;
      expect(blob['userId'], 'u-lulu');
      expect(blob['username'], 'lulu');
      expect(blob['token'], 't-lulu');
    });

    test('a re-save without a token keeps the stored one', () async {
      await store.saveSession(
        userId: 'u-lulu',
        username: 'lulu',
        name: 'Lulu',
        token: 't-lulu',
      );
      await store.saveSession(
        userId: 'u-lulu',
        username: 'lulu',
        name: 'Lulu Renamed',
      );

      final session = await store.loadSession();
      expect(session!.name, 'Lulu Renamed');
      expect(store.token, 't-lulu');
    });
  });

  group('the pre-blob layout', () {
    test('an upgraded install still signs in, and is folded into one item',
        () async {
      seedLegacy(userId: 'u-goksu', username: 'goksu', token: 't-goksu');

      final session = await store.loadSession();
      expect(session, isNotNull);
      expect(session!.userId, 'u-goksu');
      expect(session.username, 'goksu');
      expect(store.token, 't-goksu');

      // Folded forward, and the old items are gone — a live one would be a
      // session `loadSession` could fall back to later.
      final stored = keychain.flat();
      expect(stored.keys, contains(_blobKey));
      expect(stored.keys, isNot(contains('mh.userId')));
      expect(stored.keys, isNot(contains('mh.sessionToken')));
    });

    test('an identity with no token is not a session', () async {
      seedLegacy(userId: 'u-old', username: 'old');

      expect(await store.loadSession(), isNull);
      expect(keychain.flat().keys, isNot(contains('mh.userId')));
    });

    /// THE regression. A legacy item on the old shelf used to make the next
    /// sign-in's write fail with `errSecDuplicateItem`, which was swallowed —
    /// so the new session never reached disk and the next cold start restored
    /// the OLD account. That is the reported bug, in one test.
    test('signing in over a legacy item lands, and the old account is gone',
        () async {
      seedLegacy(userId: 'u-goksu', username: 'goksu', token: 't-goksu');

      await store.saveSession(
        userId: 'u-lulu',
        username: 'lulu',
        name: 'Lulu',
        token: 't-lulu',
      );

      final session = await store.loadSession();
      expect(session!.username, 'lulu');
      expect(session.userId, 'u-lulu');
      expect(store.token, 't-lulu');
    });

    test('a failed migration write still returns the session it read',
        () async {
      seedLegacy(userId: 'u-goksu', username: 'goksu', token: 't-goksu');
      keychain.failWrites = true;

      // Re-stamping is best effort. Losing the value because the re-stamp
      // failed is how "your keychain is busy" became "you are signed out".
      final session = await store.loadSession();
      expect(session, isNotNull);
      expect(session!.username, 'goksu');
      expect(store.token, 't-goksu');
    });
  });

  // 1.3.105's settings migration moved every `unlocked` item into
  // `first_unlock`, whatever store it belonged to. A session left on the
  // legacy shelf went with it, onto a shelf this store never used to ask.
  group('items another store moved', () {
    test('a session swept into first_unlock still signs in', () async {
      keychain.shelves['first_unlock'] = {
        _blobKey: jsonEncode({
          'v': 1,
          'userId': 'u-goksu',
          'token': 't-goksu',
          'username': 'goksu',
          'name': 'Göksu',
          'accountType': AccountType.adult.wire,
        }),
        'mh.isChildDevice': 'true',
      };

      final session = await store.loadSession();

      expect(session?.userId, 'u-goksu');
      expect(store.token, 't-goksu');
      expect(store.isChildDevice, isTrue,
          reason: 'a child handset must not start offering the adult form');
      expect(keychain.shelves['first_unlock_this_device']?[_blobKey],
          isNotNull, reason: 'moved home, so a locked launch reads it');
      expect(keychain.shelves['first_unlock'], isEmpty);
    });
  });

  group('clearing', () {
    test('signing out removes both layouts', () async {
      seedLegacy(userId: 'u-goksu', username: 'goksu', token: 't-goksu');
      await store.saveSession(
        userId: 'u-lulu',
        username: 'lulu',
        name: 'Lulu',
        token: 't-lulu',
      );

      await store.clearSession();

      expect(await store.loadSession(), isNull);
      expect(store.token, isNull);
      final stored = keychain.flat();
      expect(stored.keys, isNot(contains(_blobKey)));
      expect(stored.keys, isNot(contains('mh.userId')));
    });

    test('the token of a session that ended is kept for its teardown', () async {
      // Signing out is local-first: this store is emptied BEFORE `auth:logout`
      // and `voipTokens:clearDeviceToken` are sent. Both are authenticated, so
      // without this the two calls that revoke the session and delete the push
      // row went out with an empty token, were rejected, and had their errors
      // swallowed — leaving a signed-out handset still receiving that
      // account's notifications.
      await store.saveSession(
        userId: 'u-lulu',
        username: 'lulu',
        name: 'Lulu',
        token: 't-lulu',
      );
      expect(store.outgoingToken, isNull);

      await store.clearSession();

      expect(store.token, isNull);
      expect(store.outgoingToken, 't-lulu');

      // A second pass over the same sign-out must not wipe what the teardown
      // in flight is about to use.
      await store.clearSession();
      expect(store.outgoingToken, 't-lulu');

      // The next sign-in is where the outgoing session stops being anyone's
      // business.
      await store.saveSession(
        userId: 'u-goksu',
        username: 'goksu',
        name: 'Goksu',
        token: 't-goksu',
      );
      expect(store.outgoingToken, isNull);
    });

    test('a launch inherits no teardown', () async {
      await store.saveSession(
        userId: 'u-lulu',
        username: 'lulu',
        name: 'Lulu',
        token: 't-lulu',
      );
      await store.clearSession();
      expect(store.outgoingToken, isNotNull);

      await store.loadSession();

      expect(store.outgoingToken, isNull);
    });

    test('the handset markers outlive the session', () async {
      await store.saveSession(
        userId: 'u-lulu',
        username: 'lulu',
        name: 'Lulu',
        token: 't-lulu',
      );
      await store.clearSession();
      await store.loadSession();

      // Deliberate, and documented on the fields: signing out does not make
      // the device new again.
      expect(store.hasSignedInBefore, isTrue);
    });
  });
}
