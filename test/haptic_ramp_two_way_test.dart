import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/haptic_ramp.dart';
import 'package:monkeyhub/widgets/haptic_tick.dart';

/// The two-way mode of HapticRamp and the tier HapticTick decides on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AnimationController progress;
  late List<double> ticks;
  late List<MethodCall> native;
  Map<String, Object?> caps = {};

  setUp(() {
    ticks = [];
    native = [];
    caps = {'primitives': true, 'amplitude': true, 'touchFeedbackEnabled': true};
    HapticTick.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('monkeyhub/haptics'),
            (call) async {
      native.add(call);
      return call.method == 'capabilities' ? caps : null;
    });
    progress = AnimationController(vsync: const TestVSync());
  });

  tearDown(() {
    progress.dispose();
    HapticTick.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('monkeyhub/haptics'), null);
  });

  HapticRamp twoWay({HapticTier tier = HapticTier.full, int Function()? clock}) =>
      HapticRamp.twoWay(
        progress,
        tier: tier,
        onTick: ticks.add,
        clockMs: clock,
      );

  group('detent math', () {
    test('spacing is ((i+1)/(n+1))^0.6, shrinking gaps', () {
      expect(HapticRamp.detentAt(0, 12), closeTo(0.2146, 1e-3));
      expect(HapticRamp.detentAt(11, 12), closeTo(0.9531, 1e-3));
      final gaps = [
        for (var i = 1; i < 12; i++)
          HapticRamp.detentAt(i, 12) - HapticRamp.detentAt(i - 1, 12),
      ];
      for (var i = 1; i < gaps.length; i++) {
        expect(gaps[i], lessThan(gaps[i - 1]));
      }
    });

    test('intensity runs min to max across the detents', () {
      final ramp = twoWay();
      expect(ramp.intensityOf(0, 12), closeTo(0.15, 1e-9));
      expect(ramp.intensityOf(11, 12), closeTo(0.75, 1e-9));
      ramp.dispose();
    });
  });

  group('two-way crossing', () {
    test('a pull up then back down ticks on both legs, strength by position', () {
      final ramp = twoWay();
      for (var i = 1; i <= 100; i++) {
        progress.value = i / 100;
      }
      final up = List.of(ticks);
      expect(up, hasLength(12));
      expect(up, orderedEquals([...up]..sort()));
      ticks.clear();

      for (var i = 99; i >= 1; i--) {
        progress.value = i / 100;
      }
      // The same 12 detents, played on the way back, firm first and fading.
      expect(ticks, hasLength(12));
      expect(ticks, orderedEquals(up.reversed));
      ramp.dispose();
    });

    test('the same detent has the same strength whichever way it is crossed', () {
      final ramp = twoWay();
      progress.value = 0.3; // crosses detent 0 only
      final upward = ticks.single;
      ticks.clear();
      progress.value = 0.1;
      expect(ticks.single, upward);
      ramp.dispose();
    });

    test('a fast flick across several detents plays the strongest once', () {
      final ramp = twoWay();
      progress.value = 0.95;
      expect(ticks, hasLength(1));
      expect(ticks.single, ramp.intensityOf(10, 12)); // detent 11 sits at 0.953, so 10 is the last <= 0.95
      ticks.clear();
      progress.value = 0.2; // back across many
      expect(ticks, hasLength(1));
      ramp.dispose();
    });

    test('no tick without crossing a detent, and zero is a silent reset', () {
      final ramp = twoWay();
      progress.value = 0.05;
      progress.value = 0.1;
      expect(ticks, isEmpty);
      progress.value = 0.9;
      ticks.clear();
      progress.value = 0; // letting go
      expect(ticks, isEmpty);
      ramp.dispose();
    });

    test('landmarks and silent tiers play no ramp', () {
      for (final tier in [HapticTier.landmarks, HapticTier.silent]) {
        final ramp = twoWay(tier: tier);
        progress.value = 0.9;
        progress.value = 0.1;
        expect(ticks, isEmpty, reason: '$tier');
        ramp.dispose();
        progress.value = 0;
      }
    });

    test('thinned plays 6 detents at least 40ms apart', () {
      var now = 0;
      final ramp = twoWay(tier: HapticTier.thinned, clock: () => now);
      expect(ramp.detents, 6);
      // Every frame is 16ms: the 40ms floor drops ticks that land too close.
      for (var i = 1; i <= 200; i++) {
        now += 16;
        progress.value = i / 200;
      }
      expect(ticks, isNotEmpty);
      expect(ticks.length, lessThanOrEqualTo(6));
      // Unthrottled (slow frames), all six play.
      ticks.clear();
      progress.value = 0;
      now = 0;
      ramp.beginGesture(tier: HapticTier.thinned);
      for (var i = 1; i <= 200; i++) {
        now += 100;
        progress.value = i / 200;
      }
      expect(ticks, hasLength(6));
      ramp.dispose();
    });

    test('disposed, it stops listening', () {
      twoWay().dispose();
      progress.value = 0.9;
      expect(ticks, isEmpty);
    });
  });

  group('one-way is unchanged', () {
    test('still steps selection, light, medium and never ticks', () {
      final seen = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') seen.add('${call.arguments}');
        return null;
      });
      final ramp = HapticRamp(progress);
      for (var i = 1; i <= 60; i++) {
        progress.value = i / 60;
      }
      expect(seen, hasLength(12));
      progress.value = 0.5; // coming back down is silent in one-way mode
      expect(seen, hasLength(12));
      expect(native.where((c) => c.method == 'tick'), isEmpty);
      ramp.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('tier selection', () {
    Future<HapticTier> androidTier() async {
      HapticTick.platformOverride = TargetPlatform.android;
      await HapticTick.load();
      return HapticTick.current();
    }

    test('primitives + amplitude is the full ramp', () async {
      expect(await androidTier(), HapticTier.full);
    });

    test('amplitude without primitives is thinned', () async {
      caps['primitives'] = false;
      expect(await androidTier(), HapticTier.thinned);
    });

    test('no amplitude control is landmarks only', () async {
      caps['primitives'] = false;
      caps['amplitude'] = false;
      expect(await androidTier(), HapticTier.landmarks);
    });

    test('touch feedback off is silent', () async {
      caps['touchFeedbackEnabled'] = false;
      expect(await androidTier(), HapticTier.silent);
    });

    test('low power or a call drops to landmarks', () async {
      await androidTier();
      HapticTick.lowPowerProbe = () => true;
      expect(HapticTick.current(), HapticTier.landmarks);
      HapticTick.lowPowerProbe = () => false;
      HapticTick.inCallProbe = () => true;
      expect(HapticTick.current(), HapticTier.landmarks);
    });

    test('unknown capabilities (not loaded yet) play safe', () {
      HapticTick.platformOverride = TargetPlatform.android;
      expect(HapticTick.current(), HapticTier.landmarks);
    });

    test('capabilities are asked once', () async {
      await androidTier();
      HapticTick.current();
      await HapticTick.load();
      expect(native.where((c) => c.method == 'capabilities'), hasLength(1));
    });

    test('iOS needs no capability query and is full', () {
      HapticTick.platformOverride = TargetPlatform.iOS;
      expect(HapticTick.current(), HapticTier.full);
      expect(native, isEmpty);
    });
  });

  group('playing', () {
    test('goes through the channel with intensity and style', () {
      HapticTick.platformOverride = TargetPlatform.iOS;
      HapticTick.play(0.4);
      HapticTick.play(0.9, kind: HapticKind.notch);
      expect(native.map((c) => c.method), ['tick', 'tick']);
      expect(native[0].arguments, {'intensity': 0.4, 'style': 'light'});
      expect(native[1].arguments, {'intensity': 0.9, 'style': 'rigid'});
    });

    test('landmarks drop ticks but keep the notch; silent drops all', () {
      HapticTick.platformOverride = TargetPlatform.iOS;
      HapticTick.play(0.5, tier: HapticTier.landmarks);
      HapticTick.play(0.9, kind: HapticKind.arm, tier: HapticTier.landmarks);
      HapticTick.play(0.9, kind: HapticKind.commit, tier: HapticTier.silent);
      expect(native, hasLength(1));
      expect((native.single.arguments as Map)['style'], 'medium');
    });

    test('prepare warms the generator on iOS only', () {
      HapticTick.platformOverride = TargetPlatform.iOS;
      HapticTick.prepare();
      expect(native.single.method, 'prepare');
    });

    test('desktop falls back to HapticFeedback', () {
      HapticTick.platformOverride = TargetPlatform.macOS;
      final seen = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') seen.add('${call.arguments}');
        return null;
      });
      HapticTick.play(0.1);
      HapticTick.play(0.5);
      HapticTick.play(0.9);
      expect(seen, [
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
      ]);
      expect(native, isEmpty);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });
}
