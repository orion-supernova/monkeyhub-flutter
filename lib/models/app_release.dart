/// The latest shipped build for one distribution channel, as published by
/// `deploy.sh` and read back from `releases:latest`.
///
/// Mirrors the `appReleases` table in `backend/convex/schema.ts`.
class AppRelease {
  const AppRelease({
    required this.channel,
    required this.version,
    this.minSupported,
    this.updateUrl,
    this.notes,
    required this.publishedAt,
  });

  /// Matches `ReleaseChannel.wire`.
  final String channel;

  /// Display version, no `+N` suffix — e.g. `1.3.30`.
  final String version;

  /// When set and the running version is below it, the update is mandatory:
  /// the prompt loses its "Later" button and can't be dismissed.
  final String? minSupported;

  /// Where the update button should send the user. Server-owned so a build can
  /// be pointed at a store listing that didn't exist when it was compiled; the
  /// client falls back to a per-channel default when this is absent.
  final String? updateUrl;

  /// Optional one-liner shown in the prompt ("fixes call ringing on Android").
  final String? notes;

  final int publishedAt;

  static AppRelease fromJson(Map<String, dynamic> j) => AppRelease(
        channel: j['channel'] as String? ?? '',
        version: j['version'] as String? ?? '',
        minSupported: j['minSupported'] as String?,
        updateUrl: j['updateUrl'] as String?,
        notes: j['notes'] as String?,
        publishedAt: (j['publishedAt'] as num?)?.toInt() ?? 0,
      );
}
