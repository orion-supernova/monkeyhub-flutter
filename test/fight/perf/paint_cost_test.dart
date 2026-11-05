import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/art/fight_art.dart';

/// Counts what a frame of the fight asks the GPU to do. Clips, layers and
/// blurs are the expensive ones on the web (CanvasKit) and on low-end
/// Android; this pins them so a regression shows up as a number, not as a
/// laggy phone. The paint itself is discarded.
class PaintCounts {
  int clip = 0, layer = 0, path = 0, shaded = 0, blur = 0, other = 0, frames = 0;
  void add(PaintCounts o) {
    clip += o.clip;
    layer += o.layer;
    path += o.path;
    shaded += o.shaded;
    blur += o.blur;
    other += o.other;
  }

  String per(int n) => 'clip ${(clip / n).toStringAsFixed(1)}  layer ${(layer / n).toStringAsFixed(1)}  '
      'path ${(path / n).toStringAsFixed(0)}  shaded ${(shaded / n).toStringAsFixed(1)}  blur ${(blur / n).toStringAsFixed(1)}';
}

class CountingCanvas implements ui.Canvas {
  CountingCanvas(this.n);
  final PaintCounts n;
  int _saves = 1;

  void _paint(Paint p) {
    if (p.shader != null) n.shaded++;
    if (p.maskFilter != null || p.imageFilter != null) n.blur++;
  }

  @override
  void save() => _saves++;
  @override
  void saveLayer(Rect? bounds, Paint paint) {
    _saves++;
    n.layer++;
    _paint(paint);
  }

  @override
  void restore() => _saves--;
  @override
  int getSaveCount() => _saves;
  @override
  void restoreToCount(int count) => _saves = count;
  @override
  void clipPath(Path path, {bool doAntiAlias = true}) => n.clip++;
  @override
  void clipRect(Rect rect, {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) {}
  @override
  void clipRRect(RRect rrect, {bool doAntiAlias = true}) => n.clip++;
  @override
  void drawPath(Path path, Paint paint) {
    n.path++;
    _paint(paint);
  }

  @override
  dynamic noSuchMethod(Invocation i) {
    // Every other draw: count it and inspect its Paint.
    n.other++;
    for (final a in i.positionalArguments) {
      if (a is Paint) _paint(a);
    }
    return null;
  }
}

FightState _fight(CharacterDef a, CharacterDef b, int frames) {
  final s = FightState.initial(seed: 7, p1: a, p2: b);
  final b0 = FightBot(seed: 1, level: BotLevel.hard), b1 = FightBot(seed: 2, level: BotLevel.hard);
  for (var i = 0; i < frames; i++) {
    step(s, b0.decide(s, 0), b1.decide(s, 1));
  }
  return s;
}

/// Per-frame budgets, in operations. Clips and layers are the costliest
/// GPU state changes there are; the fighters must need none per part.
const int kMaxClipsPerFrame = 6;
const int kMaxLayersPerFrame = 3;
const int kMaxBlursPerFrame = 2;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await GoogleFonts.pendingFonts([
      GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800),
      GoogleFonts.anta(),
      GoogleFonts.doto(fontWeight: FontWeight.w900),
    ]);
  });
  const size = Size(1280, 800);
  final looks = [FightLook.cartoon, FightLook.painted, FightLook.pixel];

  test('per-frame paint cost of every fighter stays inside the budget', () {
    final art = FightArt();
    final report = <String>[];
    final worst = {for (final l in looks) l: PaintCounts()};
    for (final look in looks) {
      final total = PaintCounts();
      var n = 0;
      for (final c in roster) {
        final s = _fight(c, roster[(c.id + 3) % roster.length], 240);
        // 120 consecutive frames of a live fight, both fighters busy.
        FightCamera? cam;
        for (var f = 0; f < 120; f++) {
          step(s, (f ~/ 9).isEven ? Inp.light : Inp.heavy, f % 23 == 0 ? Inp.special : 0);
          cam = FightCamera.follow(s, size, cam);
          final k = PaintCounts();
          final canvas = CountingCanvas(k);
          art.paintStage(canvas, size, cam, look, s.frame);
          art.paintActors(canvas, size, cam, s, look);
          art.paintHud(canvas, size, s, look, ['A', 'B']);
          total.add(k);
          n++;
          final w = worst[look]!;
          if (k.clip > w.clip) w.clip = k.clip;
          if (k.layer > w.layer) w.layer = k.layer;
          if (k.blur > w.blur) w.blur = k.blur;
          if (k.path > w.path) w.path = k.path;
        }
      }
      report.add('${look.name.padRight(8)} avg/frame: ${total.per(n)}');
    }
    for (final l in looks) {
      final w = worst[l]!;
      report.add('${l.name.padRight(8)} worst frame: clip ${w.clip} layer ${w.layer} blur ${w.blur} path ${w.path}');
    }
    // ignore: avoid_print
    print(report.join('\n'));
    for (final l in looks) {
      final w = worst[l]!;
      expect(w.clip, lessThanOrEqualTo(kMaxClipsPerFrame), reason: '${l.name}: clips per frame');
      expect(w.layer, lessThanOrEqualTo(kMaxLayersPerFrame), reason: '${l.name}: layers per frame');
      expect(w.blur, lessThanOrEqualTo(kMaxBlursPerFrame), reason: '${l.name}: blurs per frame');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
