import 'convex_client.dart';

/// Every Convex call the profile cache makes.
///
/// The session token is injected by [ConvexBackend] like any other call.
///
/// **Not-found is the caller's signal.** A server that predates `profiles`
/// answers with "function not found"; [isMissing] is the one place that phrase
/// is matched, and the cache goes legacy (every lookup returns the caller's
/// fallback) when it sees it.
class ProfileApi {
  ProfileApi(this._cv);
  final ConvexBackend _cv;

  static const versionsName = 'profiles:versions';
  static const getName = 'profiles:get';

  /// The server's limit on ids per call, for both functions.
  static const maxIds = 100;

  /// One-shot fetch of up to [maxIds] profiles. The result lines up with
  /// [ids]; a null entry means the server knows no such profile (or the
  /// viewer may not see it).
  Future<List<Map<String, dynamic>?>> get(List<String> ids) async {
    final raw = await _cv.query(getName, {'ids': ids});
    if (raw is! List) return List.filled(ids.length, null);
    return [
      for (final r in raw) r is Map ? r.cast<String, dynamic>() : null,
    ];
  }

  /// Whether [error] means the server has no such function (an older
  /// deployment).
  static bool isMissing(Object error) {
    final m = error.toString();
    return m.contains('Could not find public function') ||
        m.contains('function not found') ||
        m.contains("Couldn't find function");
  }
}
