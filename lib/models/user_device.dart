/// One row of "your devices", as `voipTokens:listDevices` returns it.
///
/// Deliberately carries no push credential. The backend does not send one and
/// this class could not hold one if it did — a token is a capability to send
/// to a device, and nothing on a settings screen needs that.
class UserDevice {
  const UserDevice({
    required this.deviceId,
    required this.platform,
    required this.lastSeenAt,
    required this.createdAt,
    required this.isThis,
    required this.reachable,
    this.deviceName,
  });

  /// Client-persisted UUIDv4 — see `DeviceIdentity.ensure()`.
  final String deviceId;

  /// `ios` / `android` / `macos` / `windows` / `linux` / `web`, matching
  /// `DeviceIdentity.platformTag()`.
  final String platform;

  /// What the OS calls this device — "Bob's iPhone". Null on a device that
  /// registered before the field existed, or whose OS gave nothing useful;
  /// `DeviceIdentity.friendlyPlatformLabel()` is the fallback.
  final String? deviceName;

  final DateTime lastSeenAt;
  final DateTime createdAt;

  /// Whether this row is the device doing the asking.
  ///
  /// Resolved by the SERVER, not by comparing ids here — the row the UI
  /// refuses to offer Remove on should be decided by the same code that would
  /// carry the removal out.
  final bool isThis;

  /// Whether a notification could still reach it. False for a device that
  /// muted itself, one whose credential was swept after the provider reported
  /// it dead, and every desktop that never had one.
  final bool reachable;

  static UserDevice fromJson(Map<String, dynamic> json) => UserDevice(
    deviceId: json['deviceId'] as String,
    platform: (json['platform'] as String?) ?? 'unknown',
    deviceName: (json['deviceName'] as String?)?.trim().isEmpty ?? true
        ? null
        : (json['deviceName'] as String).trim(),
    lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
      (json['lastSeenAt'] as num?)?.toInt() ?? 0,
    ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num?)?.toInt() ?? 0,
    ),
    isThis: json['isThis'] == true,
    reachable: json['reachable'] == true,
  );
}
