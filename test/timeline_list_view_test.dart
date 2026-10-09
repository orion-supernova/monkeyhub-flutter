import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/timeline_list_view.dart';

class _LoadedMedia extends StatefulWidget {
  const _LoadedMedia(this.id, this.mounts);
  final String id;
  final Map<String, int> mounts;
  @override
  State<_LoadedMedia> createState() => _LoadedMediaState();
}

class _LoadedMediaState extends State<_LoadedMedia> {
  @override
  void initState() {
    super.initState();
    widget.mounts.update(widget.id, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.id == 'row0' ? 320 : 80,
    child: Center(child: Text(widget.id)),
  );
}

void main() {
  testWidgets('newer pagination retains mounted media during a drag', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final mounts = <String, int>{};
    var rows = List.generate(30, (i) => 'row$i');
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return TimelineListView(
              controller: controller,
              rowKeys: [for (final row in rows) ValueKey(row)],
              itemBuilder: (context, i) => _LoadedMedia(rows[i], mounts),
            );
          },
        ),
      ),
    );
    controller.jumpTo(400);
    await tester.pump();
    final before = mounts['row3'];
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('row3')),
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    final anchorBefore = tester.getTopLeft(find.text('row3'));
    update(() => rows = [...List.generate(40, (i) => 'newest$i'), ...rows]);
    await tester.pump();
    expect(tester.getTopLeft(find.text('row3')), anchorBefore);
    expect(
      mounts['row3'],
      before,
      reason: 'loaded media must not remount at placeholder height',
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(TimelineListView),
      const Offset(0, 80),
      1000,
    );
    await tester.pump(const Duration(milliseconds: 16));
    final flingBefore = tester.getTopLeft(find.text('row3'));
    update(() => rows = [...List.generate(40, (i) => 'next$i'), ...rows]);
    await tester.pump();
    expect(tester.getTopLeft(find.text('row3')), flingBefore);
    final flingOffset = controller.offset;
    await tester.pump(const Duration(milliseconds: 32));
    expect(
      controller.offset,
      isNot(flingOffset),
      reason: 'pagination must keep the fling running',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a decoded image changing height preserves a held viewport', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var photoHeight = 320.0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return TimelineListView(
              controller: controller,
              rowKeys: [for (var i = 0; i < 30; i++) ValueKey('row$i')],
              itemBuilder: (context, i) => SizedBox(
                height: i == 0 ? photoHeight : 80,
                child: Center(child: Text('row$i')),
              ),
            );
          },
        ),
      ),
    );
    controller.jumpTo(400);
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('row3')),
    );
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    final before = tester.getTopLeft(find.text('row3'));
    update(() => photoHeight = 520);
    await tester.pump();
    expect(tester.getTopLeft(find.text('row3')), before);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(TimelineListView),
      const Offset(0, 80),
      1000,
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.position.isScrollingNotifier.value, isTrue);
    final ballisticBefore = tester.getTopLeft(find.text('row3'));
    update(() => photoHeight = 420);
    await tester.pump();
    expect(tester.getTopLeft(find.text('row3')), ballisticBefore);
    final offset = controller.offset;
    await tester.pump(const Duration(milliseconds: 32));
    expect(controller.offset, isNot(offset));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mixed-height history scrolls continuously across cache boundaries',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      late StateSetter update;
      const heights = [48.0, 420.0, 62.0, 300.0, 560.0, 80.0, 28.0];
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TimelineListView(
                controller: controller,
                rowKeys: [for (var i = 0; i < 100; i++) ValueKey(i)],
                itemBuilder: (context, i) => SizedBox(
                  height: heights[i % heights.length],
                  child: Text('mixed$i'),
                ),
              );
            },
          ),
        ),
      );
      controller.jumpTo(5000);
      await tester.pump();
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      for (var i = 0; i < 80; i++) {
        final offset = controller.offset;
        await gesture.moveBy(const Offset(0, -40));
        update(() {}); // Mirrors the floating date changing while scrolling.
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          controller.offset,
          closeTo(offset - 40, .01),
          reason: 'frame $i must follow the finger',
        );
        expect(tester.takeException(), isNull);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('older pagination does not move the resting transcript', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final mounts = <String, int>{};
    var rows = List.generate(30, (i) => 'row$i');
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return TimelineListView(
              controller: controller,
              rowKeys: [for (final row in rows) ValueKey(row)],
              itemBuilder: (context, i) => _LoadedMedia(rows[i], mounts),
            );
          },
        ),
      ),
    );
    controller.jumpTo(400);
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('row3'));
    final offset = controller.offset;
    update(() => rows = [...rows, 'older1', 'older2']);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('row3')), before);
    expect(controller.offset, offset);
  });

  testWidgets('landing on the bottom as new rows arrive follows the tail', (
    tester,
  ) async {
    // The frame a scroll-to-latest reaches 0 can be the frame a message
    // lands, the typing row toggles or a history window swaps back to live.
    // The anchor taken while still scrolled up must not push the
    // transcript back off the bottom it just reached.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final mounts = <String, int>{};
    var rows = List.generate(30, (i) => 'row$i');
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return TimelineListView(
              controller: controller,
              rowKeys: [for (final row in rows) ValueKey(row)],
              itemBuilder: (context, i) => _LoadedMedia(rows[i], mounts),
            );
          },
        ),
      ),
    );
    controller.jumpTo(400);
    await tester.pumpAndSettle();
    update(() => rows = ['newest', ...rows]);
    controller.jumpTo(0);
    await tester.pump();
    expect(controller.offset, 0);
    expect(find.text('newest'), findsOneWidget);
  });
}
