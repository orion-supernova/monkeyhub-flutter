import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/push/device_identity.dart';

/// Keychain stand-in that, unlike the package's own test double, keys on the
/// accessibility class in `options`.
///
/// That distinction is the entire subject of these tests: an item written under
/// one accessibility attribute may be invisible to a read issued under another,
/// and a double that ignores `options` cannot show the bug or the fix. It also
/// behaves like the real keychain on the three points that follow from it:
///
///  * a write collides with the same key on ANOTHER shelf — accessibility is
///    not part of a generic password's primary key, so `SecItemAdd` fails with
///    `errSecDuplicateItem`. This double used to accept it, which is how a
///    re-stamp that failed on every real launch passed here;
///  * a delete matches every shelf (`performDelete` nils the class);
///  * a read with no class matches every shelf.
class AccessibilityAwareStorage extends FlutterSecureStoragePlatform {
  /// accessibility class → (key → value).
  final Map<String, Map<String, String>> shelves = {};

  /// Every write, in order, as `accessibility/key=value`. Proves the migration
  /// re-stamped the item rather than merely reading it.
  final List<String> writes = [];

  String _shelf(Map<String, String> options) =>
      options['accessibility'] ?? 'unspecified';

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (options.containsKey('accessibility')) {
      return shelves[_shelf(options)]?[key];
    }
    for (final shelf in shelves.values) {
      if (shelf.containsKey(key)) return shelf[key];
    }
    return null;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final shelf = _shelf(options);
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
      shelves[_shelf(options)]?.clear();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => shelves[_shelf(options)] ?? {};
}

const _key = 'monkeyhub.device_id';
const _new = 'first_unlock_this_device';
const _legacy = 'unlocked';
const _swept = 'first_unlock';

void main() {
  late AccessibilityAwareStorage storage;

  setUp(() {
    storage = AccessibilityAwareStorage();
    FlutterSecureStoragePlatform.instance = storage;
    DeviceIdentity.resetCacheForTest();
    // The migration only applies to the iOS keychain, and the storage plugin
    // selects its per-platform options off this same value.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  // The one that matters. Moving to `first_unlock_this_device` makes the item
  // an existing install already wrote invisible to the new read — so without
  // the fallback, every upgrading device would mint a FRESH id here, orphaning
  // its backend device row and its registered VoIP token. That is a worse
  // outcome than the locked-launch bug the accessibility change fixes.
  test('an id written under the legacy class survives the upgrade', () async {
    storage.shelves[_legacy] = {_key: 'id-from-before-the-upgrade'};

    final id = await DeviceIdentity.ensure();

    expect(id, 'id-from-before-the-upgrade');
  });

  test('the migrated id is re-stamped so the next locked launch can read it',
      () async {
    storage.shelves[_legacy] = {_key: 'id-from-before-the-upgrade'};

    await DeviceIdentity.ensure();

    expect(storage.shelves[_new]?[_key], 'id-from-before-the-upgrade');
    expect(
      storage.writes,
      ['$_new/$_key=id-from-before-the-upgrade'],
      reason: 'exactly one write, and none of it under the legacy class',
    );
  });

  // The 1.3.105 incident. The settings migration swept every `unlocked` item
  // into `first_unlock` — the id included, still on the legacy shelf because
  // the re-stamp above never landed on a real device. Neither read looked
  // there, so the id was re-minted, the write collided with the swept item,
  // and this threw on every launch: no calling stack, no push registration.
  test('an id swept into first_unlock is found, not re-minted', () async {
    storage.shelves[_swept] = {_key: 'the-real-id'};

    final id = await DeviceIdentity.ensure();

    expect(id, 'the-real-id');
    expect(storage.shelves[_new]?[_key], 'the-real-id',
        reason: 'moved home, so the next locked launch reads it directly');
    expect(storage.shelves[_swept], isEmpty);
  });

  test('a locked keychain elsewhere propagates instead of minting', () async {
    FlutterSecureStoragePlatform.instance = _LockedElsewhereStorage();

    await expectLater(DeviceIdentity.ensure(), throwsA(isA<StateError>()));
  });

  test('an id already under the new class is returned without a write',
      () async {
    storage.shelves[_new] = {_key: 'already-migrated'};

    final id = await DeviceIdentity.ensure();

    expect(id, 'already-migrated');
    expect(storage.writes, isEmpty);
  });

  test('a first launch mints one id, under the new class', () async {
    final id = await DeviceIdentity.ensure();

    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
      reason: 'RFC-4122 v4',
    );
    expect(storage.shelves[_new]?[_key], id);
    expect(storage.shelves[_legacy], isNull);
  });

  // A locked device throws rather than returning null, and that difference is
  // load-bearing: "unreadable right now" collapsing into "absent" is exactly
  // how a fresh id would get minted over a real one. Callers retry on resume.
  test('a keychain failure propagates instead of minting over the real id',
      () async {
    FlutterSecureStoragePlatform.instance = _ThrowingStorage();

    await expectLater(DeviceIdentity.ensure(), throwsA(isA<StateError>()));
  });
}

class _ThrowingStorage extends AccessibilityAwareStorage {
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => throw StateError('User interaction is not allowed.');
}

/// Our own class answers "nothing", but the item lives under a class that is
/// locked right now — the any-class read throws.
class _LockedElsewhereStorage extends AccessibilityAwareStorage {
  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    if (!options.containsKey('accessibility')) {
      throw StateError('User interaction is not allowed.');
    }
    return super.read(key: key, options: options);
  }
}
