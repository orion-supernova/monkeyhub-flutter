import '../l10n/generated/app_localizations.dart';
import '../models/chat_match.dart';
import '../party_games/party_views.dart';

/// [game]'s name in the viewer's language. Falls back to the id for a game
/// this build does not know yet, so a newer client's card still says
/// something.
String chatGameName(AppLocalizations l10n, String game) => switch (game) {
  'tictactoe' => l10n.chatGameNameTicTacToe,
  'connectfour' => l10n.chatGameNameConnectFour,
  'checkers' => l10n.chatGameNameCheckers,
  'reversi' => l10n.chatGameNameReversi,
  'dots' => l10n.chatGameNameDots,
  'chess' => l10n.chatGameNameChess,
  'liarsdice' => l10n.chatGameNameLiarsDice,
  'imposter' => l10n.chatGameNameImposter,
  'race' => l10n.chatGameNameRace,
  _ => game,
};

String chatGameDescription(AppLocalizations l10n, String game) =>
    switch (game) {
      'tictactoe' => l10n.chatGameDescTicTacToe,
      'connectfour' => l10n.chatGameDescConnectFour,
      'checkers' => l10n.chatGameDescCheckers,
      'reversi' => l10n.chatGameDescReversi,
      'dots' => l10n.chatGameDescDots,
      'chess' => l10n.chatGameDescChess,
      'liarsdice' => l10n.chatGameDescLiarsDice,
      'imposter' => l10n.chatGameDescImposter,
      'race' => l10n.chatGameDescRace,
      _ => '',
    };

String chatGamePlayers(AppLocalizations l10n, String game) {
  final max = maxSeatsOf(game);
  if (isPartyGame(game)) return l10n.chatGamePlayersRange(minSeatsOf(game), max);
  return max > 2 ? l10n.chatGamePlayersUpToFour : l10n.chatGamePlayersTwo;
}

/// [seat]'s name as the viewer reads it: "You" for themselves.
String seatName(AppLocalizations l10n, ChatMatch m, int seat, String viewerId) {
  if (seat < 0 || seat >= m.seats.length) return '';
  final s = m.seats[seat];
  return s.userId == viewerId ? l10n.momentRailYouLabel : s.name;
}

/// The one line that says where a game stands, from the viewer's side.
String matchStatusLine(AppLocalizations l10n, ChatMatch m, String viewerId) {
  switch (m.status) {
    case MatchStatus.lobby:
      final missing = minSeatsOf(m.game) - m.seats.length;
      return missing > 0
          ? l10n.chatGameNeedPlayers(missing)
          : l10n.chatGameStartsWhenReady;
    case MatchStatus.paused:
      final away = [
        for (var i = 0; i < m.seats.length; i++)
          if (m.seats[i].away && !m.seats[i].out) i,
      ];
      return away.length == 1
          ? l10n.chatGamePausedTitle(seatName(l10n, m, away.first, viewerId))
          : l10n.chatGamePausedMany;
    case MatchStatus.active:
      if (m.party) return partyPhaseLine(l10n, m, viewerId);
      if (m.isTurnOf(viewerId)) return l10n.chatGameYourMove;
      final t = m.turnSeat;
      if (t == null) return '';
      return m.isSeated(viewerId) && m.mode == MatchMode.async
          ? l10n.chatGameWaitingFor(m.seats[t].name)
          : l10n.chatGameTurnOf(seatName(l10n, m, t, viewerId));
    case MatchStatus.finished:
      return matchResultLine(l10n, m, viewerId);
    case MatchStatus.abandoned:
      return l10n.chatGameNobodyWon;
  }
}

/// The game screen's line under the title. The status line, except for a
/// Liar's Dice round, whose round and dice count the table already shows
/// large: up there, whose move it is says more.
String matchHeaderLine(AppLocalizations l10n, ChatMatch m, String viewerId) {
  if (m.party && m.game == 'liarsdice' && m.status == MatchStatus.active) {
    if (m.isTurnOf(viewerId)) return l10n.chatGameYourMove;
    final t = m.turnSeat;
    if (t != null && t < m.seats.length) {
      return l10n.chatGameTurnOf(seatName(l10n, m, t, viewerId));
    }
  }
  return matchStatusLine(l10n, m, viewerId);
}

