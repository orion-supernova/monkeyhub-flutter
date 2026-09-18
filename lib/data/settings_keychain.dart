import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The keychain [SettingsStore] persists through.
///
/// Exists because the store used to read its ~40 keys one at a time under the
/// `unlocked` accessibility class, and that combination reset people's
/// preferences after every app update. An update kills the process, so the next
/// launch is a cold one — and on iOS that is very often a BACKGROUND launch (a
/// silent dismiss push, a VoIP call) on a locked phone, where an `unlocked`
/// item throws `errSecInteractionNotAllowed (-25308)`. The store swallowed the
/// throw and carried on with its defaults for the life of the process, so the
/// person who unlocked and opened the app found push notifications, the daily
/// reminder and friend activity all switched back on, and the rest of their
/// choices quietly reverted too.
///
/// Three changes, all here:
///
/// * **`first_unlock`**, the class [SessionStore] and `DeviceIdentity` already
///   moved to for the same reason: readable from the first unlock after boot
///   onward, locked or not. Not `…_this_device`, because these are
///   preferences, and preferences are exactly what should follow a person to a
///   new phone restored from an encrypted backup — which is what `unlocked`
///   allowed before.
/// * **One round trip.** [readAll] returns the whole store in a single
///   platform call instead of forty sequential ones on the launch path.
/// * **"Unreadable" is not "absent".** A failed read throws, and the store
///   keeps the read pending instead of adopting defaults as if they were the
///   user's — see `SettingsStore.retryIfUnread`.
///
/// Items an older build wrote under `unlocked` are read through [_legacy] and
/// re-stamped under the new class once, after which [_kMigrated] lets every
/// later launch skip the legacy lookup entirely.
class SettingsKeychain {
  SettingsKeychain({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
    FlutterSecureStorage legacy = const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
    ),
  })  : _storage = storage,
        _legacy = legacy;

  final FlutterSecureStorage _storage;
  final FlutterSecureStorage _legacy;

  /// Written once every legacy item has been re-stamped.
  static const _kMigrated = 'mh.settings.keychainV2';

  /// Whether this install still has (or may still have) items under the
  /// legacy class. Until it is known not to, every write deletes first — see
  /// [write].
  bool _migrated = false;

  /// Legacy-only values found by the last [readAll], waiting for [migrate].
  Map<String, String> _toRestamp = const {};

  /// Writes that failed — almost always a locked device — keyed to the value
  /// (null = delete) they were trying to store. Overlaid onto every read so a
  /// choice made in this process is never replaced by an older one from disk,
  /// and replayed by [flush].
  final Map<String, String?> _unflushed = {};

  static bool get _hasLegacyClass =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Every stored preference.
  ///
  /// Throws when the keychain cannot be read right now — it must never answer
  /// "nothing is stored" for "nothing could be read".
  Future<Map<String, String>> readAll() async {
    final current = await _storage.readAll();
    final out = <String, String>{};
    if (!_hasLegacyClass || current[_kMigrated] == '1') {
      _migrated = true;
      out.addAll(current);
    } else {
      // Deliberately not caught: an upgraded install that has not migrated yet
      // keeps every preference in the legacy class, so a legacy failure here
      // means the real values are unknown, not absent.
      final legacy = await _legacy.readAll();
      _toRestamp = {
        for (final e in legacy.entries)
          if (!current.containsKey(e.key)) e.key: e.value,
      };
      out
        ..addAll(legacy)
        ..addAll(current);
    }
    _unflushed.forEach((key, value) {
      if (value == null) {
        out.remove(key);
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  /// Re-stamps what [readAll] found only under the legacy class, then marks the
  /// install migrated. Best effort: anything that fails stays readable through
  /// the legacy path and is retried on the next launch.
  Future<void> migrate() async {
    if (_migrated) return;
    try {
      for (final e in _toRestamp.entries) {
        // A newer value written this process wins over the one being moved.
        if (_unflushed.containsKey(e.key)) continue;
        await _restamp(e.key, e.value);
      }
      await _storage.write(key: _kMigrated, value: '1');
      _migrated = true;
      _toRestamp = const {};
    } catch (e) {
      debugPrint('SettingsKeychain.migrate: $e');
    }
  }

  /// Replays writes that failed earlier. Returns true when nothing is left.
  Future<bool> flush() async {
    for (final key in _unflushed.keys.toList()) {
      final value = _unflushed[key];
      try {
        await _put(key, value);
        if (_unflushed[key] == value) _unflushed.remove(key);
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  Future<void> write({required String key, required String value}) =>
      _record(key, value);

  Future<void> delete({required String key}) => _record(key, null);

  /// Never throws. The caller has already updated its in-memory state and
  /// notified; a preference that could not be persisted yet is held in
  /// [_unflushed] and retried, rather than surfacing as an unhandled error
  /// from a settings toggle.
  Future<void> _record(String key, String? value) async {
    _unflushed[key] = value;
    try {
      await _put(key, value);
      // Only clear the slot if a later write has not replaced it meanwhile.
      if (_unflushed.containsKey(key) && _unflushed[key] == value) {
        _unflushed.remove(key);
      }
    } catch (e) {
      debugPrint('SettingsKeychain: write of $key deferred: $e');
    }
  }

  Future<void> _put(String key, String? value) async {
    if (value == null) {
      await _storage.delete(key: key);
    } else if (_migrated) {
      await _storage.write(key: key, value: value);
    } else {
      await _restamp(key, value);
    }
  }

  /// Delete-then-write. The plugin's `write` probes with a query carrying
  /// `kSecAttrAccessible`, so an item still stored under the OLD class reads
  /// as absent, and the `SecItemAdd` that follows fails with
  /// `errSecDuplicateItem` — accessibility is not part of a generic password's
  /// primary key. `delete` matches every class, which is what makes the
  /// overwrite land. Same hazard, same fix, as `SessionStore._write`.
  Future<void> _restamp(String key, String value) async {
    await _storage.delete(key: key);
    await _storage.write(key: key, value: value);
  }
}
