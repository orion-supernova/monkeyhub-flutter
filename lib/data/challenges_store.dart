import 'package:flutter/widgets.dart';

import '../backend/convex_client.dart';
import '../models/daily_game.dart';
import 'chat_repository.dart';

/// One "Beat my time" card's body: whose time, on which board.
class GameChallenge {
  const GameChallenge({
    required this.messageId,
    required this.userId,
    required this.name,
    required this.game,
    required this.dayKey,
    required this.durationMs,
    required this.hintsUsed,
    this.roomId = '',
    this.isGroup = true,
    this.roomName,
  });

  final String messageId;
  final String userId;
  final String name;
  final DailyGame game;
  final String dayKey;
  final int durationMs;
  final int hintsUsed;

  /// The room the card was sent into, for "challenge back". Empty from a
  /// server older than the field.
  final String roomId;

  /// False for a DM. True when unknown, which only costs the button its
  /// person's name.
  final bool isGroup;

  /// The group's name; null for a DM.
  final String? roomName;

  static GameChallenge? fromJson(Map<String, dynamic> j) {
    final game = DailyGame.parse(j['game']?.toString());
    if (game == null) return null;
    return GameChallenge(
      messageId: j['messageId']?.toString() ?? '',
      userId: j['userId']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      game: game,
      dayKey: j['dayKey']?.toString() ?? '',
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
      hintsUsed: (j['hintsUsed'] as num?)?.toInt() ?? 0,
      roomId: j['roomId']?.toString() ?? '',
      isGroup: j['isGroup'] != false,
      roomName: j['roomName']?.toString(),
    );
  }
}

/// The time a daily board is being played against, while it is, and where
/// the dare came from — so a solve can answer it in the same chat.
class ChallengeTarget {
  const ChallengeTarget({
    required this.game,
    required this.dayKey,
    required this.name,
    required this.durationMs,
    this.challengerId = '',
    this.roomId = '',
    this.messageId = '',
    this.isGroup = true,
    this.roomName,
  });

  /// The board a challenge card opens, from that card's body.
  /// [roomId] is the card's own message's room, which a server older than
  /// [GameChallenge.roomId] does not send.
  factory ChallengeTarget.of(GameChallenge c, {String? roomId}) =>
      ChallengeTarget(
    game: c.game,
    dayKey: c.dayKey,
    name: c.name,
    durationMs: c.durationMs,
    challengerId: c.userId,
    roomId: c.roomId.isNotEmpty ? c.roomId : (roomId ?? ''),
    messageId: c.messageId,
    isGroup: c.isGroup,
    roomName: c.roomName,
  );

  final DailyGame game;
  final String dayKey;
  final String name;
  final int durationMs;
  final String challengerId;
  final String roomId;
  final String messageId;
  final bool isGroup;
  final String? roomName;
}

/// The challenge one board's route was opened against.
///
/// Scoped to the ROUTE, never a global: the card that opens a board wraps it
/// in this, so the chip and the result card can only ever see the dare that
/// opened this very screen. Opening the same game from the hub carries no
/// scope and so can never show a stale target from an earlier card.
class ChallengeScope extends InheritedWidget {
  const ChallengeScope({super.key, required this.target, required super.child});

  final ChallengeTarget? target;

  static ChallengeTarget? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChallengeScope>()?.target;

  @override
  bool updateShouldNotify(ChallengeScope old) => old.target != target;
}

/// One board's finished results among a room's members: the "who played"
/// line on a challenge card. Rows arrive sorted and placed by the server,
/// the viewer's nameless.
class RoomResults {
  const RoomResults({
    required this.isGroup,
    required this.played,
    required this.rows,
    required this.avatars,
  });

  final bool isGroup;
  final int played;
  final List<GameResult> rows;

  /// Faces by user id, already through the viewer's privacy lens.
  final Map<String, String> avatars;

  static RoomResults? fromJson(dynamic raw, DailyGame game) {
    if (raw is! Map) return null;
    final rows = <GameResult>[];
    final avatars = <String, String>{};
    for (final r in (raw['rows'] as List?) ?? const []) {
      if (r is! Map) continue;
      final j = r.cast<String, dynamic>();
      final row = GameResult.fromJson(j, game: game);
      if (row == null) continue;
      rows.add(row);
      final face = j['avatarStorageId']?.toString();
      if (face != null && face.isNotEmpty) avatars[row.userId] = face;
    }
    return RoomResults(
      isGroup: raw['isGroup'] != false,
      played: (raw['played'] as num?)?.toInt() ?? rows.length,
      rows: rows,
      avatars: avatars,
    );
  }
}

class _RoomResultsEntry {
  _RoomResultsEntry(this.value, this.at, this.viewerFinished);
  final RoomResults? value;
  final DateTime at;
  final bool viewerFinished;
}

/// "Beat my time": the cards' bodies, and the target a challenged board is
/// being played against.
///
/// A challenge never changes once sent, so its body is fetched once per card
/// (`challenges:forMessages`) and kept for the session — no subscription. The
/// target a board is played against is NOT kept here: it rides the route, see
/// [ChallengeScope].
///
/// "Who played" (`challenges:roomResults`) is one-shot too, cached per
/// (room, game, day) so every card of the same board in a room shares one
/// fetch. It is fetched again when a card is drawn after [roomResultsTtl], and
/// at once when the viewer has finished the board since the last fetch — the
/// moment their own row would appear. A subscription would re-run on every
/// read cursor in the room.
class ChallengesStore extends ChangeNotifier {
  ChallengesStore._();
  static final ChallengesStore instance = ChallengesStore._();

