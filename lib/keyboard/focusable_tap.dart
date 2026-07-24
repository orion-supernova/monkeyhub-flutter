import 'package:flutter/widgets.dart';

import '../theme/theme_scope.dart';

/// Shape of the focus ring, matched to the wrapped control's own outline.
enum FocusRingShape { rounded, circle, capsule }

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
///    and no caller needs re-spacing.
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
  });

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

class _FocusableTapState extends State<FocusableTap> {
  bool _focused = false;

  bool get _active => widget.enabled && widget.onTap != null;

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
        label: widget.semanticLabel,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Stack sizes itself to its first non-positioned child, so the ring
            // below contributes nothing to layout.
            widget.child,
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
