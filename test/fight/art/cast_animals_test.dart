// Renders RYOKO / BAO / VEX / GALE in all three looks (idle, normals, every
// special at its first active frame, projectiles and traps in flight, the
// Super, a mirror match, portraits) to PNGs that are inspected by eye, plus a
// contact sheet per character and look.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/characters/wave2a.dart' show bao, gale, ryoko, vex;
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/art/fight_art.dart';
import 'package:monkeyhub/fight/view/art/poser.dart';
import 'package:monkeyhub/fight/view/fighter_portrait.dart';

import '../fight_test_utils.dart';

/// PNG output for eyeballing the art: set `FIGHT_SHOTS=dir` to write them.
/// Unset (CI, everyday runs), the render tests return at once; the
/// no-throw sweeps always run.
final String? _shots = Platform.environment['FIGHT_SHOTS'];
final String outDir = '${_shots ?? ''}/animals';
const ui.Size sz = ui.Size(1280, 800);

void forceMove(FightState s, int p, int moveId, int sf) {
  s.p[p].state = St.move;
  s.p[p].moveId = moveId;
  s.p[p].sf = sf;
}

int idx(CharacterDef c, String name) => c.moves.indexWhere((m) => m.name == name);

typedef Shot = (String, FightState Function());

int runUntil(FightState s, bool Function(FightState) done, int Function(int f, FightState s) in0, {int max = 400}) {
  var f = 0;
  while (!done(s) && f < max) {
    step(s, in0(f, s), 0);
    f++;
  }
  expect(f < max, true, reason: 'scenario did not reach its target frame');
  return f;
}

List<Shot> shots(CharacterDef c) {
  final foe = kai;
  FightState moveAt(String name, {int? at, int dist = 12000}) {
    final s = duel(c, foe, dist: dist);
    final i = idx(c, name);
    forceMove(s, 0, i, at ?? c.moves[i].startup);
    return s;
  }

  /// Plays the move from its first frame so spawned projectiles / traps exist.
  FightState played(String name, int frames, {int dist = 30000}) {
    final s = duel(c, foe, dist: dist);
    forceMove(s, 0, idx(c, name), 0);
    play(s, frames);
    return s;
  }

  final out = <Shot>[
    ('idle', () {
      final s = duel(c, foe, dist: 16000);
      play(s, 30);
      return s;
    }),
    ('light', () => moveAt('standLight')),
    ('light2', () => moveAt('standLight2')),
    ('heavy', () => moveAt('standHeavy')),
    ('jump', () {
      final s = duel(c, foe, dist: 22000);
      step(s, Inp.up | Inp.right, 0);
      play(s, 22, in0: (f, s) => Inp.right);
      return s;
    }),
  ];
  switch (c.id) {
    case 8:
      out.addAll([
        ('clawFlurry', () => moveAt('clawFlurry', at: 13)),
        ('clawFlurry_b', () => moveAt('clawFlurry', at: 19)),
        ('pounce', () => moveAt('pounce')),
        ('lowRake', () => moveAt('lowRake')),
        ('risingClaw', () => moveAt('risingClaw')),
        ('tigerRage_roar', () => moveAt('tigerRage', at: 7)),
        ('tigerRage', () => moveAt('tigerRage', at: 22)),
        ('tigerRage_end', () => moveAt('tigerRage', at: 36)),
      ]);
      break;
    case 9:
      out.addAll([
        ('drunkenSway', () => moveAt('drunkenSway', at: 8)),
        ('swayCounter', () => moveAt('swayCounter')),
        ('bellyBounce', () => moveAt('bellyBounce')),
        ('tipsySweep', () => moveAt('tipsySweep')),
        ('jugRise', () => moveAt('jugRise')),
        ('drunkenMaster_swig', () => moveAt('drunkenMaster', at: 6)),
        ('drunkenMaster', () => moveAt('drunkenMaster', at: 22)),
        ('drunkenMaster_end', () => moveAt('drunkenMaster', at: 40)),
      ]);
      break;
    case 10:
      out.addAll([
        ('decoy', () => moveAt('decoy', at: 11)),
        ('fakeOut', () => moveAt('fakeOut')),
        ('phantomSnare', () => moveAt('phantomSnare', at: 10)),
        ('mirageStep_vanish', () => moveAt('mirageStep', at: 6, dist: 24000)),
        ('mirageStep', () => moveAt('mirageStep', at: 11, dist: 24000)),
        ('nineTails_gather', () => moveAt('nineTails', at: 16)),
        ('nineTails', () => moveAt('nineTails', at: 33)),
        ('decoy_proj', () => played('decoy', 20)),
        ('spirits_proj', () => played('nineTails', 24, dist: 50000)),
        ('snare_trap', () {
          final s = duel(c, foe, dist: 30000);
          runUntil(s, (s) => s.traps.isNotEmpty, (f, s) => f == 0 ? Inp.down | Inp.special : 0);
          play(s, 30);
          return s;
        }),
      ]);
      break;
    default:
      out.addAll([
        ('wingGust', () => moveAt('wingGust', at: 13)),
        ('talonGlide', () => moveAt('talonGlide', at: 12)),
        ('talonGlide_dive', () => moveAt('talonGlide', at: 21)),
        ('wingSweep', () => moveAt('wingSweep')),
        ('skyDive_rise', () => moveAt('skyDive', at: 12)),
        ('skyDive', () => moveAt('skyDive', at: 28)),
        ('stormTalon', () => moveAt('stormTalon', at: 22)),
        ('gust_proj', () => played('wingGust', 22)),
        ('storm_proj', () => played('stormTalon', 26, dist: 50000)),
        ('airdash', () {
          final s = duel(c, foe, dist: 30000);
          step(s, Inp.up, 0);
          play(s, 20);
          s.p[0].airDashT = 8;
          s.p[0].airDashUsed = true;
          s.p[0].vx = 13000;
          play(s, 3);
          return s;
        }),
      ]);
  }
  out.add(('mirror', () {
    final s = duel(c, c, dist: 12000);
    forceMove(s, 1, idx(c, 'standHeavy'), c.moves[idx(c, 'standHeavy')].startup);
    return s;
  }));
  return out;
}

