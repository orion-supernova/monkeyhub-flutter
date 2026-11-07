import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/native/native_control.dart';

/// A native control may only show when it is whole and nothing Flutter
/// floats over it. Liquid Glass cut by a clipping ancestor renders as a flat
/// grey box (seen on device at the page bar, a sheet's top and the chat
/// list's header), and a native view always draws above Flutter, so one
/// under the call pills drew on top of them. Either way its Flutter
/// stand-in shows instead.
void main() {
  late List<Map<String, Object?>> syncs;

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    syncs = [];
    const overlay = MethodChannel('monkeyhub/native_overlay');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(overlay, (
      call,
    ) async {
      if (call.method == 'sync') {
        final items = (call.arguments as Map)['items'] as List;
        for (final i in items) {
          syncs.add((i as Map).cast<String, Object?>());
        }
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        overlay,
        null,
      ),
    );
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(home: Material(child: child)),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Widget control() => NativeControl(
    size: const Size(100, 40),
    spec: NativeSpec.button(label: 'Go', height: 40),
    standIn: const SizedBox(width: 100, height: 40),
  );

  Map<String, Object?> last() => syncs.last;

  testWidgets('a whole control shows', (tester) async {
    await pump(
      tester,
      const Align(alignment: Alignment.center, child: _Ctl()),
    );
    expect(last()['visible'], isTrue);
  });

  testWidgets('a control a clip cuts into hides (the grey box)', (
    tester,
  ) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 60, // narrower than the 100pt control
          height: 40,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: 100,
              child: control(),
            ),
          ),
        ),
      ),
    );
    expect(last()['visible'], isFalse);
    expect(last()['why'], 'partial');
  });

  testWidgets('a control under floating Flutter chrome hides', (
    tester,
  ) async {
    await pump(
      tester,
      Stack(
        children: [
          Positioned(left: 20, top: 20, child: control()),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 50,
            child: NativeOccluder(child: ColoredBox(color: Colors.red)),
          ),
        ],
      ),
    );
    expect(last()['visible'], isFalse);
    expect(last()['why'], 'occluded');
  });

  testWidgets('a collapsed occluder (pill hidden) hides nothing', (
    tester,
  ) async {
    await pump(
      tester,
      Stack(
        children: [
          Positioned(left: 20, top: 20, child: control()),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 0,
            child: NativeOccluder(child: SizedBox.shrink()),
          ),
        ],
      ),
    );
    expect(last()['visible'], isTrue);
  });
}

class _Ctl extends StatelessWidget {
  const _Ctl();

  @override
  Widget build(BuildContext context) => NativeControl(
    size: const Size(100, 40),
    spec: NativeSpec.button(label: 'Go', height: 40),
    standIn: const SizedBox(width: 100, height: 40),
  );
}
