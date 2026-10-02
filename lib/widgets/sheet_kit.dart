import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';

// The furniture every sheet in the app is built from, in the iOS 26 shape: a
// generously rounded top, a grabber, an optional bar with a glass close button
// on one side and a glass confirm on the other, and a centred title. Kept
// separate from ios_kit.dart (pages and grouped lists) because a sheet has its
// own geometry — it is a card that rises over a page, not a page.

/// Top corner radius of a sheet. iOS 26 sheets run to ~34pt, concentric with
/// the display; a theme with a square personality (a small `radiusXl`) keeps
/// proportionally square corners instead.
double sheetTopRadius(AppTheme theme) =>
    (theme.radiusXl * 1.7).clamp(8.0, 34.0);

/// Fill of a sheet: the theme's surface, which on every palette sits one step
/// above the page — the elevation iOS gives a presented card.
Color sheetFill(AppTheme theme) => theme.surface;

/// The 36×5 capsule at the top of a draggable sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    // Meaningless where the sheet is a desktop popover, which nothing drags.
    if (!context.isCompact) return const SizedBox(height: 10);
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: theme.ink.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// A sheet's card: rounded top, grabber, optional title bar, then [child].
///
/// [leading] / [trailing] sit at either end of the title bar — usually a
/// [SheetCloseButton] and a [SheetConfirmButton]. [padding] insets the child;
/// the home-indicator and keyboard insets are added to its bottom so content
/// never sits under either.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.maxHeightFraction,
    this.handle = true,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets padding;

  /// When set, the sheet is pinned to this fraction of the window's height —
  /// for scrolling content whose sheet must not resize as it filters.
  final double? maxHeightFraction;
  final bool handle;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final media = MediaQuery.of(context);
    final hasBar = title != null || leading != null || trailing != null;
    final fraction = maxHeightFraction;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: fraction == null
            ? null
            : BoxConstraints(maxHeight: media.size.height * fraction),
        decoration: BoxDecoration(
          color: sheetFill(theme),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sheetTopRadius(theme)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (handle) const SheetHandle() else const SizedBox(height: 10),
            if (hasBar)
              SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (title != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 54),
                          child: Text(
                            title!,
                            style: theme.bodyEmph.copyWith(color: theme.ink),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Row(
                        children: [
                          ?leading,
                          const Spacer(),
                          ?trailing,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Flexible(
              fit: fraction == null ? FlexFit.loose : FlexFit.tight,
              child: Padding(
                padding: padding.copyWith(
                  bottom: padding.bottom +
                      media.padding.bottom +
                      media.viewInsets.bottom,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The glass × that dismisses a sheet.
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GlassIconButton(
        icon: CupertinoIcons.xmark,
        iconSize: 16,
        size: 38,
        semanticLabel: MaterialLocalizations.of(context).closeButtonLabel,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
      );
}

/// The accent ✓ that commits a sheet — iOS 26's tinted confirm circle.
class SheetConfirmButton extends StatelessWidget {
  const SheetConfirmButton({super.key, required this.onTap, this.label});
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    return SpringPress(
      onTap: onTap,
      semanticLabel: label ?? MaterialLocalizations.of(context).okButtonLabel,
      child: AnimatedContainer(
        duration: theme.motionFast,
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? theme.accent : theme.ink.withValues(alpha: 0.10),
        ),
        child: Icon(
          CupertinoIcons.checkmark_alt,
          size: 19,
          color: enabled ? theme.accentInk : theme.inkMuted,
        ),
      ),
    );
  }
}

/// A sheet's big call to action: a full-width rounded slab, sentence case.
class SheetActionButton extends StatelessWidget {
  const SheetActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.tonal = false,
  });

  final String label;
  final VoidCallback? onTap;

  /// Red fill for an action that destroys something.
  final bool destructive;

  /// A soft tinted slab instead of a solid one — the secondary action.
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    final Color fill;
    final Color ink;
    if (!enabled) {
      fill = theme.ink.withValues(alpha: 0.08);
      ink = theme.inkMuted;
    } else if (tonal) {
      fill = (destructive ? theme.danger : theme.ink).withValues(alpha: 0.10);
      ink = destructive ? theme.danger : theme.ink;
    } else {
      fill = destructive ? theme.danger : theme.bubbleFill(isMine: true);
      ink = destructive ? Colors.white : theme.accentInk;
    }
    return SpringPress(
      onTap: onTap,
      scale: 0.97,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: theme.motionFast,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(
            (theme.radiusXl * 0.8).clamp(6.0, 16.0),
          ),
        ),
        child: Text(
          sentenceCaseOf(context, label),
          textAlign: TextAlign.center,
          style: theme.bodyEmph.copyWith(
            fontSize: 17,
            color: ink,
            letterSpacing: -0.2,
            fontStyle: FontStyle.normal,
          ),
        ),
      ),
    );
  }
}

