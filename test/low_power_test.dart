import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/theme/low_power.dart';

void main() {
  tearDown(() {
    LowPowerMode.instance.value = false;
    SettingsStore.instance.setPowerSaving(PowerSaving.auto);
    SettingsStore.instance.setMotionLevel(null);
  });

  test('automatic follows the phone', () async {
    await SettingsStore.instance.setPowerSaving(PowerSaving.auto);
    expect(LowPowerMode.active, isFalse);
    LowPowerMode.instance.value = true;
    expect(LowPowerMode.active, isTrue);
  });

  test('never ignores the phone, always ignores it the other way', () async {
    LowPowerMode.instance.value = true;
    await SettingsStore.instance.setPowerSaving(PowerSaving.off);
    expect(LowPowerMode.active, isFalse);
    LowPowerMode.instance.value = false;
    await SettingsStore.instance.setPowerSaving(PowerSaving.on);
    expect(LowPowerMode.active, isTrue);
  });

  test('an explicit Motion choice outranks power saving', () async {
    await SettingsStore.instance.setPowerSaving(PowerSaving.on);
    await SettingsStore.instance.setMotionLevel(MotionLevel.full);
    expect(LowPowerMode.active, isFalse);
  });

  test('unknown stored values read as automatic', () {
    expect(PowerSaving.parse(null), PowerSaving.auto);
    expect(PowerSaving.parse('nonsense'), PowerSaving.auto);
    expect(PowerSaving.parse('on'), PowerSaving.on);
  });
}
