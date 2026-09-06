import '../models/daily_game.dart';
import '../models/moment.dart';
import '../models/puzzle.dart';
import 'convex_client.dart';

/// Every Convex call the Feed board makes.
///
/// A facade beside [ChatApi] rather than more methods on it: `chat_api.dart` is
/// already ~1600 lines and 150 methods, and the Feed is a self-contained
/// surface with its own backend module. Same shape as `CallApi` and
/// `GroupCallApi` — one method per endpoint, holding the same
/// [ConvexBackend] singleton, decoding in the facade so no caller ever sees a
/// raw map.
class FeedApi {
  FeedApi(this._cv);
  final ConvexBackend _cv;

  /// Subscribes to the whole board for one local day.
  ///
  /// ONE subscription for four pillars, on purpose — the app runs ~15 live
  /// queries and the codebase repeatedly refuses to add more. Goes through
  /// [ConvexBackend.subscribe] rather than the raw client so
  /// `SubscriptionRegistry` re-binds it after a reconnect; a subscribe that
  /// threw is registered nowhere and would otherwise be permanently dead while
  /// still handing back a perfectly ordinary handle.
  ///
  /// [dayKey] must be the VIEWER's local day. The server cannot derive it — it
  /// has no idea what zone the phone is in, and assuming UTC puts everyone west
  /// of Greenwich on yesterday's board all evening.
  Future<Subscription> subscribeBoard({
    required String userId,
    required String dayKey,
    required void Function(FeedBoard board) onData,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'feed:board',
      {'userId': userId, 'dayKey': dayKey},
      onData: (raw) => onData(FeedBoard.fromJson(raw)),
      onError: onError,
    );
  }

  /// Publishes a moment and returns its id.
  ///
  /// [dayKey] is the author's local day. Timestamps are the server's, so a
  /// wrong device clock cannot pin something to the top of a friend's board.
  ///
  /// Throws `EMPTY_MOMENT` when neither media nor caption is present,
  /// `CAPTION_TOO_LONG` past 280 characters, `UNKNOWN_TAG` for a tag this
  /// backend does not know, `DAILY_CAP_REACHED` at 20 of one tag in a day, and
  /// `CHILD_NOT_ALLOWED` when a supervised account posts media its guardian has
  /// switched off.
  Future<String> post({
    required String userId,
    required String dayKey,
    MomentTag? tag,
    String? caption,
    String? mediaStorageId,
    String? posterStorageId,
    MomentMedia mediaKind = MomentMedia.none,
  }) async {
    final res = await _cv.mutation('feed:post', {
      'userId': userId,
      'dayKey': dayKey,
      'tag': ?tag?.wire,
      'caption': ?caption,
      'mediaStorageId': ?mediaStorageId,
      'posterStorageId': ?posterStorageId,
      if (mediaKind != MomentMedia.none) 'mediaKind': mediaKind.name,
    });
    return res.toString();
  }

  /// Deletes one of your own moments, its reactions, its view records and its
  /// blobs. Throws `NOT_YOUR_MOMENT` for anyone else's.
  Future<void> remove({
    required String userId,
    required String momentId,
  }) async {
    await _cv.mutation('feed:remove', {
      'userId': userId,
      'momentId': momentId,
    });
  }

  /// Clears the unseen ring on [momentIds].
  ///
  /// Batched because the viewer swipes a rail, and one mutation per card would
  /// be a write storm on a screen someone is passing through. Idempotent, so a
  /// re-send after a reconnect costs nothing.
  Future<void> markSeen({
    required String userId,
    required List<String> momentIds,
  }) async {
    if (momentIds.isEmpty) return;
    await _cv.mutation('feed:markSeen', {
      'userId': userId,
      'momentIds': momentIds,
    });
  }

  /// Adds a reaction. Re-adding the same emoji is a no-op, not an error.
  Future<void> react({
    required String userId,
    required String momentId,
    required String emoji,
  }) async {
    await _cv.mutation('feed:react', {
      'userId': userId,
      'momentId': momentId,
      'emoji': emoji,
    });
  }

  /// Removes one of your own reactions. Absent is not an error.
  Future<void> unreact({
    required String userId,
    required String momentId,
    required String emoji,
  }) async {
    await _cv.mutation('feed:unreact', {
      'userId': userId,
      'momentId': momentId,
      'emoji': emoji,
    });
  }

  /// Submits one guess at today's puzzle.
  ///
  /// Returns the WHOLE attempt, not just the new row, so a client that missed
  /// a response can resync from any single call. The board subscription also
  /// carries the same state, but this return is what lets the tile flip its
  /// feedback in immediately rather than a round trip later.
  ///
  /// Throws `BAD_GUESS` for a malformed guess, `ALREADY_SOLVED` for a replay
  /// after winning, and `OUT_OF_GUESSES` past the sixth try.
  Future<PuzzleAttempt> guess({
    required String userId,
    required String dayKey,
    required List<int> guess,
  }) async {
    final res = await _cv.mutation('puzzle:guess', {
      'userId': userId,
      'dayKey': dayKey,
      'guess': guess,
    });
    return PuzzleAttempt.fromJson((res as Map).cast<String, dynamic>())!;
  }

