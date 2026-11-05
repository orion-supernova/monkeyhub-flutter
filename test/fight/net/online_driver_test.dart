import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/bot.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/net/fight_link.dart';
import 'package:monkeyhub/fight/view/fight_online_screen.dart';

/// One end of an in-memory pipe between two phones. Packets wait in a queue
/// for [latency] delivery rounds and some are dropped, like a real network.
class _Pipe implements FightPipe {
  _Pipe(this._rng, {this.loss = 0});
  final math.Random _rng;
  final double loss;
  late _Pipe peer;
  final List<(int, Uint8List?, Map<String, dynamic>?)> _inbox = [];
  int round = 0;

  void Function(Uint8List)? _onInput;
  void Function(Map<String, dynamic>)? _onControl;
  @override
  set onInput(void Function(Uint8List bytes)? f) => _onInput = f;
  @override
  set onControl(void Function(Map<String, dynamic> msg)? f) => _onControl = f;
  @override
  DateTime lastHeard = DateTime.now();
  @override
  final ValueNotifier<FightLinkState> state = ValueNotifier(FightLinkState.open);

  @override
  void sendInput(Uint8List bytes) {
    if (_rng.nextDouble() < loss) return;
    peer._inbox.add((peer.round + 2 + _rng.nextInt(3), Uint8List.fromList(bytes), null));
  }

  @override
  void sendControl(Map<String, dynamic> msg) => peer._inbox.add((peer.round + 1, null, msg)); // reliable

  /// Delivers what is due this round.
  void deliver() {
    round++;
    final due = _inbox.where((p) => p.$1 <= round).toList();
    _inbox.removeWhere((p) => p.$1 <= round);
    for (final (_, bytes, msg) in due) {
      lastHeard = DateTime.now();
      if (bytes != null) _onInput?.call(bytes);
      if (msg != null) _onControl?.call(msg);
    }
  }
}

void main() {
  test('the seed is a pure function of the match id', () {
    expect(fightSeedFor('k97abc'), fightSeedFor('k97abc'));
    expect(fightSeedFor('k97abc'), isNot(fightSeedFor('k97abd')));
    expect(fightSeedFor('x'), inInclusiveRange(0, 0x3fffffff));
  });

  for (final loss in [0.0, 0.1]) {
    test('two phones, bots on both, ${(loss * 100).round()}% loss: both report the same result', () async {
      final rng = math.Random(7);
      final a = _Pipe(rng, loss: loss), b = _Pipe(rng, loss: loss);
      a.peer = b;
      b.peer = a;
      final reports = <int, String>{};
      OnlineFightDriver driver(_Pipe p, int seat) => OnlineFightDriver(
        link: p,
        localIndex: seat,
        seed: fightSeedFor('match-under-test'),
        report: (action) async {
          reports[seat] = action;
          return true;
        },
        lostText: 'lost',
        pingText: (ms) => 'ping $ms',
      );
      final d0 = driver(a, 0), d1 = driver(b, 1);
      final bot0 = FightBot(seed: 3, level: BotLevel.hard), bot1 = FightBot(seed: 5, level: BotLevel.hard);

      // Seat 0 pings, then says go: let the real-time handshake run.
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (!(d0.started && d1.started) && DateTime.now().isBefore(deadline)) {
        a.deliver();
        b.deliver();
        d0.step(0);
        d1.step(0);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(d0.started && d1.started, isTrue, reason: 'both phones started');

      for (var i = 0; i < 60 * 60 * 8 && reports.length < 2; i++) {
        a.deliver();
        b.deliver();
        d0.step(bot0.decide(d0.state, 0));
        d1.step(bot1.decide(d1.state, 1));
      }
      expect(reports.length, 2, reason: 'both reported');
      expect(reports[0], reports[1]);
      expect(reports[0], matches(RegExp(r'^result:(-1|0|1):\d+$')));
      expect(reports[0], isNot(endsWith(':0')), reason: 'no desync, no lost-peer report');
    });
  }
}
