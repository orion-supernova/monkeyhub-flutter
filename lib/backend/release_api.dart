import '../models/app_release.dart';
import 'convex_client.dart';

/// Every Convex call the update checker makes.
///
/// A facade beside [ChatApi] rather than more methods on it, for the reason
/// `FeedApi` gives: `chat_api.dart` is already ~1600 lines and 150 methods, and
/// "which build is current" has nothing to do with chat. Same shape as
/// `CallApi`, `GroupCallApi` and `FeedApi` — one method per endpoint, holding
/// the same [ConvexBackend] singleton, decoding in the facade so no caller ever
/// sees a raw map.
///
/// Both methods are unauthenticated on the backend on purpose (see
/// `backend/convex/releases.ts`): the update check runs before the session is
/// restored, so it works on the login screen too. That's also why this facade
/// takes no userId — unlike every other one, it has no notion of a viewer.
class ReleaseApi {
  ReleaseApi(this._cv);
  final ConvexBackend _cv;

  /// The latest build published for one distribution channel, or null when
  /// nothing has been published for it yet.
  Future<AppRelease?> latestRelease(String channel) async {
    final res = await _cv.query('releases:latest', {'channel': channel});
    if (res == null) return null;
    return AppRelease.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Live version of [latestRelease]. Publishing a release reaches phones that
  /// are already running over the socket that's already open, so the "there's
  /// a new version" badge doesn't wait for a cold start — which on iOS, where
  /// an app can stay warm for weeks, may never come.
  ///
  /// Cheaper than it looks: a one-shot [query] in this client is internally a
  /// subscribe/read/unsubscribe on the same socket, so holding the
  /// subscription costs the same traffic as polling it would, minus the timer
  /// and the wakeups. The row is invalidated only when `deploy.sh` runs
  /// `releases:publish`, so there's none of the invalidation fanout that makes
  /// presence writes expensive.
  ///
  /// Goes through [ConvexBackend.subscribe] rather than the raw client so
  /// `SubscriptionRegistry` re-binds it after a reconnect — which is also what
  /// makes this cover the foreground case for free, since backgrounding past
  /// `backgroundRebuildThreshold` rebuilds the socket and re-delivers on
  /// resume.
  Future<Subscription> subscribeLatestRelease({
    required String channel,
    required void Function(AppRelease? release) onRelease,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'releases:latest',
      {'channel': channel},
      onData: (raw) {
        if (raw == null) {
          onRelease(null);
          return;
        }
        onRelease(AppRelease.fromJson((raw as Map).cast<String, dynamic>()));
      },
      onError: onError,
    );
  }
}
