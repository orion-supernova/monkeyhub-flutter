/// Day-boundary arithmetic for the Feed board.
///
/// Every surface on the board is scoped to "today": highlights are listed for
/// 24h, the puzzle is one per day, standings default to the current day. That
/// makes the day boundary load-bearing, and getting it wrong is the kind of bug
/// that only shows up for one user, once, at 23:59.
///
/// Deliberately a pure leaf with no Flutter binding and no `DateTime.now()` of
/// its own — every function takes the instant to reason about. That is what
/// lets the rollover, the DST seams and the year boundary be unit-tested in
/// microseconds instead of by waiting for midnight, and it matches the shape of
/// the other extracted rule files (`pending_reconcile.dart`,
/// `request_outcome.dart`, `auth_errors.dart`).
library;

/// Day 1 of the Feed. Fixed forever — the masthead's edition number is derived
/// from it, so moving this renumbers every edition retroactively.
///
/// Deliberately a *calendar* date rather than a UTC instant: editions are
/// counted in local days, and anchoring to an instant would put users west of
/// UTC an edition behind on the very first day.
const int _epochYear = 2026;
const int _epochMonth = 1;
const int _epochDay = 1;

/// The stable identity of the local calendar day containing [local].
///
/// `YYYY-MM-DD`, zero-padded so it sorts lexicographically — which is what lets
/// Convex range-scan an index on it without a separate numeric column.
///
/// Takes a LOCAL DateTime. Passing a UTC one silently buckets users into the
/// wrong day near either midnight, and because the string still looks perfectly
/// well-formed there is nothing downstream to catch it.
String dayKeyOf(DateTime local) {
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

/// The first instant of the day AFTER the one containing [local].
///
/// Built with `DateTime(y, m, d + 1)` rather than by adding 24 hours on
/// purpose: the constructor normalises overflow (Dec 32 → Jan 1) *and* resolves
/// the result against the local zone's real offset, so a DST spring-forward day
/// is 23 hours and a fall-back day is 25 and both land exactly on midnight.
/// `local.add(const Duration(days: 1))` gets both of those wrong by an hour,
/// which parks the rollover timer either an hour early (a board that flips
/// while you are looking at it) or an hour late.
DateTime nextMidnightAfter(DateTime local) =>
    DateTime(local.year, local.month, local.day + 1);

/// How long until the board should roll over to a new day.
///
/// Never negative and never zero — a zero-delay `Timer` that re-reads the same
/// day would spin. Clamped to at least a second so a clock adjustment landing
/// exactly on the boundary costs one extra tick rather than a busy loop.
Duration untilNextDay(DateTime local) {
  final gap = nextMidnightAfter(local).difference(local);
  return gap < const Duration(seconds: 1) ? const Duration(seconds: 1) : gap;
}

/// The masthead's edition number: local days since the epoch, 1-based.
///
/// Compares midnight-to-midnight rather than the raw instants so the result is
/// a whole number of calendar days regardless of what time of day [local] is —
/// and so DST transitions, which make some days 23 or 25 hours long, cannot
/// round a day away. Dividing raw microseconds by 24h drifts by one after the
/// first spring-forward and never recovers.
int editionNumber(DateTime local) {
  final epoch = DateTime(_epochYear, _epochMonth, _epochDay);
  final today = DateTime(local.year, local.month, local.day);
  // `inDays` on a midnight-to-midnight difference is exact only if both ends
  // share a UTC offset, which they do not across a DST change. Rounding the
  // hour-scale remainder is what keeps this a clean integer.
  final hours = today.difference(epoch).inHours;
  return (hours / 24).round() + 1;
}

/// Whether [a] and [b] fall on the same local calendar day.
bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
