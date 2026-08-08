import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/push/push_manager.dart';

/// What [PushManager] actually says down the `monkeyhub/notifications` channel.
///
/// The native handlers on the other end are written in two other languages and
/// cannot be exercised here, so the method names and argument shapes are the
/// only part of that seam a fast test can hold still. Getting one wrong is a
/// silent no-op on a device: a notification that never clears, or a banner over
/// the room you are reading.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('monkeyhub/notifications');
  late List<MethodCall> calls;

  void mockChannel({Object? Function(MethodCall call)? answer}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer?.call(call);
    });
  }

  setUp(() {
    calls = [];
    mockChannel();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('opening a room tells the platform which one is on screen', () async {
    await PushManager.instance.setActiveRoom('room-7');
    expect(calls.single.method, 'setActiveRoom');
    expect(calls.single.arguments, {'roomId': 'room-7'});
  });

  test('leaving a room clears it, rather than leaving it stale', () async {
    // A stale value suppresses that room's notifications for the rest of the
    // session, which reads as "notifications randomly stopped working".
    await PushManager.instance.setActiveRoom(null);
    expect(calls.single.method, 'setActiveRoom');
    expect(calls.single.arguments, {'roomId': null});
  });

  test('reading a room sweeps its notifications by room, not by id', () async {
    await PushManager.instance.dismissRoomNotifications('room-7');
    expect(calls.single.method, 'dismissRoom');
    expect(calls.single.arguments, {'roomId': 'room-7'});
  });

  test('a deleted message is dismissed by its collapse id', () async {
    await PushManager.instance.dismissNotifications(['msg-1', 'msg-2']);
    expect(calls.single.method, 'dismiss');
    expect(calls.single.arguments, {
      'ids': ['msg-1', 'msg-2'],
    });
  });

  test('an empty dismiss list is not a channel round trip', () async {
    await PushManager.instance.dismissNotifications([]);
    expect(calls, isEmpty);
  });

  test('an unwired platform is survivable, not a crash', () async {
    // macOS/Windows/Linux install no such channel. Every one of these is
    // called from ordinary UI paths — opening a room, reading one — so a
    // MissingPluginException must never escape.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('no such channel');
    });
    await expectLater(
      PushManager.instance.dismissRoomNotifications('room-7'),
      completes,
    );
    await expectLater(
      PushManager.instance.dismissNotifications(['m']),
      completes,
    );
    await expectLater(PushManager.instance.setActiveRoom('r'), completes);
  });

  test('a platform error is swallowed too', () async {
    // Not the same case: the channel exists but the handler threw. Still not
    // worth taking a room-open down for.
    mockChannel(answer: (_) => throw PlatformException(code: 'boom'));
    await expectLater(
      PushManager.instance.dismissRoomNotifications('room-7'),
      completes,
    );
  });
}
