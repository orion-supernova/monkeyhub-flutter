import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/net/rollback_session.dart';

void main() {
  test('packet codec round-trips', () {
    final pk = InputPacket(frame: 123456, ack: 123450, startFrame: 123449, inputs: [0, 1, 511, 16, 64, 32, 0, 300], csFrame: 120, csValue: 4000000000);
    final d = InputPacket.decode(pk.encode())!;
    expect(d.frame, 123456);
    expect(d.ack, 123450);
    expect(d.startFrame, 123449);
    expect(d.inputs, [0, 1, 511, 16, 64, 32, 0, 300]);
    expect(d.csFrame, 120);
    expect(d.csValue, 4000000000);
    final none = InputPacket.decode(const InputPacket(frame: 0, ack: -1, startFrame: 0, inputs: []).encode())!;
    expect(none.ack, -1);
    expect(none.csFrame, -1);
  });

  test('malformed packets are ignored', () {
    expect(InputPacket.decode(Uint8List(0)), isNull);
    expect(InputPacket.decode(Uint8List.fromList([0xF1, 3, 1, 2])), isNull);
    final good = const InputPacket(frame: 1, ack: 0, startFrame: 0, inputs: [1, 2]).encode();
    final bad = Uint8List.fromList(good)..[0] = 0x00;
    expect(InputPacket.decode(bad), isNull);
    final s = RollbackSession(
        localIndex: 0, initial: FightState.initial(seed: 1, p1: kai, p2: kai), send: (_) {});
    s.receive(bad); // must not throw
    s.receive(Uint8List.fromList([1, 2, 3]));
  });

  test('packets carry the last 8 inputs redundantly', () {
    final sent = <Uint8List>[];
    final s = RollbackSession(localIndex: 0, initial: FightState.initial(seed: 1, p1: kai, p2: kai), send: sent.add);
    s.tick(Inp.left);
    final pk = InputPacket.decode(sent.last)!;
    expect(pk.inputs.length, lessThanOrEqualTo(8));
    expect(pk.inputs.last, Inp.left);
  });

  test('a session stalls when the peer goes silent for more than the rollback window', () {
    final s = RollbackSession(localIndex: 0, initial: FightState.initial(seed: 1, p1: kai, p2: kai), send: (_) {});
    var advanced = 0;
    for (var i = 0; i < 40; i++) {
      if (s.tick(0) == TickResult.advanced) advanced++;
    }
    expect(advanced, lessThanOrEqualTo(8 + s.inputDelay + 1));
    expect(s.stalls, greaterThan(0));
    expect(s.state.frame, advanced);
  });

  test('desync detection fires when the peers diverge', () {
    final a = <Uint8List>[], b = <Uint8List>[];
    final reports = <int>[];
    final sa = RollbackSession(localIndex: 0, initial: FightState.initial(seed: 1, p1: kai, p2: nyx), send: a.add, onDesync: (f, x, y) => reports.add(f));
    final sb = RollbackSession(localIndex: 1, initial: FightState.initial(seed: 1, p1: kai, p2: nyx), send: b.add, onDesync: (f, x, y) => reports.add(f));
    for (var f = 0; f < 140; f++) {
      if (f == 35) sb.state.p[0].health -= 1; // silent corruption on one peer
      for (final d in a) {
        sb.receive(d);
      }
      for (final d in b) {
        sa.receive(d);
      }
      a.clear();
      b.clear();
      sa.tick(f % 7 == 0 ? Inp.light : 0);
      sb.tick(f % 11 == 0 ? Inp.heavy : 0);
    }
    expect(reports, isNotEmpty);
    expect(reports.first % 30, 0);
    expect(sa.desynced || sb.desynced, isTrue);
  });

  test('no desync report on a healthy zero-latency pair, and checksums are exchanged', () {
    final a = <Uint8List>[], b = <Uint8List>[];
    var desync = 0;
    final sa = RollbackSession(localIndex: 0, initial: FightState.initial(seed: 1, p1: kai, p2: nyx), send: a.add, onDesync: (f, x, y) => desync++);
    final sb = RollbackSession(localIndex: 1, initial: FightState.initial(seed: 1, p1: kai, p2: nyx), send: b.add, onDesync: (f, x, y) => desync++);
    for (var f = 0; f < 200; f++) {
      for (final d in a) {
        sb.receive(d);
      }
      for (final d in b) {
        sa.receive(d);
      }
      a.clear();
      b.clear();
      sa.tick(f % 7 == 0 ? Inp.light : 0);
      sb.tick(f % 11 == 0 ? Inp.heavy : 0);
    }
    expect(desync, 0);
    expect(sa.state.frame, greaterThan(150));
  });

  test('time sync: a peer running ahead is told to skip', () {
    final a = <Uint8List>[], b = <Uint8List>[];
    final sa = RollbackSession(localIndex: 0, initial: FightState.initial(seed: 1, p1: kai, p2: nyx), send: a.add);
    final sb = RollbackSession(localIndex: 1, initial: FightState.initial(seed: 1, p1: kai, p2: nyx), send: b.add);
    // sa runs 2 ticks per tick of sb with a 1-frame network delay.
    var skipped = 0;
    List<Uint8List> toA = [], toB = [];
    for (var t = 0; t < 120; t++) {
      for (final d in toA) {
        sa.receive(d);
      }
      for (final d in toB) {
        sb.receive(d);
      }
      toA = List.of(b);
      toB = List.of(a);
      a.clear();
      b.clear();
      for (var k = 0; k < 2; k++) {
        if (sa.tick(0) == TickResult.skipped) skipped++;
      }
      sb.tick(0);
    }
    expect(skipped + sa.stalls, greaterThan(0));
    expect((sa.state.frame - sb.state.frame).abs(), lessThan(14));
  });
}
