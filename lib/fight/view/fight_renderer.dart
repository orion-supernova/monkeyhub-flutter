import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/core.dart';
import 'art/fight_art.dart';

/// Draws a [FightState] in any [FightLook], including the pixel look's
/// low-res + shader pipeline. One per on-screen fight view; it keeps the
/// camera, the art's render-side memory and the pixel caches.
///
/// Cartoon and painted draw straight to the canvas. Pixel renders the stage,
/// the actors and the HUD at ~320 px wide, runs the actor and stage layers
/// through `shaders/fight_pixel.frag` (palette snap, dithering for the stage,
/// a 1-px ink outline for sprites), and upscales with nearest-neighbour. The
/// pixel layers refresh every [_pixelStride] sim frames, which is the 12 fps
/// "animated on fives" cadence of real sprite art, and is also what keeps the
/// pipeline cheap.
class FightRenderer {
  FightRenderer();

  final FightArt art = FightArt();
  FightCamera? _cam;

  static ui.FragmentProgram? _program;
  static Future<void>? _loading;

  /// Loads the pixel shader once per process. Safe to call repeatedly; the
  /// pixel look falls back to an unprocessed low-res render until it lands
  /// (or if the platform can't compile it).
  static Future<void> warmUp() {
    return _loading ??= () async {
      try {
        _program = await ui.FragmentProgram.fromAsset('shaders/fight_pixel.frag');
      } catch (e) {
        debugPrint('FightRenderer: pixel shader unavailable: $e');
      }
    }();
  }

  // ---- pixel caches
  static const int _pixelStride = 5;
  static const double _lowWidth = 320;
  int _pixFrame = -1;
  Size _pixSize = Size.zero;
  ui.Image? _pixStage, _pixActors, _pixHud;
  _Palette? _actorPal, _stagePal;
  double _stageCamX = double.nan, _stageCamScale = 0;
  int _stageFrame = -1;
  bool _stagePalDirty = false;
  bool _buildingPalette = false;
  int _pixStageId = 0;

  void dispose() {
    _pixStage?.dispose();
    _pixActors?.dispose();
    _pixHud?.dispose();
    _actorPal?.image.dispose();
    _stagePal?.image.dispose();
  }

  /// Snaps the camera on the next paint (new round, new match).
  void resetCamera() => _cam = null;

