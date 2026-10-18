/// The party games' public and private views, parsed.
///
/// There is no Dart mirror of the party rules (unlike the turn games): what a
/// party board shows depends on secrets the phone never holds, so the client
/// draws what the server says and nothing more. These classes are just that
/// JSON with types on it. Shapes are `publicView` / `privateView` in
/// `backend/convex/partyGames/{liarsDice,imposter,race}.ts`; a field this
/// build does not know is ignored, and a field it expects but does not get
/// reads as empty, so a newer server never crashes an older card.
///
/// Parsing is cached per state string ([partyViewOf]): a card, the banner and
/// the screen all ask for the same view of the same row on every rebuild, and
/// the state string only changes when the game does.
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:ui' show Locale;

import '../models/chat_match.dart';

/// The view of [m]'s state, or null when it has none (a lobby) or is not a
/// party game this build knows.
PartyView? partyViewOf(ChatMatch m) {
  final raw = m.state;
  if (!m.party || raw == null || raw.isEmpty) return null;
  final hit = _cache.remove(raw);
  if (hit != null) {
    _cache[raw] = hit;
    return hit;
  }
  final view = _parse(m.game, raw);
  if (view != null) {
    _cache[raw] = view;
    if (_cache.length > 48) _cache.remove(_cache.keys.first);
  }
  return view;
}

final LinkedHashMap<String, PartyView> _cache = LinkedHashMap();

PartyView? _parse(String game, String raw) {
  final Object? j;
  try {
    j = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final map = j.cast<String, dynamic>();
  return switch (game) {
    'liarsdice' => LiarsDiceView.fromJson(map),
    'imposter' => ImposterView.fromJson(map),
    'race' => RaceView.fromJson(map),
    _ => null,
  };
}

/// What every party view has: a phase, and when it ends on its own.
sealed class PartyView {
  const PartyView({required this.phase, this.deadline});

  final String phase;

  /// Server time, ms since epoch. Null when nothing is timed (it is over).
  final int? deadline;

  bool get over => phase == 'over';
}

// ── Liar's Dice ─────────────────────────────────────────────────────────────

class DiceBid {
  const DiceBid({
    required this.seat,
    required this.qty,
    required this.face,
    this.auto = false,
  });

  final int seat;
  final int qty;
  final int face;

  /// Played by the timer, not the player.
  final bool auto;

  /// Whether [qty]×[face] is strictly higher than this bid. Mirrors `raises`
  /// in liarsDice.ts: a bigger quantity, or the same quantity on a higher
  /// face, with Perudo's price for wild 1s: half (rounded up) to bid onto
  /// them, more of them from 1s to 1s, double plus one to leave them.
  bool raisedBy(int qty, int face) {
    if (this.face == 1 && face == 1) return qty > this.qty;
    if (face == 1) return qty >= (this.qty + 1) ~/ 2;
    if (this.face == 1) return qty >= this.qty * 2 + 1;
    return qty > this.qty || (qty == this.qty && face > this.face);
  }

  /// The fewest dice any raise of this bid can name, on any face.
  int get minRaiseQty => face == 1 ? qty + 1 : (qty + 1) ~/ 2;

  static DiceBid? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return DiceBid(
      seat: _int(raw['seat']),
      qty: _int(raw['qty']),
      face: _int(raw['face']),
      auto: raw['auto'] == true,
    );
  }
}

/// The last call, and what the dice said.
class DiceReveal {
  const DiceReveal({
    required this.round,
    required this.dice,
    required this.bid,
    required this.caller,
    required this.count,
    required this.holds,
    required this.loser,
    required this.auto,
  });

  final int round;
  final List<List<int>> dice;
  final DiceBid bid;
  final int caller;
  final int count;
  final bool holds;
  final int loser;
  final bool auto;

  static DiceReveal? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final bid = DiceBid.fromJson(raw['bid']);
    if (bid == null) return null;
    return DiceReveal(
      round: _int(raw['round']),
      dice: _intLists(raw['dice']),
      bid: bid,
      caller: _int(raw['caller']),
      count: _int(raw['count']),
      holds: raw['holds'] == true,
      loser: _int(raw['loser']),
      auto: raw['auto'] == true,
    );
  }
}

/// Whether a die showing [die] counts toward a bid on [face]: its own face,
/// or a wild 1 unless the bid is on 1s. Mirrors `countFace` in liarsDice.ts.
bool diceCounts(int die, int face) => die == face || (face != 1 && die == 1);

class LiarsDiceView extends PartyView {
  const LiarsDiceView({
    required super.phase,
    super.deadline,
    required this.round,
    this.turn,
    this.bid,
    required this.bids,
    required this.counts,
    required this.left,
    required this.totalDice,
    this.reveal,
    this.winner,
    this.dice,
  });

