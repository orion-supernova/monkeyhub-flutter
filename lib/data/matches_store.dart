import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../backend/convex_client.dart';
import '../backend/matches_api.dart';
import '../models/chat_match.dart';
import '../models/chat_user.dart';
import '../turn_games/registry.dart';

/// In-chat games, for the screens that show them: the cards in a room's
/// transcript, the room's active-games banner, and the chat list's "your
/// move" dot.
///
/// One live subscription per OPEN room (`matches:listForRoom`), held while the
/// room's screen is up and dropped when it goes — the same lifetime the
/// room's other secondary subscriptions have — plus one global
/// `matches:myTurns` while signed in. A card scrolled back past the room's
/// window is hydrated once, on demand, through [ensureFor].
///
/// The game screen does not read from here; it holds its own
/// [MatchController], whose subscription is to the one game it shows.
class MatchesStore extends ChangeNotifier {
  MatchesStore._();
  static final MatchesStore instance = MatchesStore._();

  /// Resolves a seated player to their cached user, for their face. Set once
  /// by the app to the chat repository's lookups; null falls back to a
  /// monogram from the seat's denormalized name.
  ChatUser? Function(String roomId, String userId)? resolveUser;

  MatchesApi? _api;
  MatchesApi get api => _api ??= MatchesApi(ConvexBackend.instance);
  set api(MatchesApi value) => _api = value;

  /// Every game this store has heard of, by its id. A game with a card (a
  /// live game, or an async one from an older build) is also findable by
  /// the card's message id through [_idByCard]; a turn by turn game started
  /// with its first move has no card at all, and is reached by its id alone
  /// (the room's banner, its move bubbles).
  final Map<String, ChatMatch> _byId = {};
  final Map<String, String> _idByCard = {};
  final Map<String, void Function()> _roomSubs = {};
  final Map<String, int> _roomRefs = {};

  /// Card message ids [ensureFor] has asked about.
  final Set<String> _hydrating = {};

  /// When [note] folded a game in, by its id: a room delivery read before
  /// that game existed must not evict it. See [_merge].
  final Map<String, DateTime> _notedAt = {};
  static const _noteGrace = Duration(seconds: 15);
  void Function()? _turnsSub;
  String? _turnsUser;
  Set<String> _myTurnRooms = const {};

  /// The game behind the card [messageId], if this store has heard of it.
  ChatMatch? forMessage(String messageId) {
    final id = _idByCard[messageId];
    return id == null ? null : _byId[id];
  }

  /// The game [matchId] names, if this store has heard of it.
  ChatMatch? forMatch(String matchId) => _byId[matchId];

