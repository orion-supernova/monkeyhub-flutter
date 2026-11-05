import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'art/art_common.dart' show FightLook;
import 'art/kai_poses.dart';
import 'art/kai_rig.dart';
import 'art/roster_poses.dart';
import 'art/cast/registry.dart';

/// One fighter, alive, for cards and lobbies: breathing in its stance, and
/// throwing a heavy punch the moment [ready] turns on, then holding a tighter
/// guard. Drawn with the fight's own rig, so what you see here is exactly
/// what you play.
///
/// [facingLeft] mirrors it (the opponent's side of a VS screen). [alt] is the
/// alternate outfit the second fighter wears in a mirror match. The pixel
/// look has no single-sprite pipeline, so portraits use cartoon for it.
class FighterPortrait extends StatefulWidget {
  const FighterPortrait({
    super.key,
    this.charId = 0,
    this.alt = false,
    this.facingLeft = false,
    this.ready = false,
    this.look = FightLook.cartoon,
    this.glow = const Color(0xff3fd2c7),
  });

  final int charId;
  final bool alt, facingLeft, ready;
  final FightLook look;
  final Color glow;

  @override
  State<FighterPortrait> createState() => _FighterPortraitState();
}

class _FighterPortraitState extends State<FighterPortrait> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _t = ValueNotifier(0);
  double? _readyAt;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _t.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void didUpdateWidget(FighterPortrait old) {
    super.didUpdateWidget(old);
    if (widget.ready && !old.ready) _readyAt = _t.value;
    if (!widget.ready) _readyAt = null;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PortraitPainter(
          t: _t,
          readyAt: () => _readyAt,
          ready: widget.ready,
          charId: widget.charId,
          alt: widget.alt,
          facingLeft: widget.facingLeft,
          look: widget.look == FightLook.pixel ? FightLook.cartoon : widget.look,
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
    required this.readyAt,
    required this.ready,
    required this.charId,
    required this.alt,
    required this.facingLeft,
    required this.look,
    required this.glow,
  }) : super(repaint: t);

  final ValueNotifier<double> t;
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
    canvas.save();
    canvas.translate(size.width / 2 + (facingLeft ? 10 : -10) * scale, ground);
    canvas.scale(facingLeft ? -scale : scale, scale);
    _rig.fighter(canvas, portraitPose(t.value, readyAt: readyAt(), charId: charId), KPalette.forChar(charId, alt), look,
        charId: charId, alt: alt, frame: (t.value * 60).round());
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter o) =>
      o.ready != ready || o.look != look || o.alt != alt || o.facingLeft != facingLeft || o.charId != charId || o.glow != glow;
}
