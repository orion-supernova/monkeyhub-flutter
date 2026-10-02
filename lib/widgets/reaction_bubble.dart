import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
  });

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
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
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
  });
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
        decoration: BoxDecoration(
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
