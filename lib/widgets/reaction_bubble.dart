import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/message_reaction.dart';
import '../theme/app_theme.dart';
import '../theme/interaction.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

class ReactionRow extends StatefulWidget {
  const ReactionRow({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onToggle,
    this.onShowReactors,
    this.alignment = WrapAlignment.start,
    this.hanging = false,
  });

  /// Drawn as badges hanging off the bubble above — see [HangingReactions].
  /// Each chip is opaque and wears a ring of the chat's own background, so
  /// where it overlaps the bubble it reads as cut out of it (WhatsApp's look)
  /// instead of a translucent wash going muddy over the bubble's colour.
  /// False keeps the plain chips the album tiles draw on their photographs.
  final bool hanging;

  final List<MessageReaction> reactions;
  final String currentUserId;
  final void Function(String emoji) onToggle;

  final void Function(String emoji)? onShowReactors;

  final WrapAlignment alignment;

  @override
  State<ReactionRow> createState() => _ReactionRowState();
}

class _ReactionRowState extends State<ReactionRow> {
  /// False until the row has painted once. Chips present on the first build
  /// were already there — a room opening, a row scrolling back into view —
  /// and must not pop; only one that appears after it has just been added.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _settled = true);
  }

  @override
  Widget build(BuildContext context) {
    final reactions = widget.reactions;
    if (reactions.isEmpty) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    final calm = MotionScope.of(context).calm;

    // Group by emoji
    final groups = <String, List<MessageReaction>>{};
    for (final r in reactions) {
      groups.putIfAbsent(r.emoji, () => []).add(r);
    }

    return Padding(
      // A hanging row's air above is the bubble itself — the overlap is the
      // point — so only the free-standing row keeps its gap.
      padding: EdgeInsets.only(top: widget.hanging ? 0 : 4),
      child: Wrap(
        // A hanging chip's ring is stroked OUTSIDE its box, so at 4 apart two
        // rings meet exactly and the fills keep 4pt of background between.
        spacing: 4,
        runSpacing: 4,
        alignment: widget.alignment,
        children: [
          for (final entry in groups.entries)
            _ReactionChip(
              // Keyed by emoji so a chip keeps its state — and does not
              // re-pop — when the others around it change.
              key: ValueKey(entry.key),
              emoji: entry.key,
              count: entry.value.length,
              mine: entry.value.any((r) => r.userId == widget.currentUserId),
              popIn: _settled && !calm,
              animate: !calm,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onToggle(entry.key);
              },
              onLongPress: widget.onShowReactors == null
                  ? null
                  : () => widget.onShowReactors!(entry.key),
              theme: theme,
              hanging: widget.hanging,
            ),
        ],
      ),
    );
  }
}

