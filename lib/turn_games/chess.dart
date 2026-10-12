/// Chess, mirrored from `backend/convex/turnGames/chess.ts`.
///
/// The wire state is `<FEN>|<history>`, exactly as the server writes it: the
/// FEN as chess.js 1.4.0 emits it (the en passant square only when a legal en
/// passant capture exists), then one 5-char hash per earlier position since
/// the last capture or pawn move, which is all threefold repetition needs.
/// See the TS module for why that is enough and why it stays small.
///
/// A move is a UCI token (`e2e4`, `e7e8q`) on the wire and an int here, laid
/// out so that sorting the ints sorts the tokens: [legalMoves] comes out in
/// the server's order with no string compare.
///
/// Two rule sets over the same [ChessState], both replaying
/// `test/fixtures/turn_games/chess.json`:
///
///  * [chessRules], the rules of record: move generation, check, mate,
///    stalemate and insufficient material come from the `chess` package
///    (pub.dev, BSD-2/MIT), a port of the chess.js the server runs. Boards and
///    the optimistic wire view use this one.
///  * [chessEngineRules], a lean 0x88 generator on plain typed arrays that
///    the bot searches with. The package builds an object per move and
///    re-generates the move list for every check test, which measured roughly
///    an order of magnitude too slow for a search on a phone. Plain arrays,
///    not 64-bit bitboards: Flutter web's bitwise operators are 32-bit. It is
///    checked by perft (`test/turn_games/chess_test.dart`) as well as by the
///    fixtures.
library;

import 'dart:typed_data';

import 'package:chess/chess.dart' as pkg;

import 'turn_rules.dart';

// ── Pieces and squares ──────────────────────────────────────────────────────

/// Piece codes as [ChessState.pieceAt] returns them: the type, plus
/// [chessBlack] for a black piece. 0 is an empty square.
const int chessPawn = 1;
const int chessKnight = 2;
const int chessBishop = 3;
const int chessRook = 4;
const int chessQueen = 5;
const int chessKing = 6;
const int chessBlack = 8;

/// Halfmove clock at which the game is drawn.
const int chessFiftyMovePlies = 100;

const String _initialFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const String _letters = '.pnbrqk';

/// 0x88 board index, `a8 = 0`, `h1 = 119`, as chess.js and the package use.
/// `sq64` throughout the public API is row-major from a8: `row * 8 + col`,
/// row 0 is rank 8.
int _to88(int sq64) => ((sq64 >> 3) << 4) | (sq64 & 7);
int _to64(int sq88) => ((sq88 >> 4) << 3) | (sq88 & 7);

/// "e4" for a board square, `sq64` as above.
String chessSquareName(int sq64) =>
    '${String.fromCharCode(0x61 + (sq64 & 7))}${8 - (sq64 >> 3)}';

String _name88(int sq) => chessSquareName(_to64(sq));

// ── Moves ───────────────────────────────────────────────────────────────────

/// Promotion slot in a move int, in token-sort order: none, b, n, q, r.
const List<int> _promoTypes = [0, chessBishop, chessKnight, chessQueen, chessRook];
const String _promoLetters = '.bnqr';

/// A move as an int: from-file, from-rank, to-file, to-rank and the
/// promotion slot, three bits each, most significant first. Each field sorts
/// the way its character does in the UCI token, so the ints sort like the
/// tokens.
int _move(int from88, int to88, int promo) =>
    (from88 & 7) << 12 |
    (7 - (from88 >> 4)) << 9 |
    (to88 & 7) << 6 |
    (7 - (to88 >> 4)) << 3 |
    promo;

int _from88(int m) => (7 - ((m >> 9) & 7)) << 4 | ((m >> 12) & 7);
int _to88m(int m) => (7 - ((m >> 3) & 7)) << 4 | ((m >> 6) & 7);

/// The move's start square, `sq64`.
int chessMoveFrom(int move) => _to64(_from88(move));

/// The move's landing square, `sq64`.
int chessMoveTo(int move) => _to64(_to88m(move));

/// The promoted-to piece type ([chessQueen] etc.), or 0.
int chessMovePromotion(int move) => _promoTypes[move & 7];

/// A move from board squares and an optional promotion piece type.
int chessMove(int from64, int to64, [int promotion = 0]) {
  final slot = promotion == 0 ? 0 : _promoTypes.indexOf(promotion);
  if (slot < 0) throw ArgumentError.value(promotion, 'promotion');
  return _move(_to88(from64), _to88(to64), slot);
}

String _uci(int m) {
  final p = m & 7;
  return '${_name88(_from88(m))}${_name88(_to88m(m))}'
      '${p == 0 ? '' : _promoLetters[p]}';
}

// ── Position hashing ────────────────────────────────────────────────────────

const String _hashChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
const int _hashMod = 1000000007;
const int _hashLen = 5;

/// The TS `positionHash`: a polynomial hash of the FEN's first four fields,
/// mod a prime under 2^30. Every intermediate stays under 2^38, so this is
/// exact on the web, where Dart ints are doubles.
int _hashKey(String key) {
  var h = 0;
  for (var i = 0; i < key.length; i++) {
    h = (h * 131 + key.codeUnitAt(i)) % _hashMod;
  }
  return h;
}

String _hashText(int h) => String.fromCharCodes([
  for (var shift = 24; shift >= 0; shift -= 6)
    _hashChars.codeUnitAt((h >> shift) & 63),
]);

// ── Attacks and move generation (the lean engine) ───────────────────────────

const List<int> _knightSteps = [-33, -31, -18, -14, 14, 18, 31, 33];
const List<int> _kingSteps = [-17, -16, -15, -1, 1, 15, 16, 17];
const List<int> _diagonals = [-17, -15, 15, 17];
const List<int> _lines = [-16, -1, 1, 16];

