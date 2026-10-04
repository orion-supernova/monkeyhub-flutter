import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';

/// THE icon button: a glass circle with a glyph — back, close, compose, more,
/// and every control floating over a photo or the camera.
///
/// [tone] picks the glass ([GlassTone.media] over photos/video), [tint] makes
/// it a solid, lit control (an armed tool, an active toggle). A null [onTap]
/// is a disabled button: dimmed ink, no press, no focus stop.
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

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final Color ink;
    if (tone == GlassTone.media) {
      ink = color ?? (enabled ? MediaGlass.ink : MediaGlass.inkDisabled);
    } else {
      final theme = ThemeScope.of(context);
      ink = color ??
          (tint != null
              ? theme.accentInk
              : (enabled ? theme.ink : theme.inkMuted));
    }
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
}

/// The back control every pushed page wears: a glass circle with a chevron,
/// iOS 26's toolbar treatment.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({
    super.key,
    this.onTap,
    this.tone = GlassTone.app,
    this.semanticLabel,
    this.enabled = true,
  });

  final VoidCallback? onTap;
  final GlassTone tone;
  final String? semanticLabel;

  /// False draws it dimmed and inert (a capture in flight, say).
  final bool enabled;

  @override
  Widget build(BuildContext context) => GlassIconButton(
        icon: CupertinoIcons.chevron_back,
        iconSize: 20,
        tone: tone,
        semanticLabel: semanticLabel ??
            MaterialLocalizations.of(context).backButtonTooltip,
        onTap: enabled
            ? onTap ?? () => Navigator.of(context).maybePop()
            : null,
      );
}

/// The close control of a full-screen surface: a glass circle with an ×.
///
/// One size app-wide (40pt, 17pt glyph — the [GlassBackButton]'s), and it
/// sits top-LEADING, like a sheet's ×. A pushed page has no ×; it has a
/// back chevron.
class GlassCloseButton extends StatelessWidget {
  const GlassCloseButton({
    super.key,
    this.onTap,
    this.semanticLabel,
    this.tone = GlassTone.app,
    this.enabled = true,
  });

  /// Defaults to popping the route.
  final VoidCallback? onTap;
  final String? semanticLabel;
  final GlassTone tone;

  /// False draws it dimmed and inert (a save in flight, say) — a null
  /// [onTap] cannot say that, since it means "pop".
  final bool enabled;

  @override
  Widget build(BuildContext context) => GlassIconButton(
        icon: CupertinoIcons.xmark,
        iconSize: 17,
        tone: tone,
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
