import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/steady_hero.dart';

/// Pins the reason a photo blinked when it landed back in its bubble.
///
/// Flutter's default [Hero] placeholder is a bare `SizedBox`, and on a pop
/// *neither* end of the flight keeps its child: `heroes.dart` passes
/// `shouldIncludedChildInPlaceholder: false` for the popping hero and takes the
/// same default for the landing one. So the thumbnail a picture is flying home
/// to is torn out of the tree at take-off and built again from nothing on
/// touchdown — a fresh RemoteImage with no URL, no image stream, and a decode
/// that spent the flight with nothing holding it live in the ImageCache.
///
/// The first test is the bug, stated as behaviour. The second is the fix.
void main() {
  Widget app(GlobalKey<NavigatorState> nav, {required bool steady}) {
    const probe = _Probe(size: 40);
    return MaterialApp(
      navigatorKey: nav,
      home: Scaffold(
        body: Center(
          child: steady
              ? const SteadyHero(tag: 'photo', child: probe)
              : const Hero(tag: 'photo', child: probe),
        ),
      ),
    );
  }

  Future<void> flyThereAndBack(
    WidgetTester tester,
    GlobalKey<NavigatorState> nav,
  ) async {
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Center(
            child: Hero(tag: 'photo', child: _Probe(size: 300)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
  }

  // The home probe is the thumbnail a picture flies home to. If its State object
  // survives a round trip, the landing was a repaint; if a new one appears, the
  // subtree was destroyed mid-flight and rebuilt from nothing to be landed on —
  // and whatever it could not produce in that first frame is the blink.
  //
  // State identity, not a mount count: the flight's shuttle inflates copies of
  // the same widget in the overlay, so counting constructions counts those too.
  _ProbeState homeProbe(WidgetTester tester) =>
      tester.state<_ProbeState>(find.byType(_Probe));

  testWidgets('a plain Hero rebuilds the child it lands on', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(nav, steady: false));
    final before = homeProbe(tester);

    await flyThereAndBack(tester, nav);

    expect(
      identical(homeProbe(tester), before),
      isFalse,
      reason: 'expected a plain Hero to rebuild the child it lands on',
    );
  });

  testWidgets('SteadyHero carries the child through the flight', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(nav, steady: true));
    final before = homeProbe(tester);

    await flyThereAndBack(tester, nav);

    expect(
      identical(homeProbe(tester), before),
      isTrue,
      reason: 'the thumbnail should be carried through, not rebuilt',
    );
  });

  testWidgets('the held-open slot is sized, invisible and inert', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
          body: Center(
            child: SteadyHero(
              tag: 'photo',
              child: GestureDetector(
                onTap: () => taps++,
                child: const _Probe(size: 40),
              ),
            ),
          ),
        ),
      ),
    );

    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Center(
            child: Hero(tag: 'photo', child: _Probe(size: 300)),
          ),
        ),
      ),
    );
    // Mid-flight: the placeholder is what is standing in the home route.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final slot = find.descendant(
      of: find.byType(SteadyHero),
      matching: find.byType(GestureDetector),
    );

    // Still laid out, at the size the hero had when it took off — the slot in
    // the transcript keeps its shape while the picture is away.
    expect(tester.getSize(slot), const Size(40, 40));

    // Invisible: an Opacity of 0 paints nothing, so the picture is never on
    // screen in two places at once during a flight.
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: slot, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 0);

    // And inert: an invisible child is still hit-testable without the
    // IgnorePointer, which would let a tap re-open a picture that is in the air.
    await tester.tap(slot, warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);

    await tester.pumpAndSettle();
  });
}

class _Probe extends StatefulWidget {
  const _Probe({required this.size});
  final double size;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: widget.size, height: widget.size);
}