/// Whether [by] attacks [sq] on board [b].
bool _attacked(Int8List b, int sq, int by) {
  final c = by << 3;
  // A white pawn attacks up the board (towards a8), so it sits below.
  if (by == 0) {
    var t = sq + 15;
    if (t & 0x88 == 0 && b[t] == chessPawn) return true;
    t = sq + 17;
    if (t & 0x88 == 0 && b[t] == chessPawn) return true;
  } else {
    var t = sq - 15;
    if (t & 0x88 == 0 && b[t] == chessPawn | chessBlack) return true;
    t = sq - 17;
    if (t & 0x88 == 0 && b[t] == chessPawn | chessBlack) return true;
  }
  final knight = chessKnight | c;
  for (final d in _knightSteps) {
    final t = sq + d;
    if (t & 0x88 == 0 && b[t] == knight) return true;
  }
  final king = chessKing | c;
  for (final d in _kingSteps) {
    final t = sq + d;
    if (t & 0x88 == 0 && b[t] == king) return true;
  }
  final queen = chessQueen | c;
  final bishop = chessBishop | c;
  for (final d in _diagonals) {
    var t = sq + d;
    while (t & 0x88 == 0) {
      final p = b[t];
      if (p != 0) {
        if (p == bishop || p == queen) return true;
        break;
      }
      t += d;
    }
  }
  final rook = chessRook | c;
  for (final d in _lines) {
    var t = sq + d;
    while (t & 0x88 == 0) {
      final p = b[t];
      if (p != 0) {
        if (p == rook || p == queen) return true;
        break;
      }
      t += d;
    }
  }
  return false;
}

/// Adds [us]'s pseudo-legal moves on [b] to [out] as move ints. With
/// [noisy] only captures and queen promotions, for the capture search.
void _pseudo(
  Int8List b,
  int us,
  int castling,
  int ep,
  List<int> out, {
  bool noisy = false,
}) {
  final dir = us == 0 ? -16 : 16;
  final startRow = us == 0 ? 6 : 1;
  final lastRow = us == 0 ? 0 : 7;
  for (var sq = 0; sq < 120; sq++) {
    if (sq & 0x88 != 0) {
      sq += 7;
      continue;
    }
    final p = b[sq];
    if (p == 0 || p >> 3 != us) continue;
    final type = p & 7;
    if (type == chessPawn) {
      final t = sq + dir;
      final promotes = t >> 4 == lastRow;
      if (b[t] == 0) {
        if (promotes) {
          if (noisy) {
            out.add(_move(sq, t, 3));
          } else {
            for (var k = 1; k <= 4; k++) {
              out.add(_move(sq, t, k));
            }
          }
        } else if (!noisy) {
          out.add(_move(sq, t, 0));
          if (sq >> 4 == startRow && b[t + dir] == 0) {
            out.add(_move(sq, t + dir, 0));
          }
        }
      }
      for (final side in const [-1, 1]) {
        final x = t + side;
        if (x & 0x88 != 0) continue;
        final q = b[x];
        if (q != 0 && q >> 3 != us) {
          if (promotes) {
            if (noisy) {
              out.add(_move(sq, x, 3));
            } else {
              for (var k = 1; k <= 4; k++) {
                out.add(_move(sq, x, k));
              }
            }
          } else {
            out.add(_move(sq, x, 0));
          }
        } else if (x == ep) {
          out.add(_move(sq, x, 0));
        }
      }
      continue;
    }
    if (type == chessKnight || type == chessKing) {
      for (final d in type == chessKnight ? _knightSteps : _kingSteps) {
        final t = sq + d;
        if (t & 0x88 != 0) continue;
        final q = b[t];
        if (q == 0 ? !noisy : q >> 3 != us) out.add(_move(sq, t, 0));
      }
      continue;
    }
    for (final d in type == chessBishop
        ? _diagonals
        : type == chessRook
        ? _lines
        : _kingSteps) {
      var t = sq + d;
      while (t & 0x88 == 0) {
        final q = b[t];
        if (q == 0) {
          if (!noisy) out.add(_move(sq, t, 0));
        } else {
          if (q >> 3 != us) out.add(_move(sq, t, 0));
          break;
        }
        t += d;
      }
    }
  }
  if (noisy) return;
  // Castling: the rights imply king and rook are home (apply and decode both
  // keep that true). The king may not start in, pass through or land in
  // check, which the landing test below repeats, as chess.js does.
  final them = 1 - us;
  final e = us == 0 ? 116 : 4;
  final kBit = us == 0 ? 1 : 4;
  final qBit = us == 0 ? 2 : 8;
  if (castling & kBit != 0 &&
      b[e + 1] == 0 &&
      b[e + 2] == 0 &&
      !_attacked(b, e, them) &&
      !_attacked(b, e + 1, them) &&
      !_attacked(b, e + 2, them)) {
    out.add(_move(e, e + 2, 0));
  }
  if (castling & qBit != 0 &&
      b[e - 1] == 0 &&
      b[e - 2] == 0 &&
      b[e - 3] == 0 &&
      !_attacked(b, e, them) &&
      !_attacked(b, e - 1, them) &&
      !_attacked(b, e - 2, them)) {
    out.add(_move(e, e - 2, 0));
  }
}

