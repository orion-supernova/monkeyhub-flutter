import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import 'status_pill.dart';

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
    final l10n = AppLocalizations.of(context);
    return StatusPill(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      dropLabelWhenTight: true,
      icon: CupertinoIcons.pin_fill,
      tone: StatusTone.accent,
      outlineAlpha: 0.55,
      label: l10n.pinnedBadgeLabel,
      tooltip: l10n.pinnedBadgeLabel,
    );
  }
}
