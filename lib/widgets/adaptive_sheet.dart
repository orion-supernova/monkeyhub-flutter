import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'glass_reveal.dart';
import 'glass_surface.dart';
import 'sheet_drag.dart';
import 'sheet_kit.dart' show DialogEdge, dialogShadows, sheetRadius;

/// Presents modal content adaptively: a bottom sheet on compact (phone)
/// windows, a floating desktop popover on wider (desktop/web) windows — where
/// a panel sliding up from the bottom of a large window feels out of place.
///
/// Signature mirrors [showModalBottomSheet] so migration is mechanical: most
/// call sites just swap the function name and drop the now-default
/// `backgroundColor`/`isScrollControlled` arguments. The existing sheet
/// content widgets already build their own themed, top-rounded container via
/// `AppTheme.sheetDecoration()` — on desktop that container is wrapped in
/// [GlassSurface], whose own fully-rounded `ClipRRect` clips away the flat
/// bottom corners, so it reads as a proper floating card with no changes
/// needed inside the content widgets themselves.
///
/// `isDismissible: false` (plus `enableDrag: false`) makes the sheet
/// undismissable by tap-outside or drag in both forms — for the rare modal that
/// has to be answered, like a mandatory update. Pair it with a
/// `PopScope(canPop: false)` in the content to also block Android back and Esc.
///
/// Compact sheets FLOAT: 8pt in from the sides, lifted to hug the home
/// indicator ([sheetBottomLift]), all four corners [sheetRadius], moving on a
/// spring ([SheetDragHost]). Content sees only the bottom inset left over
/// after the lift, so `SheetFrame`/`SheetSurface` need no special case.
///
/// Every compact sheet stops below the top safe area (see `useSafeArea`) and
/// 8pt short of it, so the page underneath peeks out under the island the
/// way iOS stacks a sheet. Its scrolling body pulls it closed when that body
/// is a `SheetScrollBody` (the [SheetDragHost] wrapped around it here).
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color backgroundColor = Colors.transparent,
  bool useRootNavigator = false,
  double maxWidth = 460,
  bool isDismissible = true,
  bool enableDrag = true,

  /// Bounds the bottom sheet by the window's top safe area instead of by the
  /// raw screen height. On by default: a sheet that grows (a keyboard, a long
  /// list, a big text size) otherwise runs up under the notch or the Dynamic
  /// Island, bar and × included — the point composer did exactly that. Off
  /// only for a sheet that deliberately paints edge to edge.
  ///
  /// Worth knowing before reaching for anything else: `ModalBottomSheetRoute`
  /// wraps its content in `MediaQuery.removePadding(removeTop: true)`, which
  /// zeroes `padding.top` AND `viewPadding.top` for everything inside the
  /// sheet. So a sheet cannot read the top inset itself, and a `SafeArea` added
  /// inside the content widget is a silent no-op. This flag is the hook that
  /// applies it from OUTSIDE, at the route level, where the padding is still
  /// intact.
  bool useSafeArea = true,
}) {
  if (context.isCompact) {
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    final theme = ThemeScope.of(context);
    return navigator.push<T>(
      _FloatingSheetRoute<T>(
        builder: builder,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        // The dim: Signal's black 40% on a dark page, 20% on a light one,
        // where the same black reads far heavier.
        scrim: Colors.black.withValues(alpha: theme.isLight ? 0.20 : 0.40),
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        isScrollControlled: isScrollControlled,
        useSafeArea: useSafeArea,
        backgroundColor: backgroundColor,
        calm: MotionScope.of(context).calm,
      ),
    );
  }
  final theme = ThemeScope.of(context);
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: theme.motionFast,
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // Content widgets are authored for a full-width bottom sheet; give
        // them bounded height and let them scroll internally if the
        // viewport is short, so nothing overflows in the popover form.
        child: GlassSurface(
          radius: theme.radiusXl,
          padding: EdgeInsets.zero,
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(child: builder(dialogContext)),
          ),
        ),
      ),
    ),
    // A restrained grow + rise, in the same voice as the message action
    // menu's own entrance animation — showDialog's default fade-only
    // transition read as too abrupt for a card this size.
    //
    // Grown, not faded: the card is glass, and a fading layer leaves its blur
    // sampling an empty buffer, a flat wash for the whole fade and a snap to
    // frost at the end. Its content still fades, inside the glass; see
    // [GlassReveal].
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: theme.motionEntrance,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: AnimatedBuilder(
          animation: curved,
          builder: (_, child) =>
              GlassReveal(t: curved.value, from: 0.85, child: child!),
          child: child,
        ),
      );
    },
  );
}

