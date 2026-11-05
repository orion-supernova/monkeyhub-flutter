import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/art/fight_art.dart';
import 'package:monkeyhub/fight/view/art/quality.dart';
import 'package:monkeyhub/fight/view/art/stages/stages.dart';
import 'package:monkeyhub/fight/view/fight_stage_picker.dart';

import '../fight_test_utils.dart';

/// PNG output for eyeballing the stages: set `FIGHT_SHOTS=dir` to write them.
final String? _shots = Platform.environment['FIGHT_SHOTS'];
const ui.Size _sz = ui.Size(1280, 720);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await GoogleFonts.pendingFonts([
      GoogleFonts.bricolageGrotesque(fontWeight: ui.FontWeight.w800),
      GoogleFonts.anta(),
      GoogleFonts.doto(fontWeight: ui.FontWeight.w900),
    ]);
  });

  FightState scene() {
    final s = duel(kai, mojo, dist: 22000);
    play(s, 20);
    return s;
  }

  Future<void> shot(FightArt art, FightState s, int stage, FightLook look, int frame) async {
    final cam = FightCamera.follow(s, _sz, null);
    final ui.Image img;
    if (look == FightLook.pixel) {
      // The pixel look renders at ~320 px wide and is upscaled with nearest.
      const k = 4.0;
      final low = ui.Size(_sz.width / k, _sz.height / k);
      final lowCam = FightCamera(cam.scale / k, cam.originX / k, cam.groundY / k);
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      art.paintStage(c, low, lowCam, look, frame, stage);
      art.paintActors(c, low, lowCam, s, look);
      final small = await rec.endRecording().toImage(low.width.toInt(), low.height.toInt());
      final rec2 = ui.PictureRecorder();
      ui.Canvas(rec2).drawImageRect(small, ui.Rect.fromLTWH(0, 0, low.width, low.height), ui.Offset.zero & _sz, ui.Paint()..filterQuality = ui.FilterQuality.none);
      img = await rec2.endRecording().toImage(_sz.width.toInt(), _sz.height.toInt());
    } else {
      final rec = ui.PictureRecorder();
      final c = ui.Canvas(rec);
      art.paintStage(c, _sz, cam, look, frame, stage);
      art.paintActors(c, _sz, cam, s, look);
      art.paintHud(c, _sz, s, look, [s.chars[0].name, s.chars[1].name]);
      img = await rec.endRecording().toImage(_sz.width.toInt(), _sz.height.toInt());
    }
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(_shots!)..createSync(recursive: true);
    File('${dir.path}/stage${stage}_${look.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  test('stage PNGs', () async {
    if (_shots == null) return;
    final art = FightArt();
    final s = scene();
    for (final d in kFightStages) {
      for (final look in FightLook.values) {
        await shot(art, s, d.id, look, 137);
      }
    }
  });

  test('picker thumbnails sheet', () async {
    if (_shots == null) return;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    for (final d in kFightStages) {
      final img = FightStageThumbs.of(d.id)!;
      c.drawImage(img, ui.Offset(d.id * 322.0, 0), ui.Paint());
    }
    final out = await rec.endRecording().toImage(322 * kFightStages.length, 200);
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    File('$_shots/thumbs.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });

  test('every stage paints in every look and quality without throwing', () {
    final art = FightArt();
    final s = scene();
    final cam = FightCamera.follow(s, _sz, null);
    final was = fightQuality.value;
    for (final q in FightQuality.values) {
      fightQuality.value = q;
      for (final d in kFightStages) {
        for (final look in FightLook.values) {
          for (final f in [0, 1, 77, 5000]) {
            final rec = ui.PictureRecorder();
            art.paintStage(ui.Canvas(rec), _sz, cam, look, f, d.id);
            rec.endRecording().dispose();
          }
        }
      }
    }
    fightQuality.value = was;
  });
}
