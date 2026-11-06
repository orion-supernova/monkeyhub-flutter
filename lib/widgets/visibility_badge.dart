import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'status_pill.dart';

/// Says whether a room is open to everyone or invite-only.
///
/// Not meant for DMs: "private" is the only thing a one-to-one conversation
/// could be, so the pill there is a word that tells you nothing. Callers with
/// a DM in hand leave it off entirely rather than pass a flag.
class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({
    super.key,
    required this.isPublic,
    this.dense = false,
    this.invert = false,
    this.iconOnly = false,
    this.explainOnTap = true,
  });

  final bool isPublic;
  final bool dense;
  final bool invert;
  final bool iconOnly;
  final bool explainOnTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return StatusPill(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      dropLabelWhenTight: true,
      surface: invert ? StatusSurface.media : StatusSurface.page,
      iconWidget: (size, _) =>
          theme.visibilityIcon(isPublic: isPublic, size: size),
      label: isPublic
          ? loc.enterPublicRoomVisibilityPublicLabel
          : loc.enterPublicRoomVisibilityPrivateLabel,
      tooltip: isPublic
          ? loc.roomBadgePublicTooltip
          : loc.roomBadgePrivateTooltip,
      tone: StatusTone.soft,
    );
  }
}

/// Says a room won't let you in without its password.
///
/// Worth knowing before the tap, not after: the join sheet is where a locked
/// room used to first admit it wanted a password.
class LockedBadge extends StatelessWidget {
  const LockedBadge({
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
    final loc = AppLocalizations.of(context);
    return StatusPill(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      dropLabelWhenTight: true,
      icon: CupertinoIcons.lock,
      tone: StatusTone.soft,
      labelTone: StatusTone.muted,
      label: loc.roomCardLockedBadge,
      tooltip: loc.roomBadgeLockedTooltip,
    );
  }
}

/// Marks a room in Discover/search that the viewer is already a member of.
///
/// Sits in the same slot as [VisibilityBadge] and replaces it: once you're in a
/// room, whether it's public is no longer the useful thing to say about it —
/// that you can just walk in is. Filled rather than outlined so the "already
/// yours" tiles read as a distinct group at a glance.
class JoinedBadge extends StatelessWidget {
  const JoinedBadge({
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
    final loc = AppLocalizations.of(context);
    return StatusPill(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      dropLabelWhenTight: true,
      icon: CupertinoIcons.checkmark_alt,
      tone: StatusTone.accent,
      fill: StatusFill.quiet,
      label: loc.enterPublicRoomJoinedBadgeLabel,
      tooltip: loc.roomBadgeJoinedTooltip,
    );
  }
}

/// The shortest honest form of a self-destruct interval: `45s`, `5m`, `2h`.
///
/// Lives here rather than on [EphemeralBadge] because the room info sheet says
/// the same interval in a longer sentence, and the pill and the sentence
/// disagreeing about how long a room keeps its messages would be worse than
/// either being terse.
String ephemeralShort(AppLocalizations loc, Duration ttl) {
  final s = ttl.inSeconds;
  if (s < 60) return loc.enterPublicRoomEphemeralSecondsShort(s);
  if (s < 3600) return loc.enterPublicRoomEphemeralMinutesShort((s / 60).round());
  return loc.enterPublicRoomEphemeralHoursShort((s / 3600).round());
}

/// Marks a room whose messages delete themselves, and after how long.
///
/// The duration is the whole point of the badge, so when the pill goes
/// icon-only the tooltip has to keep it — an hourglass alone says "not
/// forever" without saying when.
class EphemeralBadge extends StatelessWidget {
  const EphemeralBadge({
    super.key,
    required this.ttl,
    this.dense = false,
    this.iconOnly = false,
    this.explainOnTap = true,
  });

  final Duration ttl;
  final bool dense;
  final bool iconOnly;
  final bool explainOnTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final ttlLabel = ephemeralShort(loc, ttl);
    return StatusPill(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      dropLabelWhenTight: true,
      iconWidget: (size, color) => theme.hourglassIcon(size: size, color: color),
      tone: StatusTone.accent,
      outlineAlpha: 0.55,
      label: dense
          ? ttlLabel
          : loc.enterPublicRoomEphemeralBadgeLabel(ttlLabel),
      tooltip: loc.roomBadgeEphemeralTooltip(ttlLabel),
    );
  }
}
