import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/app_shortcuts.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/density.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'hover_hint.dart';
import 'labeled_field.dart';
import 'ios_kit.dart';
import 'liquid_glass.dart' show SpecularRim;
import 'sunlit_surface.dart' show sunlitShadows;
import '../l10n/text_case.dart';

export 'action_buttons.dart';
export 'labeled_field.dart' show SheetTextField, FormErrorBanner;
export 'sheet_drag.dart' show SheetScrollBody, SheetPullPhysics, SheetDragHost;

// The furniture every sheet in the app is built from, in the iOS 26 shape: a
// generously rounded top, a grabber, an optional bar with a glass close button
// on one side and a glass confirm on the other, and a centred title. Kept
// separate from ios_kit.dart (pages and grouped lists) because a sheet has its
// own geometry — it is a card that rises over a page, not a page.

/// Corner radius of a sheet. A floating iOS 26 sheet is concentric with the
/// display (38pt on the round themes); a theme with a square personality (a
/// small `radiusXl`) keeps proportionally square corners instead.
double sheetRadius(AppTheme theme) => (theme.radiusXl * 1.9).clamp(8.0, 38.0);

/// Old name of [sheetRadius], kept so panels that still say "top radius" keep
/// compiling (the route clips all four corners anyway). Prefer [sheetRadius].
double sheetTopRadius(AppTheme theme) => sheetRadius(theme);

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
      // 8 from the sheet's top edge; 15 in all, so a pinned grabber header
      // (`_GrabberHeader`) and every bar under it keep their old rhythm.
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            // The spec's 0.5 is for a dark sheet; 0.30 reads on both a white
            // panel and a near-black one without shouting.
            color: theme.ink.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(2.5),
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
    this.scrollsUnderInset = false,
    this.help,
    this.helpLabel,
    this.closeIsBack,
  }) : assert(
          (confirm == null || trash == null) &&
              (help == null || (confirm == null && trash == null)),
          'the trailing slot holds one of ✓, trash or help',
        );

  /// Opens this sheet's explanation, from a "?" in the bar's trailing slot
  /// ([SheetHelpButton]): the native place for help, where it costs the
  /// content no height. For a sheet that commits from its footer, whose
  /// trailing slot is otherwise empty.
  final VoidCallback? help;

  /// What a screen reader says for [help].
  final String? helpLabel;

  final Widget child;
  final String? title;

  /// A quiet line under the title, inside the bar.
  final String? subtitle;

  /// Whether the leading × shows. Defaults to "when there is a title".
  final bool? showClose;

  /// What the × does. Defaults to popping the sheet.
  final VoidCallback? onClose;

  /// For a sheet with pages of its own: non-null draws the leading button as
  /// a [SheetBackCloseButton], whose × turns into a ‹ (true) on an inner page
  /// and back again, and the title crossfades as it changes. [onClose] then
  /// does both jobs.
  final bool? closeIsBack;

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

  /// The child is a scroll view that pads its own end by the home
  /// indicator (see [sheetListPadding]), so the list runs to the sheet's
  /// bottom edge and scrolls under it, rather than stopping above a solid
  /// band the frame would otherwise reserve there.
  final bool scrollsUnderInset;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final close = showClose ?? title != null;
    final hasBar = title != null ||
        close ||
        confirm != null ||
        trash != null ||
        help != null;
    final fraction = maxHeightFraction;
    final inset = sheetBottomInset(media);
    final foot = footer;

    Widget card(double? maxHeight) => SheetPanel(
          constraints:
              maxHeight == null ? null : BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (handle) const SheetHandle() else const SizedBox(height: 10),
              if (hasBar)
                SheetBar(
                  title: title,
                  subtitle: subtitle,
                  leading: !close
                      ? null
                      : closeIsBack != null
                      ? SheetBackCloseButton(
                          back: closeIsBack!,
                          onTap: onClose,
                        )
                      : SheetCloseButton(onTap: onClose),
                  trailing: confirm != null
                      ? SheetConfirmButton(
                          onTap: confirm!.onTap,
                          label: confirm!.label,
                        )
                      : trash != null
                          ? SheetTrashButton(onTap: trash!)
                          : help != null
                              ? SheetHelpButton(
                                  onTap: help!,
                                  semanticLabel: helpLabel,
                                )
                              : null,
                ),
              Flexible(
                fit: fraction == null ? FlexFit.loose : FlexFit.tight,
                child: Padding(
                  padding: padding.copyWith(
                    bottom: padding.bottom +
                        (foot == null && !scrollsUnderInset ? inset : 0),
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

/// The room a sheet leaves under its last row: the keyboard when one is up, the
/// home indicator when the sheet is attached to the bottom edge, and otherwise
/// (a floating sheet, which has already cleared the indicator) just a small
/// floor, so there is never a tall solid band of nothing under the content.
double sheetBottomInset(MediaQueryData media) =>
    media.viewInsets.bottom > media.padding.bottom
        ? media.viewInsets.bottom
        : math.max(media.padding.bottom, 8.0);

/// A list sheet's padding: the frame's 16pt sides, and at the end room for
/// the home indicator, inside the scroll, so the last row can scroll clear
/// of it while every other row runs under it. Pairs with
/// [SheetFrame.scrollsUnderInset].
EdgeInsets sheetListPadding(BuildContext context) {
  final media = MediaQuery.of(context);
  return EdgeInsets.fromLTRB(16, 0, 16, 20 + sheetBottomInset(media));
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
    final density = Density.of(context);
    final slot = sheetButtonSize(context);
    return SizedBox(
      height: density.sheetBarHeight + (subtitle == null ? 0 : 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (title != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: slot + 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A sheet whose title changes (one with pages) crossfades
                    // it; every other sheet's title never does, so this
                    // costs them nothing.
                    AnimatedSwitcher(
                      duration: MotionScope.of(context).d(theme.motionFast),
                      child: Text(
                        title!,
                        key: ValueKey(title),
                        style: sheetTitleStyle(theme),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                leading ?? SizedBox(width: slot),
                const Spacer(),
                trailing ?? SizedBox(width: slot),
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

/// [kSheetButtonSize] at the current [Density]: 32 in the compact desktop
/// layout, where every chrome disc is.
double sheetButtonSize(BuildContext context) =>
    Density.of(context).iconButton;

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
        // Esc dismisses a sheet only when this × would just pop it; a custom
        // close (a discard prompt) is not what Esc does.
        shortcut: onTap == null ? AppShortcuts.back : null,
      );
}

/// A sheet's leading button for a sheet with pages: × on the first page,
/// ‹ on any page under it, the glyph turning and swapping in place rather
/// than a second button appearing beside the first.
class SheetBackCloseButton extends StatelessWidget {
  const SheetBackCloseButton({super.key, required this.back, this.onTap});

  final bool back;

  /// Defaults to popping the sheet (which a sheet on an inner page should
  /// intercept with a `PopScope`).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final density = Density.of(context);
    final motion = MotionScope.of(context);
    final m = MaterialLocalizations.of(context);
    final label = back ? m.backButtonTooltip : m.closeButtonLabel;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return HoverHint(
      label: label,
      child: Semantics(
        button: true,
        label: label,
        child: ChromeDisc(
          size: density.iconButton,
          still: true,
          onTap: onTap ?? () => Navigator.of(context).maybePop(),
          child: AnimatedSwitcher(
            duration: motion.d(theme.motionMed),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => RotationTransition(
              turns: Tween(begin: back ? -0.25 : 0.25, end: 0.0).animate(anim),
              child: ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
            ),
            child: Icon(
              back
                  ? (rtl
                        ? CupertinoIcons.chevron_right
                        : CupertinoIcons.chevron_left)
                  : CupertinoIcons.xmark,
              key: ValueKey(back),
              size: density.iconGlyph(back ? 19 : 17),
              color: theme.ink,
            ),
          ),
        ),
      ),
    );
  }
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
    final density = Density.of(context);
    final name = label ?? MaterialLocalizations.of(context).okButtonLabel;
    return HoverHint(
      label: name,
      enabled: enabled,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: name,
        child: ChromeDisc(
          size: density.iconButton,
          still: true,
          tint: enabled ? theme.accent : null,
          onTap: onTap,
          child: Icon(
            CupertinoIcons.checkmark_alt,
            size: density.iconGlyph(19),
            color: enabled ? theme.accentInk : theme.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// The trash a sheet's bar may wear on its TRAILING edge, instead of a ✓,
/// when the sheet shows something of yours and deleting it is the one
/// action (§0.1 of the round-2 rulings). The still chrome disc with a red
/// 18pt glyph. Follow the tap with `showConfirmSheet`.
/// The "?" a [SheetFrame] wears on its trailing edge when it has [SheetFrame.help]:
/// the same glass disc as the ×, so the bar reads as one piece of chrome.
class SheetHelpButton extends StatelessWidget {
  const SheetHelpButton({super.key, required this.onTap, this.semanticLabel});
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GlassIconButton(
      still: true,
      icon: CupertinoIcons.question,
      iconSize: 18,
      color: theme.ink,
      onTap: onTap,
      semanticLabel: semanticLabel,
    );
  }
}

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
    final inset = sheetBottomInset(media);
    final foot = widget.footer;
    final radius = Radius.circular(sheetRadius(theme));
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

// ── The dialog family ───────────────────────────────────────────────────
//
// The action sheet, the confirm sheet and the alert are one family, drawn
// with the app's own light rather than a copy of the system's: a SOLID panel
// lit from above (a soft highlight at the top, a little shade at the foot, a
// specular rim, a soft shadow), the same recipe as the chrome disc. Raised
// things (the Cancel capsule, the emblem) take a shadow and a rim; recessed
// things (the group of choices) sit flat in the panel. Nothing here blurs, so
// all of it is free on a sheet that slides.

/// Radius of a row on a dialog sheet: concentric with the sheet's corner, less
/// the 16pt it is inset by.
double dialogRowRadius(AppTheme theme) =>
    (sheetRadius(theme) - 16).clamp(6.0, 22.0);

/// Radius of a dialog's Cancel capsule: a full capsule on every theme, like
/// the [SheetActionButton] it sits under (the app's one button shape), even
/// where the rows beside it take a square theme's small radius.
const double kDialogCancelRadius = 999;

/// A sheet panel: the theme's solid [sheetFill], lit from above.
///
/// What [SheetFrame] and `SheetSurface` paint instead of a flat colour. The
/// highlight (white, ~170pt tall) and the shade at the foot are paint-only,
/// drawn UNDER the content, so nothing on the sheet is dimmed by them. The
/// route draws the rim, the hairline and the shadow outside (see
/// `showAdaptiveSheet`).
class SheetPanel extends StatelessWidget {
  const SheetPanel({super.key, required this.child, this.radius, this.constraints});

  final Widget child;

  /// The panel's corners; the sheet's top radius when null.
  final BorderRadius? radius;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      constraints: constraints,
      child: CustomPaint(
        painter: _PanelLight(
          fill: sheetFill(theme),
          light: theme.isLight,
          radius: radius ??
              BorderRadius.vertical(top: Radius.circular(sheetRadius(theme))),
        ),
        child: child,
      ),
    );
  }
}

class _PanelLight extends CustomPainter {
  const _PanelLight({
    required this.fill,
    required this.light,
    required this.radius,
  });

  final Color fill;
  final bool light;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.save();
    canvas.clipRRect(rrect);
    // Sunlight from the top: white fading out over the first 170pt.
    final lit = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height < 170 ? size.height : 170,
    );
    canvas.drawRect(
      lit,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: light ? 0.7 : 0.075),
            // Transparent WHITE: fading to transparent black greys the band.
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(lit),
    );
    // The foot falls into a little shade, so the panel reads as lit, not flat.
    final shade = Rect.fromLTWH(
      0,
      size.height < 120 ? 0 : size.height - 120,
      size.width,
      size.height < 120 ? size.height : 120,
    );
    canvas.drawRect(
      shade,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: light ? 0.04 : 0.16),
          ],
        ).createShader(shade),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PanelLight old) =>
      old.fill != fill || old.light != light || old.radius != radius;
}

/// The shadow under a floating dialog panel (a sheet or an alert): the house
/// shadow of [sunlitShadows] (a wide soft fall in the theme's own ink on light
/// pages, and a tight contact line), lifted higher for a panel this big.
List<BoxShadow> dialogShadows(AppTheme theme) =>
    sunlitShadows(theme, lift: 1.4);

/// The lit edge of a dialog panel, painted over it: a hairline that is absent
/// at the lit top and falls into shade at the foot (light themes, where a
/// white rim has nothing to show against), then the [SpecularRim].
class DialogEdge extends CustomPainter {
  const DialogEdge({required this.radius, required this.light});

  final double radius;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final rect = Offset.zero & size;
    if (light) {
      canvas.drawPath(
        shape.getOuterPath(rect.deflate(0.25)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0),
              Colors.black.withValues(alpha: 0.14),
            ],
            stops: const [0.2, 1],
          ).createShader(rect),
      );
    }
    SpecularRim(shape: shape, light: light).paint(canvas, size);
  }

  @override
  bool shouldRepaint(DialogEdge old) =>
      old.radius != radius || old.light != light;
}

