import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/text_case.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';
import 'spring_press.dart';

/// The fill of the app's chrome disc — every 40pt icon button on the app's
/// own pages and sheets (back, ×, compose, more).
///
/// Defined by the THEME, never by what is behind it: the user saw the sheet's
/// flat × and the page's frosted × side by side and read them as two
/// different buttons. One opaque colour, a step off the surface (an ink wash
/// on light palettes, a white one on dark), is the same disc on a page, a
/// sheet and a card.
Color chromeDiscFill(AppTheme theme) => theme.isLight
    ? Color.alphaBlend(theme.ink.withValues(alpha: 0.06), theme.surface)
    : Color.alphaBlend(Colors.white.withValues(alpha: 0.12), theme.surface);

/// THE icon button: a 40pt circle with a glyph — back, close, compose, more,
/// and every control floating over a photo or the camera.
///
/// [tone] picks the material. [GlassTone.app] draws the chrome disc (see
/// [chromeDiscFill]); [GlassTone.media] keeps real glass, because over an
/// arbitrary photo only a blur reads. [tint] makes it a solid, lit control
/// (an armed tool, an active toggle). A null [onTap] is a disabled button:
/// dimmed ink, no press, no focus stop.
///
/// [still] drops the disc's backdrop blur for anything that slides — a sheet,
/// a card, a row — so nothing re-rasterises on every frame of the rise. On a
/// page (the default) the blur stays, so a list scrolling under a bar button
/// frosts through it; at rest over a plain page the two look the same.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.size = 40,
    this.iconSize = 19,
    this.color,
    this.tone = GlassTone.app,
    this.tint,
    this.still = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double size;
  final double iconSize;

  /// The glyph's colour. Defaults to the tone's ink (dimmed when disabled).
  final Color? color;
  final GlassTone tone;
  final Color? tint;

  /// No backdrop blur: for a disc on a sheet, a card, anything that moves.
  /// Ignored by [GlassTone.media], which is always glass.
  final bool still;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    if (tone == GlassTone.media) {
      final ink = color ?? (enabled ? MediaGlass.ink : MediaGlass.inkDisabled);
      return Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        child: LiquidGlass(
          size: Size(size, size),
          tone: tone,
          tint: tint,
          onTap: onTap,
          child: Icon(icon, size: iconSize, color: ink),
        ),
      );
    }
    final theme = ThemeScope.of(context);
    final ink = color ??
        (tint != null
            ? theme.accentInk
            : (enabled ? theme.ink : theme.inkMuted));
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: ChromeDisc(
        size: size,
        still: still,
        tint: tint,
        onTap: onTap,
        child: Icon(icon, size: iconSize, color: ink),
      ),
    );
  }
}

/// The chrome disc itself, for the one button that is not a
/// [GlassIconButton] but must read as one (the sheet's accent ✓ wears the
/// rim and shadow over its own fill — see `SheetConfirmButton`).
///
/// Layers, bottom up: an optional backdrop blur (live only), the opaque
/// [chromeDiscFill] (86% when live, so the blur shows), a top highlight, the
/// pressed light, the glyph; [SpecularRim] and a soft shadow outside. The
/// blur is never animated — the disc only ever scales under a finger, and a
/// still disc has no blur at all.
class ChromeDisc extends StatelessWidget {
  const ChromeDisc({
    super.key,
    required this.child,
    this.size = 40,
    this.still = false,
    this.tint,
    this.onTap,
  });

  final Widget child;
  final double size;
  final bool still;

  /// A solid fill instead of the theme disc — a control that is ON.
  final Color? tint;