/// A label authored in capitals for the old letter-spaced buttons, read in
/// sentence case. Leaves anything already mixed-case alone, and short
/// all-caps words (OK, GIF, DM) as they are. Lower-case labels get their first
/// letter raised.
///
/// Locale-aware for the one case that matters here: Dart's own case mapping
/// is not, and turns Turkish "KAPALI" into "kapali" and "GİDEN" into "gi̇den"
/// (a stray combining dot). Under Turkish and Azerbaijani the dotted and
/// dotless I pairs are mapped by hand.
String sentenceCase(String s, {String? languageCode}) {
  if (s.isEmpty) return s;
  final turkic = languageCode == 'tr' || languageCode == 'az';
  String lower(String x) => turkic
      ? x.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase()
      : x.replaceAll('İ', 'i').toLowerCase();
  String upper(String x) => turkic
      ? x.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase()
      : x.toUpperCase();

  final first = s.characters.first;
  final rest = s.characters.skip(1).toString();
  if (s == upper(s)) {
    final letters = s.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    if (letters.length <= 3) return s;
    return upper(first) + lower(rest);
  }
  // Mixed or lower case: raise the first letter only.
  return upper(first) + rest;
}

/// [sentenceCase] in the reader's language.
String sentenceCaseOf(BuildContext context, String s) => sentenceCase(
      s,
      languageCode: Localizations.maybeLocaleOf(context)?.languageCode,
    );

/// One button in an [showIosActionSheet].
class IosSheetAction<T> {
  const IosSheetAction({
    required this.label,
    required this.value,
    this.destructive = false,
    this.icon,
  });

  final String label;
  final T value;
  final bool destructive;
  final IconData? icon;
}

/// The iOS action sheet: a floating rounded group of choices with an optional
/// title and message above them, and a separate Cancel below. Rises on a
/// spring; returns the chosen action's value, or null for Cancel / dismissal.
Future<T?> showIosActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<IosSheetAction<T>> actions,
  String? cancelLabel,
}) {
  // Opens silently: the weight belongs to the destructive answer, which
  // lands a heavy impact (see `app_haptics_test.dart`).
  return showAdaptiveSheet<T>(
    context,
    builder: (ctx) => _IosActionSheet<T>(
      title: title,
      message: message,
      actions: actions,
      cancelLabel: cancelLabel,
    ),
  );
}

class _IosActionSheet<T> extends StatelessWidget {
  const _IosActionSheet({
    required this.title,
    required this.message,
    required this.actions,
    required this.cancelLabel,
  });

  final String? title;
  final String? message;
  final List<IosSheetAction<T>> actions;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final media = MediaQuery.of(context);
    final radius = (theme.radiusXl * 1.2).clamp(8.0, 26.0);
    final fill = sheetFill(theme);
    final hairline = 1 / media.devicePixelRatio;
    final cancel = cancelLabel ??
        AppLocalizations.of(context).destructiveSheetCancelButtonLabel;

