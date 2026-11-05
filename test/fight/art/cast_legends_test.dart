// Renders the LEGENDS family (UNIT-7, KAGE, EMBER, GOLEM) in all three looks:
// idle, normals, every special at its first active frame, projectiles in
// flight, the Super, a mirror match, a portraits sheet; plus a no-throw sweep
// over every state / move / frame. PNGs are inspected by eye.
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
    '/private/tmp/claude-501/-Users-muratcankoc-Documents-Projects-monkeyhub-flutter-monkeyhub/e56bc469-ecc4-40cc-91e2-f5899446bcce/scratchpad/fight_png/legends';
const ui.Size sz = ui.Size(1280, 800);

final CharacterDef unit7 = roster[16], kage = roster[17], ember = roster[18], golem = roster[19];

void forceMove(FightState s, int p, int moveId, int sf) {
  s.p[p].state = St.move;
  s.p[p].moveId = moveId;
  s.p[p].sf = sf;
}

int idx(CharacterDef c, String name) => c.moves.indexWhere((m) => m.name == name);

typedef Shot = (String, FightState Function());

/// Per fighter: (move name, frame to freeze at (null = startup), foe distance in units).
Map<int, List<(String, int?, int)>> _specials = {
  16: [
    ('rocket', 17, 40000),
    ('thrusterDash', 8, 30000),
    ('laserBeam', 16, 40000),
    ('jetRise', 6, 20000),
    ('selfDestruct', 26, 20000),
    ('selfDestruct', 33, 20000),
    ('selfDestruct', 40, 20000),
  ],
  17: [
    ('iaido', 12, 20000),
    ('iaidoStrike', 4, 12000),
    ('dashSlash', 8, 20000),
    ('shadowSlip', 6, 20000),
    ('risingSlash', 8, 20000),
    ('yuureiRyu', 8, 20000),
    ('yuureiRyu', 20, 20000),
  ],
  18: [
    ('fireball', 14, 40000),
    ('fireBreath', 14, 20000),
    ('tailSweep', 9, 20000),
    ('flameWingHop', 8, 20000),
    ('dragonInferno', 24, 30000),
    ('dragonInferno', 38, 30000),
  ],
  19: [
    ('rockThrow', 21, 40000),
    ('stoneShoulder', 20, 20000),
    ('groundSlam', 22, 24000),
    ('groundSlam', 28, 24000),
    ('crushGrab', 9, 14000),
    ('cataclysm', 20, 30000),
    ('cataclysm', 30, 30000),
  ],
};

/// Projectile names to wait for: (label, move, frames to play from move start).
Map<int, List<(String, String, int)>> _flights = {
  16: [('rocket_proj', 'rocket', 24), ('laser_proj', 'laserBeam', 22)],
  17: [],
  18: [('fireball_proj', 'fireball', 22), ('breath_proj', 'fireBreath', 18)],
  19: [('boulder_proj', 'rockThrow', 32)],
};

List<Shot> shots(CharacterDef c) {
  final foe = kai;
  FightState moveAt(String name, {int? at, int dist = 12000}) {
    final s = duel(c, foe, dist: dist);
    final i = idx(c, name);
    forceMove(s, 0, i, at ?? c.moves[i].startup);
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
    ('finisher', () => moveAt('standFinisher')),
    ('crouchHeavy', () => moveAt('crouchHeavy')),
    ('jumpLight', () => moveAt('jumpLight')),
    ('guard', () {
      final s = duel(c, foe, dist: 12000);
      s.p[0].state = St.blockstun;
      s.p[0].stun = 6;
      return s;
    }),
    ('hit', () {
      final s = duel(c, foe, dist: 12000);
      s.p[0].state = St.hitstun;
      s.p[0].stun = 10;
      return s;
    }),
  ];
  for (final (name, at, dist) in _specials[c.id]!) {
    out.add(('${name}_${at ?? 's'}', () => moveAt(name, at: at, dist: dist)));
  }
  for (final (label, name, frames) in _flights[c.id]!) {
    out.add((label, () {
      final s = duel(c, foe, dist: 40000);
      forceMove(s, 0, idx(c, name), 0);
      play(s, frames);
      return s;
    }));
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
  Directory(outDir).createSync(recursive: true);

  for (final c in [unit7, kage, ember, golem]) {
    for (final look in FightLook.values) {
      test('legends ${c.key} ${look.name}', () async {
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
                  for (final id in [16, 17, 18, 19]) ...[
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

  test('every state and move of the legends paints without throwing (all looks)', () {
    final art = FightArt();
    for (final cd in [unit7, kage, ember, golem]) {
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
      // Every plain state too.
      for (var st = 0; st <= St.techd; st++) {
        if (st == St.move) continue;
        final s = duel(cd, kai, dist: 14000);
        s.p[0].state = st;
        for (var sf = 0; sf < 14; sf += 3) {
          s.p[0].sf = sf;
          s.p[0].stun = 8;
          s.frame = sf * 2;
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
  });
}
