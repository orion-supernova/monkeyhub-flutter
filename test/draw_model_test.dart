import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/draw/draw_model.dart';
import 'package:monkeyhub/calls/draw/draw_wire.dart';
import 'package:monkeyhub/theme/basic_theme.dart';

/// A stroke's short life, and how the drawer's own ops leave the device.
void main() {
  final born = DateTime(2026, 3, 1, 12);

  /// A model whose clock is fakeAsync's.
  DrawModel modelOn(FakeAsync async) =>
      DrawModel()..clock = () => born.add(async.elapsed);

  Float32List pts(List<double> xy) => Float32List.fromList(xy);

  test('a stroke is sharp, then dissolves at 2.5 s, then is gone', () {
    fakeAsync((async) {
      final model = modelOn(async);
      var notified = 0;
      model.addListener(() => notified++);
      model.apply('peer', [
        StrokeBegin(
            strokeId: 1, argb: 0xFFFF0000, width: 0.01, points: pts([0, 0])),
        StrokeAppend(strokeId: 1, points: pts([0.5, 0.5])),
        const StrokeEnd(strokeId: 1),
      ]);
      expect(model.strokes.length, 1);
      final s = model.strokes.single;
      expect(s.length, 2);
      expect(s.endedAt, born);
      expect(model.dissolveT(s, model.clock()), 0);
      expect(model.anyDissolving, isFalse);
      expect(model.nextDeadline, born.add(DrawModel.lifetime));

      async.elapse(const Duration(milliseconds: 2400));
      expect(model.dissolveT(s, model.clock()), 0);
      expect(model.strokes.length, 1);

      // The model's own timer fires the repaint at the threshold.
      final before = notified;
      async.elapse(const Duration(milliseconds: 200));
      expect(notified, greaterThan(before));
      expect(model.dissolveT(s, model.clock()), greaterThan(0));
      expect(model.dissolveT(s, model.clock()), lessThan(1));
      expect(model.anyDissolving, isTrue);
      expect(model.strokes.length, 1);

      // ...and the prune at the end of the dissolve.
      async.elapse(const Duration(milliseconds: 600));
      expect(model.strokes, isEmpty);
      expect(model.nextDeadline, isNull);
      model.dispose();
    });
  });

  test('a stroke still under the finger never dissolves', () {
    fakeAsync((async) {
      final model = modelOn(async);
      model.apply('peer', [
        StrokeBegin(
            strokeId: 1, argb: 0xFFFF0000, width: 0.01, points: pts([0, 0])),
      ]);
      async.elapse(const Duration(seconds: 10));
      expect(model.strokes.length, 1);
      expect(model.dissolveT(model.strokes.single, model.clock()), 0);
      expect(model.nextDeadline, isNull);
      model.dispose();
    });
  });

  test('local ops apply at once and go out batched, appends folded', () {
    fakeAsync((async) {
      final model = modelOn(async);
      final sent = <List<DrawOp>>[];
      model.onOutbound = sent.add;

      final id = model.beginLocal(const Offset(0.1, 0.1),
          color: const Color(0xFF00FF00), width: 0.02);
      model.appendLocal(id, const Offset(0.2, 0.2));
      model.appendLocal(id, const Offset(0.3, 0.3));
      // Applied locally before anything is sent.
      expect(model.strokes.single.length, 3);
      expect(sent, isEmpty);

      async.flushMicrotasks();
      async.elapse(Duration.zero);
      expect(sent.length, 1);
      expect(sent.single.length, 2);
      expect(sent.single[0], isA<StrokeBegin>());
      final append = sent.single[1] as StrokeAppend;
      expect(append.points.length ~/ 2, 2);
      expect(append.points[2], closeTo(0.3, 1e-6));

      // Within the interval: nothing more goes out yet, however many points.
      model.appendLocal(id, const Offset(0.4, 0.4));
      model.appendLocal(id, const Offset(0.5, 0.5));
      async.elapse(const Duration(milliseconds: 10));
      expect(sent.length, 1);
      async.elapse(const Duration(milliseconds: 30));
      expect(sent.length, 2);
      expect((sent[1].single as StrokeAppend).points.length ~/ 2, 2);

      model.endLocal(id);
      async.elapse(const Duration(milliseconds: 40));
      expect(sent.length, 3);
      expect(sent[2].single, isA<StrokeEnd>());
      model.dispose();
    });
  });

  test('clearAll drops everyone\'s strokes and tells the peers', () {
    fakeAsync((async) {
      final model = modelOn(async);
      final sent = <List<DrawOp>>[];
      model.onOutbound = sent.add;
      model.apply('peer', [
        StrokeBegin(
            strokeId: 9, argb: 0xFF0000FF, width: 0.01, points: pts([0, 0])),
      ]);
      model.beginLocal(const Offset(0.5, 0.5),
          color: const Color(0xFF00FF00), width: 0.02);
      expect(model.strokes.length, 2);
      model.clearAll();
      expect(model.strokes, isEmpty);
      async.elapse(const Duration(milliseconds: 40));
      expect(sent.single.last, isA<DrawClear>());
      model.dispose();
    });
  });

  test('a stroke colour is stable per user and readable on any ground', () {
    final theme = BasicTheme.midnight();
    final a = drawColorFor('user-a', theme);
    expect(drawColorFor('user-a', theme), a);
    for (final id in ['user-a', 'user-b', 'someone-else', '']) {
      final l = HSLColor.fromColor(drawColorFor(id, theme)).lightness;
      expect(l, inInclusiveRange(0.48, 0.62), reason: id);
    }
  });
}
