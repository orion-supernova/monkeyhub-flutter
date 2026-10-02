import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/room_filter.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';

/// The always-visible control for [FilterStyle.chips].
///
/// Eight facets don't fit a phone row — let alone the 360pt column the chat
/// list occupies in the desktop two-pane — so the row scrolls. Dimension
/// separators are drawn between groups because the combination rule is
/// OR-within / AND-across, and a flat undifferentiated row would imply the
/// wrong thing.
class RoomFilterBar extends StatelessWidget {
  const RoomFilterBar({
    super.key,
    required this.filter,
    required this.counts,
    required this.onChanged,
    this.gutter = 20,
  });

  final RoomFilter filter;
  final RoomFacetCounts counts;
  final ValueChanged<RoomFilter> onChanged;

  /// The page margin the row lines up with at rest.
  ///
  /// The bar itself must be laid out full-bleed and apply this itself, rather
  /// than being handed an already-inset box: as leading and trailing scroll
  /// padding the first and last chip still start and end on the page margin,
  /// but the ones in between run to the screen edge and slide off it instead of
  /// vanishing at an invisible wall 20pt in.
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    // A horizontal ListView hands its children a TIGHT cross-axis constraint,
    // so this height is imposed on every chip rather than being a floor. Left
    // at a flat 34 it clipped the label at accessibility text sizes — nothing
    // in the app clamps `textScaler`. Scaling the box keeps the chips whole;
    // the cap stops a 3x setting from eating the room list.
    final scaled = MediaQuery.textScalerOf(context).scale(32).clamp(32.0, 56.0);
    return SizedBox(
      height: scaled,
      child: ListView(
        // The row lives inside the chat list's scroll view, so scrolling far
        // enough down unmounts it. A scroll position only survives that if it
        // has somewhere to persist to, and one without a PageStorageKey of its
        // own persists nowhere: scroll the row to a later facet, scroll the
        // chats past it, come back, and the row had silently rewound to the
        // start.
        key: const PageStorageKey('room_filter_bar'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        physics: const BouncingScrollPhysics(),
        children: [
          // 'all' is a reset, not a facet — it reads active precisely when
          // nothing else is, so the row always has exactly one obvious
          // way back to the unfiltered list.
          _Chip(
            label: l10n.roomFilterBarAllChipLabel,
            active: filter.isEmpty,
            onTap: filter.isEmpty
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onChanged(RoomFilter.empty);
                  },
          ),
          for (final dimension in facetDimensionOrder) ...[
            _Separator(color: theme.divider),
            for (final facet in RoomFacet.values.where(
              (f) => f.dimension == dimension,
            ))
              _Chip(
                label: facet.label(l10n),
                count: counts[facet],
                active: filter.has(facet),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(filter.toggle(facet));
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 0.5,
    height: 16,
    color: color,
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
  );
}

/// The facet labels are authored lower-case for the old letter-spaced chips;
/// the filled capsules read in sentence case.
String _sentence(String s) => s.isEmpty
    ? s
    : s.characters.first.toUpperCase() + s.characters.skip(1).toString();

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  /// Null on the 'all' chip, which counts nothing.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final empty = count == 0;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: count == null
            ? label
            : AppLocalizations.of(
                context,
              ).roomFilterBarChipCountSemanticLabel(count!, label),
        selected: active,
        shape: FocusRingShape.capsule,
        radius: 999,
        inset: 2,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: theme.motionFast,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            // Soft filled capsules with no outline, the iOS 26 filter-chip
            // treatment (Mail, WhatsApp). A hairline-bordered pill on a dark
            // page is a Material chip; a tinted fill is a control.
            decoration: BoxDecoration(
              color: active
                  ? theme.accent.withValues(alpha: 0.18)
                  : theme.ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: theme.motionFast,
                  style: theme.bodySoft.copyWith(
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.2,
                    color: active
                        ? theme.accent
                        // A facet matching nothing is dimmed rather than
                        // hidden — the row would otherwise reshuffle itself
                        // every time a room was read or archived.
                        : (empty ? theme.inkMuted : theme.inkSoft),
                  ),
                  child: Text(_sentence(label)),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: theme.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: active
                          ? theme.accent.withValues(alpha: 0.75)
                          : theme.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
