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
  });

  final RoomFilter filter;
  final RoomFacetCounts counts;
  final ValueChanged<RoomFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    // A horizontal ListView hands its children a TIGHT cross-axis constraint,
    // so this height is imposed on every chip rather than being a floor. Left
    // at a flat 34 it clipped the label at accessibility text sizes — nothing
    // in the app clamps `textScaler`. Scaling the box keeps the chips whole;
    // the cap stops a 3x setting from eating the room list.
    final scaled = MediaQuery.textScalerOf(context).scale(34).clamp(34.0, 56.0);
    return SizedBox(
      height: scaled,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? theme.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active ? theme.accent : theme.divider,
                width: active ? 1 : 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: theme.motionFast,
                  style: theme.label.copyWith(
                    color: active
                        ? theme.accentInk
                        // A facet matching nothing is dimmed rather than
                        // hidden — the row would otherwise reshuffle itself
                        // every time a room was read or archived.
                        : (empty ? theme.inkMuted : theme.inkSoft),
                  ),
                  child: Text(label),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: theme.monoTiny.copyWith(
                      color: active
                          ? theme.accentInk.withValues(alpha: 0.8)
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