/// Plays [m] for [us] on [b] in place: the capture, en passant's pawn,
/// castling's rook and promotion. Returns the en passant victim's square,
/// or -1, for an undo.
int _play(Int8List b, int m, int us) {
  final from = _from88(m);
  final to = _to88m(m);
  final p = b[from];
  final type = p & 7;
  var epVictim = -1;
  if (type == chessPawn && (from & 7) != (to & 7) && b[to] == 0) {
    epVictim = to + (us == 0 ? 16 : -16);
    b[epVictim] = 0;
  } else if (type == chessKing && (to - from == 2 || from - to == 2)) {
    final rookFrom = to > from ? from + 3 : from - 4;
    final rookTo = to > from ? from + 1 : from - 1;
    b[rookTo] = b[rookFrom];
    b[rookFrom] = 0;
  }
  final promo = m & 7;
  b[to] = promo == 0 ? p : _promoTypes[promo] | us << 3;
  b[from] = 0;
  return epVictim;
}

/// Takes back [_play] of [m] by [us], given what stood on the landing square
/// and the en passant victim's square [_play] returned.
void _unplay(Int8List b, int m, int us, int moved, int captured, int epVictim) {
  final from = _from88(m);
  final to = _to88m(m);
  b[from] = moved;
  b[to] = captured;
  if (epVictim >= 0) {
    b[epVictim] = chessPawn | (1 - us) << 3;
  } else if (moved & 7 == chessKing && (to - from == 2 || from - to == 2)) {
    final rookFrom = to > from ? from + 3 : from - 4;
    final rookTo = to > from ? from + 1 : from - 1;
    b[rookFrom] = b[rookTo];
    b[rookTo] = 0;
  }
}

/// One scratch board per isolate (each isolate has its own statics), so a
/// legality test never allocates.
final Int8List _scratch = Int8List(128);

/// Whether [m] keeps [us]'s king out of check. Plays it on [b] and takes it
/// back, so [b] must be a board nobody else is reading: [_scratch].
bool _legalInPlace(Int8List b, int m, int us, int kingSq) {
  final from = _from88(m);
  final to = _to88m(m);
  final moved = b[from];
  final captured = b[to];
  final epVictim = _play(b, m, us);
  final ok = !_attacked(b, from == kingSq ? to : kingSq, 1 - us);
  _unplay(b, m, us, moved, captured, epVictim);
  return ok;
}

bool _legalOn(Int8List b, int m, int us, int kingSq) {
  _scratch.setRange(0, 128, b);
  return _legalInPlace(_scratch, m, us, kingSq);
}

/// Whether [side], to move, has a legal en passant capture onto [ep]: the
/// chess.js `fen()` test for writing the square at all.
bool _epCapturable(Int8List b, int ep, int side, int kingSq) {
  final pushed = ep + (side == 0 ? 16 : -16);
  final pawn = chessPawn | side << 3;
  for (final x in [pushed + 1, pushed - 1]) {
    if (x & 0x88 != 0 || b[x] != pawn) continue;
    if (_legalOn(b, _move(x, ep, 0), side, kingSq)) return true;
  }
  return false;
}

int _findKing(Int8List b, int side) {
  final k = chessKing | side << 3;
  for (var sq = 0; sq < 120; sq++) {
    if (sq & 0x88 == 0 && b[sq] == k) return sq;
  }
  return -1;
}

/// chess.js `isInsufficientMaterial`, square for square: bare kings, a lone
/// minor piece, or any number of bishops all on one colour.
bool _insufficient(Int8List b) {
  var pieces = 0;
  var bishops = 0;
  var knights = 0;
  var light = 0;
  for (var sq = 0; sq < 120; sq++) {
    if (sq & 0x88 != 0) {
      sq += 7;
      continue;
    }
    final p = b[sq];
    if (p == 0) continue;
    pieces++;
    final t = p & 7;
    if (t == chessBishop) {
      bishops++;
      if (((sq >> 4) + (sq & 7)) & 1 == 0) light++;
    } else if (t == chessKnight) {
      knights++;
    }
  }
  if (pieces == 2) return true;
  if (pieces == 3 && (bishops == 1 || knights == 1)) return true;
  if (pieces == bishops + 2) return light == 0 || light == bishops;
  return false;
}

// ── State ───────────────────────────────────────────────────────────────────

/// A decoded position. Immutable apart from caches of things it already
/// determines (its FEN, legal moves, hash, outcome), filled on first use.
class ChessState {
  ChessState._(
    this._board,
    this.turn,
    this.castling,
    this._ep,
    this.halfmove,
    this.fullmove,
    this.history,
    this._kings, [
    this._fen,
  ]);

  final Int8List _board;

  /// Seat to move: 0 white, 1 black.
  final int turn;

  /// Castling rights: 1 white short, 2 white long, 4 black short, 8 black long.
  final int castling;

  /// En passant target, 0x88, or -1. Only set when the capture is legal.
  final int _ep;

  final int halfmove;
  final int fullmove;

  /// Hashes of the earlier positions since the clock last reset, oldest first.
  final List<int> history;

  /// King squares, 0x88, white then black.
  final List<int> _kings;

  String? _fen;
  int? _hash;
  List<int>? _moves;
  bool? _check;
  Object? _outcome;
  pkg.Chess? _record;

  /// The piece on [sq64] (see the codes at the top of this file), or 0.
  int pieceAt(int sq64) => _board[_to88(sq64)];

  /// The [chessKing] of [side], as `sq64`.
  int kingSquare(int side) => _to64(_kings[side]);

  /// The en passant target as `sq64`, or null.
  int? get enPassant => _ep < 0 ? null : _to64(_ep);

  /// Whether the side to move is in check.
  bool get inCheck =>
      _check ??= _attacked(_board, _kings[turn], 1 - turn);

  String get fen => _fen ??= '${_key()} $halfmove $fullmove';

