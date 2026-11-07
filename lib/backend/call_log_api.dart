import 'convex_client.dart';
import '../screens/calls/call_log_models.dart';

/// What the Calls tab and its store need from the backend. A seam so widget
/// tests drive the screen with a fake instead of a socket.
abstract class CallLogSource {
  /// Live first page of [filter] (`"all"` or `"missed"`). One subscription per
  /// filter; the returned canceller ends it.
  Future<void Function()> subscribeFirstPage({
    required String filter,
    required int numItems,
    required void Function(CallLogPage page) onPage,
    void Function(Object error)? onError,
  });

  /// The page after [cursor], one-shot.
  Future<CallLogPage> page({
    required String filter,
    required int numItems,
    required String cursor,
  });

  Future<CallLogSummary> summary({required int since, int tzOffsetMin = 0});

  Future<void> remove(String id);

  /// Live list of the people I pinned, oldest first. One subscription; the
  /// returned canceller ends it.
  Future<void Function()> subscribeFavourites({
    required void Function(List<CallFavourite> favourites) onData,
    void Function(Object error)? onError,
  });

  Future<void> addFavourite(String peerId);

  Future<void> removeFavourite(String peerId);
}

/// Client for `callLog:*` (see docs/design/calls.md section 2). Every function
/// is authed through the session token `ConvexBackend` attaches, so nothing
/// here passes a user id.
class CallLogApi implements CallLogSource {
  CallLogApi(this._cv);
  final ConvexBackend _cv;

  /// The app-wide instance on the shared backend.
  static final CallLogApi shared = CallLogApi(ConvexBackend.instance);

  @override
  Future<void Function()> subscribeFirstPage({
    required String filter,
    required int numItems,
    required void Function(CallLogPage page) onPage,
    void Function(Object error)? onError,
  }) async {
    final sub = await _cv.subscribe(
      'callLog:list',
      {
        'paginationOpts': {'numItems': numItems, 'cursor': null},
        'filter': filter,
      },
      onData: (raw) {
        if (raw is Map) onPage(CallLogPage.fromJson(raw.cast<String, dynamic>()));
      },
      onError: onError,
    );
    return sub.cancel;
  }

  @override
  Future<CallLogPage> page({
    required String filter,
    required int numItems,
    required String cursor,
  }) async {
    final res = await _cv.query('callLog:list', {
      'paginationOpts': {'numItems': numItems, 'cursor': cursor},
      'filter': filter,
    });
    return CallLogPage.fromJson((res as Map).cast<String, dynamic>());
  }

  @override
  Future<CallLogSummary> summary({required int since, int tzOffsetMin = 0}) async {
    Object? res;
    if (_tzRejected) {
      res = await _cv.query('callLog:summary', {'since': since});
    } else {
      try {
        res = await _cv.query(
          'callLog:summary',
          {'since': since, 'tzOffsetMin': tzOffsetMin},
        );
      } catch (e) {
        // A server older than the stats sheet validates `since` alone and
        // rejects the extra field, which blanked the whole talk-time card.
        // Ask again the old way (totals still show; the clock-bucketed
        // figures come back empty) and stop sending it this session.
        if (!'$e'.contains('ArgumentValidationError') &&
            !'$e'.contains('tzOffsetMin')) {
          rethrow;
        }
        _tzRejected = true;
        res = await _cv.query('callLog:summary', {'since': since});
      }
    }
    return CallLogSummary.fromJson((res as Map).cast<String, dynamic>());
  }

  /// The server refused `tzOffsetMin` once; don't send it again.
  static bool _tzRejected = false;

  @override
  Future<void> remove(String id) async {
    await _cv.mutation('callLog:remove', {'id': id});
  }

  @override
  Future<void Function()> subscribeFavourites({
    required void Function(List<CallFavourite> favourites) onData,
    void Function(Object error)? onError,
  }) async {
    final sub = await _cv.subscribe(
      'callFavorites:list',
      const {},
      onData: (raw) => onData(CallFavourite.parseList(raw)),
      onError: onError,
    );
    return sub.cancel;
  }

  @override
  Future<void> addFavourite(String peerId) async {
    await _cv.mutation('callFavorites:add', {'peerId': peerId});
  }

  @override
  Future<void> removeFavourite(String peerId) async {
    await _cv.mutation('callFavorites:remove', {'peerId': peerId});
  }

  /// Deletes up to 500 of my rows; true while more remain.
  Future<bool> clear() async {
    final res = await _cv.mutation('callLog:clear', {});
    return res is Map && res['more'] == true;
  }

  /// After a call: my connection quality, one bucket per 10 s connected
  /// (0 good, 1 fair, 2 poor). Exactly one of [callId] / [groupCallId].
  Future<void> reportQuality({
    String? callId,
    String? groupCallId,
    required List<int> samples,
  }) async {
    await _cv.mutation('callLog:reportQuality', {
      'callId': ?callId,
      'groupCallId': ?groupCallId,
      'samples': samples,
    });
  }
}