  final int round;
  final int? turn;

  /// The standing bid, the last of [bids].
  final DiceBid? bid;
  final List<DiceBid> bids;

  /// Dice each seat still holds. 0 is out.
  final List<int> counts;
  final List<bool> left;
  final int totalDice;

  /// The last call. Stays set into the next round, which is what lets the
  /// board show it for a few seconds while the next turn's clock runs.
  final DiceReveal? reveal;
  final int? winner;

  /// Every seat's dice, once it is over.
  final List<List<int>>? dice;

  bool isOut(int seat) => seat >= counts.length || counts[seat] <= 0;

  static LiarsDiceView fromJson(Map<String, dynamic> j) => LiarsDiceView(
    phase: j['phase']?.toString() ?? 'bidding',
    deadline: _intOrNull(j['deadline']),
    round: _int(j['round']),
    turn: _intOrNull(j['turn']),
    bid: DiceBid.fromJson(j['bid']),
    bids: [
      for (final b in (j['bids'] as List?) ?? const [])
        ?DiceBid.fromJson(b),
    ],
    counts: _ints(j['counts']),
    left: _bools(j['left']),
    totalDice: _int(j['totalDice']),
    reveal: DiceReveal.fromJson(j['reveal']),
    winner: _intOrNull(j['winner']),
    dice: j['dice'] is List ? _intLists(j['dice']) : null,
  );
}

/// Your own dice this round, sorted.
class LiarsDiceSecret {
  const LiarsDiceSecret({required this.round, required this.dice});

  final int round;
  final List<int> dice;

  static LiarsDiceSecret? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return LiarsDiceSecret(round: _int(raw['round']), dice: _ints(raw['dice']));
  }
}

// ── Imposter ────────────────────────────────────────────────────────────────

class ImposterClue {
  const ImposterClue({
    required this.seat,
    required this.text,
    this.passed = false,
  });

  final int seat;
  final String text;

  /// Their time ran out. [text] is then the server's placeholder, never shown.
  final bool passed;
}

/// The word, once the game is over.
class ImposterWord {
  const ImposterWord({
    required this.id,
    required this.category,
    required this.names,
    required this.categoryNames,
  });

  final String id;
  final String category;
  final Map<String, String> names;
  final Map<String, String> categoryNames;
}

class ImposterView extends PartyView {
  const ImposterView({
    required super.phase,
    super.deadline,
    required this.voice,
    required this.order,
    this.turn,
    required this.clues,
    required this.seen,
    required this.voted,
    required this.left,
    this.votes,
    this.voteCounts,
    this.skips,
    this.accused,
    this.result,
    this.reason,
    this.imposter,
    this.word,
    this.guess,
    this.guessCorrect,
  });

  final bool voice;

  /// Clue order, every seat.
  final List<int> order;

  /// Who is giving their clue, in `clues`.
  final int? turn;
  final List<ImposterClue> clues;
  final List<bool> seen;

  /// WHO has voted, never for whom, while the vote is open.
  final List<bool> voted;
  final List<bool> left;

  /// Per seat: the seat voted for, -1 for a skip, null for no vote. Published
  /// once the vote is counted.
  final List<int?>? votes;
  final List<int>? voteCounts;
  final int? skips;
  final int? accused;

  /// "imposter" | "crew".
  final String? result;
  final String? reason;

  /// Revealed once it is over.
  final int? imposter;
  final ImposterWord? word;
  final String? guess;
  final bool? guessCorrect;

  /// The seats still in the game, in clue order.
  List<int> get living => [
    for (final s in order)
      if (!(s < left.length && left[s])) s,
  ];

  static ImposterView fromJson(Map<String, dynamic> j) {
    final w = j['word'];
    return ImposterView(
      phase: j['phase']?.toString() ?? 'reveal',
      deadline: _intOrNull(j['deadline']),
      voice: j['voice'] == true,
      order: _ints(j['order']),
      turn: _intOrNull(j['turn']),
      clues: [
        for (final c in (j['clues'] as List?) ?? const [])
          if (c is Map)
            ImposterClue(
              seat: _int(c['seat']),
              text: c['text']?.toString() ?? '',
              passed: c['passed'] == true,
            ),
      ],
      seen: _bools(j['seen']),
      voted: _bools(j['voted']),
      left: _bools(j['left']),
      votes: j['votes'] is List
          ? [
              for (final v in j['votes'] as List)
                v == 'skip' ? -1 : (v is num ? v.toInt() : null),
            ]
          : null,
      voteCounts: j['voteCounts'] is List ? _ints(j['voteCounts']) : null,
      skips: _intOrNull(j['skips']),
      accused: _intOrNull(j['accused']),
      result: j['result']?.toString(),
      reason: j['reason']?.toString(),
      imposter: _intOrNull(j['imposter']),
      word: w is Map
          ? ImposterWord(
              id: w['id']?.toString() ?? '',
              category: w['category']?.toString() ?? '',
              names: _strings(w['names']),
              categoryNames: _strings(w['categoryNames']),
            )
          : null,
      guess: j['guess']?.toString(),
      guessCorrect: j['guessCorrect'] is bool ? j['guessCorrect'] as bool : null,
    );
  }
}