  /// The repetition key: placement, side, castling, en passant.
  String _key() {
    final out = StringBuffer();
    for (var row = 0; row < 8; row++) {
      var empty = 0;
      for (var col = 0; col < 8; col++) {
        final p = _board[row << 4 | col];
        if (p == 0) {
          empty++;
          continue;
        }
        if (empty > 0) out.write(empty);
        empty = 0;
        final l = _letters[p & 7];
        out.write(p >> 3 == 0 ? l.toUpperCase() : l);
      }
      if (empty > 0) out.write(empty);
      if (row < 7) out.write('/');
    }
    out.write(turn == 0 ? ' w ' : ' b ');
    if (castling == 0) {
      out.write('-');
    } else {
      if (castling & 1 != 0) out.write('K');
      if (castling & 2 != 0) out.write('Q');
      if (castling & 4 != 0) out.write('k');
      if (castling & 8 != 0) out.write('q');
    }
    out.write(' ');
    out.write(_ep < 0 ? '-' : _name88(_ep));
    return out.toString();
  }

  /// [_hashKey] of [_key], streamed char by char from the board: the bot
  /// needs one per searched node, and building the string was a third of
  /// the cost of a node. [_key] stays the readable definition; the tests
  /// hold the two to the same answer.
  int get _positionHash {
    final cached = _hash;
    if (cached != null) return cached;
    var h = 0;
    for (var row = 0; row < 8; row++) {
      var empty = 0;
      for (var col = 0; col < 8; col++) {
        final p = _board[row << 4 | col];
        if (p == 0) {
          empty++;
          continue;
        }
        if (empty > 0) h = (h * 131 + 0x30 + empty) % _hashMod;
        empty = 0;
        final l = _letters.codeUnitAt(p & 7);
        h = (h * 131 + (p >> 3 == 0 ? l - 0x20 : l)) % _hashMod;
      }
      if (empty > 0) h = (h * 131 + 0x30 + empty) % _hashMod;
      if (row < 7) h = (h * 131 + 0x2F) % _hashMod;
    }
    h = (h * 131 + 0x20) % _hashMod;
    h = (h * 131 + (turn == 0 ? 0x77 : 0x62)) % _hashMod;
    h = (h * 131 + 0x20) % _hashMod;
    if (castling == 0) {
      h = (h * 131 + 0x2D) % _hashMod;
    } else {
      for (var bit = 0; bit < 4; bit++) {
        if (castling & (1 << bit) != 0) {
          h = (h * 131 + 'KQkq'.codeUnitAt(bit)) % _hashMod;
        }
      }
    }
    h = (h * 131 + 0x20) % _hashMod;
    if (_ep < 0) {
      h = (h * 131 + 0x2D) % _hashMod;
    } else {
      h = (h * 131 + 0x61 + (_ep & 7)) % _hashMod;
      h = (h * 131 + 0x38 - (_ep >> 4)) % _hashMod;
    }
    return _hash = h;
  }

  /// [_positionHash] the slow way, from the key string. For tests.
  int get debugKeyHash => _hashKey(_key());

  /// [_positionHash], for tests.
  int get debugStreamHash => _positionHash;

  /// How many times this position has stood on the board, itself included.
  int get repetitions {
    // A third occurrence needs two earlier ones with the same side to move,
    // four and eight plies back at the least.
    if (history.length < 8) return 1;
    final now = _positionHash;
    var n = 1;
    for (final h in history) {
      if (h == now) n++;
    }
    return n;
  }

  /// Lean-engine legal moves, ascending, whether or not the game is over.
  List<int> get _legal {
    final cached = _moves;
    if (cached != null) return cached;
    final pseudo = <int>[];
    _pseudo(_board, turn, castling, _ep, pseudo);
    final k = _kings[turn];
    _scratch.setRange(0, 128, _board);
    final checked = inCheck;
    final out = <int>[];
    for (final m in pseudo) {
      // Out of check, a piece that does not share a line with its own king
      // cannot be pinned, so its move needs no test. The king itself and en
      // passant (which lifts a second pawn off the board) always get one.
      final from = _from88(m);
      if (!checked && from != k) {
        final df = (from & 7) - (k & 7);
        final dr = (from >> 4) - (k >> 4);
        final aligned = df == 0 || dr == 0 || df == dr || df == -dr;
        final enPassant = _board[from] & 7 == chessPawn && _to88m(m) == _ep;
        if (!aligned && !enPassant) {
          out.add(m);
          continue;
        }
      }
      if (_legalInPlace(_scratch, m, turn, k)) out.add(m);
    }
    out.sort();
    return _moves = out;
  }

  /// The board as the package sees it, built once. Never mutated: the
  /// record rules copy it before playing a move.
  pkg.Chess get _package =>
      _record ??= pkg.Chess.fromFEN(fen, check_validity: false);

  /// The position after the lean engine plays [m], legal or not.
  ChessState _after(int m) {
    final b = Int8List.fromList(_board);
    final from = _from88(m);
    final to = _to88m(m);
    final type = b[from] & 7;
    final captured = b[to] != 0;
    final pawn = type == chessPawn;
    _play(b, m, turn);
    var rights = castling;
    if (type == chessKing) rights &= turn == 0 ? ~3 : ~12;
    for (final sq in [from, to]) {
      rights &= switch (sq) {
        119 => ~1,
        112 => ~2,
        7 => ~4,
        0 => ~8,
        _ => ~0,
      };
    }
    final kings = List<int>.of(_kings);
    if (type == chessKing) kings[turn] = to;
    final next = 1 - turn;
    var ep = -1;
    if (pawn && (to - from == 32 || from - to == 32)) {
      final mid = (from + to) >> 1;
      if (_epCapturable(b, mid, next, kings[next])) ep = mid;
    }
    final clock = pawn || captured ? 0 : halfmove + 1;
    return ChessState._(
      b,
      next,
      rights,
      ep,
      clock,
      turn == 1 ? fullmove + 1 : fullmove,
      clock == 0 ? const [] : [...history, _positionHash],
      kings,
    );
  }
}

