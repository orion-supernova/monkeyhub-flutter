import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent per-device identifier used to scope push tokens. Generated
/// once on first launch (RFC-4122 UUIDv4 via `Random.secure`), stashed in
/// the platform keychain, and read back on every subsequent launch.
/// Cleared on app uninstall; survives logout.
class DeviceIdentity {
  DeviceIdentity._();

  static const _storageKey = 'monkeyhub.device_id';
  static const _storage = FlutterSecureStorage();
  static final Random _random = Random.secure();

  static String? _cached;

  static Future<String> ensure() async {
    final cached = _cached;
    if (cached != null) return cached;
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final fresh = _mintUuidV4();
    await _storage.write(key: _storageKey, value: fresh);
    _cached = fresh;
    return fresh;
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
