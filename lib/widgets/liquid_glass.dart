import 'dart:ui';

import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';

enum LiquidGlassShape { circle, capsule, rounded }

/// Frosted-glass surface — clones the visual recipe from MonkeyHub v02's
/// `LiquidGlassModifier` (frosted blur + translucent fill + diagonal white
/// sheen + accent stroke + soft drop shadow).
///
/// Performance note: the blur is rendered through `BackdropFilter.grouped`,
/// which pairs with a `BackdropGroup` ancestor so all sibling glass surfaces
/// share a single rasterization pass. With six instances per screen (header
/// pill + two header buttons + composer attach + field + send) the cost
/// drops from six full-screen blurs per frame to one.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.shape = LiquidGlassShape.circle,
    this.radius = 22,
    this.padding = EdgeInsets.zero,
    this.size,
    this.tinted = false,
    this.onTap,
    this.blurSigma = 18,
  });

  final Widget child;
  final LiquidGlassShape shape;
  final double radius;
  final EdgeInsets padding;
  final Size? size;
  final bool tinted;
  final VoidCallback? onTap;
  final double blurSigma;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  bool _pressed = false;

  OutlinedBorder _border({BorderSide side = BorderSide.none}) {
    switch (widget.shape) {
      case LiquidGlassShape.circle:
        return CircleBorder(side: side);
      case LiquidGlassShape.capsule:
        return StadiumBorder(side: side);
      case LiquidGlassShape.rounded:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.radius),
          side: side,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isLight = MediaQuery.platformBrightnessOf(context) == Brightness.light;

    final frostAlpha = isLight ? 0.55 : 0.35;
    final overlayTop = isLight ? 0.45 : 0.10;
    const overlayMid = 0.05;

    final clipShape = _border();
    final framedShape = _border(
      side: BorderSide(color: theme.accent.withValues(alpha: 0.30), width: 1.5),
    );

    // BackdropFilter.grouped looks up the nearest BackdropGroup ancestor and
    // shares a single rasterization pass across all sibling grouped filters.
    // Falls back to a private group if no ancestor is found.
    final blurred = ClipPath(
      clipper: ShapeBorderClipper(shape: clipShape),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: widget.blurSigma, sigmaY: widget.blurSigma),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: theme.surface.withValues(alpha: frostAlpha)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: widget.tinted
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.accent.withValues(alpha: 0.50),
                            theme.accent.withValues(alpha: 0.18),
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: overlayTop),
                            Colors.white.withValues(alpha: overlayMid),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                ),
              ),
            ),
            // A Stack sizes to its non-positioned children, so THIS decides
            // how wide the glass is. Centring unconditionally made that child
            // an Align, which expands to fill whatever bounded width it is
            // given — so a capsule around two words still painted full width,
            // and every caller that wanted a pill had to defend itself with
            // an IntrinsicWidth. Centre only when [size] pins the box, where
            // there is real slack to centre the child within; otherwise let
            // the glass shrink-wrap its content.
            Padding(
              padding: widget.padding,
              child: widget.size == null
                  ? widget.child
                  : Center(child: widget.child),
            ),
          ],
        ),
      ),
    );

    // Stroke + shadow live outside the clip so the shadow casts past the glass.
    final framed = DecoratedBox(
      decoration: ShapeDecoration(
        shape: framedShape,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: blurred,
    );

    Widget sized = framed;
    if (widget.size != null) {
      sized = SizedBox(width: widget.size!.width, height: widget.size!.height, child: framed);
    }

    final scaled = AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: theme.motionMed,
      curve: Curves.easeOutBack,
      child: sized,
    );

    // The null check is exactly the right gate for keyboard focus too: the
    // composer's glass *field* passes no onTap and must not become a focus
    // stop, while the send/attach buttons pass one and should.
    if (widget.onTap == null) return scaled;
    return FocusableTap(
      onTap: _activateFromKeyboard,
      shape: _ringShape,
      radius: widget.radius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: scaled,
      ),
    );
  }

  FocusRingShape get _ringShape {
    switch (widget.shape) {
      case LiquidGlassShape.circle:
        return FocusRingShape.circle;
      case LiquidGlassShape.capsule:
        return FocusRingShape.capsule;
      case LiquidGlassShape.rounded:
        return FocusRingShape.rounded;
    }
  }

  /// Enter/Space activation. Pulses the same press state a tap would, so
  /// keyboard use gets the identical scale feedback instead of firing
  /// invisibly.
  void _activateFromKeyboard() {
    final theme = ThemeScope.of(context);
    setState(() => _pressed = true);
    Future<void>.delayed(theme.motionMed, () {
      if (mounted) setState(() => _pressed = false);
    });
    widget.onTap?.call();
  }
}
