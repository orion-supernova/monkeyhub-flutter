import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../keyboard/focusable_tap.dart';
import '../l10n/text_case.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../ui/foundation/ui_kit.dart';
import '../ui/native/native_control.dart';
import '../ui/kits/material/material_kit_theme.dart';
import 'app_spinner.dart';
import 'liquid_glass.dart' show SpecularRim;
import 'spring_press.dart';

// THE buttons. One primary/secondary shape, one text action, one inline row
// pill — exported from both ios_kit.dart and sheet_kit.dart, so a page and a
// sheet reach for the same three things.
//
// There were four full-width families before this (a 54pt gradient capsule, a
// 52pt rounded slab in bubble-blue, a flat 50pt capsule and a bare-text
// "secondary"), and they ended up stacked on the same screens: a capsule over
// a near-square slab reads as two apps. The capsule won because iOS 26 and
// [GlassPillButton] are capsules; the accent won over `bubbleFill` because a
// button is not a message.

/// Minimum height of a [SheetActionButton].
const double kActionButtonHeight = 50;

/// Horizontal padding inside a [SheetActionButton]. Public so a caller that
/// measures labels before choosing a layout (`GameResultActions`) measures
/// against the same numbers the button draws with.
const double kActionButtonHPad = 18;

/// Glyph size and gap of a [SheetActionButton]'s leading [icon].
const double kActionButtonIcon = 18;
const double kActionButtonIconGap = 8;

/// The label style of a [SheetActionButton]: 17/w600 on the theme's emphasis
/// face, upright even on themes whose emphasis is italic.
TextStyle actionButtonLabelStyle(AppTheme theme) => theme.bodyEmph.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      fontStyle: FontStyle.normal,
      height: 1.2,
    );

/// THE full-width action: an accent capsule, 50pt, sentence case — the
/// primary button of every sheet, form, first-run screen and empty state.
///
/// * [tonal] — the secondary: a soft ink fill, ink label.
/// * [destructive] — red (solid, or red-on-red-wash with [tonal]).
/// * [busy] — a spinner replaces the label at the SAME size, coloured for the
///   fill, so nothing under the button moves; taps are ignored meanwhile.
/// * [icon] — an optional leading glyph.
/// * [expand] — false sizes the capsule to its label (an empty state's
///   action); the default fills the width it is given.
///
/// Labels wrap to a second line rather than ellipsize: a button you cannot
/// read is not a button. A null [onTap] draws it disabled (neutral fill,
/// muted label) — never hidden.
class SheetActionButton extends StatelessWidget {
  const SheetActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.tonal = false,
    this.busy = false,
    this.icon,
    this.expand = true,
    this.autofocus = false,
    this.haptic = true,
    this.minHeight = kActionButtonHeight,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;

  /// Red fill for an action that destroys something.
  final bool destructive;

  /// A soft tinted capsule instead of a solid one — the secondary action.
  final bool tonal;

  /// Work in flight: a spinner in place of the label, taps ignored.
  final bool busy;

  /// A leading glyph (Cupertino), drawn in the label's colour.
  final IconData? icon;

  /// Fill the available width (default) or hug the label.
  final bool expand;

  /// Take keyboard focus on first build.
  final bool autofocus;

  /// The selection tick on tap. Off when the caller plays its own, heavier
  /// haptic (the one big commit on a first-run screen).
  final bool haptic;

  /// 50 everywhere except inside an alert, which runs a shade tighter.
  final double minHeight;
  final String? semanticLabel;

