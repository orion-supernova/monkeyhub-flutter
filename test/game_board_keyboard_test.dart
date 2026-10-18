import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// A daily board can be played from a keyboard: arrows move a ring around the
/// grid, Space or Enter is the tap, F the long press (Minesweeper's flag), and
/// anything else is offered to the game with the square under the ring. A
/// right click is the long press too.
void main() {
  Widget host(GameBoardSurface board) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Center(child: SizedBox.square(dimension: 300, child: board)),
    ),
  );

  CustomPainter painter() => _Blank();

  testWidgets('arrows show the ring first, then move it; Space taps there', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(
      host(GameBoardSurface(n: 5, painter: painter(), onTapCell: taps.add)),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, [0], reason: 'the first arrow only shows where the ring is');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, [0, 6]);

    // Edges hold: no wrapping to the next row.
    for (var i = 0; i < 8; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, [0, 6, 5]);
  });

  testWidgets('a select board selects as the ring moves; digits reach the '
      'game with the square', (tester) async {
    final taps = <int>[];
    final keys = <(int, int?)>[];
    await tester.pumpWidget(
      host(
        GameBoardSurface(
          n: 6,
          painter: painter(),
          onTapCell: taps.add,
          keyboardSelects: true,
          onCellKey: (cell, key) {
            final d = digitOfKey(key);
            if (d == null) return false;
            keys.add((cell, d));
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(taps, [0, 6]);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(keys, [(6, 4), (6, 2), (6, 0)]);
    // Space is not a tap on a select board: the square is already selected.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, [0, 6]);
  });

  testWidgets('F and a right click are the long press; chords pass through', (
    tester,
  ) async {
    final flags = <int>[];
    final taps = <int>[];
    await tester.pumpWidget(
      host(
        GameBoardSurface(
          n: 3,
          painter: painter(),
          onTapCell: taps.add,
          onLongPressCell: flags.add,
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    expect(flags, [0]);

    // Bottom-right square of a 300px 3x3 board.
    final at = tester.getTopLeft(find.byType(GameBoardSurface)) +
        const Offset(250, 250);
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pump();
    expect(flags, [0, 8]);
    expect(taps, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    expect(flags, [0, 8], reason: '⌘F belongs to the app');
  });
}

class _Blank extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(_Blank old) => false;
}
