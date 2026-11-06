import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/detent_ruler.dart';
import 'package:monkeyhub/widgets/haptic_tick.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> native;

  setUp(() {
    native = [];
    HapticTick.resetForTest();
    HapticTick.platformOverride = TargetPlatform.iOS;
    HapticTick.lowPowerProbe = () => false;
    HapticTick.inCallProbe = () => false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('monkeyhub/haptics'),
            (call) async {
      native.add(call);
      return null;
    });
  });

  tearDown(() {
    HapticTick.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('monkeyhub/haptics'), null);
  });

  const labels = ['10s', '30s', '1m', '5m', '1h'];

  /// A ruler 324 wide: a 276 track after the 24 padding, so stops sit 69 apart
  /// starting at x = 24.
  Widget host({
    required ValueNotifier<int> index,
    bool calm = false,
    List<String> items = labels,
  }) =>
      ThemeScope(
        controller: ThemeController(ThemeController.byId('basic')),
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: calm),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 324,
                  child: ValueListenableBuilder<int>(
                    valueListenable: index,
                    builder: (_, i, _) => DetentRuler(
                      labels: items,
                      index: i,
                      semanticLabel: 'Message timer',
                      onChanged: (v) => index.value = v,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  double stopX(WidgetTester t, int i) =>
      t.getTopLeft(find.byType(DetentRuler)).dx + 24 + 69.0 * i;

  testWidgets('dragging snaps through the stops and ticks once per stop',
      (t) async {
    final index = ValueNotifier(0);
    await t.pumpWidget(host(index: index));
    final y = t.getCenter(find.byType(DetentRuler)).dy;

    final g = await t.startGesture(Offset(stopX(t, 0), y));
    await t.pump();
    native.clear();
    for (var i = 1; i <= 4; i++) {
      await g.moveTo(Offset(stopX(t, i), y));
      await t.pump();
      expect(index.value, i);
    }
    await g.up();
    await t.pumpAndSettle();

    final ticks = native.where((c) => c.method == 'tick').toList();
    expect(ticks, hasLength(4));
    final strengths = [for (final c in ticks) (c.arguments as Map)['intensity'] as double];
    expect(strengths, orderedEquals([...strengths]..sort()),
        reason: 'soft to firm along the ruler');
    expect(strengths.first, closeTo(0.25 + 0.5 * 1 / 4, 1e-9));
    expect(strengths.last, closeTo(0.75, 1e-9));
  });

  testWidgets('dragging back crosses the same stops again', (t) async {
    final index = ValueNotifier(4);
    await t.pumpWidget(host(index: index));
    final y = t.getCenter(find.byType(DetentRuler)).dy;
    final g = await t.startGesture(Offset(stopX(t, 4), y));
    await t.pump();
    native.clear();
    await g.moveTo(Offset(stopX(t, 1), y));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(index.value, 1);
    expect(native.where((c) => c.method == 'tick'), hasLength(1),
        reason: 'one move, one landing stop, one tick');
  });

  testWidgets('a tap jumps to the nearest stop', (t) async {
    final index = ValueNotifier(0);
    await t.pumpWidget(host(index: index));
    await t.tapAt(Offset(stopX(t, 3) + 10, t.getCenter(find.byType(DetentRuler)).dy));
    await t.pumpAndSettle();
    expect(index.value, 3);
  });

  testWidgets('release springs onto the stop; calm just lands', (t) async {
    Future<double> knobAfterRelease({required bool calm}) async {
      final index = ValueNotifier(0);
      await t.pumpWidget(host(index: index, calm: calm));
      final y = t.getCenter(find.byType(DetentRuler)).dy;
      final g = await t.startGesture(Offset(stopX(t, 0), y));
      // Between stops 2 and 3, nearer 2.
      await g.moveTo(Offset(stopX(t, 2) + 20, y));
      await t.pump();
      await g.up();
      await t.pump();
      final x = t.getCenter(find.text('1m').last).dx;
      await t.pumpAndSettle();
      expect(index.value, 2);
      return x - t.getCenter(find.text('1m').last).dx;
    }

    // With the spring the knob is still travelling one frame after release;
    // calm, it is already home.
    expect(await knobAfterRelease(calm: false), isNot(0));
    expect(await knobAfterRelease(calm: true), 0);
  });

  testWidgets('semantics: an adjustable slider that steps by stop', (t) async {
    final handle = t.ensureSemantics();
    final index = ValueNotifier(1);
    await t.pumpWidget(host(index: index));

    final node = find.semantics.byLabel('Message timer').evaluate().single;
    expect(node.label, 'Message timer');
    expect(node.value, '30s');
    expect(node.increasedValue, '1m');
    expect(node.decreasedValue, '10s');
    expect(node.flagsCollection.isSlider, isTrue);

    t.semantics.increase(find.semantics.byLabel('Message timer'));
    await t.pumpAndSettle();
    expect(index.value, 2);
    t.semantics.decrease(find.semantics.byLabel('Message timer'));
    t.semantics.decrease(find.semantics.byLabel('Message timer'));
    await t.pumpAndSettle();
    expect(index.value, 0);
    // No decrease past the first stop.
    expect(find.semantics.byLabel('Message timer').evaluate().single.decreasedValue, isEmpty);
    handle.dispose();
  });

  testWidgets('keyboard: arrows, Home and End', (t) async {
    final index = ValueNotifier(2);
    await t.pumpWidget(host(index: index));
    // Focus it with a Tab.
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(index.value, 3);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pumpAndSettle();
    expect(index.value, 1);
    await t.sendKeyEvent(LogicalKeyboardKey.end);
    await t.pumpAndSettle();
    expect(index.value, 4);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(index.value, 4, reason: 'clamped at the last stop');
    await t.sendKeyEvent(LogicalKeyboardKey.home);
    await t.pumpAndSettle();
    expect(index.value, 0);
  });

  testWidgets('an outside change to the stop list re-seats the knob', (t) async {
    final index = ValueNotifier(4);
    await t.pumpWidget(host(index: index));
    index.value = 1;
    await t.pumpAndSettle();
    final knob = t.getCenter(find.text('30s').first);
    expect(knob.dx, closeTo(stopX(t, 1), 1));
  });
}
