import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/input.dart';
import 'package:monkeyhub/fight/view/fight_controls.dart';
import 'package:monkeyhub/fight/view/fight_renderer.dart';

void main() {
  group('FightInput keyboard', () {
    test('maps keys to engine bits and clears on focus loss', () {
      final input = FightInput();
      input.onKey(const KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyD, logicalKey: LogicalKeyboardKey.keyD, timeStamp: Duration.zero));
      input.onKey(const KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyJ, logicalKey: LogicalKeyboardKey.keyJ, timeStamp: Duration.zero));
      expect(input.mask, Inp.right | Inp.light);
      input.onKey(const KeyUpEvent(physicalKey: PhysicalKeyboardKey.keyJ, logicalKey: LogicalKeyboardKey.keyJ, timeStamp: Duration.zero));
      expect(input.mask, Inp.right);
      input.clear();
      expect(input.mask, 0);
    });

    test('ignores unmapped keys', () {
      final input = FightInput();
      final r = input.onKey(const KeyDownEvent(physicalKey: PhysicalKeyboardKey.keyQ, logicalKey: LogicalKeyboardKey.keyQ, timeStamp: Duration.zero));
      expect(r, KeyEventResult.ignored);
      expect(input.mask, 0);
    });
  });

  group('FightTouchControls', () {
    Future<FightInput> pump(WidgetTester tester, {bool superReady = false}) async {
      final input = FightInput();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: FightTouchControls(input: input, superReady: ValueNotifier(superReady)),
            ),
          ),
        ),
      );
      return input;
    }

    Offset origin(WidgetTester tester) => tester.getTopLeft(find.byType(FightTouchControls));

    testWidgets('stick drag gives directions, release clears', (tester) async {
      final input = await pump(tester);
      final o = origin(tester);
      final g = await tester.startGesture(o + const Offset(80, 200));
      await g.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(input.mask, Inp.right);
      await g.moveBy(const Offset(-80, -60));
      await tester.pump();
      expect(input.mask, Inp.left | Inp.up);
      await g.up();
      await tester.pump();
      expect(input.mask, 0);
    });

    testWidgets('two thumbs: a direction and a button together', (tester) async {
      final input = await pump(tester);
      final o = origin(tester);
      final stick = await tester.startGesture(o + const Offset(80, 200), pointer: 1);
      await stick.moveBy(const Offset(0, 40));
      // Find the light button by scanning the right side for a press that
      // sets the light bit.
      TestGesture? btn;
      for (var x = 220.0; x < 400 && btn == null; x += 12) {
        for (var y = 120.0; y < 300; y += 12) {
          final g = await tester.startGesture(o + Offset(x, y), pointer: 2);
          await tester.pump();
          if (input.mask & Inp.light != 0) {
            btn = g;
            break;
          }
          await g.up();
          await tester.pump();
        }
      }
      expect(btn, isNotNull, reason: 'a light button exists on the right half');
      expect(input.mask & Inp.down, Inp.down);
      await btn!.up();
      await stick.up();
      await tester.pump();
      expect(input.mask, 0);
    });

    testWidgets('super cannot be pressed without meter', (tester) async {
      final input = await pump(tester);
      final o = origin(tester);
      var sawSuper = false;
      for (var x = 200.0; x < 400; x += 10) {
        for (var y = 0.0; y < 300; y += 10) {
          final g = await tester.startGesture(o + Offset(x, y));
          await tester.pump();
          if (input.mask & Inp.superBtn != 0) sawSuper = true;
          await g.up();
          await tester.pump();
        }
      }
      expect(sawSuper, isFalse);
    });
  });

  test('medianCut returns at most n averaged colours', () {
    final colors = [
      for (var i = 0; i < 200; i++) 0xff000000 | (i % 2 == 0 ? 0xff0000 : 0x0000ff),
    ];
    final pal = medianCut(colors, 8);
    expect(pal.length, lessThanOrEqualTo(8));
    expect(pal, containsAll([0xffff0000, 0xff0000ff]));
    expect(medianCut([], 8), isEmpty);
  });
}
