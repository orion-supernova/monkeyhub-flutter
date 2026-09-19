import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_keychain.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/push/device_identity.dart';

/// Keychain stand-in that models the two iOS behaviours this whole change is
/// about:
///
/// * items are shelved by accessibility class, and a query only sees its own
///   class — except `delete`, which matches every class;
/// * a class can be LOCKED, which makes any query against it throw, the way
///   `errSecInteractionNotAllowed (-25308)` does for `unlocked` items on a
///   locked phone.
///
/// A write that lands on a key already held under ANOTHER class throws too,
/// because accessibility is not part of a generic password's primary key and
/// the real `SecItemAdd` fails with `errSecDuplicateItem`.
class _Keychain extends FlutterSecureStoragePlatform {
  final Map<String, Map<String, String>> shelves = {};
  final Set<String> locked = {};
  final List<String> writes = [];
  int legacyReads = 0;

  String _shelf(Map<String, String> o) => o['accessibility'] ?? 'unspecified';

  void _gate(String shelf) {
    if (locked.contains(shelf)) {
      throw StateError('errSecInteractionNotAllowed ($shelf)');
    }
  }

  /// A read with no class matches every shelf, as a query with no
  /// `kSecAttrAccessible` does.
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (!options.containsKey('accessibility')) {
      for (final e in shelves.entries) {
        if (e.value.containsKey(key)) {
          _gate(e.key);
          return e.value[key];
        }
      }
      return null;
    }
    _gate(_shelf(options));
    return shelves[_shelf(options)]?[key];
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    final shelf = _shelf(options);
    if (shelf == 'unlocked') legacyReads++;
    _gate(shelf);
    return {...?shelves[shelf]};
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final shelf = _shelf(options);
    _gate(shelf);
    for (final e in shelves.entries) {
      if (e.key != shelf && e.value.containsKey(key)) {
        throw StateError('errSecDuplicateItem ($key under ${e.key})');
      }
    }
    writes.add('$shelf/$key=$value');
    (shelves[shelf] ??= {})[key] = value;
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      shelves[_shelf(options)]?.containsKey(key) ?? false;

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
      shelves[_shelf(options)]?.clear();
}

const _new = 'first_unlock';
const _legacy = 'unlocked';

SettingsKeychain _settings() => SettingsKeychain(keys: SettingsStore.keys);

