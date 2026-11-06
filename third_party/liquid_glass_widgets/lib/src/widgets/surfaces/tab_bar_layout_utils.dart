// Pure-Dart layout utilities shared across the bottom bar widgets.
//
// No Flutter widget imports — keep this file dependency-free so that
// SearchableBottomBarController can import it without breaking the
// "controller must be widget-free" testability constraint.
library;

import 'dart:math' as math;
import 'dart:ui' show Color;

/// The iOS 26 calibration for a bar's interaction glow, resolved when the
/// caller leaves `interactionGlowRadius` null.
///
/// These are [GlassButton]'s native-mode figures, which it has carried since
/// 1.3.0: a wide radius under a heavy Gaussian, at an alpha low enough that
/// the light washes across the surface instead of concentrating into a
/// hotspot. The bars could not reach them — their radius was non-nullable
/// with a default, so there was no null to key on.
const double kNativeTabBarGlowRadius = 1.6;

/// The blur sigma that goes with [kNativeTabBarGlowRadius]. The theme's own
/// fallback is 4, which at this radius draws a disc with a visible edge.
const double kNativeTabBarGlowBlurRadius = 16.0;

/// The native sheen, dark mode: white at ~7%.
const Color kNativeTabBarGlowColorDark = Color(0x12FFFFFF);

/// The native sheen, light mode: white at ~10%.
const Color kNativeTabBarGlowColorLight = Color(0x1AFFFFFF);

/// Resolves a bar's interaction glow from what the caller asked for and what
/// the theme offers.
///
/// A null [interactionGlowRadius] means *native mode* — take the platform
/// calibration, the same one [GlassButton] resolves from a null `glowRadius`.
/// Any explicit radius keeps the theme's palette instead, so an app that
/// tuned its glow through [GlassGlowColors] keeps exactly what it tuned.
///
/// [interactionGlowColor] always wins when given: native mode sets the
/// default sheen, it does not override a caller.
///
/// Shared by `TabBarBottomLayout` and `TabBarSearchableLayout` so the two
/// bars cannot drift apart again.
({double radius, double blurRadius, Color? color})
    resolveTabBarInteractionGlow({
  required double? interactionGlowRadius,
  required Color? interactionGlowColor,
  required Color? themeGlowColor,
  required double themeGlowBlurRadius,
  required bool isDark,
}) {
  final isNative = interactionGlowRadius == null;
  return (
    radius: interactionGlowRadius ?? kNativeTabBarGlowRadius,
    blurRadius: isNative ? kNativeTabBarGlowBlurRadius : themeGlowBlurRadius,
    color: interactionGlowColor ??
        (isNative
            ? (isDark
                ? kNativeTabBarGlowColorDark
                : kNativeTabBarGlowColorLight)
            : themeGlowColor),
  );
}

/// Resolves the effective tab pill width given a per-slot [tabWidth] and
/// the maximum space available.
///
/// - [tabWidth] `null`  → returns [maxAvailable] (expand — fills available space).

/// - [tabWidth] set     → returns `tabWidth × tabCount`, clamped to [maxAvailable].
///
/// [maxAvailable] is floored to 0 before clamping so that unusual layout
/// constraints (e.g. tightly constrained test environments or a very large
/// [extraButton]) never produce a negative clamp range, which would throw a
/// [RangeError] in Dart's [num.clamp].
///
/// This is the single authoritative implementation used by:
/// - [SearchableBottomBarController.computeLayout] (searchable bar)
/// - [GlassTabBar.bottom]'s build method (standalone bar)
///
/// Both bars share the same compact-sizing semantics: [tabWidth] controls the
/// per-tab slot width, and the total pill is bounded by the available space.
double resolveTabPillWidth({
  required double? tabWidth,
  required int tabCount,
  required double maxAvailable,
}) {
  // Guard: clamp requires min ≤ max. If an unusual constraint makes
  // maxAvailable negative (e.g. extra button wider than the bar), floor to 0
  // so we degrade gracefully instead of throwing a RangeError.
  final safeMax = math.max(0.0, maxAvailable);
  if (tabWidth == null) return safeMax;
  return (tabWidth * tabCount).clamp(0.0, safeMax);
}

/// SWIRL PATCH (vendored copy): the resting pill for a bar whose tabs are not all
/// the same width.
///
/// Upstream sizes the pill to one equal slot, `trackWidth / itemCount`, wherever
/// it is. Native iOS hugs the selected tab's content, so a short label gets a
/// narrow pill and a long one a wide pill, and the pill changes size as it
/// slides. The tab slots (and so the icons and labels) stay equal. Only the pill
/// takes [widths], in logical pixels, one per tab.
///
/// [alignmentX] is the pill's -1..1 position along the track. The width is
/// interpolated between the two tabs it sits between, and the pill stays
/// centered on that point of the track. It is slid back inside the track when it
/// is wider than its end tab's slot, so it never pokes out of the bar.
///
/// [slotPadding] is the bar's `tabPadding` on each side: the tab row is inset by
/// it, so the slots are narrower than the track and start further in. The
/// default is the package's own 4, which the track already includes.
({double left, double width}) resolveVariableTabPill({
  required double trackWidth,
  required int itemCount,
  required double alignmentX,
  required List<double> widths,
  double slotPadding = 4,
}) {
  // The track starts 4px inside the bar, the tab row starts [slotPadding] inside it.
  final rowWidth = trackWidth + 8 - 2 * slotPadding;
  final slot = rowWidth / itemCount;
  final p = itemCount <= 1 ? 0.0 : ((alignmentX + 1) / 2 * (itemCount - 1)).clamp(0.0, itemCount - 1.0);
  final i0 = p.floor().clamp(0, itemCount - 1);
  final i1 = math.min(i0 + 1, itemCount - 1);
  final width = widths[i0] + (widths[i1] - widths[i0]) * (p - i0);
  final left = (slotPadding - 4 + (p + 0.5) * slot - width / 2).clamp(0.0, math.max(0.0, trackWidth - width)).toDouble();
  return (left: left, width: width);
}
