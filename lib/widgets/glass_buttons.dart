import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/app_shortcuts.dart';
import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/text_case.dart';
import '../theme/app_theme.dart';
import '../theme/density.dart';
import '../theme/layout.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'hover_hint.dart';
import 'liquid_glass.dart';
import 'route_depth.dart';
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
///
/// On desktop and web the [semanticLabel] doubles as a [HoverHint], with
/// [shortcut]'s keys after it. An app-tone button with no explicit [size]
/// follows [Density]: 40pt on a phone, 32pt in the compact desktop layout,
/// its glyph scaled with it.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.size,
    this.iconSize = 19,
    this.color,
    this.tone = GlassTone.app,
    this.tint,
    this.still = false,
    this.shortcut,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Null follows [Density] (app tone) or 40 (media tone, which floats over
  /// photos and keeps its size everywhere).
  final double? size;

  /// The glyph as drawn on a 40pt disc; scaled with the disc when [size]
  /// follows [Density].
  final double iconSize;

  /// The keyboard shortcut that does the same thing, shown in the hover hint.
  final ShortcutDef? shortcut;

  /// The glyph's colour. Defaults to the tone's ink (dimmed when disabled).
  final Color? color;
  final GlassTone tone;
  final Color? tint;

  /// No backdrop blur: for a disc on a sheet, a card, anything that moves.
  /// [GlassTone.media] keeps its look and only drops the blur.
  final bool still;

  @override
  Widget build(BuildContext context) => HoverHint(
        label: semanticLabel,
        shortcut: shortcut,
        enabled: onTap != null,
        child: _button(context),
      );

  Widget _button(BuildContext context) {
    final enabled = onTap != null;
    final dense = this.size == null && tone == GlassTone.app
        ? Density.of(context)
        : Density.regular;
    final size = this.size ?? dense.iconButton;
    final iconSize = dense.iconGlyph(this.iconSize);
    // Real glass on pages, as it shipped in 1.3.114 — the user preferred it
    // to the opaque disc this briefly became. Only a [still] button (on a
    // sheet or card, which slide) draws the blur-free [ChromeDisc].
    if (tone == GlassTone.app && !still) {
      final theme = ThemeScope.of(context);
      final ink = color ??
          (tint != null
              ? theme.accentInk
              : (enabled ? theme.ink : theme.inkMuted));
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
          still: still,
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
///
/// On the desktop split shell it turns into the × whenever leaving the page
/// closes something rather than going back to an earlier page: a chat in the
/// right pane, a settings page, room info beside a chat, a full-window page
/// over the shell. There, the list the user came from is still on screen
/// beside it, and a chevron pointing at it is a phone's idea. A page pushed
/// deeper (settings, then a page inside it) keeps its chevron, because there
/// "back" is what happens. Decided by [closes], or by [RouteDepthObserver]
/// when that is null.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({
    super.key,
    this.onTap,
    this.tone = GlassTone.app,
    this.semanticLabel,
    this.enabled = true,
    this.still = false,
    this.shortcut,
    this.closes,
  });

  /// Draw the × instead of the chevron. Null decides by itself: the × on the
  /// split shell for a page pushed straight over its navigator's base, and
  /// only when [onTap] is the default pop (a custom [onTap] may step back
  /// through the page's own states, so its caller says).
  final bool? closes;

  /// Whether a back button here leaves the page by closing it. See
  /// [GlassBackButton]; shared so a page drawing its own back control can ask
  /// the same question.
  static bool closesHere(BuildContext context) {
    if (!context.usesSplitShell) return false;
    return RouteDepthObserver.of(ModalRoute.of(context)) == 1;
  }

  final VoidCallback? onTap;
  final GlassTone tone;
  final String? semanticLabel;

  /// False draws it dimmed and inert (a capture in flight, say).
  final bool enabled;

  /// See [GlassIconButton.still].
  final bool still;

  /// Shown in the hover hint. Defaults to Esc when the button does the
  /// default pop, which is exactly what Esc does on any pushed route
  /// (`EscapeToPop`); a custom [onTap] may do more than pop, so it shows
  /// keys only when the caller says which.
  final ShortcutDef? shortcut;

  @override
  Widget build(BuildContext context) {
    final asClose = closes ?? (onTap == null && closesHere(context));
    final labels = MaterialLocalizations.of(context);
    return GlassIconButton(
      icon: asClose ? CupertinoIcons.xmark : CupertinoIcons.chevron_back,
      iconSize: asClose ? 17 : 20,
      tone: tone,
      still: still,
      shortcut: shortcut ?? (onTap == null ? AppShortcuts.back : null),
      semanticLabel: semanticLabel ??
          (asClose ? labels.closeButtonLabel : labels.backButtonTooltip),
      onTap: enabled
          ? onTap ?? () => Navigator.of(context).maybePop()
          : null,
    );
  }
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
    this.shortcut,
  });

  /// Defaults to popping the route.
  final VoidCallback? onTap;
  final String? semanticLabel;
  final GlassTone tone;

  /// Shown in the hover hint; Esc by default when [onTap] is the default pop.
  /// See [GlassBackButton.shortcut].
  final ShortcutDef? shortcut;

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
        shortcut: shortcut ?? (onTap == null ? AppShortcuts.back : null),
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
/// proud of its 38/40pt neighbours). Label 17/w600, the button scale. An
/// app-tone pill with no explicit [height] follows [Density] the way the
/// icon button does, so the pair stays level in the compact layout too.
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tint,
    this.tone = GlassTone.app,
    this.semanticLabel,
    this.height,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? tint;
  final GlassTone tone;
  final String? semanticLabel;

  /// Null follows [Density] (app tone) or 40 (media tone).
  final double? height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final dense = this.height == null && tone == GlassTone.app
        ? Density.of(context)
        : Density.regular;
    final height = this.height ?? dense.iconButton;
    final type = dense.compact ? 15.0 : 17.0;
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
            padding: EdgeInsets.symmetric(horizontal: dense.compact ? 16 : 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sentenceCaseOf(context, label),
                  style: TextStyle(
                    color: ink,
                    fontSize: type,
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
                  Icon(icon, size: type, color: ink),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One slot in a [GlassButtonGroup]: a glyph or a short label ("HD", "1").
class GlassGroupItem {
  const GlassGroupItem({
    this.icon,
    this.text,
    required this.semanticLabel,
    required this.onTap,
    this.active = false,
    this.color,
  }) : assert(icon != null || text != null);

  final IconData? icon;
  final String? text;

  /// Carries the on/off state too ("HD: on"), so the slot needs no toggled
  /// semantics of its own.
  final String semanticLabel;

  /// Null draws the slot dimmed and inert.
  final VoidCallback? onTap;

  /// Lit with the accent — an armed pen, view-once on, HD on.
  final bool active;

  /// The glyph's colour when it is not lit — the toolbar's red Delete.
  final Color? color;
}

/// Related controls sharing one capsule of glass, the iOS 26 way: grouped by
/// shape, never by rules between the glyphs. A group of one is just the 40pt
/// disc every other button is.
///
/// THE grouped pill — the photo composer's tools, its add buttons, undo/redo,
/// and the middle of a viewer's toolbar are all this, so a group looks the
/// same wherever it appears.
///
/// [still] drops the blur, for chrome that fades (a viewer's). [haptic] is
/// the press's own tick; turn it off where every action plays its own, or the
/// two land on top of each other.
class GlassButtonGroup extends StatelessWidget {
  const GlassButtonGroup({
    super.key,
    required this.items,
    this.tone = GlassTone.media,
    this.still = false,
    this.haptic = true,
    this.accent,
  });

  final List<GlassGroupItem> items;
  final GlassTone tone;
  final bool still;
  final bool haptic;

  /// The lit slot's fill. Defaults to the theme's accent.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final lit = accent ?? theme.accent;
    return LiquidGlass(
      tone: tone,
      still: still,
      shape: LiquidGlassShape.capsule,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: items.length > 1 ? 2 : 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final item in items) _slot(item, lit, theme)],
        ),
      ),
    );
  }

  Widget _slot(GlassGroupItem item, Color lit, AppTheme theme) {
    final enabled = item.onTap != null;
    final media = tone == GlassTone.media;
    final Color ink;
    if (item.active) {
      ink = theme.accentInk;
    } else if (!enabled) {
      ink = media ? MediaGlass.inkDisabled : theme.inkMuted;
    } else {
      ink = item.color ?? (media ? MediaGlass.ink : theme.ink);
    }
    final glyph = item.icon != null
        ? Icon(item.icon, size: 19, color: ink)
        : Text(
            item.text!,
            style: TextStyle(
              color: ink,
              fontSize: item.text!.length > 1 ? 13 : 15,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: 0.2,
              decoration: TextDecoration.none,
            ),
          );
    // The label carries the state too ("HD: on"), which is just what a hover
    // should say about a glyph.
    return HoverHint(
      label: item.semanticLabel,
      enabled: enabled,
      child: _slotPress(item, glyph, lit),
    );
  }

  Widget _slotPress(GlassGroupItem item, Widget glyph, Color lit) {
    return SpringPress(
      onTap: item.onTap,
      semanticLabel: item.semanticLabel,
      scale: PressSpec.scaleSmall,
      focusShape: FocusRingShape.circle,
      focusRadius: 20,
      haptic: haptic,
      child: SizedBox(
        width: items.length > 1 ? 44 : 40,
        height: 40,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.active ? lit : const Color(0x00000000),
              shape: BoxShape.circle,
            ),
            child: glyph,
          ),
        ),
      ),
    );
  }
}
