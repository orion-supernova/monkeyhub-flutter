import 'package:flutter/material.dart';

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

class _SkeletonRowsState extends State<SkeletonRows>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // TRANSLUCENT ink, not blended surface colours.
    //
    // `GameBoardSkeleton` can blend `surfaceSunken` over `surface` because it
    // sits inside a tile and knows exactly what is behind it. These rows do
    // not: room info scrolls over `theme.backgroundLayer`, and the first cut
    // — copied from that widget — came out almost invisible against it.
    //
    // Composing over whatever is actually behind is both more robust and less
    // to reason about: the same two alphas read on every palette, light or
    // dark, on a page or inside a card.
    final base = theme.inkMuted.withValues(alpha: 0.16);
    final highlight = theme.inkMuted.withValues(alpha: 0.34);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (_, _) => Column(
          children: [
            for (var i = 0; i < widget.count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _Shape(
                      width: widget.avatarSize,
                      height: widget.avatarSize,
                      radius: widget.circular ? widget.avatarSize : theme.radiusSm,
                      t: _sweep.value,
                      base: base,
                      highlight: highlight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Shape(
                            // Varied widths so the block reads as names rather
                            // than as a grid. Deterministic, not random: a
                            // skeleton that reshuffles on every rebuild draws
                            // attention to itself, which is the opposite of
                            // the job.
                            width: 120.0 + (i % 3) * 34,
                            height: 11,
                            radius: 4,
                            t: _sweep.value,
                            base: base,
                            highlight: highlight,
                          ),
                          const SizedBox(height: 6),
                          _Shape(
                            width: 70.0 + (i % 2) * 22,
                            height: 9,
                            radius: 4,
                            t: _sweep.value,
                            base: base,
                            highlight: highlight,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One shimmering block.
///
/// The sweep is a gradient whose stops move with [t], rather than an opacity
/// pulse. A pulse makes the whole list breathe in unison, which is more
/// distracting than a highlight travelling across it once.
class _Shape extends StatelessWidget {
  const _Shape({
    required this.width,
    required this.height,
    required this.radius,
    required this.t,
    required this.base,
    required this.highlight,
  });

  final double width;
  final double height;
  final double radius;
  final double t;
  final Color base;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    // Travels from fully off the left to fully off the right, so there is a
    // beat with no highlight at all between passes.
    final x = (t * 2.4) - 0.7;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(x - 0.6, 0),
          end: Alignment(x + 0.6, 0),
          colors: [base, highlight, base],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
