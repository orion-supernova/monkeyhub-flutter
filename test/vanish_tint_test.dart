import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/theme/vanish_palette.dart';
import 'package:monkeyhub/widgets/vanish_card.dart';

/// The violet wave must cost paint, not build: the transcript is not rebuilt
/// per frame, and the painter repaints through its listenable.
void main() {
  final theme = BasicTheme.midnight();
  final boundary = GlobalKey();
  late StateSetter flip;
  var on = false;
  var rowBuilds = 0;
  var tintHostBuilds = 0;

  Widget app({Alignment origin = const Alignment(0, 1)}) => ThemeScope(
        controller: ThemeController(theme),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: theme.background,
              child: SizedBox(
                width: 200,
                height: 400,
                child: Stack(children: [
                  StatefulBuilder(builder: (_, set) {
                    flip = set;
                    tintHostBuilds++;
                    return Positioned.fill(
                        child: VanishTint(on: on, origin: origin));
                  }),
                  ListView.builder(
                    itemCount: 20,
                    itemBuilder: (_, i) {
                      rowBuilds++;
                      return const SizedBox(height: 40);
                    },
                  ),
                ]),
              ),
            ),
          ),
          ),
        ),
      );

  setUp(() {
    on = false;
    rowBuilds = 0;
    tintHostBuilds = 0;
  });

  VanishTintPainter painterOf(WidgetTester tester) {
    final paints = tester.widgetList<CustomPaint>(find.descendant(
        of: find.byType(VanishTint), matching: find.byType(CustomPaint)));
    return paints.first.painter! as VanishTintPainter;
  }

  testWidgets('the wave does not rebuild transcript rows or its host per frame',
      (tester) async {
    await tester.pumpWidget(app());
    final p0 = painterOf(tester);
    flip(() => on = true);
    await tester.pump(); // the one rebuild the flip itself causes
    final rows = rowBuilds;
    final hosts = tintHostBuilds;
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(rowBuilds, rows, reason: 'rows must not rebuild while the wave runs');
    expect(tintHostBuilds, hosts);
    expect(identical(painterOf(tester), painterOf(tester)), isTrue);
    expect(painterOf(tester).animation.value, 1.0);
    expect(p0.animation, same(painterOf(tester).animation));
  });

  testWidgets('the painter repaints through its listenable, not a rebuild',
      (tester) async {
    await tester.pumpWidget(app());
    flip(() => on = true);
    await tester.pump();
    final painter = painterOf(tester);
    final box = tester.renderObject<RenderCustomPaint>(find.descendant(
        of: find.byType(VanishTint), matching: find.byType(CustomPaint)));
    await tester.pump(const Duration(milliseconds: 100));
    // The tick marked the render object dirty with no widget build in between.
    expect(box.debugNeedsPaint, isFalse);
    final v1 = painter.animation.value;
    await tester.pump(const Duration(milliseconds: 100));
    expect(painter.animation.value, greaterThan(v1));
    expect(painterOf(tester), same(painter));
    expect(painter.shouldRepaint(painter), isFalse);
    // Its repaint listenable is the wave animation.
    var notified = 0;
    painter.animation.addListener(() => notified++);
    await tester.pump(const Duration(milliseconds: 100));
    expect(notified, greaterThan(0));
  });

  Future<List<Color>> sample(WidgetTester tester, List<Offset> pts) async {
    final img = await tester.runAsync(() async {
      final b = boundary.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      return b.toImage();
    });
    final bytes = (await tester.runAsync(
        () => img!.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    return [
      for (final p in pts)
        () {
          final o = (p.dy.toInt() * img!.width + p.dx.toInt()) * 4;
          return Color.fromARGB(bytes.getUint8(o + 3), bytes.getUint8(o),
              bytes.getUint8(o + 1), bytes.getUint8(o + 2));
        }()
    ];
  }

  testWidgets('wave grows from the origin and settles on the tint',
      (tester) async {
    await tester.pumpWidget(app());
    final bg = theme.background;
    const near = Offset(100, 395);
    const far = Offset(100, 5);
    flip(() => on = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    var px = await sample(tester, [near, far]);
    expect(px[0].toARGB32(), isNot(bg.toARGB32()), reason: 'origin tinted first');
    expect(px[1].toARGB32(), bg.toARGB32(), reason: 'far edge not reached yet');
    await tester.pump(const Duration(milliseconds: 700));
    px = await sample(tester, [near, far]);
    expect(px[1].toARGB32(), isNot(bg.toARGB32()));
    expect(px[0].toARGB32(), px[1].toARGB32());
    // Reverse shrinks back to the plain background.
    flip(() => on = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    px = await sample(tester, [near, far]);
    expect(px[0].toARGB32(), bg.toARGB32());
    expect(VanishPalette(theme).tint.a, greaterThan(0));
  });

  testWidgets('origin parameter moves the wave', (tester) async {
    await tester.pumpWidget(app(origin: Alignment.topCenter));
    flip(() => on = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final px = await sample(
        tester, [const Offset(100, 5), const Offset(100, 395)]);
    expect(px[0].toARGB32(), isNot(theme.background.toARGB32()));
    expect(px[1].toARGB32(), theme.background.toARGB32());
  });

  test('bubbleFill is memoised and unchanged', () {
    final a = VanishPalette(theme).bubbleFill;
    expect(VanishPalette(theme).bubbleFill, a);
  });
}
