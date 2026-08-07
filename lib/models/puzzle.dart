/// The daily puzzle's client-side model.
///
/// Wordle's tension, minus the words: guess a hidden four-symbol code in six
/// tries, each guess answered tile by tile — exactly right, right symbol
/// wrong place, or absent. No words anywhere, because this app ships in
/// twelve languages: a real Wordle needs a curated answer list per locale,
/// and friends on different app languages would then be solving different
/// puzzles, making the shared scoreboard compare nothing.
///
/// The per-slot read ([PuzzlePegs.slots]) is only ever populated for the
/// player's OWN guesses ([PuzzleAttempt.feedback]). A friend's finished
/// attempt ([PuzzleScore.feedback]) stays aggregate-only — see the class doc
/// there for why an ordered grid would leak the shared answer.
///
/// The answer never reaches the device until the player can no longer act on
/// it: guesses are scored on the server and only feedback comes back.
library;

/// Symbols in the alphabet. Mirrored by `SYMBOLS` in backend/convex/puzzle.ts.
const int kPuzzleSymbolCount = 6;

/// Slots in the code.
const int kPuzzleSlots = 4;

/// Guesses allowed.
const int kPuzzleMaxGuesses = 6;

/// One slot's status within a guess.
enum PuzzlePegSlot {
  /// Right symbol, right place.
  exact,

  /// Right symbol, wrong place.
  present,

  /// Not in the code at all.
  absent;

  static PuzzlePegSlot _parse(String s) => switch (s) {
    'exact' => exact,
    'present' => present,
    _ => absent,
  };
}

/// The result of scoring one guess.
class PuzzlePegs {
  const PuzzlePegs({
    required this.exact,
    required this.present,
    this.slots = const [],
  });

  /// Right symbol, right slot.
  final int exact;

  /// Right symbol, wrong slot. Counted after exacts are consumed, so
  /// `exact + present` can never exceed the number of slots.
  final int present;

  /// Per-slot status, index-aligned with the guess. Empty for a friend's row
  /// — see the library doc for why ordered feedback is only ever sent for the
  /// player's own attempt.
  final List<PuzzlePegSlot> slots;

  static PuzzlePegs fromJson(Map<String, dynamic> j) => PuzzlePegs(
    exact: (j['exact'] as num?)?.toInt() ?? 0,
    present: (j['present'] as num?)?.toInt() ?? 0,
    slots: [
      for (final s in (j['slots'] as List?) ?? const [])
        PuzzlePegSlot._parse(s.toString()),
    ],
  );

  /// One row of the shareable grid.
  ///
  /// Green for exact, yellow for misplaced, white for nothing — the same
  /// vocabulary Wordle made universal, so a pasted grid reads correctly to
  /// anyone regardless of what language they play in. Deliberately does NOT
  /// use [slots]' order even when it's populated: the share text goes to
  /// people who may not have played today yet, and an ordered grid would tell
  /// them which slots of the (shared, identical) answer are right before
  /// they've earned that. Aggregate counts only, always.
  String get shareRow =>
      '🟩' * exact + '🟨' * present + '⬜' * (kPuzzleSlots - exact - present);
}

/// The viewer's own attempt at today's puzzle.
class PuzzleAttempt {
  const PuzzleAttempt({
    required this.guesses,
    required this.feedback,
    required this.solved,
    required this.done,
    this.answer,
  });

  /// Each guess, oldest first, as symbol indices.
  final List<List<int>> guesses;

  /// Feedback per guess, index-aligned with [guesses].
  final List<PuzzlePegs> feedback;

  final bool solved;

  /// Whether the player can still act — solved, or out of guesses.
  final bool done;

  /// Revealed only on a loss, and only once [done]. Null while playing.
  final List<int>? answer;

  bool get started => guesses.isNotEmpty;
  int get remaining => kPuzzleMaxGuesses - guesses.length;

  /// The full shareable grid.
  String get shareGrid => feedback.map((p) => p.shareRow).join('\n');

  static PuzzleAttempt? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return PuzzleAttempt(
      guesses: [
        for (final g in (j['guesses'] as List?) ?? const [])
          [for (final s in (g as List?) ?? const []) (s as num).toInt()],
      ],
      feedback: [
        for (final f in (j['feedback'] as List?) ?? const [])
          PuzzlePegs.fromJson((f as Map).cast<String, dynamic>()),
      ],
      solved: j['solved'] == true,
      done: j['done'] == true,
      answer: j['answer'] == null
          ? null
          : [for (final s in j['answer'] as List) (s as num).toInt()],
    );
  }
}

/// A friend's finished attempt.
///
/// In-progress attempts are deliberately absent from the payload — knowing
/// someone is on their fifth try leaks how hard today is, and a live counter
/// turns a quiet daily puzzle into a race.
class PuzzleScore {
  const PuzzleScore({
    required this.userId,
    required this.name,
    required this.solved,
    required this.guessCount,
    required this.finishedAt,
    required this.feedback,
  });

  final String userId;

  /// The player's display name. Empty for the viewer's own row — the UI shows
  /// the localized word for "you" there rather than echoing their own name.
  final String name;

  final bool solved;
  final int guessCount;
  final DateTime finishedAt;
  final List<PuzzlePegs> feedback;

  static PuzzleScore fromJson(Map<String, dynamic> j) => PuzzleScore(
    userId: j['userId'].toString(),
    name: j['name']?.toString() ?? '',
    solved: j['solved'] == true,
    guessCount: (j['guessCount'] as num?)?.toInt() ?? 0,
    finishedAt: DateTime.fromMillisecondsSinceEpoch(
      (j['finishedAt'] as num?)?.toInt() ?? 0,
    ),
    feedback: [
      for (final f in (j['feedback'] as List?) ?? const [])
        PuzzlePegs.fromJson((f as Map).cast<String, dynamic>()),
    ],
  );
}

/// Today's puzzle as the board sees it.
class PuzzleState {
  const PuzzleState({this.mine, this.scores = const []});

  final PuzzleAttempt? mine;

  /// Everyone who has finished today, best first.
  final List<PuzzleScore> scores;

  /// Where the viewer placed among those who have finished, 1-based, or null
  /// if they have not finished.
  int? rankOf(String userId) {
    final i = scores.indexWhere((s) => s.userId == userId);
    return i < 0 ? null : i + 1;
  }

  static PuzzleState fromJson(Map<String, dynamic>? j) {
    if (j == null) return const PuzzleState();
    return PuzzleState(
      mine: PuzzleAttempt.fromJson(
        (j['mine'] as Map?)?.cast<String, dynamic>(),
      ),
      scores: [
        for (final s in (j['scores'] as List?) ?? const [])
          PuzzleScore.fromJson((s as Map).cast<String, dynamic>()),
      ],
    );
  }
}
