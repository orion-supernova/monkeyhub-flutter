import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import 'approval_gate.dart';
import 'user_avatar.dart';
import 'visibility_badge.dart';

/// Someone you already know. Tapping opens (or starts) the DM.
///
/// Shared between Discover's preview and the full people list, so a row can't
/// come to mean two different things depending on where you found it.
class FriendRow extends StatelessWidget {
  const FriendRow({
    super.key,
    required this.user,
    required this.api,
    required this.onTap,
  });
  final ChatUser user;
  final ChatApi api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.childSetupScreenFriendRowMessageSemanticLabel(
          user.displayName),
      radius: theme.radiusXl,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: theme.roomCardDecoration(ephemeral: false, active: false),
          child: Row(
            children: [
              UserAvatar(user: user, size: 36, api: api),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.displaySmall.copyWith(fontSize: 16),
                    ),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.monoTiny,
                    ),
                  ],
                ),
              ),
              Icon(Icons.north_east, size: 14, color: theme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A public room you may or may not be in yet.
class PublicRoomTile extends StatelessWidget {
  const PublicRoomTile({
    super.key,
    required this.room,
    required this.onTap,
    this.awaiting = false,
    this.joined = false,
  });
  final ChatRoom room;
  final VoidCallback onTap;

  /// This child has already asked a grown-up about this room.
  final bool awaiting;

  /// The viewer is already a member, so tapping opens it rather than joining.
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: room.name,
      radius: theme.radiusXl,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: theme.roomCardDecoration(
            ephemeral: room.isEphemeral,
            active: false,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.accentSoft,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                alignment: Alignment.center,
                child: room.isEphemeral
                    ? theme.hourglassIcon(size: 14, color: theme.accent)
                    : Icon(Icons.tag, size: 14, color: theme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.displaySmall,
                    ),
                    const SizedBox(height: 2),
                    if (room.description != null &&
                        room.description!.isNotEmpty)
                      Text(
                        room.description!.toLowerCase(),
                        style: theme.bodySoft,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Worth knowing before the tap rather than at the join sheet.
              if (room.hasPassword) ...[
                const LockedBadge(dense: true, iconOnly: true),
                const SizedBox(width: 6),
              ],
              if (joined)
                const JoinedBadge(dense: true)
              else if (awaiting)
                WaitingPill(label: l10n.childSetupScreenWaitingPillAskedLabel)
              else
                VisibilityBadge(isPublic: room.isPublic, dense: true),
              const SizedBox(width: 8),
              Text('${room.memberCount}', style: theme.monoLarge),
              const SizedBox(width: 4),
              Text(l10n.childSetupScreenMemberCountUnitLabel,
                  style: theme.monoTiny),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section label with a hairline rule and a true total.
///
/// Carries no action of its own. A search glyph did briefly live here, and it
/// was too quiet to find — a full labelled row above the list does that job
/// where you can actually see it.
class DiscoverSectionHeader extends StatelessWidget {
  const DiscoverSectionHeader({
    super.key,
    required this.label,
    required this.count,
  });
  final String label;

  /// Empty string hides the number — used while a fetch is in flight, so a `0`
  /// only ever means "looked, found nothing".
  final String count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: theme.label),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: theme.divider)),
        if (count.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(count, style: theme.monoTiny),
        ],
      ],
    );
  }
}

/// The row that ends a capped preview: "see all 87".
class SeeAllRow extends StatelessWidget {
  const SeeAllRow({super.key, required this.total, required this.onTap});
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.childSetupScreenSeeAllSemanticLabel(total),
      radius: theme.radiusXl,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: theme.roomCardDecoration(ephemeral: false, active: false),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.childSetupScreenSeeAllLabel(total),
                style: theme.label.copyWith(color: theme.accent),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: theme.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// One muted line. Keeps an empty section from shoving the page around.
class DiscoverEmptyLine extends StatelessWidget {
  const DiscoverEmptyLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Text(text, style: theme.bodySoft),
    );
  }
}
