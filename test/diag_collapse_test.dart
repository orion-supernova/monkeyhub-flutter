import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/diagnostics/diag_event.dart';
import 'package:monkeyhub/screens/diagnostics/diag_collapse.dart';

/// The collapse is what makes a strobe readable: without it the viewer shows
/// four thousand identical rows and the surrounding context — the one thing
/// that explains the burst — is off-screen forever.
void main() {
  var seq = 0;
  DiagEvent ev({
    String event = 'metrics',
    String? detail = 'padBottom=48.0',
    DiagCat cat = DiagCat.layout,
    DiagSev sev = DiagSev.debug,
    int upMs = 0,
  }) {
    seq++;
    return DiagEvent(
      seq: seq,
      tsMs: 1700000000000 + upMs,
      upMs: upMs,
      cat: cat,
      sev: sev,
      event: event,
      detail: detail,
    );
  }

  setUp(() => seq = 0);

  test('a run of identical events becomes one counted group', () {
    final events = [for (var i = 0; i < 200; i++) ev(upMs: i * 17)];
    final groups = collapseEvents(events);
    expect(groups.length, 1);
    expect(groups.single.count, 200);
    expect(groups.single.collapsed, isTrue);
  });

  test('the group reports the span it covers, not just the count', () {
    // ×214 over 3.4s is a diagnosis; ×214 alone could be a busy minute.
    final events = [for (var i = 0; i < 100; i++) ev(upMs: i * 20)];
    final g = collapseEvents(events).single;
    expect(g.spanMs, 99 * 20);
  });

  test('only CONSECUTIVE runs collapse', () {
    // Two identical events separated by something else are two different facts
    // about the timeline; merging across the gap would destroy the ordering.
    final events = [
      ev(upMs: 0),
      ev(upMs: 10),
      ev(
        event: 'phase',
        detail: 'online → stalled',
        cat: DiagCat.connection,
        upMs: 20,
      ),
      ev(upMs: 30),
    ];
    final groups = collapseEvents(events);
    expect(groups.length, 3);
    expect(groups[0].count, 2);
    expect(groups[1].count, 1);
    expect(groups[2].count, 1);
  });

  test('a differing detail breaks the run', () {
    final events = [
      ev(detail: 'padBottom=48.0', upMs: 0),
      ev(detail: 'padBottom=48.0', upMs: 10),
      ev(detail: 'padBottom=0.0', upMs: 20),
    ];
    final groups = collapseEvents(events);
    expect(groups.length, 2);
    expect(groups[0].count, 2);
    expect(groups[1].count, 1);
  });

  test('severity is part of identity', () {
    final events = [
      ev(sev: DiagSev.debug, upMs: 0),
      ev(sev: DiagSev.warn, upMs: 10),
    ];
    expect(collapseEvents(events).length, 2);
  });

  test('disabling it yields one group per event', () {
    final events = [for (var i = 0; i < 5; i++) ev(upMs: i)];
    final groups = collapseEvents(events, enabled: false);
    expect(groups.length, 5);
    expect(groups.every((g) => !g.collapsed), isTrue);
  });

  test('an empty timeline collapses to nothing rather than throwing', () {
    expect(collapseEvents(const []), isEmpty);
  });

  test('first and last expose the ends of the run', () {
    final events = [for (var i = 0; i < 3; i++) ev(upMs: i * 100)];
    final g = collapseEvents(events).single;
    expect(g.first.upMs, 0);
    expect(g.last.upMs, 200);
  });
}
