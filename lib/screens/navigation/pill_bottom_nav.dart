import 'package:flutter/material.dart';

import '../../data/glass_config.dart';
import '../../data/settings_store.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/count_badge.dart';
import '../../widgets/liquid_glass.dart';
import 'destinations.dart';

/// The floating bottom nav, stacked icon-over-label.
///
/// Went stacked when a fourth destination arrived: at four segments a 375pt
/// phone gives each item ~82pt, and after padding the side-by-side layout left
/// ~40pt for a label needing ~45pt, so "Settings" and "Discover" both
/// ellipsised — and worse once a badge appeared. Stacking also brings this into
/// line with the side rail, which was already icon-over-label, so compact and
/// expanded windows finally read as the same design.
///
/// Returns a [Positioned], so it must be placed directly in a [Stack].
///
/// Lives in its own file, and public, so a widget test can pump it. As a
/// private class inside the shell it was unreachable from `test/`, which is
/// exactly why a uniform 13.875pt horizontal offset on every segment shipped
/// unnoticed — see `test/pill_bottom_nav_layout_test.dart`.
class PillBottomNav extends StatelessWidget {
  const PillBottomNav({
    super.key,
    required this.active,
    required this.onSelect,
    required this.badges,
    this.profile,
  });
  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;

  /// Glass and layout to render with. Null — the shell — reads the live
  /// settings. The tuning screen passes an interpolated profile so the bar
  /// eases between looks instead of snapping.
  final GlassProfile? profile;

  /// Per-destination badge counts. Was a pair of named `chatBadge` /
  /// `settingsBadge` fields, which meant every new destination wanting a badge
  /// cost another constructor parameter.
  final Map<HomeSection, int> badges;

