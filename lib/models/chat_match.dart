/// One in-chat game, as `matches:get` / `matches:listForRoom` deliver it.
///
/// The live body of a chat card of type `game` — the card itself is a plain
/// message whose `content` is the game's name. Everything a screen needs to
/// draw the table is here: who sits where, whose turn it is, the encoded
/// position (decoded by the game's rules in `lib/turn_games/`), and how it
/// ended. Nothing in it is secret; every member of the room may see it.
///
/// A PARTY game (Liar's Dice, Imposter, Puzzle Race) rides the same row:
/// [state] is then the public view's JSON (parsed by
/// `lib/party_games/party_views.dart`), and a player's own hidden slice (their
/// dice, their word) comes separately from `matches:mySecret`.
///
/// Not ranked, and nothing here feeds a daily game's standings or records —
/// see `backend/convex/matches.ts`.
library;

enum MatchMode {
  /// Everyone at the board at once; leaving pauses it.
  live,

  /// A DM game played a move at a time, with a push for each turn.
  async;

  static MatchMode parse(Object? raw) =>
      raw == 'async' ? MatchMode.async : MatchMode.live;

  String get wire => name;
}

enum MatchStatus {
  lobby,
  active,
  paused,
  finished,
  abandoned;

  static MatchStatus parse(Object? raw) => switch (raw) {
    'lobby' => MatchStatus.lobby,
    'active' => MatchStatus.active,
    'paused' => MatchStatus.paused,
    'finished' => MatchStatus.finished,
    _ => MatchStatus.abandoned,
  };

  /// Still being played, or waiting to be.
  bool get isOpen =>
      this == MatchStatus.lobby ||
      this == MatchStatus.active ||
      this == MatchStatus.paused;
}

class MatchSeat {
  const MatchSeat({
    required this.userId,
    required this.name,
    this.ready = false,
    this.away = false,
    this.out = false,
    this.done = false,
  });

  final String userId;

  /// Denormalized when they sat down, so a card never waits on a user fetch.
  final String name;

  /// Lobby only.
  final bool ready;

  /// Live only: left the board, which is what paused the game.
  final bool away;

  /// Forfeited in a game of more than two; the others play on.
  final bool out;

  /// Party games: nothing left to do (out of dice, finished the race). Such a
  /// seat is never marked away, so the screen should not nag them either.
  final bool done;

  static MatchSeat fromJson(Map<String, dynamic> j) => MatchSeat(
    userId: j['userId']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    ready: j['ready'] == true,
    away: j['away'] == true,
    out: j['out'] == true,
    done: j['done'] == true,
  );
}

/// What a party game's creator chose at `matches.create`, as the server
/// validated it. Carried by a rematch, so the next round plays the same way.
class MatchOptions {
  const MatchOptions({this.voice = false, this.puzzle});

  /// Imposter: clues are spoken on the room's call, not typed.
  final bool voice;

  /// Puzzle Race: `queens` | `tango` | `sudoku` | `zip`; null is random.
  final String? puzzle;

  static const none = MatchOptions();

  static MatchOptions parse(Object? raw) {
    if (raw is! Map) return none;
    final puzzle = raw['puzzle'];
    return MatchOptions(
      voice: raw['voice'] == true,
      puzzle: puzzle is String && puzzle != 'random' ? puzzle : null,
    );
  }

  /// The wire shape `matches.create` takes, or null when there is nothing
  /// to say (a turn game, or a party game left on its defaults).
  Map<String, dynamic>? toWire() {
    final out = <String, dynamic>{
      if (voice) 'voice': true,
      'puzzle': ?puzzle,
    };
    return out.isEmpty ? null : out;
  }
}

class SeatRequest {
  const SeatRequest({
    required this.userId,
    required this.name,
    required this.seat,
    required this.at,
  });

  final String userId;
  final String name;
  final int seat;
  final DateTime at;
}