void main() {
  late _Keychain keychain;

  setUp(() {
    keychain = _Keychain();
    FlutterSecureStoragePlatform.instance = keychain;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('SettingsKeychain', () {
    test('preferences an older build wrote survive the upgrade', () async {
      keychain.shelves[_legacy] = {'mh.pushEnabled': 'false'};

      final values = await _settings().readAll();

      expect(values['mh.pushEnabled'], 'false');
    });

    test('migration re-stamps them, after which the legacy class is never read',
        () async {
      keychain.shelves[_legacy] = {'mh.pushEnabled': 'false'};
      final first = _settings();
      await first.readAll();
      await first.migrate();

      expect(keychain.shelves[_new]?['mh.pushEnabled'], 'false');
      expect(keychain.shelves[_legacy], isEmpty);

      // The next launch, on a locked phone: the legacy class would throw, and
      // it is not even asked.
      keychain.locked.add(_legacy);
      keychain.legacyReads = 0;
      final values = await _settings().readAll();
      expect(values['mh.pushEnabled'], 'false');
      expect(keychain.legacyReads, 0);
    });

    // The bug itself. The old store swallowed this throw and carried on with
    // "every notification on".
    test('an unreadable keychain throws instead of answering "nothing stored"',
        () async {
      keychain.shelves[_legacy] = {'mh.pushEnabled': 'false'};
      keychain.locked.add(_legacy);

      await expectLater(_settings().readAll(), throwsStateError);
    });

    test('a write before migration replaces the legacy item instead of failing',
        () async {
      keychain.shelves[_legacy] = {'mh.gameReminders': 'true'};
      final store = _settings();

      await store.write(key: 'mh.gameReminders', value: 'false');

      expect(keychain.shelves[_new]?['mh.gameReminders'], 'false');
      expect((await store.readAll())['mh.gameReminders'], 'false');
    });

    test('a write that cannot land yet still wins every read, and is replayed',
        () async {
      final store = _settings();
      await store.readAll();
      keychain.locked.add(_new);

      await store.write(key: 'mh.friendActivity', value: 'false');
      expect(keychain.shelves[_new]?['mh.friendActivity'], isNull);

      keychain.locked.remove(_new);
      expect((await store.readAll())['mh.friendActivity'], 'false');
      expect(await store.flush(), isTrue);
      expect(keychain.shelves[_new]?['mh.friendActivity'], 'false');
    });

    test('a newer write is not overwritten by the value being migrated',
        () async {
      keychain.shelves[_legacy] = {'mh.pushEnabled': 'false'};
      final store = _settings();
      await store.readAll();
      keychain.locked.add(_new);
      await store.write(key: 'mh.pushEnabled', value: 'true');
      keychain.locked.remove(_new);

      await store.migrate();
      await store.flush();

      expect(keychain.shelves[_new]?['mh.pushEnabled'], 'true');
    });

    test('Android has no legacy class to consult', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      // Android options carry no iOS accessibility class at all.
      keychain.shelves['unspecified'] = {'mh.pushEnabled': 'false'};
      keychain.locked.add(_legacy);

      final values = await _settings().readAll();

      expect(values['mh.pushEnabled'], 'false');
      expect(keychain.legacyReads, 0);
    });

    // The 1.3.105 incident. The legacy class is shared with every other store
    // the app keeps, and the migration moved all of it into `first_unlock`,
    // where none of their reads looked.
    test('only the preferences leave the legacy class', () async {
      const foreign = {
        'monkeyhub.device_id': 'the-real-id',
        'mh.sessionToken': 't-goksu',
        'mh.server.url': 'https://example.org',
      };
      keychain.shelves[_legacy] = {'mh.pushEnabled': 'false', ...foreign};
      final store = _settings();

      final values = await store.readAll();
      await store.migrate();

      expect(values.keys, isNot(contains('monkeyhub.device_id')));
      expect(keychain.shelves[_new]?['mh.pushEnabled'], 'false');
      expect(keychain.shelves[_legacy], foreign,
          reason: "other stores' items stay where those stores look");
    });

    test('the device id survives it, so the calling stack can attach',
        () async {
      keychain.shelves[_legacy] = {
        'mh.pushEnabled': 'false',
        'monkeyhub.device_id': 'the-real-id',
      };
      final store = _settings();
      await store.readAll();
      await store.migrate();
      DeviceIdentity.resetCacheForTest();

      expect(await DeviceIdentity.ensure(), 'the-real-id');
    });
  });

  // End to end through the singleton, in the order a real update produces:
  // a background launch on a locked phone, then the user opening the app.
  test('SettingsStore: a locked launch holds its read until the first resume',
      () async {
    keychain.shelves[_legacy] = {
      'mh.pushEnabled': 'false',
      'mh.gameReminders': 'false',
      'mh.friendActivity': 'false',
    };
    keychain.locked.add(_legacy);
    final store = SettingsStore.instance;
    var ready = false;
    unawaited(store.ready.then((_) => ready = true));

    await store.load();
    await pumpEventQueue();

    expect(store.loaded, isTrue, reason: 'the app must still boot');
    expect(ready, isFalse, reason: 'defaults must not pass for the real thing');

    keychain.locked.clear();
    expect(await store.retryIfUnread(), isTrue);
    await pumpEventQueue();

    expect(ready, isTrue);
    expect(store.pushEnabled, isFalse);
    expect(store.gameReminders, isFalse);
    expect(store.friendActivity, isFalse);
    expect(await store.retryIfUnread(), isFalse,
        reason: 'free once the preferences have been read');
  });
}
