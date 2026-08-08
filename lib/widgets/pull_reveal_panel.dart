import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';

/// Lives as the first child of the chat list's [ListView]. Hidden by default;
/// pulling down at the top of the list (overscroll) reveals it — see
/// `_HomeScreenState._onScrollNotification` in home_screen.dart, which owns
/// the gesture and just hands this widget a drag distance and an open flag.
///
/// [AnimatedSize] wraps both states (matches the "grow from zero" idiom
/// already used by `pinned_banner.dart` and `room_filter_drawer.dart`), so
/// there's nothing to snap — the hint grows in with the drag, and the panel
/// grows in when it opens.
class PullRevealSlot extends StatelessWidget {
  const PullRevealSlot({
    super.key,
    required this.dragExtent,
    required this.dragThreshold,
    required this.open,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.archivedCount,
    required this.onOpenArchived,
    required this.onCollapse,
  });

  /// Live drag distance while pulling at the top, 0 when not dragging.
  final double dragExtent;
  final double dragThreshold;
  final bool open;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final int archivedCount;
  final VoidCallback onOpenArchived;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedSize(
      duration: theme.motionMed,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: open
          ? _PullRevealPanel(
              searchCtrl: searchCtrl,
              onSearchChanged: onSearchChanged,
              archivedCount: archivedCount,
              onOpenArchived: onOpenArchived,
              onCollapse: onCollapse,
            )
          : dragExtent > 0
          ? _PullHint(progress: (dragExtent / dragThreshold).clamp(0.0, 1.0))
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// A small chevron that grows and fades in as the user drags, so the pull
/// gesture confirms itself before the real panel commits to opening — the
/// same reason [RefreshIndicator] tracks a small glyph during the pull rather
/// than animating its whole result view.
class _PullHint extends StatelessWidget {
  const _PullHint({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      height: 40 * progress,
      child: Center(
        child: Opacity(
          opacity: progress,
          child: Icon(
            CupertinoIcons.chevron_down,
            size: 16 + 4 * progress,
            color: theme.inkMuted,
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
    required this.archivedCount,
    required this.onOpenArchived,
    required this.onCollapse,
  });

  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
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
          Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: theme.inputDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
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

class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.archivedChatsFolderLabel(count),
      shape: FocusRingShape.rounded,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.surfaceSunken,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(color: theme.divider, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.archivebox, size: 18, color: theme.inkSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.archivedChatsFolderLabel(count),
                  style: theme.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: theme.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
