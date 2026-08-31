import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/calls/audio_level_monitor.dart';

import 'fakes/fake_webrtc.dart';

/// Who is talking, without the flicker.
///
/// A raw audio level rises on the first syllable and falls in every gap
/// between words; a ring wired straight to it would blink with every
/// consonant. These pin the smoothing and the hysteresis — two loud polls
/// to light, four quiet ones to go dark — and that a muted or vanished peer
/// goes quiet without a poll.
StatsReport _inbound(double level) => StatsReport(
      'in1',
      'inbound-rtp',
      0,
      {'kind': 'audio', 'audioLevel': level},
    );

StatsReport _source(double level) => StatsReport(
      'src1',
      'media-source',
      0,
      {'kind': 'audio', 'audioLevel': level},
    );

void main() {
  test('two loud polls light a speaker, four quiet ones put it out', () async {
    final pc = FakePeerConnection()..stats = [_inbound(0.5)];
    final m = AudioLevelMonitor()
      ..sources = () => [AudioLevelSource(id: 'b', pc: pc, track: null)];
    await m.pollNow();
    expect(m.speaking.value, isEmpty, reason: 'one syllable is not speech');
    expect(m.levelOf('b').value, 0.5);
    await m.pollNow();
    expect(m.speaking.value, {'b'});

    pc.stats = [_inbound(0.0)];
    for (var i = 0; i < 3; i++) {
      await m.pollNow();
      expect(m.speaking.value, {'b'}, reason: 'a pause is not the end');
    }
    await m.pollNow();
    expect(m.speaking.value, isEmpty);
    // The level decayed rather than dropping.
    expect(m.levelOf('b').value, lessThan(0.5));
    expect(m.levelOf('b').value, greaterThan(0));
    m.dispose();
  });

  test('a muted peer reads as silent without asking the connection', () async {
    var asked = 0;
    final pc = _CountingPc(onStats: () => asked++)..stats = [_inbound(0.9)];
    final m = AudioLevelMonitor()
      ..sources = () => [
            AudioLevelSource(id: 'b', pc: pc, track: null, muted: true),
          ];
    await m.pollNow();
    await m.pollNow();
    expect(asked, 0);
    expect(m.speaking.value, isEmpty);
    m.dispose();
  });

  test('the local level comes from media-source, filed under "me"', () async {
    final pc = FakePeerConnection()..stats = [_source(0.3)];
    final m = AudioLevelMonitor()..localPc = () => pc;
    await m.pollNow();
    expect(m.levelOf(AudioLevelMonitor.me).value, 0.3);
    m.dispose();
  });

  test('a peer that left goes quiet', () async {
    final pc = FakePeerConnection()..stats = [_inbound(0.6)];
    var present = true;
    final m = AudioLevelMonitor()
      ..sources = () => [
            if (present) AudioLevelSource(id: 'b', pc: pc, track: null),
          ];
    await m.pollNow();
    await m.pollNow();
    expect(m.speaking.value, {'b'});
    present = false;
    for (var i = 0; i < 4; i++) {
      await m.pollNow();
    }
    expect(m.speaking.value, isEmpty);
    expect(m.levelOf('b').value, lessThan(0.1));
    m.dispose();
  });

  test('start/stop are ref-counted and stopping settles everyone', () async {
    final pc = FakePeerConnection()..stats = [_inbound(0.6)];
    final m = AudioLevelMonitor(interval: const Duration(days: 1))
      ..sources = () => [AudioLevelSource(id: 'b', pc: pc, track: null)];
    m.start();
    m.start();
    expect(m.running, isTrue);
    await m.pollNow();
    await m.pollNow();
    expect(m.speaking.value, {'b'});
    m.stop();
    expect(m.running, isTrue, reason: 'one screen still listening');
    m.stop();
    expect(m.running, isFalse);
    expect(m.speaking.value, isEmpty);
    expect(m.levelOf('b').value, 0);
    m.dispose();
  });
}

class _CountingPc extends FakePeerConnection {
  _CountingPc({required this.onStats});
  final void Function() onStats;

  @override
  Future<List<StatsReport>> getStats([MediaStreamTrack? track]) async {
    onStats();
    return stats;
  }
}