  /// Which place to draw (stages/stages.dart). View-only: the simulation never sees it.
  void paint(Canvas canvas, Size size, FightState s, FightLook look, List<String> names, FightHudText text, {int stage = 0}) {
    if (size.isEmpty) return;
    final cam = _cam = FightCamera.follow(s, size, _cam);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (look == FightLook.pixel) {
      _paintPixel(canvas, size, cam, s, names, text, stage);
    } else {
      art.paintStage(canvas, size, cam, look, s.frame, stage);
      art.paintActors(canvas, size, cam, s, look);
      art.paintHud(canvas, size, s, look, names, text: text);
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- pixel

  void _paintPixel(Canvas canvas, Size size, FightCamera cam, FightState s, List<String> names, FightHudText text, int stage) {
    final k = size.width / _lowWidth;
    final low = Size(_lowWidth, (size.height / k).roundToDouble());
    final lowCam = FightCamera(cam.scale / k, cam.originX / k, cam.groundY / k);
    if (stage != _pixStageId) {
      // A new place: its colours are not in the old palettes, so rebuild them.
      _pixStageId = stage;
      _actorPal?.image.dispose();
      _stagePal?.image.dispose();
      _actorPal = _stagePal = null;
      _pixStage?.dispose();
      _pixStage = null;
    }
    final stale = _pixStage == null || _pixSize != size || s.frame < _pixFrame || s.frame - _pixFrame >= _pixelStride;
    if (stale) {
      _pixSize = size;
      _pixFrame = s.frame;
      final w = low.width.toInt(), h = low.height.toInt();

      // The stage is the costliest layer (dithered, full screen): redraw it
      // only when the camera moved by a low-res pixel, or every quarter second
      // for the ambient motion (neon, rain, fireflies, snow).
      final camMoved = (lowCam.originX - _stageCamX).abs() >= .5 || (lowCam.scale - _stageCamScale).abs() > .002;
      final stageDue = _pixStage == null || camMoved || s.frame - _stageFrame >= 15 || s.frame < _stageFrame || _stagePalDirty;
      final stageRaw = stageDue || _actorPal == null ? _record(low, (c) => art.paintStage(c, low, lowCam, FightLook.pixel, s.frame, stage)) : null;
      final actorsRaw = _record(low, (c) => art.paintActors(c, low, lowCam, s, FightLook.pixel));
      if (stageDue && stageRaw != null) {
        _stageCamX = lowCam.originX;
        _stageCamScale = lowCam.scale;
        _stageFrame = s.frame;
        _stagePalDirty = false;
        _replace(() => _pixStage, (v) => _pixStage = v, _process(stageRaw, w, h, _stagePal, dither: 0.09, outline: false));
      }
      _replace(() => _pixActors, (v) => _pixActors = v, _process(actorsRaw, w, h, _actorPal, dither: 0, outline: true));
      _replace(() => _pixHud, (v) => _pixHud = v, _record(low, (c) => art.paintHud(c, low, s, FightLook.pixel, names, text: text)).toImageSync(w, h));
      if (_actorPal == null && !_buildingPalette && stageRaw != null) _buildPalettes(stageRaw, actorsRaw, w, h, stage);
    }
    final dst = Offset.zero & size;
    final paint = Paint()..filterQuality = FilterQuality.none;
    for (final img in [_pixStage, _pixActors, _pixHud]) {
      if (img == null) continue;
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, paint);
    }
  }

  void _replace(ui.Image? Function() get, void Function(ui.Image?) set, ui.Image next) {
    final old = get();
    set(next);
    old?.dispose();
  }

  ui.Picture _record(Size size, void Function(Canvas) draw) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Offset.zero & size);
    draw(c);
    return rec.endRecording();
  }

  /// Runs [raw] through the pixel shader into a w x h image. Without the
  /// shader or a palette yet, returns the raw low-res render.
  ui.Image _process(ui.Picture raw, int w, int h, _Palette? pal, {required double dither, required bool outline}) {
    final src = raw.toImageSync(w, h);
    final program = _program;
    if (program == null || pal == null) return src;
    final shader = program.fragmentShader()
      ..setFloat(0, w.toDouble())
      ..setFloat(1, h.toDouble())
      ..setFloat(2, pal.count.toDouble())
      ..setFloat(3, dither)
      // ink #150f1e, premultiplied (alpha 1)
      ..setFloat(4, outline ? 0x15 / 255 : 0)
      ..setFloat(5, outline ? 0x0f / 255 : 0)
      ..setFloat(6, outline ? 0x1e / 255 : 0)
      ..setFloat(7, outline ? 1 : 0)
      ..setImageSampler(0, src)
      ..setImageSampler(1, pal.image);
    final out = _record(Size(w.toDouble(), h.toDouble()), (c) => c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..shader = shader)).toImageSync(w, h);
    shader.dispose();
    src.dispose();
    return out;
  }

  /// Builds the two palettes once, from what this fight actually looks like:
  /// a median cut of the first stage and actor renders, plus the effect
  /// colours that may not be on screen yet. Async (pixel readback), so the
  /// first few pixel frames are drawn unprocessed.
  Future<void> _buildPalettes(ui.Picture stage, ui.Picture actors, int w, int h, int stageId) async {
    _buildingPalette = true;
    try {
      final si = stage.toImageSync(w, h), ai = actors.toImageSync(w, h);
      final sb = await si.toByteData(), ab = await ai.toByteData();
      si.dispose();
      ai.dispose();
      if (sb == null || ab == null || stageId != _pixStageId) return;
      final stageColors = medianCut(_opaque(sb), 40);
      final actorColors = medianCut(_opaque(ab), 40)..addAll(_effectColors);
      final sp = await _Palette.build(stageColors), ap = await _Palette.build(actorColors);
      if (stageId != _pixStageId) {
        sp.image.dispose();
        ap.image.dispose();
        return;
      }
      _stagePal = sp;
      _actorPal = ap;
      _pixFrame = -_pixelStride; // re-render with the palettes now
      _stagePalDirty = true;
    } finally {
      _buildingPalette = false;
    }
  }

  static const List<int> _effectColors = [
    0xffffe14d, 0xffffffff, 0xff7fe8ff, 0xffbff6ff, 0xff35c6ff, 0xff5fd8ff,
    0xffd9cfe3, 0xffff4f6e, 0xffffd23a, 0xff53d6f0, 0xfffff6ee, 0xffff9d5c,
  ];

  static List<int> _opaque(ByteData b) {
    final out = <int>[];
    final n = b.lengthInBytes ~/ 4;
    for (var i = 0; i < n; i++) {
      final a = b.getUint8(i * 4 + 3);
      if (a < 200) continue;
      out.add(0xff000000 | b.getUint8(i * 4) << 16 | b.getUint8(i * 4 + 1) << 8 | b.getUint8(i * 4 + 2));
    }
    return out;
  }
}

