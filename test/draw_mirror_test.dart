import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/draw/draw_channel.dart';
import 'package:monkeyhub/calls/draw/draw_mirror.dart';
import 'package:monkeyhub/calls/draw/draw_model.dart';
import 'package:monkeyhub/calls/draw/draw_wire.dart';

import 'fakes/fake_webrtc.dart';

/// The drawing, handed to the platform while the app is out of sight — and
/// only then.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late List<Uint8List> sent;
  late DrawModel model;
  late DrawChannels channels;
  late DrawMirror mirror;
  late FakeDataChannel wire;

  Float32List pts(List<double> xy) => Float32List.fromList(xy);

  setUp(() {
    calls = [];
    sent = [];
    messenger.setMockMethodCallHandler(
      const MethodChannel('monkeyhub/draw_mirror'),
      (call) async {
        calls.add(call);
        return call.method == 'arm' ? true : null;
      },
    );
    messenger.setMockMessageHandler('monkeyhub/draw_mirror/ops', (data) async {
      sent.add(Uint8List.fromList(data!.buffer
          .asUint8List(data.offsetInBytes, data.lengthInBytes)));
      return null;
    });
    model = DrawModel();
    channels = DrawChannels(model: model);
    wire = FakeDataChannel(channelLabel: DrawChannels.label);
    channels.attach('alice', wire);
    mirror = DrawMirror(model: model, channels: channels, supported: true);
  });

  tearDown(() {
    mirror.dispose();
    channels.dispose();
    model.dispose();
    messenger.setMockMethodCallHandler(
        const MethodChannel('monkeyhub/draw_mirror'), null);
    messenger.setMockMessageHandler('monkeyhub/draw_mirror/ops', null);
  });

  void lifecycle(AppLifecycleState s) =>
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(s);

  Uint8List aliceStroke() => encodeDrawBatch([
        StrokeBegin(
            strokeId: 7, argb: 0xFF00FF00, width: 0.01, points: pts([0.1, 0.2])),
      ]);

  test('in front, nothing goes to the platform', () async {
    lifecycle(AppLifecycleState.resumed);
    await mirror.start(trackId: 'screen-track', idleText: 'idle');
    expect(calls.single.method, 'arm');
    expect(calls.single.arguments,
        {'trackId': 'screen-track', 'idleText': 'idle'});

    wire.emit(aliceStroke());
    await pumpEventQueue();
    expect(model.strokes, hasLength(1), reason: 'Flutter still draws it');
    expect(sent, isEmpty);
    expect(mirror.debugVisible, isFalse);
  });

  test('out of sight: the live strokes are handed over, then the wire is '
      'passed through as it came', () async {
    lifecycle(AppLifecycleState.resumed);
    await mirror.start(trackId: 't', idleText: 'idle');
    wire.emit(aliceStroke());

    lifecycle(AppLifecycleState.inactive);
    await pumpEventQueue();
    expect(sent, isEmpty, reason: 'a pulled-down shade is not leaving');

    lifecycle(AppLifecycleState.hidden);
    await pumpEventQueue();
    expect(sent.first, [0x01], reason: 'reset first');
    // The hand-off: the stroke already on screen, still being drawn.
    final handOff = sent[1];
    expect(handOff[0], 0x03);
    final author = utf8.encode('alice');
    expect(handOff[1], author.length);
    expect(handOff.sublist(2, 2 + author.length), author);
    final ago = ByteData.sublistView(handOff, 2 + author.length)
        .getInt32(0, Endian.little);
    expect(ago, -1);
    final ops = decodeDrawBatch(
        Uint8List.sublistView(handOff, 2 + author.length + 4));
    expect((ops.single as StrokeBegin).strokeId, 7);
    expect(sent.last, [0x04, 1]);

    sent.clear();
    final more = encodeDrawBatch([
      StrokeAppend(strokeId: 7, points: pts([0.3, 0.4])),
      const StrokeEnd(strokeId: 7),
    ]);
    wire.emit(more);
    await pumpEventQueue();
    expect(sent.single[0], 0x02);
    expect(sent.single.sublist(2 + author.length), more,
        reason: 'the same bytes, no re-encode');

    lifecycle(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(sent.last, [0x04, 0]);
    sent.clear();
    wire.emit(aliceStroke());
    await pumpEventQueue();
    expect(sent, isEmpty, reason: 'back in front, Flutter has it again');
  });

  test('a stroke that has ended hands over its age', () async {
    final born = DateTime(2026, 10, 12, 12);
    var now = born;
    model.clock = () => now;
    lifecycle(AppLifecycleState.resumed);
    await mirror.start(trackId: null, idleText: 'idle');
    model.apply('bob', [
      StrokeBegin(strokeId: 1, argb: 0xFFFF0000, width: 0.01, points: pts([0, 0])),
      const StrokeEnd(strokeId: 1),
    ]);
    now = born.add(const Duration(milliseconds: 900));
    lifecycle(AppLifecycleState.paused);
    await pumpEventQueue();
    final handOff = sent.firstWhere((b) => b[0] == 0x03);
    final ago = ByteData.sublistView(handOff, 2 + 3).getInt32(0, Endian.little);
    expect(ago, 900);
  });

  test('stop disarms and lets go of the wire', () async {
    lifecycle(AppLifecycleState.resumed);
    await mirror.start(trackId: 't', idleText: 'idle');
    lifecycle(AppLifecycleState.hidden);
    await pumpEventQueue();
    expect(channels.onInbound, isNotNull);

    await mirror.stop();
    expect(calls.last.method, 'disarm');
    expect(channels.onInbound, isNull);
    expect(sent.last, [0x04, 0]);

    sent.clear();
    lifecycle(AppLifecycleState.resumed);
    lifecycle(AppLifecycleState.hidden);
    await pumpEventQueue();
    expect(sent, isEmpty, reason: 'no share, no mirror');
  });

  test('unsupported platforms never touch a channel', () async {
    final off = DrawMirror(model: model, channels: channels, supported: false);
    await off.start(trackId: 't', idleText: 'idle');
    lifecycle(AppLifecycleState.hidden);
    await off.stop();
    off.dispose();
    expect(calls, isEmpty);
    expect(sent, isEmpty);
  });
}
