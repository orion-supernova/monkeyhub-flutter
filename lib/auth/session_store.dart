import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/family.dart';

/// Mirrors v02's `KeychainService`. Stores `userId` / `username` / `themeId`
/// in the platform secure store so sessions survive across reinstalls
/// (matches v02 behavior — Keychain is not cleared on uninstall).
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  /// The whole session, as one JSON item.
  ///
  /// ONE item, not five, and that is the point rather than a tidy-up. The five
  /// keys below were written one after another by [saveSession] with no
  /// transaction over them — token first, userId second — so a write that
  /// failed or a process that died in the middle left this device holding one
  /// account's token beside ANOTHER account's userId and username.
  ///
  /// Nothing downstream could survive that. `functions.ts` resolves identity
  /// from the token, so the device went on acting as the newer account while
  /// every screen rendered the older one's name; and the correction never came,
  /// because the profile fetch used the stale userId, got `null` for a deleted
  /// row, and dropped it. One item makes the state unrepresentable: the
  /// keychain either has the whole session or the previous one, never halves of
  /// both.
  static const _kSession = 'mh.session';

  // ── The pre-blob layout ────────────────────────────────────────────────
  // Read once by [_migrateLegacySession] and deleted on the way past. Kept as
  // constants (rather than inlined there) because [clearSession] must also
  // delete them: a half-migrated install with these still present is exactly
  // the resurrection this class now exists to prevent.
  static const _kUserId = 'mh.userId';
  static const _kToken = 'mh.sessionToken';
  static const _kUsername = 'mh.username';
  static const _kName = 'mh.name';
  static const _kAccountType = 'mh.accountType';

  static const _kThemeId = 'mh.themeId';
  static const _kChildDevice = 'mh.isChildDevice';
  static const _kHasSignedIn = 'mh.hasSignedIn';

  /// Every key a session lives in, current and historical.
  static const _sessionKeys = <String>[
    _kSession,
    _kUserId,
    _kToken,
    _kUsername,
    _kName,
    _kAccountType,
  ];

  // `first_unlock_this_device`, NOT `unlocked`: a VoIP push can cold-start
  // the app while the phone is LOCKED, and the session must be readable
  // then or an answered call can never connect (CallService never attaches
  // without a restored userId). first_unlock keeps items readable from the
  // first unlock after boot onward, locked or not — same accessibility
  // class WhatsApp-tier VoIP apps use.
  // No aOptions: `encryptedSharedPreferences` was the only one set, and v10
  // deprecated it into a no-op — Jetpack Security is dead, so the plugin now
  // uses its own ciphers and migrates existing items on first access.
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Pre-existing installs wrote their items under `unlocked`; those may be
  // invisible to reads issued with the new accessibility attribute. Reads
  // fall back to this legacy instance and migrate hits forward.
  static const _legacyStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
  );

  /// Read [key], falling back to (and migrating from) the legacy
  /// `unlocked`-accessibility item on iOS. The migration write re-stamps
  /// the item with the new accessibility class, so it becomes readable on
  /// locked-phone launches from then on.
  Future<String?> _read(String key) async {
    final value = await _storage.read(key: key);
    if (value != null) return value;
    // `defaultTargetPlatform` rather than `Platform.isIOS`, matching
    // `DeviceIdentity._read`: it is what the storage plugin dispatches its own
    // options on, so the two agree by construction — and unlike dart:io it can
    // be overridden in a test, which is what lets the migration below be
    // covered at all.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    String? legacy;
    try {
      legacy = await _legacyStorage.read(key: key);
    } catch (_) {
      return null;
    }
    if (legacy == null) return null;
    // Re-stamping is best effort, and its failure must NOT lose the value we
    // just read. The previous version returned null from this catch, which
    // turned "your session is in the old slot" into "you have no session" —
    // and then the next sign-in wrote over nothing, because [_write]'s hazard
    // below made that fail too.
    try {
      await _write(key, legacy);
    } catch (_) {/* stays in the legacy slot; still readable next launch */}
    return legacy;
  }

  /// Write [key], deleting any existing item first.
  ///
  /// The delete is load-bearing. The plugin's `write` probes with
  /// `containsKey`, whose query carries `kSecAttrAccessible`, so an item
  /// stored under the OLD accessibility class reads as absent; `write` then
  /// falls through to `SecItemAdd`, which fails with `errSecDuplicateItem`
  /// because accessibility is not part of a generic password's primary key.
  /// A plain overwrite across the two classes therefore THROWS rather than
  /// replacing — silently, since every caller used to swallow it.
  ///
  /// `delete` has no such problem: it nils the accessibility attribute, so it
  /// matches the item whichever class it was written under. Delete-then-add is
  /// what makes the overwrite land.
  Future<void> _write(String key, String value) async {
    await _storage.delete(key: key);
    await _storage.write(key: key, value: value);
  }

  /// Sticky marker that this handset belongs to a child.
  ///
  /// This is what stands in for OS-level family detection, which no platform
  /// exposes portably — iOS gates it behind the Family Controls entitlement
  /// and Android's Family Link has no public API at all. Once a device has
  /// been paired as a child device the flag stays put, so the login screen
  /// offers only the pairing path on every later launch — even after the
  /// child signs out or the session is cleared.
  ///
  /// Cached in memory so `LoginScreen` can branch synchronously on first
  /// frame instead of flashing the adult form. Populated by [loadSession].
  bool _isChildDevice = false;
  bool get isChildDevice => _isChildDevice;

  /// Sticky marker that somebody has completed a sign-in on this handset.
  ///
  /// Only the login screen's greeting reads it: a device that has never been
  /// signed into is not owed "welcome back". Deliberately NOT cleared by
  /// [clearSession] — signing out does not make the device new again, and the
  /// greeting would be a lie on the very next launch if it did.
  ///
  /// Cached in memory for the same reason as [isChildDevice]: `LoginScreen`
  /// picks its hero on the first frame and must not flash the wrong one.
  /// Populated by [loadSession].
  bool _hasSignedInBefore = false;
  bool get hasSignedInBefore => _hasSignedInBefore;

  /// The live bearer token, or null when signed out.
  ///
  /// Cached in memory as well as persisted, because `ConvexBackend` reads it on
  /// EVERY call and a keychain round trip per request would be the most
  /// expensive thing in the app. Kept in step by [saveSession]/[clearSession],
  /// which are the only two writers.
  String? _token;
  String? get token => _token;

  Future<void> saveSession({
    required String userId,
    required String username,
    required String name,
    /// Null means "keep whatever token is already stored" — for the re-saves
    /// that change a display name or graduate an account, which rewrite the
    /// session's *description* and must not disturb the credential it was
    /// established with.
    String? token,
    AccountType accountType = AccountType.adult,
  }) async {
    final effective = token ?? _token ?? await _read(_kToken);
    final encoded = jsonEncode(<String, dynamic>{
      'v': 1,
      'userId': userId,
      'token': effective,
      'username': username,
      'name': name,
      'accountType': accountType.wire,
    });
    // One write, so there is no window in which half of this session and half
    // of the last one are both on disk. If it throws, the PREVIOUS session
    // survives intact — which is recoverable — rather than a blend of the two,
    // which is not.
    await _write(_kSession, encoded);
    _token = effective;
    // Only now, with the new session safely stored: a legacy item left live
    // here is a session [loadSession] would fall back to.
    await _clearLegacySession();
    _hasSignedInBefore = true;
    await _write(_kHasSignedIn, 'true');
    if (accountType == AccountType.child) await markChildDevice();
  }

  Future<Session?> loadSession() async {
    // Read the markers first — the login screen needs both of them even when
    // there is no session left to restore.
    _isChildDevice = (await _read(_kChildDevice)) == 'true';
    _hasSignedInBefore = (await _read(_kHasSignedIn)) == 'true';

    final record = await _readSession() ?? await _migrateLegacySession();
    if (record == null) {
      _token = null;
      return null;
    }

    final id = record['userId'] as String? ?? '';
    _token = record['token'] as String?;
    if (id.isEmpty) {
      await clearSession();
      return null;
    }
    // A stored identity with no token is a session from before tokens existed.
    // It cannot authenticate anything, so it is not a session — returning null
    // sends the app to the login screen, which is the honest outcome and the
    // one `SessionGuard` produces for a revoked token too.
    if (_token == null || _token!.isEmpty) {
      await clearSession();
      return null;
    }
    final username = record['username'] as String? ?? '';
    final name = record['name'] as String? ?? username;
    final type = AccountTypeWire.parse(record['accountType'] as String?);
    if (type == AccountType.child) _isChildDevice = true;
    return Session(
      userId: id,
      username: username,
      name: name,
      accountType: type,
    );
  }

  /// The stored session, or null when there is none or it is unreadable.
  ///
  /// Corrupt JSON is treated as "no session" rather than thrown: the only
  /// thing an exception could achieve here is a launch that dies before the
  /// login screen, which is strictly worse than asking someone to sign in.
  Future<Map<String, dynamic>?> _readSession() async {
    final raw = await _read(_kSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Fold a pre-blob session into [_kSession], and return what it held.
  ///
  /// Runs at most once per install in practice, but is written to be safe
  /// every launch: if the rewrite fails the legacy items stay exactly where
  /// they are and this returns them anyway, so an install that cannot migrate
  /// still signs in rather than being silently logged out.
  Future<Map<String, dynamic>?> _migrateLegacySession() async {
    final id = await _read(_kUserId);
    if (id == null || id.isEmpty) return null;
    final username = await _read(_kUsername) ?? '';
    final record = <String, dynamic>{
      'v': 1,
      'userId': id,
      'token': await _read(_kToken),
      'username': username,
      'name': await _read(_kName) ?? username,
      'accountType': await _read(_kAccountType) ?? AccountType.adult.wire,
    };
    try {
      await _write(_kSession, jsonEncode(record));
      await _clearLegacySession();
    } catch (_) {/* left in the old slot; re-tried next launch */}
    return record;
  }

  Future<void> _clearLegacySession() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kName);
    await _storage.delete(key: _kAccountType);
  }

  Future<void> markChildDevice() async {
    _isChildDevice = true;
    await _write(_kChildDevice, 'true');
  }

  /// Deliberately NOT called by [clearSession] — a child signing out (which
  /// the UI doesn't offer, but a guardian unpairing does) must still land on
  /// the pairing screen rather than the adult login form.
  ///
  /// Two callers, both meaning "this handset is nobody's child device now":
  /// a guardian releasing the device (`AuthService.releaseChildDevice`), and
  /// the account being graduated to an adult one
  /// (`AuthService.applyAccountType`) — which is the only one of the two still
  /// available afterwards, since graduation destroys the release codes.
  Future<void> clearChildDevice() async {
    _isChildDevice = false;
    await _storage.delete(key: _kChildDevice);
  }

  /// Note what is absent: `_kChildDevice` (see [clearChildDevice]) and
  /// `_kHasSignedIn` (see [hasSignedInBefore]). Both describe the handset
  /// rather than the session, and both must outlive a sign-out.
  Future<void> clearSession() async {
    _token = null;
    // Both layouts. Clearing only the current one would leave a half-migrated
    // install with a legacy session [loadSession] falls back to — signing
    // someone back in, as a previous account, on the very next launch.
    for (final key in _sessionKeys) {
      await _storage.delete(key: key);
    }
  }

  Future<void> saveThemeId(String id) async => _write(_kThemeId, id);

  Future<String?> loadThemeId() async => _read(_kThemeId);
}

class Session {
  Session({
    required this.userId,
    required this.username,
    required this.name,
    this.accountType = AccountType.adult,
  });
  final String userId;
  final String username;
  final String name;
  final AccountType accountType;

  bool get isChild => accountType == AccountType.child;
}