  /// The chat repository, for the "send to which chats" picker. Set once by
  /// the app at sign-in; a daily game's scaffold has no other way to it.
  ChatRepository? repo;

  final Map<String, GameChallenge> _byMessage = {};
  final Set<String> _asked = {};

  static const roomResultsTtl = Duration(seconds: 60);
  final Map<String, _RoomResultsEntry> _roomResults = {};
  final Set<String> _roomResultsInFlight = {};

  /// Challenge cards answered from their result card this session, by
  /// message id — the "challenge back" button's sent state.
  final Set<String> _answered = {};
  final Set<String> _answering = {};

  GameChallenge? forMessage(String messageId) => _byMessage[messageId];

  Future<void> ensureFor(String userId, Iterable<String> messageIds) async {
    final want = [
      for (final id in messageIds)
        if (!_byMessage.containsKey(id) && _asked.add(id)) id,
    ];
    if (want.isEmpty) return;
    try {
      final raw = await ConvexBackend.instance.query('challenges:forMessages', {
        'messageIds': want,
        'viewerUserId': userId,
      });
      for (final r in (raw as List?) ?? const []) {
        if (r is! Map) continue;
        final c = GameChallenge.fromJson(r.cast<String, dynamic>());
        if (c != null) _byMessage[c.messageId] = c;
      }
      notifyListeners();
    } catch (_) {
      _asked.removeAll(want);
    }
  }

  static String _roomKey(String roomId, DailyGame game, String dayKey) =>
      '$roomId|${game.wire}|$dayKey';

  RoomResults? roomResults(String roomId, DailyGame game, String dayKey) =>
      _roomResults[_roomKey(roomId, game, dayKey)]?.value;

  /// Fetches "who played" for one board in one room unless a fresh enough
  /// answer is cached or a fetch is already out. Safe to call from build.
  Future<void> ensureRoomResults({
    required String userId,
    required String roomId,
    required DailyGame game,
    required String dayKey,
    required bool viewerFinished,
  }) async {
    if (userId.isEmpty || roomId.isEmpty || dayKey.isEmpty) return;
    final key = _roomKey(roomId, game, dayKey);
    final have = _roomResults[key];
    final fresh = have != null &&
        DateTime.now().difference(have.at) < roomResultsTtl &&
        (have.viewerFinished || !viewerFinished);
    if (fresh || !_roomResultsInFlight.add(key)) return;
    try {
      final raw = await ConvexBackend.instance.query('challenges:roomResults', {
        'roomId': roomId,
        'game': game.wire,
        'dayKey': dayKey,
        'viewerUserId': userId,
      });
      _roomResults[key] = _RoomResultsEntry(
        RoomResults.fromJson(raw, game),
        DateTime.now(),
        viewerFinished,
      );
      notifyListeners();
    } catch (_) {
      // Left uncached, so the next draw tries again.
    } finally {
      _roomResultsInFlight.remove(key);
    }
  }

  bool answered(String messageId) => _answered.contains(messageId);
  bool answering(String messageId) => _answering.contains(messageId);

  /// Answers [target]'s card in its own room with the viewer's result for
  /// the same board: no picker, one room. Marks the card answered.
  Future<void> answer({
    required String userId,
    required ChallengeTarget target,
  }) async {
    if (!_answering.add(target.messageId)) return;
    notifyListeners();
    try {
      await send(
        userId: userId,
        roomIds: [target.roomId],
        game: target.game,
        dayKey: target.dayKey,
      );
    } finally {
      _answering.remove(target.messageId);
    }
    _answered.add(target.messageId);
    // Their own row is on this room's board now, and so is the new card.
    _roomResults.remove(_roomKey(target.roomId, target.game, target.dayKey));
    notifyListeners();
  }

  /// Sends the viewer's finished result for [game] on [dayKey] to [roomIds].
  Future<void> send({
    required String userId,
    required List<String> roomIds,
    required DailyGame game,
    required String dayKey,
  }) => ConvexBackend.instance.mutation('challenges:send', {
    'userId': userId,
    'roomIds': roomIds,
    'game': game.wire,
    'dayKey': dayKey,
    'clientId': 'ch_${DateTime.now().microsecondsSinceEpoch}',
  });

  /// Puts a card's body and its room's results in place, as the two fetches
  /// would. Tests only.
  @visibleForTesting
  void debugSeed({GameChallenge? challenge, RoomResults? results, String? roomId}) {
    if (challenge != null) _byMessage[challenge.messageId] = challenge;
    if (challenge != null && results != null) {
      _roomResults[_roomKey(roomId ?? challenge.roomId, challenge.game, challenge.dayKey)] =
          _RoomResultsEntry(results, DateTime.now(), true);
    }
    notifyListeners();
  }

  void clear() {
    _byMessage.clear();
    _asked.clear();
    _roomResults.clear();
    _roomResultsInFlight.clear();
    _answered.clear();
    _answering.clear();
    repo = null;
  }
}
