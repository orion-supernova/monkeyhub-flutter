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
import 'labeled_field.dart';
import 'ios_kit.dart';
import 'teardown_safe.dart';
import '../l10n/text_case.dart';

export 'action_buttons.dart';
export 'labeled_field.dart' show SheetTextField, FormErrorBanner;
export 'sheet_drag.dart' show SheetScrollBody, SheetPullPhysics, SheetDragHost;

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

/// A sheet's card: rounded top, grabber, optional title bar, then [child],
/// then an optional pinned [footer].
///
/// The bar's layout is fixed here, not by callers, so it cannot drift from
/// sheet to sheet: the × is ALWAYS on the leading edge and the trailing slot
/// holds a ✓ ([confirm]) or a lone destructive trash ([trash]) — iOS 26's
/// sheet shape, and it keeps the × in place the day a sheet gains a confirm.
/// A titled sheet shows the × by default ([showClose]); an untitled menu does
/// not.
///
/// [padding] insets the child. The home-indicator / keyboard inset goes under
/// the last thing on the sheet — the [footer] when there is one, otherwise
/// the child — and it is the LARGER of the two, never their sum: with the
/// keyboard up the home indicator is under the keyboard, and adding both
/// left a dead 34pt band above it.
///
/// A scrolling body should be a [SheetScrollBody], so a pull down from its
/// top drags the sheet closed.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.showClose,
    this.onClose,
    this.confirm,
    this.trash,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.maxHeightFraction,
    this.handle = true,
  }) : assert(confirm == null || trash == null,
            'the trailing slot holds one of ✓ or trash');

  final Widget child;
  final String? title;

  /// A quiet line under the title, inside the bar.
  final String? subtitle;

  /// Whether the leading × shows. Defaults to "when there is a title".
  final bool? showClose;

  /// What the × does. Defaults to popping the sheet.
  final VoidCallback? onClose;

  /// The trailing ✓, when the sheet commits something.
  final SheetConfirm? confirm;

  /// The trailing trash, when the sheet shows one of YOUR things and the
  /// only thing to do to it is delete it. Confirm with `showConfirmSheet`.
  final VoidCallback? trash;

  /// Pinned under the body, always on screen — the sheet's commit button
  /// (a [SheetActionButton]). The body shrinks (and scrolls) first, so the
  /// button rides above the keyboard. Padded (16, 8, 16, 12) + the inset.
  final Widget? footer;
  final EdgeInsets padding;

  /// When set, the sheet is pinned to this fraction of the height it may
  /// take — for scrolling content whose sheet must not resize as it filters.
  /// A fraction of the sheet's room (the screen below the top safe area),
  /// not of the raw screen.
  final double? maxHeightFraction;
  final bool handle;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final media = MediaQuery.of(context);
    final close = showClose ?? title != null;
    final hasBar = title != null ||
        close ||
        confirm != null ||
        trash != null;
    final fraction = maxHeightFraction;
    final inset = media.viewInsets.bottom > media.padding.bottom
        ? media.viewInsets.bottom
        : media.padding.bottom;
    final foot = footer;

    Widget card(double? maxHeight) => Container(
          constraints:
              maxHeight == null ? null : BoxConstraints(maxHeight: maxHeight),
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
                SheetBar(
                  title: title,
                  subtitle: subtitle,
                  leading: close ? SheetCloseButton(onTap: onClose) : null,
                  trailing: confirm != null
                      ? SheetConfirmButton(
                          onTap: confirm!.onTap,
                          label: confirm!.label,
                        )
                      : trash != null
                          ? SheetTrashButton(onTap: trash!)
                          : null,
                ),
              Flexible(
                fit: fraction == null ? FlexFit.loose : FlexFit.tight,
                child: Padding(
                  padding: padding.copyWith(
                    bottom: padding.bottom + (foot == null ? inset : 0),
                  ),
                  child: child,
                ),
              ),
              if (foot != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + inset),
                  child: foot,
                ),
            ],
          ),
        );

    return Material(
      type: MaterialType.transparency,
      child: fraction == null
          ? card(null)
          // The room the route actually gives the sheet: with the top safe
          // area excluded (the `showAdaptiveSheet` default) the window height
          // over-counts by the status bar. Unbounded in the desktop popover,
          // which scrolls; the window height is the honest cap there.
          : LayoutBuilder(
              builder: (context, box) => card(
                (box.maxHeight.isFinite ? box.maxHeight : media.size.height) *
                    fraction,
              ),
            ),
    );
  }
}

/// The ✓ a [SheetFrame] wears on its trailing edge. A null [onTap] draws it
/// disabled.
class SheetConfirm {
  const SheetConfirm({required this.onTap, this.label});
  final VoidCallback? onTap;
  final String? label;
}

