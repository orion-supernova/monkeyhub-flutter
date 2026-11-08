import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../keyboard/app_shortcuts.dart';
import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/text_case.dart';
import '../theme/app_theme.dart';
import '../theme/density.dart';
import '../theme/layout.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../ui/foundation/ui_kit.dart';
import '../ui/native/native_control.dart';
import '../ui/kits/material/material_kit_theme.dart';
import '../ui/kits/shader/shader_skin.dart';
import 'hover_hint.dart';
import 'liquid_glass.dart';
import 'route_depth.dart';
import 'spring_press.dart';
import 'sunlit_surface.dart' show sunlitHairline;

/// The fill of the app's chrome disc — every 44pt icon button on the app's
/// own pages and sheets (back, ×, compose, more).
///
/// Defined by the THEME, never by what is behind it: the user saw the sheet's
/// flat × and the page's frosted × side by side and read them as two
/// different buttons. One opaque colour, a step off the surface (an ink wash
/// on light palettes, a white one on dark), is the same disc on a page, a
/// sheet and a card.
Color chromeDiscFill(AppTheme theme) => plateFill(theme);

/// THE icon button: a 44pt circle with a glyph — back, close, compose, more,
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
/// follows [Density]: 44pt on a phone, 32pt in the compact desktop layout,
/// its glyph scaled with it.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    this.icon,
    this.glyph,
    required this.onTap,
    this.semanticLabel,
    this.size,
    this.iconSize = 20,
    this.color,
    this.tone = GlassTone.app,
    this.tint,
    this.still = false,
    this.shortcut,
  }) : assert(icon != null || glyph != null);

  final IconData? icon;

  /// A drawn glyph in place of [icon], for a control whose glyph moves (the
  /// call screen's Minimize). Sized and inked by the caller.
  final Widget? glyph;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Null follows [Density] (app tone) or 44 (media tone, which floats over
  /// photos and keeps its size everywhere).
  final double? size;

  /// The glyph as drawn on the 44pt phone disc; scaled down with it when [size]
  /// follows [Density] into the compact layout.
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

  /// The [UiKit.material] skin: `IconButton.filledTonal` (or `.filled` when
  /// [tint]ed), the glyph a step larger than Cupertino's, with a ripple.
  Widget _materialButton(BuildContext context, double size, double iconSize) {
    final enabled = onTap != null;
    final shape = Size.square(size);
    final style = ButtonStyle(
      fixedSize: WidgetStatePropertyAll(shape),
      minimumSize: WidgetStatePropertyAll(shape),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: color == null ? null : WidgetStatePropertyAll(color),
    );
    final glyphSize = (iconSize * 1.2).roundToDouble();
    final child = glyph ?? Icon(icon, size: glyphSize);
    final onPressed = enabled ? onTap : null;
    final button = tint != null
        ? IconButton.filled(
            onPressed: onPressed,
            iconSize: glyphSize,
            style: style.copyWith(
              backgroundColor: WidgetStatePropertyAll(tint),
              foregroundColor:
                  WidgetStatePropertyAll(color ?? ThemeScope.of(context).accentInk),
            ),
            icon: child,
          )
        : IconButton.filledTonal(
            onPressed: onPressed,
            iconSize: glyphSize,
            style: style,
            icon: child,
          );
    return MaterialKitScope(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: button,
      ),
    );
  }

  Widget _button(BuildContext context) {
    final enabled = onTap != null;
    final dense = this.size == null && tone == GlassTone.app
        ? Density.of(context)
        : Density.regular;
    final size = this.size ?? dense.iconButton;
    final iconSize = dense.iconGlyph(this.iconSize);
    final kit = UiKit.of(context);
    if (tone == GlassTone.app && kit == UiKit.material) {
      return _materialButton(context, size, iconSize);
    }
    // The liquid kit's real iOS 26 button, when the glyph has an exact SF
    // Symbol and nothing custom is drawn on the disc.
    final symbol = glyph == null && tint == null ? sfSymbolFor(icon) : null;
    if (tone == GlassTone.app &&
        kit == UiKit.liquid &&
        NativeControl.readyIn(context) &&
        symbol != null) {
      return NativeControl(
        standIn: FlutterSkinsOnly(child: Builder(builder: build)),
        size: Size.square(size),
        spec: NativeSpec.symbolButton(
          symbol: symbol,
          label: semanticLabel ?? '',
          enabled: enabled,
          size: size,
          symbolSize: size * 17 / 44,
        ),
        onEvent: (event, _) {
          if (event == 'tap') onTap?.call();
        },
      );
    }
    // The shader kit's own GlassButton: clear iOS 27 glass with the package's
    // jelly press and glow. A still disc (on a sheet or card, which slide)
    // keeps the blur-free chrome disc below.
    if (tone == GlassTone.app && kit == UiKit.shader && !still) {
      final theme = ThemeScope.of(context);
      final ink = color ??
          (tint != null
              ? theme.accentInk
              : (enabled ? theme.ink : theme.inkMuted));
      return ShaderSkin.button(
        context,
        width: size,
        height: size,
        tint: tint,
        label: semanticLabel ?? '',
        onTap: onTap,
        child: glyph ?? Icon(icon, size: iconSize, color: ink),
      );
    }
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
          child: glyph ?? Icon(icon, size: iconSize, color: ink),
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
          child: glyph ?? Icon(icon, size: iconSize, color: ink),
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
        child: glyph ?? Icon(icon, size: iconSize, color: ink),
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
    this.size = 44,
    this.still = false,
    this.tint,
    this.onTap,
  })  : radius = null,
        pressScale = PressSpec.bloom,
        semanticLabel = null;

  /// The same chrome in a rounded rectangle that sizes to [child]: an action
  /// tile on a sheet or a profile reads as the × above it, one material.
  const ChromeDisc.plate({
    super.key,
    required this.child,
    required double this.radius,
    this.still = false,
    this.tint,
    this.onTap,
    this.semanticLabel,
    this.pressScale = PressSpec.scaleSmall,
  }) : size = 0;

  final Widget child;

  /// The disc's diameter. Unused by [ChromeDisc.plate], which hugs [child].
  final double size;

  /// Null draws a disc; set, a plate with this corner radius.
  final double? radius;

  /// Scale while held: discs bloom, plates (a large target) settle.
  final double pressScale;
  final String? semanticLabel;
  final bool still;

  /// A solid fill instead of the theme disc — a control that is ON.
  final Color? tint;

  /// Null draws it inert (no press, no focus stop).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (UiKit.of(context) == UiKit.material) return _tonalDisc(context);
    Widget surface(bool pressed) => _surface(context, pressed);
    if (onTap == null) return surface(false);
    final r = radius;
    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: pressScale,
      semanticLabel: semanticLabel,
      focusShape: r == null ? FocusRingShape.circle : FocusRingShape.rounded,
      focusRadius: r ?? size / 2,
      builder: (context, pressed) => surface(pressed),
    );
  }

  OutlinedBorder get _shape {
    final r = radius;
    return r == null
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
  }

  /// A disc has a fixed size; a plate takes its child's.
  Widget _sized(Widget child) => radius != null
      ? child
      : SizedBox(width: size, height: size, child: child);

  /// The [UiKit.material] disc: a tonal circle (filled when [tint]ed) with a
  /// ripple. No blur, no rim, a flat Material surface.
  Widget _tonalDisc(BuildContext context) {
    final scheme = MaterialKitTheme.of(ThemeScope.of(context)).colorScheme;
    final tap = onTap;
    return MaterialKitScope(
      child: _sized(
        Material(
          color: tint ?? scheme.secondaryContainer,
          shape: _shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tap,
            customBorder: _shape,
            child: radius == null ? Center(child: child) : child,
          ),
        ),
      ),
    );
  }

  Widget _surface(BuildContext context, bool pressed) {
    final theme = ThemeScope.of(context);
    final light = theme.isLight;
    final t = tint;
    final live = !still && t == null && UiKit.of(context).blurs;
    final fill = t ?? chromeDiscFill(theme);
    final shape = _shape;
    return _sized(
      // Shadow painted after the disc, outside it: under it, the disc's own
      // backdrop blur smeared it into a grey ring (see GlassShadow).
      GlassShadow(
        shape: shape,
        shadows: [
            BoxShadow(
              color: (light ? theme.ink : Colors.black)
                  .withValues(alpha: light ? 0.12 : 0.30),
              blurRadius: light ? 10 : 12,
              offset: Offset(0, light ? 3 : 3),
            ),
            // Light: a contact shadow too, the edge a pale disc needs.
            if (light)
              BoxShadow(
                color: theme.ink.withValues(alpha: 0.06),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
          ],
        child: CustomPaint(
          foregroundPainter: SpecularRim(
            shape: shape,
            light: light,
            edge: light ? sunlitHairline(theme) : null,
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: Stack(
              // A disc fills its fixed square; a plate sizes to its content,
              // which is the one non-positioned layer.
              fit: radius == null ? StackFit.expand : StackFit.passthrough,
              children: [
                if (live)
                  Positioned.fill(
                    child: BackdropFilter.grouped(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: const SizedBox.expand(),
                    ),
                  ),
                Positioned.fill(
                  child: ColoredBox(
                    color: live ? fill.withValues(alpha: 0.86) : fill,
                  ),
                ),
                if (t == null)
                  Positioned.fill(child: DecoratedBox(
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
                  )),
                if (pressed)
                  Positioned.fill(
                    child: ColoredBox(
                      color:
                          Colors.white.withValues(alpha: light ? 0.18 : 0.06),
                    ),
                  ),
                if (radius == null) Center(child: child) else child,
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
      icon: asClose
          ? kitValue(UiKit.of(context),
              glass: CupertinoIcons.xmark, material: Icons.close)
          : kitValue(UiKit.of(context),
              glass: CupertinoIcons.chevron_back, material: Icons.arrow_back),
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

/// THE × of the app: a chrome disc with a 17pt glyph, 44pt.
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
    this.size,
    this.iconSize = 17,
  });

  /// Null follows [GlassIconButton.size].
  final double? size;

  /// The × as drawn on a 44pt disc; shrink it with a smaller [size].
  final double iconSize;

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
        icon: kitValue(UiKit.of(context),
            glass: CupertinoIcons.xmark, material: Icons.close),
        iconSize: iconSize,
        size: size,
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
/// 44pt tall by default, the height of every glass icon button, so a pill
/// and the buttons beside it sit on one line (the editor's 44pt Send stood
/// proud of its 38/40pt neighbours). Label 17/w500 with 16pt side padding, as Signal's "Edit". An
/// app-tone pill with no explicit [height] follows [Density] the way the
/// icon button does, so the pair stays level in the compact layout too.
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.glyph,
    this.color,
    this.tint,
    this.tone = GlassTone.app,
    this.semanticLabel,
    this.height,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// A drawn glyph before the label, for one that animates: a toggle's state
  /// reads first, as iOS puts it. Sized and coloured by the caller.
  final Widget? glyph;

  /// The label's colour. Defaults to the tone's ink (dimmed when disabled).
  final Color? color;
  final Color? tint;
  final GlassTone tone;
  final String? semanticLabel;

  /// Null follows [Density] (app tone) or 44 (media tone).
  final double? height;

  /// The [UiKit.material] skin: `FilledButton.tonal` (filled when [tint]ed).
  Widget _materialPill(BuildContext context, double height, double type) {
    final enabled = onTap != null;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      fixedSize: WidgetStatePropertyAll(Size.fromHeight(height)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: WidgetStatePropertyAll(
        ThemeScope.of(context).body.copyWith(
          fontSize: type - 1,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      foregroundColor: color == null ? null : WidgetStatePropertyAll(color),
    );
    final text = Text(sentenceCaseOf(context, label));
    final lead = glyph ?? (icon != null ? Icon(icon, size: type + 1) : null);
    final t = tint;
    final button = t != null
        ? FilledButton(
            onPressed: onTap,
            style: style.copyWith(
              backgroundColor: WidgetStatePropertyAll(t),
              foregroundColor: WidgetStatePropertyAll(
                  color ?? ThemeScope.of(context).accentInk),
            ),
            child: _pillRow(lead, text),
          )
        : FilledButton.tonal(
            onPressed: onTap,
            style: style,
            child: _pillRow(lead, text),
          );
    return MaterialKitScope(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel ?? label,
        excludeSemantics: true,
        child: button,
      ),
    );
  }

  Widget _pillRow(Widget? lead, Widget text) => lead == null
      ? text
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [lead, const SizedBox(width: 8), text],
        );

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final dense = this.height == null && tone == GlassTone.app
        ? Density.of(context)
        : Density.regular;
    final height = this.height ?? dense.iconButton;
    final type = dense.compact ? 15.0 : 17.0;
    final Color ink;
    if (color != null) {
      ink = color!;
    } else if (tone == GlassTone.media) {
      ink = enabled ? MediaGlass.ink : MediaGlass.inkDisabled;
    } else {
      final theme = ThemeScope.of(context);
      ink = tint != null
          ? theme.accentInk
          : (enabled ? theme.ink : theme.inkMuted);
    }
    final t = tint?.withValues(alpha: enabled ? 1 : 0.35);
    if (tone == GlassTone.app && UiKit.of(context) == UiKit.material) {
      return _materialPill(context, height, type);
    }
    // The liquid kit's real glass button, for a plain label (no drawn glyph,
    // no custom ink or tint, which the system button cannot carry).
    if (tone == GlassTone.app &&
        glyph == null &&
        color == null &&
        icon == null &&
        NativeControl.readyIn(context)) {
      return NativeControl(
        standIn: FlutterSkinsOnly(child: Builder(builder: build)),
        size: nativeButtonSize(
          context,
          sentenceCaseOf(context, label),
          height: height,
        ),
        spec: NativeSpec.button(
          label: sentenceCaseOf(context, label),
          prominent: tint != null,
          enabled: enabled,
          height: height,
        ),
        onEvent: (event, _) {
          if (event == 'tap') onTap?.call();
        },
      );
    }
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            glyph!,
            const SizedBox(width: 8),
          ],
          Text(
            sentenceCaseOf(context, label),
            style: TextStyle(
              color: ink,
              fontSize: type,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
              // Explicit, not inherited: this chrome can float over a
              // photo outside any Material, and must never fall back to
              // Flutter's debug text style (yellow underlines).
              decoration: TextDecoration.none,
            ),
          ),
          if (icon != null && glyph == null) ...[
            const SizedBox(width: 7),
            Icon(icon, size: type, color: ink),
          ],
        ],
      ),
    );
    if (tone == GlassTone.app && UiKit.of(context) == UiKit.shader) {
      return ShaderSkin.button(
        context,
        shape: ShaderSkin.capsule,
        height: height,
        tint: t,
        label: semanticLabel ?? label,
        onTap: onTap,
        child: body,
      );
    }
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
          child: body,
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
    this.glyph,
    required this.semanticLabel,
    required this.onTap,
    this.active = false,
    this.color,
  }) : assert(icon != null || text != null || glyph != null);

  final IconData? icon;
  final String? text;

  /// A drawn glyph that carries its own state (a toggle that morphs rather
  /// than lighting up), in place of [icon] or [text]. Sized and inked by the
  /// caller; the slot gives it no accent fill, so leave [active] off.
  final Widget? glyph;

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
/// shape, never by rules between the glyphs. A group of one is just the 44pt
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
  Widget build(BuildContext context) => KitSwitch(
    glass: _glass,
    liquid: NativeControl.readyIn(context) && _hasNativeForm(context)
        ? _liquid
        : null,
    // Over photos (media tone) the group keeps its own dark recipe.
    shader: tone == GlassTone.app ? _shader : null,
  );

  /// The [UiKit.shader] skin: the package's merged button group. Each slot is
  /// the same lit disc / glyph / label the glass skin draws, so a lit slot
  /// still reads; the capsule takes the jelly press.
  Widget _shader(BuildContext context) {
    final theme = ThemeScope.of(context);
    final lit = accent ?? theme.accent;
    return ShaderSkin.group(
      context,
      slots: [
        for (final item in items)
          (
            widget: _slotFace(item, lit, theme),
            onTap: item.onTap == null
                ? null
                : () {
                    if (haptic) HapticFeedback.selectionClick();
                    item.onTap!();
                  },
            label: item.semanticLabel,
          ),
      ],
    );
  }

  /// Native only when every slot is a plain symbol: a lit slot, a text slot
  /// or a drawn glyph would lose information in the system capsule.
  bool _hasNativeForm(BuildContext context) {
    final danger = ThemeScope.of(context).danger;
    return items.isNotEmpty &&
        items.every(
          (i) =>
              i.glyph == null &&
              i.text == null &&
              !i.active &&
              sfSymbolFor(i.icon) != null &&
              (i.color == null || i.color == danger),
        );
  }

  Widget _liquid(BuildContext context) {
    final danger = ThemeScope.of(context).danger;
    return NativeControl(
      standIn: FlutterSkinsOnly(child: Builder(builder: build)),
      size: Size(items.length * 44.0, 44),
      spec: NativeSpec.buttonGroup(
        options: [
          for (var i = 0; i < items.length; i++)
            NativeOptionSpec(
              value: '$i',
              label: items[i].semanticLabel,
              symbol: sfSymbolFor(items[i].icon),
              disabled: items[i].onTap == null,
              destructive: items[i].color == danger,
            ),
        ],
      ),
      onEvent: (event, value) {
        if (event != 'select') return;
        final i = int.tryParse('$value');
        if (i == null || i < 0 || i >= items.length) return;
        if (haptic) HapticFeedback.selectionClick();
        items[i].onTap?.call();
      },
    );
  }

  Widget _glass(BuildContext context) {
    final theme = ThemeScope.of(context);
    final lit = accent ?? theme.accent;
    return LiquidGlass(
      tone: tone,
      still: still,
      shape: LiquidGlassShape.capsule,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final item in items) _slot(item, lit, theme)],
        ),
      ),
    );
  }

  Widget _slot(GlassGroupItem item, Color lit, AppTheme theme) {
    final enabled = item.onTap != null;
    final glyph = _glyphOf(item, theme);
    // The label carries the state too ("HD: on"), which is just what a hover
    // should say about a glyph.
    return HoverHint(
      label: item.semanticLabel,
      enabled: enabled,
      child: _slotPress(item, glyph, lit),
    );
  }

  /// The lit disc, glyph or label of a slot, 38pt, without the press wrapper.
  Widget _slotFace(GlassGroupItem item, Color lit, AppTheme theme) =>
      _lit(item, _glyphOf(item, theme), lit);

  Widget _glyphOf(GlassGroupItem item, AppTheme theme) {
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
    return item.glyph ??
        (item.icon != null
        ? Icon(item.icon, size: 20, color: ink)
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
          ));
  }

  Widget _lit(GlassGroupItem item, Widget glyph, Color lit) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: item.active ? lit : const Color(0x00000000),
          shape: BoxShape.circle,
        ),
        child: glyph,
      );

  Widget _slotPress(GlassGroupItem item, Widget glyph, Color lit) {
    return SpringPress(
      onTap: item.onTap,
      semanticLabel: item.semanticLabel,
      scale: PressSpec.bloom,
      focusShape: FocusRingShape.circle,
      focusRadius: 22,
      haptic: haptic,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: _lit(item, glyph, lit)),
      ),
    );
  }
}