    Widget button(String label, VoidCallback onTap,
        {bool destructive = false, bool bold = false, IconData? icon,
        bool autofocus = false}) {
      return _ActionSheetButton(
        label: label,
        onTap: onTap,
        destructive: destructive,
        bold: bold,
        icon: icon,
        autofocus: autofocus,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + media.padding.bottom),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: ColoredBox(
                color: fill,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null || message != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          children: [
                            if (title != null)
                              Text(
                                sentenceCaseOf(context, title!),
                                textAlign: TextAlign.center,
                                style: theme.caption.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.inkMuted,
                                ),
                              ),
                            if (title != null && message != null)
                              const SizedBox(height: 4),
                            if (message != null)
                              Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: theme.caption.copyWith(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: theme.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0 || title != null || message != null)
                        Container(
                          height: hairline,
                          color: theme.ink.withValues(alpha: 0.12),
                        ),
                      button(
                        actions[i].label,
                        () {
                          if (actions[i].destructive) {
                            HapticFeedback.heavyImpact();
                          }
                          Navigator.of(context).pop(actions[i].value);
                        },
                        destructive: actions[i].destructive,
                        icon: actions[i].icon,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: ColoredBox(
                color: fill,
                // Autofocused so Enter on a freshly opened destructive sheet
                // cancels rather than destroys — the desktop convention.
                child: button(
                  cancel,
                  () => Navigator.of(context).pop(),
                  bold: true,
                  autofocus: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionSheetButton extends StatefulWidget {
  const _ActionSheetButton({
    required this.label,
    required this.onTap,
    required this.destructive,
    required this.bold,
    required this.icon,
    required this.autofocus,
  });

  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final bool bold;
  final IconData? icon;
  final bool autofocus;

  @override
  State<_ActionSheetButton> createState() => _ActionSheetButtonState();
}

class _ActionSheetButtonState extends State<_ActionSheetButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = widget.destructive ? theme.danger : theme.accent;
    return FocusableTap(
      onTap: widget.onTap,
      autofocus: widget.autofocus,
      semanticLabel: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _down ? Duration.zero : const Duration(milliseconds: 240),
          color: _down ? theme.ink.withValues(alpha: 0.08) : Colors.transparent,
          constraints: const BoxConstraints(minHeight: 57),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: color),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  sentenceCaseOf(context, widget.label),
                  textAlign: TextAlign.center,
                  style: theme.body.copyWith(
                    fontSize: 19,
                    fontWeight:
                        widget.bold ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rounded group of rows inside a sheet — the same block a [GroupedSection]
/// draws on a page, one step brighter so it reads on the sheet's own fill.
class SheetGroup extends StatelessWidget {
  const SheetGroup({super.key, required this.children, this.header});
  final List<Widget> children;
  final String? header;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
            child: Text(
              sentenceCaseOf(context, header!),
              style: theme.caption.copyWith(
                fontSize: 13,
                color: theme.inkMuted,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
          child: ColoredBox(
            color: sheetGroupFill(theme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Padding(
                      padding: EdgeInsets.only(
                        left: children[i] is GroupedRow &&
                                (children[i] as GroupedRow).icon != null
                            ? 60
                            : 16,
                      ),
                      child: Container(
                        height: hairline,
                        color: theme.ink.withValues(alpha: 0.10),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The fill of a grouped block that sits ON a sheet rather than on a page.
Color sheetGroupFill(AppTheme theme) => Color.alphaBlend(
      (theme.isLight ? Colors.black : Colors.white)
          .withValues(alpha: theme.isLight ? 0.035 : 0.06),
      sheetFill(theme),
    );

/// A spring entrance for content inside a freshly opened sheet: rises 12pt
/// and fades in, staggered by [index]. Calm under reduced motion.
class SheetRise extends StatelessWidget {
  const SheetRise({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    if (motion.calm) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 45),
      curve: const _Overshoot(),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, (1 - t) * 14),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}

/// easeOutBack with a gentler overshoot — enough to feel alive, not bouncy.
class _Overshoot extends Curve {
  const _Overshoot();
  @override
  double transformInternal(double t) {
    const s = 1.2;
    final u = t - 1;
    return u * u * ((s + 1) * u + s) + 1;
  }
}
