import 'package:monkeyhub/fight/core/core.dart';

typedef InputFn = int Function(int frame, FightState s);

int none(int f, FightState s) => 0;
InputFn hold(int bits) => (f, s) => bits;

/// Presses [bits] on frame [at] only (a single-frame edge), nothing otherwise.
InputFn tapAt(int bits, [int at = 0]) => (f, s) => f == at ? bits : 0;

/// Fresh fight with the intro skipped and fighters [dist] units apart.
FightState duel(CharacterDef a, CharacterDef b, {int dist = 9000, int x = 50000, int seed = 7}) {
  final s = FightState.initial(seed: seed, p1: a, p2: b);
  var guard = 0;
  while (s.phase != Phase.fight && guard++ < 200) {
    step(s, 0, 0);
  }
  s.p[0].x = x;
  s.p[1].x = x + dist;
  return s;
}

/// Plays [frames] frames; the input functions receive the local frame index.
void play(FightState s, int frames, {InputFn in0 = none, InputFn in1 = none}) {
  for (var f = 0; f < frames; f++) {
    step(s, in0(f, s), in1(f, s));
  }
}

bool sawEvent(FightState s, int kind, {int sinceFrame = 0}) {
  for (final e in s.events) {
    if (e.kind == kind && e.frame >= sinceFrame) return true;
  }
  return false;
}

/// Plays frames and records whether [kind] showed up at any point (the event
/// ring is bounded so scanning only at the end can miss things).
class Watch {
  final Map<int, int> seen = {};
  int _lastFrame = -1;
  void observe(FightState s) {
    for (final e in s.events) {
      if (e.frame > _lastFrame) seen[e.kind] = (seen[e.kind] ?? 0) + 1;
    }
    _lastFrame = s.frame;
  }

  bool has(int kind) => (seen[kind] ?? 0) > 0;
}

Watch playWatch(FightState s, int frames, {InputFn in0 = none, InputFn in1 = none}) {
  final w = Watch();
  w._lastFrame = s.frame;
  for (var f = 0; f < frames; f++) {
    step(s, in0(f, s), in1(f, s));
    w.observe(s);
  }
  return w;
}
