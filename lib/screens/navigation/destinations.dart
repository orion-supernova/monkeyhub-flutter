import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/layout.dart';

/// One destination in the shell's navigation, in nav order.
///
/// [label] is what the bottom pill and side rail print. [short] is the radial
/// menu's name for the destination — the fan is icon-only, so that string is
/// never drawn; it is what a screen reader announces for the orb.
typedef NavDest = ({
  HomeSection section,
  IconData icon,
  String label,
  String short,
});

/// The single source of truth for what the shell navigates between.
///
/// The bottom pill, the side rail, the radial menu and the settings previews
/// all read this list. They used to each hardcode their own copy — the pill
/// went so far as to keep a `_sections` list for its indicator math *and* a
/// literal row of three buttons, which is two lists that could silently
/// disagree, and the settings previews drew a hardcoded three either way.
///
/// Ordering matters: the pill's sliding indicator and the radial fan both
/// derive their geometry from a destination's index here.
/// Bottom padding every scrolling section needs so its last row clears the
/// floating nav pill.
///
/// The pill sits at `bottom: 12` inside its own SafeArea, and a section's own
/// SafeArea has already excluded the same bottom inset — so from a section's
/// point of view the pill's top edge is 12 + its height above the bottom. The
/// stacked four-item pill is ~60pt tall (6 + 6 padding, 22 icon, 2 gap, ~12
/// label, 6 + 6 padding), so 72pt is the floor and this leaves ~38pt of air.
///
/// A constant because four screens each hardcoded their own number and they had
/// already drifted: Feed was still on 80 from the three-item era, which cleared
/// the old 46pt pill by 34pt and its successor by 1pt. The arithmetic above had
/// drifted too, so `pill_bottom_nav_layout_test.dart` now measures the real bar
/// against this number rather than trusting a comment.
const double kFloatingNavClearance = 110;

/// Bottom padding a scrolling section needs at the current window class.
///
/// [kFloatingNavClearance] only means something in the phone shell, where the
/// pill floats over the bottom of the content. The split shell (see
/// [LayoutX.usesSplitShell]) swaps it for a persistent side rail that sits
/// beside the content rather than over it, so the same clearance there was
/// just 110pt of dead air under the last row — use a plain footer gap instead,
/// matching the screens (Discover's full-list pages, the games hub, …) that
/// never had a floating nav to clear in the first place.
///
/// Keyed off the shell rather than the window class: a tablet's medium window
/// still has the floating pill, and a desktop's medium window does not.
///
/// Plus whatever of the bottom inset the pill has to climb over beyond the
/// indicator — nothing on a gesture phone, the whole button bar on Android's
/// 3-button navigation. The pill rises by exactly that much (see
/// [navBottomKeepOut]), so a fixed clearance left the last row behind it.
double sectionBottomPadding(BuildContext context) {
  if (context.usesSplitShell) return 40;
  final inset = MediaQuery.viewPaddingOf(context).bottom;
  final extra = navBottomKeepOut(inset) - kIndicatorKeepOut;
  return kFloatingNavClearance + (extra > 0 ? extra : 0);
}

/// How much of the bottom inset the home indicator itself actually claims.
///
/// The inset a phone reports (34pt on a modern iPhone, ~24 for Android's
/// gesture bar) is not the size of the thing that must not be covered — it is
/// comfortable padding around a thin glyph near the edge. Floating chrome is
/// meant to live inside it; a full-width tab bar is the shape that fills it.
/// This is the part that is genuinely spoken for, and everything above it is
/// the designer's to spend.
const double kIndicatorKeepOut = 12;

/// The tallest bottom inset Android reports for gesture navigation.
///
/// The gesture handle's inset is 16–24dp across OEMs; 2- and 3-button
/// navigation is 48dp, as is a pinned taskbar. Nothing ships in between, so
/// anything above this is a bar of buttons rather than a handle.
const double kGestureInsetMax = 32;

