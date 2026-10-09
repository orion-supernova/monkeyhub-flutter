import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/room_filter.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../l10n/text_case.dart';
import 'filter_capsule.dart';
import 'desktop_scroll.dart';

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
      child: HorizontalWheelScroll(
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterCapsule(
          label: sentenceCaseOf(context, label),
          active: active,
          onTap: onTap,
          count: count,
          semanticLabel: count == null
              ? label
              : AppLocalizations.of(
                  context,
                ).roomFilterBarChipCountSemanticLabel(count!, label),
        ),
      );
}
