import '../models/chat_match.dart';
import 'convex_client.dart';

/// Every Convex call in-chat games make (`backend/convex/matches.ts`).
///
/// Mutations throw the server's bare error code inside the exception text
/// (`STALE`, `ILLEGAL`, `ALREADY_LIVE`, …); [matchErrorCode] pulls it out so
/// a screen can pick a localized line for it.
class MatchesApi {
  MatchesApi(this._cv);
  final ConvexBackend _cv;

  Future<({String matchId, String messageId})> create({
    required String userId,
    required String roomId,
    required String game,
    required MatchMode mode,
    required String clientId,
    String? senderName,
    MatchOptions options = MatchOptions.none,
  }) async {
    final res = await _cv.mutation('matches:create', {
      'userId': userId,
      'roomId': roomId,
      'game': game,
      'mode': mode.wire,
      'clientId': clientId,
      'senderName': ?senderName,
      'options': ?options.toWire(),
    });
    final m = (res as Map).cast<String, dynamic>();
    return (
      matchId: m['matchId'].toString(),
      messageId: m['messageId'].toString(),
    );
  }

  Future<({String matchId, String messageId})> rematch({
    required String userId,
    required String matchId,
    required String clientId,
  }) async {
    final res = await _cv.mutation('matches:rematch', {
      'userId': userId,
      'matchId': matchId,
      'clientId': clientId,
    });
    final m = (res as Map).cast<String, dynamic>();
    return (
      matchId: m['matchId'].toString(),
      messageId: m['messageId'].toString(),
    );
  }

  Future<void> _call(String name, String userId, String matchId,
          [Map<String, dynamic> extra = const {}]) =>
      _cv.mutation('matches:$name', {
        'userId': userId,
        'matchId': matchId,
        ...extra,
      });

  Future<void> join(String userId, String matchId) =>
      _call('join', userId, matchId);
  Future<void> leave(String userId, String matchId) =>
      _call('leave', userId, matchId);
  Future<void> setReady(String userId, String matchId, bool ready) =>
      _call('setReady', userId, matchId, {'ready': ready});
  Future<void> resign(String userId, String matchId) =>
      _call('resign', userId, matchId);
  Future<void> offerDraw(String userId, String matchId) =>
      _call('offerDraw', userId, matchId);
  Future<void> answerDraw(String userId, String matchId, bool accept) =>
      _call('answerDraw', userId, matchId, {'accept': accept});
  Future<void> requestSeat(String userId, String matchId, int seat) =>
      _call('requestSeat', userId, matchId, {'seat': seat});
  Future<void> cancelSeatRequest(String userId, String matchId) =>
      _call('cancelSeatRequest', userId, matchId);
  Future<void> answerSeatRequest(String userId, String matchId, bool accept) =>
      _call('answerSeatRequest', userId, matchId, {'accept': accept});
  Future<void> beat(String userId, String matchId) =>
      _call('beat', userId, matchId);
  Future<void> away(String userId, String matchId) =>
      _call('away', userId, matchId);
  Future<void> nudge(String userId, String matchId) =>
      _call('nudge', userId, matchId);

  /// One move, fenced on [expectedSeq]. Resending with the same
  /// [clientMoveId] after a lost reply is answered as the success it was.
  Future<int> move({
    required String userId,
    required String matchId,
    required int expectedSeq,
    required String move,
    required String clientMoveId,
  }) async {
    final res = await _cv.mutation('matches:move', {
      'userId': userId,
      'matchId': matchId,
      'expectedSeq': expectedSeq,
      'move': move,
      'clientMoveId': clientMoveId,
    });
    return ((res as Map)['seq'] as num).toInt();
  }

  /// One party-game action (`bid:3:5`, `vote:2`, `finish:[…]`), fenced on
  /// the phase [expectedSeq] belongs to. A resend with the same
  /// [clientActionId] is answered as the success it was (`replay`); an action
  /// the rules took but that changed nothing (a throttled progress tick) comes
  /// back `ignored`.
  Future<({int seq, bool replay, bool ignored})> partyAct({
    required String userId,
    required String matchId,
    required int expectedSeq,
    required String action,
    required String clientActionId,
  }) async {
    final res = await _cv.mutation('matches:partyAct', {
      'userId': userId,
      'matchId': matchId,
      'expectedSeq': expectedSeq,
      'action': action,
      'clientActionId': clientActionId,
    });
    final m = (res as Map).cast<String, dynamic>();
    return (
      seq: (m['seq'] as num?)?.toInt() ?? expectedSeq,
      replay: m['replay'] == true,
      ignored: m['ignored'] == true,
    );
  }