/// How far above the screen's bottom edge floating nav chrome must start.
///
/// [inset] is the physical bottom inset (`viewPadding`, not `padding`). A
/// gesture handle — every iPhone, Android's gesture navigation — only claims
/// [kIndicatorKeepOut] of it. Android's button navigation is the opposite:
/// opaque buttons filling the entire inset, which edge-to-edge (forced at
/// targetSdk 35+) draws the app under. Floating 12pt into that put the pill
/// on top of back/home/recents, so there the whole inset is spoken for.
double navBottomKeepOut(double inset) {
  if (inset <= 0) return 0;
  final buttons = defaultTargetPlatform == TargetPlatform.android &&
      inset > kGestureInsetMax;
  return buttons ? inset : kIndicatorKeepOut;
}

/// Horizontal alignment of the bottom nav's sliding indicator over segment
/// [index] of [count], on [Alignment]'s -1..1 x axis.
///
/// Pulled out of the nav widget so it can be checked directly. It was written
/// inline as `-1 + i * 1.0`, which is this formula with `count == 3` baked in —
/// a fourth destination yielded +2.0 and threw the indicator a half-segment
/// past the right edge of the pill, with nothing to catch it.
///
/// Returns centre for an unknown segment ([index] < 0), matching the widget's
/// `indexWhere` miss.
double segmentAlignmentX(int index, int count) {
  if (count <= 1 || index < 0) return 0;
  return segmentAlignmentAt(index.toDouble(), count);
}

/// [segmentAlignmentX] for a *fractional* segment.
///
/// The indicator no longer steps from one segment to the next; it is driven by
/// a spring and by the finger during a drag, so it spends most of its life
/// between two segments. [position] is in segment-index space and may sit
/// slightly outside `0..count-1` while the pill rubber-bands past an end.
double segmentAlignmentAt(double position, int count) {
  if (count <= 1) return 0;
  return -1 + position * (2 / (count - 1));
}

/// Nav order, independent of localization.
///
/// [navDestinations] is built from this, so a destination's index here is the
/// index the bottom pill's indicator, the side rail and the radial fan all
/// derive their geometry from. Separate from that list because the index is
/// needed in places that have no [AppLocalizations] to hand — the pill's
/// `didUpdateWidget`, and the shell deciding which way a section transition
/// should travel.
const List<HomeSection> navOrder = [
  HomeSection.chat,
  HomeSection.feed,
  HomeSection.discover,
  HomeSection.settings,
];

/// Where [s] sits in [navOrder]. Never -1: every [HomeSection] is a nav
/// destination.
int navIndexOf(HomeSection s) => navOrder.indexOf(s);

/// Localized per call — [label]/[short] can't be a compile-time [const] once
/// they come from [AppLocalizations], so every caller now asks for a fresh
/// list instead of reading a top-level constant. Cheap: four small records.
///
/// Takes the resolved [AppLocalizations] rather than a BuildContext so it
/// stays plain-Dart testable without pumping a widget tree.
/// Ordered by [navOrder] rather than by a second hand-written list, so the
/// index a caller computes with [navIndexOf] and the index it finds here can
/// never disagree.
List<NavDest> navDestinations(AppLocalizations l10n) {
  return [
    for (final s in navOrder)
      switch (s) {
        HomeSection.chat => (
          section: s,
          icon: CupertinoIcons.bubble_left,
          label: l10n.destinationsChatLabel,
          short: l10n.destinationsChatShort,
        ),
        HomeSection.feed => (
          section: s,
          icon: CupertinoIcons.sparkles,
          label: l10n.destinationsFeedLabel,
          short: l10n.destinationsFeedShort,
        ),
        HomeSection.discover => (
          section: s,
          icon: CupertinoIcons.compass,
          label: l10n.destinationsDiscoverLabel,
          short: l10n.destinationsDiscoverShort,
        ),
        HomeSection.settings => (
          section: s,
          icon: CupertinoIcons.gear,
          label: l10n.destinationsSettingsLabel,
          short: l10n.destinationsSettingsShort,
        ),
      },
  ];
}