  /// The [UiKit.material] skin: `FilledButton` / `.tonal`, error-coloured when
  /// [destructive]; [busy] swaps the label for a ring at the same size.
  Widget _material(BuildContext context) {
    final theme = ThemeScope.of(context);
    final scheme = MaterialKitTheme.of(theme).colorScheme;
    final enabled = onTap != null;
    final text = sentenceCaseOf(context, label);
    final ink = !enabled
        ? null
        : tonal
            ? (destructive ? scheme.error : scheme.onSecondaryContainer)
            : (destructive ? scheme.onError : scheme.onPrimary);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: kActionButtonIcon),
          const SizedBox(width: kActionButtonIconGap),
        ],
        Flexible(child: Text(text, textAlign: TextAlign.center)),
      ],
    );
    final child = busy
        ? Stack(
            alignment: Alignment.center,
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: content,
              ),
              AppSpinner(color: ink ?? scheme.onSurface, radius: 9),
            ],
          )
        : content;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, minHeight)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: kActionButtonHPad, vertical: 12),
      ),
      textStyle: WidgetStatePropertyAll(
        theme.bodyEmph.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.1,
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final onPressed = enabled && !busy
        ? () {
            if (haptic) HapticFeedback.selectionClick();
            onTap!();
          }
        : null;
    // A busy button keeps its enabled colours: it is working, not disabled.
    final ButtonStyle colors = busy && enabled
        ? ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(
              tonal
                  ? (destructive
                      ? scheme.error.withValues(alpha: 0.12)
                      : scheme.secondaryContainer)
                  : (destructive ? scheme.error : scheme.primary),
            ),
            foregroundColor: WidgetStatePropertyAll(ink),
          )
        : tonal && destructive
            ? ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(
                  scheme.error.withValues(alpha: 0.12),
                ),
                foregroundColor: WidgetStatePropertyAll(scheme.error),
              )
            : destructive
                ? ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(scheme.error),
                    foregroundColor: WidgetStatePropertyAll(scheme.onError),
                  )
                : const ButtonStyle();
    final merged = style.merge(colors);
    final button = tonal
        ? FilledButton.tonal(
            onPressed: onPressed,
            autofocus: autofocus,
            style: merged,
            child: child,
          )
        : FilledButton(
            onPressed: onPressed,
            autofocus: autofocus,
            style: merged,
            child: child,
          );
    return MaterialKitScope(
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: semanticLabel ?? text,
        excludeSemantics: true,
        child: expand ? SizedBox(width: double.infinity, child: button) : button,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => KitSwitch(
        glass: _glass,
        material: _material,
        // Busy shows a spinner in the button; the native button has none, so
        // a busy button keeps the glass skin.
        liquid: NativeControl.readyIn(context) && !busy ? _liquid : null,
      );

  /// The [UiKit.liquid] skin: a real glass button; the primary action is
  /// prominent (tinted), tonal is plain glass, destructive is red.
  Widget _liquid(BuildContext context) {
    final text = sentenceCaseOf(context, label);
    final button = NativeControl(
      size: Size(expand ? double.infinity : text.length * 9.0 + 64, minHeight),
      spec: NativeSpec.button(
        label: text,
        symbol: sfSymbolFor(icon),
        prominent: !tonal && !destructive,
        destructive: destructive,
        enabled: onTap != null,
        fill: expand,
        height: minHeight,
      ),
      onEvent: (event, _) {
        if (event != 'tap') return;
        if (haptic) HapticFeedback.mediumImpact();
        onTap?.call();
      },
    );
    return Semantics(label: semanticLabel, child: button);
  }

  Widget _glass(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    final Color fill;
    final Color ink;
    if (!enabled) {
      // Disabled is a neutral capsule with muted text, iOS-style — never a
      // washed-out accent, which on a dark page is a navy slab.
      fill = theme.ink.withValues(alpha: 0.08);
      ink = theme.inkMuted;
    } else if (tonal) {
      fill = (destructive ? theme.danger : theme.ink).withValues(alpha: 0.12);
      ink = destructive ? theme.danger : theme.ink;
    } else {
      fill = destructive ? theme.danger : theme.accent;
      ink = destructive ? Colors.white : theme.accentInk;
    }
    final style = actionButtonLabelStyle(theme).copyWith(color: ink);
    final text = sentenceCaseOf(context, label);
    // A solid, live capsule — the one that takes a rim and a shadow.
    final solid = enabled && !tonal;

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: kActionButtonIcon, color: ink),
          const SizedBox(width: kActionButtonIconGap),
        ],
        Flexible(
          child: Text(text, textAlign: TextAlign.center, style: style),
        ),
      ],
    );

    return SpringPress(
      onTap: enabled && !busy ? onTap : null,
      scale: 0.97,
      haptic: haptic,
      autofocus: autofocus,
      semanticLabel: semanticLabel ?? text,
      focusShape: FocusRingShape.capsule,
      focusRadius: 999,
      child: AnimatedContainer(
        duration: theme.motionFast,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
          // A solid capsule sits on a soft fall of its own colour, the way the
          // chrome disc sits on its shadow; a tonal or disabled one is flat.
          boxShadow: solid
              ? [
                  BoxShadow(
                    color: fill.withValues(alpha: theme.isLight ? 0.30 : 0.34),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: CustomPaint(
          // The lit edge, on a solid capsule only.
          foregroundPainter: solid
              ? SpecularRim(
                  shape: const StadiumBorder(),
                  light: theme.isLight,
                  opacity: 0.6,
                )
              : null,
          // Sunlight from above, under the label: a fill and a gradient cannot
          // share a decoration (the gradient wins), so it is a layer of its own.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(
                    alpha: !enabled
                        ? 0
                        : solid
                            ? (theme.isLight ? 0.20 : 0.14)
                            : (theme.isLight ? 0.30 : 0.05),
                  ),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0, 0.6],
              ),
            ),
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight),
              padding: const EdgeInsets.symmetric(
                horizontal: kActionButtonHPad,
                vertical: 12,
              ),
              alignment: expand ? Alignment.center : null,
              // The label stays laid out (invisible) under the spinner, so the
              // capsule keeps its width and height while busy.
              child: busy
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Visibility(
                          visible: false,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: content,
                        ),
                        AppSpinner(color: ink),
                      ],
                    )
                  : content,
            ),
          ),
        ),
      ),
    );
  }
}

