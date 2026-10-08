/// How many reactions one person may leave on one thing.
///
/// Mirrored on the server — `MAX_REACTIONS_PER_PERSON` in
/// `backend/convex/reactions.ts` and `MAX_MOMENT_REACTIONS_PER_PERSON` in
/// `backend/convex/feed.ts` — which is the one that actually enforces them. The
/// client checks first only so the friendly alert can say so before anything
/// is sent, instead of a reaction appearing and then vanishing on the refusal.
///
/// Per person, not per message: the thing being prevented is one reactor
/// spraying the whole picker onto a bubble, and a busy group thread with ten
/// different people each adding one is exactly what reactions are for.
const int kMaxMessageReactionsPerPerson = 10;

/// The same cap on a highlight, and on each comment under one. Lower than a
/// message's because a highlight's reaction row is the whole point of it —
/// five pills from one person would be most of the row.
const int kMaxMomentReactionsPerPerson = 5;

/// The error string both servers throw at the cap. Matched by substring, as
/// `PIN_LIMIT_REACHED` is in `ChatRepository.pinMessage`.
const String kReactionLimitError = 'REACTION_LIMIT';
