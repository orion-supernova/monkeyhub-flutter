import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';

/// Shape of the focus ring, matched to the wrapped control's own outline.
enum FocusRingShape { rounded, circle, capsule }

/// What a mouse resting over a control does to it. Never a scale: a pointer
/// sliding along a toolbar must not make the bar wobble, and a hover is a
/// question ("is this clickable?"), not an action.
enum HoverEffect {
  /// Nothing drawn. The cursor still turns to a hand.
  none,

  /// The theme's ink at 5% (light) / 7% (dark) over the control: the quiet
  /// table-cell fill of a row, a chip, a text button. Darkens on a light
  /// palette and lightens on a dark one, because ink is the opposite of the
  /// page either way.
  tint,

  /// A little more light in the glass, the way a finger's press brightens it
  /// but softer: for discs and pills of glass. White over the surface on a
  /// dark palette; on a light one the disc is already near white and a white
  /// wash vanished (render-checked), so there it is a faint shade instead.
  /// The blur underneath is never touched.
  glow,
}

/// How long a hover takes to come and go. Short enough that sweeping the
/// pointer across a list leaves no trail, long enough that it is not a flash.
const Duration kHoverFade = Duration(milliseconds: 120);

/// The colour [HoverEffect] paints at full strength.
Color hoverColor(AppTheme theme, HoverEffect effect) => switch (effect) {
      HoverEffect.none => const Color(0x00000000),
      HoverEffect.tint =>
        theme.ink.withValues(alpha: theme.isLight ? 0.05 : 0.07),
      HoverEffect.glow => theme.isLight
          ? const Color(0xFF000000).withValues(alpha: 0.06)
          : const Color(0xFFFFFFFF).withValues(alpha: 0.09),
    };

/// Makes an existing tappable subtree reachable and activatable by keyboard,
/// without changing how it handles pointers.
///
/// This app's buttons are bare [GestureDetector]s with hand-rolled press and
/// scale animations, which create no focus node and no button semantics — so
/// Tab can't reach them, Enter/Space can't activate them, and screen readers
/// don't announce them. Rather than rewrite each one, this wraps them: it adds
/// a focus node, binds Enter/Space/NumpadEnter to [onTap], and paints a ring.
///
/// Three deliberate properties:
///
///  * **It registers no gesture recognizer of its own.** The child's existing
///    gesture handling — including [LiquidGlass]'s onTapDown/onTapCancel/
///    onTapUp press state — is passed through untouched.
///  * **The ring is drawn outside the child's bounds** via a [Stack] with a
///    negative-inset [Positioned], so layout is identical at every call site
///    and no caller needs re-spacing. That is why the Stack is
///    [StackFit.passthrough] and not the default [StackFit.loose] — see the
///    note at the Stack itself.
///  * **It does not take focus on tap.** Clicking Send in the composer must not
///    pull focus out of the message field.
///
/// The ring only appears for keyboard-driven focus: [FocusableActionDetector]'s
/// `onShowFocusHighlight` respects [FocusManager.highlightMode], so clicking a
/// button with the mouse shows nothing. Enter, Space and NumpadEnter all arrive
/// as [ActivateIntent] because `WidgetsApp` binds them by default, so one
/// action covers all three.
///
/// Ships ungated by platform: with no keyboard attached nothing requests focus
/// and no ring ever paints, and gating it would deny a tablet user with a
/// Bluetooth keyboard the whole feature.
class FocusableTap extends StatefulWidget {
  const FocusableTap({
    super.key,
    required this.onTap,
    required this.child,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.shape = FocusRingShape.rounded,
    this.radius = 14,
    this.inset = 3,
    this.enabled = true,
    this.selected,
    this.hover = HoverEffect.none,
    this.hoverRadius,
    this.onHover,
  });

  /// What a mouse over the control draws, clipped to [shape]. [HoverEffect.none]
  /// by default because this wraps arbitrary subtrees and cannot know what it
  /// is laid over; [SpringPress] and the row primitives opt in.
  final HoverEffect hover;

  /// The hover fill's corner radius when it should differ from the ring's
  /// [radius] — 0 for a full-width row inside a grouped block, whose own
  /// clip rounds the outer corners.
  final double? hoverRadius;

  /// Hover in and out, for a control with its own treatment (see
  /// `SpringPress.stateBuilder`). Fires only for a mouse, only while enabled,
  /// and never on a touch screen.
  final ValueChanged<bool>? onHover;

  /// Selection state for controls that toggle. Leave null for ordinary buttons
  /// — `Semantics.selected` on a non-toggle would have VoiceOver announce
  /// "not selected" after every label.
  final bool? selected;

  /// Null (or `enabled: false`) means disabled: Tab skips it and the ring never
  /// paints, matching the dimmed CTAs the sheets already render.
  final VoidCallback? onTap;
  final Widget child;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;
  final FocusRingShape shape;