/// THE tertiary action: accent text, 17pt, no fill — "Use password
/// instead", "Not now", "Scan another". Springs and takes keyboard focus like
/// every other control; at least 44pt tall so it is a real touch target.
class TextLinkButton extends StatelessWidget {
  const TextLinkButton({
    super.key,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.muted = false,
    this.fontSize = 17,
    this.weight = FontWeight.w400,
    this.icon,
    this.autofocus = false,
    this.semanticLabel,
  });

  final String label;

  /// Null draws it muted and inert.
  final VoidCallback? onTap;
  final bool destructive;

  /// Ink-muted instead of accent — a quiet footnote action.
  final bool muted;

  /// 17 by default; 15 only where it sits inside 15pt copy.
  final double fontSize;
  final FontWeight weight;

  /// Optional trailing glyph (a chevron for "See all").
  final IconData? icon;
  final bool autofocus;
  final String? semanticLabel;

  /// The [UiKit.material] skin: a `TextButton`.
  Widget _material(BuildContext context) {
    final theme = ThemeScope.of(context);
    final scheme = MaterialKitTheme.of(theme).colorScheme;
    final enabled = onTap != null;
    final color = destructive
        ? scheme.error
        : (muted ? scheme.onSurfaceVariant : scheme.primary);
    final text = sentenceCaseOf(context, label);
    return MaterialKitScope(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel ?? text,
        excludeSemantics: true,
        child: TextButton(
          onPressed: onTap,
          autofocus: autofocus,
          style: TextButton.styleFrom(
            foregroundColor: color,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: theme.body.copyWith(
              fontSize: fontSize - 1,
              fontWeight: weight == FontWeight.w400 ? FontWeight.w500 : weight,
              letterSpacing: 0.1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(text, textAlign: TextAlign.center)),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: fontSize * 0.9),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      KitSwitch(glass: _glass, material: _material);

  Widget _glass(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    final color = !enabled
        ? theme.inkMuted.withValues(alpha: 0.6)
        : destructive
            ? theme.danger
            : (muted ? theme.inkMuted : theme.accent);
    final text = sentenceCaseOf(context, label);
    return SpringPress(
      onTap: onTap,
      scale: PressSpec.scaleSmall,
      autofocus: autofocus,
      semanticLabel: semanticLabel ?? text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.body.copyWith(
                    fontSize: fontSize,
                    fontWeight: weight,
                    color: color,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 3),
                Icon(icon, size: fontSize * 0.82, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// THE inline action at a row's trailing edge — "Remove", "Unblock", "Take
/// back": a small quiet capsule, accent (or red) 15/w600 label, its own
/// spinner while [busy]. Carries an 8pt leading gap so it never touches a
/// truncated name beside it.
class RowPillButton extends StatelessWidget {
  const RowPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.busy = false,
    this.filled = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool busy;

  /// Solid accent (or red) with white-ish ink — for the one row action that is
  /// the point of the list ("Add" in a suggestions list).
  final bool filled;
  final String? semanticLabel;

  /// The [UiKit.material] skin: a small `FilledButton.tonal` (`FilledButton`
  /// when [filled]), error-coloured when [destructive].
  Widget _material(BuildContext context) {
    final theme = ThemeScope.of(context);
    final scheme = MaterialKitTheme.of(theme).colorScheme;
    final enabled = onTap != null;
    final text = sentenceCaseOf(context, label);
    final tone = destructive ? scheme.error : scheme.primary;
    final ButtonStyle colors = filled
        ? ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(tone),
            foregroundColor: WidgetStatePropertyAll(
              destructive ? scheme.onError : scheme.onPrimary,
            ),
          )
        : ButtonStyle(
            foregroundColor: WidgetStatePropertyAll(
              destructive ? scheme.error : scheme.onSecondaryContainer,
            ),
          );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: WidgetStatePropertyAll(
        theme.bodySoft.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    ).merge(colors);
    final child = busy
        ? Stack(
            alignment: Alignment.center,
            children: [
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: Text(text, maxLines: 1, softWrap: false),
              ),
              AppSpinner(color: filled ? scheme.onPrimary : tone, radius: 8),
            ],
          )
        : Text(text, maxLines: 1, softWrap: false);
    final onPressed = enabled && !busy ? onTap : null;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: MaterialKitScope(
        child: Semantics(
          button: true,
          enabled: onPressed != null,
          label: semanticLabel ?? text,
          excludeSemantics: true,
          child: filled
              ? FilledButton(onPressed: onPressed, style: style, child: child)
              : FilledButton.tonal(
                  onPressed: onPressed,
                  style: style,
                  child: child,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => KitSwitch(
    glass: _glass,
    liquid: NativeControl.readyIn(context) && !busy ? _liquid : null,
    material: _material,
  );

  /// The system glass button, small. A busy pill keeps the Flutter skin: the
  /// system button has no in-place spinner.
  Widget _liquid(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 8),
    child: NativeControl(
      spec: NativeSpec.button(
        label: sentenceCaseOf(context, label),
        prominent: filled,
        destructive: destructive,
        enabled: onTap != null,
        height: 32,
      ),
      onEvent: (event, _) {
        if (event == 'tap') onTap?.call();
      },
    ),
  );

  Widget _glass(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    final tone = destructive ? theme.danger : theme.accent;
    final Color fill;
    final Color ink;
    if (!enabled) {
      fill = theme.ink.withValues(alpha: theme.isLight ? 0.06 : 0.10);
      ink = theme.inkMuted;
    } else if (filled) {
      fill = tone;
      ink = destructive ? Colors.white : theme.accentInk;
    } else {
      fill = theme.ink.withValues(alpha: theme.isLight ? 0.06 : 0.10);
      ink = tone;
    }
    final text = sentenceCaseOf(context, label);
    final labelWidget = Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: theme.bodySoft.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: -0.1,
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: SpringPress(
        onTap: enabled && !busy ? onTap : null,
        scale: PressSpec.scaleSmall,
        semanticLabel: semanticLabel ?? text,
        focusShape: FocusRingShape.capsule,
        focusRadius: 999,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: busy
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Visibility(
                      visible: false,
                      maintainSize: true,
                      maintainAnimation: true,
                      maintainState: true,
                      child: labelWidget,
                    ),
                    AppSpinner(color: ink, radius: 8),
                  ],
                )
              : labelWidget,
        ),
      ),
    );
  }
}
