import '../../diagnostics/diag_event.dart';

/// A run of consecutive events that read as the same thing.
class DiagGroup {
  const DiagGroup(this.events);

  final List<DiagEvent> events;

  DiagEvent get first => events.first;
  DiagEvent get last => events.last;
  int get count => events.length;
  bool get collapsed => events.length > 1;

  /// Wall time the run covers, in ms. Measured on the monotonic clock.
  ///
  /// The count alone is not the diagnostic — `×214` could be a busy minute or a
  /// catastrophe. `×214 over 3.4s` is unambiguous, and telling those two apart
  /// is the entire reason this screen exists.
  int get spanMs => last.upMs - first.upMs;
}

/// Collapses consecutive identical events into counted runs.
///
/// Borrowed from the reference implementation, where it exists to fold a
/// request/response pair repeating in a loop. It matters more here: a strobe IS
/// a run of identical events, so this is what turns four thousand unreadable
/// rows into a dozen that say what happened.
///
/// Only CONSECUTIVE runs collapse. Two identical events separated by something
/// else are two different facts about the timeline, and merging them across the
/// gap would destroy the ordering that makes the log worth reading.
List<DiagGroup> collapseEvents(List<DiagEvent> events, {bool enabled = true}) {
  if (!enabled) {
    return [
      for (final e in events) DiagGroup([e]),
    ];
  }

  final out = <DiagGroup>[];
  var i = 0;
  while (i < events.length) {
    var j = i;
    while (j + 1 < events.length && _same(events[j], events[j + 1])) {
      j++;
    }
    out.add(DiagGroup(events.sublist(i, j + 1)));
    i = j + 1;
  }
  return out;
}

/// What counts as "the same event happening again".
///
/// Deliberately ignores duration and correlation id: a query that fires two
/// hundred times is one fact whether each call took 8 ms or 12 ms, and keeping
/// them apart on timing alone would defeat the collapse entirely.
bool _same(DiagEvent a, DiagEvent b) =>
    a.cat == b.cat &&
    a.event == b.event &&
    a.name == b.name &&
    a.sev == b.sev &&
    a.detail == b.detail;
