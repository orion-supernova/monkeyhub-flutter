import 'dart:async';

import 'package:flutter/gestures.dart' show PointerEnterEvent, PointerExitEvent;
import 'package:flutter/material.dart';

import '../keyboard/app_shortcuts.dart';
import '../platform.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'shortcuts/keycaps.dart';

/// The name of an icon-only control, shown when a mouse rests on it — with
/// its keyboard shortcut, when it has one.
///
/// A glyph is a guess until someone tells you what it does. A finger finds
/// out by pressing; a pointer should not have to. This is the desktop's
/// tooltip, drawn the way macOS and Telegram Desktop draw theirs: a small
/// solid pill a beat after the pointer settles, gone the moment it leaves or
/// clicks.
///
/// Rules it keeps:
///  * **Solid, not glass.** A tooltip is text that must read over anything,
///    and because there is no blur in it, fading it in and out is free.
///  * **Waits [delay] on a cold start, none on a warm one.** Once one hint has
///    shown, sliding to the next button shows its hint at once, the way a
///    native toolbar reads: you are clearly looking for something.
///  * **A press dismisses it**, and it stays away until the pointer leaves:
///    you clicked, so you knew.
///  * **Never on a touch-only platform.** It returns [child] untouched there,
///    and a touch never produces hover anyway.
///  * **Out of the semantics tree.** The control already carries its label.
class HoverHint extends StatefulWidget {
  const HoverHint({
    super.key,
    required this.label,
    required this.child,
    this.shortcut,
    this.enabled = true,
  });

  /// The control's name, usually its semantic label. Null or empty shows
  /// nothing.
  final String? label;

  /// Printed after the label as keycaps. Skipped when this platform does not
  /// offer it (a browser-reserved chord on web).
  final ShortcutDef? shortcut;
  final bool enabled;
  final Widget child;

  /// The settle time before a cold hint.
  static const delay = Duration(milliseconds: 500);

  /// How long after one hint hides the next still counts as warm.
  static const warmWindow = Duration(milliseconds: 600);

  static DateTime? _lastHidden;
  static bool _anyShowing = false;

  @override
  State<HoverHint> createState() => _HoverHintState();
}

class _HoverHintState extends State<HoverHint>
    with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  AnimationController? _fade;
  Timer? _timer;

  /// Pressed while hovered: hold off until the pointer leaves.
  bool _suppressed = false;

  bool get _active =>
      widget.enabled && (widget.label?.isNotEmpty ?? false);

  void _enter(PointerEnterEvent _) {
    if (!_active || _suppressed) return;
    _timer?.cancel();
    final last = HoverHint._lastHidden;
    final warm = HoverHint._anyShowing ||
        (last != null &&
            DateTime.now().difference(last) < HoverHint.warmWindow);
    if (warm) {
      _show();
    } else {
      _timer = Timer(HoverHint.delay, _show);
    }
  }

  void _exit(PointerExitEvent _) {
    _suppressed = false;
    _hide();
  }

  void _press(PointerDownEvent _) {
    _suppressed = true;
    _hide(instant: true);
  }

  void _show() {
    if (!mounted || !_active) return;
    final c = _fade ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 90),
    );
    c.duration = MotionScope.of(context).d(const Duration(milliseconds: 120));
    HoverHint._anyShowing = true;
    _portal.show();
    c.forward();
  }

  void _hide({bool instant = false}) {
    _timer?.cancel();
    _timer = null;
    final c = _fade;
    if (c == null || !_portal.isShowing) return;
    HoverHint._anyShowing = false;
    HoverHint._lastHidden = DateTime.now();
    if (instant) {
      c.value = 0;
      _portal.hide();
      return;
    }
    c.reverse().whenCompleteOrCancel(() {
      if (mounted && c.value == 0 && _portal.isShowing) _portal.hide();
    });
  }

  @override
  void didUpdateWidget(HoverHint old) {
    super.didUpdateWidget(old);
    if (!_active) _hide(instant: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_portal.isShowing) {
      HoverHint._anyShowing = false;
      HoverHint._lastHidden = DateTime.now();
    }
    _fade?.dispose();
    super.dispose();
  }

  /// The control's rect in the overlay's coordinates, or null if either box
  /// is not laid out (a hint asked for mid-teardown).
  Rect? _targetRect(BuildContext overlayContext) {
    final box = context.findRenderObject();
    final overlay = overlayContext.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox) return null;
    if (!box.attached || !box.hasSize || !overlay.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      Offset.zero & box.size,
    );
  }

  Widget _bubble(BuildContext overlayContext) {
    final target = _targetRect(Overlay.of(context).context);
    final fade = _fade;
    if (target == null || fade == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: CustomSingleChildLayout(
            delegate: _HintLayout(target),
            child: FadeTransition(
              opacity: fade,
              child: HintBubble(
                label: widget.label!,
                shortcut: widget.shortcut,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isWebOrDesktop) return widget.child;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _bubble,
      child: MouseRegion(
        opaque: false,
        onEnter: _enter,
        onExit: _exit,
        child: Listener(onPointerDown: _press, child: widget.child),
      ),
    );
  }
}

/// The pill itself: the label and, after it, the shortcut's keycaps.
/// Public so a preview or test can draw it without a hover.
class HintBubble extends StatelessWidget {
  const HintBubble({super.key, required this.label, this.shortcut});

  final String label;
  final ShortcutDef? shortcut;

  /// Near-black on every theme, with a hairline that only shows on a dark
  /// page, where the pill would otherwise melt into it.
  static const fill = Color(0xF21C1C1E);
  static const ink = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final def = shortcut;
    final keys = def != null && def.offeredHere;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 4, keys ? 4 : 8, 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: ink.withValues(alpha: 0.12),
          width: 0.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // The body face, never the caption: on a character theme that
              // is a tracked mono. Every field explicit — this floats in the
              // overlay, outside any Material, and must never fall back to
              // Flutter's debug text style.
              style: theme.body.copyWith(
                color: ink,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (keys) ...[
            const SizedBox(width: 6),
            Keycaps.forDef(def, size: KeycapSize.small, color: ink),
          ],
        ],
      ),
    );
  }
}

/// Below the control, centred on it; above when there is no room below;
/// always kept [margin] inside the window.
class _HintLayout extends SingleChildLayoutDelegate {
  _HintLayout(this.target);

  final Rect target;
  static const gap = 6.0;
  static const margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          (constraints.maxWidth - margin * 2).clamp(0, 320),
          constraints.maxHeight,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final below = target.bottom + gap;
    final y = below + child.height <= size.height - margin
        ? below
        : (target.top - gap - child.height).clamp(margin, double.infinity);
    final x = (target.center.dx - child.width / 2)
        .clamp(margin, (size.width - margin - child.width).clamp(margin, double.infinity));
    return Offset(x.toDouble(), y.toDouble());
  }

  @override
  bool shouldRelayout(_HintLayout old) => old.target != target;
}
