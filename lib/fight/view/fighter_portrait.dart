import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'art/art_common.dart' show FightLook;
import 'art/kai_poses.dart';
import 'art/kai_rig.dart';
import 'art/roster_poses.dart';
import 'art/cast/registry.dart';
import 'fight_renderer.dart';

/// One fighter, alive, for cards and lobbies: breathing in its stance, and
/// throwing a heavy punch the moment [ready] turns on, then holding a tighter
/// guard. Drawn with the fight's own rig, so what you see here is exactly
/// what you play.
///
/// [facingLeft] mirrors it (the opponent's side of a VS screen). [alt] is the
/// alternate outfit the second fighter wears in a mirror match. The pixel
/// look goes through the fight's own pixel pass ([FightRenderer.pixelPass]):
/// the rig drawn small, palette-snapped, ink-outlined and upscaled with
/// nearest-neighbour, so every look switch restyles the cards too.
class FighterPortrait extends StatefulWidget {
  const FighterPortrait({
    super.key,
    this.charId = 0,
    this.alt = false,
    this.facingLeft = false,
    this.ready = false,
    this.look = FightLook.cartoon,
    this.glow = const Color(0xff3fd2c7),
    this.animate = true,
  });

  final int charId;
  final bool alt, facingLeft, ready;
  final FightLook look;
  final Color glow;

  /// False draws one still frame (grids of many portraits stay cheap).
  final bool animate;

  @override
  State<FighterPortrait> createState() => _FighterPortraitState();
}