/// A white highlight fading out down a surface — the sunlight on a raised
/// control. A widget of its own because a [BoxDecoration] that has both a
/// colour and a gradient paints only the gradient: the fill goes under this,
/// in an outer decoration.
class _Sheen extends StatelessWidget {
  const _Sheen({
    required this.alpha,
    this.reach = 0.55,
    this.radius,
    this.circle = false,
    this.child,
  });

  final double alpha;
  final double reach;
  final double? radius;
  final bool circle;
  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              circle || radius == null ? null : BorderRadius.circular(radius!),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: alpha),
              Colors.white.withValues(alpha: 0),
            ],
            stops: [0, reach],
          ),
        ),
        child: child,
      );
}

/// A round, sunlit emblem for the top of a dialog: a pale wash of [tone] over
/// the sheet, a highlight from above, a specular rim and a soft glow of the
/// tone beneath, the chrome disc's recipe in a colour. The glyph is [tone].
class DialogEmblem extends StatelessWidget {
  const DialogEmblem({super.key, required this.icon, this.tone, this.size = 60});

  final IconData icon;

  /// The emblem's colour; the theme's danger when null.
  final Color? tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final light = theme.isLight;
    final color = tone ?? theme.danger;
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: light ? 0.24 : 0.30),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: light ? 0.06 : 0.25),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: CustomPaint(
            foregroundPainter: SpecularRim(
              shape: const CircleBorder(),
              light: light,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.alphaBlend(
                  color.withValues(alpha: light ? 0.14 : 0.24),
                  light ? sheetFill(theme) : chromeDiscFill(theme),
                ),
              ),
              child: _Sheen(
                alpha: light ? 0.6 : 0.12,
                reach: 0.6,
                circle: true,
                child: Center(child: Icon(icon, size: size * 0.46, color: color)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The title block of a dialog sheet: an optional [emblem], the title, what it
/// means, and an optional [note] (a quiet tinted capsule — "this cannot be
/// undone"). Centred; long text wraps rather than ellipsizes, and the block
/// scrolls if a big text size would push the buttons off the screen.
class DialogHeader extends StatelessWidget {
  const DialogHeader({
    super.key,
    this.title,
    this.message,
    this.note,
    this.emblem,
  });

  final String? title;
  final String? message;
  final String? note;
  final Widget? emblem;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Flexible(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(8, emblem != null ? 8 : 12, 8, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (emblem != null) ...[emblem!, const SizedBox(height: 16)],
            if (title != null)
              Text(
                sentenceCaseOf(context, title!),
                textAlign: TextAlign.center,
                style: dialogTitleStyle(theme),
              ),
            if (title != null && message != null) const SizedBox(height: 8),
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: groupedFooterStyle(theme)
                    .copyWith(color: theme.inkSoft, height: 1.4),
              ),
            if (note != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.danger.withValues(alpha: theme.isLight ? 0.10 : 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: groupedMetaStyle(theme).copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.danger,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A dialog's title: 18/w700 on the theme's emphasis face, upright even on
/// themes whose emphasis is italic.
TextStyle dialogTitleStyle(AppTheme theme, {double size = 18}) =>
    theme.bodyEmph.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      fontStyle: FontStyle.normal,
      height: 1.25,
      color: theme.ink,
    );

/// A recessed group of choices on a dialog sheet: rows on the group fill, a
/// hairline between, no shadow — the quiet counterpart of the raised Cancel.
class DialogGroup extends StatelessWidget {
  const DialogGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(dialogRowRadius(theme)),
      child: ColoredBox(
        color: sheetGroupFill(theme),
        child: _Sheen(
          alpha: theme.isLight ? 0.35 : 0.04,
          reach: 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Container(
                    height: hairline,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: theme.ink.withValues(alpha: 0.10),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice on a dialog sheet. [destructive] draws it as its own tinted pill
/// with a solid red disc for its glyph, so it reads as the weighty answer
/// without being a bare red word; a plain one sits in a [DialogGroup].
class DialogActionRow extends StatelessWidget {
  const DialogActionRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final light = theme.isLight;
    final radius = dialogRowRadius(theme);
    final text = sentenceCaseOf(context, label);
    final tone = destructive ? theme.danger : theme.ink;

    // Rows with a glyph read as a list, glyph and label from the leading
    // edge; a bare label is centred.
    Widget content() => Row(
          mainAxisSize: icon == null ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment:
              icon == null ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            if (icon != null) ...[
              _RowDisc(icon: icon!, destructive: destructive),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                text,
                textAlign: icon == null ? TextAlign.center : TextAlign.start,
                style: theme.body.copyWith(
                  fontSize: 17,
                  fontWeight: destructive ? FontWeight.w600 : FontWeight.w500,
                  color: tone,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        );

    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: destructive ? 0.98 : 1,
      semanticLabel: text,
      focusRadius: radius,
      builder: (context, pressed) {
        final body = Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.center,
          child: content(),
        );
        if (!destructive) {
          return ColoredBox(
            color: pressed
                ? theme.ink.withValues(alpha: light ? 0.07 : 0.10)
                : Colors.transparent,
            child: body,
          );
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: Color.alphaBlend(
              theme.danger.withValues(
                alpha: (light ? 0.10 : 0.17) + (pressed ? 0.07 : 0),
              ),
              sheetFill(theme),
            ),
            border: Border.all(
              color: theme.danger.withValues(alpha: light ? 0.16 : 0.26),
              width: 0.75,
            ),
          ),
          child: _Sheen(alpha: light ? 0.5 : 0.07, radius: radius, child: body),
        );
      },
    );
  }
}

/// The glyph disc of a [DialogActionRow]: solid, lit red for a destructive
/// one (white glyph), a soft ink wash for a plain one.
class _RowDisc extends StatelessWidget {
  const _RowDisc({required this.icon, required this.destructive});
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final light = theme.isLight;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: destructive ? theme.danger : theme.ink.withValues(alpha: 0.08),
        boxShadow: destructive
            ? [
                BoxShadow(
                  color: theme.danger.withValues(alpha: light ? 0.30 : 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: _Sheen(
        alpha: destructive ? 0.28 : 0,
        reach: 0.7,
        circle: true,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 17,
            color: destructive ? Colors.white : theme.ink,
          ),
        ),
      ),
    );
  }
}

/// A dialog's way out: a raised capsule of its own, the chrome disc's recipe
/// stretched wide (its fill, a top highlight, the specular rim, a soft shadow),
/// below and apart from the choices. Autofocused by the sheets that carry one,
/// so Enter on a freshly opened destructive dialog backs out.
class DialogCancelButton extends StatelessWidget {
  const DialogCancelButton({
    super.key,
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.minHeight = 54,
  });

  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final light = theme.isLight;
    const radius = kDialogCancelRadius;
    final text = sentenceCaseOf(context, label);
    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: 0.97,
      autofocus: autofocus,
      semanticLabel: text,
      focusRadius: radius,
      builder: (context, pressed) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: light ? 0.10 : 0.30),
              blurRadius: light ? 10 : 12,
              offset: Offset(0, light ? 1 : 3),
            ),
          ],
        ),
        child: CustomPaint(
          foregroundPainter:
              SpecularRim(shape: const StadiumBorder(), light: light),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: pressed
                  ? Color.alphaBlend(
                      Colors.white.withValues(alpha: light ? 0.18 : 0.06),
                      chromeDiscFill(theme),
                    )
                  : chromeDiscFill(theme),
            ),
            child: _Sheen(
              alpha: light ? 0.35 : 0.08,
              radius: radius,
              child: Container(
                constraints: BoxConstraints(minHeight: minHeight),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: actionButtonLabelStyle(theme).copyWith(color: theme.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

/// The action sheet: the floating card every sheet is, holding an optional
/// title and message, then the choices, then Cancel on a capsule of its own.
/// Plain choices share one recessed group; a [IosSheetAction.destructive] one
/// is its own tinted pill. Returns the chosen action's value, or null for
/// Cancel / dismissal.
///
/// [icon] puts a sunlit emblem over the title (see [DialogEmblem]), tinted
/// danger when any action is destructive and accent otherwise.
Future<T?> showIosActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<IosSheetAction<T>> actions,
  String? cancelLabel,
  IconData? icon,
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
      icon: icon,
    ),
  );
}

class _IosActionSheet<T> extends StatelessWidget {
  const _IosActionSheet({
    required this.title,
    required this.message,
    required this.actions,
    required this.cancelLabel,
    required this.icon,
  });

  final String? title;
  final String? message;
  final List<IosSheetAction<T>> actions;
  final String? cancelLabel;
  final IconData? icon;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final cancel = cancelLabel ??
        AppLocalizations.of(context).destructiveSheetCancelButtonLabel;

    Widget row(IosSheetAction<T> a) => DialogActionRow(
          label: a.label,
          icon: a.icon,
          destructive: a.destructive,
          onTap: () {
            if (a.destructive) HapticFeedback.heavyImpact();
            Navigator.of(context).pop(a.value);
          },
        );

    // Consecutive plain choices share a group; a destructive one stands alone.
    final blocks = <Widget>[];
    var plain = <Widget>[];
    void flush() {
      if (plain.isEmpty) return;
      blocks.add(DialogGroup(children: plain));
      plain = [];
    }

    for (final a in actions) {
      if (a.destructive) {
        flush();
        blocks.add(row(a));
      } else {
        plain.add(row(a));
      }
    }
    flush();

    final anyDestructive = actions.any((a) => a.destructive);
    return SheetPanel(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              if (title != null || message != null || icon != null)
                DialogHeader(
                  title: title,
                  message: message,
                  emblem: icon == null
                      ? null
                      : DialogEmblem(
                          icon: icon!,
                          tone: anyDestructive ? theme.danger : theme.accent,
                        ),
                )
              else
                const SizedBox(height: 10),
              for (final b in blocks) ...[b, const SizedBox(height: _gap)],
              const SizedBox(height: 6),
              // Autofocused so Enter on a freshly opened destructive sheet
              // cancels rather than destroys: the desktop convention.
              DialogCancelButton(
                label: cancel,
                autofocus: true,
                onTap: () => Navigator.of(context).pop(),
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
                        left: groupedDividerInset(
                          children[i],
                          Density.of(context),
                        ),
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
/// truncates. The panel is the action sheet's own — solid, lit from above,
/// rimmed and shadowed — and the way out is the same raised capsule.
/// [icon] puts a sunlit emblem over the title (see [DialogEmblem]).
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
  IconData? icon,
}) {
  final calm = MotionScope.of(context).calm;
  final dismissible = actions.any((a) => a.cancel);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    // In: ~300ms on a spring-ish settle. Out: the first 180ms of the same
    // 300 (the reverse curves below are `Interval(0.4, 1)`), quicker, no wobble.
    transitionDuration: Duration(milliseconds: calm ? 0 : 300),
    pageBuilder: (ctx, _, _) => _IosAlert<T>(
      title: title,
      message: message,
      actions: actions,
      field: field,
      icon: icon,
    ),
    // Arrives from 112% (a spring's soft settle, clamped for the fade) and
    // leaves to 92%. A solid card: nothing here blurs, so scaling is free.
    transitionBuilder: (ctx, anim, _, child) {
      if (calm) return child;
      final curved = CurvedAnimation(
        parent: anim,
        curve: const _AlertSettle(),
        reverseCurve: const Interval(0.4, 1, curve: Curves.easeInCubic),
      );
      final fade = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOut,
        reverseCurve: const Interval(0.4, 1, curve: Curves.easeIn),
      );
      return FadeTransition(
        opacity: fade,
        child: AnimatedBuilder(
          animation: anim,
          builder: (_, c) {
            final t = curved.value;
            final scale = anim.status == AnimationStatus.reverse
                ? 0.92 + 0.08 * t
                : 1.12 - 0.12 * t;
            return Transform.scale(scale: scale, child: c);
          },
          child: child,
        ),
      );
    },
  );
}

/// A spring-ish ease-out with a hair of overshoot, for the alert's scale.
class _AlertSettle extends Curve {
  const _AlertSettle();
  @override
  double transformInternal(double t) {
    const s = 0.9;
    final u = t - 1;
    return u * u * ((s + 1) * u + s) + 1;
  }
}

class _IosAlert<T> extends StatelessWidget {
  const _IosAlert({
    required this.title,
    required this.message,
    required this.actions,
    required this.field,
    required this.icon,
  });

  final String? title;
  final String? message;
  final List<IosAlertAction<T>> actions;
  final IosAlertField? field;
  final IconData? icon;

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
    final radius = (theme.radiusXl * 1.4).clamp(10.0, 30.0);
    final f = field;

    Widget button(IosAlertAction<T> a) => a.cancel
        ? DialogCancelButton(
            label: a.label,
            onTap: () => Navigator.of(context).pop(a.value),
            autofocus: f == null,
            minHeight: 46,
          )
        : SheetActionButton(
            label: a.label,
            onTap: () => Navigator.of(context).pop(a.value),
            tonal: !_filled(a),
            destructive: a.destructive,
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: dialogShadows(theme),
              ),
              child: CustomPaint(
                foregroundPainter: DialogEdge(radius: radius, light: theme.isLight),
                child: SheetPanel(
                  radius: BorderRadius.circular(radius),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (icon != null) ...[
                            Center(
                              child: DialogEmblem(
                                icon: icon!,
                                size: 52,
                                tone: actions.any((a) => a.destructive)
                                    ? theme.danger
                                    : theme.accent,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (title != null)
                            Text(
                              sentenceCaseOf(context, title!),
                              textAlign: TextAlign.center,
                              style: dialogTitleStyle(theme, size: 17),
                            ),
                          if (title != null && message != null)
                            const SizedBox(height: 6),
                          if (message != null)
                            Text(
                              message!,
                              textAlign: TextAlign.center,
                              style: groupedFooterStyle(theme)
                                  .copyWith(color: theme.inkSoft, height: 1.4),
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
                          const SizedBox(height: 22),
                          buttons,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
