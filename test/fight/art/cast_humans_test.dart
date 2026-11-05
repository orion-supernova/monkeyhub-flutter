// Renders LUZ / DEX / HANA / BOOM in all three looks (idle, normals, every
// special at its first active frame, the Super, a mirror match, portraits) to
// PNGs that are inspected by eye, plus a contact sheet per fighter and look,
// and sweeps every state and move for exceptions.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/art/cast/registry.dart';
import 'package:monkeyhub/fight/view/art/fight_art.dart';
import 'package:monkeyhub/fight/view/art/poser.dart';
import 'package:monkeyhub/fight/view/fighter_portrait.dart';

import '../fight_test_utils.dart';

/// PNG output for eyeballing the art: set `FIGHT_SHOTS=dir` to write them.
/// Unset (CI, everyday runs), the render tests return at once; the
/// no-throw sweeps always run.
final String? _shots = Platform.environment['FIGHT_SHOTS'];
final String outDir = '${_shots ?? ''}/humans';
const ui.Size sz = ui.Size(1280, 800);

void forceMove(FightState s, int p, int moveId, int sf) {
  s.p[p].state = St.move;
  s.p[p].moveId = moveId;
  s.p[p].sf = sf;
}

int idx(CharacterDef c, String name) => c.moves.indexWhere((m) => m.name == name);

typedef Shot = (String, FightState Function());

/// (move name, frames after startup to show it at, distance to the foe).
const Map<int, List<(String, int, int)>> _specials = {
  12: [('dropkick', 0, 14000), ('runningSplash', 2, 14000), ('slideKick', 0, 14000), ('hurricanrana', 0, 14000), ('topRopeSwan', 3, 14000)],
  13: [('spinKick', 0, 14000), ('flowCombo', 5, 14000), ('lowCartwheel', 0, 14000), ('invertida', 0, 14000), ('rodaDeFogo', 9, 14000)],
  14: [('thrustFlurry', 3, 20000), ('lunge', 0, 20000), ('riposte', 0, 14000), ('riposteStrike', 1, 20000), ('risingPoint', 0, 14000), ('grandeFleche', 6, 20000)],
  15: [('tsuppari', 5, 16000), ('dohyoCharge', 0, 16000), ('uwatenage', 0, 14000), ('bellyBounce', 0, 14000), ('yokozunaThunder', 12, 16000)],
};

List<Shot> shots(CharacterDef c) {
  final foe = roster[0];
  FightState moveAt(String name, {int plus = 0, int dist = 12000}) {
    final s = duel(c, foe, dist: dist);
    final i = idx(c, name);
    forceMove(s, 0, i, c.moves[i].startup + plus);
    return s;
  }

  final out = <Shot>[
    ('idle', () {
      final s = duel(c, foe, dist: 16000);
      play(s, 30);
      return s;
    }),
    ('idle2', () {
      final s = duel(c, foe, dist: 16000);
      play(s, 75);
      return s;
    }),
    ('light', () => moveAt('standLight')),
    ('light2', () => moveAt('standLight2')),
    ('heavy', () => moveAt('standHeavy')),
  ];
  for (final (name, plus, dist) in _specials[c.id]!) {
    out.add((name, () => moveAt(name, plus: plus, dist: dist)));
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

Future<void> writePng(String path, ui.Picture pic, int w, int h) async {
  final img = await pic.toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_shots != null) Directory(outDir).createSync(recursive: true);

  test('the four humans are registered with matching ids and dims', () {
    for (final id in [12, 13, 14, 15]) {
      final a = castArt[id];
      expect(a, isNotNull, reason: 'id $id');
      expect(a!.id, id);
      expect(a.dims.kind, id);
      expect(roster[id].id, id);
    }
  });

  for (final id in [12, 13, 14, 15]) {
    final c = roster[id];
    for (final look in FightLook.values) {
      test('humans ${c.key} ${look.name}', () async {
        if (_shots == null) return; // PNGs only when FIGHT_SHOTS=<dir> is set
        final art = FightArt();
        final list = shots(c);
        final pics = <ui.Picture>[];
        for (final (name, make) in list) {
          final pic = shot(art, make(), look);
          pics.add(pic);
          await writePng('$outDir/${c.key}_${name}_${look.name}.png', pic, 1280, 800);
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
      });
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
          width: 1200,
          height: 480,
          child: Column(children: [
            for (final look in FightLook.values)
              Expanded(
                child: Row(children: [
                  for (final id in [12, 13, 14, 15]) ...[
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

  test('every move frame of the humans paints without throwing (all looks)', () {
    final art = FightArt();
    for (final id in [12, 13, 14, 15]) {
      final cd = roster[id];
      for (var mv = 0; mv < cd.moves.length; mv++) {
        final s = duel(cd, roster[0], dist: 14000);
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

  test('every state of the humans paints without throwing, mirror match included', () {
    final art = FightArt();
    for (final id in [12, 13, 14, 15]) {
      final cd = roster[id];
      for (var st = 0; st <= St.techd; st++) {
        if (st == St.move) continue;
        final s = duel(cd, cd, dist: 14000);
        s.p[0].state = st;
        s.p[1].state = st;
        for (var sf = 0; sf < 30; sf += 3) {
          s.p[0].sf = sf;
          s.p[1].sf = sf;
          s.p[0].stun = 12 - sf ~/ 3;
          s.frame = sf * 2;
          final rec = ui.PictureRecorder();
          final cv = ui.Canvas(rec);
          final cam = FightCamera.follow(s, sz, null);
          for (final look in FightLook.values) {
            art.paintActors(cv, sz, cam, s, look);
          }
          rec.endRecording().dispose();
          expect(poseFor(s, 0).v.every((v) => v.isFinite), true, reason: '${cd.key} $st $sf');
        }
      }
    }
  });
}