class ChatMatch {
  const ChatMatch({
    required this.id,
    required this.roomId,
    required this.messageId,
    required this.game,
    required this.mode,
    required this.status,
    required this.seats,
    required this.state,
    required this.seq,
    required this.turnSeat,
    required this.createdBy,
    required this.createdAt,
    this.lastMove,
    this.startedAt,
    this.lastMoveAt,
    this.finishedAt,
    this.deadlineAt,
    this.nudgedAt,
    this.watching = 0,
    this.watchers = const [],
    this.seatRequest,
    this.drawOfferSeat,
    this.drawOfferSeq,
    this.winner,
    this.winners,
    this.draw = false,
    this.reason,
    this.party = false,
    this.options = MatchOptions.none,
    this.phaseSeq = 0,
    this.pausedAt,
  });

  final String id;
  final String roomId;
  final String messageId;

  /// A `lib/turn_games/registry.dart` id.
  final String game;
  final MatchMode mode;
  final MatchStatus status;
  final List<MatchSeat> seats;

  /// The rules module's encoding. Null in a lobby.
  final String? state;

  /// Moves applied so far — and the fence a move is sent against.
  final int seq;
  final int? turnSeat;

  /// The move that produced [state], for the board's highlight.
  final String? lastMove;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? lastMoveAt;
  final DateTime? finishedAt;

  /// Async: when the player to move forfeits. Live: when a pause ends.
  final DateTime? deadlineAt;
  final DateTime? nudgedAt;

  /// Room members watching right now (not seated).
  final int watching;

  /// Who they are, in the order they arrived: at most a dozen, so
  /// [watching] can be the larger. Empty from a server that predates it.
  final List<String> watchers;

  /// [watchers] less anyone seated since the server last counted (a seat
  /// swap lands before the next recount).
  List<String> get watcherIds =>
      [for (final w in watchers) if (!isSeated(w)) w];
  final SeatRequest? seatRequest;
  final int? drawOfferSeat;
  final int? drawOfferSeq;

  /// The winning seat, when there is one.
  final int? winner;

  /// A party game won by a team (Imposter's crew). When set, [winner] is
  /// absent.
  final List<int>? winners;
  final bool draw;

  /// "win" | "draw" | "resign" | "timeout" | "left" | "abandoned", and for a
  /// party game its own: Imposter's `escaped` | `wrongAccused` | `guessed` |
  /// `caught` | `imposterLeft`, Puzzle Race's `finished` | `time`.
  final String? reason;

  /// A party game: [state] is a public view, actions go through `partyAct`.
  final bool party;
  final MatchOptions options;

  /// Party games: the [seq] the current phase began at. An action against an
  /// older seq than this is refused as `STALE`.
  final int phaseSeq;

  /// Party games: when the game's clock was frozen by a pause.
  final DateTime? pausedAt;

  int seatOf(String userId) => seats.indexWhere((s) => s.userId == userId);

  bool isSeated(String userId) => seatOf(userId) >= 0;

  /// Whether [seat] is on the winning side: the one winner, or one of a
  /// winning team.
  bool seatWon(int seat) =>
      winner == seat || (winners?.contains(seat) ?? false);

  bool isTurnOf(String userId) {
    final t = turnSeat;
    return status == MatchStatus.active &&
        t != null &&
        t < seats.length &&
        seats[t].userId == userId;
  }

  /// A draw offer standing at the current position, from someone else.
  bool drawOfferedTo(String userId) {
    final seat = drawOfferSeat;
    return seat != null &&
        drawOfferSeq == seq &&
        status == MatchStatus.active &&
        isSeated(userId) &&
        seatOf(userId) != seat;
  }

  ChatMatch withOptimistic({
    required String state,
    required int seq,
    required String lastMove,
  }) =>
      ChatMatch(
        id: id,
        roomId: roomId,
        messageId: messageId,
        game: game,
        mode: mode,
        status: status,
        seats: seats,
        state: state,
        seq: seq,
        turnSeat: null,
        lastMove: lastMove,
        createdBy: createdBy,
        createdAt: createdAt,
        startedAt: startedAt,
        lastMoveAt: lastMoveAt,
        finishedAt: finishedAt,
        deadlineAt: deadlineAt,
        nudgedAt: nudgedAt,
        watching: watching,
        watchers: watchers,
        seatRequest: seatRequest,
        winner: winner,
        winners: winners,
        draw: draw,
        reason: reason,
        party: party,
        options: options,
        phaseSeq: phaseSeq,
        pausedAt: pausedAt,
      );