  /// Null draws it inert (no press, no focus stop).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget surface(bool pressed) => _surface(context, pressed);
    if (onTap == null) return surface(false);
    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: 0.94,
      focusShape: FocusRingShape.circle,
      focusRadius: size / 2,
      builder: (context, pressed) => surface(pressed),
    );
  }

  Widget _surface(BuildContext context, bool pressed) {
    final theme = ThemeScope.of(context);
    final light = theme.isLight;
    final t = tint;
    final live = !still && t == null;
    final fill = t ?? chromeDiscFill(theme);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: light ? 0.10 : 0.30),
              blurRadius: light ? 10 : 12,
              offset: Offset(0, light ? 1 : 3),
            ),
          ],
        ),
        child: CustomPaint(
          foregroundPainter: SpecularRim(
            shape: const CircleBorder(),
            light: light,
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (live)
                  BackdropFilter.grouped(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: const SizedBox.expand(),
                  ),
                ColoredBox(
                  color: live ? fill.withValues(alpha: 0.86) : fill,
                ),
                if (t == null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: light ? 0.35 : 0.08),
                          // Transparent WHITE, not Colors.transparent: fading
                          // to transparent black lays a grey band across.
                          Colors.white.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.55],
                      ),
                    ),
                  ),
                if (pressed)
                  ColoredBox(
                    color: Colors.white.withValues(alpha: light ? 0.18 : 0.06),
                  ),
                Center(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The back control every pushed page wears: a chrome disc with a chevron,
/// iOS 26's toolbar treatment.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({
    super.key,
    this.onTap,
    this.tone = GlassTone.app,
    this.semanticLabel,
    this.enabled = true,
    this.still = false,
  });

  final VoidCallback? onTap;
  final GlassTone tone;
  final String? semanticLabel;

  /// False draws it dimmed and inert (a capture in flight, say).
  final bool enabled;

  /// See [GlassIconButton.still].
  final bool still;

  @override
  Widget build(BuildContext context) => GlassIconButton(
        icon: CupertinoIcons.chevron_back,
        iconSize: 20,
        tone: tone,
        still: still,
        semanticLabel: semanticLabel ??
            MaterialLocalizations.of(context).backButtonTooltip,
        onTap: enabled
            ? onTap ?? () => Navigator.of(context).maybePop()
            : null,
      );
}

/// THE × of the app: a chrome disc with a 17pt glyph, 40pt.
///
/// One button everywhere — a full-screen surface wears it top-leading, and a
/// sheet's bar draws this same widget (`SheetCloseButton` is it with
/// [still]). A pushed page has no ×; it has a back chevron.
class GlassCloseButton extends StatelessWidget {
  const GlassCloseButton({
    super.key,
    this.onTap,
    this.semanticLabel,
    this.tone = GlassTone.app,
    this.enabled = true,
    this.still = false,
  });

  /// Defaults to popping the route.
  final VoidCallback? onTap;
  final String? semanticLabel;
  final GlassTone tone;

  /// False draws it dimmed and inert (a save in flight, say) — a null
  /// [onTap] cannot say that, since it means "pop".
  final bool enabled;

  /// See [GlassIconButton.still]. True on sheets and cards.
  final bool still;

  @override
  Widget build(BuildContext context) => GlassIconButton(
        icon: CupertinoIcons.xmark,
        iconSize: 17,
        tone: tone,
        still: still,
        semanticLabel: semanticLabel ??
            MaterialLocalizations.of(context).closeButtonLabel,
        onTap: enabled
            ? onTap ?? () => Navigator.of(context).maybePop()
            : null,
      );
}

/// A glass capsule with a label — the commit action floating over content
/// (Send, Done, Use photo). Pass [tint] (usually the accent) for the primary
/// action. Labels authored in capitals are read in sentence case.
///
/// 40pt tall by default, the height of every glass icon button, so a pill
/// and the buttons beside it sit on one line (the editor's 44pt Send stood
/// proud of its 38/40pt neighbours). Label 17/w600, the button scale.
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tint,
    this.tone = GlassTone.app,
    this.semanticLabel,
    this.height = 40,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? tint;
  final GlassTone tone;
  final String? semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Color ink;
    if (tone == GlassTone.media) {
      ink = enabled ? MediaGlass.ink : MediaGlass.inkDisabled;
    } else {
      final theme = ThemeScope.of(context);
      ink = tint != null
          ? theme.accentInk
          : (enabled ? theme.ink : theme.inkMuted);
    }
    final t = tint?.withValues(alpha: enabled ? 1 : 0.35);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: LiquidGlass(
        shape: LiquidGlassShape.capsule,
        tone: tone,
        tint: t,
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sentenceCaseOf(context, label),
                  style: TextStyle(
                    color: ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    // Explicit, not inherited: this chrome can float over a
                    // photo outside any Material, and must never fall back to
                    // Flutter's debug text style (yellow underlines).
                    decoration: TextDecoration.none,
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 7),
                  Icon(icon, size: 17, color: ink),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
