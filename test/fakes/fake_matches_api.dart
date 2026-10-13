import 'package:monkeyhub/backend/matches_api.dart';
import 'package:monkeyhub/models/chat_match.dart';

/// A [MatchesApi] with no socket: [push] delivers a row to whoever is
/// watching, and every call is recorded in [calls] as `name` or
/// `name:arg`. [failNextMove] makes the next move throw the given code, and
/// [failNextAct] the next party action. [pushSecret] delivers a seat's hidden
/// slice to the screen watching `matches:mySecret`.
class FakeMatchesApi implements MatchesApi {
  final List<String> calls = [];
  final Map<String, void Function(ChatMatch?)> _watchers = {};
  final Map<String, void Function(List<ChatMatch>)> _rooms = {};
  final Map<String, void Function(PartySecret?)> _secrets = {};
  String? failNextMove;
  String? failNextAct;

  /// The party actions sent, in order, without the other calls.
  final List<String> actions = [];

  /// Options the last `create` carried.
  MatchOptions? lastOptions;

  void push(ChatMatch? m, {String? matchId}) =>
      _watchers[matchId ?? m!.id]?.call(m);

  void pushSecret(String matchId, PartySecret? s) =>
      _secrets[matchId]?.call(s);

  bool watchingSecret(String matchId) => _secrets.containsKey(matchId);

  void pushRoom(String roomId, List<ChatMatch> rows) =>
      _rooms[roomId]?.call(rows);

  @override
  Future<void Function()> watch(
    String userId,
    String matchId,
    void Function(ChatMatch?) onData, {
    void Function(Object)? onError,
  }) async {
    _watchers[matchId] = onData;
    calls.add('watch');
    return () => _watchers.remove(matchId);
  }

  @override
  Future<void Function()> watchRoom(
    String userId,
    String roomId,
    void Function(List<ChatMatch>) onData, {
    void Function(Object)? onError,
  }) async {
    _rooms[roomId] = onData;
    return () => _rooms.remove(roomId);
  }

  @override
  Future<void Function()> watchMyTurns(
    String userId,
    void Function(Set<String>) onData,
  ) async => () {};

  @override
  Future<List<ChatMatch>> forMessages(String userId, List<String> ids) async =>
      const [];

  @override
  Future<int> move({
    required String userId,
    required String matchId,
    required int expectedSeq,
    required String move,
    required String clientMoveId,
  }) async {
    calls.add('move:$move');
    final fail = failNextMove;
    if (fail != null) {
      failNextMove = null;
      throw Exception('ConvexError: $fail');
    }
    return expectedSeq + 1;
  }

  @override
  Future<({int seq, bool replay, bool ignored})> partyAct({
    required String userId,
    required String matchId,
    required int expectedSeq,
    required String action,
    required String clientActionId,
  }) async {
    calls.add('act:$action');
    actions.add(action);
    final fail = failNextAct;
    if (fail != null) {
      failNextAct = null;
      throw Exception('ConvexError: $fail');
    }
    return (seq: expectedSeq + 1, replay: false, ignored: false);
  }

  @override
  Future<void Function()> watchSecret(
    String userId,
    String matchId,
    void Function(PartySecret?) onData, {
    void Function(Object)? onError,
  }) async {
    _secrets[matchId] = onData;
    calls.add('watchSecret');
    return () => _secrets.remove(matchId);
  }

  @override
  Future<({String matchId, String messageId})> create({
    required String userId,
    required String roomId,
    required String game,
    required MatchMode mode,
    required String clientId,
    String? senderName,
    MatchOptions options = MatchOptions.none,
  }) async {
    lastOptions = options;
    calls.add('create:$game:${mode.wire}');
    return (matchId: 'm-new', messageId: 'msg-new');
  }

  /// Makes the next `startTurns` throw the given code.
  String? failNextStart;

  @override
  Future<({String matchId, String messageId, int seq})> startTurns({
    required String userId,
    required String roomId,
    required String game,
    required String move,
    required String clientMoveId,
    String? senderName,
    String? rematchOf,
  }) async {
    calls.add(
      'startTurns:$game:$move${rematchOf == null ? '' : ':re=$rematchOf'}',
    );
    final fail = failNextStart;
    if (fail != null) {
      failNextStart = null;
      throw Exception('ConvexError: $fail');
    }
    return (matchId: 'm-turns', messageId: 'msg-move-1', seq: 1);
  }

  @override
  Future<({String matchId, String messageId})> rematch({
    required String userId,
    required String matchId,
    required String clientId,
  }) async {
    calls.add('rematch');
    return (matchId: 'm-re', messageId: 'msg-re');
  }

  @override
  Future<void> join(String userId, String matchId) async => calls.add('join');
  @override
  Future<void> leave(String userId, String matchId) async => calls.add('leave');
  @override
  Future<void> setReady(String userId, String matchId, bool ready) async =>
      calls.add('ready:$ready');
  @override
  Future<void> resign(String userId, String matchId) async =>
      calls.add('resign');
  @override
  Future<void> offerDraw(String userId, String matchId) async =>
      calls.add('offerDraw');
  @override
  Future<void> answerDraw(String userId, String matchId, bool accept) async =>
      calls.add('answerDraw:$accept');
  @override
  Future<void> requestSeat(String userId, String matchId, int seat) async =>
      calls.add('requestSeat:$seat');
  @override
  Future<void> cancelSeatRequest(String userId, String matchId) async =>
      calls.add('cancelSeatRequest');
  @override
  Future<void> answerSeatRequest(
    String userId,
    String matchId,
    bool accept,
  ) async => calls.add('answerSeat:$accept');
  @override
  Future<void> beat(String userId, String matchId) async => calls.add('beat');
  @override
  Future<void> away(String userId, String matchId) async => calls.add('away');
  @override
  Future<void> nudge(String userId, String matchId) async => calls.add('nudge');
}
