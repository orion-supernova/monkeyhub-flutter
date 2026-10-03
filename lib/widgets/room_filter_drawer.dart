import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/room_filter.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';
import 'sheet_kit.dart' show sentenceCaseOf;
import 'ios_kit.dart' show groupedFill, groupedRadius, quietFill;

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
    final l10n = AppLocalizations.of(context);
    final active = filter.isNotEmpty;

    return FocusableTap(
      onTap: onTap,
      semanticLabel: active
          ? l10n.roomFilterDrawerButtonActiveSemanticLabel(
              filter.summary(l10n),
            )
          : l10n.roomFilterDrawerButtonSemanticLabel,
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
                // Filled, never outlined — the toolbar circle beside the
                // compose button.
                color: active
                    ? quietFill(theme)
                    : theme.ink.withValues(alpha: 0.07),
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: quietFill(theme),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                sentenceCaseOf(
                  context,
                  l10n.roomFilterDrawerActiveSummary(
                    matchCount,
                    filter.summary(l10n),
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _small(theme).copyWith(color: theme.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FocusableTap(
            onTap: onClear,
            semanticLabel: l10n.roomFilterDrawerClearSemanticLabel,
            shape: FocusRingShape.capsule,
            radius: 999,
            child: GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.xmark_circle_fill,
                    size: 15,
                    color: theme.inkMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    sentenceCaseOf(context, l10n.roomFilterDrawerClearLabel),
                    style: _small(theme).copyWith(color: theme.inkMuted),
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

  String _dimensionLabel(AppLocalizations l10n, FacetDimension dimension) {
    switch (dimension) {
      case FacetDimension.type:
        return l10n.roomFilterDrawerDimensionType;
      case FacetDimension.nature:
        return l10n.roomFilterDrawerDimensionNature;
      case FacetDimension.status:
        return l10n.roomFilterDrawerDimensionStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return AnimatedSize(
      duration: theme.motionMed,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                decoration: BoxDecoration(
                  color: groupedFill(theme),
                  borderRadius: BorderRadius.circular(groupedRadius(theme)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final dimension in facetDimensionOrder) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, top: 2),
                        child: Text(
                          sentenceCaseOf(
                            context,
                            _dimensionLabel(l10n, dimension),
                          ),
                          style: _small(theme).copyWith(color: theme.inkMuted),
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
                          label: l10n.roomFilterDrawerPanelClear,
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
                          label: l10n.roomFilterDrawerPanelDone,
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
    final l10n = AppLocalizations.of(context);
    // A facet nothing matches stays tappable — ticking it and seeing "0" is a
    // real answer to "do I have any locked rooms?".
    final empty = count == 0;

    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.roomFilterDrawerFacetSemanticLabel(
        count,
        facet.label(l10n),
      ),
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
                  child: Text(sentenceCaseOf(context, facet.label(l10n))),
                ),
              ),
              Text(
                '$count',
                style: _small(theme).copyWith(
                  color: empty
                      ? theme.inkMuted.withValues(alpha: 0.6)
                      : theme.inkMuted,
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

  /// The iOS multi-select circle: an empty ring, or a filled disc whose
  /// checkmark springs in.
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedContainer(
      duration: theme.motionFast,
      curve: Curves.easeOutCubic,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? theme.accent : Colors.transparent,
        border: selected
            ? null
            : Border.all(
                color: theme.inkMuted.withValues(alpha: 0.55),
                width: 1.5,
              ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: MotionScope.of(context).d(const Duration(milliseconds: 380)),
        curve: selected ? Curves.elasticOut : Curves.easeIn,
        child: Icon(
          CupertinoIcons.checkmark_alt,
          size: 15,
          color: theme.accentInk,
        ),
      ),
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
        // Capsules: the commit filled, the secondary a soft tint.
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: filled
                ? theme.bubbleFill(isMine: true)
                : theme.ink.withValues(alpha: disabled ? 0.04 : 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            sentenceCaseOf(context, label),
            style: theme.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Text(
            sentenceCaseOf(
              context,
              l10n.roomFilterDrawerEmptyStateTitle(filter.summary(l10n)),
            ),
            style: theme.bodySoft.copyWith(color: theme.inkMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FocusableTap(
            onTap: onClear,
            semanticLabel: l10n.roomFilterDrawerShowAllSemanticLabel(total),
            radius: theme.radiusMd,
            child: GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: quietFill(theme),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sentenceCaseOf(context, l10n.roomFilterDrawerShowAllLabel(total)),
                  style: theme.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footnote-size text in the theme's body face, tabular figures for counts.
TextStyle _small(AppTheme theme) => theme.bodySoft.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