/// A sheet's 52pt title bar: × leading, centred title (and optional
/// subtitle), ✓ trailing. [SheetFrame] draws it; a sheet that cannot be a
/// [SheetFrame] (one that owns its own scroll or surface) draws this, with a
/// [SheetCloseButton] leading and a [SheetConfirmButton] OR a
/// [SheetTrashButton] trailing — never anything else in those slots, so
/// every sheet's bar reads the same.
class SheetBar extends StatelessWidget {
  const SheetBar({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      height: subtitle == null ? 52 : 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 54),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title!,
                      style: sheetTitleStyle(theme),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.bodySoft.copyWith(
                          fontSize: 13,
                          color: theme.inkMuted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            Row(
              children: [
                leading ?? const SizedBox(width: kSheetButtonSize),
                const Spacer(),
                trailing ?? const SizedBox(width: kSheetButtonSize),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The one sheet title style: 17pt emphasised body, the theme's ink.
TextStyle sheetTitleStyle(AppTheme theme) =>
    theme.bodyEmph.copyWith(fontSize: 17, color: theme.ink);

/// The diameter of every sheet-bar button, and of [GlassCloseButton]: one
/// size app-wide, matching [GlassBackButton].
const double kSheetButtonSize = 40;

/// The × that dismisses a sheet: always the bar's leading slot.
///
/// It IS the app's × — a [GlassCloseButton], the same chrome disc a
/// full-screen viewer wears — drawn [GlassCloseButton.still]: no backdrop
/// blur, because a [BackdropFilter] inside a sheet re-rasterises on every
/// frame of the sheet's rise (the jank `sheet_surface.dart` documents), and
/// on a sheet's solid fill a blur has nothing to show anyway.
class SheetCloseButton extends StatelessWidget {
  const SheetCloseButton({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GlassCloseButton(
        still: true,
        onTap: onTap ?? () => Navigator.of(context).maybePop(),
      );
}

/// The accent ✓ that commits a sheet — iOS 26's tinted confirm circle. It
/// wears the chrome disc's rim and shadow over its accent, so the × and the
/// ✓ read as one pair; disabled, it is the plain disc with a muted glyph.
class SheetConfirmButton extends StatelessWidget {
  const SheetConfirmButton({super.key, required this.onTap, this.label});
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label ?? MaterialLocalizations.of(context).okButtonLabel,
      child: ChromeDisc(
        size: kSheetButtonSize,
        still: true,
        tint: enabled ? theme.accent : null,
        onTap: onTap,
        child: Icon(
          CupertinoIcons.checkmark_alt,
          size: 19,
          color: enabled ? theme.accentInk : theme.inkMuted,
        ),
      ),
    );
  }
}

/// The trash a sheet's bar may wear on its TRAILING edge, instead of a ✓,
/// when the sheet shows something of yours and deleting it is the one
/// action (§0.1 of the round-2 rulings). The still chrome disc with a red
/// 18pt glyph. Follow the tap with `showConfirmSheet`.
class SheetTrashButton extends StatelessWidget {
  const SheetTrashButton({super.key, required this.onTap, this.semanticLabel});
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GlassIconButton(
      still: true,
      icon: CupertinoIcons.trash,
      iconSize: 18,
      color: theme.danger,
      onTap: onTap,
      semanticLabel: semanticLabel ??
          MaterialLocalizations.of(context).deleteButtonTooltip,
    );
  }
}

/// A sheet that opens as a glance and is dragged up into the whole thing,
/// the way Maps' and Photos' info sheets are: it rests at [glance] or at full
/// height, and a pull down from the glance closes it.
///
/// The body is one scroll view that drives the sheet. Dragged up, the sheet
/// grows first and the content scrolls once it is full; dragged down from the
/// top of the content, the sheet shrinks, then closes. A flick carries it to
/// the next resting height in that direction. [DraggableScrollableSheet] does
/// the hand-off, so the content and the sheet never fight over a pixel, and
/// the grabber is the first thing in the scroll view, pinned, so dragging it
/// moves the sheet too.
///
/// Not an expand button that closes the sheet and opens a page in its place:
/// that was two screens for one thing, with a cut between them.
///
/// [slivers] are built against the sheet's own scroll controller, and [wrap]
/// gets the same one, for a region that auto-scrolls it (a drag-select grid).
/// [footer] stays pinned under the body at every height.
///
/// Present it with `showAdaptiveSheet`. In the desktop popover, which nothing
/// drags, it is a fixed-height card that scrolls.
class ExpandingSheet extends StatefulWidget {
  const ExpandingSheet({
    super.key,
    required this.slivers,
    this.footer,
    this.wrap,
    this.glance = 0.62,
  });

  final List<Widget> Function(BuildContext context, ScrollController scroll)
      slivers;
  final Widget? footer;
  final Widget Function(ScrollController scroll, Widget body)? wrap;

  /// The resting height it opens at, as a share of the room the sheet has.
  final double glance;

  @override
  State<ExpandingSheet> createState() => _ExpandingSheetState();
}

class _ExpandingSheetState extends State<ExpandingSheet> {
  /// The popover's own; on a phone the draggable sheet supplies one.
  ScrollController? _popover;

  @override
  void dispose() {
    _popover?.dispose();
    super.dispose();
  }

  Widget _card(BuildContext context, ScrollController scroll,
      {required bool handle}) {
    final theme = ThemeScope.of(context);
    final media = MediaQuery.of(context);
    final inset = media.viewInsets.bottom > media.padding.bottom
        ? media.viewInsets.bottom
        : media.padding.bottom;
    final foot = widget.footer;
    final radius = Radius.circular(sheetTopRadius(theme));
    Widget body = CustomScrollView(
      controller: scroll,
      slivers: [
        if (handle)
          SliverPersistentHeader(
            pinned: true,
            delegate: _GrabberHeader(sheetFill(theme)),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        ...widget.slivers(context, scroll),
        if (foot == null)
          SliverToBoxAdapter(child: SizedBox(height: 16 + inset)),
      ],
    );
    final wrap = widget.wrap;
    if (wrap != null) body = wrap(scroll, body);
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: radius),
        child: ColoredBox(
          color: sheetFill(theme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: body),
              if (foot != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + inset),
                  child: foot,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!context.isCompact) {
      final scroll = _popover ??= ScrollController();
      final height = MediaQuery.sizeOf(context).height;
      return SizedBox(
        height: (height * 0.8).clamp(320.0, 760.0),
        child: _card(context, scroll, handle: false),
      );
    }
    return DraggableScrollableSheet(
      // Sized to itself, not stretched over the route: the space above the
      // card stays the barrier, so a tap there still closes it.
      expand: false,
      initialChildSize: widget.glance,
      // Down to nothing: reaching it is a close (the modal route listens for
      // exactly that), so the glance is never a floor the finger hits.
      minChildSize: 0,
      maxChildSize: 1,
      snap: true,
      snapSizes: [widget.glance],
      snapAnimationDuration: const Duration(milliseconds: 260),
      builder: (context, scroll) => _card(context, scroll, handle: true),
    );
  }
}

/// The grabber, pinned at the top of an [ExpandingSheet]'s scroll view so the
/// content scrolls under it and a drag on it moves the sheet.
class _GrabberHeader extends SliverPersistentHeaderDelegate {
  const _GrabberHeader(this.fill);
  final Color fill;

  static const double _extent = 15;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: fill, child: const SheetHandle());

  @override
  bool shouldRebuild(_GrabberHeader old) => old.fill != fill;
}

// [SheetActionButton], [TextLinkButton] and [RowPillButton] live in
// action_buttons.dart and are exported below: a page and a sheet share them.

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
                                // The body face, never the caption slot: on
                                // a character theme that is tracked mono, and
                                // the question read as terminal output.
                                style: groupedMetaStyle(theme).copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            if (title != null && message != null)
                              const SizedBox(height: 4),
                            if (message != null)
                              Text(
                                message!,
                                textAlign: TextAlign.center,
                                style: groupedMetaStyle(theme).copyWith(
                                  height: 1.35,
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

class _ActionSheetButtonState extends State<_ActionSheetButton>
    with TeardownSafe<_ActionSheetButton> {
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
        if (header != null) GroupedHeader(header!),
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
                        left: groupedDividerInset(children[i]),
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

/// One button of a [showIosAlert].
class IosAlertAction<T> {
  const IosAlertAction({
    required this.label,
    required this.value,
    this.destructive = false,
    this.cancel = false,
    this.preferred = false,
  });

  final String label;

  /// What [showIosAlert] returns when this is tapped.
  final T value;

  /// Red — the answer that destroys something. Filled.
  final bool destructive;

  /// The way out. Autofocused, so Enter on a fresh alert never commits, and
  /// its presence lets a tap outside (or Escape) dismiss the alert with null.
  final bool cancel;

  /// The answer the alert expects — filled accent, and what Return in the
  /// [IosAlertField] submits.
  final bool preferred;
}

/// The optional text field of a [showIosAlert]. The caller owns
/// [controller] and reads it after the alert returns.
class IosAlertField {
  const IosAlertField({
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLength,
  });

  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLength;
}

/// THE centred alert: a question that needs an answer before anything else
/// happens ("Save these glass settings?", "Name this preset").
///
/// Themed from [ThemeScope] — the sheet's fill, the theme's body face, the
/// accent — never Material's purple `AlertDialog` or a stock
/// `CupertinoAlertDialog`, which ignore the theme entirely. Buttons are the
/// app's capsules: side by side when two labels fit, stacked otherwise (and
/// always stacked for three or more), so a long Turkish label never
/// truncates.
///
/// Prefer [showIosActionSheet] for a choice between actions and for
/// destructive confirmations; an alert is for a blocking question or a
/// one-field prompt. Returns the tapped action's value, or null when
/// dismissed (only possible when an action is [IosAlertAction.cancel]).
Future<T?> showIosAlert<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<IosAlertAction<T>> actions,
  IosAlertField? field,
}) {
  final calm = MotionScope.of(context).calm;
  final dismissible = actions.any((a) => a.cancel);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: Duration(milliseconds: calm ? 150 : 260),
    pageBuilder: (ctx, _, _) => _IosAlert<T>(
      title: title,
      message: message,
      actions: actions,
      field: field,
    ),
    // The iOS alert's arrival: a fade with a slight settle from 108%. A
    // solid card — nothing here blurs, so scaling it costs nothing.
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: calm
            ? child
            : ScaleTransition(
                scale: Tween<double>(begin: 1.08, end: 1).animate(curved),
                child: child,
              ),
      );
    },
  );
}

class _IosAlert<T> extends StatelessWidget {
  const _IosAlert({
    required this.title,
    required this.message,
    required this.actions,
    required this.field,
  });

