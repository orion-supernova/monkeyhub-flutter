import '../turn_games/registry.dart';

/// The position a board game's picture shows, as its encoded state.
///
/// The opening position for most: a chess or checkers set-up, a Reversi
/// centre, Connect Four's empty rack all read as their game at a glance. Two
/// do not. An empty tic-tac-toe grid and an empty field of dots look like a
/// tile that failed to load, so those two show a game under way: three in a
/// row with the stroke through it, and a few drawn lines around one claimed
/// box.
///
/// Built once per game by playing real moves through the rules, so the
/// picture can never show a position the game itself could not reach.
String? chatGameArtState(String game) =>
    _cache.putIfAbsent(game, () => _build(game));

final Map<String, String?> _cache = {};

const _showcase = <String, List<String>>{
  // X takes the diagonal; O holds the top edge.
  'tictactoe': ['0', '1', '4', '2', '8'],
  // On the 4x4 field: seat two closes the top-left box (top 0, bottom 4,
  // left 20, right 21) and, going again, draws on; a few lines scattered
  // elsewhere so the field reads as mid-game rather than one lone square.
  'dots': ['0', '4', '20', '21', '13', '27', '9', '33', '18', '36'],
};

String? _build(String game) {
  final rules = turnGameFor(game);
  if (rules == null) return null;
  var state = rules.initialEncoded(2);
  for (final move in _showcase[game] ?? const <String>[]) {
    try {
      state = rules.applyEncoded(state, move);
    } catch (_) {
      // A rules change made a showcase move illegal: stop at the last good
      // position rather than draw nothing.
      break;
    }
  }
  return state;
}
