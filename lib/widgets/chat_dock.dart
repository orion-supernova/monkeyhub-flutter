/// The chat screen's bottom dock: one layout system for everything that sits
/// near the composer.
///
/// Design: `docs/design/swipe-up-fork.html`, section "The bottom dock".
///
/// Before this, the composer column and the floating buttons each decided their
/// own position, and the order was an accident of how the `Column` happened to
/// be written: with a scheduled message pending, the scheduled pill wedged
/// itself BETWEEN the reply card and the field the reply belongs to. Now every
/// element registers into a lane with an owner, and the order is fixed here,
/// once, for both chat styles.
///
/// ```
///   Float right  : the scroll FAB column            (not measured)
///   Float center : one transient pill               (not measured)
///   ------------------------------------------------
///   Lane 3 Shelf   : persistent room state, 1 row   (measured)
///   Lane 2 Context : edit > reply, capacity 1       (measured)
///   Lane 1 Input   : mention picker, stickers,
///                    picked media, then the field   (measured)
/// ```
///
/// Lanes 1 to 3 are [ChatDock], which the host mounts inside its existing
/// `MeasureChatBottomInset` pair (target inside the growth animation, drawn
/// outside it — see `chat_bottom_inset.dart`). The dock adds no measurement of
/// its own and changes neither of those two: it is just the `Column` that used
/// to be inlined there, with a fixed order. The floats are [ChatDockFloats],
/// which stay offset by the measured inset exactly as before.
///
/// Takeovers (what hides what):
///  * mention picker open: the shelf hides ([ChatDock.mentionOpen]);
///  * a recording in progress: the shelf and the context lane hide
///    ([ChatDock.recording]); both come back when it ends;
///  * selection mode: the host swaps the whole dock for the selection bar;
///  * read-only room: the host swaps the whole dock for the footer;
///  * a gesture (the swipe-up fork): [ChatDock.dockFade] / [ChatDockFloats.fade]
///    dim everything. See [DockFade].
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../theme/theme_scope.dart';
import 'glass_reveal.dart';
import 'liquid_glass.dart';
import 'scheduled_pill.dart' show kScheduledPillHeight;

/// Who wins the shelf's width. Higher priority takes the width; the rest
/// collapse to [kDockChipWidth] chips in the same row.
///
/// Spaced so a new kind of item can slot between two existing ones without
/// renumbering. Order from the design: in-huddle bar > Join > scheduled with a
/// failure > scheduled.
abstract final class DockShelfPriority {
  static const int scheduled = 10;
  static const int scheduledFailed = 20;
  static const int join = 30;
  static const int huddle = 40;
}

/// One thing the shelf can show. Registered by whoever owns the state; the
/// shelf decides which form it is drawn in.
///
/// The widget is built per frame by the host, so [expanded] and [chip] only
/// need to be correct for the host's current state.
class DockShelfItem {
  const DockShelfItem({
    required this.id,
    required this.priority,
    required this.expanded,
    required this.chip,
  });

  /// Stable across rebuilds: it is the item's key, so a chip becoming the
  /// expanded form (or the other way round) keeps its element.
  final String id;

  /// See [DockShelfPriority].
  final int priority;

  /// The full-width form, used when this is the top item. Should be at most
  /// [kDockShelfHeight] tall (the pill/bar and the gap under it).
  final WidgetBuilder expanded;

  /// The collapsed form, used when something outranks this item. Should be
  /// [kDockChipWidth] wide; use [DockShelfChip] so every chip looks the same.
  final WidgetBuilder chip;
}

/// Height of the shelf's one row, including the gap under it. The scheduled
/// pill's own slot, so the shelf reserves exactly what the pill always did and
/// the liquid style's first-frame estimate (60 + safe area + this) still holds.
const double kDockShelfHeight = kScheduledPillHeight;

/// Width of a collapsed shelf item.
const double kDockChipWidth = 44;

/// Width of one thumb column at the screen's edge. The center float slot may be
/// at most the screen minus two of these.
const double kDockThumbColumn = 56;

