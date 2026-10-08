import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/drag_select.dart';

/// A 3×3 grid of 100pt tiles, ids t0..t8, selection held by the test.
class _Grid extends StatefulWidget {
  const _Grid({required this.onTap, this.initial = const {}});
  final ValueChanged<String> onTap;
  final Set<String> initial;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  late Set<String> selected = {...widget.initial};
  final ids = [for (var i = 0; i < 9; i++) 't$i'];

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 300,
            child: DragSelectRegion(
              ids: ids,
              selected: selected,
              selecting: selected.isNotEmpty,
              onChanged: (s) => setState(() => selected = s),
              child: GridView.count(
                crossAxisCount: 3,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final id in ids)
                    DragSelectTile(
                      id: id,
                      child: GestureDetector(
                        onTap: () => widget.onTap(id),
                        child: ColoredBox(color: Colors.grey, child: Text(id)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

Offset _center(int i) => Offset((i % 3) * 100 + 50, (i ~/ 3) * 100 + 50);

void main() {
  testWidgets('long press then drag picks the range in grid order',
      (tester) async {
    await tester.pumpWidget(_Grid(onTap: (_) {}));
    final state = tester.state<_GridState>(find.byType(_Grid));

    final g = await tester.startGesture(_center(1));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(state.selected, {'t1'});

    await g.moveTo(_center(4));
    await tester.pump();
    expect(state.selected, {'t1', 't2', 't3', 't4'});

    // Dragging back unpicks what it passes back over.
    await g.moveTo(_center(2));
    await tester.pump();
    expect(state.selected, {'t1', 't2'});
    await g.up();
  });

  testWidgets('a drag that starts on a picked tile unpicks', (tester) async {
    await tester.pumpWidget(
        _Grid(onTap: (_) {}, initial: {'t0', 't1', 't2', 't3'}));
    final state = tester.state<_GridState>(find.byType(_Grid));

    final g = await tester.startGesture(_center(1));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await g.moveTo(_center(3));
    await tester.pump();
    expect(state.selected, {'t0'});
    await g.up();
  });

  testWidgets('a tap still reaches the tile and selects nothing',
      (tester) async {
    String? tapped;
    await tester.pumpWidget(_Grid(onTap: (id) => tapped = id));
    final state = tester.state<_GridState>(find.byType(_Grid));
    await tester.tapAt(_center(5));
    await tester.pump();
    expect(tapped, 't5');
    expect(state.selected, isEmpty);
  });
}
