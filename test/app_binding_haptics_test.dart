import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/services/app_binding.dart';

/// Records what reaches the engine, in place of Flutter's messenger.
class _Inner implements BinaryMessenger {
  final sent = <String>[];

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    final call = const JSONMethodCodec().decodeMethodCall(message);
    sent.add('${call.method}:${call.arguments}');
    return Future.value(null);
  }

  @override
  Future<void> handlePlatformMessage(String channel, ByteData? data,
          PlatformMessageResponseCallback? callback) async {}

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {}
}

ByteData _vibrate(String type) => const JSONMethodCodec()
    .encodeMethodCall(MethodCall('HapticFeedback.vibrate', type));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a haptic played twice in one event reaches the engine once', () async {
    final inner = _Inner();
    final m = HapticMessenger(inner, mac: false);
    await m.send('flutter/platform', _vibrate('HapticFeedbackType.lightImpact'));
    await m.send('flutter/platform', _vibrate('HapticFeedbackType.selectionClick'));
    expect(inner.sent, ['HapticFeedback.vibrate:HapticFeedbackType.lightImpact']);
  });

  test('a deliberate run of haptics is not collapsed', () async {
    final inner = _Inner();
    final m = HapticMessenger(inner, mac: false);
    for (var i = 0; i < 3; i++) {
      await m.send('flutter/platform', _vibrate('HapticFeedbackType.lightImpact'));
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }
    expect(inner.sent, hasLength(3));
  });

  test('everything else passes straight through', () async {
    final inner = _Inner();
    final m = HapticMessenger(inner, mac: true);
    await m.send(
      'flutter/platform',
      const JSONMethodCodec()
          .encodeMethodCall(const MethodCall('Clipboard.setData', null)),
    );
    expect(inner.sent, ['Clipboard.setData:null']);
  });

  test('on macOS a haptic goes to the Runner, not the engine', () async {
    final played = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('monkeyhub/haptics'),
            (call) async {
      played.add(call.arguments);
      return null;
    });
    final inner = _Inner();
    final m = HapticMessenger(inner, mac: true);
    await m.send('flutter/platform', _vibrate('HapticFeedbackType.selectionClick'));
    await pumpEventQueue();
    expect(inner.sent, isEmpty);
    expect(played, ['HapticFeedbackType.selectionClick']);
  });
}
