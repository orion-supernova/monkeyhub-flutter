import 'package:flutter/material.dart';
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
    test('pull: progress follows dy, orb is 1:1 then rubber-banded', () {
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

    Future<void> pumpScene(WidgetTester tester) async {
      log = [];
      allowed = true;
      room = const ForkRoomState();
      failWith = null;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: _Host(
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

    testWidgets('options are captured at touch-down', (t) async {
      await pumpScene(t);
      final g = await t.startGesture(const Offset(200, 560));
      room = const ForkRoomState(isSecret: true); // changes mid-gesture
      for (var i = 0; i < 11; i++) {
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

    testWidgets('drive the dock: fades with the pull, back to 1 after', (t) async {
      await pumpScene(t);
      final dock = ValueNotifier<double>(1);
      addTearDown(dock.dispose);
      final f2 = SwipeForkController(
        vsync: const TestVSync(),
        hapticTier: HapticTier.silent,
        dockFade: dock,
        canArm: () => true,
        roomState: () => const ForkRoomState(),
        onStartHuddle: () async {},
        onJoinHuddle: () async {},
        onToggleVanish: (_) async {},
      );
      addTearDown(f2.dispose);
      expect(f2.prepare(const Offset(200, 560)), isTrue);
      f2.start();
      f2.move(const Offset(200, 512));
      expect(dock.value, closeTo(0.5, 1e-9));
      f2.move(const Offset(200, 440));
      expect(dock.value, 0);
      f2.release(0);
      await t.pump();
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(dock.value, 1);
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
}

class _Host extends StatefulWidget {
  const _Host({required this.build});
  final SwipeForkController Function(TickerProvider) build;
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
          child: ListView.builder(
            reverse: true,
            itemCount: 30,
            itemBuilder: (_, i) => SizedBox(height: 60, child: Text('m$i')),
          ),
        ),
        SwipeForkOverlay(controller: c),
      ]);
}
