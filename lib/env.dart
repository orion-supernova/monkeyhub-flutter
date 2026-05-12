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
