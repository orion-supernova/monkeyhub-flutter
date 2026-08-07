import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/games_store.dart';

/// [GamesStore] must never mark a listener dirty in the middle of a build.
///
/// This is not a hypothetical. Every game screen kicks `GamesStore.load` off
/// from `initState`, and `load` settles a little state — the day key, the
/// loading flag, a cleared board across a rollover — *before* its first
/// `await`. That puts a `notifyListeners()` in the same call stack as the build
/// that is mounting the screen. `FeedScreen` is still listening from behind the
/// new route, so it gets marked dirty mid-build and Flutter throws
/// "setState() or markNeedsBuild() called during build" — which it did, on the
/// first tap of a game tile.
///
/// The store is a singleton reached from anywhere, so the guard belongs on the
/// store rather than on each of the call sites that would otherwise each have
/// to remember to schedule their own post-frame callback.
void main() {
  late int seen;

  void count() => seen++;

  setUp(() {
    seen = 0;
    GamesStore.instance.addListener(count);
  });

  tearDown(() => GamesStore.instance.removeListener(count));

  testWidgets('a store poked while a screen mounts does not throw', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _Listener(
          child: _PokesOnMount(poke: () => GamesStore.instance.clear()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the notification still lands, one frame later', (tester) async {
    // Deferring must not mean dropping it: the whole point of the listener is
    // that the Feed's games band redraws when the store changes.
    await tester.pumpWidget(
      MaterialApp(
        home: _Listener(
          child: _PokesOnMount(poke: () => GamesStore.instance.clear()),
        ),
      ),
    );
    await tester.pump();

    expect(seen, greaterThan(0));
  });

  testWidgets('a poke outside a build notifies without waiting', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: _Listener(child: SizedBox())),
    );
    seen = 0;

    GamesStore.instance.clear();

    // No pump. Outside the build phase there is nothing to defer around, and
    // routing every notification through a microtask would put a frame's delay
    // on every ordinary update.
    expect(seen, 1);
  });
}

/// A widget already listening to the store, exactly as `FeedScreen` is while a
/// game screen mounts on top of it. The `setState` is what the store's
/// notification lands on, and what Flutter rejects mid-build.
class _Listener extends StatefulWidget {
  const _Listener({required this.child});

  final Widget child;

  @override
  State<_Listener> createState() => _ListenerState();
}

class _ListenerState extends State<_Listener> {
  @override
  void initState() {
    super.initState();
    GamesStore.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    GamesStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Stands in for a game screen: touches the store from `initState`, which runs
/// inside the parent's build.
class _PokesOnMount extends StatefulWidget {
  const _PokesOnMount({required this.poke});

  final VoidCallback poke;

  @override
  State<_PokesOnMount> createState() => _PokesOnMountState();
}

class _PokesOnMountState extends State<_PokesOnMount> {
  @override
  void initState() {
    super.initState();
    widget.poke();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
