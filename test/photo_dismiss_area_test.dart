import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/photo_dismiss_area.dart';

// 800×600 test screen, with a 400×200 "photo" letterboxed in its middle:
// x 200–600, y 200–400.
class _Harness {
  final drag = ValueNotifier(Offset.zero);
  var dismissed = 0;
  final zoom = <bool>[];

  Widget build() => MaterialApp(
        home: PhotoDismissArea(
          drag: drag,
          onDismiss: () => dismissed++,
          onZoomChanged: zoom.add,
          child: Container(
            key: const ValueKey('photo'),
            width: 400,
            height: 200,
            color: Colors.red,
          ),
        ),
      );
}

Matrix4 _matrix(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;

Future<void> _pinch(
  WidgetTester tester,
  Offset a,
  Offset b, {
  required double spread,
}) async {
  final g1 = await tester.startGesture(a, pointer: 1);
  final g2 = await tester.startGesture(b, pointer: 2);
  for (var i = 0; i < 10; i++) {
    await g1.moveBy(Offset(-spread / 10, 0));
    await g2.moveBy(Offset(spread / 10, 0));
    await tester.pump();
  }
  await g1.up();
  await g2.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a pinch on the black around the photo zooms it', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    // Both fingers well below the photo.
    await _pinch(tester, const Offset(350, 500), const Offset(450, 500),
        spread: 200);
    expect(_matrix(tester).getMaxScaleOnAxis(), greaterThan(1.5));
    expect(h.dismissed, 0);
  });

  testWidgets('a zoomed photo is not clipped to its letterbox', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    final viewer =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.clipBehavior, Clip.none);
    expect(tester.getSize(find.byType(InteractiveViewer)), const Size(800, 600));
  });

  testWidgets('a zoomed photo pans to its own edges, not the letterbox', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    // Double-tap zooms 2.5×: the photo is 1000×500, wider than the screen
    // but still shorter than it.
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(_matrix(tester).getMaxScaleOnAxis(), closeTo(2.5, 0.01));
    expect(h.zoom.last, isTrue);

    // Drag far right and far down.
    await tester.dragFrom(const Offset(400, 300), const Offset(2000, 2000));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const ValueKey('photo')));
    // Left edge stops at the screen edge rather than revealing black.
    expect(rect.left, closeTo(0, 0.5));
    // Shorter than the screen: stays vertically centred.
    expect(rect.center.dy, closeTo(300, 0.5));
    expect(h.dismissed, 0);
  });

  testWidgets('one finger dragged down dismisses', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.dragFrom(const Offset(400, 300), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(h.dismissed, 1);
  });

  testWidgets('a second finger turns a dismiss drag into a pinch', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    final g1 = await tester.startGesture(const Offset(400, 300), pointer: 1);
    for (var i = 0; i < 8; i++) {
      await g1.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    expect(h.drag.value.dy, greaterThan(0));
    final g2 = await tester.startGesture(const Offset(500, 460), pointer: 2);
    expect(h.zoom.last, isTrue, reason: 'two fingers lock the pager');
    for (var i = 0; i < 10; i++) {
      await g2.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    await g2.up();
    await g1.up();
    await tester.pumpAndSettle();
    expect(h.dismissed, 0);
    expect(h.drag.value, Offset.zero);
    expect(_matrix(tester).getMaxScaleOnAxis(), greaterThan(1.2));
  });
}