// ── FEN ─────────────────────────────────────────────────────────────────────

/// Parses a FEN with no checks beyond its shape. For FENs the package or
/// [ChessState.fen] wrote; [_ChessRulesBase.decode] adds the rest.
ChessState? _parseFen(String fen, List<int> history) {
  final f = fen.split(' ');
  if (f.length != 6) return null;
  final rows = f[0].split('/');
  if (rows.length != 8) return null;
  final b = Int8List(128);
  for (var r = 0; r < 8; r++) {
    var c = 0;
    for (final ch in rows[r].split('')) {
      final digit = int.tryParse(ch);
      if (digit != null) {
        if (digit < 1 || digit > 8) return null;
        c += digit;
        continue;
      }
      final t = _letters.indexOf(ch.toLowerCase());
      if (t <= 0 || c > 7) return null;
      b[r << 4 | c] = t | (ch == ch.toUpperCase() ? 0 : chessBlack);
      c++;
    }
    if (c != 8) return null;
  }
  if (f[1] != 'w' && f[1] != 'b') return null;
  var rights = 0;
  if (f[2] != '-') {
    for (final ch in f[2].split('')) {
      final bit = 'KQkq'.indexOf(ch);
      if (bit < 0) return null;
      rights |= 1 << bit;
    }
  }
  var ep = -1;
  if (f[3] != '-') {
    if (!RegExp(r'^[a-h][36]$').hasMatch(f[3])) return null;
    ep = (8 - int.parse(f[3][1])) << 4 | (f[3].codeUnitAt(0) - 0x61);
  }
  final clock = int.tryParse(f[4]);
  final number = int.tryParse(f[5]);
  if (clock == null || number == null) return null;
  final kings = [_findKing(b, 0), _findKing(b, 1)];
  return ChessState._(
    b,
    f[1] == 'w' ? 0 : 1,
    rights,
    ep,
    clock,
    number,
    history,
    kings,
    fen,
  );
}

// ── Rules ───────────────────────────────────────────────────────────────────

/// What both rule sets share: the wire format, which is the server's.
abstract class _ChessRulesBase extends TurnRules<ChessState, int> {
  const _ChessRulesBase();

  @override
  String get id => 'chess';

  @override
  int get minSeats => 2;

  @override
  int get maxSeats => 2;

  @override
  ChessState initial(int seats) {
    if (seats != 2) throw const IllegalMove('chess is two seats');
    return _parseFen(_initialFen, const [])!;
  }

  @override
  int toMove(ChessState state) => state.turn;

  /// The reason for a finished game, in the TS order: no legal move first
  /// (a mate on the 100th ply is still a mate), then the three draws.
  TurnOutcome? _outcome(
    ChessState s, {
    required bool noMoves,
    required bool check,
    required bool insufficient,
  }) {
    if (noMoves) {
      return check
          ? TurnOutcome(winner: 1 - s.turn, reason: 'checkmate')
          : const TurnOutcome(winner: null, reason: 'stalemate');
    }
    if (insufficient) {
      return const TurnOutcome(winner: null, reason: 'insufficient-material');
    }
    if (s.halfmove >= chessFiftyMovePlies) {
      return const TurnOutcome(winner: null, reason: 'fifty-moves');
    }
    if (s.repetitions >= 3) {
      return const TurnOutcome(winner: null, reason: 'repetition');
    }
    return null;
  }

  @override
  String encode(ChessState state) =>
      '${state.fen}|${state.history.map(_hashText).join()}';

  /// Everything the TS `decode` refuses, refused here too: a non-canonical
  /// FEN, castling rights without the king and rook at home, an en passant
  /// square no pawn crossed (or none can take), the side that just moved
  /// in check, and a history whose length is not the halfmove clock.
  @override
  ChessState decode(String raw) {
    Never bad() => throw FormatException('BAD_STATE', raw);
    final parts = raw.split('|');
    if (parts.length != 2) bad();
    final fen = parts[0];
    final h = parts[1];
    final f = fen.split(' ');
    if (f.length != 6) bad();
    if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(f[4])) bad();
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(f[5])) bad();
    if (!RegExp(r'^(-|K?Q?k?q?)$').hasMatch(f[2])) bad();
    final clock = int.parse(f[4]);
    if (clock > chessFiftyMovePlies || h.length != clock * _hashLen) bad();
    final history = <int>[];
    for (var i = 0; i < h.length; i += _hashLen) {
      var v = 0;
      for (var j = i; j < i + _hashLen; j++) {
        final d = _hashChars.indexOf(h[j]);
        if (d < 0) bad();
        v = v * 64 + d;
      }
      history.add(v);
    }
    final s = _parseFen(fen, history);
    if (s == null) bad();
    final b = s._board;
    if (s._kings[0] < 0 || s._kings[1] < 0) bad();
    var kings = 0;
    for (var sq = 0; sq < 120; sq++) {
      if (sq & 0x88 != 0) continue;
      final p = b[sq];
      if (p & 7 == chessKing) kings++;
      if (p & 7 == chessPawn && (sq >> 4 == 0 || sq >> 4 == 7)) bad();
    }
    if (kings != 2) bad();
    const homes = [(1, 116, 119, 0), (2, 116, 112, 0), (4, 4, 7, 1), (8, 4, 0, 1)];
    for (final (bit, king, rook, side) in homes) {
      if (s.castling & bit == 0) continue;
      if (b[king] != chessKing | side << 3) bad();
      if (b[rook] != chessRook | side << 3) bad();
    }
    final ep = s._ep;
    if (ep >= 0) {
      // White to move: black's pawn went from rank 7 over rank 6 to rank 5.
      final white = s.turn == 0;
      if ((ep >> 4) != (white ? 2 : 5)) bad();
      final pushed = ep + (white ? 16 : -16);
      final start = ep + (white ? -16 : 16);
      if (b[pushed] != (white ? chessPawn | chessBlack : chessPawn)) bad();
      if (b[ep] != 0 || b[start] != 0) bad();
      if (!_epCapturable(b, ep, s.turn, s._kings[s.turn])) bad();
    }
    if (_attacked(b, s._kings[1 - s.turn], s.turn)) bad();
    // Canonical: exactly what the writer would produce from this board.
    s._fen = null;
    if (s.fen != fen) bad();
    return s;
  }

  @override
  String encodeMove(int move) => _uci(move);

  @override
  int decodeMove(String raw) {
    if (!RegExp(r'^[a-h][1-8][a-h][1-8][bnqr]?$').hasMatch(raw)) {
      throw FormatException('BAD_MOVE', raw);
    }
    int sq(int i) =>
        (8 - (raw.codeUnitAt(i + 1) - 0x30)) << 4 | (raw.codeUnitAt(i) - 0x61);
    final promo = raw.length == 5 ? _promoLetters.indexOf(raw[4]) : 0;
    return _move(sq(0), sq(2), promo);
  }
}

