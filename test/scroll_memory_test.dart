import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/screens/navigation/scroll_memory.dart';

/// The bounce these exist for: a section's State is destroyed on every tab
/// switch, so scroll position survived only through `PageStorageKey` — which
/// re-applies the saved offset BEFORE layout, discovers it is out of range
/// once the extent is known, and animates the correction under bouncing
/// physics. That settle is what reads as a glitch on returning to a list you
/// had scrolled to the bottom of.
Widget host(ScrollController c, int items) => MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: c,
          itemCount: items,
          itemBuilder: (_, i) => SizedBox(height: 100, child: Text('$i')),
        ),
      ),
    );

/// A REAL tab switch: the old tree is torn down before the new one is built.
///
/// Without this step `pumpWidget` reuses the element tree and the scroll
/// position carries over on its own — which made an early version of these
/// tests pass for the wrong reason, proving nothing about [ScrollMemory].
Future<void> switchAway(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  testWidgets('restores where you were', (t) async {
    final a = ScrollMemory.controller();
    await t.pumpWidget(host(a, 50));
    a.jumpTo(1200);
    await t.pump();
    ScrollMemory.save('k1', a);
    await switchAway(t);

    // The switch: old tree gone, brand-new controller, same content.
    final b = ScrollMemory.controller();
    ScrollMemory.restore('k1', b);
    await t.pumpWidget(host(b, 50));
    await t.pumpAndSettle();
    expect(b.position.pixels, 1200);
  });

  testWidgets('clamps when the content got SHORTER, without animating',
      (t) async {
    final a = ScrollMemory.controller();
    await t.pumpWidget(host(a, 50));
    a.jumpTo(4400); // at the bottom of 50 items
    await t.pump();
    ScrollMemory.save('k2', a);
    await switchAway(t);

    // Come back to a shorter list — the case that produced the bounce.
    final b = ScrollMemory.controller();
    ScrollMemory.restore('k2', b);
    await t.pumpWidget(host(b, 20));
    // ONE frame after layout. A ballistic correction would still be running
    // here; a jump has already finished.
    await t.pump();
    await t.pump();
    expect(b.position.pixels, b.position.maxScrollExtent,
        reason: 'lands exactly at the new bottom');
    expect(b.position.activity?.isScrolling ?? false, isFalse,
        reason: 'settled, not mid-animation — that animation IS the bounce');
  });

  testWidgets('does nothing when nothing was saved', (t) async {
    final c = ScrollMemory.controller();
    ScrollMemory.restore('never-seen', c);
    await t.pumpWidget(host(c, 30));
    await t.pumpAndSettle();
    expect(c.position.pixels, 0);
  });

  testWidgets('keeps sections separate', (t) async {
    final a = ScrollMemory.controller();
    await t.pumpWidget(host(a, 50));
    a.jumpTo(900);
    await t.pump();
    ScrollMemory.save('feed', a);
    await switchAway(t);

    final b = ScrollMemory.controller();
    ScrollMemory.restore('discover', b); // different key — must not apply
    await t.pumpWidget(host(b, 50));
    await t.pumpAndSettle();
    expect(b.position.pixels, 0);
  });
}