  /// One moment by id, or null if it is gone or no longer visible.
  ///
  /// Exists for the notification tap, which is the one caller that knows an id
  /// without already holding the row. The board cannot be asked: it is scanned
  /// by the VIEWER's `dayKey`, so a friend in a distant enough timezone posts
  /// under a different one and is legitimately absent from it.
  ///
  /// Never throws for "you can't see this" — a tap on a push that is hours old
  /// can find the moment deleted, the friendship gone, or the setting changed,
  /// and none of those is something the person tapping can act on. Null is the
  /// answer to all three and the caller falls back to the board.
  Future<Moment?> moment({
    required String userId,
    required String momentId,
  }) async {
    final res = await _cv.query('feed:moment', {
      'userId': userId,
      'momentId': momentId,
    });
    if (res == null) return null;
    return Moment.fromJson((res as Map).cast<String, dynamic>());
  }

  /// A page of moment history, newest first.
  ///
  /// One-shot, not a subscription — the archive is cold data and a second live
  /// query for it would be exactly the budget creep the board avoids.
  ///
  /// [ofUserId] null means your own archive, which is always complete. A
  /// friend's throws `HISTORY_PRIVATE` unless they have opened their past, and
  /// `NOT_A_FRIEND` if the friendship is gone.
  Future<MomentPage> archive({
    required String userId,
    String? ofUserId,
    int? beforeTimestamp,
    int? limit,
  }) async {
    final res = await _cv.query('feed:archive', {
      'userId': userId,
      'ofUserId': ?ofUserId,
      'beforeTimestamp': ?beforeTimestamp,
      'limit': ?limit,
    });
    final map = (res as Map).cast<String, dynamic>();
    return MomentPage(
      items: [
        for (final m in (map['items'] as List?) ?? const [])
          Moment.fromJson((m as Map).cast<String, dynamic>()),
      ],
      hasMore: map['hasMore'] == true,
    );
  }
}

/// One board payload.
class FeedBoard {
  const FeedBoard({
    required this.moments,
    required this.serverNow,
    this.puzzle = const PuzzleState(),
    this.games = const {},
  });

  final List<Moment> moments;

  /// Today's puzzle, carried in THIS payload rather than a query of its own —
  /// see [FeedApi.subscribeBoard] on why the board is one subscription.
  final PuzzleState puzzle;

  /// How the VIEWER is doing on each daily game, keyed by game.
  ///
  /// Their own rows only — one indexed read on the server, no fan-out over
  /// friends. It rides along here so the Feed's games band can say "solved in
  /// 1:42" rather than four identical unplayed tiles, which is the difference
  /// between a feature people notice and one they have to remember to go and
  /// look for. Friends' times cost a read each and live on the hub, which
  /// fetches them one-shot when it opens.
  final Map<DailyGame, GameResult> games;

  /// The server's clock at the moment this was computed.
  ///
  /// Carried so expiry and the ephemeral-decay overlay are judged against the
  /// same clock that decided what to include. A device whose clock is a few
  /// minutes fast would otherwise fade a moment out while the server still
  /// considers it live, and the card would sit there fully decayed.
  final DateTime serverNow;

  static FeedBoard fromJson(dynamic raw) {
    if (raw is! Map) return FeedBoard(moments: const [], serverNow: DateTime.now());
    final map = raw.cast<String, dynamic>();
    return FeedBoard(
      moments: [
        for (final m in (map['moments'] as List?) ?? const [])
          Moment.fromJson((m as Map).cast<String, dynamic>()),
      ],
      serverNow: DateTime.fromMillisecondsSinceEpoch(
        (map['serverNow'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      puzzle: PuzzleState.fromJson(
        (map['puzzle'] as Map?)?.cast<String, dynamic>(),
      ),
      games: Map.fromEntries([
        for (final g in (map['games'] as List?) ?? const [])
          ?_gameEntry(GameResult.fromJson((g as Map).cast<String, dynamic>())),
      ]),
    );
  }
}

/// One `game: result` pair, or null for a row this build does not know about.
///
/// A game the server has started shipping and this app version has never heard
/// of decodes to null, and the band simply does not draw a tile for it — rather
/// than the whole board payload failing to parse on an older client.
MapEntry<DailyGame, GameResult>? _gameEntry(GameResult? row) =>
    row == null ? null : MapEntry(row.game, row);

/// One page of [FeedApi.archive].
class MomentPage {
  const MomentPage({required this.items, required this.hasMore});
  final List<Moment> items;
  final bool hasMore;
}
