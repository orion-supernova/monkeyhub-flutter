import 'convex_client.dart';

/// Every Convex call presence makes.
///
/// The session token is injected by [ConvexBackend] for all three, like any
/// other call, so none of them takes a user id: who is beating is the session.
///
/// **Not-found is the caller's signal.** A server that predates `presenceApi`
/// answers these with "function not found". They rethrow it unchanged so the
/// app can fall back to the legacy `users` writes; [isMissing] is the one place
/// that phrase is matched.
class PresenceApi {
  PresenceApi(this._cv);
  final ConvexBackend _cv;

  static const forUsersName = 'presenceApi:forUsers';

  /// The heartbeat. [status] is `online` or `away`, never `offline`: offline
  /// is what the server derives when beats stop, not something a client writes.
  Future<void> beat({required String status}) async {
    await _cv.mutation('presenceApi:beat', {'status': status});
  }

  /// An explicit status change (foreground, background).
  Future<void> setStatus({required String status}) async {
    await _cv.mutation('presenceApi:setStatus', {'status': status});
  }

  /// Whether [error] means the server has no such function (an older
  /// deployment). Convex words that three ways depending on version, the same
  /// three `ServerProbe` matches.
  static bool isMissing(Object error) {
    final m = error.toString();
    return m.contains('Could not find public function') ||
        m.contains('function not found') ||
        m.contains("Couldn't find function");
  }
}