/// Inset of a floating sheet from the left and right edges.
const double kSheetInset = 8;

/// How far above the screen's bottom edge a floating sheet rests: it hugs the
/// home indicator the way iOS 26's do. The card's content ends on its own
/// bottom padding, clear of the indicator, with no extra inset inside it.
double sheetBottomLift(double safeBottom) =>
    math.max(kSheetInset, safeBottom - 26);

/// The compact sheet's route: a card that floats 8pt in from the sides and
/// [sheetBottomLift] up from the bottom, all four corners rounded.
///
/// Not `ModalBottomSheetRoute`: that animates its child with a fixed-duration
/// curve and drags it with its own ballistics. Here the route owns only the
/// scrim (a short fade) and its own lifetime; the sheet's motion is a spring
/// owned by [SheetDragHost], which also hands a fling's velocity on to the
/// exit. The route stays on the stack for [reverseTransitionDuration], long
/// enough for that exit to clear the screen.
class _FloatingSheetRoute<T> extends PopupRoute<T> {
  _FloatingSheetRoute({
    required this.builder,
    required this.capturedThemes,
    required this.barrierLabel,
    required this.scrim,
    required this.isDismissible,
    required this.enableDrag,
    required this.isScrollControlled,
    required this.useSafeArea,
    required this.backgroundColor,
    required this.calm,
  });

  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;
  final Color scrim;
  final bool isDismissible;
  final bool enableDrag;
  final bool isScrollControlled;
  final bool useSafeArea;
  final Color backgroundColor;
  final bool calm;

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => scrim;

  @override
  bool get barrierDismissible => isDismissible;

  @override
  Duration get transitionDuration =>
      calm ? Duration.zero : const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration =>
      calm ? Duration.zero : const Duration(milliseconds: 320);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final theme = ThemeScope.of(context);
    final lift = sheetBottomLift(media.viewPadding.bottom);
    final radius = sheetRadius(theme);
    final top = (useSafeArea ? media.padding.top : 0.0) + 8;

    // What the sheet's content sees: the top inset is spent (the route placed
    // the sheet below it), and the bottom insets are what is LEFT after the
    // sheet's own lift. The home indicator is spent too: the card floats above
    // it and its content ends on its own padding, so no solid band of dead
    // space is left under the last button. A keyboard's height loses the lift,
    // so nothing inside double-counts a gap the route already left.
    double less(double v) => math.max(0.0, v - lift);
    final contentMedia = media.copyWith(
      padding: media.padding.copyWith(top: 0, bottom: 0),
      viewPadding: media.viewPadding.copyWith(top: 0, bottom: 0),
      viewInsets: media.viewInsets.copyWith(
        bottom: less(media.viewInsets.bottom),
      ),
    );

    // The panel's depth lives out here, where the clip is: a soft shadow, and
    // the lit edge painted over the content (see [DialogEdge]). The fill and
    // its sunlight are the content's own (`SheetPanel`), solid, so nothing
    // blurs while the sheet slides.
    Widget panel() => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: dialogShadows(theme),
      ),
      child: CustomPaint(
        foregroundPainter: DialogEdge(radius: radius, light: theme.isLight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Material(
            color: backgroundColor,
            child: Builder(builder: builder),
          ),
        ),
      ),
    );

    return capturedThemes.wrap(
      Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: MediaQuery(
          data: contentMedia,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              kSheetInset + media.padding.left,
              top,
              kSheetInset + media.padding.right,
              lift,
            ),
            child: LayoutBuilder(
              builder: (ctx, box) => Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: box.maxWidth,
                    maxWidth: box.maxWidth,
                    maxHeight: isScrollControlled
                        ? box.maxHeight
                        : box.maxHeight * 9 / 16,
                  ),
                  child: SheetDragHost(
                    enabled: enableDrag && isDismissible,
                    animateIn: true,
                    offscreenExtra: lift + 32,
                    child: panel(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // The scrim is the route's; the sheet moves itself.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
