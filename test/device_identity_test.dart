import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/push/device_identity.dart';

/// Keychain stand-in that, unlike the package's own test double, keys on the
/// accessibility class in `options`.
///
/// That distinction is the entire subject of these tests: an item written under
/// one accessibility attribute may be invisible to a read issued under another,
/// and a double that ignores `options` cannot show the bug or the fix.
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
  }) async => shelves[_shelf(options)]?[key];

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final shelf = _shelf(options);
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
  }) async => shelves[_shelf(options)]?.remove(key);

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