/// One emoji's chip. Pops in on a spring when it is new, and gives a small
/// bump whenever its count changes — the Telegram feel, where adding a
/// reaction is something you watch land rather than a number that changes.
class _ReactionChip extends StatefulWidget {
  const _ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
    required this.onLongPress,
    required this.theme,
    required this.popIn,
    required this.animate,
    this.hanging = false,
  });
  final bool hanging;
  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final AppTheme theme;

  /// Whether this chip was born after its row first painted.
  final bool popIn;

  /// False under reduced motion: no pop, no bump.
  final bool animate;

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  /// True while the current run of [_ctrl] is a bump rather than a pop.
  bool _bump = false;

  @override
  void initState() {
    super.initState();
    if (widget.popIn) _ctrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(_ReactionChip old) {
    super.didUpdateWidget(old);
    if (widget.animate && old.count != widget.count) {
      _bump = true;
      _ctrl.forward(from: 0).whenComplete(() => _bump = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _scale(double t) {
    if (_bump) {
      // 1 → 1.18 → 1, front-loaded.
      return 1 + 0.18 * (t < 0.3 ? t / 0.3 : (1 - t) / 0.7);
    }
    return Curves.elasticOut.transform(t).clamp(0.0, 1.3);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final mine = widget.mine;
    final chip = RawGestureDetector(
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (instance) => instance
            ..onTap = widget.onTap
            // Desktop/trackpad right-click reaches the same list, matching
            // how the bubble already treats a secondary tap as a long-press.
            ..onSecondaryTap = widget.onLongPress,
        ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: kReactorsLongPress),
          (instance) => instance.onLongPress = widget.onLongPress,
        ),
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        // Yours is solid, in the colour of your own bubbles; everyone else's
        // is a soft wash with no outline.
        //
        // Hanging, the wash is pre-blended onto the background so it is the
        // same colour it always was where it sits on the chat, and stays that
        // colour where it overlaps a bubble — a translucent fill there took
        // on the bubble's hue. The ring is the chat background too, so the
        // badge looks punched out of the bubble's edge, and a whisper of
        // shadow lifts it on themes whose bubble and background are close.
        decoration: widget.hanging
            ? BoxDecoration(
                color: mine
                    ? theme.bubbleFill(isMine: true)
                    : Color.alphaBlend(
                        theme.ink.withValues(alpha: 0.09),
                        theme.background,
                      ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: theme.background,
                  width: kReactionRing,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              )
            : BoxDecoration(
                color: mine
                    ? theme.bubbleFill(isMine: true)
                    : theme.ink.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(999),
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 4),
            Text(
              '${widget.count}',
              style: theme.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: mine ? theme.accentInk : theme.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _ctrl,
      child: chip,
      builder: (context, child) => _ctrl.isCompleted
          ? child!
          : Transform.scale(scale: _scale(_ctrl.value), child: child),
    );
  }
}

/// Width of the background-coloured ring round a hanging chip.
const double kReactionRing = 2;

/// How far a hanging reaction row climbs up over the bubble above it.
///
/// Chosen against the in-bubble timestamp, which is the one thing it must
/// never touch. Measured on a render, the stamp's glyphs end ~7.7pt above a
/// text bubble's bottom edge (a photo's stamp lozenge, 8pt); the badge climbs
/// this far plus its [kReactionRing], 6pt in all, so it clears both. At 8 the
/// ring visibly bit into "21:15" on every short bubble — the overlap is
/// deliberately the subtle kind, the ring sitting ON the edge doing the work.
const double kReactionOverlap = 4;

/// Lays [child] out normally, then pulls it up by [overlap]: it paints and
/// takes taps [overlap] points above its own top, and reports that much less
/// height, so whatever follows it sits where it would have with no overlap.
///
/// A render object rather than a `Transform.translate` because a transform
/// moves the paint but not the layout — the row would still reserve its full
/// height and leave an [overlap]-tall gap under every reacted bubble. And it
/// overrides [hitTest] because a box only accepts taps inside its own size:
/// without that, the strip of chip that overlaps the bubble would pass the
/// tap through to the bubble underneath and open its menu instead.
///
/// It must be the DIRECT child of whatever it overlaps into (here,
/// `_BubbleLayout`'s column). Any ordinary box between them — a `Padding` —
/// would refuse the overlapped taps at its own edge before they got here, so
/// insets go inside [child].
class HangingReactions extends SingleChildRenderObjectWidget {
  const HangingReactions({
    super.key,
    this.overlap = kReactionOverlap,
    required Widget super.child,
  });

  final double overlap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHanging(overlap);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderHanging).overlap = overlap;
  }
}

class _RenderHanging extends RenderShiftedBox {
  _RenderHanging(this._overlap) : super(null);

  double _overlap;
  double get overlap => _overlap;
  set overlap(double v) {
    if (v == _overlap) return;
    _overlap = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints.loosen(), parentUsesSize: true);
    // Never climbs further than the child is tall — an empty row reports
    // zero rather than a negative height.
    final up = overlap.clamp(0.0, c.size.height);
    (c.parentData! as BoxParentData).offset = Offset(0, -up);
    size = constraints.constrain(Size(c.size.width, c.size.height - up));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    final up = overlap.clamp(0.0, c.size.height);
    final bounds = Rect.fromLTWH(0, -up, size.width, size.height + up);
    if (!bounds.contains(position)) return false;
    if (hitTestChildren(result, position: position)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }

  @override
  Rect get paintBounds {
    final up = overlap.clamp(0.0, child?.size.height ?? 0.0);
    return Rect.fromLTWH(0, -up, size.width, size.height + up);
  }
}
