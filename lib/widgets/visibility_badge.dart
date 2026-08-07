import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';

/// One pill: a small icon, a short label, a rounded chip around both.
///
/// The label is the first thing to go when the pill is squeezed. A grid tile
/// can hand the badge slot less than 90px, and a translated label runs well
/// past that ("HERKESE AÇIK" needs ~104px), so the pill measures its label
/// against the space it was actually given and falls back to the icon alone
/// rather than overflowing or ellipsing two words into noise. The words stay
/// available to screen readers either way.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.decoration,
    required this.textStyle,
    required this.dense,
  });

  /// Built by the caller at the size the badge asks for.
  final Widget Function(double size) icon;
  final String label;
  final BoxDecoration decoration;
  final TextStyle textStyle;
  final bool dense;

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
    final iconSize = dense ? 10.0 : 12.0;
    final gap = dense ? 4.0 : 6.0;
    final padding = EdgeInsets.symmetric(
      horizontal: dense ? 6 : 10,
      vertical: dense ? 3 : 5,
    );
    final chromeWidth =
        padding.horizontal + _borderWidth * 2 + iconSize + gap;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabel =
            _labelFits(context, constraints.maxWidth, chromeWidth);
        return Semantics(
          label: showLabel ? null : label,
          container: !showLabel,
          child: Container(
            padding: padding,
            decoration: decoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon(iconSize),
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
  }
}

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
    return _Badge(
      dense: dense,
      icon: (size) => theme.visibilityIcon(isPublic: isPublic, size: size),
      label: isPublic
          ? loc.enterPublicRoomVisibilityPublicLabel
          : loc.enterPublicRoomVisibilityPrivateLabel,
      decoration: theme.chipDecoration(filled: false),
      textStyle: theme.monoTiny
          .copyWith(color: invert ? theme.background : theme.inkSoft),
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
    return _Badge(
      dense: dense,
      icon: (size) =>
          Icon(Icons.check_rounded, size: size, color: theme.accent),
      label: AppLocalizations.of(context).enterPublicRoomJoinedBadgeLabel,
      decoration: BoxDecoration(
        color: theme.accentSoft,
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
    return _Badge(
      dense: dense,
      icon: (size) => theme.hourglassIcon(size: size, color: theme.accent),
      label: dense
          ? _fmt(context)
          : loc.enterPublicRoomEphemeralBadgeLabel(_fmt(context)),
      decoration: theme.chipDecoration(filled: false).copyWith(
            border:
                Border.all(color: theme.accent.withValues(alpha: 0.55), width: 1),
          ),
      textStyle: theme.monoTiny.copyWith(color: theme.accent),
    );
  }
}
