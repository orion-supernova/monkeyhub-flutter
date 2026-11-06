import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/services/haptics.dart';
import 'package:monkeyhub/widgets/haptic_tick.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Haptics.resetForTest();
    HapticTick.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('monkeyhub/haptics'), null);
  });

  test('the gate defaults to enabled before settings load', () {
    expect(Haptics.enabled, isTrue);
  });

  test('HapticTick is silent when disabled and plays when enabled', () async {
    HapticTick.platformOverride = TargetPlatform.iOS;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('monkeyhub/haptics'),
            (call) async {
      calls.add(call.method);
      return null;
    });
    HapticTick.play(0.5);
    await pumpEventQueue();
    expect(calls, ['tick']);

    calls.clear();
    Haptics.enabled = false;
    expect(HapticTick.current(), HapticTier.silent);
    HapticTick.play(0.5, tier: HapticTier.full);
    HapticTick.prepare();
    await pumpEventQueue();
    expect(calls, isEmpty);
  });

  test('the setting persists through load() and feeds the gate', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = SettingsStore.instance;
    await store.reloadForTest();
    expect(store.hapticsEnabled, isTrue);

    await store.setHapticsEnabled(false);
    expect(Haptics.enabled, isFalse);

    Haptics.enabled = true;
    await store.reloadForTest();
    expect(store.hapticsEnabled, isFalse);
    expect(Haptics.enabled, isFalse);

    await store.setHapticsEnabled(true);
    await store.reloadForTest();
    expect(store.hapticsEnabled, isTrue);
    expect(Haptics.enabled, isTrue);
  });
}
