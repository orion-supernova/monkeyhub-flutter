import '../l10n/generated/app_localizations.dart';

/// A move, the way a player would say it: "e2 → e4", "11 → 15", "D3",
/// "Column 4". Null where the board says it better than words (a tic-tac-toe
/// mark, a line in Dots), or for a token this build cannot read.
String? moveNotation(AppLocalizations l10n, String game, String move) {
  switch (game) {
    case 'chess':
      if (!RegExp(r'^[a-h][1-8][a-h][1-8][bnqr]?$').hasMatch(move)) return null;
      final promo = move.length == 5 ? '=${move[4].toUpperCase()}' : '';
      return '${move.substring(0, 2)} → ${move.substring(2, 4)}$promo';
    case 'checkers':
      if (!RegExp(r'^\d+([-x]\d+)+$').hasMatch(move)) return null;
      return move.replaceAll('-', ' → ').replaceAll('x', ' × ');
    case 'connectfour':
      final col = int.tryParse(move);
      return col == null ? null : l10n.chatGameMvColumn(col + 1);
    case 'reversi':
      final cell = int.tryParse(move);
      if (cell == null || cell < 0 || cell > 63) return null;
      return '${String.fromCharCode(0x41 + cell % 8)}${cell ~/ 8 + 1}';
    default:
      return null;
  }
}
