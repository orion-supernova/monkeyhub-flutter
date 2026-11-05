// ignore_for_file: avoid_print, avoid_relative_lib_imports
// Cross-platform determinism check. Plays fixed, scripted input logs and bot
// matches for every matchup and prints checksums. The output must be
// byte-identical on the Dart VM and compiled to JS:
//
//   dart run tool/fight/golden.dart
//   dart compile js tool/fight/golden.dart -o /tmp/golden.js && node /tmp/golden.js

import '../../lib/fight/core/core.dart';

/// Scripted "recorded" input log from an integer LCG (identical everywhere).
List<int> scriptedLog(int seed, int frames) {
  var r = seed % 2147483647 + 1;
  int next(int n) {
    r = (r * 1664525 + 1013904223) % 4294967296;
    return (r ~/ 65536) % n;
  }

  const dirs = [0, Inp.left, Inp.right, Inp.down, Inp.up, Inp.left | Inp.down, Inp.right | Inp.down, Inp.up | Inp.right, Inp.up | Inp.left];
  const btns = [Inp.light, Inp.heavy, Inp.special, Inp.roll, Inp.light | Inp.heavy, Inp.special | Inp.heavy, Inp.superBtn, Inp.special | Inp.heavy | Inp.light];
  final out = <int>[];
  var dir = 0, left = 0;
  while (out.length < frames) {
    if (left <= 0) {
      dir = dirs[next(dirs.length)];
      left = 2 + next(14);
    }
    left--;
    out.add(dir | (next(100) < 14 ? btns[next(btns.length)] : 0));
  }
  return out;
}

String _u(int v) => (v % 4294967296).toString();

void main() {
  const frames = 1800;
  var combined = 2166136261;
  for (final a in roster) {
    for (final b in roster) {
      final seed = 1000 + a.id * 10 + b.id;
      // 1. scripted logs, with a meter boost so supers and EX moves fire.
      final l0 = scriptedLog(seed * 2, frames), l1 = scriptedLog(seed * 2 + 1, frames);
      final s = FightState.initial(seed: seed, p1: a, p2: b);
      final marks = StringBuffer();
      for (var f = 0; f < frames; f++) {
        if (f % 300 == 0) {
          s.p[0].meter = meterMax;
          s.p[1].meter = meterMax;
        }
        step(s, l0[f], l1[f]);
        if ((f + 1) % 600 == 0) marks.write(' ${_u(s.checksum())}');
      }
      // 2. bot vs bot.
      final t = FightState.initial(seed: seed + 5000, p1: a, p2: b);
      final b0 = FightBot(seed: seed, level: BotLevel.hard), b1 = FightBot(seed: seed + 1, level: BotLevel.normal);
      for (var f = 0; f < frames; f++) {
        step(t, b0.decide(t, 0), b1.decide(t, 1));
      }
      final line = '${a.name}-${b.name} script:${_u(s.checksum())}$marks bots:${_u(t.checksum())} hp:${s.p[0].health}/${s.p[1].health} ${t.p[0].health}/${t.p[1].health} r${s.round}/${t.round}';
      print(line);
      combined = (combined * 31 + s.checksum() + t.checksum()) % 4294967296;
    }
  }
  print('combined $combined');
}
