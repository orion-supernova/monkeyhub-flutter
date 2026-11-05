// Renders MOJO / TANK / NYX in all three looks (idle, normals, every special at
// its first active frame, props, a mirror match, portraits) to PNGs that are
// inspected by eye, plus a contact sheet per character and look.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/art/fight_art.dart';
import 'package:monkeyhub/fight/view/art/poser.dart';
import 'package:monkeyhub/fight/view/fighter_portrait.dart';

import '../fight_test_utils.dart';

const String outDir =
    '/private/tmp/claude-501/-Users-muratcankoc-Documents-Projects-monkeyhub-flutter-monkeyhub/e56bc469-ecc4-40cc-91e2-f5899446bcce/scratchpad/fight_png/roster';
const ui.Size sz = ui.Size(1280, 800);

void forceMove(FightState s, int p, int moveId, int sf) {
  s.p[p].state = St.move;
  s.p[p].moveId = moveId;
  s.p[p].sf = sf;
}

int idx(CharacterDef c, String name) => c.moves.indexWhere((m) => m.name == name);

typedef Shot = (String, FightState Function());

List<Shot> shots(CharacterDef c) {
  final foe = kai;
  FightState melee() => duel(c, foe, dist: 12000);
  FightState moveAt(String name, {int? at, int dist = 12000}) {
    final s = duel(c, foe, dist: dist);
    final i = idx(c, name);
    final m = c.moves[i];
    forceMove(s, 0, i, at ?? m.startup);
    return s;
  }

  final out = <Shot>[
    ('idle', () {
      final s = duel(c, foe, dist: 16000);
      play(s, 30);
      return s;
    }),
    ('light', () => moveAt('standLight')),
    ('heavy', () => moveAt('standHeavy')),
  ];
  switch (c.id) {
    case 1:
      out.addAll([
        ('staffVault', () => moveAt('staffVault')),
        ('spinSweep', () => moveAt('spinSweep', at: 14)),
        ('bananaPeel', () => moveAt('bananaPeel', at: 12, dist: 20000)),
        ('canopyDive', () => moveAt('canopyDive')),
        ('jungleFury', () => moveAt('jungleFury', at: 22)),
        ('peel_trap', () {
          final s = duel(c, foe, dist: 26000);
          runUntil(s, (s) => s.traps.isNotEmpty, (f, s) => f == 0 ? Inp.down | Inp.special : 0);
          play(s, 20);
          return s;
        }),
      ]);
      break;
    case 2:
      out.addAll([
        ('stampede', () => moveAt('stampede', at: 22)),
        ('hornToss', () => moveAt('hornToss', at: 24)),
        ('earthquake', () => moveAt('earthquake', at: 28, dist: 30000)),
        ('rhinoUppercut', () => moveAt('rhinoUppercut')),
        ('avalancheSlam', () => moveAt('avalancheSlam', at: 38)),
      ]);
      break;
    default:
      out.addAll([
        ('moonShard', () => moveAt('moonShard', at: 12, dist: 40000)),
        ('phaseStep', () => moveAt('phaseStep', at: 11, dist: 20000)),
        ('shadowPool', () => moveAt('shadowPool', at: 12, dist: 30000)),
        ('eclipse', () => moveAt('eclipse', at: 14)),
        ('eclipseStrike', () => moveAt('eclipseStrike')),
        ('totalEclipse', () => moveAt('totalEclipse', at: 24)),
        ('shard_proj', () {
          final s = duel(c, foe, dist: 40000);
          runUntil(s, (s) => s.projectiles.isNotEmpty, (f, s) => f == 0 ? Inp.special : 0);
          play(s, 12);
          return s;
        }),
        ('pool_trap', () {
          final s = duel(c, foe, dist: 30000);
          runUntil(s, (s) => s.traps.isNotEmpty, (f, s) => f == 0 ? Inp.down | Inp.special : 0);
          play(s, 20);
          return s;
        }),
      ]);
  }
  out.add(('mirror', () {
    final s = duel(c, c, dist: 12000);
    forceMove(s, 1, idx(c, 'standHeavy'), c.moves[idx(c, 'standHeavy')].startup);
    return s;
  }));
  melee();
  return out;
}

int runUntil(FightState s, bool Function(FightState) done, int Function(int f, FightState s) in0, {int max = 400}) {
  var f = 0;
  while (!done(s) && f < max) {
    step(s, in0(f, s), 0);
    f++;
  }
  expect(f < max, true, reason: 'scenario did not reach its target frame');
  return f;
}

ui.Picture shot(FightArt art, FightState s, FightLook look) {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  final cam = FightCamera.follow(s, sz, null);
  art.paintStage(c, sz, cam, look, s.frame);
  art.paintActors(c, sz, cam, s, look);
  return rec.endRecording();
}

Future<void> writePng(String path, ui.Picture pic, int w, int h) async {
  final img = await pic.toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Directory(outDir).createSync(recursive: true);

  for (final c in [mojo, tank, nyx]) {
    for (final look in FightLook.values) {
      test('roster ${c.key} ${look.name}', () async {
        final art = FightArt();
        final list = shots(c);
        final pics = <ui.Picture>[];
        for (final (name, make) in list) {
          final pic = shot(art, make(), look);
          pics.add(pic);
          await writePng('$outDir/${c.key}_${name}_${look.name}.png', pic, 1280, 800);
        }
        // Contact sheet: 4 columns of half-size cells.
        const cols = 4;
        final rows = (pics.length / cols).ceil();
        final rec = ui.PictureRecorder();
        final cv = ui.Canvas(rec);
        for (var i = 0; i < pics.length; i++) {
          cv.save();
          cv.translate((i % cols) * 640.0, (i ~/ cols) * 400.0);
          cv.clipRect(const ui.Rect.fromLTWH(0, 0, 640, 400));
          cv.scale(.5);
          cv.drawPicture(pics[i]);
          cv.restore();
        }
        await writePng('$outDir/sheet_${c.key}_${look.name}.png', rec.endRecording(), cols * 640, rows * 400);
        expect(File('$outDir/sheet_${c.key}_${look.name}.png').lengthSync(), greaterThan(5000));
      });
    }
  }

  testWidgets('portraits', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFF2A1F3A),
          width: 1200,
          height: 480,
          child: Column(children: [
            for (final look in FightLook.values)
              Expanded(
                child: Row(children: [
                  for (final id in [0, 1, 2, 3]) ...[
                    Expanded(child: FighterPortrait(charId: id, look: look)),
                    Expanded(child: FighterPortrait(charId: id, look: look, alt: true, facingLeft: true, ready: true)),
                  ],
                ]),
              ),
          ]),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1.5);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/portraits.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox());
  });

  test('every state and move of the roster paints without throwing (all looks)', () {
    final art = FightArt();
    for (final cd in [mojo, tank, nyx]) {
      for (var mv = 0; mv < cd.moves.length; mv++) {
        final s = duel(cd, kai, dist: 14000);
        s.p[0].state = St.move;
        s.p[0].moveId = mv;
        for (var sf = 0; sf <= cd.moves[mv].total; sf++) {
          s.p[0].sf = sf;
          s.frame = sf;
          final rec = ui.PictureRecorder();
          final cv = ui.Canvas(rec);
          final cam = FightCamera.follow(s, sz, null);
          for (final look in FightLook.values) {
            art.paintActors(cv, sz, cam, s, look);
          }
          rec.endRecording().dispose();
          expect(poseFor(s, 0).v.every((v) => v.isFinite), true, reason: '${cd.key} ${cd.moves[mv].name} $sf');
        }
      }
    }
  });
}
