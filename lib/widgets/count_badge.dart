import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';

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
  });

  final int count;

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
        : (onAccent ? theme.accent : theme.accent.withValues(alpha: 0.28));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${mention ? '@' : ''}${count > max ? '$max+' : '$count'}',
        style: theme.monoTiny.copyWith(color: fg),
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
