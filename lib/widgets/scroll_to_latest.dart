import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';

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

/// Mounts [ScrollToLatestPill] only while it is visible or animating.
///
/// The pill is a `BackdropFilter`, which costs a backdrop rasterization pass
/// every frame it exists — even at zero opacity. So this does not park a hidden
/// pill in the tree behind an `AnimatedOpacity`: below `isDismissed` it renders
/// nothing at all, which also means nothing to hit-test.
class ScrollToLatestSlot extends StatefulWidget {
  const ScrollToLatestSlot({
    super.key,
    required this.visible,
    required this.onTap,
  });

  final bool visible;
  final VoidCallback onTap;

  @override
  State<ScrollToLatestSlot> createState() => _ScrollToLatestSlotState();
}

class _ScrollToLatestSlotState extends State<ScrollToLatestSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      // Replaced from the theme in didChangeDependencies, before first paint.
      duration: const Duration(milliseconds: 220),
      value: widget.visible ? 1 : 0,
    );
    // Opacity must stay inside 0..1, so the overshooting curve drives only the
    // scale. easeOutBack on a fade would assert.
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      ),
    );
    // The only transitions that change what is mounted are into and out of
    // `dismissed`; every other frame is painted by the transitions themselves.
    _ctrl.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl.duration = ThemeScope.of(context).motionFast;
  }

  @override
  void didUpdateWidget(ScrollToLatestSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _fade.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl.isDismissed) return const SizedBox.shrink();
    return RepaintBoundary(
      // Ignoring on the way out too: the pill is still painted while it fades,
      // and a tap landing on something that is visibly leaving is a misfire.
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: ScrollToLatestPill(onTap: widget.onTap),
          ),
        ),
      ),
    );
  }
}

/// Returns the reader to the newest message.
///
/// Same glass capsule as the room's floating date chip, on purpose: the two are
/// one family of transient list chrome, and a reader who has learned to read
/// one shouldn't have to learn the other.
class ScrollToLatestPill extends StatelessWidget {
  const ScrollToLatestPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: 'Jump to latest',
      shape: FocusRingShape.capsule,
      // Bare GestureDetector, never InkWell — this app renders no ink anywhere.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: theme.accentSoft,
                border: Border.all(color: theme.divider, width: 1),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.arrow_down, size: 11, color: theme.accent),
                  const SizedBox(width: 6),
                  Text(
                    'JUMP TO LATEST',
                    style: theme.monoTiny.copyWith(letterSpacing: 1.8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