  /// Where the indicator rests over segment [s].
  ///
  /// [AlignmentDirectional], not [Alignment]: the [Row] below mirrors under
  /// RTL — destination 0 renders on the right — but an absolute alignment does
  /// not, so the indicator used to land on the mirrored segment. Directional on
  /// both sides keeps them in step, and reads the same in LTR.
  AlignmentGeometry _alignmentFor(List<NavDest> destinations, HomeSection s) =>
      AlignmentDirectional(
        segmentAlignmentX(
          destinations.indexWhere((d) => d.section == s),
          destinations.length,
        ),
        0,
      );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final destinations = navDestinations(AppLocalizations.of(context));
    final profile = this.profile ?? SettingsStore.instance.glass;
    final geo = profile.geometry;
    final margin = geo.of(kBarMargin);
    return Positioned(
      left: margin,
      right: margin,
      bottom: geo.of(kBarBottom),
      // Bottom only. SafeArea defaults to all four sides, and the status-bar
      // inset is still in MediaQuery down here, so the default was padding ~44pt
      // of dead space onto the top of a bottom-anchored bar.
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        // The app's own glass recipe rather than a hand-rolled ClipRRect +
        // BackdropFilter + Container, which is what this was and which had
        // drifted: it drew a flat 0.72 surface with no sheen while every other
        // floating surface in the app had one, and its solo BackdropFilter
        // could not join the shared rasterization pass that
        // BackdropFilter.grouped gives the rest.
        //
        // A capsule, reversing an earlier call to make it a rounded rectangle.
        // That call was right about the symptom — `circular(999)` on a 335x63
        // shell clamps into barrel ends — but treated it as a shape problem
        // when it was a height problem. Trimming the segment to 48pt puts the
        // shell at 60pt, where a true StadiumBorder is the iOS tab bar it was
        // always imitating.
        // Its own glass config, separate from every other surface's: this is
        // the one that sits over moving content for its whole life, so a
        // tuning that reads well here as a lens is usually too thin for a
        // composer or a header with text directly behind it.
        child: LiquidGlass(
          shape: LiquidGlassShape.capsule,
          padding: EdgeInsets.symmetric(
            horizontal: geo.of(kShellPadH),
            vertical: geo.of(kShellPadV),
          ),
          config: profile.nav,
          child: Stack(
            children: [
              // Sliding accent indicator behind the active segment.
              Positioned.fill(
                child: AnimatedAlign(
                  duration: theme.motionFast,
                  curve: Curves.easeOutCubic,
                  alignment: _alignmentFor(destinations, active),
                  child: FractionallySizedBox(
                    widthFactor: 1 / destinations.length,
                    heightFactor: 1,
                    // The slot stays a full segment wide — that is what
                    // segmentAlignmentX positions, and what the tests measure
                    // against — and only the painted pill is inset within it.
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: geo.of(kIndicatorInset),
                      ),
                      child: const _Indicator(),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final d in destinations)
                    _btn(
                      theme,
                      geo,
                      d.icon,
                      d.label,
                      d.section,
                      badge: badges[d.section] ?? 0,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(
    AppTheme theme,
    GlassConfig geo,
    IconData icon,
    String label,
    HomeSection s, {
    int badge = 0,
  }) {
    final isActive = s == active;
    final iconSize = geo.of(kIconSize);
    return Expanded(
      child: FocusableTap(
        onTap: () => onSelect(s),
        semanticLabel: label,
        // Matches the indicator behind it.
        shape: FocusRingShape.capsule,
        child: GestureDetector(
          onTap: () => onSelect(s),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            // Wider than the indicator's own inset, so the width a long label
            // ellipsizes at stays inside the painted pill rather than running
            // out to its edge.
            padding: EdgeInsets.symmetric(
              vertical: geo.of(kSegmentPadV),
              horizontal: geo.of(kIndicatorInset) + 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sized to the glyph, not past it. This was a 46pt-wide box
                // around a 22pt icon, widened purely so a `right: 0` badge had
                // somewhere to grow — which parked the badge 12pt clear of the
                // icon it counts for, and padded 24pt of nothing into the
                // middle of every segment.
                SizedBox.square(
                  dimension: iconSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: theme.motionFast,
                        style: TextStyle(
                          color: isActive ? theme.accent : theme.inkSoft,
                        ),
                        child: Builder(
                          builder: (ctx) => Icon(
                            icon,
                            size: iconSize,
                            color: DefaultTextStyle.of(ctx).style.color,
                          ),
                        ),
                      ),
                      if (badge > 0)
                        Positioned(
                          top: -6,
                          // Anchored by `left`, so the badge grows rightward
                          // out of the box. Anchoring by `right` — the obvious
                          // reading — pins its right edge and grows it
                          // LEFTWARD across the glyph instead: one digit
                          // covered the icon's right 6pt and "99+" covered 18
                          // of its 22. There is ~28pt of slack either side of
                          // the content inside a segment, so the overflow has
                          // somewhere to go.
                          left: iconSize - 9,
                          // Sits on the accent-filled sliding indicator when
                          // this segment is the active one, so it has to invert
                          // there. Hardcoding `false` painted accent@0.16 on
                          // accent@0.16 and the badge vanished on the one
                          // segment most likely to carry it.
                          child: CountBadge(count: badge, onAccent: isActive),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: geo.of(kIconLabelGap)),
                AnimatedDefaultTextStyle(
                  duration: theme.motionFast,
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontFamily: 'CupertinoSystemText',
                    fontSize: geo.of(kLabelSize),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.08,
                    color: isActive ? theme.accent : theme.inkSoft,
                  ),
                  // Still guarded: at four segments a 375pt phone leaves each
                  // label ~62pt, which fits every current destination, but a
                  // fifth one or a longer word should degrade rather than
                  // throw an overflow.
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The painted selection pill. Its parent [FractionallySizedBox] is the full
/// segment, so a test measuring the slot cannot see whether the pill inside it
/// is inset or full-bleed — which is the whole difference between a selection
/// and a slab.
@visibleForTesting
const Key navIndicatorKey = Key('pill-nav-indicator');

/// The accent pill behind the active segment. Split out only so the [Padding]
/// wrapping it can stay `const`.
class _Indicator extends StatelessWidget {
  const _Indicator();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return DecoratedBox(
      key: navIndicatorKey,
      decoration: ShapeDecoration(
        color: theme.accent.withValues(alpha: 0.16),
        shape: StadiumBorder(
          side: BorderSide(
            color: theme.accent.withValues(alpha: 0.32),
            width: 0.5,
          ),
        ),
      ),
    );
  }
}
