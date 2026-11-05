// A cached soft-glow sprite: cheap additive glows without MaskFilter blur or
// per-frame gradient shaders.
import 'dart:ui';

Image? _glow;
final Paint _gp = Paint()..isAntiAlias = false..filterQuality = FilterQuality.low;

Image? _glowImage() {
  if (_glow != null) return _glow;
  try {
    final rec = PictureRecorder();
    final c = Canvas(rec);
    const r = 32.0;
    c.drawCircle(
        const Offset(r, r),
        r,
        Paint()
          ..shader = Gradient.radial(const Offset(r, r), r, const [
            Color(0xFFFFFFFF),
            Color(0xB3FFFFFF),
            Color(0x40FFFFFF),
            Color(0x00FFFFFF),
          ], const [0, .25, .6, 1]));
    final pic = rec.endRecording();
    _glow = pic.toImageSync(64, 64);
    pic.dispose();
  } catch (_) {
    _glow = null;
  }
  return _glow;
}

/// Additive glow of [color] (its alpha is the intensity) around [c].
void drawGlow(Canvas canvas, Offset c, double radius, Color color, {bool additive = true}) {
  final img = _glowImage();
  if (img == null || radius <= 0) return;
  _gp
    ..colorFilter = ColorFilter.mode(color, BlendMode.modulate)
    ..blendMode = additive ? BlendMode.plus : BlendMode.srcOver;
  canvas.drawImageRect(img, const Rect.fromLTWH(0, 0, 64, 64), Rect.fromCircle(center: c, radius: radius), _gp);
}