ui.Picture shot(FightArt art, FightState s, FightLook look) {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  final cam = FightCamera.follow(s, sz, null);
  art.paintStage(c, sz, cam, look, s.frame);
  art.paintActors(c, sz, cam, s, look);
  return rec.endRecording();
}

/// A close-up on player 0 (body shots only), for checking the drawing itself.
ui.Picture zoomShot(FightArt art, FightState s, FightLook look, {double zoom = 2.6}) {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  final cam = FightCamera(zoom, 520 - s.p[0].x / unitsPerPx * zoom, 740);
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
  if (_shots != null) Directory(outDir).createSync(recursive: true);

  final chars = [ryoko, bao, vex, gale];

  for (final c in chars) {
    for (final look in FightLook.values) {
      test('animals ${c.key} ${look.name}', () async {
        if (_shots == null) return; // PNGs only when FIGHT_SHOTS=<dir> is set
        final art = FightArt();
        final list = shots(c);
        final pics = <ui.Picture>[];
        for (final (name, make) in list) {
          final pic = shot(art, make(), look);
          pics.add(pic);
          await writePng('$outDir/${c.key}_${name}_${look.name}.png', pic, 1280, 800);
          if (look == FightLook.cartoon && !name.contains('_proj') && !name.contains('_trap') && !name.contains('airdash')) {
            await writePng('$outDir/zoom_${c.key}_${name}_${look.name}.png', zoomShot(art, make(), look), 1280, 800);
          }
        }
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
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  }

  testWidgets('portraits', (tester) async {
    if (_shots == null) return; // PNGs only when FIGHT_SHOTS=<dir> is set
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFF2A1F3A),
          width: 1600,
          height: 560,
          child: Column(children: [
            for (final look in FightLook.values)
              Expanded(
                child: Row(children: [
                  for (final id in [8, 9, 10, 11]) ...[
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

  test('every state and move of the animals paints without throwing (all looks)', timeout: const Timeout(Duration(minutes: 5)), () {
    final art = FightArt();
    for (final cd in chars) {
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
      // Every non-move state across its first frames, both facings, mirror match.
      for (var st = 0; st <= St.techd; st++) {
        if (st == St.move) continue;
        for (final mirror in [false, true]) {
          final s = duel(cd, mirror ? cd : kai, dist: 14000);
          s.p[0].state = st;
          s.p[0].stun = 12;
          s.p[0].y = st == St.jump || st == St.airstun ? 8000 : 0;
          for (var sf = 0; sf < 24; sf++) {
            s.p[0].sf = sf;
            s.frame = sf;
            final rec = ui.PictureRecorder();
            final cv = ui.Canvas(rec);
            final cam = FightCamera.follow(s, sz, null);
            for (final look in FightLook.values) {
              art.paintActors(cv, sz, cam, s, look);
            }
            rec.endRecording().dispose();
            expect(poseFor(s, 0).v.every((v) => v.isFinite), true, reason: '${cd.key} state $st $sf');
          }
        }
      }
    }
  });
}
