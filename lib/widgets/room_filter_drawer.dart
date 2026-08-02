import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/room_filter.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';

/// The header affordance for [FilterStyle.drawer].
///
/// Deliberately a fixed 36pt circle rather than growing into a summary pill:
/// the header already carries an avatar, the greeting and the create button,
/// and a variable-width control there would squeeze the greeting to an ellipsis
/// on a narrow phone — and worse in the 360pt desktop column. The summary lives
/// in [ActiveFilterCue] on its own row instead. The badge here is what makes
/// the collapsed state honest about a filter being on.
class RoomFilterButton extends StatelessWidget {
  const RoomFilterButton({
    super.key,
    required this.filter,
    required this.expanded,
    required this.onTap,
  });

  final RoomFilter filter;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final active = filter.isNotEmpty;

    return FocusableTap(
      onTap: onTap,
      semanticLabel: active
          ? 'Filtering by ${filter.summary}. Change filter'
          : 'Filter chats',
      shape: FocusRingShape.circle,
      radius: 999,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: theme.motionFast,
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? theme.accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                  color: active ? theme.accent : theme.divider,
                  width: active ? 1 : 0.5,
                ),
              ),
              child: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: theme.motionFast,
                curve: Curves.easeOutCubic,
                child: Icon(
                  expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.slider_horizontal_3,
                  size: 16,
                  color: active ? theme.accent : theme.inkSoft,
                ),
              ),
            ),
            if (active)
              Positioned(
                top: -3,
                right: -3,
                child: CountBadge(count: filter.facets.length),
              ),
          ],
        ),
      ),
    );
  }
}

/// The standing explanation for why the list below is short.
///
/// Shown by the drawer style whenever a filter is active — including on a cold
/// start, since the filter persists. Without it, relaunching into a filtered
/// list reads as lost data rather than as a setting.
class ActiveFilterCue extends StatelessWidget {
  const ActiveFilterCue({
    super.key,
    required this.filter,
    required this.matchCount,
    required this.onClear,
  });

  final RoomFilter filter;

  /// How many rooms survive the filter — the "· 0" that makes an empty list
  /// legible at a glance.
  final int matchCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${filter.summary} · $matchCount',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.label.copyWith(color: theme.accentInk),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FocusableTap(
            onTap: onClear,
            semanticLabel: 'Clear filter',
            shape: FocusRingShape.capsule,
            radius: 999,
            child: GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.xmark, size: 11, color: theme.inkMuted),
                  const SizedBox(width: 5),
                  Text(
                    'clear',
                    style: theme.label.copyWith(color: theme.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The expanding panel: every facet, grouped by dimension, with live counts.
///
/// Inline rather than a modal sheet — the room list stays visible behind it, so
/// the effect of each tick is watchable. Collapses to zero height when closed,
/// costing nothing in the resting state.
class RoomFilterPanel extends StatelessWidget {
  const RoomFilterPanel({
    super.key,
    required this.filter,
    required this.counts,
    required this.expanded,
    required this.onChanged,
    required this.onDone,
  });

  final RoomFilter filter;
  final RoomFacetCounts counts;
  final bool expanded;
  final ValueChanged<RoomFilter> onChanged;
  final VoidCallback onDone;

  static const _dimensionLabels = {
    FacetDimension.type: 'TYPE',
    FacetDimension.nature: 'NATURE',
    FacetDimension.status: 'STATUS',
  };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

    return AnimatedSize(
      duration: theme.motionMed,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  color: theme.surfaceSunken,
                  borderRadius: BorderRadius.circular(theme.radiusLg),
                  border: Border.all(color: theme.divider, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final dimension in FacetDimension.values) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, top: 2),
                        child: Text(
                          _dimensionLabels[dimension]!,
                          style: theme.monoTiny.copyWith(color: theme.inkMuted),
                        ),
                      ),
                      for (final facet in RoomFacet.values.where(
                        (f) => f.dimension == dimension,
                      ))
                        _FacetRow(
                          facet: facet,
                          selected: filter.has(facet),
                          count: counts[facet],
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onChanged(filter.toggle(facet));
                          },
                        ),
                      const SizedBox(height: 8),
                    ],
                    Divider(height: 1, thickness: 0.5, color: theme.divider),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _PanelAction(
                          label: 'CLEAR',
                          // Nothing to clear reads as disabled rather than
                          // silently doing nothing.
                          onTap: filter.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  onChanged(RoomFilter.empty);
                                },
                        ),
                        const SizedBox(width: 8),
                        _PanelAction(
                          label: 'DONE',
                          filled: true,
                          onTap: onDone,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _FacetRow extends StatelessWidget {
  const _FacetRow({
    required this.facet,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final RoomFacet facet;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // A facet nothing matches stays tappable — ticking it and seeing "0" is a
    // real answer to "do I have any locked rooms?".
    final empty = count == 0;

    return FocusableTap(
      onTap: onTap,
      semanticLabel: '${facet.label}, $count chats',
      selected: selected,
      radius: theme.radiusMd,
      inset: 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              _Tick(selected: selected),
              const SizedBox(width: 10),
              if (facet == RoomFacet.secret) ...[
                theme.hourglassIcon(size: 12, color: theme.accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: theme.motionFast,
                  style: theme.body.copyWith(
                    color: selected
                        ? theme.ink
                        : (empty ? theme.inkMuted : theme.inkSoft),
                  ),
                  child: Text(facet.label),
                ),
              ),
              Text(
                '$count',
                style: theme.mono.copyWith(
                  color: empty ? theme.inkMuted : theme.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedContainer(
      duration: theme.motionFast,
      curve: Curves.easeOutCubic,
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? theme.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(
          color: selected ? theme.accent : theme.divider,
          width: selected ? 1 : 1.2,
        ),
      ),
      child: selected
          ? Icon(CupertinoIcons.check_mark, size: 12, color: theme.accentInk)
          : null,
    );
  }
}

class _PanelAction extends StatelessWidget {
  const _PanelAction({
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final disabled = onTap == null;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: filled ? theme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(
              color: filled
                  ? theme.accent
                  : (disabled ? theme.divider : theme.inkMuted),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: theme.label.copyWith(
              color: filled
                  ? theme.accentInk
                  : (disabled ? theme.inkMuted : theme.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared by both filter styles: what the list says when a filter is on and
/// nothing matches. Distinct from "no rooms yet" — the rooms exist, they're
/// just hidden, and saying so with a one-tap way out is the whole reason a
/// persisted filter is safe to ship.
class FilteredEmptyState extends StatelessWidget {
  const FilteredEmptyState({
    super.key,
    required this.filter,
    required this.total,
    required this.onClear,
  });

  final RoomFilter filter;

  /// Unfiltered room count — named in the escape hatch so the offer is concrete.
  final int total;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            'nothing matches ${filter.summary}',
            style: theme.bodySoft,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FocusableTap(
            onTap: onClear,
            semanticLabel: 'Show all $total chats',
            radius: theme.radiusMd,
            child: GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: theme.chipDecoration(),
                child: Text(
                  'show all $total ${total == 1 ? 'chat' : 'chats'}',
                  style: theme.label.copyWith(color: theme.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
