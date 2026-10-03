import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'search_field.dart';
import 'sheet_kit.dart' show sentenceCaseOf;
import 'teardown_safe.dart';

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
///
/// Once it's [open], the reveal is pinned at full height and this widget
/// stops having a say: the panel is simply the first thing in the list, and an
/// upward scroll carries it off the top edge at the speed of the finger doing
/// the scrolling. The only heights that animate are the ones a gesture
/// released on, and the collapse the close button asks for — see [instant].
class PullRevealSlot extends StatelessWidget {
  const PullRevealSlot({
    super.key,
    this.panelKey,
    required this.dragExtent,
    required this.dragThreshold,
    required this.instant,
    required this.open,
    required this.searchCtrl,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.archivedCount,
    required this.onOpenArchived,
    required this.onCollapse,
  });

  /// Goes on the panel inside the clip, not on the clip itself, so the owner
  /// can measure the height a full reveal actually comes to — which is
  /// whatever a search field plus an optional archived row measure at the
  /// reader's text scale, and which the clipped slot can't report.
  final GlobalKey? panelKey;

  /// Live drag distance while pulling at the top, 0 when idle or settled.
  final double dragExtent;
  final double dragThreshold;

  /// Whether a height change has to land in a single frame instead of
  /// animating toward wherever it ended up.
  ///
  /// True while the finger is dragging the reveal open, which is what makes
  /// it track that finger. True again when the owner drops an open panel that
  /// scrolling has carried off the top of the list: that collapse happens
  /// *above* the viewport, where animating it would spend a quarter second
  /// hauling everything below it up — see
  /// `_HomeScreenState._dropScrolledAwayPanel`.
  ///
  /// False for a height a gesture released on, and for the collapse the close
  /// button asks for, which are the two the reader is meant to watch.
  final bool instant;
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
        duration: instant ? Duration.zero : theme.motionMed,
        curve: Curves.easeOutCubic,
        tween: Tween<double>(end: progress),
        builder: (context, factor, child) =>
            Align(alignment: Alignment.topCenter, heightFactor: factor, child: child),
        child: _PullRevealPanel(
          key: panelKey,
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
    super.key,
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
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 14),
      child: Column(
        // Load-bearing now that the reveal measures this panel instead of
        // clipping it to a constant: a max-size Column would report whatever
        // height it was offered, which is exactly the dead space this was
        // supposed to remove.
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // The app's one search bar — the same widget Discover's search
              // screen uses, which is what keeps the two from drifting apart
              // the way the hand-rolled copies did.
              Expanded(
                child: SearchField(
                  controller: searchCtrl,
                  focusNode: searchFocus,
                  hintText: l10n.pullRevealSearchHint,
                  onChanged: onSearchChanged,
                  // Its own, not the default: this one also has to cancel
                  // the pending debounce, or the list would come back 250ms
                  // after a tap that asked for it now.
                  onClear: onClear,
                ),
              ),
              const SizedBox(width: 8),
              // Beside the field rather than on a row of its own above it —
              // that row used to be almost entirely empty (one small glyph
              // against the panel's full width), which read as dead space
              // stacked on top of the search bar rather than part of it.
              // The iOS search bar's Cancel: a text button in the accent,
              // beside the field. It dismisses the whole panel, field and all.
              FocusableTap(
                onTap: onCollapse,
                semanticLabel: l10n.pullRevealCollapseSemanticLabel,
                shape: FocusRingShape.capsule,
                radius: 999,
                child: GestureDetector(
                  onTap: onCollapse,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Text(
                      sentenceCaseOf(
                        context,
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                      style: theme.body.copyWith(
                        fontSize: 17,
                        color: theme.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (archivedCount > 0) ...[
            const SizedBox(height: 6),
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

class _ArchivedRowState extends State<_ArchivedRow>
    with TeardownSafe<_ArchivedRow> {
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
        // Shaped like a chat row — the Telegram folder: a grey disc where a
        // face would be, the title, the count in grey (archived chats ask for
        // nothing), a chevron because it opens a list rather than a chat.
        child: AnimatedContainer(
          duration: _pressed ? Duration.zero : const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _pressed ? theme.ink.withValues(alpha: 0.06) : null,
            borderRadius: BorderRadius.circular(theme.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.inkMuted.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.archivebox_fill,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  sentenceCaseOf(context, l10n.archivedChatsFolderTitle),
                  style: theme.bodyEmph.copyWith(
                    color: theme.ink,
                    fontStyle: FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.inkMuted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.count}',
                  style: theme.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: theme.background,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: theme.inkMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
