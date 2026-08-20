import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/games/game_canvas.dart';

/// The Zip board is drawn on with a finger, and it lives inside the game
/// screen's scroll view. Those two facts fight: a [Scrollable] claims a
/// vertical drag once it has travelled 18 logical pixels and a stock pan only
/// claims one at 36, so before [GameBoardSurface] took its drags eagerly, a
/// stroke drawn *downward* never started at all — the page scrolled out from
/// under the finger instead — and a stroke drawn sideways only started after
/// most of a square had gone by. It read as "the board barely lets you draw".
///
/// These pin the two halves of the fix: the board wins the drags that begin on
/// it, and it fills in the squares between two reports of a fast one.
void main() {
  const side = 300.0;
  const n = 6;
  const cell = side / n;
  const key = ValueKey('board');

  late List<int> entered;
  late ScrollController scroll;

  setUp(() {
    entered = <int>[];
    scroll = ScrollController();
  });

  tearDown(() => scroll.dispose());

  /// The board, in a scroll view long enough to actually scroll — which is the
  /// point: a board with no page to compete with would pass these with the old
  /// gestures too.
  Widget board({bool claimsDrag = true}) => MaterialApp(
    home: Scaffold(
      body: ListView(
        controller: scroll,
        children: [
          // Short enough that the whole board is on screen at rest, long
          // enough below it that the page has somewhere to scroll to.
          const SizedBox(height: 100),
          SizedBox(
            width: side,
            height: side,
            child: GameBoardSurface(
              key: key,
              n: n,
              painter: _BlankBoard(),
              claimsDrag: claimsDrag,
              onDragTo: entered.add,
              onTapCell: entered.add,
            ),
          ),
          const SizedBox(height: 900),
        ],
      ),
    ),
  );

  Offset centerOf(WidgetTester tester, int index) =>
      tester.getTopLeft(find.byKey(key)) +
      Offset((index % n) * cell + cell / 2, (index ~/ n) * cell + cell / 2);

  /// Drags at the step size a finger actually produces — a pointer reports
  /// every few pixels, not once per square. That distinction is the whole
  /// test: at five pixels a report the page's drag recognizer passes its
  /// 18-pixel threshold three reports before a stock pan passes its 36, and
  /// takes the stroke. A single teleporting `moveTo` crosses both thresholds
  /// in the same report and hides the bug completely.
  Future<void> slide(
    WidgetTester tester,
    TestGesture gesture,
    Offset from,
    Offset to,
  ) async {
    final steps = ((to - from).distance / 5).ceil();
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
      await tester.pump();
    }
  }

  testWidgets('a downward stroke draws on the board instead of scrolling the '
      'page it sits in', (tester) async {
    await tester.pumpWidget(board());

    final gesture = await tester.startGesture(centerOf(tester, 0));
    await slide(tester, gesture, centerOf(tester, 0), centerOf(tester, 30));
    await gesture.up();
    await tester.pump();

    expect(entered, [0, 6, 12, 18, 24, 30]);
    expect(scroll.offset, 0);
  });

  testWidgets('a stroke that outruns the pointer reports still visits every '
      'square it crossed', (tester) async {
    await tester.pumpWidget(board());

    // One report for the whole flick — five squares in a single frame, which
    // is what a fast finger actually produces.
    final gesture = await tester.startGesture(centerOf(tester, 0));
    await gesture.moveTo(centerOf(tester, 30));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(entered, [0, 6, 12, 18, 24, 30]);
  });

  testWidgets('a cut corner is offered both ways round, never as a diagonal '
      'jump', (tester) async {
    await tester.pumpWidget(board());

    final gesture = await tester.startGesture(centerOf(tester, 0));
    await gesture.moveTo(centerOf(tester, 7));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // 1 and 6 are the two squares that turn the corner. They are diagonal to
    // each other, so a board can only ever take one of them.
    expect(entered, [0, 1, 6, 7]);
  });

  testWidgets('a board with nothing left to draw gives the page its drags '
      'back', (tester) async {
    await tester.pumpWidget(board(claimsDrag: false));

    final gesture = await tester.startGesture(centerOf(tester, 30));
    await slide(tester, gesture, centerOf(tester, 30), centerOf(tester, 0));
    await gesture.up();
    await tester.pump();

    expect(entered, isEmpty);
    expect(scroll.offset, greaterThan(0));
  });

  testWidgets('a tap still lands on the square under it', (tester) async {
    await tester.pumpWidget(board());

    await tester.tapAt(centerOf(tester, 21));
    await tester.pump();

    expect(entered, [21]);
    expect(scroll.offset, 0);
  });
}

class _BlankBoard extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
