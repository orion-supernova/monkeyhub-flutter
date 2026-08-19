import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/screens/navigation/route_return.dart';

/// Discover fetches its public-room list once, in `initState`, and a pushed
/// route leaves the screen underneath fully alive. So going into a public room,
/// setting it to private and backing out left Discover still advertising it —
/// nothing had re-run since the screen was built. Switching sections happened
/// to fix it, because that disposes the screen, which is what made the bug look
/// intermittent rather than simply broken.
///
/// These pin the mechanism that closes it, and the two places it must stay
/// quiet: while the screen is only being covered, and after it is gone.
void main() {
  late List<String> events;

  Widget harness() => MaterialApp(
    navigatorObservers: [appRoutes],
    home: _Watcher(events: events),
    routes: {'/next': (_) => const Scaffold(body: Text('next'))},
  );

  setUp(() => events = []);

  testWidgets('a popped route refreshes the screen underneath', (t) async {
    await t.pumpWidget(harness());
    expect(events, isEmpty, reason: 'mounting is initState\'s job, not ours');

    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamed('/next');
    await t.pumpAndSettle();
    expect(
      events,
      isEmpty,
      reason: 'being covered is not returning — nobody can see the result',
    );

    nav.pop();
    await t.pumpAndSettle();
    expect(events, ['refresh']);
  });

  testWidgets('every trip back refreshes, not just the first', (t) async {
    // The list can go stale again the second time just as easily as the first.
    await t.pumpWidget(harness());
    final nav = t.state<NavigatorState>(find.byType(Navigator));

    for (var i = 0; i < 3; i++) {
      nav.pushNamed('/next');
      await t.pumpAndSettle();
      nav.pop();
      await t.pumpAndSettle();
    }
    expect(events, ['refresh', 'refresh', 'refresh']);
  });

  testWidgets('a dialog on top does not count as a route to return from', (
    t,
  ) async {
    // `RouteObserver<PageRoute>` filters these out on purpose: Discover's own
    // password sheet and child-approval gate are not pushed pages, and firing a
    // refetch every time one is dismissed would spend a round trip on nothing.
    await t.pumpWidget(harness());
    final ctx = t.element(find.text('watching'));

    showDialog<void>(context: ctx, builder: (_) => const Text('gate'));
    await t.pumpAndSettle();
    Navigator.of(ctx, rootNavigator: true).pop();
    await t.pumpAndSettle();

    expect(events, isEmpty);
  });

  testWidgets('unsubscribes on dispose', (t) async {
    // A screen that stayed registered would be a retained State the observer
    // calls into forever — the leak shape this whole file exists next to.
    await t.pumpWidget(harness());
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    await t.pumpAndSettle();
    expect(events, isEmpty);
  });
}

/// A stand-in for Discover: the one thing it does with the mixin is refetch.
class _Watcher extends StatefulWidget {
  const _Watcher({required this.events});
  final List<String> events;

  @override
  State<_Watcher> createState() => _WatcherState();
}

class _WatcherState extends State<_Watcher> with RefreshOnReturn<_Watcher> {
  @override
  void onReturnToScreen() => widget.events.add('refresh');

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('watching')));
}
