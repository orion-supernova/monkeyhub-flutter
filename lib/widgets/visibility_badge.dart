import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';

class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({
    super.key,
    required this.isPublic,
    this.dense = false,
    this.invert = false,
  });

  final bool isPublic;
  final bool dense;
  final bool invert;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final label = isPublic
        ? loc.enterPublicRoomVisibilityPublicLabel
        : loc.enterPublicRoomVisibilityPrivateLabel;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: dense ? 3 : 5),
      decoration: theme.chipDecoration(filled: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          theme.visibilityIcon(isPublic: isPublic, size: dense ? 10 : 12),
          SizedBox(width: dense ? 4 : 6),
          Text(label, style: theme.monoTiny.copyWith(color: invert ? theme.background : theme.inkSoft)),
        ],
      ),
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
  const JoinedBadge({super.key, this.dense = false});
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: theme.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.32),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: dense ? 10 : 12, color: theme.accent),
          SizedBox(width: dense ? 4 : 6),
          Text(
            AppLocalizations.of(context).enterPublicRoomJoinedBadgeLabel,
            style: theme.monoTiny.copyWith(color: theme.accent),
          ),
        ],
      ),
    );
  }
}

class EphemeralBadge extends StatelessWidget {
  const EphemeralBadge({super.key, required this.ttl, this.dense = false});
  final Duration ttl;
  final bool dense;

  String _fmt(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final s = ttl.inSeconds;
    if (s < 60) return loc.enterPublicRoomEphemeralSecondsShort(s);
    if (s < 3600) {
      return loc.enterPublicRoomEphemeralMinutesShort((s / 60).round());
    }
    return loc.enterPublicRoomEphemeralHoursShort((s / 3600).round());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 10, vertical: dense ? 3 : 5),
      decoration: theme.chipDecoration(filled: false).copyWith(
            border: Border.all(color: theme.accent.withValues(alpha: 0.55), width: 1),
          ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          theme.hourglassIcon(size: dense ? 10 : 12, color: theme.accent),
          SizedBox(width: dense ? 4 : 6),
          Text(
            dense
                ? _fmt(context)
                : loc.enterPublicRoomEphemeralBadgeLabel(_fmt(context)),
            style: theme.monoTiny.copyWith(color: theme.accent),
          ),
        ],
      ),
    );
  }
}
