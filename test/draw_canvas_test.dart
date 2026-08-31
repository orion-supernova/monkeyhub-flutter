import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/draw/draw_canvas.dart';
import 'package:monkeyhub/calls/draw/draw_model.dart';
import 'package:monkeyhub/calls/draw/draw_wire.dart';

/// The canvas over a shared screen: a finger draws in frame fractions, and
/// the dust it leaves runs a ticker only while there is dust.
void main() {
  test('contain-fit puts the frame where the video is', () {
    // Landscape video in a portrait box: full width, letterboxed.
    final r = fittedVideoRect(const Size(1920, 1080), const Size(400, 800));
    expect(r.left, 0);
    expect(r.width, 400);
    expect(r.height, closeTo(225, 0.01));
    expect(r.top, closeTo((800 - 225) / 2, 0.01));
    // Portrait video in a landscape box: full height, pillarboxed.
    final p = fittedVideoRect(const Size(1080, 1920), const Size(800, 400));
    expect(p.top, 0);
    expect(p.height, 400);
    expect(p.width, closeTo(225, 0.01));
    expect(p.left, closeTo((800 - 225) / 2, 0.01));
    // No frame yet: the whole box.
    expect(fittedVideoRect(Size.zero, const Size(10, 20)),
        const Rect.fromLTWH(0, 0, 10, 20));
  });

  Widget host(Widget child, {required Size size, bool calm = false}) =>
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: calm),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: size.width, height: size.height, child: child),
            ),
          ),
        ),
      );

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final g = await tester.startGesture(from);
    await tester.pump();
    await g.moveTo(to);
    await tester.pump();
    await g.up();
    await tester.pump();
  }

  testWidgets('an armed pan produces begin/append/end in frame fractions',
      (tester) async {
    final model = DrawModel();
    final sent = <DrawOp>[];
    model.onOutbound = sent.addAll;

    // Landscape frame.
    await tester.pumpWidget(host(
      DrawCanvas(model: model, armed: true, inkColor: const Color(0xFF00AAFF)),
      size: const Size(400, 200),
    ));
    await drag(tester, const Offset(100, 50), const Offset(300, 150));
    await tester.pump(const Duration(milliseconds: 50));
    expect(model.strokes.length, 1);
    final s = model.strokes.single;
    expect(s.endedAt, isNotNull);
    expect(s.x(0), closeTo(0.25, 1e-3));
    expect(s.y(0), closeTo(0.25, 1e-3));
    expect(s.x(s.length - 1), closeTo(0.75, 1e-3));
    expect(s.y(s.length - 1), closeTo(0.75, 1e-3));
    expect(sent.first, isA<StrokeBegin>());
    expect(sent.last, isA<StrokeEnd>());
    expect(sent.whereType<StrokeAppend>(), isNotEmpty);

    // Portrait frame: the same screen point is a different fraction.
    sent.clear();
    await tester.pumpWidget(host(
      DrawCanvas(model: model, armed: true, inkColor: const Color(0xFF00AAFF)),
      size: const Size(200, 400),
    ));
    await drag(tester, const Offset(100, 300), const Offset(150, 350));
    await tester.pump(const Duration(milliseconds: 50));
    final s2 = model.strokes.last;
    expect(s2.x(0), closeTo(0.5, 1e-3));
    expect(s2.y(0), closeTo(0.75, 1e-3));
    model.dispose();
  });

  testWidgets('unarmed, the canvas takes no hits', (tester) async {
    final model = DrawModel();
    await tester.pumpWidget(host(
      DrawCanvas(model: model, armed: false, inkColor: const Color(0xFF00AAFF)),
      size: const Size(400, 200),
    ));
    await drag(tester, const Offset(100, 50), const Offset(300, 150));
    await tester.pump(const Duration(milliseconds: 50));
    expect(model.strokes, isEmpty);
    model.dispose();
  });

  /// A finished stroke from a peer, clocked from [born].
  DrawModel finishedStroke(DateTime born) {
    var now = born;
    final model = DrawModel()..clock = () => now;
    model.apply('peer', [
      StrokeBegin(
        strokeId: 1,
        argb: 0xFFFF3300,
        width: 0.01,
        points: Float32List.fromList([0.1, 0.5, 0.9, 0.5]),
      ),
      const StrokeEnd(strokeId: 1),
    ]);
    // The clock is advanced by the test through this closure.
    model.clock = () => now;
    _clocks[model] = (DateTime t) => now = t;
    return model;
  }

  testWidgets('full motion: dust runs one ticker, then none', (tester) async {
    final born = DateTime(2026, 3, 1, 12);
    final model = finishedStroke(born);
    await tester.pumpWidget(host(
      DrawCanvas(model: model, armed: false, inkColor: const Color(0xFF00AAFF)),
      size: const Size(400, 200),
    ));
    expect(tester.binding.transientCallbackCount, 0);

    // Cross into the dissolve: the model's timer fires, the canvas dusts.
    _clocks[model]!(born.add(const Duration(milliseconds: 2600)));
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    final state = tester.state<State<DrawCanvas>>(find.byType(DrawCanvas))
        as dynamic;
    expect(state.debugMotes, greaterThan(0));
    expect(tester.binding.transientCallbackCount, 1);

    // The motes die within a second and take the ticker with them.
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(state.debugMotes, 0);
    expect(tester.binding.transientCallbackCount, 0);
    model.dispose();
  });

  testWidgets('calm motion: no dust, no ticker', (tester) async {
    final born = DateTime(2026, 3, 1, 12);
    final model = finishedStroke(born);
    await tester.pumpWidget(host(
      DrawCanvas(model: model, armed: false, inkColor: const Color(0xFF00AAFF)),
      size: const Size(400, 200),
      calm: true,
    ));
    _clocks[model]!(born.add(const Duration(milliseconds: 2600)));
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pump();
    final state = tester.state<State<DrawCanvas>>(find.byType(DrawCanvas))
        as dynamic;
    expect(state.debugMotes, 0);
    expect(tester.binding.transientCallbackCount, 0);
    model.dispose();
  });
}

/// Per-model clock setters, so [finishedStroke] can hand back a model whose
/// time the test still controls.
final Map<DrawModel, void Function(DateTime)> _clocks = {};
