import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/diagnostics/diag_buffer.dart';
import 'package:monkeyhub/diagnostics/diag_event.dart';
import 'package:monkeyhub/screens/diagnostics/diag_filter_sheet.dart';

/// What the viewer shows for a given filter.
///
/// The one rule worth pinning: hiding a category only shapes **All**. Asking
/// for a hidden category by name shows exactly it — the whole point of hiding
/// `frame` is to keep it out of the way until you tap it.
void main() {
  final buf = DiagBuffer.instance;
  late List<DiagEvent> log;

  setUp(() {
    buf.resetForTest();
    DiagEvent add(DiagCat cat, String name, [DiagSev sev = DiagSev.info]) =>
        buf.add(cat: cat, sev: sev, event: 'e', name: name);
    log = [
      add(DiagCat.subscription, 'sub:rooms'),
      add(DiagCat.frame, 'frame:jank', DiagSev.warn),
      add(DiagCat.frame, 'frame:slow'),
      add(DiagCat.api, 'calls:initiate', DiagSev.error),
      add(DiagCat.connection, 'socket'),
    ];
  });

  List<String?> shown(DiagFilter f) =>
      log.where(f.matches).map((e) => e.name).toList();

  const hideNoise = {DiagCat.subscription, DiagCat.frame};

  test('All leaves the hidden categories out', () {
    expect(
      shown(const DiagFilter(hidden: hideNoise)),
      ['calls:initiate', 'socket'],
    );
  });

  test('picking a hidden category shows exactly it', () {
    expect(
      shown(const DiagFilter(hidden: hideNoise, cats: {DiagCat.frame})),
      ['frame:jank', 'frame:slow'],
    );
  });

  test('a pick can mix hidden and shown categories', () {
    expect(
      shown(const DiagFilter(
        hidden: hideNoise,
        cats: {DiagCat.frame, DiagCat.api},
      )),
      ['frame:jank', 'frame:slow', 'calls:initiate'],
    );
  });

  test('search and severity still narrow a hidden pick', () {
    const frames = DiagFilter(hidden: hideNoise, cats: {DiagCat.frame});
    expect(shown(frames.copyWith(query: 'SLOW')), ['frame:slow']);
    expect(shown(frames.copyWith(minSev: DiagSev.warn)), ['frame:jank']);
  });

  test('nothing hidden is the old All', () {
    expect(shown(const DiagFilter()), hasLength(log.length));
  });
}
