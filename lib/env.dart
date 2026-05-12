/// Build-time environment values for MonkeyHub.
///
/// Values are passed in via `--dart-define-from-file=env.local`. Nothing is
/// hardcoded in source — running without an env file is a fatal startup error
/// surfaced via [Env.missing].
///
/// See `env.example` for the full key list.
class Env {
  static const String convexUrl = String.fromEnvironment('CONVEX_URL');
  static const String oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');

  static const String clientId = 'monkeyhub-flutter';

  /// Returns the list of required keys missing at compile time, so the app
  /// can show a clear "env not configured" error rather than fail downstream.
  static List<String> missing() {
    final m = <String>[];
    if (convexUrl.isEmpty) m.add('CONVEX_URL');
    if (oneSignalAppId.isEmpty) m.add('ONESIGNAL_APP_ID');
    return m;
  }
}

/// Thrown at boot when required env values aren't compiled in.
class EnvMissingError extends Error {
  EnvMissingError(this.keys);
  final List<String> keys;
  @override
  String toString() =>
      'Missing required env keys: ${keys.join(', ')}.\n'
      'Run with: flutter run --dart-define-from-file=env.local\n'
      '(copy env.example → env.local and fill it in)';
}
