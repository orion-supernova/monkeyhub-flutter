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

  /// VAPID application server key for Web Push, base64url — the public half of
  /// the pair whose private key lives in Convex deployment env as
  /// `VAPID_PRIVATE_KEY_P8`. PUBLIC by design: the browser has to be handed it
  /// to subscribe at all.
  ///
  /// Deliberately NOT in [missing]. Web push is the only thing it affects, so
  /// an absent key must not stop an iPhone from launching.
  static String get vapidPublicKey => _get('VAPID_PUBLIC_KEY');

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

  /// Google OAuth client ids, from GCP project `monkeyhub-2b2c6`.
  ///
  /// Both are PUBLIC identifiers — they are safe in `env.local` even though it
  /// ships inside the app bundle. The Sign in with Apple `.p8` is NOT, and lives
  /// in Convex deployment env instead; see `backend/convex/appleTokens.ts`.
  ///
  /// [googleIosClientId] is the iOS OAuth client. [googleServerClientId] is the
  /// WEB client, passed as `serverClientId` on both platforms so that the ID
  /// token's `aud` is one single value on iOS and Android — which is what the
  /// backend allow-lists via `GOOGLE_CLIENT_IDS`. Getting these two confused is
  /// the usual cause of an audience mismatch that reads as "invalid token".
  static String get googleIosClientId => _get('GOOGLE_IOS_CLIENT_ID');
  static String get googleServerClientId => _get('GOOGLE_SERVER_CLIENT_ID');

  /// Google sign-in is hidden entirely until the OAuth clients exist, so the
  /// app stays shippable between now and the console work.
  static bool get googleSignInConfigured => googleServerClientId.isNotEmpty;

  static const String clientId = 'monkeyhub-flutter';

  /// Returns missing required keys so the app can surface a clean error.
  static List<String> missing() {
    final m = <String>[];
    if (convexUrl.isEmpty) m.add('CONVEX_URL');
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
