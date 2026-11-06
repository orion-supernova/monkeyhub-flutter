import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../ui/foundation/ui_kit.dart';
import 'ios_kit.dart' show groupedMetaStyle, quietFill, tileColor, TileTone;
import 'spring_press.dart';

/// What a [StatusPill] is saying, as a role. The colour is resolved from the
/// theme so a pill reads the same on every theme and a kit can restyle all of
/// them in one place.
enum StatusTone { accent, muted, soft, danger, success, warning, neutral }

/// How the pill is drawn around its content.
enum StatusFill {
  /// A hairline outline, no fill: the room badges (pinned, public, locked).
  outline,

  /// A neutral quiet plate with the tone on the glyph and words: a state that
  /// must not shout (a game's "Waiting").
  quiet,

  /// The tone itself at a low wash: a log level, a count of something.
  tint,

  /// A solid tone with its contrasting ink: "which one is live?".
  solid,

  /// No box at all: a glyph and a word, the iOS status line.
  none,
}

/// Where the pill sits. [media] is for a photo or video thumbnail: a dark
/// scrim with white words, because a themed plate can vanish into a picture.
enum StatusSurface { page, media }

/// THE read-only status pill: a small glyph, a short label, a rounded plate
/// around both, and (optionally) a sentence on tap saying what it means.
///
/// Behaviour lives here once: the label drops to the glyph when a slot is too
/// narrow (the words survive in Semantics and the tap tooltip), the tap
/// explains itself, a screen reader never meets a bare icon. Only the paint is
/// per kit ([_skin]), so Lite and the future Material kit restyle every pill in
/// one place. Pills that are buttons are not pills: use a chip or
/// RowPillButton. [onTap] is for "explain this" or "open the thing it names",
/// never for toggling.
///
/// [PinnedBadge], [MutedBadge] and the visibility family are presets over this.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    this.label,
    this.icon,
    this.iconWidget,
    this.tone = StatusTone.neutral,
    this.color,
    this.fill = StatusFill.outline,
    this.surface = StatusSurface.page,
    this.dense = false,
    this.iconOnly = false,
    this.dropLabelWhenTight = false,
    this.tooltip,
    this.explainOnTap = true,
    this.onTap,
    this.semanticLabel,
    this.iconSize,
    this.outlineAlpha,
    this.labelTone,
  }) : assert(label != null || icon != null || iconWidget != null);

  final String? label;
  final IconData? icon;

  /// A prebuilt glyph (an hourglass the theme draws itself), built at the
  /// size the pill asks for.
  final Widget Function(double size, Color color)? iconWidget;

  final StatusTone tone;

  /// An explicit ink, beating [tone] (a value the caller computed).
  final Color? color;
  final StatusFill fill;
  final StatusSurface surface;
  final bool dense;

  /// Glyph only. The label survives in Semantics and in the [tooltip].
  final bool iconOnly;

  /// Measure the label against the slot and drop it (not ellipsize it) when it
  /// cannot fit: a grid tile slot under 90px with a translated word.
  final bool dropLabelWhenTight;

  /// The full sentence behind the pill. Shown on tap while [explainOnTap] is
  /// on, and always given to a screen reader.
  final String? tooltip;

  /// Off for a pill inside a row that is itself one tap target: the tooltip
  /// would swallow the tap meant for the row.
  final bool explainOnTap;

  /// Opens the thing the pill names. Wins over the tooltip.
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double? iconSize;

  /// [StatusFill.outline] only: draws the outline in the tone at this alpha.
  /// Null keeps the theme's own hairline (an outline that is not announcing).
  final double? outlineAlpha;

  /// The label's tone when it differs from the glyph's (a quiet plate in a
  /// neutral word beside a coloured glyph).
  final StatusTone? labelTone;

  static Color resolve(AppTheme theme, StatusTone tone) => switch (tone) {
        StatusTone.accent => theme.accent,
        StatusTone.muted => theme.inkMuted,
        StatusTone.soft => theme.inkSoft,
        StatusTone.danger => theme.danger,
        StatusTone.success => theme.success,
        StatusTone.warning => tileColor(theme, TileTone.orange),
        StatusTone.neutral => theme.inkSoft,
      };

  /// The per-kit paint: the one place a kit restyles every pill.
  static _Skin _skin(UiKit kit) => kitValue<_Skin>(
        kit,
        glass: const _Skin(radius: 999, tintAlpha: 0.16),
        lite: const _Skin(radius: 999, tintAlpha: 0.16, opaque: true),
      );

  static const double _borderWidth = 1;

  bool _fits(BuildContext context, double maxWidth, double chrome,
      TextStyle style) {
    if (!maxWidth.isFinite) return true;
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return chrome + painter.width <= maxWidth;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final skin = _skin(UiKit.of(context));
    final media = surface == StatusSurface.media;
    final ink = color ?? resolve(theme, tone);
    final glyphInk = media && color == null && tone == StatusTone.neutral
        ? Colors.white
        : ink;
    final wordInk = media
        ? Colors.white
        : (color ??
            (labelTone != null ? resolve(theme, labelTone!) : ink));
    final boxed = fill != StatusFill.none;
    final outlined = fill == StatusFill.outline;

    final gap = dense ? 4.0 : 5.0;
    final labelledIcon = iconSize ?? (dense ? 10.0 : (boxed ? 12.0 : 16.0));
    final soloIcon = iconSize ?? (dense ? 15.0 : 18.0);
    final labelledPadding = !boxed
        ? EdgeInsets.zero
        : outlined
            ? EdgeInsets.symmetric(
                horizontal: dense ? 6 : 10, vertical: dense ? 3 : 5)
            : EdgeInsets.symmetric(
                horizontal: dense ? 6 : 8, vertical: dense ? 1.5 : 3);
    final soloPadding = !boxed
        ? EdgeInsets.zero
        : EdgeInsets.symmetric(
            horizontal: dense ? 5 : 7, vertical: dense ? 4 : 6);
    final hasIcon = icon != null || iconWidget != null;
    final border = outlined ? _borderWidth * 2 : 0.0;
    final chrome = labelledPadding.horizontal +
        border +
        (hasIcon ? labelledIcon + gap : 0);

    final style = groupedMetaStyle(theme).copyWith(
      fontWeight: FontWeight.w600,
      height: 1.1,
      color: wordInk,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget glyph(double size) => iconWidget != null
        ? iconWidget!(size, glyphInk)
        : Icon(icon, size: size, color: glyphInk);

    BoxDecoration? decoration() {
      if (!boxed) return null;
      if (media) {
        return BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(skin.radius),
        );
      }
      switch (fill) {
        case StatusFill.outline:
          return theme.chipDecoration(filled: false).copyWith(
                borderRadius: BorderRadius.circular(skin.radius),
                border: outlineAlpha == null
                    ? null
                    : Border.all(
                        color: ink.withValues(alpha: outlineAlpha!), width: 1),
              );
        case StatusFill.quiet:
          return BoxDecoration(
            color: quietFill(theme),
            borderRadius: BorderRadius.circular(skin.radius),
          );
        case StatusFill.tint:
          final wash = ink.withValues(alpha: skin.tintAlpha);
          return BoxDecoration(
            color: skin.opaque ? Color.alphaBlend(wash, theme.surface) : wash,
            borderRadius: BorderRadius.circular(skin.radius),
          );
        case StatusFill.solid:
          return BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(skin.radius),
          );
        case StatusFill.none:
          return null;
      }
    }

    // Ink on a solid plate: the theme's own contrast for its accent, white on
    // the semantic hues.
    final solidInk = tone == StatusTone.accent && color == null
        ? theme.accentInk
        : Colors.white;

    final semantics = semanticLabel ?? label ?? tooltip;

    Widget pill = LayoutBuilder(
      builder: (context, constraints) {
        final hasLabel = label != null && !iconOnly;
        final showLabel = hasLabel &&
            (!dropLabelWhenTight ||
                !hasIcon ||
                _fits(context, constraints.maxWidth, chrome, style));
        final solid = fill == StatusFill.solid && !media;
        final labelStyle = solid ? style.copyWith(color: solidInk) : style;
        final Widget text = constraints.maxWidth.isFinite && !dropLabelWhenTight
            ? Flexible(
                child: Text(label ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle),
              )
            : Text(label ?? '',
                maxLines: 1, softWrap: false, style: labelStyle);
        final glyphSize = showLabel ? labelledIcon : soloIcon;
        final Widget iconW = !hasIcon
            ? const SizedBox.shrink()
            : (solid
                ? (iconWidget != null
                    ? iconWidget!(glyphSize, solidInk)
                    : Icon(icon, size: glyphSize, color: solidInk))
                : glyph(glyphSize));
        return Semantics(
          label: showLabel ? null : semantics,
          container: !showLabel,
          child: Container(
            padding: showLabel || !hasIcon ? labelledPadding : soloPadding,
            decoration: decoration(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasIcon) iconW,
                if (showLabel) ...[
                  if (hasIcon) SizedBox(width: gap),
                  text,
                ],
              ],
            ),
          ),
        );
      },
    );

    if (onTap != null) {
      return SpringPress(
        onTap: onTap,
        scale: PressSpec.scaleSmall,
        semanticLabel: semantics,
        child: pill,
      );
    }
    if (tooltip != null && explainOnTap) {
      pill = Tooltip(
        message: tooltip!,
        triggerMode: TooltipTriggerMode.tap,
        preferBelow: false,
        showDuration: const Duration(seconds: 3),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: theme.tooltipDecoration(),
        textStyle: groupedMetaStyle(theme).copyWith(color: theme.ink),
        child: pill,
      );
    }
    return pill;
  }
}

class _Skin {
  const _Skin({
    required this.radius,
    required this.tintAlpha,
    this.opaque = false,
  });
  final double radius;
  final double tintAlpha;

  /// Lite: no translucency, the wash is blended onto the page plate.
  final bool opaque;
}
