import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';
import 'search_field.dart';

/// Lives as the first child of the chat list's [ListView]. Hidden by default;
/// pulling down at the top of the list (overscroll) reveals it — see
/// `_HomeScreenState._onScrollNotification` in home_screen.dart, which owns
/// the gesture and hands this widget a live drag distance.
///
/// The reveal tracks the finger 1:1 while dragging — [dragging] gates the
/// height change to `Duration.zero`, so every touch-move frame snaps the clip
/// straight to the new drag distance instead of animating toward it — and
/// only animates on release, either the rest of the way open or back to
/// hidden. This is what makes it read as the same gesture as Telegram/iOS
/// Mail's pull-to-search rather than a delayed pop-in: an earlier version
/// showed only a small static hint glyph during the drag and mounted the real
/// panel afterwards, which made the reveal feel like it arrived late no
/// matter how far or confidently you pulled.
class PullRevealSlot extends StatelessWidget {
  const PullRevealSlot({
    super.key,
    required this.dragExtent,
    required this.dragThreshold,
    required this.dragging,
    required this.open,
    required this.searchCtrl,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.archivedCount,
    required this.onOpenArchived,
    required this.onCollapse,
  });

  /// Live drag distance while pulling at the top, 0 when idle or settled.
  final double dragExtent;
  final double dragThreshold;

  /// True only between the first live drag sample and release. While true,
  /// height changes are instant (tracking the finger); once false, the same
  /// height change animates toward wherever it landed (open or closed).
  final bool dragging;
  final bool open;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final int archivedCount;
  final VoidCallback onOpenArchived;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final progress = open ? 1.0 : (dragExtent / dragThreshold).clamp(0.0, 1.0);
    // `Align.heightFactor` — the same mechanism SizeTransition uses — reveals
    // a fraction of whatever the panel's NATURAL height turns out to be, and
    // ClipRect hides the rest.
    //
    // This used to clip against a fixed 190pt upper bound instead, which meant
    // the open panel was always 190pt tall no matter what was in it: an
    // account with nothing archived (no folder row) got a band of dead space
    // under the search field, and so, less obviously, did every account at
    // default text scale. Measuring instead of guessing also drops the
    // "tall enough at any text scale" caveat the constant carried.
    return ClipRect(
      child: TweenAnimationBuilder<double>(
        // Same rule the constant-height version followed: instant while the
        // finger is down so the reveal tracks it, animated on release.
        duration: dragging ? Duration.zero : theme.motionMed,
        curve: Curves.easeOutCubic,
        tween: Tween<double>(end: progress),
        builder: (context, factor, child) =>
            Align(alignment: Alignment.topCenter, heightFactor: factor, child: child),
        child: _PullRevealPanel(
          searchCtrl: searchCtrl,
          searchFocus: searchFocus,
          onSearchChanged: onSearchChanged,
          onClear: onClearSearch,
          archivedCount: archivedCount,
          onOpenArchived: onOpenArchived,
          onCollapse: onCollapse,
        ),
      ),
    );
  }
}

class _PullRevealPanel extends StatelessWidget {
  const _PullRevealPanel({
    required this.searchCtrl,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onClear,
    required this.archivedCount,
    required this.onOpenArchived,
    required this.onCollapse,
  });

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClear;
  final int archivedCount;
  final VoidCallback onOpenArchived;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      // The bottom inset is the only thing separating the search field from
      // the filter row directly under it in the list, so it's wider than a
      // symmetric padding would be. It has to live in here rather than
      // between the two in home_screen: out there it would hold space even
      // with the panel shut, which is the dead band this panel just lost.
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Column(
        // Load-bearing now that the reveal measures this panel instead of
        // clipping it to a constant: a max-size Column would report whatever
        // height it was offered, which is exactly the dead space this was
        // supposed to remove.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FocusableTap(
              onTap: onCollapse,
              semanticLabel: l10n.pullRevealCollapseSemanticLabel,
              shape: FocusRingShape.circle,
              radius: 999,
              child: GestureDetector(
                onTap: onCollapse,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    CupertinoIcons.chevron_up,
                    size: 16,
                    color: theme.inkMuted,
                  ),
                ),
              ),
            ),
          ),
          // The app's one search bar — the same widget Discover's search
          // screen uses, which is what keeps the two from drifting apart the
          // way the hand-rolled copies did.
          SearchField(
            controller: searchCtrl,
            focusNode: searchFocus,
            hintText: l10n.pullRevealSearchHint,
            onChanged: onSearchChanged,
            // Its own, not the default: this one also has to cancel the
            // pending debounce, or the list would come back 250ms after a tap
            // that asked for it now.
            onClear: onClear,
          ),
          if (archivedCount > 0) ...[
            const SizedBox(height: 10),
            _ArchivedRow(count: archivedCount, onTap: onOpenArchived),
          ],
        ],
      ),
    );
  }
}

class _ArchivedRow extends StatefulWidget {
  const _ArchivedRow({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  State<_ArchivedRow> createState() => _ArchivedRowState();
}

class _ArchivedRowState extends State<_ArchivedRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: widget.onTap,
      // The accessible label still carries the count in words — the visible
      // row splits it into an icon-badge instead, but a screen reader gets
      // the same information either way.
      semanticLabel: l10n.archivedChatsFolderLabel(widget.count),
      shape: FocusRingShape.rounded,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: theme.motionFast,
          curve: theme.motionCurve,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.surfaceSunken,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(color: theme.divider, width: 0.5),
            ),
            child: Row(
              children: [
                // Same "icon on an accent-soft circle" treatment as the
                // Saved Messages avatar and the pin badge — one visual
                // language for "this row is a fixture, not a person."
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: theme.accentSoft, shape: BoxShape.circle),
                  child: Icon(CupertinoIcons.archivebox_fill, size: 16, color: theme.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.archivedChatsFolderTitle,
                    style: theme.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                CountBadge(count: widget.count),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: theme.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