/// A palette as the shader reads it: a 64x1 RGBA image and how many entries
/// are real.
class _Palette {
  _Palette(this.image, this.count);
  final ui.Image image;
  final int count;

  static Future<_Palette> build(List<int> argb) async {
    final colors = argb.length > 64 ? argb.sublist(0, 64) : argb;
    final px = Uint8List(64 * 4);
    for (var i = 0; i < colors.length; i++) {
      final c = colors[i];
      px[i * 4] = (c >> 16) & 0xff;
      px[i * 4 + 1] = (c >> 8) & 0xff;
      px[i * 4 + 2] = c & 0xff;
      px[i * 4 + 3] = 0xff;
    }
    // decodeImageFromPixels, not ImageDescriptor.raw: the descriptor throws
    // on web (see web_safe_apis_test), and the fight ships there too.
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      px,
      64,
      1,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return _Palette(await done.future, colors.length);
  }
}

/// Median-cut colour quantisation: splits the colour set along its widest
/// channel until there are [n] boxes, and returns each box's average (ARGB).
@visibleForTesting
List<int> medianCut(List<int> argb, int n) {
  if (argb.isEmpty) return [];
  final boxes = <List<int>>[List.of(argb)];
  int range(List<int> b, int shift) {
    var lo = 255, hi = 0;
    for (final c in b) {
      final v = (c >> shift) & 0xff;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return hi - lo;
  }

  while (boxes.length < n) {
    var bi = -1, best = 0, bestShift = 16;
    for (var i = 0; i < boxes.length; i++) {
      if (boxes[i].length < 2) continue;
      for (final sh in const [16, 8, 0]) {
        final r = range(boxes[i], sh);
        if (r > best) {
          best = r;
          bi = i;
          bestShift = sh;
        }
      }
    }
    if (bi < 0 || best < 6) break;
    final b = boxes.removeAt(bi)..sort((x, y) => ((x >> bestShift) & 0xff) - ((y >> bestShift) & 0xff));
    final mid = b.length ~/ 2;
    boxes
      ..add(b.sublist(0, mid))
      ..add(b.sublist(mid));
  }
  return [
    for (final b in boxes)
      if (b.isNotEmpty) _average(b),
  ];
}

int _average(List<int> b) {
  var r = 0, g = 0, bl = 0;
  for (final c in b) {
    r += (c >> 16) & 0xff;
    g += (c >> 8) & 0xff;
    bl += c & 0xff;
  }
  final n = b.length;
  return 0xff000000 | (r ~/ n) << 16 | (g ~/ n) << 8 | (bl ~/ n);
}
