import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';

/// Generous upper bound on the panel's real natural height (collapse chevron
/// + search field row + optional archived-folder row), used only to give
/// [OverflowBox] room to lay the panel out at full size while [PullRevealSlot]
/// clips how much of it is actually visible. Doesn't need to be exact — only
/// tall enough for the real content at any text scale.
const double _kMaxPanelHeight = 190.0;

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
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final int archivedCount;
  final VoidCallback onOpenArchived;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final progress = open ? 1.0 : (dragExtent / dragThreshold).clamp(0.0, 1.0);
    return ClipRect(
      child: AnimatedContainer(
        duration: dragging ? Duration.zero : theme.motionMed,
        curve: Curves.easeOutCubic,
        height: progress * _kMaxPanelHeight,
        alignment: Alignment.topCenter,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: _kMaxPanelHeight,
          minHeight: 0,
          child: _PullRevealPanel(
            searchCtrl: searchCtrl,
            onSearchChanged: onSearchChanged,
            onClear: onClearSearch,
            archivedCount: archivedCount,
            onOpenArchived: onOpenArchived,
            onCollapse: onCollapse,
          ),
        ),
      ),
    );
  }
}

class _PullRevealPanel extends StatelessWidget {
  const _PullRevealPanel({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onClear,
    required this.archivedCount,
    required this.onOpenArchived,
    required this.onCollapse,
  });

  final TextEditingController searchCtrl;
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Column(
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
          // Material(transparency) + no-underline InputDecoration: this app
          // never lets Flutter's debug underline show through on a text field
          // that lives outside a Material-themed ancestor.
          //
          // Full pill shape (theme's own color/border, just rounder) rather
          // than the app's default moderate-radius input box — every big
          // chat app's search field reads this way, and it's what makes this
          // look like a search bar rather than a stray text field.
          Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: theme
                  .inputDecoration()
                  .copyWith(borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.inkMuted, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      style: theme.body.copyWith(color: theme.ink),
                      cursorColor: theme.accent,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: l10n.pullRevealSearchHint,
                        hintStyle: theme.body.copyWith(color: theme.inkMuted),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      onChanged: onSearchChanged,
                    ),
                  ),
                  // Rebuilds only this small row on every keystroke — the
                  // controller is a Listenable, and the clear button's whole
                  // job is reacting to its text, so there's no reason to
                  // rebuild the rest of the panel (or lift state up) for it.
                  AnimatedBuilder(
                    animation: searchCtrl,
                    builder: (context, _) => searchCtrl.text.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: FocusableTap(
                              onTap: onClear,
                              semanticLabel: l10n.pullRevealClearSearchSemanticLabel,
                              shape: FocusRingShape.circle,
                              radius: 999,
                              child: GestureDetector(
                                onTap: onClear,
                                behavior: HitTestBehavior.opaque,
                                child: Icon(
                                  CupertinoIcons.clear_circled_solid,
                                  size: 18,
                                  color: theme.inkMuted,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
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
