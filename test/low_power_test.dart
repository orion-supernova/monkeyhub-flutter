import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/theme/low_power.dart';

void main() {
  tearDown(() {
    LowPowerMode.instance.apply(const {});
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

  test('a low battery turns it on at 20%, not before, and not while charging', () {
    final mode = LowPowerMode.instance;
    mode.apply({'powerSaveMode': false, 'batteryLevel': 21, 'charging': false});
    expect(mode.value, isFalse);
    mode.apply({'powerSaveMode': false, 'batteryLevel': 20, 'charging': false});
    expect(mode.value, isTrue);
    expect(mode.lowBattery, isTrue);
    expect(mode.osPowerSave, isFalse);
    mode.apply({'powerSaveMode': false, 'batteryLevel': 12, 'charging': true});
    expect(mode.value, isFalse);
    // No level (the simulator) is normal power, not an empty battery.
    mode.apply({'powerSaveMode': false});
    expect(mode.value, isFalse);
  });

  test('the phone\'s own mode is told apart from a low battery', () {
    final mode = LowPowerMode.instance;
    mode.apply({'powerSaveMode': true, 'batteryLevel': 10, 'charging': false});
    expect(mode.value, isTrue);
    expect(mode.osPowerSave, isTrue);
    mode.apply({'powerSaveMode': false, 'batteryLevel': 80, 'charging': false});
    expect(mode.value, isFalse);
  });

  test('unknown stored values read as automatic', () {
    expect(PowerSaving.parse(null), PowerSaving.auto);
    expect(PowerSaving.parse('nonsense'), PowerSaving.auto);
    expect(PowerSaving.parse('on'), PowerSaving.on);
  });
}
