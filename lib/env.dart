import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime env values for MonkeyHub.
///
/// `env.local` is bundled as an asset (declared in pubspec.yaml) and loaded
/// by `dotenv.load()` in main.dart before runApp. Values are read on demand.
///
/// `env.local` is gitignored — copy `env.example` → `env.local` and fill in.
class Env {
  static String _get(String key) {
    if (!dotenv.isInitialized) return '';
    return dotenv.maybeGet(key, fallback: '') ?? '';
  }

  static String get convexUrl => _get('CONVEX_URL');
  static String get oneSignalAppId => _get('ONESIGNAL_APP_ID');

  /// Origin serving Convex HTTP actions — currently just `/viewOnce`, which
  /// streams a view-once photo against a single-use nonce.
  ///
  /// On this self-hosted deployment that is the same host as [convexUrl] (the
  /// backend answers both on one origin), which is why the fallback is the
  /// right default rather than a missing-key error. Convex Cloud splits them
  /// (`.convex.cloud` vs `.convex.site`), so the key exists to make that
  /// difference a config change rather than a code change.
  static String get convexSiteUrl {
    final explicit = _get('CONVEX_SITE_URL');
    return explicit.isNotEmpty ? explicit : convexUrl;
  }

  static const String clientId = 'monkeyhub-flutter';

  /// Returns missing required keys so the app can surface a clean error.
  static List<String> missing() {
    final m = <String>[];
    if (convexUrl.isEmpty) m.add('CONVEX_URL');
    if (oneSignalAppId.isEmpty) m.add('ONESIGNAL_APP_ID');
    return m;
  }
}

class EnvMissingError extends Error {
  EnvMissingError(this.keys);
  final List<String> keys;
  @override
  String toString() =>
      'Missing required env keys: ${keys.join(', ')}.\n'
      'Copy env.example → env.local in the project root and fill it in.';
}