  /// The room's games still being played or waiting to be, newest first.
  /// Card or no card: the banner shows every one.
  List<ChatMatch> openIn(String roomId) {
    final out = [
      for (final m in _byId.values)
        if (m.roomId == roomId && m.status.isOpen) m,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  void _put(ChatMatch m) {
    _byId[m.id] = m;
    if (m.messageId.isNotEmpty) _idByCard[m.messageId] = m.id;
  }

  /// Removes [matchId] and everything keyed to it. True when it was held.
  bool _drop(String matchId) {
    final m = _byId.remove(matchId);
    _notedAt.remove(matchId);
    if (m == null) return false;
    if (m.messageId.isNotEmpty) {
      _idByCard.remove(m.messageId);
      _hydrating.remove(m.messageId);
    }
    return true;
  }

  /// Rooms where an async game is waiting on the viewer.
  Set<String> get myTurnRooms => _myTurnRooms;

  /// Starts (or shares) the room's subscription. Pair with [unwatchRoom].
  Future<void> watchRoom(String userId, String roomId) async {
    final refs = (_roomRefs[roomId] ?? 0) + 1;
    _roomRefs[roomId] = refs;
    if (refs > 1) return;
    try {
      final sub = await api.watchRoom(userId, roomId, (rows) {
        _merge(roomId, rows);
      }, onError: (e) => debugPrint('matches:listForRoom error: $e'));
      // Unwatched while the subscribe was in flight.
      if ((_roomRefs[roomId] ?? 0) == 0) {
        sub();
        return;
      }
      _roomSubs[roomId] = sub;
    } catch (e) {
      debugPrint('matches watchRoom failed: $e');
    }
  }

  void unwatchRoom(String roomId) {
    final refs = (_roomRefs[roomId] ?? 0) - 1;
    if (refs > 0) {
      _roomRefs[roomId] = refs;
      return;
    }
    _roomRefs.remove(roomId);
    _roomSubs.remove(roomId)?.call();
  }

  /// Folds one delivery of the room's list in.
  ///
  /// The list is the source of truth for the room's OPEN games: it carries
  /// every one of them, card or not, so an open game this store holds for
  /// [roomId] that is missing from it no longer exists (its card was deleted
  /// or expired, which erases the game, or its room was wiped) and is
  /// evicted. Without that the banner kept counting a game whose screen then
  /// said it was gone. Finished games are left alone: the list carries only
  /// the newest of those, and an older one was hydrated for its card by
  /// [ensureFor].
  ///
  /// An evicted game's card is forgotten by [ensureFor] too, so a card still
  /// on screen (a game that finished outside the list's window) re-hydrates.
  void _merge(String roomId, List<ChatMatch> rows) {
    var changed = false;
    final present = {for (final m in rows) m.id};
    final now = DateTime.now();
    final gone = [
      for (final m in _byId.values)
        if (m.roomId == roomId &&
            m.status.isOpen &&
            !present.contains(m.id) &&
            !(_notedAt[m.id] != null &&
                now.difference(_notedAt[m.id]!) < _noteGrace))
          m.id,
    ];
    for (final id in gone) {
      changed = _drop(id) || changed;
    }
    for (final m in rows) {
      final before = _byId[m.id];
      if (before == null ||
          before.seq != m.seq ||
          before.status != m.status ||
          !_sameSeats(before, m) ||
          before.watching != m.watching ||
          before.seatRequest?.userId != m.seatRequest?.userId) {
        _put(m);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  static bool _sameSeats(ChatMatch a, ChatMatch b) {
    if (a.seats.length != b.seats.length) return false;
    for (var i = 0; i < a.seats.length; i++) {
      final x = a.seats[i];
      final y = b.seats[i];
      if (x.userId != y.userId ||
          x.ready != y.ready ||
          x.away != y.away ||
          x.out != y.out) {
        return false;
      }
    }
    return true;
  }

  /// Hydrates the games behind the cards [messageIds] that the room's window
  /// does not carry — cards scrolled back to. One-shot, and each id at most
  /// once per session unless it comes back missing.
  Future<void> ensureFor(String userId, Iterable<String> messageIds) async {
    final want = [
      for (final id in messageIds)
        if (!_idByCard.containsKey(id) && _hydrating.add(id)) id,
    ];
    if (want.isEmpty) return;
    try {
      for (var i = 0; i < want.length; i += 100) {
        final rows = await api.forMessages(
          userId,
          want.sublist(i, (i + 100).clamp(0, want.length)),
        );
        for (final m in rows) {
          _put(m);
        }
      }
      notifyListeners();
    } catch (e) {
      _hydrating.removeAll(want);
    }
  }

  /// Folds in a game the viewer just created or acted on, ahead of the
  /// subscription's echo, so its card or banner entry shows at once.
  void note(ChatMatch m) {
    if (m.id.isEmpty) return;
    _put(m);
    _notedAt[m.id] = DateTime.now();
    notifyListeners();
  }

  /// Drops [matchId]: its screen found the server row gone (or the viewer no
  /// longer in its room), so no banner or card should keep offering it.
  void forget(String matchId) {
    if (_drop(matchId)) notifyListeners();
  }

  Future<void> attach(String userId) async {
    if (_turnsUser == userId) return;
    detach();
    _turnsUser = userId;
    try {
      final sub = await api.watchMyTurns(userId, (rooms) {
        if (!setEquals(rooms, _myTurnRooms)) {
          _myTurnRooms = rooms;
          notifyListeners();
        }
      });
      if (_turnsUser != userId) {
        sub();
        return;
      }
      _turnsSub = sub;
    } catch (e) {
      debugPrint('matches:myTurns failed: $e');
    }
  }

  void detach() {
    _turnsSub?.call();
    _turnsSub = null;
    _turnsUser = null;
    for (final cancel in _roomSubs.values) {
      cancel();
    }
    _roomSubs.clear();
    _roomRefs.clear();
    _byId.clear();
    _idByCard.clear();
    _notedAt.clear();
    _hydrating.clear();
    _myTurnRooms = const {};
  }
}

/// Why a move bounced, for the screen to say so.
enum MoveRejection {
  stale,
  illegal,
  paused,
  network,

  /// Party games: the phase's clock ran out before the action landed.
  tooLate,

  /// Imposter: a clue the server will not take (too long, too many words, a
  /// link).
  badClue,

  /// Imposter: an empty or overlong guess.
  badGuess,

  /// Puzzle Race: the board sent as finished is not solved.
  notSolved,

  /// A turn by turn game's first move, refused because the DM already has
  /// as many of those going as it may (`TOO_MANY_GAMES`). Nothing was made.
  tooManyGames,

  /// A first move refused because the room's messages self-destruct.
  ephemeral;

  static MoveRejection fromCode(String code) => switch (code) {
    'STALE' => MoveRejection.stale,
    'ILLEGAL' || 'NOT_YOUR_TURN' || 'ALREADY_FINISHED' => MoveRejection.illegal,
    'PAUSED' => MoveRejection.paused,
    'TOO_LATE' => MoveRejection.tooLate,
    'BAD_CLUE' => MoveRejection.badClue,
    'BAD_GUESS' => MoveRejection.badGuess,
    'NOT_SOLVED' => MoveRejection.notSolved,
    'TOO_MANY_GAMES' => MoveRejection.tooManyGames,
    'EPHEMERAL_ROOM' => MoveRejection.ephemeral,
    _ => MoveRejection.network,
  };
}

/// A turn by turn game that does not exist yet: the opening board, drawn on
/// this phone, with the creator to move. Nothing reaches the server until
/// the first move is sent, which creates the game, plays the move and posts
/// its bubble in one go (`matches:startTurns`). Backing out sends nothing.
///
/// [seats] is creator first: seat 0 opens in every turn game. [rematchOf] is
/// the finished game this one plays again.
class TurnDraft {
  const TurnDraft({
    required this.roomId,
    required this.game,
    required this.seats,
    this.rematchOf,
  });

  final String roomId;
  final String game;
  final List<MatchSeat> seats;
  final String? rematchOf;

  /// The game as the screen draws it before it exists: active, seq 0, seat 0
  /// to move, no id and no card.
  ChatMatch toMatch() => ChatMatch(
    id: '',
    roomId: roomId,
    messageId: '',
    game: game,
    mode: MatchMode.async,
    status: MatchStatus.active,
    seats: seats,
    state: turnGameFor(game)?.initialEncoded(seats.length),
    seq: 0,
    turnSeat: 0,
    createdBy: seats.isEmpty ? '' : seats.first.userId,
    createdAt: DateTime.now(),
  );
}

/// One game's screen: its live row, the move in flight, and the heartbeat
/// that tells the server this player is at the board.
///
/// ## A game not started yet ([MatchController.draft])
///
/// A turn by turn game opens as a [TurnDraft]: the opening board is local,
/// a move is staged on it as usual, and [sendStaged] creates the game with
/// that move (`MatchesApi.startTurns`). From then on [matchId] is the new
/// game's and the controller watches it like any other. Until then there is
/// no subscription, no heartbeat, and nothing to resign.
///
/// ## Moves
///
/// A tap draws at once: the move is applied locally with the game's own rules
/// ([TurnGame.applyEncoded]) and shown while the server catches up. The
/// optimistic board is shown only while the server's `seq` is still the one
/// the move was made against; once the server moves past it — the move
/// landed, or somebody else's did — the server's board wins. A refusal snaps
/// back to the server board and reports [lastRejection].
///
/// A move whose reply was lost is resent with the same `clientMoveId`, which
/// the server answers as the success it was rather than applying twice.
///
/// ## Party games
///
/// No optimistic board: a party table cannot be predicted without secrets the
/// phone does not hold, so [act] sends the action and the screen shows it as
/// [pendingAction] (a bid button greyed, a vote ring half-drawn) until the
/// server's row moves past it. The same idempotency applies, on
/// `clientActionId`. The viewer's own hidden slice (their dice, their card)
/// comes from one extra live subscription, `matches:mySecret`, opened only
/// for a seated player of a party game and only while the screen is up.
///
/// Party phases end on the SERVER's clock, and a phone's clock can be seconds
/// off. [serverNow] corrects for that with an offset learned from the rows
/// themselves: every live change carries the server's `lastMoveAt`, stamped
/// a moment before the row reached us, so `lastMoveAt - received` is the
/// clock difference less the trip time. A countdown drawn from it errs a
/// fraction of a second long, never short, and never shows a turn as over
/// while the server still takes it.
///
/// ## Presence (live games)
///
/// While the screen is up and the app in the foreground, a `beat` every
/// [beatEvery]. Leaving the screen or backgrounding the app sends `away` at
/// once, which pauses the game for the others; coming back beats again,
/// which resumes it.
class MatchController extends ChangeNotifier with WidgetsBindingObserver {
  MatchController({
    required String matchId,
    required this.userId,
    ChatMatch? initial,
  }) : _matchId = matchId,
       _match = initial;

  /// A game that does not exist until its first move is sent.
  MatchController.draft({required TurnDraft draft, required this.userId})
    : _matchId = '',
      _draft = draft,
      _match = draft.toMatch();

  /// The game's id. Empty while [isDraft]; the created game's once the first
  /// move lands.
  String get matchId => _matchId;
  String _matchId;
  final String userId;

  TurnDraft? _draft;

  /// Not created yet: the board is local and Send makes the game.
  bool get isDraft => _draft != null;

  static const beatEvery = Duration(seconds: 10);

  MatchesApi get _api => MatchesStore.instance.api;

  ChatMatch? _match;
  void Function()? _sub;
  Timer? _beat;
  bool _foreground = true;
  bool _disposed = false;
  bool _gone = false;

  ({String move, int expectedSeq, String clientMoveId, String state})? _pending;
  MoveRejection? _lastRejection;
  int _rejections = 0;

  /// A turn by turn move made on the board but not sent yet: drawn, never
  /// posted, until [sendStaged]. Live games never stage.
  ({String move, int seq, String state})? _staged;

  ({String action, int expectedSeq})? _pendingAction;
  PartySecret? _secret;
  void Function()? _secretSub;
  bool _secretStarted = false;
  Duration _clockOffset = Duration.zero;
  int? _lastSeq;
  DateTime? _lastProgressAt;
  int? _lastProgress;

  /// The server's row, as last delivered.
  ChatMatch? get serverMatch => _match;

  /// What to draw: the server's row, or the optimistic position while a move
  /// of ours is in flight against it.
  ChatMatch? get match {
    final m = _match;
    final p = _pending;
    final st = _staged;
    if (m != null && p == null && st != null && m.seq == st.seq) {
      return m.withOptimistic(
        state: st.state,
        seq: st.seq + 1,
        lastMove: st.move,
      );
    }
    if (m == null || p == null || m.seq != p.expectedSeq) return m;
    return m.withOptimistic(
      state: p.state,
      seq: p.expectedSeq + 1,
      lastMove: p.move,
    );
  }

  bool get sending => _pending != null || _pendingAction != null;

  /// The staged move's token, while one waits for Send.
  String? get stagedMove {
    final st = _staged;
    final m = _match;
    return st != null && m != null && m.seq == st.seq ? st.move : null;
  }

  /// Puts [move] on the board without sending it: turn by turn games only,
  /// where a move is a message and deserves a second look. Ignored unless it
  /// is the viewer's turn and the rules take it.
  void stage(String move) {
    final m = _match;
    if (m == null || _pending != null || !m.isTurnOf(userId)) return;
    final game = turnGameFor(m.game);
    final state = m.state;
    if (game == null || state == null) return;
    try {
      _staged = (move: move, seq: m.seq, state: game.applyEncoded(state, move));
    } catch (_) {
      _reject(MoveRejection.illegal);
      return;
    }
    notifyListeners();
  }

  /// Takes the staged move back.
  void unstage() {
    if (_staged == null) return;
    _staged = null;
    notifyListeners();
  }

  /// Sends the staged move. True once the server has it; false when it was
  /// refused (and [lastRejection] says why) or there was nothing to send.
  Future<bool> sendStaged() async {
    final st = _staged;
    final m = _match;
    if (st == null || m == null || m.seq != st.seq) {
      _staged = null;
      notifyListeners();
      return false;
    }
    _staged = null;
    final draft = _draft;
    if (draft != null) return _startWith(draft, st.move, st.state);
    return play(st.move);
  }

  /// Creates the drafted game with its first [move] ([next] is the board it
  /// makes), then watches it. The optimistic board stays up meanwhile, the
  /// same way [play]'s does; a refusal snaps back to the opening board and
  /// reports why. Retried on a lost reply with the same id, which the server
  /// answers with the game the first send made.
  Future<bool> _startWith(TurnDraft draft, String move, String next) async {
    if (_pending != null) return false;
    final clientMoveId = 'mv_${DateTime.now().microsecondsSinceEpoch}_0';
    _pending = (
      move: move,
      expectedSeq: 0,
      clientMoveId: clientMoveId,
      state: next,
    );
    notifyListeners();
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await _api.startTurns(
          userId: userId,
          roomId: draft.roomId,
          game: draft.game,
          move: move,
          clientMoveId: clientMoveId,
          rematchOf: draft.rematchOf,
        );
        _matchId = res.matchId;
        _draft = null;
        // The subscription's first delivery (seq 1) clears [_pending].
        if (!_disposed) unawaited(_watch());
        return true;
      } catch (e) {
        final code = matchErrorCode(e);
        if (code == 'UNKNOWN' && attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
          if (_disposed) return false;
          continue;
        }
        _pending = null;
        _reject(MoveRejection.fromCode(code));
        return false;
      }
    }
    return false;
  }

  /// The party action in flight, until the server's row moves past the seq it
  /// was sent against.
  String? get pendingAction => _pendingAction?.action;

  /// The viewer's hidden slice of a party game, as JSON (their dice, their
  /// card). Null for a spectator, before it arrives, and for Puzzle Race.
  String? get secret => _secret?.secret;

  /// The `seq` [secret] was read at. Behind [match]'s seq for a moment after a
  /// change, while the secret's subscription catches up.
  int? get secretSeq => _secret?.seq;

  /// Now, on the server's clock (see the class doc).
  DateTime serverNow() => DateTime.now().add(_clockOffset);

  /// What is left of a phase ending at [deadline] (server ms), never
  /// negative. Frozen at the pause while the game is paused.
  Duration remaining(int? deadline) {
    if (deadline == null) return Duration.zero;
    final m = _match;
    final now = m != null && m.status == MatchStatus.paused && m.pausedAt != null
        ? m.pausedAt!
        : serverNow();
    final left = deadline - now.millisecondsSinceEpoch;
    return Duration(milliseconds: left < 0 ? 0 : left);
  }

  /// Why the last move bounced. Bumps [rejectionCount] each time, so a
  /// screen can shake once per refusal.
  MoveRejection? get lastRejection => _lastRejection;
  int get rejectionCount => _rejections;

  /// False until the first delivery.
  bool get loaded => _match != null;

  /// The game was deleted, or the viewer is no longer in the room.
  bool get gone => _gone;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    // A draft has nothing on the server to watch until its first move.
    if (_draft != null) return;
    await _watch();
  }

  Future<void> _watch() async {
    if (_disposed || _sub != null) return;
    try {
      final sub = await _api.watch(userId, matchId, (m) {
        if (_disposed) return;
        if (m == null) {
          _gone = true;
          _stopBeating();
          MatchesStore.instance.forget(matchId);
          notifyListeners();
          return;
        }
        _learnClock(m);
        _match = m;
        final p = _pending;
        if (p != null && m.seq > p.expectedSeq) _pending = null;
        final a = _pendingAction;
        if (a != null && m.seq > a.expectedSeq) _pendingAction = null;
        if (m.party && !_secretStarted && m.isSeated(userId)) {
          _secretStarted = true;
          unawaited(_watchSecret());
        }
        if (m.status.isOpen && m.mode == MatchMode.live) {
          _ensureBeating();
        } else {
          _stopBeating();
        }
        notifyListeners();
      }, onError: (e) => debugPrint('matches:get error: $e'));
      if (_disposed) {
        sub();
        return;
      }
      _sub = sub;
    } catch (e) {
      debugPrint('match watch failed: $e');
    }
  }

  /// Plays [move]. Ignored unless it is the viewer's turn and nothing else
  /// is in flight.
  /// True once the server has the move.
  Future<bool> play(String move) async {
    final m = _match;
    if (m == null || _pending != null || !m.isTurnOf(userId)) return false;
    // A draft's only move is the staged first one, through [sendStaged].
    if (_draft != null) return false;
    final game = turnGameFor(m.game);
    final state = m.state;
    if (game == null || state == null) return false;
    final String next;
    try {
      next = game.applyEncoded(state, move);
    } catch (_) {
      _reject(MoveRejection.illegal);
      return false;
    }
    final clientMoveId =
        'mv_${DateTime.now().microsecondsSinceEpoch}_${m.seq}';
    _pending = (
      move: move,
      expectedSeq: m.seq,
      clientMoveId: clientMoveId,
      state: next,
    );
    notifyListeners();
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _api.move(
          userId: userId,
          matchId: matchId,
          expectedSeq: m.seq,
          move: move,
          clientMoveId: clientMoveId,
        );
        // The subscription's echo clears [_pending]; until it lands the
        // optimistic board stays, which is the board the server now has.
        return true;
      } catch (e) {
        final code = matchErrorCode(e);
        if (code == 'UNKNOWN' && attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
          if (_disposed) return false;
          continue;
        }
        _pending = null;
        _forgetIfGone(code);
        _reject(MoveRejection.fromCode(code));
        return false;
      }
    }
    return false;
  }

