import 'dart:io';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/linux_secure_storage_io.dart';

/// Stands in for the libsecret plugin: a fixed set of items, or a keyring
/// that throws on every call the way a locked or absent one does.
class _Keyring extends FlutterSecureStoragePlatform {
  _Keyring([this.items = const {}, this.fails = false]);
  final Map<String, String> items;
  final bool fails;
  int readAlls = 0;

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    readAlls++;
    if (fails) throw Exception('KeyringLocked');
    return Map.of(items);
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) =>
      throw UnimplementedError();
  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) =>
      throw UnimplementedError();
  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) =>
      throw UnimplementedError();
  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) =>
      throw UnimplementedError();
  @override
  Future<void> deleteAll({required Map<String, String> options}) =>
      throw UnimplementedError();
}

void main() {
  late Directory dir;
  const none = <String, String>{};

  setUp(() => dir = Directory.systemTemp.createTempSync('mh-secure-'));
  tearDown(() => dir.deleteSync(recursive: true));

  LinuxFileSecureStorage open(_Keyring keyring) => LinuxFileSecureStorage(
        keyring: keyring,
        directory: () async => dir,
      );

  // The bug: a session written on one launch was gone on the next.
  test('a value written survives a fresh instance (a relaunch)', () async {
    await open(_Keyring()).write(key: 'mh.session', value: '{"v":1}', options: none);

    expect(await open(_Keyring()).read(key: 'mh.session', options: none), '{"v":1}');
  });

  test('what an older build kept in the keyring is brought over once', () async {
    final keyring = _Keyring({'mh.session': 'old', 'mh.deviceId': 'dev-1'});
    final first = open(keyring);

    expect(await first.read(key: 'mh.deviceId', options: none), 'dev-1');
    expect(await first.read(key: 'mh.session', options: none), 'old');
    expect(keyring.readAlls, 1);
  });

  // The resurrection: sign out here, keyring still holds the session, and a
  // second import would sign the user straight back in.
  test('a deleted value does not come back from the keyring', () async {
    final keyring = _Keyring({'mh.session': 'old'});
    await open(keyring).delete(key: 'mh.session', options: none);

    expect(await open(keyring).read(key: 'mh.session', options: none), isNull);
    expect(keyring.readAlls, 1);
  });

  test('a locked keyring costs the import, not the launch', () async {
    final keyring = _Keyring(const {}, true);
    final store = open(keyring);

    await store.write(key: 'mh.session', value: 'new', options: none);

    expect(await open(keyring).read(key: 'mh.session', options: none), 'new');
    expect(keyring.readAlls, 1);
  });

  test('a corrupt file reads as empty instead of throwing', () async {
    File('${dir.path}/secure_store.json').writeAsStringSync('{not json');

    expect(await open(_Keyring()).read(key: 'mh.session', options: none), isNull);
  });

  test('the file is private to its owner', () async {
    await open(_Keyring()).write(key: 'k', value: 'v', options: none);

    final mode = File('${dir.path}/secure_store.json').statSync().mode & 0x1ff;
    expect(mode, 0x180); // 0600
  });
}
