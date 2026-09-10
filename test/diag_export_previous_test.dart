import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/diagnostics/diag_event.dart';
import 'package:monkeyhub/diagnostics/diag_export.dart';

/// A crash report has to carry the run that crashed.
///
/// The gap these close was total and silent: `previous.ndjson` was written at
/// every boot and read by nothing, so `DiagExport.build` only ever saw the
/// in-memory buffer — which, for the one report that matters, belongs to the
/// session that REPLACED the crashed one. Two real reports arrived that way:
/// both were clean post-restart sessions ending in a normal frame, and neither
/// contained the crash they were filed about.
DiagEvent _event(int seq, String event) => DiagEvent(
  seq: seq,
  tsMs: 1789036700000 + seq,
  upMs: seq,
  cat: DiagCat.device,
  sev: DiagSev.info,
  event: event,
);

void main() {
  group('DiagExport.build carries the previous session', () {
    test('appends it, and after the current one', () async {
      final text = await DiagExport.build(
        events: [_event(1, 'live-one'), _event(2, 'live-two')],
        dropped: 0,
        previous: [_event(1, 'crashed-one'), _event(2, 'crashed-two')],
      );

      expect(text, contains('crashed-one'));
      expect(text, contains('crashed-two'));

      // Ordering is the whole point, not a detail: `build` keeps the TAIL when
      // it has to truncate, so the crashed run must sit at the end or an
      // oversized report drops the evidence it exists to carry.
      expect(
        text.indexOf('crashed-one'),
        greaterThan(text.indexOf('live-two')),
        reason: 'the previous session must follow the current one',
      );
    });

    test('announces it in the header and marks the boundary', () async {
      final text = await DiagExport.build(
        events: [_event(1, 'live-one')],
        dropped: 0,
        previous: [_event(1, 'crashed-one')],
      );

      expect(text, contains('previous    events 1'));
      expect(text, contains('--- previous session: 1 events'));
    });

    test('says nothing when there is no previous run', () async {
      final text = await DiagExport.build(
        events: [_event(1, 'live-one')],
        dropped: 0,
      );

      expect(text, isNot(contains('previous session')));
      expect(text, isNot(contains('previous    events')));
      expect(text, contains('live-one'));
    });
  });
}
