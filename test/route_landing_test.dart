import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/route_landing.dart';

/// What this pins: **a route that has not moved yet must not claim to be
/// finished.**
///
/// `HeroController` parks an arriving route offstage for one frame so it can
/// measure where the heroes are going to land, and `TransitionRoute.offstage`
/// swaps the route's animation for `kAlwaysCompleteAnimation` while it is
/// there. So on precisely the frame a hero flight is being set up — the one
/// frame that matters most to everything built on top of this — a route that
/// is about to animate reports `isCompleted`.
///
/// Three screens read their own route animation during their first build and
/// latched on that lie, so their "do less while the flight is in the air"
/// deferrals had quietly never run. Nothing looked broken; the work just
/// happened at the worst possible moment instead of the best one. `a hero
/// flight does not count as having landed` is the test that would have caught
/// it.
class _Probe extends StatefulWidget {
  const _Probe({this.unlandsOnExit = false});

  final bool unlandsOnExit;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with RouteLanding {
  @override
  bool get unlandsOnExit => widget.unlandsOnExit;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Hero(tag: 'probe', child: SizedBox(width: 40, height: 40)),
          Text(landed ? 'landed' : 'moving', textDirection: TextDirection.ltr),
        ],
      ),
    ),
  );
}

void main() {
  /// A first page with a matching hero, so a push really does start a flight.
  Widget app({bool unlandsOnExit = false, bool withHero = true}) => MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            if (withHero)
              const Hero(tag: 'probe', child: SizedBox(width: 80, height: 80)),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _Probe(unlandsOnExit: unlandsOnExit),
                ),
              ),
              child: const Text('open'),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('a hero flight does not count as having landed', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));

    await tester.pump(); // the offstage frame — where the animation lies
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('moving'),
      findsOneWidget,
      reason: 'the route is a fifth of the way in, whatever it says about '
          'itself while HeroController has it offstage',
    );

    await tester.pumpAndSettle();
    expect(find.text('landed'), findsOneWidget);
  });

  testWidgets('nor does an ordinary transition with no hero at all', (
    tester,
  ) async {
    await tester.pumpWidget(app(withHero: false));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('moving'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('landed'), findsOneWidget);
  });

  testWidgets('by default a route stays landed on the way out', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('landed'))).pop();
    await tester.pump();

    expect(
      find.text('landed'),
      findsOneWidget,
      reason: 'nothing to reconsider on the way out for most callers',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('unlandsOnExit gives the pop its frame back', (tester) async {
    await tester.pumpWidget(app(unlandsOnExit: true));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('landed'), findsOneWidget);

    Navigator.of(tester.element(find.text('landed'))).pop();
    // One frame, because that is all the room there is: Flutter looks for
    // flight candidates in the post-frame callback of the frame the pop
    // starts on.
    await tester.pump();

    expect(find.text('moving'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
