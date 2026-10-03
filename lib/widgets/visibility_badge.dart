import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show quietFill;

/// One pill: a small icon, a short label, a rounded chip around both — and a
/// sentence, on tap, saying what the pill actually means.
///
/// Two things shrink the label. A caller can ask for [iconOnly], which is what
/// the grid tiles do: four pills of words on a tile that also has to hold a
/// name and a preview line is a wall, and the icons carry the meaning once you
/// can reach the sentence behind them. And the pill measures itself — a grid
/// slot can be under 90px, and a translated label runs well past that
/// ("HERKESE AÇIK" needs ~104px), so it drops the words rather than overflow
/// or ellipse two of them into noise.
///
/// Either way the words survive: the tap tooltip spells the state out in full,
/// and Semantics carries the label so a screen reader never meets a bare icon.
///
/// A caller whose surface already answers the question can turn the tooltip off
/// with [explainOnTap] — see the flag's own note.
class RoomBadge extends StatelessWidget {
  const RoomBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.decoration,
    required this.textStyle,
    required this.dense,
    required this.iconOnly,
    required this.explainOnTap,
  });

  /// Built by the caller at the size the badge asks for.
  final Widget Function(double size) icon;
  final String label;

  /// The sentence behind the pill — what this state means, in full.
  final String tooltip;
  final BoxDecoration decoration;
  final TextStyle textStyle;
  final bool dense;
  final bool iconOnly;

  /// Whether the pill answers for itself on tap.
  ///
  /// Off for a pill sitting inside a row that is itself one tap target — a
  /// Discover room row opens a sheet that spells every one of these states out
  /// in full sentences, so a tooltip there would only swallow the tap meant for
  /// the row and hand back less than the row was about to give. The [tooltip]
  /// sentence still reaches a screen reader either way.
  final bool explainOnTap;

  /// Themes draw the chip border anywhere from 0.5 to 1.0 wide; assume the
  /// widest so the fit check never claims room the border is using.
  static const double _borderWidth = 1;

  bool _labelFits(BuildContext context, double maxWidth, double chromeWidth) {
    if (!maxWidth.isFinite) return true;
    final painter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return chromeWidth + painter.width <= maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final gap = dense ? 4.0 : 6.0;
    // Beside a word the glyph is a bullet and stays out of the way. Alone it
    // *is* the badge — the only thing carrying the meaning until someone taps
    // it — so it grows, and the pill tightens around it into a token you can
    // actually aim at.
    final labelledIcon = dense ? 10.0 : 12.0;
    final soloIcon = dense ? 15.0 : 18.0;
    final labelledPadding = EdgeInsets.symmetric(
      horizontal: dense ? 6 : 10,
      vertical: dense ? 3 : 5,
    );
    final soloPadding = EdgeInsets.symmetric(
      horizontal: dense ? 5 : 7,
      vertical: dense ? 4 : 6,
    );
    final chromeWidth =
        labelledPadding.horizontal + _borderWidth * 2 + labelledIcon + gap;

    final pill = LayoutBuilder(
      builder: (context, constraints) {
        final showLabel =
            !iconOnly && _labelFits(context, constraints.maxWidth, chromeWidth);
        return Semantics(
          label: showLabel ? null : label,
          container: !showLabel,
          child: Container(
            padding: showLabel ? labelledPadding : soloPadding,
            decoration: decoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon(showLabel ? labelledIcon : soloIcon),
                if (showLabel) ...[
                  SizedBox(width: gap),
                  Text(label, style: textStyle, maxLines: 1, softWrap: false),
                ],
              ],
            ),
          ),
        );
      },
    );
    if (!explainOnTap) return pill;

    return Tooltip(
      message: tooltip,
      triggerMode: TooltipTriggerMode.tap,
      preferBelow: false,
      showDuration: const Duration(seconds: 3),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: theme.tooltipDecoration(),
      textStyle: theme.body.copyWith(fontSize: 12, color: theme.ink),
      child: pill,
    );
  }
}

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
    return RoomBadge(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      icon: (size) => theme.visibilityIcon(isPublic: isPublic, size: size),
      label: isPublic
          ? loc.enterPublicRoomVisibilityPublicLabel
          : loc.enterPublicRoomVisibilityPrivateLabel,
      tooltip: isPublic
          ? loc.roomBadgePublicTooltip
          : loc.roomBadgePrivateTooltip,
      decoration: theme.chipDecoration(filled: false),
      textStyle: theme.monoTiny
          .copyWith(color: invert ? theme.background : theme.inkSoft),
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
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return RoomBadge(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      icon: (size) =>
          Icon(Icons.lock_outline_rounded, size: size, color: theme.inkSoft),
      label: loc.roomCardLockedBadge,
      tooltip: loc.roomBadgeLockedTooltip,
      decoration: theme.chipDecoration(),
      textStyle: theme.monoTiny,
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
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return RoomBadge(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      icon: (size) =>
          Icon(Icons.check_rounded, size: size, color: theme.accent),
      label: loc.enterPublicRoomJoinedBadgeLabel,
      tooltip: loc.roomBadgeJoinedTooltip,
      decoration: BoxDecoration(
        color: quietFill(theme),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.32),
          width: 0.5,
        ),
      ),
      textStyle: theme.monoTiny.copyWith(color: theme.accent),
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
    return RoomBadge(
      dense: dense,
      iconOnly: iconOnly,
      explainOnTap: explainOnTap,
      icon: (size) => theme.hourglassIcon(size: size, color: theme.accent),
      label: dense
          ? ttlLabel
          : loc.enterPublicRoomEphemeralBadgeLabel(ttlLabel),
      tooltip: loc.roomBadgeEphemeralTooltip(ttlLabel),
      decoration: theme.chipDecoration(filled: false).copyWith(
            border: Border.all(
              color: theme.accent.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
      textStyle: theme.monoTiny.copyWith(color: theme.accent),
    );
  }
}