  /// Folds a delivered row into the clock offset: only a row that CHANGED
  /// while we watched, since a first delivery's `lastMoveAt` may be minutes
  /// old and says nothing about the clocks.
  void _learnClock(ChatMatch m) {
    final before = _lastSeq;
    _lastSeq = m.seq;
    final at = m.lastMoveAt;
    if (before == null || m.seq == before || at == null) return;
    final offset = at.difference(DateTime.now());
    // Ten minutes apart is a row that was queued, not a clock: ignore it.
    if (offset.abs() > const Duration(minutes: 10)) return;
    _clockOffset = offset;
  }

  Future<void> _watchSecret() async {
    try {
      final sub = await _api.watchSecret(userId, matchId, (s) {
        if (_disposed) return;
        _secret = s;
        notifyListeners();
      }, onError: (e) => debugPrint('matches:mySecret error: $e'));
      if (_disposed) {
        sub();
        return;
      }
      _secretSub = sub;
    } catch (e) {
      debugPrint('match secret watch failed: $e');
    }
  }

  /// Sends one party action, and says whether the server took it. Ignored
  /// (false) while another is in flight, and for a game the viewer is not
  /// playing. A screen clears its text field only on true.
  Future<bool> act(String action) async {
    final m = _match;
    if (m == null ||
        !m.party ||
        _pendingAction != null ||
        m.status != MatchStatus.active ||
        !m.isSeated(userId)) {
      return false;
    }
    final expected = m.seq;
    _pendingAction = (action: action, expectedSeq: expected);
    notifyListeners();
    final seq = await _send(action, expected);
    // Refused, or taken without a change (a second `seen`): no echo is coming
    // to clear it. Taken with a change: the echo clears it, unless it has
    // already landed.
    if (_pendingAction?.expectedSeq == expected &&
        (seq == null || seq <= expected || (_match?.seq ?? 0) > expected)) {
      _pendingAction = null;
    }
    if (!_disposed) notifyListeners();
    return seq != null;
  }

