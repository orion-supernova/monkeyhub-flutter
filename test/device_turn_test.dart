import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/device_turn.dart';

/// The camera holds portrait while the phone turns; only its glyphs turn.
/// These pin the one convention the preview, the glyphs and the focus point
/// all share, so none of them can drift from the others.
void main() {
  test('one turn per quarter, matching the plugin\'s CameraPreview', () {
    expect(quarterTurnsFor(DeviceOrientation.portraitUp), 0);
    expect(quarterTurnsFor(DeviceOrientation.landscapeRight), 1);
    expect(quarterTurnsFor(DeviceOrientation.portraitDown), 2);
    expect(quarterTurnsFor(DeviceOrientation.landscapeLeft), 3);
  });

  test('glyphs turn against the phone, the opposite of the preview', () {
    // Phone top on the left (turned counter-clockwise): the glyph turns a
    // quarter clockwise to stay level. Sharing the preview's map spun every
    // camera button the wrong way.
    expect(glyphTurnsFor(DeviceOrientation.portraitUp), 0);
    expect(glyphTurnsFor(DeviceOrientation.landscapeLeft), 1);
    expect(glyphTurnsFor(DeviceOrientation.portraitDown), 2);
    expect(glyphTurnsFor(DeviceOrientation.landscapeRight), 3);
  });

  test('unturning undoes a clockwise turn of the picture', () {
    // A clockwise quarter turn sends (x, y) to (1 - y, x).
    Offset turn(Offset p) => Offset(1 - p.dy, p.dx);
    const p = Offset(0.2, 0.7);
    for (var k = 0; k < 4; k++) {
      var turned = p;
      for (var i = 0; i < k; i++) {
        turned = turn(turned);
      }
      final back = unturnNormalised(turned, k);
      expect(back.dx, closeTo(p.dx, 1e-9), reason: 'k=$k');
      expect(back.dy, closeTo(p.dy, 1e-9), reason: 'k=$k');
    }
    expect(unturnNormalised(p, 0), p);
  });

  double angleOf(WidgetTester tester) {
    final r = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
    return r.turns;
  }

  Widget host(int turns) => Directionality(
        textDirection: TextDirection.ltr,
        child: DeviceTurn(
          quarterTurns: turns,
          child: const TurnWithDevice(child: SizedBox.square(dimension: 40)),
        ),
      );

  testWidgets('turns the short way round, never three quarters',
      (tester) async {
    await tester.pumpWidget(host(0));
    expect(angleOf(tester), 0);

    // Portrait to landscape-left: a quarter back, not three forward.
    await tester.pumpWidget(host(3));
    expect(angleOf(tester), -0.25);

    // And on to upside down keeps going the same way.
    await tester.pumpWidget(host(2));
    expect(angleOf(tester), -0.5);

    await tester.pumpWidget(host(0));
    expect(angleOf(tester).abs() % 1, 0);
    expect((angleOf(tester) - (-0.5)).abs(), lessThanOrEqualTo(0.5));
  });

  testWidgets('without a DeviceTurn, upright and still', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: TurnWithDevice(child: SizedBox.square(dimension: 40)),
    ));
    expect(angleOf(tester), 0);
  });
}
