import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/art/fight_art.dart';
import 'package:monkeyhub/fight/view/art/sandbag_art.dart';
import 'package:monkeyhub/fight/view/fight_renderer.dart';
import 'package:monkeyhub/fight/view/fight_training_moves.dart';
import 'package:monkeyhub/fight/view/fight_training_screen.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

final String? shotDir = Platform.environment['FIGHT_SHOTS'];

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await GoogleFonts.pendingFonts([
      GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800),
      GoogleFonts.anta(),
      GoogleFonts.doto(fontWeight: FontWeight.w900),
    ]);
    await FightRenderer.warmUp();
    if (shotDir != null) {
      // Real glyphs instead of the test font's blocks, so the PNGs can be read.
      Future<void> font(String family, List<String> files) async {
        final l = FontLoader(family);
        for (final f in files) {
          l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
        }
        await l.load();
      }

      final mf = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
      await font('Roboto', ['$mf/Roboto-Regular.ttf', '$mf/Roboto-Bold.ttf', '$mf/Roboto-Black.ttf']);
      final cup = Directory('${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev').listSync().whereType<Directory>().where((d) => d.path.contains('cupertino_icons-')).toList();
      if (cup.isNotEmpty) await font('packages/cupertino_icons/CupertinoIcons', ['${cup.last.path}/assets/CupertinoIcons.ttf']);
    }
  });

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('every move of every fighter', () {
    test('the list is complete: normals, every special, EX, super and follow-up', () {
      for (final c in roster) {
        final ids = {for (final m in trainingMoves(c)) m.moveId};
        expect(ids, containsAll([for (var n = 0; n < N.count; n++) n]), reason: '${c.name} normals');
        expect(ids, containsAll(c.specials), reason: '${c.name} specials');
        expect(ids, containsAll(c.exSpecials.where((e) => e >= 0)), reason: '${c.name} EX');
        expect(ids.contains(c.superMove), isTrue, reason: '${c.name} super');
        // Nothing the fighter owns is missing from the list.
        expect(ids.length, c.moves.length, reason: '${c.name} has moves the list cannot perform');
      }
    });

    test('performing a move on the engine starts exactly that move', () {
      for (final c in roster) {
        for (final m in trainingMoves(c)) {
          final script = trainingScript(c, m);
          final s = trainingState(c, dist: script.dist);
          var started = false;
          for (var f = 0; f < 120 && !started; f++) {
            step(s, script.p1(s), script.p2(s));
            trainingKeepAlive(s);
            started = s.p[0].state == St.move && s.p[0].moveId == m.moveId;
          }
          expect(started, isTrue, reason: '${c.name} ${m.glyph} ${m.name}${m.normal ?? ''} (move ${m.moveId}) did not start');
          // The dummy never acts on its own (counter follow-ups poke it once).
          if (m.group != TrainGroup.counters) {
            expect(s.p[1].moveId, -1, reason: '${c.name} dummy acted during ${m.name}');
          }
        }
      }
    });

    test('moves connect with the dummy (grabs vs a wide mirror pushbox are the only exceptions)', () {
      final misses = <String>[];
      for (final c in roster) {
        for (final m in trainingMoves(c)) {
          final fd = trainingFrameData(c, m.move);
          if (!fd.hitsAnything || m.move.counterMove >= 0 || m.group == TrainGroup.counters) continue;
          final script = trainingScript(c, m);
          final s = trainingState(c, dist: script.dist);
          var hit = false;
          for (var f = 0; f < 120 && !hit; f++) {
            step(s, script.p1(s), script.p2(s));
            trainingKeepAlive(s);
            final d = s.p[1];
            hit = d.comboHits > 0 || d.state == St.hitstun || d.state == St.airstun || d.state == St.grabbed || d.state == St.down;
          }
          if (!hit) misses.add('${c.name} ${m.name}');
        }
      }
      // Every move of every fighter connects on its mirror dummy, grabs of
      // the heavyweights included (reach scales with body width).
      expect(misses, isEmpty);
    });

    test('counter follow-ups fire when the dummy pokes the stance', () {
      var seen = 0;
      for (final c in roster) {
        for (final m in trainingMoves(c).where((m) => m.group == TrainGroup.counters)) {
          seen++;
          expect(c.moves[m.parent].counterMove, m.moveId);
        }
      }
      expect(seen, 9);
    });

    test('names and glyphs', () {
      expect(trainingMoveName('surgePalm'), 'Surge Palm');
      final kai = trainingMoves(roster[0]);
      expect(kai.firstWhere((m) => m.moveId == 10).glyph, 'S');
      expect(kai.firstWhere((m) => m.moveId == 11).glyph, '→ S');
      expect(kai.firstWhere((m) => m.moveId == 16).glyph, '→ S+H');
      expect(kai.firstWhere((m) => m.moveId == 12).glyph, '↓ S');
      expect(kai.firstWhere((m) => m.moveId == 13).glyph, '↑ S');
    });

    test('frame data reads the move', () {
      final kai = roster[0];
      final surge = trainingFrameData(kai, kai.moves[10]);
      expect(surge.startup, 14);
      expect(surge.damage, 60);
      expect(surge.flags.any((f) => f.kind == TrainFlagKind.projectile), isTrue);
      final heel = trainingFrameData(kai, kai.moves[13]);
      expect(heel.flags.any((f) => f.kind == TrainFlagKind.invStrike && f.from == 0 && f.to == 9), isTrue);
      expect(heel.flags.any((f) => f.kind == TrainFlagKind.launch), isTrue);
      final thr = trainingFrameData(kai, kai.moves[N.throwMove]);
      expect(thr.height, BlockHeight.unblockable);
      expect(thr.flags.any((f) => f.kind == TrainFlagKind.grab), isTrue);
    });

    test('keep-alive: nobody dies, meter stays full, clock frozen', () {
      final c = roster[0];
      final s = trainingState(c, dist: 9000);
      final script = trainingScript(c, trainingMoves(c).firstWhere((m) => m.moveId == 14));
      for (var f = 0; f < 400; f++) {
        step(s, script.p1(s) | Inp.light, 0);
        trainingKeepAlive(s);
      }
      expect(s.phase, Phase.fight);
      expect(s.p[1].health, c.maxHealth);
      expect(s.p[0].meter, meterMax);
      expect(s.timer, roundFrames);
    });
  });

  group('hitbox overlay', () {
    test('boxes come from the live move frame', () {
      final c = roster[0];
      final s = trainingState(c, dist: 9000);
      step(s, Inp.light, 0);
      var live = false;
      for (var f = 0; f < 12; f++) {
        final b = trainingBoxes(s, 0);
        expect(b.hurt, isNotEmpty);
        expect(b.pushbox.r - b.pushbox.l, c.pushHalf * 2);
        if (b.activeHit.isNotEmpty) live = true;
        step(s, 0, 0);
      }
      expect(live, isTrue);
    });

    test('paints without error', () {
      final s = trainingState(roster[0], dist: 9000);
      step(s, Inp.light, 0);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      paintTrainingBoxes(canvas, FightCamera.follow(s, const Size(400, 250), null), s);
      rec.endRecording().dispose();
    });
  });


  group('sandbag', () {
    /// Runs [m] on a fresh room and feeds a bag every frame.
    SandbagArt swing(CharacterDef c, TrainMove m, {int frames = 90, List<double>? out}) {
      final bag = SandbagArt();
      final script = trainingScript(c, m);
      final s = trainingState(c, dist: script.dist);
      for (var f = 0; f < frames; f++) {
        step(s, script.p1(s), script.p2(s));
        trainingKeepAlive(s);
        bag.update(s, 1);
        out?.add(bag.bodyX);
      }
      return bag;
    }

    test('a hit swings the bag away from the attacker, harder for more damage, and it settles', () {
      final c = roster[0];
      final moves = trainingMoves(c);
      final light = moves.firstWhere((m) => m.normal == N.standLight);
      final heavy = moves.firstWhere((m) => m.normal == N.standHeavy);
      final a = <double>[], b = <double>[];
      swing(c, light, out: a);
      swing(c, heavy, out: b);
      double reach(List<double> xs) => xs.map((x) => (x - xs.first).abs()).reduce((p, q) => p > q ? p : q);
      expect(reach(a), greaterThan(4), reason: 'light');
      expect(reach(b), greaterThan(reach(a)), reason: 'heavy swings further');
      expect(b.reduce((p, q) => p > q ? p : q), greaterThan(b.first), reason: 'P1 is on the left, the bag goes right');
    });

    test('damping: it hangs still again long after the last hit', () {
      final c = roster[0];
      final m = trainingMoves(c).firstWhere((m) => m.normal == N.standHeavy);
      final bag = SandbagArt();
      final script = trainingScript(c, m);
      final s = trainingState(c, dist: script.dist);
      for (var f = 0; f < 1400; f++) {
        step(s, f < 60 ? script.p1(s) : 0, 0);
        trainingKeepAlive(s);
        bag.update(s, 1);
      }
      // It rests 22 px past the dummy, away from the attacker (see SandbagArt.update).
      expect((bag.bodyX - (s.p[1].x / unitsPerPx + 22)).abs(), lessThan(3));
    });

    test('paints in every look inside the clip and layer budget', () {
      final c = roster[0];
      final m = trainingMoves(c).firstWhere((m) => m.normal == N.standHeavy);
      final script = trainingScript(c, m);
      for (final look in FightLook.values) {
        final art = FightArt()..sandbagFor = 1;
        final s = trainingState(c, dist: script.dist);
        for (var f = 0; f < 40; f++) {
          step(s, script.p1(s), 0);
          trainingKeepAlive(s);
          final rec = ui.PictureRecorder();
          final canvas = Canvas(rec);
          art.paintActors(canvas, const Size(800, 500), FightCamera.follow(s, const Size(800, 500), null), s, look);
          rec.endRecording().dispose();
        }
      }
    });
  });

  group('screen', () {
    Future<GlobalKey> pump(WidgetTester tester, Size size, {int charId = 0}) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: FightTrainingScreen(charId: charId),
            ),
          ),
        ),
      );
      return key;
    }

    Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
      if (shotDir == null) return;
      await tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(shotDir!).createSync(recursive: true);
        File('$shotDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    String readout(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('training_readout'))).data ?? '';

    testWidgets('phone portrait: lists moves, performs one, toggles hitboxes', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final key = await pump(tester, const Size(393, 852));
      await tester.pump(const Duration(milliseconds: 50));
      // On a phone the title gives way to the stage and fighter chips.
      expect(find.byKey(const ValueKey('training_change_stage')), findsOneWidget);
      expect(find.text('Rooftop'), findsOneWidget);
      expect(find.text('Stand light'), findsOneWidget); // the list row (the compact panel has no title)
      // Every control keeps its whole label on a phone.
      for (final t in ['Loop', 'Hitboxes', 'Reset', 'Sandbag', 'Fighter']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await tester.scrollUntilVisible(find.text('Surge Palm'), 120, scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const ValueKey('training_frame_data')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('training_move_10')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('training_move_10')));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(readout(tester), isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('training_hitboxes')));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await shot(tester, key, 'training_portrait_boxes');
      await tester.tap(find.byKey(const ValueKey('training_hitboxes')));
      await tester.pump();

      // Pause and single-step.
      await tester.tap(find.byKey(const ValueKey('training_pause')));
      await tester.pump();
      final before = readout(tester);
      await tester.tap(find.byKey(const ValueKey('training_step')));
      await tester.pump();
      expect(readout(tester), isNot(before));
      await tester.tap(find.byKey(const ValueKey('training_speed_quarter')));
      await tester.tap(find.byKey(const ValueKey('training_loop')));
      await tester.tap(find.byKey(const ValueKey('training_reset')));
      await tester.pump();

      // Free play shows the touch deck instead of the list.
      await tester.tap(find.byKey(const ValueKey('training_tab_play')));
      await tester.pump();
      expect(find.byType(ListView), findsNothing);
      await tester.tap(find.byKey(const ValueKey('training_tab_play')));
      await tester.pump();
      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('every look renders', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      for (final look in ['cartoon', 'painted', 'pixel']) {
        await SettingsStore.instance.setFightLook(look);
        await pump(tester, const Size(393, 852), charId: 7);
        await tester.tap(find.byKey(const ValueKey('training_hitboxes')));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(tester.takeException(), isNull, reason: look);
      }
      await SettingsStore.instance.setFightLook('cartoon');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('landscape and desktop render the list beside the stage', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final key = await pump(tester, const Size(1280, 800), charId: 3);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.scrollUntilVisible(find.byKey(const ValueKey('training_move_19')), 200, scrollable: find.byType(Scrollable).last);
      await tester.ensureVisible(find.byKey(const ValueKey('training_move_19')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('training_move_19')));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await shot(tester, key, 'training_desktop');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pump(tester, const Size(852, 393));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('screenshots at phone, desktop and wide sizes', (tester) async {
      if (shotDir == null) return;
      Future<void> go(String name, Size size, TargetPlatform platform, {String look = 'cartoon', int move = 3, int frames = 24}) async {
        debugDefaultTargetPlatformOverride = platform;
        await SettingsStore.instance.setFightLook(look);
        final key = await pump(tester, size);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.ensureVisible(find.byKey(ValueKey('training_move_$move')));
        await tester.tap(find.byKey(ValueKey('training_move_$move')));
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await shot(tester, key, name);
      }

      await go('p402_cartoon', const Size(402, 874), TargetPlatform.iOS);
      await go('p360_cartoon', const Size(360, 740), TargetPlatform.android, move: 2);
      await go('p402_painted', const Size(402, 874), TargetPlatform.iOS, look: 'painted', frames: 30);
      await go('p402_pixel', const Size(402, 874), TargetPlatform.iOS, look: 'pixel', frames: 30);
      await go('d1440_cartoon', const Size(1440, 900), TargetPlatform.macOS);
      await go('d1440_painted', const Size(1440, 900), TargetPlatform.macOS, look: 'painted', frames: 30);
      await go('d1920_cartoon', const Size(1920, 1080), TargetPlatform.macOS, move: 2, frames: 30);
      await go('d900_cartoon', const Size(900, 700), TargetPlatform.macOS);
      await go('l852_cartoon', const Size(852, 393), TargetPlatform.iOS);
      await SettingsStore.instance.setFightLook('cartoon');
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('close button pops', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(393, 852) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(builder: (c) => TextButton(onPressed: () => openFightTraining(c, charId: 1), child: const Text('open'))),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('training_close')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('training_close')));
      for (var k = 0; k < 30; k++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const ValueKey('training_close')), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
