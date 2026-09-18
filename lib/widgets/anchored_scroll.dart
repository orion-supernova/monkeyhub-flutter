import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A row that is currently laid out, used to calibrate the extrapolation.
typedef ScrollProbe = ({int index, BuildContext context});

/// Reposition [controller] so the row at `targetIndex()` is on screen, then
/// settle it into place with an animation.
///
/// `ListView.builder` only lays out rows near the viewport, so a row that is
/// hundreds of items away has no `BuildContext` and `Scrollable.ensureVisible`
/// silently no-ops on it — which is why "jump to the quoted message" used to
/// fail whenever the target was more than a screen or so away. Instead of
/// hoping the row is built, we *estimate* its scroll offset from the rows that
/// are, jump there, and re-measure. Each hop lays out a fresh neighbourhood, so
/// the estimate converges in two to four iterations at any distance, and the
/// final `ensureVisible` supplies the motion that makes the landing readable.
///
/// The estimate works off [RenderAbstractViewport.getOffsetToReveal], so it is
/// correct for `reverse: true` lists, horizontal lists and non-zero padding
/// without any special-casing here. In every axis configuration the scroll
/// offset grows with the item index, which is the only assumption made.
///
/// [targetIndex] and [itemCount] are callbacks rather than values because the
/// list is live: a message arriving mid-jump shifts every index by one.
/// Returns true once the row has been revealed; false if it never showed up
/// (the caller is expected to have made sure the row is in the list at all —
/// this function never paginates).
Future<bool> snapToIndex({
  required ScrollController controller,
  required int? Function() targetIndex,
  required int Function() itemCount,
  required BuildContext? Function() targetContext,
  required List<ScrollProbe> Function() probes,
  double alignment = 0.3,
  Duration settle = const Duration(milliseconds: 300),
  Curve curve = Curves.easeOutCubic,
  int maxIterations = 12,
}) async {
  if (!controller.hasClients) return false;

  for (var i = 0; i < maxIterations; i++) {
    final ctx = targetContext();
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: alignment,
        duration: settle,
        curve: curve,
      );
      return true;
    }
    if (!controller.hasClients) return false;
    final index = targetIndex();
    if (index == null) return false;

    final position = controller.position;
    final guess = _estimateOffset(
      position: position,
      targetIndex: index,
      itemCount: itemCount(),
      probes: probes(),
      alignment: alignment,
    );
    if (guess == null) return false;

    var next = guess.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((next - position.pixels).abs() < 1) {
      // We're already sitting where the target is supposed to be and it still
      // isn't built — the extents we averaged over are unrepresentative (a run
      // of tall media, say). Step a screenful further in the target's
      // direction so the next pass measures new ground instead of stalling.
      final dir = _direction(index, probes());
      if (dir == 0) return false;
      next = (position.pixels + dir * position.viewportDimension * 0.8)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((next - position.pixels).abs() < 1) return false; // at the end
    }
    controller.jumpTo(next);
    await WidgetsBinding.instance.endOfFrame;
  }

  final ctx = targetContext();
  if (ctx != null && ctx.mounted) {
    await Scrollable.ensureVisible(
      ctx,
      alignment: alignment,
      duration: settle,
      curve: curve,
    );
    return true;
  }
  return false;
}

/// Which way [targetIndex] lies from the rows we can currently see: +1 further
/// along the scroll axis, -1 back towards the start, 0 when unknowable.
int _direction(int targetIndex, List<ScrollProbe> probes) {
  var nearest = -1;
  var bestDistance = 1 << 30;
  for (final p in probes) {
    final d = (p.index - targetIndex).abs();
    if (d < bestDistance) {
      bestDistance = d;
      nearest = p.index;
    }
  }
  if (nearest < 0) return 0;
  if (targetIndex == nearest) return 0;
  return targetIndex > nearest ? 1 : -1;
}

/// Scroll offset that would put [targetIndex] at [alignment], extrapolated
/// from whichever rows are laid out right now.
double? _estimateOffset({
  required ScrollPosition position,
  required int targetIndex,
  required int itemCount,
  required List<ScrollProbe> probes,
  required double alignment,
}) {
  final reveals = <int, double>{};
  for (final p in probes) {
    final ro = p.context.findRenderObject();
    if (ro == null || !ro.attached) continue;
    final viewport = RenderAbstractViewport.maybeOf(ro);
    if (viewport == null) continue;
    reveals[p.index] = viewport.getOffsetToReveal(ro, alignment).offset;
  }

  // The viewport's own estimate of total extent divided by the item count is
  // the average row height it is itself extrapolating with — the right
  // fallback when nothing (or only one thing) is measurable.
  final span = position.maxScrollExtent - position.minScrollExtent;
  final coarse = itemCount > 1 ? span / itemCount : 0.0;

  if (reveals.isEmpty) {
    if (coarse <= 0) return null;
    return position.minScrollExtent + coarse * targetIndex;
  }

  final measured = reveals.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final lowest = measured.first;
  final highest = measured.last;

  var perItem = coarse;
  if (highest.key != lowest.key) {
    perItem = (highest.value - lowest.value) / (highest.key - lowest.key);
  }
  if (perItem <= 0) perItem = coarse;
  if (perItem <= 0) return null;

  // Anchor on whichever measured row is closest to the target: extrapolation
  // error grows with the distance travelled.
  final anchor =
      (targetIndex - lowest.key).abs() <= (targetIndex - highest.key).abs()
          ? lowest
          : highest;
  return anchor.value + (targetIndex - anchor.key) * perItem;
}

/// The [Scrollable.ensureVisible] alignment that centres an [extent]-tall row
/// in what the reader can actually SEE of a [viewport]: the band left between
/// chrome floating over its [top] and [bottom] edges.
///
/// A plain 0.5 centres the row in the viewport's box, and in the compact chat
/// style that box runs under a glass header and a glass composer of different
/// heights — so "centred" landed visibly off-centre, by half their difference.
///
/// [reverse] is the list's own flag. `ensureVisible` measures alignment from
/// the viewport's LEADING edge, which is the bottom of a `reverse: true`
/// transcript, so the same visual target needs the complementary fraction.
///
/// Clamped to 0..1; the scroll position clamps the resulting offset in turn,
/// which is what makes this "as centred as the content allows" — a row with
/// half a screen of messages below it cannot be lifted any higher than that.
double centredAlignment({
  required double viewport,
  required double extent,
  double top = 0,
  double bottom = 0,
  bool reverse = false,
}) {
  final free = viewport - extent;
  if (free <= 0) return 0.5;
  // Where the row's centre should sit, from the viewport's top edge.
  final centre = (top + viewport - bottom) / 2;
  final fromTop = (centre - extent / 2) / free;
  return (reverse ? 1 - fromTop : fromTop).clamp(0.0, 1.0);
}