  final String? title;
  final String? message;
  final List<IosAlertAction<T>> actions;
  final IosAlertField? field;

  static const _gap = 8.0;

  bool _filled(IosAlertAction<T> a) =>
      a.preferred || a.destructive || actions.length == 1;

  void _submit(BuildContext context) {
    final a = actions.where((a) => a.preferred).firstOrNull ??
        actions.where((a) => !a.cancel).firstOrNull;
    if (a != null) Navigator.of(context).pop(a.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final media = MediaQuery.of(context);
    final width = (media.size.width - 48).clamp(0.0, 300.0);
    final f = field;

    Widget button(IosAlertAction<T> a) => SheetActionButton(
          label: a.label,
          onTap: () => Navigator.of(context).pop(a.value),
          tonal: !_filled(a),
          destructive: a.destructive,
          autofocus: a.cancel && f == null,
          minHeight: 46,
        );

    final buttons = LayoutBuilder(
      builder: (context, box) {
        if (actions.length == 2) {
          final each = (box.maxWidth - _gap) / 2 - kActionButtonHPad * 2;
          final style = actionButtonLabelStyle(theme);
          final fits = actions.every((a) {
            final p = TextPainter(
              text: TextSpan(text: sentenceCaseOf(context, a.label), style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final ok = p.width <= each;
            p.dispose();
            return ok;
          });
          if (fits) {
            // Side by side, the way out on the leading edge (iOS's order).
            final ordered = [
              ...actions.where((a) => a.cancel),
              ...actions.where((a) => !a.cancel),
            ];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: button(ordered[0])),
                const SizedBox(width: _gap),
                Expanded(child: button(ordered[1])),
              ],
            );
          }
        }
        // Stacked, the way out last — where the thumb expects it.
        final ordered = [
          ...actions.where((a) => !a.cancel),
          ...actions.where((a) => a.cancel),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < ordered.length; i++) ...[
              if (i > 0) const SizedBox(height: _gap),
              button(ordered[i]),
            ],
          ],
        );
      },
    );

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Center(
        child: SizedBox(
          width: width,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              decoration: BoxDecoration(
                color: sheetFill(theme),
                borderRadius: BorderRadius.circular(
                  (theme.radiusXl * 1.4).clamp(10.0, 30.0),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null)
                      Text(
                        sentenceCaseOf(context, title!),
                        textAlign: TextAlign.center,
                        style: groupedHeaderStyle(theme),
                      ),
                    if (title != null && message != null)
                      const SizedBox(height: 6),
                    if (message != null)
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: groupedFooterStyle(theme)
                            .copyWith(color: theme.inkSoft),
                      ),
                    if (f != null) ...[
                      const SizedBox(height: 16),
                      SheetTextField(
                        controller: f.controller,
                        hint: f.hint,
                        obscure: f.obscure,
                        keyboardType: f.keyboardType,
                        textCapitalization: f.textCapitalization,
                        maxLength: f.maxLength,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(context),
                      ),
                    ],
                    const SizedBox(height: 20),
                    buttons,
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