/// Where a party game under way stands, in a few words: "Round 2 · 14 dice",
/// "Voting", "3 of 5 finished". What the chat card and the banner say; the
/// screen says the same with the table under it.
String partyPhaseLine(AppLocalizations l10n, ChatMatch m, String viewerId) {
  final view = partyViewOf(m);
  switch (view) {
    case LiarsDiceView():
      return l10n.chatGameLdRoundDice(view.totalDice, view.round);
    case ImposterView():
      return switch (view.phase) {
        'reveal' => l10n.chatGameImpCardReveal,
        'clues' => view.turn == null
            ? l10n.chatGameImpCardClues(view.clues.length, view.living.length)
            : m.isTurnOf(viewerId)
            ? l10n.chatGameImpYourClue
            : l10n.chatGameImpGiving(seatName(l10n, m, view.turn!, viewerId)),
        'vote' => l10n.chatGameImpCardVote,
        // The imposter is the one guessing: to them it is simply their move.
        'guess' => m.isTurnOf(viewerId)
            ? l10n.chatGameYourMove
            : l10n.chatGameImpGuessing,
        _ => '',
      };
    case RaceView():
      final total = view.players.where((p) => !p.left).length;
      return l10n.chatGameRaceFinishedCount(view.finished, total);
    case null:
      return l10n.chatGameStatusPlaying;
  }
}

/// How a finished game ended: who won, and why when it was not on the board.
String matchResultLine(AppLocalizations l10n, ChatMatch m, String viewerId) {
  if (m.status == MatchStatus.abandoned) return l10n.chatGameNobodyWon;
  if (m.party) {
    final line = _partyResultLine(l10n, m, viewerId);
    if (line != null) return line;
  }
  if (m.draw) return l10n.chatGameDraw;
  final w = m.winner;
  if (w == null) return l10n.chatGameNobodyWon;
  final head = m.seats[w].userId == viewerId
      ? l10n.chatGameYouWon
      : l10n.chatGameWonBy(m.seats[w].name);
  // The loser, for "ran out of time" / "resigned" / "left": in two-player
  // games the other seat; with more, the reason line is left off.
  if (m.seats.length != 2) return head;
  final loser = seatName(l10n, m, 1 - w, viewerId);
  final why = switch (m.reason) {
    'timeout' => l10n.chatGameReasonTimeout(loser),
    'resign' => l10n.chatGameReasonResign(loser),
    'left' => l10n.chatGameReasonLeft(loser),
    _ => null,
  };
  return why == null ? head : '$head · $why';
}

/// A party game's own ending, where it has one to tell: Imposter's team win
/// and its reasons, a race nobody finished. Null falls back to the plain
/// "X won".
String? _partyResultLine(AppLocalizations l10n, ChatMatch m, String viewerId) {
  final me = m.seatOf(viewerId);
  if (m.game == 'race' && m.draw) return l10n.chatGameRaceTimeUp;
  if (m.game != 'imposter') return null;
  final why = imposterReason(l10n, m.reason);
  final String head;
  final team = m.winners;
  if (team != null) {
    head = me >= 0 && team.contains(me)
        ? l10n.chatGameImpYourTeamWon
        : l10n.chatGameImpCrewWon;
  } else if (m.winner != null && m.winner! < m.seats.length) {
    head = m.winner == me
        ? l10n.chatGameImpYouWonImposter
        : l10n.chatGameImpImposterWon(m.seats[m.winner!].name);
  } else {
    return why;
  }
  return why == null ? head : '$head · $why';
}

/// Why an Imposter game ended, as a sentence.
String? imposterReason(AppLocalizations l10n, String? reason) =>
    switch (reason) {
      'escaped' => l10n.chatGameImpReasonEscaped,
      'wrongAccused' => l10n.chatGameImpReasonWrong,
      'guessed' => l10n.chatGameImpReasonGuessed,
      'caught' => l10n.chatGameImpReasonCaught,
      'imposterLeft' => l10n.chatGameImpReasonImposterLeft,
      'left' => l10n.chatGameImpReasonCrewLeft,
      _ => null,
    };

/// "5 hours left", "40 minutes left": the async turn clock.
String? matchTimeLeft(AppLocalizations l10n, ChatMatch m, DateTime now) {
  final at = m.deadlineAt;
  if (at == null || m.status != MatchStatus.active) return null;
  final left = at.difference(now);
  if (left.isNegative) return l10n.chatGameMinutesLeft(0);
  if (left.inHours >= 1) return l10n.chatGameHoursLeft(left.inHours);
  return l10n.chatGameMinutesLeft(left.inMinutes.clamp(1, 59));
}