  static DateTime? _at(Object? raw) => raw is num
      ? DateTime.fromMillisecondsSinceEpoch(raw.toInt())
      : null;

  static ChatMatch? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final id = j['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final req = j['seatRequest'];
    final offer = j['drawOffer'];
    return ChatMatch(
      id: id,
      roomId: j['roomId']?.toString() ?? '',
      messageId: j['messageId']?.toString() ?? '',
      game: j['game']?.toString() ?? '',
      mode: MatchMode.parse(j['mode']),
      status: MatchStatus.parse(j['status']),
      seats: [
        for (final s in (j['seats'] as List?) ?? const [])
          if (s is Map) MatchSeat.fromJson(s.cast<String, dynamic>()),
      ],
      state: j['state']?.toString(),
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      turnSeat: (j['turnSeat'] as num?)?.toInt(),
      lastMove: j['lastMove']?.toString(),
      createdBy: j['createdBy']?.toString() ?? '',
      createdAt: _at(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      startedAt: _at(j['startedAt']),
      lastMoveAt: _at(j['lastMoveAt']),
      finishedAt: _at(j['finishedAt']),
      deadlineAt: _at(j['deadlineAt']),
      nudgedAt: _at(j['nudgedAt']),
      watching: (j['watching'] as num?)?.toInt() ?? 0,
      watchers: [
        for (final w in (j['watchers'] as List?) ?? const []) w.toString(),
      ],
      seatRequest: req is Map
          ? SeatRequest(
              userId: req['userId']?.toString() ?? '',
              name: req['name']?.toString() ?? '',
              seat: (req['seat'] as num?)?.toInt() ?? 0,
              at: _at(req['at']) ?? DateTime.now(),
            )
          : null,
      drawOfferSeat: offer is Map ? (offer['seat'] as num?)?.toInt() : null,
      drawOfferSeq: offer is Map ? (offer['seq'] as num?)?.toInt() : null,
      winner: (j['winner'] as num?)?.toInt(),
      winners: j['winners'] is List
          ? [
              for (final w in j['winners'] as List)
                if (w is num) w.toInt(),
            ]
          : null,
      draw: j['draw'] == true,
      reason: j['reason']?.toString(),
      party: j['party'] == true || isPartyGame(j['game']?.toString() ?? ''),
      options: MatchOptions.parse(j['options']),
      phaseSeq: (j['phaseSeq'] as num?)?.toInt() ?? 0,
      pausedAt: _at(j['pausedAt']),
    );
  }
}

/// The games a room can start, in the order the start sheet offers them.
///
/// Mirrors `backend/convex/turnGames/registry.ts`. A game missing here is
/// simply not offered; one missing there is refused (`UNKNOWN_GAME`).
const kChatGames = [
  'tictactoe',
  'connectfour',
  'checkers',
  'reversi',
  'dots',
  'chess',
];

/// The party games, in the order the start sheet's Party section offers
/// them. Mirrors `backend/convex/partyGames/registry.ts`. Live only.
const kPartyGames = ['liarsdice', 'imposter', 'race'];

bool isPartyGame(String game) => kPartyGames.contains(game);

/// Most seats each game takes: the lobby's capacity. Mirrors `maxSeats` in
/// the backend registries.
int maxSeatsOf(String game) => switch (game) {
  'dots' => 4,
  'liarsdice' => 6,
  'imposter' || 'race' => 8,
  _ => 2,
};

/// Fewest seats a game starts with: what the lobby waits for. Imposter needs
/// three, since with two the imposter is simply "the other one".
int minSeatsOf(String game) => game == 'imposter' ? 3 : 2;

/// Puzzle Race's boards, as `matches.create`'s `options.puzzle` names them.
const kRacePuzzles = ['queens', 'tango', 'sudoku', 'zip'];

/// The async games allowed in one DM at once (`matches.MAX_ASYNC_PER_DM`).
const kMaxAsyncPerDm = 3;
