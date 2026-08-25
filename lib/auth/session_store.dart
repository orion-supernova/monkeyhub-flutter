import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/family.dart';

/// Mirrors v02's `KeychainService`. Stores `userId` / `username` / `themeId`
/// in the platform secure store so sessions survive across reinstalls
/// (matches v02 behavior — Keychain is not cleared on uninstall).
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _kUserId = 'mh.userId';
  /// The bearer token. Kept in the SAME secure store as the userId and cleared
  /// with it, because a token outliving its session is a credential nobody can
  /// see and nothing can revoke.
  static const _kToken = 'mh.sessionToken';
  static const _kUsername = 'mh.username';
  static const _kName = 'mh.name';
  static const _kThemeId = 'mh.themeId';
  static const _kAccountType = 'mh.accountType';
  static const _kChildDevice = 'mh.isChildDevice';
  static const _kHasSignedIn = 'mh.hasSignedIn';

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
    if (kIsWeb || !Platform.isIOS) return null; // no iOS keychain on web
    try {
      final legacy = await _legacyStorage.read(key: key);
      if (legacy != null) {
        await _storage.write(key: key, value: legacy);
      }
      return legacy;
    } catch (_) {
      return null;
    }
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
    if (token != null) {
      _token = token;
      await _storage.write(key: _kToken, value: token);
    }
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kName, value: name);
    await _storage.write(key: _kAccountType, value: accountType.wire);
    _hasSignedInBefore = true;
    await _storage.write(key: _kHasSignedIn, value: 'true');
    if (accountType == AccountType.child) await markChildDevice();
  }

  Future<Session?> loadSession() async {
    // Read the markers first — the login screen needs both of them even when
    // there is no session left to restore.
    _isChildDevice = (await _read(_kChildDevice)) == 'true';
    _hasSignedInBefore = (await _read(_kHasSignedIn)) == 'true';
    final id = await _read(_kUserId);
    _token = await _read(_kToken);
    if (id == null || id.isEmpty) return null;
    // A stored identity with no token is a session from before tokens existed.
    // It cannot authenticate anything, so it is not a session — returning null
    // sends the app to the login screen, which is the honest outcome and the
    // one `SessionGuard` produces for a revoked token too.
    if (_token == null || _token!.isEmpty) {
      await clearSession();
      return null;
    }
    final username = await _read(_kUsername) ?? '';
    final name = await _read(_kName) ?? username;
    final type = AccountTypeWire.parse(await _read(_kAccountType));
    if (type == AccountType.child) _isChildDevice = true;
    return Session(
      userId: id,
      username: username,
      name: name,
      accountType: type,
    );
  }

  Future<void> markChildDevice() async {
    _isChildDevice = true;
    await _storage.write(key: _kChildDevice, value: 'true');
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
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kName);
    await _storage.delete(key: _kAccountType);
  }

  Future<void> saveThemeId(String id) async =>
      _storage.write(key: _kThemeId, value: id);

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
