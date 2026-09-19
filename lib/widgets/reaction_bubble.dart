import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message_reaction.dart';
import '../theme/app_theme.dart';
import '../theme/interaction.dart';
import '../theme/theme_scope.dart';

class ReactionRow extends StatelessWidget {
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

  /// Long-press a chip to find out who is behind it. Free gesture: the chip's
  /// recognizer is a descendant of the bubble's, so this never competes with
  /// the message action menu.
  final void Function(String emoji)? onShowReactors;

  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);

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
        alignment: alignment,
        children: [
          for (final entry in groups.entries)
            _ReactionChip(
              emoji: entry.key,
              count: entry.value.length,
              mine: entry.value.any((r) => r.userId == currentUserId),
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle(entry.key);
              },
              onLongPress: onShowReactors == null
                  ? null
                  : () => onShowReactors!(entry.key),
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
    required this.onLongPress,
    required this.theme,
  });
  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (instance) => instance
            ..onTap = onTap
            // Desktop/trackpad right-click reaches the same list, matching
            // how the bubble already treats a secondary tap as a long-press.
            ..onSecondaryTap = onLongPress,
        ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: kReactorsLongPress),
          (instance) => instance.onLongPress = onLongPress,
        ),
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: mine ? theme.accent.withValues(alpha: 0.18) : theme.surfaceRaised,
          border: Border.all(
              color: mine ? theme.accent.withValues(alpha: 0.6) : theme.divider,
              width: 0.8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text('$count',
                style: theme.monoTiny.copyWith(
                    color: mine ? theme.accent : theme.inkSoft)),
          ],
        ),
      ),
    );
  }
}
