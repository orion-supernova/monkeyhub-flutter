import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent per-device identifier used to scope push tokens. Generated
/// once on first launch (RFC-4122 UUIDv4 via `Random.secure`), stashed in
/// the platform keychain, and read back on every subsequent launch.
/// Cleared on app uninstall; survives logout.
class DeviceIdentity {
  DeviceIdentity._();

  static const _storageKey = 'monkeyhub.device_id';

  // `first_unlock_this_device`, NOT the plugin default (`unlocked`) — the same
  // reasoning, and the same accessibility class, as [SessionStore]. A VoIP push
  // cold-starts the app while the phone is LOCKED, and this id is the FIRST
  // thing `_onAuthChange` reads: `CallService.attach`, `GroupCallService.attach`
  // and `SignalingService.start` all take it, and all three sit behind it in
  // one try block.
  //
  // Under `unlocked` that read throws `errSecInteractionNotAllowed (-25308)` on
  // a locked device, so the whole calling stack was skipped and the process
  // never recovered — `_repo.attach` sets `_repo.userId` immediately after, and
  // that permanently disarms the guard which would let the block re-run. A
  // capture shows exactly this: `CRITICAL: call stack attach failed`, then
  // silence. `PushManager.login` reads the same key and left `_deviceId` null
  // for the process lifetime, so VoIP tokens never uploaded either.
  //
  // SessionStore already fixed its half of this and documented why. This class
  // was the hole in that fix: the session restored fine on a locked cold start,
  // and then the device id failed one layer further down.
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Pre-existing installs wrote this key under `unlocked`, and that item may be
  // invisible to a read issued with the new accessibility attribute. Without
  // the fallback below, every current install would silently mint a NEW device
  // id on upgrade — orphaning its backend device row and its registered VoIP
  // token, which is a worse outcome than the bug being fixed.
  static const _legacyStorage = FlutterSecureStorage();

  static final Random _random = Random.secure();

  static String? _cached;

  /// Drop the process-lifetime cache. Tests only — [ensure] is memoised on
  /// purpose, which would otherwise make them order-dependent.
  @visibleForTesting
  static void resetCacheForTest() => _cached = null;

  static Future<String> ensure() async {
    final cached = _cached;
    if (cached != null) return cached;
    final existing = await _read();
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final fresh = _mintUuidV4();
    await _storage.write(key: _storageKey, value: fresh);
    _cached = fresh;
    return fresh;
  }

  /// Read the id, falling back to (and migrating forward from) the legacy
  /// default-accessibility item on iOS.
  ///
  /// The migration write re-stamps the item with the new accessibility class,
  /// so from the next launch onward it is readable on a locked phone.
  ///
  /// A keychain failure propagates on purpose, and [ensure] with it. "The item
  /// is unreadable right now" and "there is no item" must not collapse into the
  /// same answer here: swallowing the error would make [ensure] mint a fresh id
  /// and orphan the real one. Callers retry once the device is unlocked — see
  /// the resume path in `app.dart`. Only the migration *write* is tolerated to
  /// fail, since by then the id is already in hand.
  static Future<String?> _read() async {
    final value = await _storage.read(key: _storageKey);
    if (value != null) return value;
    // `defaultTargetPlatform` rather than `Platform.isIOS`: it is what the
    // storage plugin itself dispatches its own options on, so the two agree by
    // construction — and unlike dart:io it can be overridden in a test, which
    // is what lets the migration below be covered at all.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    final legacy = await _legacyStorage.read(key: _storageKey);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        await _storage.write(key: _storageKey, value: legacy);
      } catch (_) {
        // Re-stamping failed (locked device, most likely). The id itself is
        // good and is what the caller needs; the next launch retries.
      }
    }
    return legacy;
  }

  /// `"ios" | "ios-simulator" | "android" | "macos" | "windows" | "linux" | "web"`.
  /// iOS simulator is detected via the resolved-executable path — same
  /// trick used in `NativeCallHandler`. The backend uses this flag to
  /// skip APNs fanout for simulators (PushKit doesn't reach them) and
  /// to derive a friendly fallback label for the active-call pill when
  /// no deviceName is captured.
  static String platformTag() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) {
      return Platform.resolvedExecutable.contains('/CoreSimulator/')
          ? 'ios-simulator'
          : 'ios';
    }
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return Platform.operatingSystem;
  }

  static const MethodChannel _deviceChannel = MethodChannel('monkeyhub/device');

  /// Friendly fallback label used when no OS-provided deviceName is
  /// available — keeps the pill readable on every platform.
  static String friendlyPlatformLabel() {
    final tag = platformTag();
    switch (tag) {
      case 'ios':
        return 'iPhone';
      case 'ios-simulator':
        return 'iOS Simulator';
      case 'android':
        return 'Android device';
      case 'macos':
        return 'Mac';
      case 'windows':
        return 'Windows PC';
      case 'linux':
        return 'Linux device';
      case 'web':
        return 'Browser';
      default:
        return 'another device';
    }
  }

  /// Human-readable name for THIS device. Source of truth:
  ///   - iOS: `UIDevice.current.name` (e.g., "Bob's iPhone")
  ///   - macOS: `Host.current().localizedName` (e.g., "Bob's MacBook Pro")
  ///   - Android: `Settings.Global.DEVICE_NAME` → `Build.MODEL`
  ///   - Other platforms: `Platform.localHostname` if non-empty
  /// Result is sanity-checked: empty / generic / hostname-like strings
  /// fall back to [friendlyPlatformLabel]. Captured at login so the
  /// backend can surface it in the "Move call here" pill.
  static Future<String> displayName() async {
    String? raw;
    try {
      if (kIsWeb) {
        raw = null; // no native device-name channel on web → 'Browser'
      } else if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
        raw = await _deviceChannel.invokeMethod<String>('getDisplayName');
      } else if (Platform.isWindows || Platform.isLinux) {
        raw = Platform.localHostname;
      }
    } catch (_) {
      raw = null;
    }
    if (raw == null) return friendlyPlatformLabel();
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return friendlyPlatformLabel();
    // Reject pure-MAC patterns and hex-only strings (some Android OEMs
    // return raw hardware ids when DEVICE_NAME isn't set).
    if (RegExp(r'^[0-9a-fA-F:-]{8,}$').hasMatch(trimmed)) {
      return friendlyPlatformLabel();
    }
    return trimmed;
  }

  static String _mintUuidV4() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
    String h(int i, int j) => b
        .sublist(i, j)
        .map((x) => x.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
  }
}
