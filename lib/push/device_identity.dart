import 'dart:io' show Platform;
import 'dart:math';

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

  /// `"ios" | "ios-simulator" | "android"`. iOS simulator is detected via
  /// the resolved-executable path — same trick used in `NativeCallHandler`.
  /// We tag the simulator separately because PushKit doesn't reach
  /// simulators; the backend uses this flag to skip APNs fanout for them.
  static String platformTag() {
    if (Platform.isIOS) {
      return Platform.resolvedExecutable.contains('/CoreSimulator/')
          ? 'ios-simulator'
          : 'ios';
    }
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
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