/// The collapsed form of a shelf item: an icon and an optional count in a glass
/// capsule, 44pt wide, sitting in the shelf row's slot the way a full pill does.
class DockShelfChip extends StatelessWidget {
  const DockShelfChip({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Shown beside the glyph when non-null.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      height: kDockShelfHeight,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: kDockChipWidth),
          child: LiquidGlass(
            shape: LiquidGlassShape.capsule,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            onTap: onTap,
            semanticLabel: semanticLabel,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: theme.accent),
                if (count != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: theme.bodySoft.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.accent,
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

/// Lanes 1 to 3 as one column. Stateless on purpose: every slot is always
/// present (an empty one is a [SizedBox.shrink]) so the composer's element
/// never shifts position when a card or the shelf comes and goes — a
/// conditional child would hand the field a different index each time.
class ChatDock extends StatelessWidget {
  const ChatDock({
    super.key,
    required this.field,
    this.mention,
    this.stickers,
    this.media,
    this.edit,
    this.reply,
    this.shelf = const [],
    this.mentionOpen = false,
    this.recording = false,
    this.below = const [],
    this.dockFade,
  });

  /// Lane 1, the composer field itself (classic or liquid).
  final Widget field;

  /// Lane 1, above the field: the @-picker, null when closed.
  final Widget? mention;

  /// Lane 1, above the field: sticker suggestions (zero height when idle).
  final Widget? stickers;

  /// Lane 1, above the field: the picked-media strip (zero height when idle).
  final Widget? media;

  /// Lane 2. Capacity one: [edit] wins over [reply] when both are given, so
  /// the "two banners" state cannot render even if the host's invariant breaks.
  final Widget? edit;
  final Widget? reply;

  /// Lane 3. Any number of items; see [DockShelfItem]. Empty means no shelf.
  final List<DockShelfItem> shelf;

  /// The @-picker is open. It covers the shelf; the shelf comes back (the
  /// call it shows keeps running) when the picker closes.
  final bool mentionOpen;

  /// A voice or video note is recording (hands-free and locked included). The
  /// shelf and the context lane hide so the recording strip has the space;
  /// both return when it ends (a reply or edit is kept by the host, only
  /// hidden).
  final bool recording;

  /// Under the field and inside the same measured box: the emoji / picker
  /// panels.
  final List<Widget> below;

  /// 0 (gone) to 1 (shown), for takeovers that dim the whole dock. Null for a
  /// dock nothing ever fades. See [DockFade].
  final ValueListenable<double>? dockFade;

  @override
  Widget build(BuildContext context) {
    final card = recording ? null : (edit ?? reply);
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lane 3, topmost: persistent room state, never between a card and the
        // field it belongs to.
        _Shelf(items: mentionOpen || recording ? const [] : shelf),
        // Lane 2: directly on top of the input lane. One slot, so edit and
        // reply can never both show. The cards animate themselves in.
        card ?? const SizedBox.shrink(),
        // Lane 1.
        mention ?? const SizedBox.shrink(),
        stickers ?? const SizedBox.shrink(),
        media ?? const SizedBox.shrink(),
        field,
        ...below,
      ],
    );
    return DockFade(fade: dockFade, child: column);
  }
}

/// Dims [child] with [fade] (1 shown, 0 gone) without breaking the glass in it.
///
/// Glass must never sit in an opacity layer — the blur would sample the layer's
/// empty buffer and flash flat (see [GlassReveal]). [GlassStill] is the shared
/// answer for "a whole rail of controls dimmed out of the way": glass under it
/// draws its blur-free twin, and it is on for exactly the frames the fade is
/// not settled at 1, so the dock looks identical at rest. Hit testing is off
/// while it is dimmed.
///
/// A null [fade] adds nothing to the tree.
class DockFade extends StatelessWidget {
  const DockFade({super.key, required this.fade, required this.child});

  final ValueListenable<double>? fade;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fade = this.fade;
    if (fade == null) return child;
    return ValueListenableBuilder<double>(
      valueListenable: fade,
      child: child,
      builder: (context, v, child) => IgnorePointer(
        ignoring: v < 1,
        child: GlassStill(
          still: v < 1,
          child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
        ),
      ),
    );
  }
}

/// Lane 3: merges its items into one row. The top item (highest priority; the
/// earlier one wins a tie) takes the width and the rest become chips beside it,
/// highest first. Nothing stacks and nothing hides.
class _Shelf extends StatelessWidget {
  const _Shelf({required this.items});

  final List<DockShelfItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    // Stable: equal priorities keep the order the host registered them in.
    final sorted = [
      for (var i = 0; i < items.length; i++) (i, items[i]),
    ]..sort((a, b) {
        final byPriority = b.$2.priority.compareTo(a.$2.priority);
        return byPriority != 0 ? byPriority : a.$1.compareTo(b.$1);
      });
    final top = sorted.first.$2;
    // One item: exactly the old centred pill, no padding, no Row.
    if (sorted.length == 1) {
      return KeyedSubtree(
        key: ValueKey('shelf:${top.id}'),
        child: SizedBox(
          height: kDockShelfHeight,
          child: Center(child: top.expanded(context)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: kDockShelfHeight,
        child: Row(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('shelf:${top.id}'),
                child: Center(child: top.expanded(context)),
              ),
            ),
            for (final (_, item) in sorted.skip(1)) ...[
              const SizedBox(width: 8),
              KeyedSubtree(
                key: ValueKey('shelf:${item.id}'),
                // A minimum, not a fixed width: a chip with a two-digit count
                // is a little wider than a bare glyph and must not overflow.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: kDockChipWidth),
                  child: item.chip(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The two floating layers over the transcript: one transient pill in the
/// center, the scroll column in the right thumb column. Not measured — the host
/// places this at `bottom: 0` and pads it by the measured dock inset (see
/// `ChatBottomInsetBuilder`), so both ride the dock's top edge every frame.
///
/// The center slot is at most the screen minus a thumb column on each side, so
/// it can never reach under the FAB column. Persistent things belong on the
/// shelf; this slot is for what comes and goes.
class ChatDockFloats extends StatelessWidget {
  const ChatDockFloats({
    super.key,
    required this.right,
    required this.rightInset,
    this.center,
    this.fade,
  });

  /// The scroll FAB column, unchanged.
  final Widget right;

  /// How far in from the right edge the column sits (`scrollFabRightInset`).
  final double rightInset;

  /// One transient item (the timeline sync pill).
  final Widget? center;

  /// Same hook as [ChatDock.dockFade].
  final ValueListenable<double>? fade;

  @override
  Widget build(BuildContext context) {
    return DockFade(
      fade: fade,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (center != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: kDockThumbColumn),
              child: center,
            ),
          Align(
            alignment: Alignment.bottomRight,
            heightFactor: 1,
            child: Padding(
              padding: EdgeInsets.only(right: rightInset),
              child: right,
            ),
          ),
        ],
      ),
    );
  }
}
