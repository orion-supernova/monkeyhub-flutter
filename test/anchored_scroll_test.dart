import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/anchored_scroll.dart';

/// [snapToIndex] exists because `Scrollable.ensureVisible` silently does
/// nothing for a row `ListView.builder` hasn't laid out — which is exactly the
/// case "jump to the quoted message" hits whenever the quote is more than a
/// screen away. These tests pin the two properties that matter: it lands on
/// rows that were never built, and it lands on them at any distance and in
/// either direction.
void main() {
  const rowCount = 600;

  // Deliberately uneven heights: a uniform list would let a naive
  // total/count estimate succeed by accident.
  double heightOf(int i) => 40.0 + (i % 7) * 18.0;

  final keys = <int, GlobalKey>{};

  Widget harness(
    ScrollController controller, {
    required bool reverse,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    keys.clear();
    return MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: controller,
          reverse: reverse,
          padding: padding,
          itemCount: rowCount,
          itemBuilder: (context, i) => KeyedSubtree(
            key: keys.putIfAbsent(i, () => GlobalKey(debugLabel: 'row-$i')),
            child: SizedBox(height: heightOf(i), child: Text('row $i')),
          ),
        ),
      ),
    );
  }

  Future<bool> snap(
    WidgetTester tester,
    ScrollController c,
    int target, {
    double alignment = 0.3,
  }) async {
    late bool landed;
    // Pumped rather than awaited directly: the helper drives frames itself.
    final pending = snapToIndex(
      controller: c,
      targetIndex: () => target,
      itemCount: () => rowCount,
      targetContext: () => keys[target]?.currentContext,
      probes: () => [
        for (final e in keys.entries)
          if (e.value.currentContext != null)
            (index: e.key, context: e.value.currentContext!),
      ],
      alignment: alignment,
      settle: const Duration(milliseconds: 100),
    ).then((v) => landed = v);
    await tester.pumpAndSettle();
    await pending;
    return landed;
  }

  testWidgets('lands on a row hundreds of items away that was never built', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(harness(controller, reverse: false));

    expect(keys[500]?.currentContext, isNull, reason: 'not built yet');
    expect(await snap(tester, controller, 500), isTrue);
    expect(find.text('row 500'), findsOneWidget);
  });

  testWidgets('works the same on a reversed list (the chat transcript)', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(harness(controller, reverse: true));

    expect(await snap(tester, controller, 420), isTrue);
    expect(find.text('row 420'), findsOneWidget);
  });

  testWidgets('comes back down again — jumps are not one-way', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(harness(controller, reverse: true));

    expect(await snap(tester, controller, 380), isTrue);
    expect(await snap(tester, controller, 12), isTrue);
    expect(find.text('row 12'), findsOneWidget);
  });

  testWidgets('a row already on screen just settles into view', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(harness(controller, reverse: false));

    expect(keys[2]?.currentContext, isNotNull);
    expect(await snap(tester, controller, 2), isTrue);
    expect(find.text('row 2'), findsOneWidget);
  });

  testWidgets('reports failure instead of hanging when the row is gone', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(harness(controller, reverse: true));

    final landed = snapToIndex(
      controller: controller,
      targetIndex: () => null, // no such row — e.g. deleted mid-jump
      itemCount: () => rowCount,
      targetContext: () => null,
      probes: () => const [],
    );
    await tester.pumpAndSettle();
    expect(await landed, isFalse);
  });

  group('centredAlignment', () {
    test('no chrome is a plain centre, either way up', () {
      expect(centredAlignment(viewport: 600, extent: 40), 0.5);
      expect(centredAlignment(viewport: 600, extent: 40, reverse: true), 0.5);
    });

    test('equal chrome top and bottom changes nothing', () {
      expect(
        centredAlignment(
            viewport: 600, extent: 40, top: 80, bottom: 80, reverse: true),
        closeTo(0.5, 1e-9),
      );
    });

    test('a reversed list measures from the bottom', () {
      final down =
          centredAlignment(viewport: 600, extent: 40, top: 120, bottom: 20);
      final up = centredAlignment(
          viewport: 600, extent: 40, top: 120, bottom: 20, reverse: true);
      expect(down + up, closeTo(1, 1e-9));
      expect(down, greaterThan(0.5), reason: 'a tall header pushes it down');
    });

    test('a row taller than the viewport cannot be centred and does not try',
        () {
      expect(centredAlignment(viewport: 300, extent: 400), 0.5);
    });
  });

  // The unread landing: a line in the MIDDLE of what the reader can see, in a
  // transcript whose top and bottom are covered by glass of different heights.
  testWidgets('centres a row in the band the chrome leaves visible', (
    tester,
  ) async {
    final controller = ScrollController();
    const top = 140.0, bottom = 60.0;
    await tester.pumpWidget(harness(
      controller,
      reverse: true,
      padding: const EdgeInsets.only(top: top, bottom: bottom),
    ));
    final viewport = controller.position.viewportDimension;
    const target = 300;

    expect(
      await snap(
        tester,
        controller,
        target,
        alignment: centredAlignment(
          viewport: viewport,
          extent: heightOf(target),
          top: top,
          bottom: bottom,
          reverse: true,
        ),
      ),
      isTrue,
    );

    final rect = tester.getRect(find.text('row $target'));
    expect(rect.center.dy, closeTo((top + viewport - bottom) / 2, 1));
  });

  testWidgets('clamps at the bottom when there is not enough below it', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(harness(controller, reverse: true));
    final viewport = controller.position.viewportDimension;

    // Row 1 sits a row above the newest: centring it would need the list to
    // scroll past its own bottom, so it stays where the bottom leaves it.
    expect(
      await snap(
        tester,
        controller,
        1,
        alignment: centredAlignment(
          viewport: viewport,
          extent: heightOf(1),
          reverse: true,
        ),
      ),
      isTrue,
    );
    expect(controller.position.pixels, 0);
    expect(find.text('row 1'), findsOneWidget);
  });
}