/// The rules of record: the `chess` package decides what is legal, what is
/// check, mate and stalemate, and what material is insufficient.
class ChessRules extends _ChessRulesBase {
  const ChessRules();

  static int _slot(pkg.PieceType? t) => t == null ? 0 : _promoLetters.indexOf(t.name);

  List<int> _packageMoves(ChessState s) => [
    for (final m in s._package.generate_moves())
      _move(m.from, m.to, _slot(m.promotion)),
  ]..sort();

  @override
  TurnOutcome? outcome(ChessState state) {
    final c = state._package;
    return _outcome(
      state,
      noMoves: c.generate_moves().isEmpty,
      check: c.in_check,
      insufficient: c.insufficient_material,
    );
  }

  @override
  List<int> legalMoves(ChessState state) =>
      outcome(state) != null ? const [] : _packageMoves(state);

  @override
  ChessState apply(ChessState state, int move) {
    if (outcome(state) != null) throw const IllegalMove('game over');
    final c = state._package.copy();
    final slot = move & 7;
    pkg.Move? found;
    for (final m in c.generate_moves()) {
      if (_move(m.from, m.to, _slot(m.promotion)) == move) found = m;
    }
    if (found == null || (slot != 0) != (found.promotion != null)) {
      throw IllegalMove(_uci(move));
    }
    c.make_move(found);
    final f = c.generate_fen().split(' ');
    // The package always writes the square a pawn skipped; chess.js only
    // when a legal en passant capture exists. Match the server.
    if (f[3] != '-' &&
        !c.generate_moves().any((m) => m.flags & pkg.Chess.BITS_EP_CAPTURE != 0)) {
      f[3] = '-';
    }
    final clock = int.parse(f[4]);
    final next = _parseFen(
      f.join(' '),
      clock == 0 ? const [] : [...state.history, state._positionHash],
    );
    if (next == null) throw StateError('package wrote a FEN it cannot read');
    return next;
  }
}

/// The lean engine the bot searches with. Same answers as [ChessRules],
/// checked by the same fixtures, several times faster.
class ChessEngineRules extends _ChessRulesBase {
  const ChessEngineRules();

  @override
  TurnOutcome? outcome(ChessState state) {
    final cached = state._outcome;
    if (cached != null) return cached is TurnOutcome ? cached : null;
    final o = _outcome(
      state,
      noMoves: state._legal.isEmpty,
      check: state.inCheck,
      insufficient: _insufficient(state._board),
    );
    state._outcome = o ?? false;
    return o;
  }

  @override
  List<int> legalMoves(ChessState state) =>
      outcome(state) != null ? const [] : state._legal;

  @override
  ChessState apply(ChessState state, int move) {
    if (outcome(state) != null) throw const IllegalMove('game over');
    if (!state._legal.contains(move)) throw IllegalMove(_uci(move));
    return state._after(move);
  }

  /// Leaf count of the legal move tree [depth] plies deep, draws ignored:
  /// the standard check on a move generator.
  int perft(ChessState state, int depth) {
    final moves = state._legal;
    if (depth <= 1) return depth == 1 ? moves.length : 1;
    var n = 0;
    for (final m in moves) {
      n += perft(state._after(m), depth - 1);
    }
    return n;
  }
}

const chessRules = ChessRules();
const chessEngineRules = ChessEngineRules();

// ── Evaluator ───────────────────────────────────────────────────────────────

/// Piece values in centipawns, by type.
const List<int> _value = [0, 100, 320, 330, 500, 900, 20000];

