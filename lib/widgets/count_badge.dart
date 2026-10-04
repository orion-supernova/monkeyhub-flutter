import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import '../l10n/generated/app_localizations.dart';
import 'odometer_number.dart';
import 'ios_kit.dart' show groupedMetaStyle, quietFill;

double _badgeContrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la < lb ? la : lb) + 0.05);
}

/// The small accent pill that carries a pending count.
///
/// Matches the badge treatment already used inside [PillNav] — that one stays
/// hand-rolled because its colours animate with the sliding active indicator,
/// which this doesn't need. Everywhere else should use this so the shape and
/// weight stay identical across the app.
///
/// Renders nothing at all when [count] is zero: a badge showing "0" is worse
/// than no badge, because it reads as something needing attention.
class CountBadge extends StatelessWidget {
  const CountBadge({
    super.key,
    required this.count,
    this.onAccent = false,
    this.max = 99,
    this.mention = false,
  }) : tab = false;

  /// THE tab-bar badge: a solid danger capsule, white 13/w600 tabular digits
  /// in the system face whatever the theme — the iOS tab badge, which reads
  /// the same on every theme because it belongs to the chrome, not the page.
  const CountBadge.tab({super.key, required this.count, this.max = 99})
    : onAccent = false,
      mention = false,
      tab = true;

  final int count;

  /// The tab-bar style (see [CountBadge.tab]).
  final bool tab;

  /// True when at least one of the counted messages named this user with an
  /// `@`. The pill fills in and grows an `@` in front of the number.
  ///
  /// A count says "there is traffic in here"; this says "some of it is
  /// yours" — a difference worth more than a slightly louder number, so it is
  /// carried by the badge itself and not by the two call sites, which would
  /// otherwise be free to drift apart.
  final bool mention;

  /// True when the badge sits on top of an accent-filled surface, so it
  /// needs to invert rather than blend into it.
  final bool onAccent;

  /// Counts above this render as "N+" — a parent doesn't need the exact
  /// number once it's this far past "deal with it".
  final int max;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    final digits = count > max ? '$max+' : '$count';
    if (tab) {
      return Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6),

        decoration: BoxDecoration(
          color: theme.danger,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Text(
            digits,
            // Fixed system face on purpose (the one exception to "the theme's
            // body face"): a badge is OS chrome, and a display serif or a mono
            // makes "3" read as decoration.
            style: const TextStyle(
              fontFamily: 'CupertinoSystemText',
              fontSize: 13,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFFFFF),
              decoration: TextDecoration.none,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }
    // Filled rather than tinted when you were named. The tinted pill has to
    // stay quiet enough to sit beside a dozen others in a room list; a mention
    // is the one that has earned the right to be read first.
    // On an accent surface the badge fills solid rather than tinting.
    //
    // A tint only reads against a plain surface. Sitting on the nav bar's
    // selected pill — itself accent at 0.16 over glass — an 18% wash of
    // accentInk had almost nothing to separate it from its background, so the
    // count all but vanished on the one tab most likely to be carrying one.
    // Filling with the accent puts a solid shape on a translucent one.
    // On unselected tabs the badge needs more visibility than a 0.16 tint
    // offers, especially on small tabbar items. Bumped to 0.28 to stay visible
    // without overwhelming the tab's icon.
    final fg = mention
        ? (onAccent ? theme.accent : theme.accentInk)
        : (onAccent ? theme.accentInk : theme.accent);
    final bg = mention
        ? (onAccent ? theme.accentInk : theme.accent)
        // Off an accent surface: a neutral quiet fill with the number in the
        // accent. A 28% accent wash read as a navy pill on a dark page.
        : (onAccent ? theme.accent : quietFill(theme));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      constraints: const BoxConstraints(minWidth: 20),

      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          '${mention ? '@' : ''}$digits',
          // Meta on the body face with tabular digits — never the mono slot,
          // which on a character theme set the count in tracked typewriter.
          style: groupedMetaStyle(theme).copyWith(
            color: fg,
            fontWeight: FontWeight.w600,
            height: 1.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// A tiny accent dot for surfaces too cramped for a number — the radial menu
/// orb, where a two-digit pill would collide with the icon.
class DotBadge extends StatelessWidget {
  const DotBadge({super.key, required this.show, this.size = 7});

  final bool show;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.accent,
        shape: BoxShape.circle,
        border: Border.all(color: theme.background, width: 1.5),
      ),
    );
  }
}

/// The conversation counter: a soft capsule rather than a bright notification
/// disc. Shared by the list, cards and grid; mentions carry an @ in the same
/// capsule, and an unread room without a count gets a quiet short dash.
class RoomUnreadBadge extends StatelessWidget {
  const RoomUnreadBadge({
    super.key,
    this.count = 0,
    this.unread = false,
    this.mention = false,
    this.quiet = false,
  });

  final int count;
  final bool unread;
  final bool mention;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && !unread) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    final tint = quiet ? theme.inkMuted : theme.accent;
    final fill = Color.alphaBlend(
      tint.withValues(alpha: quiet ? 0.10 : (mention ? 0.22 : 0.12)),
      theme.surface,
    );
    final preferred = quiet ? theme.inkSoft : theme.accent;
    // Accent colours are palette highlights, not guaranteed text colours.
    // Rose and the character themes need the same readable small digits.
    final ink = _badgeContrast(preferred, fill) >= 4.5
        ? preferred
        : (_badgeContrast(theme.ink, fill) >= 4.5
              ? theme.ink
              : (fill.computeLuminance() > 0.179
                    ? Colors.black
                    : Colors.white));
    final numbered = count > 0;
    final label = count > 99 ? '99+' : '$count';
    final style = groupedMetaStyle(theme).copyWith(
      fontSize: 12,
      height: 1,
      letterSpacing: 0,
      fontWeight: FontWeight.w600,
      color: ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Semantics(
      label: numbered
          ? '${mention ? '@ ' : ''}$label'
          : AppLocalizations.of(context).roomFacetLabelUnread,
      excludeSemantics: true,
      child: Container(
        constraints: BoxConstraints(minWidth: numbered ? 28 : 16),
        height: numbered ? 22 : 8,
        padding: EdgeInsets.symmetric(horizontal: numbered ? 7 : 0),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(numbered ? 8 : 4),
          border: Border.all(
            color: tint.withValues(alpha: quiet ? 0.14 : 0.24),
          ),
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: !numbered
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mention) ...[
                      Text('@', style: style),
                      const SizedBox(width: 3),
                    ],
                    if (count > 99)
                      Text(label, style: style)
                    else
                      OdometerNumber(value: count, style: style),
                  ],
                ),
        ),
      ),
    );
  }
}
