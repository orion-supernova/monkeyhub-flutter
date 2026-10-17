import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/device_capability.dart';
import 'package:monkeyhub/theme/perf_tier.dart';

/// The tier is the RAM figure read at boot; unknown is the normal tier.
void main() {
  tearDown(() {
    Perf.debugTier = null;
    DeviceCapability.instance.setRamForTest(null);
  });

  test('a 3 GB phone is the low tier, a 4 GB one is not', () {
    DeviceCapability.instance.setRamForTest(2850);
    expect(Perf.tier, PerfTier.low);
    DeviceCapability.instance.setRamForTest(3850);
    expect(Perf.tier, PerfTier.normal);
  });

  test('unknown RAM keeps the full effects', () {
    DeviceCapability.instance.setRamForTest(null);
    expect(Perf.low, isFalse);
    expect(Perf.particles(7000), 7000);
    expect(Perf.captureRatio(3), 3);
  });

  test('the low tier thins the grains and caps the capture at 2x', () {
    Perf.debugTier = PerfTier.low;
    expect(Perf.particles(7000), 3850);
    expect(Perf.captureRatio(3), 2);
    expect(Perf.captureRatio(1.5), 1.5);
    expect(Perf.captureRatio(3, max: 2), 2);
  });
}
