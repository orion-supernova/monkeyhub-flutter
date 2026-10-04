import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// Avatar-and-two-lines placeholders for a list that has not arrived.
///
/// Replaces a "Loading…" string. The string was one line where the content will
/// be many, so the section collapsed and then jumped to full height the moment
/// the data landed — and on a slow connection it read as an empty group rather
/// than a pending one. A skeleton occupies roughly the space the answer will,
/// so the layout settles once.
///
/// Shares `GameBoardSkeleton`'s sweep timing and shape language, but NOT its
/// colours — see the note in `build` for why a skeleton that scrolls over the
/// page background cannot use ones mixed against a known surface.
///
/// One controller for the whole group, not one per row: the rows are a single
/// block and should shimmer as one. A controller each would drift out of phase
/// and read as noise.
class SkeletonRows extends StatefulWidget {
  const SkeletonRows({
    super.key,
    this.count = 4,
    this.avatarSize = 32,
    this.circular = true,
  });

  /// How many placeholder rows. Pick the count the real list usually has, not
  /// the count it could have — the point is that nothing moves when the answer
  /// replaces it.
  final int count;

  final double avatarSize;

  /// Circular for people, rounded-square for rooms and files.
  final bool circular;

  @override
  State<SkeletonRows> createState() => _SkeletonRowsState();
}

class _SkeletonRowsState extends State<SkeletonRows> {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SkeletonSweep(
      child: Column(
        children: [
          for (var i = 0; i < widget.count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SkeletonBox(
                    width: widget.avatarSize,
                    height: widget.avatarSize,
                    radius: widget.circular ? widget.avatarSize : theme.radiusSm,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Varied widths so the block reads as names rather
                        // than as a grid. Deterministic, not random: a
                        // skeleton that reshuffles on every rebuild draws
                        // attention to itself, which is the opposite of the
                        // job.
                        SkeletonBox(width: 120.0 + (i % 3) * 34, height: 11),
                        const SizedBox(height: 6),
                        SkeletonBox(width: 70.0 + (i % 2) * 22, height: 9),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bubble-shaped placeholders for a transcript that has not arrived.
///
/// [SkeletonRows]'s avatar-and-two-lines shape is right for a roster and wrong
/// for a conversation: a transcript is alternating blocks of different widths
/// pinned to the bottom of the screen, and a skeleton that does not have that
/// silhouette reads as some other screen loading. This is the same shimmer in
/// the transcript's own shape.
///
/// Anchored to the BOTTOM, like the thing it stands in for. A chat list grows
/// upward from the composer, so a skeleton centred in the viewport would put
/// its rows where no message will be and then jump when the real ones land.
class SkeletonBubbles extends StatefulWidget {
  const SkeletonBubbles({super.key, this.count = 6});

  /// How many placeholder bubbles. Six fills a phone without implying a
  /// specific backlog.
  final int count;

  @override
  State<SkeletonBubbles> createState() => _SkeletonBubblesState();
}

class _SkeletonBubblesState extends State<SkeletonBubbles> {
  /// Widths and line counts, in order, cycled if [SkeletonBubbles.count] runs
  /// past the end.
  ///
  /// Deterministic rather than random, for the reason [SkeletonRows] gives:
  /// a skeleton that reshuffles on every rebuild draws the eye, which is the
  /// opposite of its job. Mixed one- and two-line blocks, because a column of
  /// identical rectangles reads as a table.
  static const _shapes = <({double width, int lines})>[
    (width: 0.52, lines: 1),
    (width: 0.68, lines: 2),
    (width: 0.34, lines: 1),
    (width: 0.74, lines: 2),
    (width: 0.44, lines: 1),
    (width: 0.60, lines: 1),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // The same sweep as SkeletonRows — two skeletons on screen at once (a
    // room opening over a still-loading chat list) must not beat against
    // each other.
    return SkeletonSweep(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Proportional, so the silhouette is the same on a phone and on the
          // chat column of a desktop window.
          final maxBubble = constraints.maxWidth * 0.78;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.count; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Align(
                    // Alternating sides — a conversation, not a monologue.
                    alignment:
                        i.isOdd ? Alignment.centerRight : Alignment.centerLeft,
                    child: SkeletonBox(
                      width: maxBubble * _shapes[i % _shapes.length].width,
                      // 20 a line plus the padding a bubble carries, which
                      // is what makes these read as bubbles rather than as
                      // paragraph rules.
                      height: 20.0 * _shapes[i % _shapes.length].lines + 18,
                      radius: theme.radiusLg,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The one skeleton animation: owns a single 1400ms sweep for everything
/// under it, so a block of [SkeletonBox]es shimmers as one (a controller per
/// box drifts out of phase and reads as noise). Wrap a whole placeholder
/// layout in ONE of these. Still under reduced motion.
///
/// Every skeleton in the app uses this pair — the link preview, the
/// expression grid and the game board had each grown their own controller,
/// colour maths and (in one case) an opacity pulse instead of a sweep.
class SkeletonSweep extends StatefulWidget {
  const SkeletonSweep({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonSweep> createState() => _SkeletonSweepState();
}

class _SkeletonSweepState extends State<SkeletonSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MotionScope.of(context).calm;
    if (calm) {
      _sweep
        ..stop()
        ..value = 0;
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: _SweepScope(animation: _sweep, child: widget.child),
      );
}

class _SweepScope extends InheritedWidget {
  const _SweepScope({required this.animation, required super.child});
  final Animation<double> animation;

  @override
  bool updateShouldNotify(_SweepScope old) => old.animation != animation;
}

/// One placeholder block. Under a [SkeletonSweep] it shimmers with its
/// siblings; on its own it is a static block.
///
/// Translucent ink, not blended surface colours: a skeleton scrolls over
/// `theme.backgroundLayer`, a card or a sheet, and only an alpha over whatever
/// is actually behind it reads on all of them. Repaints through a painter
/// tied to the sweep — no rebuild per frame.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 4,
    this.circle = false,
  });

  /// Null fills the available width.
  final double? width;
  final double height;
  final double radius;

  /// A round avatar placeholder (ignores [radius]).
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final scope = context.dependOnInheritedWidgetOfExactType<_SweepScope>();
    // A Container, not a SizedBox: tests find skeleton blocks by type.
    // ignore: sized_box_for_whitespace
    return Container(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ShimmerPainter(
          t: scope?.animation,
          base: theme.inkMuted.withValues(alpha: 0.16),
          highlight: theme.inkMuted.withValues(alpha: 0.34),
          radius: circle ? height / 2 : radius,
        ),
      ),
    );
  }
}

/// The sweep is a gradient whose stops move with [t], rather than an opacity
/// pulse. A pulse makes the whole list breathe in unison, which is more
/// distracting than a highlight travelling across it once.
class _ShimmerPainter extends CustomPainter {
  _ShimmerPainter({
    required this.t,
    required this.base,
    required this.highlight,
    required this.radius,
  }) : super(repaint: t);

  final Animation<double>? t;
  final Color base;
  final Color highlight;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint();
    final anim = t;
    if (anim == null) {
      paint.color = base;
    } else {
      // Travels from fully off the left to fully off the right, so there is
      // a beat with no highlight at all between passes.
      final x = (anim.value * 2.4) - 0.7;
      paint.shader = LinearGradient(
        begin: Alignment(x - 0.6, 0),
        end: Alignment(x + 0.6, 0),
        colors: [base, highlight, base],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    }
    canvas.drawRRect(rr, paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) =>
      old.t != t ||
      old.base != base ||
      old.highlight != highlight ||
      old.radius != radius;
}