// Tomasz Michniewski's "Simplified Evaluation Function" tables, as published
// on the chessprogramming wiki: white's view, a8 first. Black reads them
// mirrored top to bottom.
const List<int> _pawnTable = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];
const List<int> _knightTable = [
  -50, -40, -30, -30, -30, -30, -40, -50, //
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];
const List<int> _bishopTable = [
  -20, -10, -10, -10, -10, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 10, 10, 5, 0, -10,
  -10, 5, 5, 10, 10, 5, 5, -10,
  -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10,
  -10, 5, 0, 0, 0, 0, 5, -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
];
const List<int> _rookTable = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  5, 10, 10, 10, 10, 10, 10, 5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  0, 0, 0, 5, 5, 0, 0, 0,
];
const List<int> _queenTable = [
  -20, -10, -10, -5, -5, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 5, 5, 5, 0, -10,
  -5, 0, 5, 5, 5, 5, 0, -5,
  0, 0, 5, 5, 5, 5, 0, -5,
  -10, 5, 5, 5, 5, 5, 0, -10,
  -10, 0, 5, 0, 0, 0, 0, -10,
  -20, -10, -10, -5, -5, -10, -10, -20,
];
const List<int> _kingMiddleTable = [
  -30, -40, -40, -50, -50, -40, -40, -30, //
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20,
  20, 30, 10, 0, 0, 10, 30, 20,
];
const List<int> _kingEndTable = [
  -50, -40, -30, -20, -20, -30, -40, -50, //
  -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -30, 0, 0, 0, 0, -30, -30,
  -50, -30, -30, -30, -30, -30, -30, -50,
];

const List<List<int>> _tables = [
  [],
  _pawnTable,
  _knightTable,
  _bishopTable,
  _rookTable,
  _queenTable,
  _kingMiddleTable,
];

/// The table entry for [piece] on 0x88 square [sq].
int _pst(int piece, int sq, bool endgame) {
  final type = piece & 7;
  var i = _to64(sq);
  if (piece >> 3 == 1) i ^= 56;
  if (type == chessKing && endgame) return _kingEndTable[i];
  return _tables[type][i];
}

/// Static score from white's side, in centipawns: material, the tables, and
/// in a won endgame a "mop-up" pull that drives the lone king to the edge and
/// brings the winning king over. Without that last term a queen-up bot
/// shuffles until the fifty-move rule takes the win away.
int _staticWhite(Int8List b) {
  final queens = [0, 0];
  final minors = [0, 0];
  final majors = [0, 0];
  final material = [0, 0];
  for (var sq = 0; sq < 120; sq++) {
    if (sq & 0x88 != 0) {
      sq += 7;
      continue;
    }
    final p = b[sq];
    if (p == 0) continue;
    final side = p >> 3;
    final t = p & 7;
    if (t == chessQueen) queens[side]++;
    if (t == chessKnight || t == chessBishop) minors[side]++;
    if (t == chessRook) majors[side]++;
    if (t != chessPawn && t != chessKing) material[side] += _value[t];
  }
  // The wiki's test: no queens, or each side with a queen has at most one
  // minor piece beside it.
  bool light(int side) =>
      queens[side] == 0 || (majors[side] == 0 && minors[side] <= 1);
  final endgame = light(0) && light(1);
  var score = 0;
  var wk = -1;
  var bk = -1;
  for (var sq = 0; sq < 120; sq++) {
    if (sq & 0x88 != 0) {
      sq += 7;
      continue;
    }
    final p = b[sq];
    if (p == 0) continue;
    final v = _value[p & 7] + _pst(p, sq, endgame);
    if (p >> 3 == 0) {
      score += v;
    } else {
      score -= v;
    }
    if (p == chessKing) wk = sq;
    if (p == chessKing | chessBlack) bk = sq;
  }
  if (endgame && wk >= 0 && bk >= 0) {
    final lead = material[0] - material[1];
    if (lead.abs() >= 300) {
      final loser = lead > 0 ? bk : wk;
      final file = loser & 7;
      final rank = loser >> 4;
      final fromCentre =
          (file < 4 ? 3 - file : file - 4) + (rank < 4 ? 3 - rank : rank - 4);
      final apart =
          ((wk & 7) - (bk & 7)).abs() + ((wk >> 4) - (bk >> 4)).abs();
      final pull = 10 * fromCentre + 4 * (14 - apart);
      score += lead > 0 ? pull : -pull;
    }
  }
  return score;
}

/// A capture-only search under the generic engine's horizon.
///
/// The generic engine has no hook for a quiescence search, but it does not
/// need one: it scores every horizon node through [ChessEvaluator.evaluate],
/// which runs this. Captures (and queen promotions) are searched until the
/// position is quiet, so the bot does not stop counting halfway through an
/// exchange and "win" a queen that is about to be taken back. Bounded in
/// depth and nodes, since it runs with the full window at every leaf.
class _Quiescence {
  static const maxPlies = 6;
  static const nodeCap = 3000;

  /// Plies at the start in which a side in check searches every evasion
  /// rather than standing pat, so a mate the horizon walked into is seen.
  static const evasionPlies = 2;

  static const double mate = 30000;

  final Int8List b = Int8List(128);
  final List<int> kings = [0, 0];
  final List<List<int>> _lists = [for (var i = 0; i < maxPlies + 1; i++) <int>[]];
  final List<List<int>> _keys = [for (var i = 0; i < maxPlies + 1; i++) <int>[]];
  int nodes = 0;
  int ep = -1;

  double run(ChessState s, double alpha, double beta) {
    b.setAll(0, s._board);
    kings[0] = s._kings[0];
    kings[1] = s._kings[1];
    ep = s._ep;
    nodes = 0;
    return _q(s.turn, alpha, beta, 0);
  }

  double _static(int us) {
    final w = _staticWhite(b).toDouble();
    return us == 0 ? w : -w;
  }

