import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/haptic_tick.dart';
import 'package:monkeyhub/widgets/swipe_fork.dart';

/// The swipe-up fork: the pure state machine and options first, then the real
/// gesture over a real reversed list.

ForkOption vanishOn = const ForkOption(ForkKind.vanishOn);
ForkOption talk = const ForkOption(ForkKind.startHuddle);

ForkMachine twoOptions() =>
    ForkMachine()..begin(left: vanishOn, right: talk);

void main() {
  group('options matrix', () {
    List<ForkKind> kinds(ForkRoomState s) =>
        [for (final o in forkOptionsFor(s)) o.kind];

    test('DM or group, vanish off: vanish + talk', () {
      expect(kinds(const ForkRoomState()),
          [ForkKind.vanishOn, ForkKind.startHuddle]);
    });
    test('vanish already on: left is Turn off, never a second turn on', () {
      expect(kinds(const ForkRoomState(vanishOn: true)),
          [ForkKind.vanishOff, ForkKind.startHuddle]);
    });
    test('others in a huddle: right is Join', () {
      final o = forkOptionsFor(
          const ForkRoomState(othersHuddle: true, huddleCount: 3)).last;
      expect(o.kind, ForkKind.joinHuddle);
      expect(o.joinCount, 3);
    });
    test('secret room: talk only (single pull)', () {
      expect(kinds(const ForkRoomState(isSecret: true)), [ForkKind.startHuddle]);
    });
    test('group without settings rights: talk only', () {
      expect(kinds(const ForkRoomState(canEditVanish: false)),
          [ForkKind.startHuddle]);
    });
    test('already in a call: vanish only', () {
      expect(kinds(const ForkRoomState(inCall: true)), [ForkKind.vanishOn]);
    });
    test('secret and in a call: nothing (bounce only)', () {
      expect(forkOptionsFor(const ForkRoomState(isSecret: true, inCall: true)),
          isEmpty);
    });
    test('in a call beats a live huddle: no join', () {
      expect(kinds(const ForkRoomState(inCall: true, othersHuddle: true)),
          [ForkKind.vanishOn]);
    });
  });

  group('machine thresholds', () {
    test('pull: progress follows dy, the list lift is 1:1 then rubber-banded', () {
      final m = twoOptions();
      m.update(64, 200);
      expect(m.phase, ForkPhase.pull);
      expect(m.progress, closeTo(0.5, 1e-9));
      expect(m.travel, 64);
      m.update(96, 200);
      m.update(228, 200);
      expect(m.travel, closeTo(128 + 100 * 0.35, 1e-9));
    });

    test('forks at 128, not before', () {
      final m = twoOptions();
      expect(m.update(127.9, 200), isEmpty);
      expect(m.update(128, 200), [ForkEvent.forked]);
      expect(m.phase, ForkPhase.fork);
    });

    test('un-fork hysteresis: stays forked down to 100, collapses under it', () {
      final m = twoOptions();
      m.update(150, 200);
      expect(m.update(110, 200), isEmpty);
      expect(m.phase, ForkPhase.fork);
      expect(m.update(100.5, 200), isEmpty);
      expect(m.update(99.9, 200), [ForkEvent.unforked]);
      expect(m.phase, ForkPhase.pull);
      // And it needs the full 128 again to re-fork.
      expect(m.update(120, 200), isEmpty);
      expect(m.update(128, 200), [ForkEvent.forked]);
    });

    test('arm at 48 from the thumb x at bloom, disarm under 26', () {
      final m = twoOptions();
      m.update(140, 300); // bloom at x=300 (right edge case works: relative)
      expect(m.update(140, 253), isEmpty);
      expect(m.update(140, 252), [ForkEvent.armed]);
      expect(m.armed, ForkSide.left);
      // hysteresis: 30 away is still armed
      expect(m.update(140, 270), isEmpty);
      expect(m.armed, ForkSide.left);
      expect(m.update(140, 275), [ForkEvent.disarmed]); // 25 away: under 26
      expect(m.armed, isNull);
    });

    test('disarm emits disarmed; swapping sides emits swapped', () {
      final m = twoOptions();
      m.update(140, 200);
      m.update(140, 250);
      expect(m.armed, ForkSide.right);
      expect(m.update(140, 150), [ForkEvent.swapped]);
      expect(m.armed, ForkSide.left);
      expect(m.update(140, 195), [ForkEvent.disarmed]);
      expect(m.armed, isNull);
    });

    test('un-forking drops the arm silently', () {
      final m = twoOptions();
      m.update(140, 200);
      m.update(140, 250);
      expect(m.armed, ForkSide.right);
      final e = m.update(60, 250);
      expect(e, [ForkEvent.unforked]);
      expect(m.armed, isNull);
    });

    test('slide progress is 0..1 over the arm distance', () {
      final m = twoOptions();
      m.update(140, 200);
      m.update(140, 224);
      expect(m.slide, closeTo(0.5, 1e-9));
      expect(m.slideSigned, closeTo(0.5, 1e-9));
      m.update(140, 300);
      expect(m.slide, 1);
    });
  });

  group('machine release', () {
    test('armed release commits that side', () {
      final m = twoOptions();
      m.update(140, 200);
      m.update(140, 150);
      final out = m.end(0);
      expect(out.committed, isTrue);
      expect(out.option, vanishOn);
      expect(out.side, ForkSide.left);
      expect(m.active, isFalse);
    });

    test('unarmed release in the middle cancels', () {
      final m = twoOptions();
      m.update(140, 200);
      expect(m.end(0).committed, isFalse);
    });

    test('release before the line cancels, even armed-looking sideways', () {
      final m = twoOptions();
      m.update(90, 200);
      m.update(90, 100);
      expect(m.end(900).committed, isFalse);
    });

    test('flick > 600pt/s past the line arms that side on release', () {
      var m = twoOptions()..update(140, 200);
      var out = m.end(-601);
      expect(out.option, vanishOn);
      m = twoOptions()..update(140, 200);
      out = m.end(601);
      expect(out.option, talk);
      m = twoOptions()..update(140, 200);
      expect(m.end(600).committed, isFalse);
      m = twoOptions()..update(140, 200);
      expect(m.end(-300).committed, isFalse);
    });

    test('a flick before the line does nothing', () {
      final m = twoOptions()..update(80, 200);
      expect(m.end(-900).committed, isFalse);
    });

    test('reset (second finger / background) leaves nothing armed', () {
      final m = twoOptions();
      m.update(140, 200);
      m.update(140, 250);
      m.reset();
      expect(m.active, isFalse);
      expect(m.armed, isNull);
      expect(m.update(200, 200), isEmpty);
    });
  });

  group('machine single option', () {
    ForkMachine single() => ForkMachine()..begin(right: talk);

    test('there is no sliding or arming', () {
      final m = single();
      expect(m.single, isTrue);
      m.update(140, 200);
      expect(m.update(140, 400), isEmpty);
      expect(m.armed, isNull);
    });

    test('release past the line commits the only option', () {
      final m = single()..update(140, 200);
      final out = m.end(0);
      expect(out.committed, isTrue);
      expect(out.option, talk);
    });

    test('release before the line cancels', () {
      final m = single()..update(90, 200);
      expect(m.end(0).committed, isFalse);
    });

    test('dropping under 72 after forking cancels', () {
      final m = single()..update(140, 200);
      m.update(60, 200);
      expect(m.end(0).committed, isFalse);
    });

    test('a left-only option commits too', () {
      final m = ForkMachine()..begin(left: vanishOn);
      m.update(140, 200);
      expect(m.end(0).option, vanishOn);
    });
  });

  group('machine robustness', () {
    test('up/down oscillation never sticks: every cycle forks and unforks', () {
      final m = twoOptions();
      for (var i = 0; i < 20; i++) {
        expect(m.update(140, 200), [ForkEvent.forked], reason: 'cycle $i');
        expect(m.phase, ForkPhase.fork);
        expect(m.update(60, 200), [ForkEvent.unforked], reason: 'cycle $i');
        expect(m.phase, ForkPhase.pull);
        expect(m.armed, isNull);
        expect(m.dx, 0);
      }
      expect(m.end(0).committed, isFalse);
      expect(m.active, isFalse);
    });

    test('arming survives oscillation: each fork re-anchors at the new x', () {
      final m = twoOptions();
      m.update(140, 200);
      m.update(140, 260);
      expect(m.armed, ForkSide.right);
      m.update(60, 260); // drop under the un-fork line
      expect(m.armed, isNull);
      // Back up at a different x: the anchor is the thumb there, not 200.
      expect(m.update(140, 300), [ForkEvent.forked]);
      expect(m.dx, 0);
      expect(m.armed, isNull);
      expect(m.update(140, 360), [ForkEvent.armed]);
      expect(m.end(0).option, talk);
    });

    test('a release right after an un-fork cancels', () {
      final m = twoOptions();
      m.update(140, 200);
      m.update(140, 260);
      m.update(60, 260);
      expect(m.end(0).committed, isFalse);
    });

    test('ending twice (double lift, lift after reset) is a harmless cancel', () {
      final m = twoOptions()..update(140, 200);
      m.end(0);
      expect(m.end(0).committed, isFalse);
      m.reset();
      expect(m.end(900).committed, isFalse);
      expect(m.update(140, 200), isEmpty);
    });

    test('begin() after a half-finished gesture starts clean', () {
      final m = twoOptions();
      m.update(140, 200);
      m.update(140, 260);
      m.begin(left: vanishOn, right: talk);
      expect(m.phase, ForkPhase.pull);
      expect(m.armed, isNull);
      expect(m.dy, 0);
      expect(m.dx, 0);
    });

    test('anchored halves: the side is the screen half, armed by a move toward it',
        () {
      final m = ForkMachine()
        ..armAt = 28
        ..disarmAt = 14
        ..begin(left: vanishOn, right: talk, anchorX: 200);
      // Forks with the finger already on the right half: NOT armed, or a
      // plain pull-and-release would commit huddle (the accidental open).
      expect(m.update(140, 300), [ForkEvent.forked]);
      expect(m.armed, isNull);
      expect(m.update(140, 310), isEmpty, reason: 'under the travel gate');
      expect(m.update(140, 324), [ForkEvent.armed]);
      expect(m.armed, ForkSide.right);
      expect(m.update(140, 205), [ForkEvent.disarmed]);
      expect(m.update(140, 120), [ForkEvent.armed]);
      expect(m.armed, ForkSide.left);
      expect(m.end(0).option, vanishOn);
    });
  });

  group('machine accidental-open guards', () {
    ForkMachine timed() => ForkMachine()..begin(left: vanishOn, right: talk);

    test('a quick flick past the line does not open the fork', () {
      final m = timed();
      m.update(40, 200, ms: 0);
      m.update(90, 200, ms: 40);
      expect(m.update(160, 200, ms: 80), isEmpty, reason: 'too soon, too fast');
      expect(m.phase, ForkPhase.pull);
      expect(m.end(0).committed, isFalse);
    });

    test('a steady deliberate pull opens it', () {
      final m = timed();
      var opened = false;
      for (var t = 0; t <= 400; t += 16) {
        final events = m.update(t * 0.4, 200, ms: t); // 400pt/s
        if (events.contains(ForkEvent.forked)) opened = true;
      }
      expect(opened, isTrue);
      expect(m.phase, ForkPhase.fork);
    });

    test('fast then resting at the line: it opens once the finger has settled',
        () {
      final m = timed();
      m.update(60, 200, ms: 0);
      expect(m.update(150, 200, ms: 60), isEmpty);
      // Held still: re-asked on a timer with unchanged values.
      var opened = false;
      for (var t = 76; t <= 600; t += 16) {
        if (m.update(150, 200, ms: t).contains(ForkEvent.forked)) opened = true;
      }
      expect(opened, isTrue);
    });

    test('without timestamps the distance alone decides (legacy callers)', () {
      final m = timed();
      expect(m.update(130, 200), [ForkEvent.forked]);
    });
  });

  group('ForkBuzz', () {
    testWidgets('pulses continuously, even with the finger held still, then stops',
        (t) async {
      final plays = <double>[];
      var level = 0.5;
      final b = ForkBuzz(
        intensity: () => level,
        tier: HapticTier.full,
        capable: true,
        play: plays.add,
      )..start();
      await t.pump(const Duration(milliseconds: 280));
      expect(plays.length, inInclusiveRange(8, 11));
      level = 0.8;
      await t.pump(const Duration(milliseconds: 56));
      expect(plays.last, 0.8);
      b.stop();
      final n = plays.length;
      await t.pump(const Duration(milliseconds: 300));
      expect(plays.length, n, reason: 'silent the instant it is stopped');
      expect(b.running, isFalse);
    });

    testWidgets('a thinned motor gets a wider gap; landmarks/desktop never buzz',
        (t) async {
      final thin = <double>[];
      final a = ForkBuzz(
          intensity: () => 0.5,
          tier: HapticTier.thinned,
          capable: true,
          play: thin.add)
        ..start();
      await t.pump(const Duration(milliseconds: 440));
      expect(thin.length, inInclusiveRange(9, 10));
      a.stop();
      final none = <double>[];
      for (final (tier, capable) in [
        (HapticTier.landmarks, true),
        (HapticTier.silent, true),
        (HapticTier.full, false),
      ]) {
        final b = ForkBuzz(
            intensity: () => 1, tier: tier, capable: capable, play: none.add)
          ..start();
        await t.pump(const Duration(milliseconds: 200));
        b.stop();
      }
      expect(none, isEmpty);
    });

    testWidgets('silence below the floor', (t) async {
      final plays = <double>[];
      final b = ForkBuzz(
          intensity: () => 0.01,
          tier: HapticTier.full,
          capable: true,
          play: plays.add)
        ..start();
      await t.pump(const Duration(milliseconds: 200));
      b.stop();
      expect(plays, isEmpty);
    });
  });

  group('gesture over a list', () {
    late List<String> log;
    late SwipeForkController fork;
    bool allowed = true;
    bool halves = false;
    ForkRoomState room = const ForkRoomState();
    Object? failWith;
    int builds = 0;

    Future<void> pumpScene(
      WidgetTester tester, {
      TargetPlatform platform = TargetPlatform.android,
      double dock = 60,
    }) async {
      log = [];
      allowed = true;
      halves = false;
      room = const ForkRoomState();
      failWith = null;
      builds = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: _Host(
            dock: dock,
            onBuild: () => builds++,
            build: (vsync) => fork = SwipeForkController(
              vsync: vsync,
              hapticTier: HapticTier.silent,
              fullScreen: () => halves,
              clockMs: () => tester.binding.clock.now().millisecondsSinceEpoch,
              canArm: () => allowed,
              roomState: () => room,
              failureText: (e) => 'nope',
              onStartHuddle: () async {
                log.add('huddle');
                if (failWith != null) throw failWith!;
              },
              onJoinHuddle: () async => log.add('join'),
              onToggleVanish: (on) async => log.add('vanish:$on'),
            ),
          ),
        ),
      ));
    }

    /// Lets springs, fades and the commit's awaited futures all finish.
    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<TestGesture> pull(WidgetTester t, double up, {double x = 200}) async {
      final g = await t.startGesture(Offset(x, 560));
      for (var i = 0; i < up ~/ 10; i++) {
        await g.moveBy(const Offset(0, -10));
        await t.pump(const Duration(milliseconds: 16));
      }
      return g;
    }

    Future<void> slide(WidgetTester t, TestGesture g, double dx) async {
      final step = dx.sign * 10;
      for (var i = 0; i < dx.abs() ~/ 10; i++) {
        await g.moveBy(Offset(step, 0));
        await t.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('pull, fork, arm right, release: talk commits', (t) async {
      await pumpScene(t);
      final g = await pull(t, 150);
      expect(fork.machine.phase, ForkPhase.fork);
      expect(fork.visible.value, isTrue);
      await slide(t, g, 50);
      expect(fork.machine.armed, ForkSide.right);
      await g.up();
      await t.pump();
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(log, ['huddle']);
      expect(fork.visible.value, isFalse);
    });

    testWidgets('arm left commits vanish on', (t) async {
      await pumpScene(t);
      final g = await pull(t, 150);
      await slide(t, g, -50);
      await g.up();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(log, ['vanish:true']);
    });

    testWidgets('vanish already on commits vanish off', (t) async {
      await pumpScene(t);
      room = const ForkRoomState(vanishOn: true);
      final g = await pull(t, 150);
      await slide(t, g, -50);
      await g.up();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(log, ['vanish:false']);
    });

    testWidgets('release in the middle cancels', (t) async {
      await pumpScene(t);
      final g = await pull(t, 150);
      await slide(t, g, 20);
      await g.up();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(log, isEmpty);
      expect(fork.visible.value, isFalse);
    });

    testWidgets('single option: release past the line commits it', (t) async {
      await pumpScene(t);
      room = const ForkRoomState(isSecret: true);
      final g = await pull(t, 150);
      await g.up();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(log, ['huddle']);
    });

    testWidgets('closed gate: nothing arms, the list scrolls', (t) async {
      await pumpScene(t);
      allowed = false;
      final g = await pull(t, 150);
      expect(fork.visible.value, isFalse);
      await g.up();
      await t.pump();
      expect(log, isEmpty);
    });

    testWidgets('no options: nothing arms', (t) async {
      await pumpScene(t);
      room = const ForkRoomState(isSecret: true, inCall: true);
      final g = await pull(t, 150);
      expect(fork.visible.value, isFalse);
      await g.up();
    });

    testWidgets('options are captured when the pull begins', (t) async {
      await pumpScene(t);
      final g = await t.startGesture(const Offset(200, 560));
      await g.moveBy(const Offset(0, -10));
      await t.pump(const Duration(milliseconds: 16));
      expect(fork.visible.value, isTrue, reason: 'the pull has begun');
      room = const ForkRoomState(isSecret: true); // changes mid-gesture
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(0, -10));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(fork.options.length, 2);
      await g.up();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('a downward drag is left to the list', (t) async {
      await pumpScene(t);
      final g = await t.startGesture(const Offset(200, 400));
      await g.moveBy(const Offset(0, 60));
      await t.pump();
      expect(fork.visible.value, isFalse);
      await g.up();
    });

    testWidgets('a second finger cancels without committing', (t) async {
      await pumpScene(t);
      final g = await pull(t, 150);
      await slide(t, g, 50);
      expect(fork.machine.armed, ForkSide.right);
      final second = await t.startGesture(const Offset(100, 300), pointer: 7);
      await t.pump();
      expect(fork.machine.active, isFalse);
      await second.up();
      await g.up();
      await t.pump(const Duration(seconds: 2));
      expect(log, isEmpty);
      expect(fork.visible.value, isFalse);
    });

    testWidgets('the list itself is pulled up 1:1 with the finger', (t) async {
      await pumpScene(t);
      final rest = t.getTopLeft(find.text('m0')).dy;
      final g = await pull(t, 50);
      expect(fork.lift, closeTo(50, 1e-6));
      expect(t.getTopLeft(find.text('m0')).dy, closeTo(rest - 50, 0.01));
      // The dock does not move or fade: it is not part of the lifted list.
      expect(t.getTopLeft(find.text('dock')).dy, 540);
      await g.up();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('past the line the lift is rubber-banded', (t) async {
      await pumpScene(t);
      room = const ForkRoomState(isSecret: true); // one option: no bloom lift
      final g = await pull(t, 190);
      expect(fork.lift, closeTo(128 + 62 * 0.35, 0.5));
      await g.up();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('the arc fills with the pull', (t) async {
      await pumpScene(t);
      final g = await pull(t, 40);
      expect(fork.pullValue.value, closeTo(40 / 128, 1e-6));
      expect(fork.bloom.value, 0, reason: 'no chips before the line');
      expect(fork.viewForked, isFalse);
      await g.moveBy(const Offset(0, -100));
      await t.pump(const Duration(milliseconds: 16));
      expect(fork.pullValue.value, 1);
      await g.up();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('chips bloom past the line and lift the list a little more',
        (t) async {
      await pumpScene(t);
      final g = await pull(t, 150);
      await t.pump(const Duration(milliseconds: 400));
      expect(fork.viewForked, isTrue);
      expect(fork.bloom.value, closeTo(1, 0.02));
      expect(fork.lift, closeTo(fork.viewTravel + kForkBloomLift, 1));
      await g.up();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('one option: no chips, the glyph takes over at the line',
        (t) async {
      await pumpScene(t);
      room = const ForkRoomState(isSecret: true);
      final g = await pull(t, 150);
      await t.pump(const Duration(milliseconds: 400));
      expect(fork.bloom.value, 0);
      expect(fork.glyph.value, closeTo(1, 0.02));
      expect(fork.lift, closeTo(fork.viewTravel, 1e-6));
      await g.up();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('cancel springs the list back down', (t) async {
      await pumpScene(t);
      final rest = t.getTopLeft(find.text('m0')).dy;
      final g = await pull(t, 150);
      await slide(t, g, 10);
      final lifted = fork.lift;
      expect(lifted, greaterThan(90));
      await g.up();
      await t.pump();
      await t.pump(const Duration(milliseconds: 120));
      expect(fork.lift, lessThan(lifted));
      expect(fork.lift, greaterThan(0));
      await t.pump(const Duration(seconds: 2));
      expect(fork.lift, 0);
      expect(t.getTopLeft(find.text('m0')).dy, rest);
      expect(log, isEmpty);
    });

    testWidgets('commit springs the list back and runs the action', (t) async {
      await pumpScene(t);
      final rest = t.getTopLeft(find.text('m0')).dy;
      final g = await pull(t, 150);
      await slide(t, g, 50);
      await g.up();
      await t.pump(); // the springs start on this frame
      await t.pump(const Duration(milliseconds: 100));
      expect(fork.lift, lessThan(fork.viewTravel + kForkBloomLift));
      expect(log, ['huddle']);
      await t.pump(const Duration(seconds: 2));
      expect(t.getTopLeft(find.text('m0')).dy, rest);
    });

    testWidgets('rows are not rebuilt while the list is pulled', (t) async {
      await pumpScene(t);
      final before = builds;
      final g = await pull(t, 150);
      await slide(t, g, 50);
      await g.up();
      await t.pump(const Duration(seconds: 2));
      expect(builds, before);
    });

    testWidgets('full-screen halves: the half under the finger is the option',
        (t) async {
      await pumpScene(t);
      halves = true;
      var g = await pull(t, 150, x: 100);
      expect(fork.viewHalves, isTrue);
      expect(fork.machine.armed, isNull,
          reason: 'resting off-centre is not a choice');
      await t.pump(const Duration(milliseconds: 300));
      await g.up();
      await settle(t);
      expect(log, isEmpty, reason: 'pull and release cancels');

      g = await pull(t, 150, x: 100);
      await slide(t, g, -30); // a deliberate move into the left half
      expect(fork.machine.armed, ForkSide.left);
      await g.up();
      await settle(t);
      expect(log, ['vanish:true']);
      log.clear();

      g = await pull(t, 150, x: 100);
      await slide(t, g, 600); // across to the right half
      expect(fork.machine.armed, ForkSide.right);
      await g.up();
      await settle(t);
      expect(log, ['huddle']);
    });

    testWidgets('full-screen halves paint a wash over the whole screen',
        (t) async {
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await pumpScene(t);
      halves = true;
      final g = await pull(t, 150, x: 100);
      await t.pump(const Duration(milliseconds: 600));
      final b = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = (await t.runAsync(() => b.toImage()))!;
      final bytes = (await t.runAsync(() => img.toByteData()))!;
      int alphaAt(int x, int y) => bytes.getUint8((y * img.width + x) * 4 + 3);
      // Both halves are tinted, top and bottom, left and right.
      for (final (x, y) in [(20, 20), (380, 20), (20, 700), (380, 700)]) {
        expect(alphaAt(x, y), greaterThan(100), reason: 'at $x,$y');
      }
      await g.up();
      await settle(t);
    });

    testWidgets('a quick flick past the line does not open; resting there does',
        (t) async {
      await pumpScene(t);
      final g = await t.startGesture(const Offset(200, 560));
      for (var i = 0; i < 3; i++) {
        await g.moveBy(const Offset(0, -50));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(fork.machine.dy, greaterThan(128));
      expect(fork.machine.phase, ForkPhase.pull);
      expect(fork.viewForked, isFalse);
      // The finger stops: the beat re-asks and the fork opens.
      await t.pump(const Duration(milliseconds: 400));
      expect(fork.machine.phase, ForkPhase.fork);
      await g.up();
      await settle(t);
    });

    testWidgets('a flick that ends before settling cancels', (t) async {
      await pumpScene(t);
      final g = await t.startGesture(const Offset(200, 560));
      for (var i = 0; i < 3; i++) {
        await g.moveBy(const Offset(0, -50));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settle(t);
      expect(log, isEmpty);
      expect(fork.visible.value, isFalse);
    });

    testWidgets('up, down, up again within one drag: the second pull works',
        (t) async {
      await pumpScene(t);
      final g = await pull(t, 150);
      expect(fork.machine.phase, ForkPhase.fork);
      // All the way down: the fork cancels and its spring-back starts.
      for (var i = 0; i < 16; i++) {
        await g.moveBy(const Offset(0, 10));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(fork.machine.active, isFalse);
      // Straight back up, while that collapse may still be running.
      for (var i = 0; i < 18; i++) {
        await g.moveBy(const Offset(0, -10));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(fork.machine.active, isTrue, reason: 'a new pull began');
      expect(fork.exit, ForkExit.none);
      expect(fork.machine.phase, ForkPhase.fork);
      // And a full second round-trip keeps working.
      for (var i = 0; i < 16; i++) {
        await g.moveBy(const Offset(0, 10));
        await t.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 18; i++) {
        await g.moveBy(const Offset(0, -10));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(fork.machine.phase, ForkPhase.fork);
      await slide(t, g, 50);
      expect(fork.machine.armed, ForkSide.right);
      await g.up();
      await settle(t);
      expect(log, ['huddle']);
      expect(fork.visible.value, isFalse);
    });

    testWidgets('a stale cancel never finishes a newer gesture', (t) async {
      await pumpScene(t);
      var g = await pull(t, 150);
      await g.up(); // cancel in the middle
      await t.pump(const Duration(milliseconds: 30));
      expect(fork.exit, ForkExit.cancel);
      // A new gesture inside the collapse (the list is still lifted away from
      // the old touch point, so it lands higher up).
      g = await t.startGesture(const Offset(200, 300));
      for (var i = 0; i < 15; i++) {
        await g.moveBy(const Offset(0, -10));
        await t.pump(const Duration(milliseconds: 16));
      }
      await t.pump(const Duration(seconds: 1));
      expect(fork.visible.value, isTrue, reason: 'the old collapse did not end it');
      expect(fork.machine.active, isTrue);
      await g.up();
      await settle(t);
      expect(fork.visible.value, isFalse);
    });

    testWidgets('two fingers that lift in either order leave the fork usable',
        (t) async {
      await pumpScene(t);
      final a = await t.startGesture(const Offset(200, 560), pointer: 1);
      final b = await t.startGesture(const Offset(300, 500), pointer: 2);
      await a.up(); // the first finger goes first
      await b.up();
      await t.pump();
      final g = await pull(t, 150);
      expect(fork.machine.phase, ForkPhase.fork, reason: 'no stale second-finger');
      await g.up();
      await settle(t);
    });

    testWidgets('a pointer cancel mid-fork collapses without committing',
        (t) async {
      await pumpScene(t);
      final g = await pull(t, 150);
      await slide(t, g, 50);
      expect(fork.machine.armed, ForkSide.right);
      await g.cancel();
      await settle(t);
      expect(log, isEmpty);
      expect(fork.visible.value, isFalse);
      expect(fork.machine.active, isFalse);
    });

    testWidgets('a failing commit shakes, shows the reason, then collapses',
        (t) async {
      await pumpScene(t);
      failWith = StateError('boom');
      final g = await pull(t, 150);
      await slide(t, g, 50);
      await g.up();
      await t.pump();
      for (var i = 0; i < 9; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(fork.failReason, 'nope');
      expect(fork.visible.value, isTrue);
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(fork.visible.value, isFalse);
    });
  });

  group('from a scrolled list (one continuous drag)', () {
    late SwipeForkController fork;
    late List<String> log;

    Future<void> scene(WidgetTester t,
        {TargetPlatform platform = TargetPlatform.android,
        double dock = 60}) async {
      log = [];
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: _Host(
            dock: dock,
            build: (vsync) => fork = SwipeForkController(
              vsync: vsync,
              hapticTier: HapticTier.silent,
              fullScreen: () => false,
              clockMs: () => t.binding.clock.now().millisecondsSinceEpoch,
              canArm: () => true,
              roomState: () => const ForkRoomState(),
              onStartHuddle: () async => log.add('huddle'),
              onJoinHuddle: () async => log.add('join'),
              onToggleVanish: (on) async => log.add('vanish:$on'),
            ),
          ),
        ),
      ));
    }

    double pixels(WidgetTester t) =>
        t.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

    Future<void> steps(WidgetTester t, TestGesture g, double dy, {int n = 10}) async {
      for (var i = 0; i < n; i++) {
        await g.moveBy(Offset(0, dy / n));
        await t.pump(const Duration(milliseconds: 16));
      }
    }

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets('scroll up, come back down, keep pulling: it forks ($platform)',
          (t) async {
        await scene(t, platform: platform);
        final g = await t.startGesture(const Offset(200, 300));
        // Away from the newest message (finger down = older), then back.
        await steps(t, g, 260, n: 13);
        expect(pixels(t), greaterThan(100));
        expect(fork.visible.value, isFalse);
        await steps(t, g, -200, n: 10);
        expect(fork.visible.value, isFalse, reason: 'still has list to scroll');
        // The rest of the way is the list's; everything after it is the pull.
        await steps(t, g, -(pixels(t) + 20), n: 8);
        expect(pixels(t), 0);
        await steps(t, g, -130, n: 13);
        expect(fork.visible.value, isTrue);
        expect(fork.machine.phase, ForkPhase.fork);
        // Measured from where the list hit the edge, not from touch-down.
        expect(fork.machine.dy, closeTo(150, 3));
        expect(pixels(t), 0, reason: 'the list did not also bounce');
        await g.up();
        await t.pump();
        await t.pump(const Duration(seconds: 2));
        expect(pixels(t), 0, reason: 'and does not coast or bounce after');
      });

      testWidgets('the content moves once while the fork owns the pull ($platform)',
          (t) async {
        await scene(t, platform: platform);
        final rest = t.getTopLeft(find.text('m0')).dy;
        final g = await t.startGesture(const Offset(200, 500));
        await steps(t, g, -50, n: 5);
        expect(fork.lift, closeTo(50, 1));
        expect(pixels(t), 0);
        expect(t.getTopLeft(find.text('m0')).dy, closeTo(rest - fork.lift, 0.01));
        await steps(t, g, -140, n: 14);
        expect(pixels(t), 0);
        await g.up();
        await t.pump();
        await t.pump(const Duration(seconds: 2));
        expect(t.getTopLeft(find.text('m0')).dy, rest);
      });

      testWidgets('pulling back down hands the drag back to the list ($platform)',
          (t) async {
        await scene(t, platform: platform);
        final g = await t.startGesture(const Offset(200, 300));
        await steps(t, g, -60, n: 6);
        expect(fork.visible.value, isTrue);
        // All the way back down, then on: that is a scroll to older messages.
        await steps(t, g, 200, n: 20);
        expect(fork.machine.active, isFalse);
        expect(pixels(t), greaterThan(60));
        await g.up();
        await t.pump();
        await t.pump(const Duration(seconds: 2));
        expect(fork.visible.value, isFalse);
        expect(log, isEmpty);
      });
    }

    testWidgets('a fling that coasts to the newest message does not arm',
        (t) async {
      await scene(t);
      final list = find.byType(ListView);
      await t.fling(list, const Offset(0, 500), 3000); // away
      await t.pumpAndSettle();
      expect(pixels(t), greaterThan(100));
      await t.fling(list, const Offset(0, -500), 4000); // back, ballistic
      for (var i = 0; i < 60; i++) {
        await t.pump(const Duration(milliseconds: 50));
        expect(fork.visible.value, isFalse);
      }
      expect(pixels(t), 0);
      expect(fork.machine.active, isFalse);
    });

    testWidgets('a finger that catches the list at the end can pull',
        (t) async {
      await scene(t);
      await t.fling(find.byType(ListView), const Offset(0, 300), 1500);
      await t.pumpAndSettle();
      await t.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await t.pumpAndSettle();
      expect(pixels(t), 0);
      final g = await t.startGesture(const Offset(200, 500));
      await steps(t, g, -60, n: 6);
      expect(fork.visible.value, isTrue);
      await g.up();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
    });
  });

  group('chips ride the finger', () {
    ForkGeometry geo({double dock = 60, double top = 80}) =>
        ForkGeometry(const Size(400, 800), dock, topInset: top);

    test('the chips are centred on the finger', () {
      final g = geo();
      expect(g.chipCenter(ForkSide.left, 120, 300).dy, 300);
      expect(g.chipCenter(ForkSide.right, 120, 300).dy, 300);
      expect(g.chipCenter(ForkSide.left, 120, 300).dx, lessThan(200));
      expect(g.chipCenter(ForkSide.right, 120, 300).dx, greaterThan(200));
    });

    test('and held between the header and the dock with a margin', () {
      final g = geo(dock: 86);
      final hi = 800 - 86 - ForkGeometry.chipMargin - ForkGeometry.chipH / 2;
      final lo = 80 + ForkGeometry.chipMargin + ForkGeometry.chipH / 2;
      expect(g.chipCenter(ForkSide.left, 120, 790).dy, hi);
      expect(g.chipCenter(ForkSide.right, 120, 10).dy, lo);
    });

    test('circle and caption stay above the dock at every lift', () {
      final g = geo(dock: 86);
      for (var lift = 0.0; lift <= 160; lift += 2) {
        final c = g.circleCenter(lift);
        final bottom = c.dy + ForkGeometry.circle / 2 + 6 + ForkGeometry.captionH * g.captionRoom(lift);
        expect(bottom, lessThanOrEqualTo(g.dockTop), reason: 'lift $lift');
      }
    });
  });

  group('painted pixels', () {
    // The overlay alone, rasterized over nothing: any alpha is something the
    // fork drew.
    Future<ui.Image> shot(WidgetTester t) async {
      final b = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await t.runAsync(() => b.toImage()))!;
    }

    Future<(int, Rect)> inkIn(WidgetTester t, ui.Image img, Rect r) async {
      final bytes = (await t.runAsync(() => img.toByteData()))!;
      var n = 0;
      for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
        for (var x = r.left.floor(); x < r.right.ceil(); x++) {
          if (bytes.getUint8((y * img.width + x) * 4 + 3) != 0) n++;
        }
      }
      return (n, r);
    }

    Future<SwipeForkController> forked(WidgetTester t,
        {double dock = 60, double startY = 400, double pullTo = 150}) async {
      late SwipeForkController c;
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: _Host(
            dock: dock,
            build: (vsync) => c = SwipeForkController(
              vsync: vsync,
              hapticTier: HapticTier.silent,
              fullScreen: () => false,
              clockMs: () => t.binding.clock.now().millisecondsSinceEpoch,
              canArm: () => true,
              roomState: () => const ForkRoomState(),
              onStartHuddle: () async {},
              onJoinHuddle: () async {},
              onToggleVanish: (on) async {},
            ),
          ),
        ),
      ));
      final g = await t.startGesture(Offset(200, startY));
      for (var i = 0; i < pullTo ~/ 10; i++) {
        await g.moveBy(const Offset(0, -10));
        await t.pump(const Duration(milliseconds: 16));
      }
      await t.pump(const Duration(milliseconds: 600));
      return c;
    }

    testWidgets('finger high: the chips are at the finger, not down by the dock',
        (t) async {
      final c = await forked(t, startY: 330);
      expect(c.viewForked, isTrue);
      final img = await shot(t);
      final fingerY = c.thumbY;
      // A row of the left chip's body at the finger's height has ink...
      final (atFinger, _) = await inkIn(t, img, Rect.fromLTWH(30, fingerY - 58, 100, 4));
      expect(atFinger, greaterThan(100));
      // ...and the strip just above the dock, where they used to bloom, has none
      // in the chips' columns.
      final (nearDock, _) = await inkIn(t, img, Rect.fromLTWH(30, 800 - 60 - 40, 100, 20));
      expect(nearDock, 0);
      await t.pump(const Duration(seconds: 2));
    });

    for (final dock in [60.0, 86.0]) {
      for (final startY in [330.0, 560.0, 760.0]) {
        testWidgets('nothing drawn reaches the dock (dock $dock, finger $startY)',
            (t) async {
          final c = await forked(t, dock: dock, startY: startY);
          expect(c.viewForked, isTrue);
          final img = await shot(t);
          final (n, _) = await inkIn(t, img, Rect.fromLTWH(0, 800 - dock, 400, dock));
          expect(n, 0);
          await t.pump(const Duration(seconds: 2));
        });
      }
    }
  });
}

final _boundary = GlobalKey();
final _dockKey = GlobalKey();

class _Host extends StatefulWidget {
  const _Host({required this.build, this.onBuild, this.dock = 60});
  final double dock;
  final SwipeForkController Function(TickerProvider) build;
  final VoidCallback? onBuild;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  late final SwipeForkController c = widget.build(this);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        SwipeForkGesture(
          controller: c,
          child: ForkLift(
            controller: c,
            child: ListView.builder(
              reverse: true,
              // Rows sit above the "dock" strip, as in the room.
              padding: EdgeInsets.only(bottom: widget.dock),
              itemCount: 30,
              itemBuilder: (_, i) {
                widget.onBuild?.call();
                return SizedBox(height: 60, child: Text('m$i'));
              },
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: widget.dock,
          child: IgnorePointer(child: SizedBox(key: _dockKey, child: const Text('dock'))),
        ),
        RepaintBoundary(
          key: _boundary,
          child: SwipeForkOverlay(
            controller: c,
            dockHeight: () => widget.dock,
            dockKey: _dockKey,
            topInset: () => 80,
          ),
        ),
      ]);
}