class _FighterPortraitState extends State<FighterPortrait> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  late final Listenable _repaint = Listenable.merge([_t, PixelSprite.palettes]);
  final PixelSprite _sprite = PixelSprite();
  double? _readyAt;

  @override
  void initState() {
    super.initState();
    FightRenderer.warmUp();
    _ticker = createTicker((d) => _t.value = d.inMicroseconds / 1e6);
    if (widget.animate) _ticker.start();
  }

  @override
  void didUpdateWidget(FighterPortrait old) {
    super.didUpdateWidget(old);
    if (widget.ready && !old.ready) _readyAt = _t.value;
    if (!widget.ready) _readyAt = null;
    if (widget.animate && !_ticker.isActive) _ticker.start();
    if (!widget.animate && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    _sprite.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PortraitPainter(
          t: _t,
          repaint: _repaint,
          sprite: _sprite,
          readyAt: () => _readyAt,
          ready: widget.ready,
          charId: widget.charId,
          alt: widget.alt,
          facingLeft: widget.facingLeft,
          look: widget.look,
          glow: widget.glow,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// The pose at time [t]: breathing idle, or the ready flourish
/// (wind-up, heavy straight, hold, settle into guard).
@visibleForTesting
KPose portraitPose(double t, {double? readyAt, int charId = 0}) {
  final b = math.sin(t * 2.6);
  final isKai = charId == 0;
  final base = idleFor(charId);
  final idle = isKai
      ? KPose.from(pIdle, lean: .14 + b * .025, fu: .45 + b * .05, bu: .3 + b * .04, ff: 2.65 - b * .04)
      : KPose.from(base,
          lean: base.lean + b * .025, fu: base.fu + b * .05, bu: base.bu + b * .04, ff: base.ff - b * .04,
          ry: (charId == 3 || (castArt[charId]?.floats ?? false)) ? base.ry + b * 3 : base.ry);
  if (readyAt == null) return idle;
  final r = t - readyAt;
  final (hvyW, hvyX, guard) = isKai
      ? (pHvyW, pHvyX, KPose.from(pGuard, lean: pGuard.lean + b * .015))
      : readyPoses(charId);
  double e(double x) => x * x * (3 - 2 * x);
  if (r < .12) return KPose.lerp(idle, hvyW, e(r / .12));
  if (r < .2) return KPose.lerp(hvyW, hvyX, 1 - math.pow(1 - (r - .12) / .08, 3).toDouble());
  if (r < .55) return hvyX;
  if (r < .9) return KPose.lerp(hvyX, guard, e((r - .55) / .35));
  return guard;
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter({
    required this.t,
    required Listenable repaint,
    required this.sprite,
    required this.readyAt,
    required this.ready,
    required this.charId,
    required this.alt,
    required this.facingLeft,
    required this.look,
    required this.glow,
  }) : super(repaint: repaint);

  final ValueNotifier<double> t;
  final PixelSprite sprite;
  final double? Function() readyAt;
  final bool ready, alt, facingLeft;
  final int charId;
  final FightLook look;
  final Color glow;
  final RigPainter _rig = RigPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ground = size.height * .86;
    // A pool of light on the floor, brighter once ready.
    final pool = Rect.fromCenter(center: Offset(size.width / 2, ground), width: size.width * .9, height: size.height * .12);
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(colors: [glow.withValues(alpha: ready ? .55 : .3), glow.withValues(alpha: 0)]).createShader(pool),
    );
    // The rig stands ~190 units tall; fit it to the card, feet on the floor.
    final ratio = dimsFor(charId).cs / csScale;
    final scale = math.min(size.height * .72 / 190 * ratio, size.width * .85 / (charId == 2 ? 170 : (castArt[charId]?.portraitWidth ?? 120)));
    final pose = portraitPose(t.value, readyAt: readyAt(), charId: charId);
    void drawRig(Canvas c) {
      c.save();
      c.translate(size.width / 2 + (facingLeft ? 10 : -10) * scale, ground);
      c.scale(facingLeft ? -scale : scale, scale);
      _rig.fighter(c, pose, KPalette.forChar(charId, alt), look, charId: charId, alt: alt, frame: (t.value * 60).round());
      c.restore();
    }

    if (look == FightLook.pixel) {
      // About 72 art pixels for a standing fighter, never finer than 1.5 pt
      // per pixel, so a small card still reads as pixel art.
      sprite.paint(canvas, size, math.max(1.5, scale * 190 / 72), charId * 2 + (alt ? 1 : 0), drawRig);
    } else {
      drawRig(canvas);
    }
  }

  @override
  bool shouldRepaint(_PortraitPainter o) =>
      o.ready != ready || o.look != look || o.alt != alt || o.facingLeft != facingLeft || o.charId != charId || o.glow != glow;
}


/// One portrait's pixel-look sprite: the rig recorded at low resolution, run
/// through [FightRenderer.pixelPass] and drawn back up with nearest-neighbour.
/// Palettes are per fighter and outfit, built once per process from the first
/// render (async readback; until then the sprite is drawn unsnapped, the same
/// fallback the fight uses) and announced through [palettes] so still cards
/// repaint when theirs lands.
class PixelSprite {
  static final Map<int, PixelPalette> _palettes = {};
  static final Set<int> _building = {};
  static final ValueNotifier<int> palettes = ValueNotifier(0);

  ui.Image? _last;

  void dispose() {
    _last?.dispose();
    _last = null;
  }

  /// Draws [draw] (in [size] coordinates) as pixel art, [k] points per art
  /// pixel. [key] picks the palette (fighter and outfit).
  void paint(Canvas canvas, Size size, double k, int key, void Function(Canvas) draw) {
    final w = (size.width / k).ceil(), h = (size.height / k).ceil();
    if (w <= 0 || h <= 0) return;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    c.scale(1 / k);
    draw(c);
    final pic = rec.endRecording();
    final pal = _palettes[key];
    if (pal == null && !_building.contains(key)) _buildPalette(pic.toImageSync(w, h), key);
    final img = FightRenderer.pixelPass(pic, w, h, pal, outline: true);
    pic.dispose();
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Rect.fromLTWH(0, 0, w * k, h * k),
      Paint()..filterQuality = FilterQuality.none,
    );
    _last?.dispose();
    _last = img;
  }

  static void _buildPalette(ui.Image raw, int key) {
    _building.add(key);
    unawaited(() async {
      try {
        final bytes = await raw.toByteData();
        if (bytes == null) return;
        final colors = medianCut(FightRenderer.opaqueColors(bytes), 32);
        if (colors.isEmpty) return;
        _palettes[key] = await PixelPalette.build(colors);
        palettes.value++;
      } catch (e) {
        debugPrint('PixelSprite: palette failed: $e');
      } finally {
        raw.dispose();
        _building.remove(key);
      }
    }());
  }
}