  double _q(int us, double alpha, double beta, int ply) {
    nodes++;
    final them = 1 - us;
    final epHere = ply == 0 ? ep : -1;
    if (nodes > nodeCap) return _static(us);
    final moves = _lists[ply]..clear();
    if (ply < evasionPlies && _attacked(b, kings[us], them)) {
      _pseudo(b, us, 0, epHere, moves);
      var best = double.negativeInfinity;
      var any = false;
      for (final m in moves) {
        final v = _child(m, us, alpha, beta, ply);
        if (v == null) continue;
        any = true;
        if (v > best) best = v;
        if (v > alpha) alpha = v;
        if (alpha >= beta) break;
      }
      return any ? best : -(mate - ply);
    }
    final stand = _static(us);
    if (stand >= beta || ply >= maxPlies) return stand;
    if (stand > alpha) alpha = stand;
    _pseudo(b, us, 0, epHere, moves, noisy: true);
    if (moves.isEmpty) return stand;
    // MVV-LVA: the most valuable victim first, the cheapest attacker first.
    final keys = _keys[ply]..clear();
    for (final m in moves) {
      final victim = b[_to88m(m)] & 7;
      keys.add((victim == 0 ? 1 : victim) * 16 - (b[_from88(m)] & 7) + (m & 7 == 0 ? 0 : 64));
    }
    for (var i = 1; i < moves.length; i++) {
      final m = moves[i];
      final k = keys[i];
      var j = i - 1;
      while (j >= 0 && keys[j] < k) {
        moves[j + 1] = moves[j];
        keys[j + 1] = keys[j];
        j--;
      }
      moves[j + 1] = m;
      keys[j + 1] = k;
    }
    for (var i = 0; i < moves.length; i++) {
      final m = moves[i];
      // Delta pruning: even winning this piece clean cannot lift alpha.
      final victim = b[_to88m(m)] & 7;
      final gain = _value[victim == 0 ? chessPawn : victim] + (m & 7 == 0 ? 0 : 800);
      if (stand + gain + 200 < alpha) continue;
      final v = _child(m, us, alpha, beta, ply);
      if (v == null) continue;
      if (v >= beta) return v;
      if (v > alpha) alpha = v;
    }
    return alpha;
  }

  /// Plays [m], scores it from [us]'s side, and takes it back. Null when it
  /// leaves [us]'s king in check.
  double? _child(int m, int us, double alpha, double beta, int ply) {
    final from = _from88(m);
    final to = _to88m(m);
    final moved = b[from];
    final captured = b[to];
    final rookFrom = moved & 7 == chessKing && (to - from).abs() == 2
        ? (to > from ? from + 3 : from - 4)
        : -1;
    final victimSq = _play(b, m, us);
    final kingWas = kings[us];
    if (moved & 7 == chessKing) kings[us] = to;
    double? v;
    if (!_attacked(b, kings[us], 1 - us)) {
      v = -_q(1 - us, -beta, -alpha, ply + 1);
    }
    kings[us] = kingWas;
    b[from] = moved;
    b[to] = captured;
    if (victimSq >= 0) b[victimSq] = chessPawn | (1 - us) << 3;
    if (rookFrom >= 0) {
      final rookTo = to > from ? from + 1 : from - 1;
      b[rookFrom] = b[rookTo];
      b[rookTo] = 0;
    }
    return v;
  }
}

final _quiescence = _Quiescence();

/// Material plus piece-square tables, read after a capture search.
///
/// No mobility term: counting moves means generating them for both sides at
/// every leaf, which on this engine costs about as much as the capture
/// search itself, and the tables already reward developed pieces.
class ChessEvaluator extends TurnEvaluator<ChessState, int> {
  const ChessEvaluator();

  @override
  double evaluate(ChessState state, int seat) =>
      evaluateBounded(state, seat, double.negativeInfinity, double.infinity);

  /// The capture search inside the caller's window, which is what keeps it
  /// affordable at every leaf: a line that is already refuted stops at its
  /// first capture.
  @override
  double evaluateBounded(ChessState state, int seat, double alpha, double beta) {
    final mine = state.turn == seat;
    final v = _quiescence.run(state, mine ? alpha : -beta, mine ? beta : -alpha);
    return mine ? v : -v;
  }

  /// Static score with no capture search, from [seat]'s side. For tests.
  double staticScore(ChessState state, int seat) {
    final w = _staticWhite(state._board).toDouble();
    return seat == 0 ? w : -w;
  }

  /// Queen promotions, then captures by MVV-LVA (checking ones ahead of
  /// their peers), then quiet checks, then quiet moves by how much their
  /// table square improves; under-promotions last. Ties keep the generator's
  /// order, hence the index key.
  @override
  List<int> order(ChessState state, List<int> moves) {
    final b = state._board;
    final us = state.turn;
    final them = 1 - us;
    final enemyKing = state._kings[them];
    final ranks = List<int>.filled(moves.length, 0);
    final scratch = _scratch..setRange(0, 128, b);
    for (var i = 0; i < moves.length; i++) {
      final m = moves[i];
      final from = _from88(m);
      final to = _to88m(m);
      final piece = b[from];
      final type = piece & 7;
      var victim = b[to] & 7;
      if (victim == 0 && type == chessPawn && (from & 7) != (to & 7)) {
        victim = chessPawn;
      }
      final promo = m & 7;
      final epVictim = _play(scratch, m, us);
      final check = _attacked(scratch, enemyKing, us);
      _unplay(scratch, m, us, piece, b[to], epVictim);
      int rank;
      if (promo == 3) {
        rank = 3000000 + victim;
      } else if (promo != 0) {
        rank = -100000;
      } else if (victim != 0) {
        rank = 2000000 + _value[victim] * 10 - _value[type] ~/ 10 + (check ? 5000 : 0);
      } else if (check) {
        rank = 1000000;
      } else {
        rank = _pst(piece, to, false) - _pst(piece, from, false);
      }
      ranks[i] = rank;
    }
    final index = [for (var i = 0; i < moves.length; i++) i]
      ..sort((a, c) {
        final r = ranks[c].compareTo(ranks[a]);
        return r != 0 ? r : a.compareTo(c);
      });
    return [for (final i in index) moves[i]];
  }
}

const chessEvaluator = ChessEvaluator();
