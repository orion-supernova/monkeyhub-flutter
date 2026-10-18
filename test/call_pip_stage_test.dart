import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/widgets/call_auto_hide.dart';
import 'package:monkeyhub/calls/widgets/call_pip_stage.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// The two pictures of a video call move, they never trade places in a
/// frame, and nothing behind them ever shows through mid-move.
void main() {
  const area = Size(400, 800);

  Widget stage({bool swapped = false, bool withMain = true}) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MediaQuery(
        data: const MediaQueryData(size: area),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: CallPipStage(
            main: withMain
                ? const ColoredBox(key: ValueKey('them'), color: Colors.red)
                : null,
            pip: const ColoredBox(key: ValueKey('you'), color: Colors.blue),
            swapped: swapped,
            onPipTap: () {},
            top: 60,
            bottom: 200,
          ),
        ),
      ),
      );

  Rect rectOf(WidgetTester t, String key) =>
      t.getRect(find.byKey(ValueKey(key)));

  testWidgets('the grow overshoots once and never dips back under',
      (tester) async {
    var crossed = false;
    for (var i = 0; i <= 100; i++) {
      final v = callPipGrowAt(i / 100);
      if (v >= 1) crossed = true;
      if (crossed) expect(v, greaterThanOrEqualTo(1 - 1e-9));
    }
    expect(callPipGrowCovers, inExclusiveRange(0.3, 0.9));
  });

  testWidgets('a swap flies the tile out and never uncovers the screen',
      (tester) async {
    tester.view.physicalSize = area;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(stage());
    expect(rectOf(tester, 'them'), Offset.zero & area);
    final pip = rectOf(tester, 'you');
    expect(pip.width, lessThan(area.width / 2));

    await tester.pumpWidget(stage(swapped: true));
    final full = Offset.zero & area;
    var grewThrough = false;
    for (var ms = 16; ms <= 640; ms += 16) {
      await tester.pump(const Duration(milliseconds: 16));
      final you = rectOf(tester, 'you');
      final them = rectOf(tester, 'them');
      // One of the two always covers the whole screen.
      final covered = you.contains(full.topLeft) &&
              you.right >= full.right - 0.5 &&
              you.bottom >= full.bottom - 0.5 ||
          them == full;
      expect(covered, isTrue, reason: 'uncovered at ${ms}ms');
      if (you.width > pip.width && you.width < area.width) grewThrough = true;
    }
    expect(grewThrough, isTrue, reason: 'the tile must fly, not jump');
    await tester.pumpAndSettle();
    expect(rectOf(tester, 'you'), full);
    expect(rectOf(tester, 'them').width, pip.width);
  });

  testWidgets('their picture landing shrinks yours into the corner',
      (tester) async {
    tester.view.physicalSize = area;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(stage(withMain: false));
    expect(rectOf(tester, 'you'), Offset.zero & area);
    await tester.pumpWidget(stage());
    await tester.pump(const Duration(milliseconds: 120));
    final mid = rectOf(tester, 'you');
    expect(mid.width, inExclusiveRange(120, area.width));
    await tester.pumpAndSettle();
    expect(rectOf(tester, 'you').width, lessThan(area.width / 2));
  });

  testWidgets('the corner tile follows a straight vertical drag',
      (tester) async {
    tester.view.physicalSize = area;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var flicks = 0;
    await tester.pumpWidget(GestureDetector(
      onVerticalDragEnd: (_) => flicks++,
      child: stage(),
    ));
    final start = rectOf(tester, 'you');
    final g = await tester.startGesture(start.center);
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(0, 25));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(flicks, 0, reason: 'the screen took the tile\'s drag');
    expect(rectOf(tester, 'you').top, greaterThan(area.height / 2));
  });

  testWidgets('the chrome hides itself over video and comes back on a tap',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Chrome()));
    expect(find.text('chrome'), findsOneWidget);
    await tester.pump(CallChromeAutoHide.after + const Duration(seconds: 1));
    expect(find.text('chrome'), findsNothing);
    await tester.tap(find.byType(_Chrome));
    await tester.pump();
    expect(find.text('chrome'), findsOneWidget);
  });
}

class _Chrome extends StatefulWidget {
  const _Chrome();

  @override
  State<_Chrome> createState() => _ChromeState();
}

class _ChromeState extends State<_Chrome> with CallChromeAutoHide<_Chrome> {
  @override
  void dispose() {
    disposeAutoHide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    syncAutoHide(true);
    return autoHideScope(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggleControls,
        child: SizedBox.expand(
          child: controlsVisible ? const Text('chrome') : null,
        ),
      ),
    );
  }
}
