import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/screens/review_route.dart';

/// The in-place review contract.
///
/// Taking a photo used to pop the camera and then push the editor, so the two
/// route animations overlapped and the chat flashed through the seam between
/// them — a shutter that looked like a bug. The fix is that the review surface
/// opens *over* the camera, instantly, and the camera stays behind it. Both
/// halves of that are asserted here: nothing animates, and the route underneath
/// is still alive to go back to.
void main() {
  final navigator = GlobalKey<NavigatorState>();

  Widget host(Route<void> Function() route) => MaterialApp(
    navigatorKey: navigator,
    home: Scaffold(
      // A bare GestureDetector, not a button: material ink runs an animation of
      // its own, and these tests are about which animations exist.
      body: Builder(
        builder: (context) => GestureDetector(
          onTap: () => Navigator.of(context).push(route()),
          child: const Text('camera'),
        ),
      ),
    ),
  );

  testWidgets('a review route is fully in place one frame after the push', (
    tester,
  ) async {
    await tester.pumpWidget(host(() => reviewRoute<void>(const Text('review'))));
    await tester.tap(find.text('camera'));
    await tester.pump();

    expect(find.text('review'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the camera it was pushed over is still there', (tester) async {
    await tester.pumpWidget(host(() => reviewRoute<void>(const Text('review'))));
    await tester.tap(find.text('camera'));
    await tester.pump();

    // skipOffstage: an opaque route on top takes the one below off the stage,
    // but taking it off the *stack* is what RETAKE could not survive.
    expect(find.text('camera', skipOffstage: false), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
  });

  testWidgets('leaving it is instant too — RETAKE reveals, it does not animate', (
    tester,
  ) async {
    await tester.pumpWidget(host(() => reviewRoute<void>(const Text('review'))));
    await tester.tap(find.text('camera'));
    await tester.pump();

    navigator.currentState!.pop();
    await tester.pump();

    expect(find.text('review'), findsNothing);
    expect(find.text('camera'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('an ordinary push still animates', (tester) async {
    await tester.pumpWidget(
      host(() => MaterialPageRoute(builder: (_) => const Text('review'))),
    );
    await tester.tap(find.text('camera'));
    await tester.pump();

    // The contrast that makes the assertions above mean something: a photo
    // from the library has no camera under it and presents normally.
    expect(tester.hasRunningAnimations, isTrue);
  });
}