  /// The viewer's own hidden slice of a party game (their dice, their card),
  /// live. One per open party screen: the row is tiny and refires with the
  /// game, which is exactly when a new round's dice or a new ballot lands.
  Future<void Function()> watchSecret(
    String userId,
    String matchId,
    void Function(PartySecret?) onData, {
    void Function(Object)? onError,
  }) async => (await _cv.subscribe(
    'matches:mySecret',
    {'matchId': matchId, 'viewerUserId': userId},
    onData: (raw) => onData(raw is Map ? PartySecret.fromJson(raw) : null),
    onError: onError,
  )).cancel;

  // The three live reads hand back a cancel function rather than the
  // transport's `Subscription`, so a test can stand in for this class without
  // a socket.

  Future<void Function()> watch(
    String userId,
    String matchId,
    void Function(ChatMatch?) onData, {
    void Function(Object)? onError,
  }) async => (await _cv.subscribe(
    'matches:get',
    {'matchId': matchId, 'viewerUserId': userId},
    onData: (raw) => onData(
      raw is Map ? ChatMatch.fromJson(raw.cast<String, dynamic>()) : null,
    ),
    onError: onError,
  )).cancel;

  Future<void Function()> watchRoom(
    String userId,
    String roomId,
    void Function(List<ChatMatch>) onData, {
    void Function(Object)? onError,
  }) async => (await _cv.subscribe(
    'matches:listForRoom',
    {'roomId': roomId, 'viewerUserId': userId},
    onData: (raw) => onData(_list(raw)),
    onError: onError,
  )).cancel;

  Future<void Function()> watchMyTurns(
    String userId,
    void Function(Set<String> roomIds) onData,
  ) async => (await _cv.subscribe(
    'matches:myTurns',
    {'viewerUserId': userId},
    onData: (raw) => onData({
      for (final r in (raw as List?) ?? const [])
        if (r is Map) r['roomId'].toString(),
    }),
  )).cancel;

  Future<List<ChatMatch>> forMessages(
    String userId,
    List<String> messageIds,
  ) async => _list(
    await _cv.query('matches:forMessages', {
      'messageIds': messageIds,
      'viewerUserId': userId,
    }),
  );

  static List<ChatMatch> _list(Object? raw) => [
    for (final r in (raw as List?) ?? const [])
      if (r is Map) ?ChatMatch.fromJson(r.cast<String, dynamic>()),
  ];
}

/// What `matches:mySecret` returns: which seat the viewer holds, the `seq` the
/// secret is for, and the secret itself as the rules' JSON (null for a seat
/// with nothing hidden, and for every Puzzle Race seat).
class PartySecret {
  const PartySecret({required this.seat, required this.seq, this.secret});

  final int seat;
  final int seq;
  final String? secret;

  static PartySecret fromJson(Map raw) => PartySecret(
    seat: (raw['seat'] as num?)?.toInt() ?? -1,
    seq: (raw['seq'] as num?)?.toInt() ?? 0,
    secret: raw['secret']?.toString(),
  );
}

/// The bare server code out of a thrown Convex failure, or `UNKNOWN`.
String matchErrorCode(Object e) {
  // Longest first where one code is a prefix of another's text.
  const known = [
    'STALE',
    'TOO_LATE',
    'BAD_CLUE',
    'BAD_GUESS',
    'NOT_SOLVED',
    'ALREADY_FINISHED',
    'LIVE_ONLY',
    'BAD_OPTIONS',
    'ILLEGAL',
    'NOT_YOUR_TURN',
    'PAUSED',
    'NOT_ACTIVE',
    'NOT_SEATED',
    'ALREADY_LIVE',
    'TOO_MANY_GAMES',
    'ASYNC_DM_ONLY',
    'NO_OPPONENT',
    'FULL',
    'NOT_IN_LOBBY',
    'REQUEST_PENDING',
    'TOO_SOON',
    'NO_MATCH',
    'NOT_A_MEMBER',
    'NOT_MEMBER',
    'UNKNOWN_GAME',
  ];
  final text = e.toString();
  return known.firstWhere(text.contains, orElse: () => 'UNKNOWN');
}
