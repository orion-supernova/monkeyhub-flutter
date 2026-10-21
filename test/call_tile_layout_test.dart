import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/widgets/call_tile_layout.dart';

/// Group video tiles fill the screen, whatever the count: no fixed-shape
/// cards leaving most of it black, no empty slot in a short row.
void main() {
  const phone = Size(374, 600);

  double covered(List<Rect> rects) =>
      rects.fold(0.0, (a, r) => a + r.width * r.height);

  test('two stack on a phone, side by side on a wide window', () {
    final p = callTileRects(2, phone);
    expect(p[0].width, phone.width);
    expect(p[1].top, greaterThan(p[0].bottom));
    final w = callTileRects(2, const Size(1000, 560));
    expect(w[1].left, greaterThan(w[0].right));
  });

  test('rows are balanced, longer first, and every row is full width', () {
    for (final n in [3, 4, 5, 6, 7]) {
      final rects = callTileRects(n, phone);
      expect(rects.length, n);
      final rows = <double, List<Rect>>{};
      for (final r in rects) {
        rows.putIfAbsent(r.top, () => []).add(r);
      }
      final sizes = rows.values.map((r) => r.length).toList();
      expect(sizes, orderedEquals([...sizes]..sort((a, b) => b - a)),
          reason: 'n=$n');
      expect(sizes.reduce((a, b) => a > b ? a : b) -
          sizes.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(1),
          reason: 'n=$n');
      for (final row in rows.values) {
        expect(row.last.right, closeTo(phone.width, 0.01), reason: 'n=$n');
      }
      // Everything but the gaps is picture.
      expect(covered(rects) / (phone.width * phone.height),
          greaterThan(0.9), reason: 'n=$n');
    }
  });

  test('seven on a phone is 3, 2, 2, never 3, 3, 1', () {
    final rects = callTileRects(7, phone);
    final counts = <double, int>{};
    for (final r in rects) {
      counts.update(r.top, (c) => c + 1, ifAbsent: () => 1);
    }
    expect(counts.values.toList(), [3, 2, 2]);
  });

  test('nothing to lay out lays out nothing', () {
    expect(callTileRects(0, phone), isEmpty);
    expect(callTileRects(3, Size.zero), isEmpty);
  });

  testWidgets('each tile learns how much of the chrome covers it',
      (tester) async {
    final covers = <String, EdgeInsets>{};
    Widget probe(String id) => Builder(
          key: ValueKey(id),
          builder: (context) {
            covers[id] = CallTileCover.of(context);
            return const SizedBox.expand();
          },
        );
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.fromSize(
          size: phone,
          child: CallTileLayout(
            covered: const EdgeInsets.only(top: 100, bottom: 250),
            children: [probe('a'), probe('b')],
          ),
        ),
      ),
    ));
    // Stacked: the header over the top one, the tray over the bottom one.
    expect(covers['a'], const EdgeInsets.only(top: 100));
    expect(covers['b'], const EdgeInsets.only(bottom: 250));
  });
}
