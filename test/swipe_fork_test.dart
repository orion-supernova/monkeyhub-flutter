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
      m.update(48, 200);
      expect(m.phase, ForkPhase.pull);
      expect(m.progress, closeTo(0.5, 1e-9));
      expect(m.travel, 48);
      m.update(96, 200);
      m.update(196, 200);
      expect(m.travel, closeTo(96 + 100 * 0.35, 1e-9));
    });

    test('forks at 96, not at 95', () {
      final m = twoOptions();
      expect(m.update(95.9, 200), isEmpty);
      expect(m.update(96, 200), [ForkEvent.forked]);
      expect(m.phase, ForkPhase.fork);
    });

    test('un-fork hysteresis: stays forked down to 72, collapses under it', () {
      final m = twoOptions();
      m.update(120, 200);
      expect(m.update(80, 200), isEmpty);
      expect(m.phase, ForkPhase.fork);
      expect(m.update(73, 200), isEmpty);
      expect(m.update(71.9, 200), [ForkEvent.unforked]);
      expect(m.phase, ForkPhase.pull);
      // And it needs the full 96 again to re-fork.
      expect(m.update(90, 200), isEmpty);
      expect(m.update(96, 200), [ForkEvent.forked]);
    });

    test('arm at 40 from the thumb x at bloom, disarm under 22', () {
      final m = twoOptions();
      m.update(100, 300); // bloom at x=300 (right edge case works: relative)
      expect(m.update(100, 261), isEmpty);
      expect(m.update(100, 260), [ForkEvent.armed]);
      expect(m.armed, ForkSide.left);
      // hysteresis: 30 away is still armed
      expect(m.update(100, 270), isEmpty);
      expect(m.armed, ForkSide.left);
      expect(m.update(100, 279), [ForkEvent.disarmed]); // 21 away: under 22
      expect(m.armed, isNull);
    });

    test('disarm emits disarmed; swapping sides emits swapped', () {
      final m = twoOptions();
      m.update(100, 200);
      m.update(100, 240);
      expect(m.armed, ForkSide.right);
      expect(m.update(100, 150), [ForkEvent.swapped]);
      expect(m.armed, ForkSide.left);
      expect(m.update(100, 195), [ForkEvent.disarmed]);
      expect(m.armed, isNull);
    });

    test('un-forking drops the arm silently', () {
      final m = twoOptions();
      m.update(100, 200);
      m.update(100, 250);
      expect(m.armed, ForkSide.right);
      final e = m.update(60, 250);
      expect(e, [ForkEvent.unforked]);
      expect(m.armed, isNull);
    });

    test('slide progress is 0..1 over the arm distance', () {
      final m = twoOptions();
      m.update(100, 200);
      m.update(100, 220);
      expect(m.slide, closeTo(0.5, 1e-9));
      m.update(100, 300);
      expect(m.slide, 1);
    });
  });

  group('machine release', () {
    test('armed release commits that side', () {
      final m = twoOptions();
      m.update(100, 200);
      m.update(100, 150);
      final out = m.end(0);
      expect(out.committed, isTrue);
      expect(out.option, vanishOn);
      expect(out.side, ForkSide.left);
      expect(m.active, isFalse);
    });

    test('unarmed release in the middle cancels', () {
      final m = twoOptions();
      m.update(100, 200);
      expect(m.end(0).committed, isFalse);
    });

    test('release before the line cancels, even armed-looking sideways', () {
      final m = twoOptions();
      m.update(90, 200);
      m.update(90, 100);
      expect(m.end(900).committed, isFalse);
    });

    test('flick > 600pt/s past the line arms that side on release', () {
      var m = twoOptions()..update(100, 200);
      var out = m.end(-601);
      expect(out.option, vanishOn);
      m = twoOptions()..update(100, 200);
      out = m.end(601);
      expect(out.option, talk);
      m = twoOptions()..update(100, 200);
      expect(m.end(600).committed, isFalse);
      m = twoOptions()..update(100, 200);
      expect(m.end(-300).committed, isFalse);
    });

    test('a flick before the line does nothing', () {
      final m = twoOptions()..update(80, 200);
      expect(m.end(-900).committed, isFalse);
    });

    test('reset (second finger / background) leaves nothing armed', () {
      final m = twoOptions();
      m.update(100, 200);
      m.update(100, 250);
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
      m.update(100, 200);
      expect(m.update(100, 400), isEmpty);
      expect(m.armed, isNull);
    });

    test('release past the line commits the only option', () {
      final m = single()..update(100, 200);
      final out = m.end(0);
      expect(out.committed, isTrue);
      expect(out.option, talk);
    });

    test('release before the line cancels', () {
      final m = single()..update(90, 200);
      expect(m.end(0).committed, isFalse);
    });

    test('dropping under 72 after forking cancels', () {
      final m = single()..update(100, 200);
      m.update(60, 200);
      expect(m.end(0).committed, isFalse);
    });

    test('a left-only option commits too', () {
      final m = ForkMachine()..begin(left: vanishOn);
      m.update(100, 200);
      expect(m.end(0).option, vanishOn);
    });
  });

  group('gesture over a list', () {
    late List<String> log;
    late SwipeForkController fork;
    bool allowed = true;
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
      final g = await pull(t, 110);
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
      final g = await pull(t, 110);
      await slide(t, g, -50);
      await g.up();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(log, ['vanish:true']);
    });

    testWidgets('vanish already on commits vanish off', (t) async {
      await pumpScene(t);
      room = const ForkRoomState(vanishOn: true);
      final g = await pull(t, 110);
      await slide(t, g, -50);
      await g.up();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(log, ['vanish:false']);
    });

    testWidgets('release in the middle cancels', (t) async {
      await pumpScene(t);
      final g = await pull(t, 110);
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
      final g = await pull(t, 110);
      await g.up();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      expect(log, ['huddle']);
    });

    testWidgets('closed gate: nothing arms, the list scrolls', (t) async {
      await pumpScene(t);
      allowed = false;
      final g = await pull(t, 110);
      expect(fork.visible.value, isFalse);
      await g.up();
      await t.pump();
      expect(log, isEmpty);
    });

    testWidgets('no options: nothing arms', (t) async {
      await pumpScene(t);
      room = const ForkRoomState(isSecret: true, inCall: true);
      final g = await pull(t, 110);
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
      final g = await pull(t, 110);
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
      expect(fork.lift, closeTo(96 + 94 * 0.35, 0.5));
      await g.up();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('the arc fills with the pull', (t) async {
      await pumpScene(t);
      final g = await pull(t, 40);
      expect(fork.pullValue.value, closeTo(40 / 96, 1e-6));
      expect(fork.bloom.value, 0, reason: 'no chips before the line');
      expect(fork.viewForked, isFalse);
      await g.moveBy(const Offset(0, -80));
      await t.pump(const Duration(milliseconds: 16));
      expect(fork.pullValue.value, 1);
      await g.up();
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('chips bloom past the line and lift the list a little more',
        (t) async {
      await pumpScene(t);
      final g = await pull(t, 110);
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
      final g = await pull(t, 110);
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
      final g = await pull(t, 110);
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
      final g = await pull(t, 110);
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
      final g = await pull(t, 110);
      await slide(t, g, 50);
      await g.up();
      await t.pump(const Duration(seconds: 2));
      expect(builds, before);
    });

    testWidgets('a failing commit shakes, shows the reason, then collapses',
        (t) async {
      await pumpScene(t);
      failWith = StateError('boom');
      final g = await pull(t, 110);
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
        {double dock = 60, double startY = 400, double pullTo = 130}) async {
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
      final (atFinger, _) = await inkIn(t, img, Rect.fromLTWH(30, fingerY - 2, 100, 4));
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
