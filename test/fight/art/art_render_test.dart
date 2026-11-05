import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/art/fight_art.dart';
import 'package:monkeyhub/fight/view/art/kai_poses.dart';
import 'package:monkeyhub/fight/view/art/kai_rig.dart';
import 'package:monkeyhub/fight/view/art/poser.dart';

import '../fight_test_utils.dart';

const String outDir = '/private/tmp/claude-501/-Users-muratcankoc-Documents-Projects-monkeyhub-flutter-monkeyhub/e56bc469-ecc4-40cc-91e2-f5899446bcce/scratchpad/fight_png';
const ui.Size sz = ui.Size(1280, 800);

int runUntil(FightState s, bool Function(FightState) done, int Function(int f, FightState s) in0,
    {int Function(int f, FightState s)? in1, int max = 400}) {
  var f = 0;
  while (!done(s) && f < max) {
    step(s, in0(f, s), in1 == null ? 0 : in1(f, s));
    f++;
  }
  expect(f < max, true, reason: 'scenario did not reach its target frame');
  return f;
}

Future<void> save(FightArt art, String name, FightState s, FightLook look, {FightCamera? cam}) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  final camera = cam ?? FightCamera.follow(s, sz, null);
  art.paintStage(c, sz, camera, look, s.frame);
  art.paintActors(c, sz, camera, s, look);
  art.paintHud(c, sz, s, look, [s.chars[0].name, s.chars[1].name]);
  final img = await rec.endRecording().toImage(sz.width.toInt(), sz.height.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  Directory(outDir).createSync(recursive: true);
  File('$outDir/${name}_${look.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late FightArt art;

  setUpAll(() async {
    await GoogleFonts.pendingFonts([
      GoogleFonts.bricolageGrotesque(fontWeight: ui.FontWeight.w800),
      GoogleFonts.anta(),
      GoogleFonts.doto(fontWeight: ui.FontWeight.w900),
    ]);
    art = FightArt();
  });

  final scenarios = <String, FightState Function()>{
    'idle': () {
      final s = duel(kai, kai, dist: 16000);
      play(s, 30);
      return s;
    },
    'jab_whiff': () {
      final s = duel(kai, kai, dist: 24000);
      runUntil(s, (s) => s.p[0].state == St.move && s.p[0].sf == 4, (f, s) => f == 0 ? Inp.light : 0);
      return s;
    },
    'heavy_hit': () {
      final s = duel(kai, kai, dist: 14000);
      runUntil(s, (s) => s.p[0].state == St.move && s.p[0].sf == 10, (f, s) => f == 0 ? Inp.heavy : 0);
      return s;
    },
    'crouch_heavy': () {
      final s = duel(kai, kai, dist: 24000);
      runUntil(s, (s) => s.p[0].state == St.move && s.p[0].sf == 10 && s.p[0].moveId == N.crouchHeavy,
          (f, s) => Inp.down | (f == 3 ? Inp.heavy : 0));
      return s;
    },
    'jump_heavy': () {
      final s = duel(kai, kai, dist: 22000);
      var pressed = false;
      runUntil(s, (s) => s.p[0].state == St.move && s.p[0].moveId == N.jumpHeavy && s.p[0].sf == 8, (f, s) {
        if (f == 0) return Inp.up;
        if (s.p[0].state == St.jump && s.p[0].vy < 600 && !pressed) {
          pressed = true;
          return Inp.heavy;
        }
        return 0;
      });
      return s;
    },
    'surge_proj': () {
      final s = duel(kai, kai, dist: 40000);
      runUntil(s, (s) => s.projectiles.isNotEmpty, (f, s) => f == 0 ? Inp.special : 0);
      play(s, 9);
      return s;
    },
    'surge_charge': () {
      final s = duel(kai, kai, dist: 40000);
      runUntil(s, (s) => s.p[0].state == St.move && s.p[0].sf == 8, (f, s) => f == 0 ? Inp.special : 0);
      return s;
    },
    'roll_mid': () {
      final s = duel(kai, kai, dist: 40000);
      runUntil(s, (s) => s.p[0].state == St.roll && s.p[0].sf == 12, (f, s) => f == 0 ? Inp.roll : 0);
      return s;
    },
    'hit_spark': () {
      final s = duel(kai, kai, dist: 11000);
      runUntil(s, (s) => s.p[0].state == St.move && s.p[0].sf == 10, (f, s) => f == 0 ? Inp.heavy : 0);
      play(s, 3);
      return s;
    },
    'p2_heavy': () {
      final s = duel(kai, kai, dist: 12500);
      runUntil(s, (s) => s.p[1].state == St.move && s.p[1].sf == 10, (f, s) => 0, in1: (f, s) => f == 0 ? Inp.heavy : 0);
      return s;
    },
    'storm': () {
      final s = duel(kai, kai, dist: 20000);
      s.p[0].meter = meterMax;
      runUntil(s, (s) => s.p[0].state == St.move && s.p[0].moveId == s.chars[0].superMove && s.p[0].sf == 26 && s.superFlash == 0,
          (f, s) => f == 0 ? Inp.superBtn : 0);
      return s;
    },
    'super_flash': () {
      final s = duel(kai, kai, dist: 20000);
      s.p[0].meter = meterMax;
      runUntil(s, (s) => s.superFlash > 0, (f, s) => f == 0 ? Inp.superBtn : 0);
      play(s, 12);
      return s;
    },
    'ko': () {
      final s = duel(kai, kai, dist: 11000);
      s.p[1].health = 20;
      runUntil(s, (s) => s.phase == Phase.ko, (f, s) => f == 0 ? Inp.heavy : 0);
      play(s, 75);
      return s;
    },
    'intro_round': () {
      final s = FightState.initial(seed: 3, p1: kai, p2: kai);
      play(s, 20);
      return s;
    },
    'intro_fight': () {
      final s = FightState.initial(seed: 3, p1: kai, p2: kai);
      play(s, 66);
      return s;
    },
    'other_chars': () {
      final s = duel(mojo, nyx, dist: 16000);
      play(s, 20);
      return s;
    },
    'other_tank': () {
      final s = duel(tank, kai, dist: 16000);
      play(s, 20);
      return s;
    },
  };

  for (final look in FightLook.values) {
    for (final e in scenarios.entries) {
      test('render ${e.key} ${look.name}', () async {
        final s = e.value();
        await save(art, e.key, s, look);
        expect(File('$outDir/${e.key}_${look.name}.png').lengthSync(), greaterThan(5000));
      });
    }
  }

  test('every state and move paints without throwing', () {
    final art2 = FightArt();
    for (final cd in [kai, mojo, tank, nyx]) {
      for (var mv = 0; mv < cd.moves.length; mv++) {
        final s = duel(cd, cd, dist: 14000);
        s.p[0].state = St.move;
        s.p[0].moveId = mv;
        for (var sf = 0; sf <= cd.moves[mv].total; sf++) {
          s.p[0].sf = sf;
          final rec = ui.PictureRecorder();
          final c = ui.Canvas(rec);
          final cam = FightCamera.follow(s, sz, null);
          art2.paintActors(c, sz, cam, s, FightLook.cartoon);
          rec.endRecording().dispose();
        }
      }
      for (final st in [for (var i = 0; i <= St.techd; i++) i]) {
        if (st == St.move) continue;
        final s = duel(cd, cd, dist: 14000);
        s.p[0].state = st;
        s.p[1].state = st;
        for (final sf in [0, 3, 10, 30]) {
          s.p[0].sf = sf;
          s.p[0].stun = sf;
          s.p[1].vy = sf * 100 - 500;
          final rec = ui.PictureRecorder();
          final c = ui.Canvas(rec);
          final cam = FightCamera.follow(s, sz, null);
          for (final look in FightLook.values) {
            art2.paintStage(c, sz, cam, look, sf);
            art2.paintActors(c, sz, cam, s, look);
            art2.paintHud(c, sz, s, look, ['A', 'B']);
          }
          rec.endRecording().dispose();
        }
      }
    }
  });

  test('pose sheet', () async {
    final names = <String>[];
    final poses = <KPose>[];
    final k = kai;
    for (var i = 0; i < k.moves.length; i++) {
      final m = k.moves[i];
      final anim = animFor(m, k);
      names.add('${m.name}#$i');
      poses.add(m.name == 'hundredStorm' ? pHvyX : evalKeys(anim.keys, m.startup.toDouble()));
    }
    final extra = {
      'idle': pIdle, 'crouch': pCrouch, 'guard': pGuard, 'hit': pHitX, 'lie': pLie, 'tuck': pTuck, 'air': pAir,
      'dash': pDashW, 'getup': evalKeysU(.3),
    };
    extra.forEach((n, p) {
      names.add(n);
      poses.add(p);
    });
    const cols = 6;
    final rows = (poses.length / cols).ceil();
    const cw = 260.0, ch = 300.0;
    for (final look in FightLook.values) {
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      c.drawRect(ui.Rect.fromLTWH(0, 0, cols * cw, rows * ch), ui.Paint()..color = const ui.Color(0xFF5a4a6a));
      final rig = RigPainter();
      for (var i = 0; i < poses.length; i++) {
        final x = (i % cols) * cw + cw / 2 - 20, y = (i ~/ cols) * ch + ch - 50;
        c.save();
        c.translate(x, y);
        c.scale(1.0);
        c.drawLine(const ui.Offset(-90, 0), const ui.Offset(90, 0), ui.Paint()..color = const ui.Color(0xFF000000));
        rig.fighter(c, poses[i], KPalette.kai, look);
        c.restore();
        final tp = TextPainter(text: TextSpan(text: names[i], style: const TextStyle(fontSize: 14, color: ui.Color(0xFFFFFFFF))), textDirection: TextDirection.ltr)..layout();
        tp.paint(c, ui.Offset((i % cols) * cw + 6, (i ~/ cols) * ch + 4));
      }
      final img = await rec.endRecording().toImage((cols * cw).toInt(), (rows * ch).toInt());
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(outDir).createSync(recursive: true);
      File('$outDir/sheet_${look.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }
  });
}
