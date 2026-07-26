import 'dart:ui';

import 'package:flutter/widgets.dart';
// Narrowed on purpose. Everything else here is built out of `widgets`, and the
// one thing this file needs from Material is the spinner — there is no
// widgets-level progress indicator. A `show` clause says that out loud instead
// of quietly opening the whole library to whoever edits next.
import 'package:flutter/material.dart' show CircularProgressIndicator;

import '../keyboard/focusable_tap.dart';

/// Chrome that floats over a photograph — the camera preview and the post-
/// capture editor share it, so the two screens read as one surface.
///
/// Deliberately **not** [LiquidGlass]. That widget frosts with `theme.surface`
/// and strokes with `theme.accent`, which is right everywhere it is used — over
/// the app's own backgrounds, where the theme *is* the backdrop. Here the
/// backdrop is an arbitrary photograph: a pale theme's glass over a bright sky
/// disappears completely. So the chrome is fixed neutral dark and the theme
/// speaks only through [PhotoChrome.accent]-tinted state — the send button, the
/// armed pen, a selected chip. Legibility is not negotiable; identity is
/// expressed where there is contrast to spare.
class PhotoChrome {
  const PhotoChrome._();

  /// Translucent white fill over the blur. Reads as glass on any photo.
  static const fill = Color(0x2BFFFFFF);
  static const fillPressed = Color(0x3DFFFFFF);

  /// Hairline that separates the glass from whatever is behind it. Without it
  /// a button over a light photo has no edge at all.
  static const stroke = Color(0x33FFFFFF);

  static const ink = Color(0xFFFFFFFF);
  static const inkDim = Color(0x8AFFFFFF);
  static const inkDisabled = Color(0x4DFFFFFF);

  /// Every glass surface on these screens blurs by the same amount, so a row of
  /// them reads as one pane of glass rather than a row of unrelated buttons.
  static const blurSigma = 20.0;

  static const shadow = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 14,
    offset: Offset(0, 4),
  );
}

/// The one spinner the photo screens use.
///
/// Was copy-pasted verbatim in three places — the camera preview, the post-
/// capture editor and the avatar cropper — each spelling out the same
/// `SizedBox(22, 22)` wrapping a `strokeWidth: 2` indicator. Three copies of a
/// number is three chances for one of them to drift, and a spinner that is 22pt
/// on one screen and 24 on the next is exactly the kind of difference nobody
/// notices and everybody feels.
///
/// [value] is null for indeterminate — the usual case, where there is nothing to
/// count. Pass 0..1 where the work reports itself honestly: an upload that knows
/// how many bytes have gone out. Never pass a made-up number; a bar that moves
/// on a timer is worse than one that admits it doesn't know.
class PhotoSpinner extends StatelessWidget {
  const PhotoSpinner({super.key, this.size = 22, this.color, this.value});

  final double size;

  /// Defaults to [PhotoChrome.inkDim] — legible over any photograph, quiet
  /// enough not to compete with it. Pass `theme.accent` on the surfaces that
  /// aren't over a photo.
  final Color? color;

  /// 0..1, or null for indeterminate.
  final double? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: 2,
        color: color ?? PhotoChrome.inkDim,
      ),
    );
  }
}

/// A circular glass icon button.
///
/// No `IconButton`, no ink, no ripple — bare [GestureDetector] plus
/// [FocusableTap], which is how every control in this app is built.
class PhotoGlassButton extends StatefulWidget {
  const PhotoGlassButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.size = 40,
    this.iconSize = 19,
    this.tint,
    this.iconColor,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  /// Solid fill instead of glass — for a control that is *on* (the armed pen,
  /// an active toggle). Null keeps it neutral.
  final Color? tint;

  final Color? iconColor;

  @override
  State<PhotoGlassButton> createState() => _PhotoGlassButtonState();
}

class _PhotoGlassButtonState extends State<PhotoGlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final fg = widget.iconColor ??
        (enabled ? PhotoChrome.ink : PhotoChrome.inkDisabled);

    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.semanticLabel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: PhotoGlassSurface(
            shape: BoxShape.circle,
            tint: widget.tint,
            pressed: _pressed,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: Icon(widget.icon, size: widget.iconSize, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The frosted pane itself, without any tap handling — used directly for trays
/// and bars, and wrapped by [PhotoGlassButton] for controls.
class PhotoGlassSurface extends StatelessWidget {
  const PhotoGlassSurface({
    super.key,
    required this.child,
    this.shape = BoxShape.rectangle,
    this.radius = 999,
    this.tint,
    this.pressed = false,
    this.shadow = true,
  });

  final Widget child;
  final BoxShape shape;
  final double radius;
  final Color? tint;
  final bool pressed;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final circle = shape == BoxShape.circle;
    final border = circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));

    final fill = tint ??
        (pressed ? PhotoChrome.fillPressed : PhotoChrome.fill);
    final strokeColor = tint == null
        ? PhotoChrome.stroke
        : Color.lerp(tint, const Color(0xFFFFFFFF), 0.25)!;

    // BackdropFilter.grouped shares one rasterization pass with every sibling
    // grouped filter under the same BackdropGroup — the camera and editor each
    // put ~8 of these on screen at once, so this is the difference between one
    // full-screen blur per frame and eight.
    final blurred = ClipPath(
      clipper: ShapeBorderClipper(shape: border),
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(
          sigmaX: PhotoChrome.blurSigma,
          sigmaY: PhotoChrome.blurSigma,
        ),
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: fill)),
            child,
          ],
        ),
      ),
    );

    // Stroke and shadow sit outside the clip so the shadow can cast past the
    // glass instead of being cut off at its own edge.
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: circle
            ? CircleBorder(side: BorderSide(color: strokeColor, width: 0.8))
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
                side: BorderSide(color: strokeColor, width: 0.8),
              ),
        shadows: shadow ? const [PhotoChrome.shadow] : null,
      ),
      child: blurred,
    );
  }
}

/// A capsule button with a label — the commit action (SEND, DONE).
class PhotoGlassPill extends StatefulWidget {
  const PhotoGlassPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tint,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Solid fill — pass `theme.accent` for the primary action.
  final Color? tint;
  final String? semanticLabel;

  @override
  State<PhotoGlassPill> createState() => _PhotoGlassPillState();
}

class _PhotoGlassPillState extends State<PhotoGlassPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final tint = widget.tint?.withValues(alpha: enabled ? 1 : 0.35);
    final fg = enabled ? PhotoChrome.ink : PhotoChrome.inkDisabled;

    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.semanticLabel ?? widget.label,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: PhotoGlassSurface(
            tint: tint,
            pressed: _pressed,
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                        // Explicit, not inherited: this chrome floats over a
                        // photo and must never fall back to Flutter's debug
                        // text style, which paints yellow underlines.
                        decoration: TextDecoration.none,
                      ),
                    ),
                    if (widget.icon != null) ...[
                      const SizedBox(width: 7),
                      Icon(widget.icon, size: 16, color: fg),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
