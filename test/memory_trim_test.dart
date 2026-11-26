import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/services/memory_trim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final trim = MemoryTrim.instance;
  final cache = PaintingBinding.instance.imageCache;
  var hookRuns = 0;
  final purges = <String>[];

  setUpAll(() {
    trim.install();
    trim.register(() => hookRuns++);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('monkeyhub/memory'), (
          call,
        ) async {
          purges.add(call.method);
          return true;
        });
  });

  setUp(() {
    hookRuns = 0;
    purges.clear();
    trim.didChangeAppLifecycleState(AppLifecycleState.resumed);
  });

  testWidgets('desktop: hidden trims after the grace delay, resume restores', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    trim.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 29));
    expect(hookRuns, 0, reason: 'a quick ⌘W and back must not trim');
    await tester.pump(const Duration(seconds: 2));
    expect(hookRuns, 1);
    expect(purges, ['purgeEngine']);
    expect(cache.maximumSizeBytes, lessThan(MemoryTrim.foregroundImageBytes));

    trim.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(cache.maximumSizeBytes, MemoryTrim.foregroundImageBytes);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop: coming back inside the delay cancels the trim', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    trim.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 10));
    trim.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(minutes: 1));
    expect(hookRuns, 0);
    expect(purges, isEmpty, reason: 'engine purge is macOS-only');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('phone: backgrounding trims at once, inactive never does', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    trim.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump(const Duration(minutes: 10));
    expect(hookRuns, 0, reason: 'Control Centre swipe is not walking away');
    trim.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(hookRuns, 1);
    expect(purges, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('memory pressure trims without asking for an engine purge', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    trim.didHaveMemoryPressure();
    expect(hookRuns, 1);
    expect(purges, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
}