  /// Puzzle Race's progress bar, sent at most every
  /// [progressEvery] and only when it moved. Fire and forget: a dropped tick
  /// is the next tick's job, and it never blocks a finish.
  void reportProgress(int percent) {
    final m = _match;
    if (m == null || !m.party || m.status != MatchStatus.active) return;
    if (!m.isSeated(userId) || _pendingAction != null) return;
    final pct = percent.clamp(0, 99);
    final now = DateTime.now();
    final last = _lastProgressAt;
    if (pct == _lastProgress) return;
    if (last != null && now.difference(last) < progressEvery) return;
    _lastProgressAt = now;
    _lastProgress = pct;
    unawaited(_send('progress:$pct', m.seq, quiet: true));
  }

  /// The server's progress throttle (`PROGRESS_EVERY_MS`), plus a little so a
  /// tick never lands just inside it and is dropped.
  static const progressEvery = Duration(milliseconds: 2100);

  /// One action to the server, retried on a lost reply with the same id.
  /// The seq the game stands at after it, or null when it was refused.
  Future<int?> _send(String action, int expected, {bool quiet = false}) async {
    final id = 'pa_${DateTime.now().microsecondsSinceEpoch}_$expected';
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await _api.partyAct(
          userId: userId,
          matchId: matchId,
          expectedSeq: expected,
          action: action,
          clientActionId: id,
        );
        return res.seq;
      } catch (e) {
        final code = matchErrorCode(e);
        if (code == 'UNKNOWN' && attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
          if (_disposed) return null;
          continue;
        }
        _forgetIfGone(code);
        if (!quiet) _reject(MoveRejection.fromCode(code));
        return null;
      }
    }
    return null;
  }

  /// A refusal that says the game itself is gone: evict it from the room's
  /// banner and cards at once rather than wait for the room's next delivery.
  void _forgetIfGone(String code) {
    if (code == 'NO_MATCH') MatchesStore.instance.forget(matchId);
  }

  void _reject(MoveRejection why) {
    _lastRejection = why;
    _rejections++;
    if (!_disposed) notifyListeners();
  }

  void _ensureBeating() {
    if (_beat != null || !_foreground || _disposed) return;
    unawaited(_api.beat(userId, matchId).catchError((_) {}));
    _beat = Timer.periodic(beatEvery, (_) {
      unawaited(_api.beat(userId, matchId).catchError((_) {}));
    });
  }

  void _stopBeating() {
    _beat?.cancel();
    _beat = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final m = _match;
    final live = m != null && m.mode == MatchMode.live && m.status.isOpen;
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (live) _ensureBeating();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_foreground) return;
      _foreground = false;
      _stopBeating();
      if (live) unawaited(_api.away(userId, matchId).catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stopBeating();
    _sub?.call();
    _secretSub?.call();
    final m = _match;
    if (m != null && m.mode == MatchMode.live && m.status.isOpen) {
      unawaited(_api.away(userId, matchId).catchError((_) {}));
    }
    super.dispose();
  }
}