/// Your card: the word (crew) or only its category (the imposter), and the
/// ballot you have cast.
class ImposterSecret {
  const ImposterSecret({
    required this.imposter,
    required this.category,
    required this.categoryNames,
    this.names = const {},
    this.myVote,
  });

  final bool imposter;
  final String category;
  final Map<String, String> categoryNames;

  /// The word in every locale. Empty for the imposter.
  final Map<String, String> names;

  /// The seat voted for, -1 for a skip, null for none yet.
  final int? myVote;

  static ImposterSecret? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final v = raw['myVote'];
    return ImposterSecret(
      imposter: raw['role'] == 'imposter',
      category: raw['category']?.toString() ?? '',
      categoryNames: _strings(raw['categoryNames']),
      names: _strings(raw['names']),
      myVote: v == 'skip' ? -1 : (v is num ? v.toInt() : null),
    );
  }
}

/// [names] in the viewer's language: `pt_BR` reads `pt-br`, then the bare
/// language, then English, then whatever there is. The word bank's keys are
/// `en, tr, ar, es, fr, hi, ja, ko, pt-br, pt, sv, zh`.
String localName(Map<String, String> names, Locale locale) {
  if (names.isEmpty) return '';
  final lang = locale.languageCode.toLowerCase();
  final country = locale.countryCode?.toLowerCase();
  if (country != null) {
    final exact = names['$lang-$country'];
    if (exact != null && exact.isNotEmpty) return exact;
  }
  final bare = names[lang];
  if (bare != null && bare.isNotEmpty) return bare;
  return names['en'] ?? names.values.first;
}

// ── Puzzle Race ─────────────────────────────────────────────────────────────

class RacePlayer {
  const RacePlayer({
    required this.progress,
    this.rank,
    this.durationMs,
    this.left = false,
  });

  /// 0..100. Sits at 99 or below until the server accepts a finish.
  final int progress;

  /// 1-based finishing place.
  final int? rank;
  final int? durationMs;
  final bool left;
}

class RaceView extends PartyView {
  const RaceView({
    required super.phase,
    super.deadline,
    required this.kind,
    required this.puzzle,
    required this.startedAt,
    required this.players,
    this.reason,
  });

  /// `queens` | `tango` | `sudoku` | `zip`.
  final String kind;

  /// The board, in the daily game's own JSON shape.
  final Map<String, dynamic> puzzle;
  final int startedAt;
  final List<RacePlayer> players;
  final String? reason;

  int get finished => players.where((p) => p.rank != null).length;

  static RaceView fromJson(Map<String, dynamic> j) {
    final puzzle = j['puzzle'];
    return RaceView(
      phase: j['phase']?.toString() ?? 'racing',
      deadline: _intOrNull(j['deadline']),
      kind: j['kind']?.toString() ?? '',
      puzzle: puzzle is Map ? puzzle.cast<String, dynamic>() : const {},
      startedAt: _int(j['startedAt']),
      players: [
        for (final p in (j['players'] as List?) ?? const [])
          if (p is Map)
            RacePlayer(
              progress: _int(p['progress']),
              rank: _intOrNull(p['rank']),
              durationMs: _intOrNull(p['durationMs']),
              left: p['left'] == true,
            ),
      ],
      reason: j['reason']?.toString(),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

int _int(Object? v) => v is num ? v.toInt() : 0;

int? _intOrNull(Object? v) => v is num ? v.toInt() : null;

List<int> _ints(Object? raw) => [
  for (final v in (raw as List?) ?? const []) _int(v),
];

List<bool> _bools(Object? raw) => [
  for (final v in (raw as List?) ?? const []) v == true,
];

List<List<int>> _intLists(Object? raw) => [
  for (final v in (raw as List?) ?? const []) _ints(v is List ? v : null),
];

Map<String, String> _strings(Object? raw) => raw is Map
    ? {
        for (final e in raw.entries)
          if (e.value != null) e.key.toString(): e.value.toString(),
      }
    : const {};
