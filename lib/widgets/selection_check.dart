import 'package:flutter/cupertino.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// The circle that says whether one row is picked.
///
/// Drawn on every row of a surface in selection mode, not only the chosen ones:
/// an empty ring is what tells the reader the whole list is asking a question.
/// The media grid rings every tile for the same reason (`_SelectionVeil` in
/// `media_grid_tile.dart`), and this is the flat-surface half of that idea —
/// the grid's version has to survive on top of a photograph, so it keeps its
/// white ring and dark fill instead.
///
/// Shared by the forward-target sheet and the transcript's multi-select so the
/// two never drift apart; both are "pick some rows, then act on them".
///
/// THE selection circle — every pick-some list (forward, group-call members,
/// invite friends, linked accounts, child setup) draws this, never a private
/// `_Check`/`_SelectionDot`. [media] is the over-a-photo variant (white ring,
/// dark wash) for grids and viewers.
/// Picking it is a small event, not a repaint: the disc dips and springs back
/// as it fills, and the tick draws itself in, stroke first, the way the iOS
/// Mail and Photos checks land. Unpicking just lets go. Calm motion shows the
/// end state at once. The animation lives in one controller per circle and
/// is idle (and free) whenever nothing is changing.
class SelectionCheck extends StatefulWidget {
  const SelectionCheck({
    super.key,
    required this.picked,
    this.size = 22,
    this.media = false,
    this.enabled = true,
    this.color,
  });

  final bool picked;
  final double size;

  /// Over a photo: a white ring on a dark wash, legible on any picture.
  final bool media;

  /// False dims it — a row that cannot be picked (already a member).
  final bool enabled;

  /// The picked fill, when the circle stands for something with a colour of
  /// its own: a storage category whose slice is that colour in the chart
  /// above. Null is the accent, as everywhere else.
  final Color? color;

  @override
  State<SelectionCheck> createState() => _SelectionCheckState();
}

class _SelectionCheckState extends State<SelectionCheck>
    with SingleTickerProviderStateMixin {
  /// 0 = empty ring, 1 = filled and ticked. Starts where the row already is,
  /// so a list opening with picks in it does not play them all.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 140),
    value: widget.picked ? 1 : 0,
  );

  /// The disc's dip and spring as it fills: in a touch, then past full size,
  /// then home.
  static final _pop = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.84)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 22,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.84, end: 1.0)
          .chain(CurveTween(curve: Curves.elasticOut)),
      weight: 78,
    ),
  ]);

  @override
  void didUpdateWidget(SelectionCheck old) {
    super.didUpdateWidget(old);
    if (old.picked == widget.picked) return;
    if (MotionScope.of(context).calm) {
      _c.value = widget.picked ? 1 : 0;
    } else if (widget.picked) {
      _c.forward(from: 0);
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final theme = ThemeScope.of(context);
    final Color ring;
    final Color fill;
    if (w.picked) {
      ring = w.color ?? theme.accent;
      fill = w.color ?? theme.accent;
    } else if (w.media) {
      ring = const Color(0xE6FFFFFF);
      fill = const Color(0x33000000);
    } else {
      // The theme's ink, not its divider token: on several palettes the
      // divider is near-invisible, and an empty ring that cannot be seen
      // does not ask the question.
      ring = theme.ink.withValues(alpha: 0.30);
      fill = const Color(0x00000000);
    }
    final tick = w.color == null ? theme.accentInk : const Color(0xFFFFFFFF);
    final disc = AnimatedContainer(
      duration: theme.motionFast,
      curve: theme.motionEntrance,
      width: w.size,
      height: w.size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: w.media ? 1.6 : 1.4),
      ),
    );
    return Opacity(
      opacity: w.enabled ? 1 : 0.4,
      child: AnimatedBuilder(
        animation: _c,
        child: disc,
        builder: (context, disc) {
          final t = _c.value;
          // The pop plays only on the way in; letting go just shrinks the
          // tick away.
          final scale =
              _c.status == AnimationStatus.forward ? _pop.transform(t) : 1.0;
          return Transform.scale(
            scale: scale,
            child: CustomPaint(
              foregroundPainter: t == 0
                  ? null
                  : _TickPainter(
                      // The stroke starts once the dip has turned.
                      progress: const Interval(0.18, 0.75,
                              curve: Curves.easeOutCubic)
                          .transform(t),
                      color: tick,
                    ),
              child: disc,
            ),
          );
        },
      ),
    );
  }
}

/// The tick, drawn along its own length so [progress] reveals it stroke by
/// stroke: down into the corner, then up and out.
class _TickPainter extends CustomPainter {
  const _TickPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.29, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.72, w * 0.37);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.105
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.progress != progress || old.color != color;
}
