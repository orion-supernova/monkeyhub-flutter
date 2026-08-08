import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'visibility_badge.dart';

/// Marks a chat the viewer has pinned to the top of their own chat list.
///
/// Per-viewer state (roomMembers.isPinned), not a property of the room, so
/// this never appears for anyone but the person who pinned it.
class PinnedBadge extends StatelessWidget {
  const PinnedBadge({
    super.key,
    this.dense = false,
    this.iconOnly = false,
    this.explainOnTap = true,
  });

  final bool dense;
  final bool iconOnly;
  final bool explainOnTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return RoomBadge(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      icon: (size) =>
          Icon(CupertinoIcons.pin_fill, size: size, color: theme.accent),
      label: l10n.pinnedBadgeLabel,
      tooltip: l10n.pinnedBadgeLabel,
      decoration: theme
          .chipDecoration(filled: false)
          .copyWith(
            border: Border.all(
              color: theme.accent.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
      textStyle: theme.monoTiny.copyWith(color: theme.accent),
    );
  }
}
