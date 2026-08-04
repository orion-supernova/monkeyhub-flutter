import 'package:flutter/cupertino.dart';

import '../l10n/generated/app_localizations.dart';
import 'glass_pill.dart';

/// Tracks whether a `reverse: true` transcript is scrolled away from its bottom.
///
/// Both chat surfaces render their list reversed, so `position.pixels` IS the
/// distance from the newest message — no arithmetic against `maxScrollExtent`
/// needed, and none of it changes when a page of older history is prepended.
///
/// Two thresholds, not one. With a single boundary the affordance flickers
/// whenever the reader parks on it, and an iOS rubber-band settle can cross it
/// several times in one gesture; [showAbove] / [hideBelow] make the state
/// sticky. [ValueNotifier] already suppresses a notification when the value is
/// unchanged, so the overwhelmingly common scroll frame costs one comparison
/// and rebuilds nothing.
class BottomProximity extends ValueNotifier<bool> {
  BottomProximity() : super(false);

  /// Distance from the bottom, in pixels, past which the affordance appears.
  static const double showAbove = 240;

  /// …and within which it goes away again. Deliberately far below [showAbove];
  /// the band between the two is the sticky one. Both boundaries belong to the
  /// hidden side, so exactly [showAbove] is not yet shown and exactly
  /// [hideBelow] is already gone.
  static const double hideBelow = 96;

  void update(ScrollPosition position) => updateMetrics(
        pixels: position.pixels,
        maxScrollExtent: position.maxScrollExtent,
      );

  /// Split out from [update] so the hysteresis can be tested without pumping a
  /// widget tree.
  void updateMetrics({
    required double pixels,
    required double maxScrollExtent,
  }) {
    // A transcript that doesn't fill its viewport has no "away" to be. Also
    // covers the frame before the first layout, where both are zero.
    if (maxScrollExtent <= 0) {
      value = false;
      return;
    }
    // Overscrolling past the newest message reads as a negative offset on iOS.
    // It is emphatically "at the bottom", and must not trip `> showAbove`.
    if (value) {
      if (pixels <= hideBelow) value = false;
    } else {
      if (pixels > showAbove) value = true;
    }
  }
}

/// Scrolls a `reverse: true` transcript back to the newest message, cheaply.
///
/// A plain `animateTo(0)` from far up forces `ListView.builder` to lay out
/// every row in between, spread across the animation's frames — the further
/// you are the worse it drops. Teleporting to within a viewport-and-a-bit of
/// the bottom first means only that last stretch is ever built, so the motion
/// costs the same whether the reader was one screen up or a thousand.
///
/// Short hops (returning to the bottom right after a send) never hit the jump
/// branch and animate the whole way, as they should.
void scrollToLatest(
  ScrollController controller, {
  Duration duration = const Duration(milliseconds: 280),
  Curve curve = Curves.easeOutCubic,
}) {
  if (!controller.hasClients) return;
  final pos = controller.position;
  // Already there — or bouncing past it. Animating would fight the ballistic.
  if (pos.pixels <= 0) return;
  final cutoff = pos.viewportDimension * 1.2;
  if (pos.pixels > cutoff && cutoff < pos.maxScrollExtent) {
    controller.jumpTo(cutoff);
  }
  controller.animateTo(0, duration: duration, curve: curve);
}

/// Mounts [ScrollToLatestPill] only while it is visible or animating. See
/// [TransientPillSlot], which is the whole of it — this name stays because it
/// is what both transcripts ask for, and because "the scroll-to-latest slot"
/// says where in the layout it goes.
class ScrollToLatestSlot extends StatelessWidget {
  const ScrollToLatestSlot({
    super.key,
    required this.visible,
    required this.onTap,
  });

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TransientPillSlot(
        visible: visible,
        child: ScrollToLatestPill(onTap: onTap),
      );
}

/// Returns the reader to the newest message.
///
/// Same glass capsule as the back-to-reply pill and the room's floating date
/// chip, on purpose: they are one family of transient list chrome, and a reader
/// who has learned to read one shouldn't have to learn the others.
class ScrollToLatestPill extends StatelessWidget {
  const ScrollToLatestPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassPill(
        icon: CupertinoIcons.arrow_down,
        label: AppLocalizations.of(context).reactionBubbleJumpToLatestLabel,
        semanticLabel:
            AppLocalizations.of(context).reactionBubbleJumpToLatestSemanticLabel,
        onTap: onTap,
      );
}
