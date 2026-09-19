import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A keychain store that finds its items whichever accessibility class they
/// were written under.
///
/// Every query the plugin issues carries `kSecAttrAccessible` — `read`,
/// `readAll`, and the `containsKey` probe inside `write` alike — so an item
/// stored under one class is invisible to a store that asks under another. The
/// `SecItemAdd` that `write` then falls through to fails with
/// `errSecDuplicateItem (-25299)`, because accessibility is not part of a
/// generic password's primary key. Only `delete` matches across classes.
///
/// Items do move under a store's feet. 1.3.105's settings migration re-stamped
/// every item it found under `unlocked` into `first_unlock` — not only the
/// preferences but the device id, the server choice and the directive — while
/// each of those stores kept asking under its own class. `DeviceIdentity` then
/// found no id, minted one and failed to write it on every launch, so the
/// calling stack never attached and push never registered.
///
/// So: a read that misses [home] asks again with no accessibility attribute at
/// all, which matches any class, and moves a hit into [home]. A write deletes
/// first, so it replaces the item wherever it sits instead of throwing.
class AnyClassKeychain {
  const AnyClassKeychain(this.home);

  /// The class this store reads and writes under.
  final FlutterSecureStorage home;

  /// No accessibility attribute, which is what makes the query match any class.
  static const _anyClass = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: null),
  );

  /// [key] from [home], else from wherever [readElsewhere] finds it.
  ///
  /// Read failures propagate: "the keychain is locked right now" must never
  /// read as "there is no item", or a caller would mint over the real value.
  Future<String?> read({required String key}) async {
    final value = await home.read(key: key);
    if (value != null) return value;
    return readElsewhere(key: key);
  }

  /// [key] from whichever class it is actually under — on iOS, the only
  /// platform with classes — moved into [home] on the way so the next read is
  /// direct.
  ///
  /// The move is best effort, since the value is already in hand; a failed one
  /// is simply repeated by the next read.
  Future<String?> readElsewhere({required String key}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    final stray = await _anyClass.read(key: key);
    if (stray == null) return null;
    try {
      await write(key: key, value: stray);
    } catch (_) {/* still readable through this path next time */}
    return stray;
  }

  /// Writes [key] under [home], replacing it whatever class it is under now.
  Future<void> write({required String key, required String value}) async {
    await home.delete(key: key);
    await home.write(key: key, value: value);
  }

  Future<void> delete({required String key}) => home.delete(key: key);
}
