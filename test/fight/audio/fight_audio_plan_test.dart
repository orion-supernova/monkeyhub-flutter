import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/fight_audio_plan.dart';

class _Sink implements SoundSink {
  final List<SoundCue> played = [];
  @override
  void play(SoundCue cue) => played.add(cue);
}

CharacterDef _char() => roster.first;

FightState _fresh() => FightState.initial(seed: 1, p1: _char(), p2: _char());

void main() {
  FightSoundPlanner planner() => FightSoundPlanner(random: math.Random(1));

  group('events', () {
    test('each event plays once across repeated calls', () {
      final s = _fresh();
      s.phase = Phase.fight;
      s.frame = 100;
      s.addEvent(Ev.hit, 60000, 8000, 0, 30);
      final p = planner();
      final first = p.plan(s, localPlayer: 0).where((c) => c.sfx == Sfx.hitLight).toList();
      expect(first, hasLength(1));
      expect(p.plan(s, localPlayer: 0).where((c) => c.sfx == Sfx.hitLight), isEmpty);
      s.frame = 101;
      expect(p.plan(s, localPlayer: 0).where((c) => c.sfx == Sfx.hitLight), isEmpty);
    });

    test('a rollback replay re-emitting the same event does not replay it', () {
      final s = _fresh();
      s.phase = Phase.fight;
      s.frame = 100;
      s.addEvent(Ev.hit, 60000, 8000, 0, 70);
      final p = planner();
      expect(p.plan(s, localPlayer: 0).where((c) => c.sfx == Sfx.hitHeavy), hasLength(1));
      // Rewind to an earlier snapshot and re-simulate: same event again.
      final replay = _fresh()
        ..phase = Phase.fight
        ..frame = 100;
      replay.addEvent(Ev.hit, 60000, 8000, 0, 70);
      expect(p.plan(replay, localPlayer: 0).where((c) => c.sfx == Sfx.hitHeavy), isEmpty);
    });

    test('distinct events on the same frame both play', () {
      final s = _fresh()
        ..phase = Phase.fight
        ..frame = 50;
      s.addEvent(Ev.hit, 30000, 8000, 0, 30);
      s.addEvent(Ev.hit, 90000, 8000, 1, 30);
      final got = planner().plan(s, localPlayer: 0).where((c) => c.sfx == Sfx.hitLight);
      expect(got, hasLength(2));
    });

    test('pan follows x, pitch jitter stays within 4 percent', () {
      final s = _fresh()
        ..phase = Phase.fight
        ..frame = 50;
      s.addEvent(Ev.block, 0, 8000, 1);
      s.addEvent(Ev.block, stageWidth, 8000, 0);
      final got = planner().plan(s, localPlayer: 0).where((c) => c.sfx == Sfx.block).toList();
      expect(got[0].pan, closeTo(-0.7, 1e-9));
      expect(got[1].pan, closeTo(0.7, 1e-9));
      for (final c in got) {
        expect(c.speed, inInclusiveRange(0.96, 1.04));
      }
    });

    test('stale events from a long-gone frame are swallowed silently', () {
      final s = _fresh()
        ..phase = Phase.fight
        ..frame = 100;
      s.addEvent(Ev.ko, 60000, 8000, 1);
      final p = planner();
      s.frame = 200;
      expect(p.plan(s, localPlayer: 0).where((c) => c.sfx == Sfx.ko), isEmpty);
    });

    test('a new match (frame counter restarts) plays its callouts again', () {
      final p = planner();
      final a = _fresh()..frame = 400;
      a.phase = Phase.fight;
      p.plan(a, localPlayer: 0);
      final b = _fresh();
      expect(p.plan(b, localPlayer: 0).map((c) => c.sfx), contains(Sfx.roundStart));
    });
  });

  group('derived sounds', () {
    test('a swing whoosh on move frame 1, once, classed by move', () {
      final s = _fresh()
        ..phase = Phase.fight
        ..frame = 60;
      final f = s.p[0];
      f.state = St.move;
      f.sf = 1;
      f.moveId = N.standLight;
      final p = planner();
      expect(p.plan(s, localPlayer: 0).map((c) => c.sfx), contains(Sfx.whooshLight));
      expect(p.plan(s, localPlayer: 0).map((c) => c.sfx), isNot(contains(Sfx.whooshLight)));
      s.frame = 61;
      f.sf = 2;
      expect(p.plan(s, localPlayer: 0).map((c) => c.sfx), isNot(contains(Sfx.whooshLight)));

      s.frame = 90;
      f.sf = 1;
      f.moveId = N.standHeavy;
      f.serial = 5;
      expect(p.plan(s, localPlayer: 0).map((c) => c.sfx), contains(Sfx.whooshHeavy));
    });

    test('round callouts follow the phase, once per round', () {
      final s = _fresh();
      final p = planner();
      expect(p.plan(s, localPlayer: 0).map((c) => c.sfx), [Sfx.roundStart]);
      expect(p.plan(s, localPlayer: 0), isEmpty);
      s.phase = Phase.fight;
      s.frame = 90;
      expect(p.plan(s, localPlayer: 0).map((c) => c.sfx), [Sfx.roundFight]);
      s.frame = 91;
      expect(p.plan(s, localPlayer: 0), isEmpty);
    });

    test('victory for the local winner, defeat for the loser, by localPlayer', () {
      FightState over(int winner) => _fresh()
        ..phase = Phase.over
        ..matchWinner = winner
        ..frame = 500;
      expect(planner().plan(over(0), localPlayer: 0).map((c) => c.sfx), contains(Sfx.victory));
      expect(planner().plan(over(0), localPlayer: 1).map((c) => c.sfx), contains(Sfx.defeat));
      expect(planner().plan(over(1), localPlayer: 1).map((c) => c.sfx), contains(Sfx.victory));
      expect(planner().plan(over(1), localPlayer: 0).map((c) => c.sfx), contains(Sfx.defeat));
      final draw = planner().plan(over(2), localPlayer: 0).map((c) => c.sfx);
      expect(draw, isNot(contains(Sfx.victory)));
      expect(draw, isNot(contains(Sfx.defeat)));
    });

    test('the jingle plays once even if the over state is re-fed', () {
      final p = planner();
      final s = _fresh()
        ..phase = Phase.over
        ..matchWinner = 0
        ..frame = 500;
      expect(p.plan(s, localPlayer: 0).map((c) => c.sfx), contains(Sfx.victory));
      s.frame = 501;
      expect(p.plan(s, localPlayer: 0).map((c) => c.sfx), isNot(contains(Sfx.victory)));
    });
  });

  group('director gates', () {
    FightState hitFrame(int frame) {
      final s = _fresh()
        ..phase = Phase.fight
        ..frame = frame;
      s.addEvent(Ev.hit, 60000, 8000, 0, 30);
      return s;
    }

    test('plays when sound is on and no call is live', () {
      final sink = _Sink();
      final d = FightAudioDirector(sink: sink, soundOn: () => true, callActive: () => false, planner: planner());
      d.onFrame(hitFrame(10), localPlayer: 0);
      expect(sink.played.map((c) => c.sfx), contains(Sfx.hitLight));
    });

    test('muted plays nothing, and unmuting does not replay what was missed', () {
      final sink = _Sink();
      var on = false;
      final d = FightAudioDirector(sink: sink, soundOn: () => on, callActive: () => false, planner: planner());
      d.onFrame(hitFrame(10), localPlayer: 0);
      expect(sink.played, isEmpty);
      on = true;
      d.onFrame(hitFrame(10), localPlayer: 0);
      expect(sink.played, isEmpty);
    });

    test('an active call keeps everything silent, ui sounds included', () {
      final sink = _Sink();
      final d = FightAudioDirector(sink: sink, soundOn: () => true, callActive: () => true, planner: planner());
      d.onFrame(hitFrame(10), localPlayer: 0);
      expect(d.ui(Sfx.uiTick), isFalse);
      expect(sink.played, isEmpty);
    });

    test('a burst is capped per frame, keeping the highest priorities', () {
      final sink = _Sink();
      final d = FightAudioDirector(sink: sink, soundOn: () => true, callActive: () => false, planner: planner(), maxPerFrame: 3);
      final s = _fresh()
        ..phase = Phase.fight
        ..frame = 70;
      s.addEvent(Ev.land, 20000, 0, 0);
      s.addEvent(Ev.dash, 30000, 0, 1, 1);
      s.addEvent(Ev.hit, 40000, 0, 0, 30);
      s.addEvent(Ev.ko, 50000, 0, 1);
      s.addEvent(Ev.counterHit, 60000, 0, 0, 40);
      d.onFrame(s, localPlayer: 0);
      expect(sink.played, hasLength(3));
      expect(sink.played.map((c) => c.sfx), containsAll([Sfx.ko, Sfx.hitCounter]));
      expect(sink.played.map((c) => c.sfx), isNot(contains(Sfx.land)));
    });

    test('the same sound is rate-limited between consecutive frames', () {
      final sink = _Sink();
      final d = FightAudioDirector(sink: sink, soundOn: () => true, callActive: () => false, planner: planner());
      var s = hitFrame(10);
      s.addEvent(Ev.land, 20000, 0, 0);
      d.onFrame(s, localPlayer: 0);
      s = hitFrame(11);
      s.addEvent(Ev.land, 21000, 0, 1);
      d.onFrame(s, localPlayer: 0);
      expect(sink.played.where((c) => c.sfx == Sfx.land), hasLength(1));
    });
  });
}
