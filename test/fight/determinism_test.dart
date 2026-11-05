import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/net/rollback_session.dart';

/// Random but plausible input log: directions held for a while, buttons tapped.
List<int> randomLog(int seed, int frames) {
  final r = Random(seed);
  final out = <int>[];
  var dir = 0;
  var left = 0;
  while (out.length < frames) {
    if (left <= 0) {
      const dirs = [0, Inp.left, Inp.right, Inp.down, Inp.up, Inp.left | Inp.down, Inp.right | Inp.down, Inp.up | Inp.right, Inp.up | Inp.left];
      dir = dirs[r.nextInt(dirs.length)];
      left = 2 + r.nextInt(14);
    }
    left--;
    var b = 0;
    if (r.nextInt(100) < 14) {
      const btn = [Inp.light, Inp.heavy, Inp.special, Inp.roll, Inp.light | Inp.heavy, Inp.special | Inp.heavy, Inp.superBtn];
      b = btn[r.nextInt(btn.length)];
    }
    out.add(dir | b);
  }
  return out;
}

int straightRun(CharacterDef a, CharacterDef b, int seed, List<int> l0, List<int> l1, int delay, int frames) {
  final s = FightState.initial(seed: seed, p1: a, p2: b);
  for (var f = 0; f < frames; f++) {
    step(s, f < delay ? 0 : l0[f - delay], f < delay ? 0 : l1[f - delay]);
  }
  return s.checksum();
}

/// Two peers over a lossy, laggy, jittery, reordering fake network.
class FakeNet {
  final Random r;
  final int latency, jitter;
  final int lossPct;
  final List<List<NetMsg>> toPeer = [[], []];
  FakeNet(int seed, {this.latency = 3, this.jitter = 3, this.lossPct = 10}) : r = Random(seed);
  int now = 0;

  void send(int to, Uint8List data) {
    if (r.nextInt(100) < lossPct) return;
    toPeer[to].add(NetMsg(now + latency + (jitter > 0 ? r.nextInt(jitter + 1) : 0), Uint8List.fromList(data)));
  }

  List<Uint8List> due(int peer) {
    final out = <Uint8List>[];
    final q = toPeer[peer];
    for (var i = 0; i < q.length;) {
      if (q[i].at <= now) {
        out.add(q.removeAt(i).data);
      } else {
        i++;
      }
    }
    return out;
  }
}

class NetMsg {
  final int at;
  final Uint8List data;
  NetMsg(this.at, this.data);
}

({int c0, int c1, int rollbacks, int desyncs}) twoPeers(CharacterDef a, CharacterDef b, int seed, int frames,
    {int delay = 2, int latency = 3, int jitter = 3, int loss = 10}) {
  final l0 = randomLog(seed * 2 + 1, frames + 8);
  final l1 = randomLog(seed * 2 + 2, frames + 8);
  final net = FakeNet(seed, latency: latency, jitter: jitter, lossPct: loss);
  var desyncs = 0;
  final sessions = <RollbackSession>[];
  for (var i = 0; i < 2; i++) {
    sessions.add(RollbackSession(
      localIndex: i,
      initial: FightState.initial(seed: seed, p1: a, p2: b),
      inputDelay: delay,
      send: (d) => net.send(1 - i, d),
      onDesync: (f, x, y) => desyncs++,
    ));
  }
  final logs = [l0, l1];
  var guard = 0;
  while ((sessions[0].state.frame < frames || sessions[1].state.frame < frames || sessions[0].confirmedFrame < frames || sessions[1].confirmedFrame < frames) &&
      guard++ < frames * 40) {
    net.now++;
    for (var i = 0; i < 2; i++) {
      final s = sessions[i];
      for (final d in net.due(i)) {
        s.receive(d);
      }
      if (s.state.frame < frames) {
        s.tick(logs[i][s.state.frame]);
      } else {
        s.pump();
      }
    }
  }
  expect(guard, lessThan(frames * 40), reason: 'sessions must finish');
  for (final s in sessions) {
    s.flush();
  }
  return (c0: sessions[0].state.checksum(), c1: sessions[1].state.checksum(), rollbacks: sessions[0].rollbacks + sessions[1].rollbacks, desyncs: desyncs);
}

void main() {
  test('determinism: same seed and input log give the same checksum twice', () {
    final l0 = randomLog(1, 900), l1 = randomLog(2, 900);
    final a = straightRun(kai, nyx, 5, l0, l1, 0, 900);
    final b = straightRun(kai, nyx, 5, l0, l1, 0, 900);
    expect(a, b);
    expect(straightRun(kai, nyx, 6, l0, l1, 0, 900), isNot(a), reason: 'a different seed changes the tail of the sim');
  });

  test('copy() is a deep snapshot: resimulating from it reproduces the run', () {
    final l0 = randomLog(3, 400), l1 = randomLog(4, 400);
    final s = FightState.initial(seed: 9, p1: tank, p2: mojo);
    for (var f = 0; f < 200; f++) {
      step(s, l0[f], l1[f]);
    }
    final snap = s.copy();
    expect(snap.checksum(), s.checksum());
    for (var f = 200; f < 400; f++) {
      step(s, l0[f], l1[f]);
    }
    for (var f = 200; f < 400; f++) {
      step(snap, l0[f], l1[f]);
    }
    expect(snap.checksum(), s.checksum());
  });

  test('values stay inside signed 32-bit', () {
    final l0 = randomLog(11, 1500), l1 = randomLog(12, 1500);
    final s = FightState.initial(seed: 3, p1: kai, p2: mojo);
    s.p[0].meter = meterMax;
    s.p[1].meter = meterMax;
    for (var f = 0; f < 1500; f++) {
      step(s, l0[f], l1[f]);
      for (final p in s.p) {
        for (final v in [p.x, p.y, p.vx, p.vy, p.health, p.meter, s.rng]) {
          expect(v.abs() < 2147483647, isTrue);
        }
      }
    }
  });

  group('rollback equivalence fuzz', () {
    for (var i = 0; i < roster.length; i++) {
      for (var j = 0; j < roster.length; j++) {
        test('${roster[i].name} vs ${roster[j].name}: two lossy peers match the straight run', () {
          const frames = 420;
          const delay = 2;
          final seed = 100 + i * 4 + j;
          final l0 = randomLog(seed * 2 + 1, frames + 8);
          final l1 = randomLog(seed * 2 + 2, frames + 8);
          final expected = _straightWithMeter(roster[i], roster[j], seed, l0, l1, delay, frames);
          final r = twoPeers(roster[i], roster[j], seed, frames, delay: delay);
          expect(r.c0, expected, reason: 'peer 0');
          expect(r.c1, expected, reason: 'peer 1');
          expect(r.desyncs, 0);
          expect(r.rollbacks, greaterThan(0), reason: 'the fuzz must actually exercise rollback');
        });
      }
    }
  });
}

int _straightWithMeter(CharacterDef a, CharacterDef b, int seed, List<int> l0, List<int> l1, int delay, int frames) {
  final s = FightState.initial(seed: seed, p1: a, p2: b);
  for (var f = 0; f < frames; f++) {
    step(s, f < delay ? 0 : l0[f - delay], f < delay ? 0 : l1[f - delay]);
  }
  return s.checksum();
}
