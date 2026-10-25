import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/glass_hud.dart';
import 'package:monkeyhub/widgets/glass_progress_dialog.dart';
import 'package:monkeyhub/widgets/scan_frame_overlay.dart';

Widget _app(Widget Function(BuildContext) body, {bool calm = false}) =>
    ThemeScope(
      controller: ThemeController(ThemeController.byId('basic')),
      child: MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: calm),
          child: child!,
        ),
        home: Builder(builder: (c) => Scaffold(body: body(c))),
      ),
    );

void main() {
  testWidgets('progress shows, updates, cancels, closes', (tester) async {
    late GlassProgressHandle h;
    var cancels = 0;
    await tester.pumpWidget(_app((c) => TextButton(
          onPressed: () => h = showGlassProgress(c,
              title: 'Syncing',
              message: 'one',
              onCancel: () => cancels++,
              cancelLabel: 'Stop'),
          child: const Text('go'),
        )));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Syncing'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    h.update(message: 'two', progress: 0.55);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('two'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    expect(cancels, 1);

    h.update(progress: 1);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Stop'));
    expect(cancels, 1, reason: 'disabled at 100%');

    h.close();
    h.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Syncing'), findsNothing);
  });

  testWidgets('HUD auto-dismisses and future completes', (tester) async {
    var done = false;
    await tester.pumpWidget(_app((c) => TextButton(
          onPressed: () => showGlassHud(c,
                  icon: Icons.lock,
                  label: 'Unlocked',
                  duration: const Duration(milliseconds: 500),
                  success: true)
              .then((_) => done = true),
          child: const Text('go'),
        )));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Unlocked'), findsOneWidget);
    expect(find.byType(GlassHudCheck), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Unlocked'), findsNothing);
    expect(done, isTrue);
  });

  testWidgets('calm: overlays appear and vanish instantly', (tester) async {
    late GlassProgressHandle h;
    await tester.pumpWidget(_app(
      (c) => TextButton(
        onPressed: () => h = showGlassProgress(c, title: 'T'),
        child: const Text('go'),
      ),
      calm: true,
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // let the button ripple end
    expect(find.text('T'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    h.close();
    await tester.pump();
    await tester.pump();
    expect(find.text('T'), findsNothing);
  });

  testWidgets('scan frame paints; calm has no running animation',
      (tester) async {
    await tester.pumpWidget(_app((_) => const Center(child: ScanFrameOverlay())));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.hasRunningAnimations, isTrue);
    expect(find.byType(ScanFrameOverlay), findsOneWidget);
    expect(tester.getSize(find.byType(ScanFrameOverlay)), const Size(240, 240));
    expect(tester.renderObject(find.descendant(
        of: find.byType(ScanFrameOverlay),
        matching: find.byType(CustomPaint).last)), isA<RenderCustomPaint>());

    await tester.pumpWidget(_app(
        (_) => const Center(child: ScanFrameOverlay(detected: true)),
        calm: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('ProgressRing indeterminate spins, determinate settles',
      (tester) async {
    await tester.pumpWidget(_app((_) => const Center(child: ProgressRing())));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(
        _app((_) => const Center(child: ProgressRing(value: 0.5))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
