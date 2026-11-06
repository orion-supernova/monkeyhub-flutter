import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/haptic_tick.dart';
import 'package:monkeyhub/widgets/swipe_fork.dart';

/// The swipe-up: the pure state machine and options first, then the real
/// gesture over a real reversed list, capsules and all.

ForkOption vanishOn = const ForkOption(ForkKind.vanishOn);
ForkOption talk = const ForkOption(ForkKind.startHuddle);

/// Two capsules, the screen split at x = 200.
ForkMachine twoOptions() =>
    ForkMachine()..begin(left: vanishOn, right: talk, midX: 200);

ForkMachine oneOption({bool onLeft = false}) => ForkMachine()
  ..begin(
    left: onLeft ? vanishOn : null,
    right: onLeft ? null : talk,
    midX: 200,
  );

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
    test('reveal is 1:1 with the finger, then a rubber band past commit', () {
      final m = twoOptions();
      m.update(48, 100);
      expect(m.reveal, 48);
      expect(m.progress, closeTo(0.4, 1e-9));
      m.update(120, 100);
      expect(m.reveal, 120);
      m.update(220, 100);
      expect(m.reveal, closeTo(120 + 100 * 0.35, 1e-9));
    });

    test('opens at 56, not at 55.9', () {
      final m = twoOptions();
      expect(m.update(55.9, 100), isEmpty);
      expect(m.reached, isFalse);
      expect(m.update(56, 100), [ForkEvent.opened]);
      expect(m.reached, isTrue);
    });

    test('un-opens only under 48 (hysteresis), re-opens at 56', () {
      final m = twoOptions();
      m.update(70, 100);
      expect(m.update(50, 100), isEmpty);
      expect(m.update(47.9, 100), [ForkEvent.unopened]);
      expect(m.update(55, 100), isEmpty);
      expect(m.update(56, 100), [ForkEvent.opened]);
    });

    test('arms at 120 the half under the finger', () {
      final m = twoOptions();
      m.update(119.9, 100);
      expect(m.phase, ForkPhase.pull);
      expect(m.update(120, 100), contains(ForkEvent.armed));
      expect(m.phase, ForkPhase.armed);
      expect(m.armedSide, ForkSide.left);

      final r = twoOptions();
      r.update(125, 300);
      expect(r.armedSide, ForkSide.right);
    });

    test('disarm hysteresis: stays armed down to 104, disarms under it', () {
      final m = twoOptions();
      m.update(130, 100);
      expect(m.update(105, 100), isEmpty);
      expect(m.phase, ForkPhase.armed);
      expect(m.update(103.9, 100), [ForkEvent.disarmed]);
      expect(m.phase, ForkPhase.pull);
      expect(m.armedSide, isNull);
      // Needs the full 120 again.
      expect(m.update(115, 100), isEmpty);
      expect(m.update(120, 100), [ForkEvent.armed]);
    });

    test('sliding across the middle past commit re-arms the other half', () {
      final m = twoOptions();
      m.update(130, 100);
      expect(m.update(130, 150), isEmpty, reason: 'same half: nothing');
      expect(m.update(130, 250), [ForkEvent.swapped]);
      expect(m.armedSide, ForkSide.right);
      expect(m.update(130, 120), [ForkEvent.swapped]);
      expect(m.armedSide, ForkSide.left);
    });

    test('sliding sideways under commit arms nothing', () {
      final m = twoOptions();
      m.update(100, 100);
      expect(m.update(100, 300), isEmpty);
      expect(m.armedSide, isNull);
    });
  });

  group('machine release', () {
    test('short pull closes: nothing happens', () {
      final m = twoOptions();
      m.update(40, 100);
      final out = m.end();
      expect(out.result, ForkResult.cancel);
      expect(m.phase, ForkPhase.idle);
    });

    test('between open and commit settles open', () {
      final m = twoOptions();
      m.update(90, 100);
      final out = m.end();
      expect(out.settled, isTrue);
      expect(m.phase, ForkPhase.open);
      expect(m.holding, isFalse);
      // A settled gesture ignores the finger.
      expect(m.update(200, 300), isEmpty);
    });

    test('exactly at the open line settles open', () {
      final m = twoOptions();
      m.update(56, 100);
      expect(m.end().settled, isTrue);
    });

    test('armed release commits that side', () {
      final m = twoOptions();
      m.update(130, 100);
      final out = m.end();
      expect(out.committed, isTrue);
      expect(out.option, vanishOn);
      expect(out.side, ForkSide.left);
      expect(m.phase, ForkPhase.committing);
    });

    test('slide to the other half then release commits the other', () {
      final m = twoOptions();
      m.update(130, 100);
      m.update(130, 300);
      final out = m.end();
      expect(out.option, talk);
      expect(out.side, ForkSide.right);
    });

    test('dropping under 104 before release settles open instead', () {
      final m = twoOptions();
      m.update(130, 100);
      m.update(100, 100);
      expect(m.end().settled, isTrue);
    });

    test('settle open, then tap a capsule commits it', () {
      final m = twoOptions();
      m.update(80, 100);
      m.end();
      final out = m.tap(ForkSide.right);
      expect(out.committed, isTrue);
      expect(out.option, talk);
      expect(m.phase, ForkPhase.committing);
    });

    test('a tap while not settled open does nothing', () {
      final m = twoOptions();
      m.update(80, 100);
      expect(m.tap(ForkSide.left).committed, isFalse);
      expect(m.phase, ForkPhase.pull);
    });

    test('reset closes a settled-open gesture', () {
      final m = twoOptions();
      m.update(80, 100);
      m.end();
      m.reset();
      expect(m.active, isFalse);
      expect(m.tap(ForkSide.left).committed, isFalse);
    });
  });

  group('machine single option', () {
    test('the one capsule arms wherever the finger is', () {
      for (final x in [10.0, 199.0, 201.0, 390.0]) {
        final m = oneOption();
        expect(m.single, isTrue);
        m.update(125, x);
        expect(m.armedSide, ForkSide.right, reason: 'x=$x');
      }
      final l = oneOption(onLeft: true);
      l.update(125, 390);
      expect(l.armedSide, ForkSide.left);
    });

    test('sliding never swaps', () {
      final m = oneOption();
      m.update(130, 10);
      expect(m.update(130, 390), isEmpty);
    });

    test('release past commit fires it; short pull settles or closes', () {
      final a = oneOption()..update(130, 50);
      expect(a.end().option, talk);
      final b = oneOption()..update(80, 50);
      expect(b.end().settled, isTrue);
      final c = oneOption()..update(30, 50);
      expect(c.end().result, ForkResult.cancel);
    });
  });

  group('gesture over a list', () {
    late List<String> log;
    late SwipeForkController fork;
    bool allowed = true;
    ForkRoomState room = const ForkRoomState();
    Object? failWith;

    Future<void> pumpScene(WidgetTester tester, {bool rtl = false}) async {
      log = [];
      allowed = true;
      room = const ForkRoomState();
      failWith = null;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: rtl ? const Locale('ar') : const Locale('en'),
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

    Future<void> settle(WidgetTester t, {int ms = 2500}) async {
      await t.pump();
      for (var i = 0; i < ms ~/ 100; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('pull, settle open, tap a capsule: it runs', (t) async {
      await pumpScene(t);
      final g = await pull(t, 80);
      expect(fork.machine.holding, isTrue);
      expect(fork.isOpen, isFalse, reason: 'capsules take no taps mid-pull');
      await g.up();
      await settle(t, ms: 800);
      expect(fork.isOpen, isTrue);
      expect(fork.visible.value, isTrue);
      expect(find.text('Vanish'), findsOneWidget);
      expect(find.text('Talk'), findsOneWidget);
      expect(log, isEmpty);
      await t.tap(find.text('Talk'));
      await settle(t);
      expect(log, ['huddle']);
      expect(fork.visible.value, isFalse);
    });

    testWidgets('settle open, tap the left capsule: vanish on', (t) async {
      await pumpScene(t);
      final g = await pull(t, 80);
      await g.up();
      await settle(t, ms: 800);
      await t.tap(find.text('Vanish'));
      await settle(t);
      expect(log, ['vanish:true']);
    });

    testWidgets('settled open: a tap anywhere else closes, runs nothing',
        (t) async {
      await pumpScene(t);
      final g = await pull(t, 80);
      await g.up();
      await settle(t, ms: 800);
      expect(fork.isOpen, isTrue);
      await t.tapAt(const Offset(200, 100));
      await settle(t);
      expect(fork.visible.value, isFalse);
      expect(log, isEmpty);
    });

    testWidgets('settled open: a scroll closes', (t) async {
      await pumpScene(t);
      final g = await pull(t, 80);
      await g.up();
      await settle(t, ms: 800);
      await t.dragFrom(const Offset(200, 300), const Offset(0, -80));
      await settle(t);
      expect(fork.visible.value, isFalse);
      expect(log, isEmpty);
    });

    testWidgets('short pull: snaps closed, nothing happens', (t) async {
      await pumpScene(t);
      final g = await pull(t, 40);
      expect(fork.visible.value, isTrue);
      await g.up();
      await settle(t);
      expect(fork.visible.value, isFalse);
      expect(fork.isOpen, isFalse);
      expect(log, isEmpty);
    });

    testWidgets('pull past commit on the left half, release: vanish on',
        (t) async {
      await pumpScene(t);
      final g = await pull(t, 130, x: 200);
      expect(fork.machine.phase, ForkPhase.armed);
      expect(fork.armedSide, ForkSide.left);
      await g.up();
      await settle(t);
      expect(log, ['vanish:true']);
      expect(fork.visible.value, isFalse);
    });

    testWidgets('armed left, slide right across the middle: talk fires',
        (t) async {
      await pumpScene(t);
      final g = await pull(t, 130, x: 200);
      expect(fork.armedSide, ForkSide.left);
      await slide(t, g, 300);
      expect(fork.armedSide, ForkSide.right);
      await g.up();
      await settle(t);
      expect(log, ['huddle']);
    });

    testWidgets('armed, dropping back under commit and letting go settles open',
        (t) async {
      await pumpScene(t);
      final g = await pull(t, 130);
      for (var i = 0; i < 4; i++) {
        await g.moveBy(const Offset(0, 10));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(fork.armedSide, isNull);
      await g.up();
      await settle(t, ms: 800);
      expect(fork.isOpen, isTrue);
      expect(log, isEmpty);
      fork.dismiss();
      await settle(t);
    });

    testWidgets('vanish already on commits vanish off', (t) async {
      await pumpScene(t);
      room = const ForkRoomState(vanishOn: true);
      final g = await pull(t, 130);
      await g.up();
      await settle(t);
      expect(log, ['vanish:false']);
    });

    testWidgets('single option: one wide capsule, any x arms it', (t) async {
      await pumpScene(t);
      room = const ForkRoomState(isSecret: true);
      final g = await pull(t, 130, x: 60);
      expect(fork.armedSide, ForkSide.right);
      await g.up();
      await settle(t);
      expect(log, ['huddle']);
    });

    testWidgets('single option: settle open then tap', (t) async {
      await pumpScene(t);
      room = const ForkRoomState(isSecret: true);
      final g = await pull(t, 80);
      await g.up();
      await settle(t, ms: 800);
      expect(find.text('Vanish'), findsNothing);
      await t.tap(find.text('Talk'));
      await settle(t);
      expect(log, ['huddle']);
    });

    testWidgets('RTL mirrors the sides: vanish on the right', (t) async {
      await pumpScene(t, rtl: true);
      final g = await pull(t, 80);
      expect(fork.viewRight?.kind, ForkKind.vanishOn);
      expect(fork.viewLeft?.kind, ForkKind.startHuddle);
      await g.up();
      await settle(t);
      expect(fork.isOpen, isTrue);
      fork.dismiss();
      await settle(t);
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
      final g = await pull(t, 130);
      expect(fork.armedSide, ForkSide.left);
      final second = await t.startGesture(const Offset(100, 300), pointer: 7);
      await t.pump();
      expect(fork.machine.active, isFalse);
      await second.up();
      await g.up();
      await t.pump(const Duration(seconds: 2));
      expect(log, isEmpty);
      expect(fork.visible.value, isFalse);
    });

    testWidgets('a failing commit shakes, shows the reason, then closes',
        (t) async {
      await pumpScene(t);
      failWith = StateError('boom');
      final g = await pull(t, 130, x: 600);
      expect(fork.armedSide, ForkSide.right);
      await g.up();
      await t.pump();
      for (var i = 0; i < 9; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(fork.failReason, 'nope');
      expect(fork.visible.value, isTrue);
      expect(find.text('nope'), findsOneWidget);
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