  /// Corner radius of the wrapped control; the ring adds [inset] to it so the
  /// two stay concentric.
  final double radius;

  /// How far outside the child's bounds the ring sits.
  final double inset;
  final bool enabled;

  @override
  State<FocusableTap> createState() => _FocusableTapState();
}

class _FocusableTapState extends State<FocusableTap>
    with SingleTickerProviderStateMixin {
  bool _focused = false;

  /// Drives the hover fill. Created on the first hover, so the hundreds of
  /// tappables on a phone — where no hover ever arrives — carry no controller
  /// and no extra layer.
  AnimationController? _hover;

  bool get _active => widget.enabled && widget.onTap != null;

  void _onHover(bool v) {
    widget.onHover?.call(v);
    if (widget.hover == HoverEffect.none || !mounted) return;
    var c = _hover;
    if (c == null) {
      if (!v) return;
      c = _hover = AnimationController(vsync: this);
      // The one rebuild hover ever causes: it mounts the fill's layer. From
      // here on the fill only repaints.
      setState(() {});
    }
    c.duration = MotionScope.of(context).d(kHoverFade);
    v ? c.forward() : c.reverse();
  }

  @override
  void dispose() {
    _hover?.dispose();
    super.dispose();
  }

  ShapeBorder _ringShape(Color color) {
    final side = BorderSide(color: color, width: 2);
    switch (widget.shape) {
      case FocusRingShape.circle:
        return CircleBorder(side: side);
      case FocusRingShape.capsule:
        return StadiumBorder(side: side);
      case FocusRingShape.rounded:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.radius + widget.inset),
          side: side,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: _active,
      // Tab must skip a disabled CTA rather than park on a dead control.
      descendantsAreTraversable: _active,
      mouseCursor: _active ? SystemMouseCursors.click : MouseCursor.defer,
      onShowFocusHighlight: (v) {
        if (v != _focused && mounted) setState(() => _focused = v);
      },
      // Only ever true for a mouse in the "traditional" highlight mode, so a
      // finger never lights it: touch input flips the mode first.
      onShowHoverHighlight: _onHover,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: _active,
        // Null for a plain button; true/false marks it as a toggle and lets a
        // screen reader announce its state. Without it, controls whose only
        // on/off signal is an accent fill — the filter chips and facet rows —
        // are indistinguishable to assistive tech.
        selected: widget.selected,
        label: widget.semanticLabel,
        child: Stack(
          // Passthrough, not the default loose. A loose Stack re-loosens the
          // constraints it was handed, so a wrapped child that shrink-wraps
          // stopped filling a slot it used to fill and got pinned at the
          // Stack's default topStart — this wrapper silently moved it. The
          // bottom nav shipped that way: each segment is `Expanded` (tight
          // 81.5pt) around a `mainAxisSize.min` Column (~54pt), so every icon
          // and label sat 13.875pt left of centre, and the ~28pt of slack was
          // dead to touch because only the child's GestureDetector was opaque.
          // Passthrough forwards the constraints untouched, which is the
          // "layout is identical at every call site" promise above.
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            // Stack sizes itself to its first non-positioned child, so the ring
            // below contributes nothing to layout.
            widget.child,
            if (_hover != null && widget.hover != HoverEffect.none)
              Positioned.fill(
                child: IgnorePointer(
                  // Its own layer, so the 120ms fade re-records one small
                  // picture instead of repainting the list or the glass the
                  // control sits in.
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _HoverPainter(
                        progress: _hover!,
                        color: hoverColor(theme, widget.hover),
                        shape: widget.shape,
                        radius: widget.hoverRadius ?? widget.radius,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: -widget.inset,
              top: -widget.inset,
              right: -widget.inset,
              bottom: -widget.inset,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _focused ? 1 : 0,
                  duration: theme.motionFast,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: _ringShape(theme.accent),
                      shadows: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The hover fill: [color] scaled by [progress], in the control's outline.
/// Repaints from the animation directly; nothing above it rebuilds.
class _HoverPainter extends CustomPainter {
  _HoverPainter({
    required this.progress,
    required this.color,
    required this.shape,
    required this.radius,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final FocusRingShape shape;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0) return;
    final paint = Paint()..color = color.withValues(alpha: color.a * t);
    final rect = Offset.zero & size;
    switch (shape) {
      case FocusRingShape.circle:
        canvas.drawOval(rect, paint);
      case FocusRingShape.capsule:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2)),
          paint,
        );
      case FocusRingShape.rounded:
        if (radius <= 0) {
          canvas.drawRect(rect, paint);
        } else {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(radius)),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_HoverPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.shape != shape ||
      old.radius != radius;
}
