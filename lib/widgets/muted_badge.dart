import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'visibility_badge.dart';

/// Marks a chat this viewer has silenced.
///
/// Per-viewer state (roomMembers.muteNotifications / .muteBadges), like
/// [PinnedBadge] beside it, so it never appears for anyone but the person who
/// muted the room.
///
/// Drawn in [theme.inkMuted] rather than the accent every other room pill uses,
/// and that is the point rather than a shortcut. `PINNED`, `LOCKED` and the
/// ephemeral hourglass are all announcements — they exist to catch an eye. This
/// one says the row has been told to stop asking for attention, so a pill that
/// glows would be arguing with itself. Muted is the only state in the list
/// where the correct visual weight is "less".
///
/// [silencesCounts] picks which sentence the pill gives back on tap. The two
/// switches produce genuinely different situations — one room still climbs an
/// unread count you can see, the other has vanished from every number in the
/// app — and a single "Muted" tooltip would leave the user to guess which one
/// they picked a week ago.
class MutedBadge extends StatelessWidget {
  const MutedBadge({
    super.key,
    required this.silencesNotifications,
    required this.silencesCounts,
    this.dense = false,
    this.iconOnly = false,
    this.explainOnTap = true,
  });

  final bool silencesNotifications;
  final bool silencesCounts;
  final bool dense;
  final bool iconOnly;
  final bool explainOnTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    // The same three sentences the mute sheet uses to describe the combination
    // being built. Sharing them is what stops the sheet promising one thing and
    // the pill later claiming another.
    final tooltip = silencesNotifications && silencesCounts
        ? l10n.muteSummaryAll
        : silencesCounts
            ? l10n.muteSummaryBadgesOnly
            : l10n.muteSummaryNotificationsOnly;
    return RoomBadge(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      icon: (size) => Icon(
        CupertinoIcons.bell_slash_fill,
        size: size,
        color: theme.inkMuted,
      ),
      label: l10n.mutedBadgeLabel,
      tooltip: tooltip,
      decoration: theme.chipDecoration(filled: false),
      textStyle: theme.monoTiny.copyWith(color: theme.inkMuted),
    );
  }
}
