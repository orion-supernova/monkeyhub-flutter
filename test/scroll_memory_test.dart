import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/screens/navigation/scroll_memory.dart';

/// Two bugs live here, and the tests have to model the real teardown to catch
/// either.
///
/// 1. THE BOUNCE. A section's State is destroyed on every tab switch, so
///    position survived only through `PageStorageKey` — which re-applies the
///    saved offset before layout, then animates the correction once the extent
///    turns out to be different. That settle is the bounce.
///
/// 2. THE RESET. The first fix saved on `dispose`, which loses the position
///    EVERY time: `SectionSwitcher` removes the outgoing section from the tree
///    to cross-fade it, and `hasClients` goes false at removal, before dispose
///    runs. So it must be recorded while the user is still scrolling.
Widget host(ScrollController c, int items) => MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: c,
          itemCount: items,
          itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
        ),
      ),
    );

/// A REAL tab switch: the outgoing tree is removed BEFORE anything else, which
/// is what detaches the controller. `pumpWidget` alone reuses the element tree
/// and the position carries over on its own — an early version of these tests
/// passed for that reason and proved nothing.
Future<void> switchAway(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('restores where you were', (t) async {
    final a = ScrollMemory.controller();
    ScrollMemory.attach('k1', a);
    await t.pumpWidget(host(a, 50));
    a.jumpTo(1200);
    await t.pump();
    await switchAway(t);

    final b = ScrollMemory.controller();
    ScrollMemory.attach('k1', b);
    await t.pumpWidget(host(b, 50));
    await t.pumpAndSettle();
    expect(b.position.pixels, 1200);
  });

  testWidgets('records while scrolling, not at teardown', (t) async {
    // The regression that reset all four tabs to the top. By the time a
    // section is disposed its controller is already detached, so anything
    // read at that point is nothing at all.
    final a = ScrollMemory.controller();
    ScrollMemory.attach('k2', a);
    await t.pumpWidget(host(a, 50));
    a.jumpTo(900);
    await t.pump();

    await t.pumpWidget(const SizedBox.shrink());
    expect(a.hasClients, isFalse,
        reason: 'detached before dispose — this is why saving there failed');

    final b = ScrollMemory.controller();
    ScrollMemory.attach('k2', b);
    await t.pumpWidget(host(b, 50));
    await t.pumpAndSettle();
    expect(b.position.pixels, 900,
        reason: 'the offset was recorded while it was still scrollable');
  });

  testWidgets('clamps when the content got SHORTER, without animating',
      (t) async {
    final a = ScrollMemory.controller();
    ScrollMemory.attach('k3', a);
    await t.pumpWidget(host(a, 50));
    a.jumpTo(4400); // the bottom of 50 items
    await t.pump();
    await switchAway(t);

    final b = ScrollMemory.controller();
    ScrollMemory.attach('k3', b);
    await t.pumpWidget(host(b, 20));
    await t.pump();
    await t.pump();
    expect(b.position.pixels, b.position.maxScrollExtent,
        reason: 'lands exactly at the new bottom');
    expect(b.position.activity?.isScrolling ?? false, isFalse,
        reason: 'settled, not mid-animation — that animation IS the bounce');
  });

  testWidgets('does nothing when nothing was recorded', (t) async {
    final c = ScrollMemory.controller();
    ScrollMemory.attach('never-seen', c);
    await t.pumpWidget(host(c, 30));
    await t.pumpAndSettle();
    expect(c.position.pixels, 0);
  });

  testWidgets('keeps sections separate', (t) async {
    final a = ScrollMemory.controller();
    ScrollMemory.attach('feed', a);
    await t.pumpWidget(host(a, 50));
    a.jumpTo(900);
    await t.pump();
    await switchAway(t);

    final b = ScrollMemory.controller();
    ScrollMemory.attach('discover', b); // different key — must not apply
    await t.pumpWidget(host(b, 50));
    await t.pumpAndSettle();
    expect(b.position.pixels, 0);
  });
}
