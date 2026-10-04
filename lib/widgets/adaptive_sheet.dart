import 'package:flutter/material.dart';

import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'glass_surface.dart';
import 'sheet_drag.dart';
import 'sheet_kit.dart' show sheetTopRadius;

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
    final calm = MotionScope.of(context).calm;
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: useSafeArea,
      // The iOS dim: lighter than Material's 54%, so the page underneath
      // still reads as the place the sheet came from.
      barrierColor: Colors.black.withValues(alpha: 0.32),
      // A fast, decelerating rise with no overshoot — a bottom-anchored card
      // that bounces past its rest lifts off the screen edge and shows the
      // page through the gap. The liveliness lives in the content instead
      // (see `SheetRise`).
      sheetAnimationStyle: calm
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 420),
              curve: Cubic(0.16, 1, 0.3, 1),
              reverseDuration: Duration(milliseconds: 260),
              reverseCurve: Curves.easeInCubic,
            ),
      // One corner for every sheet, whatever its content paints. Around
      // fifty sheets draw their own top-rounded panel, at whichever radius
      // their theme's `sheetDecoration` or their own code picked; clipping
      // here gives them all the iOS 26 corner (`sheetTopRadius`) in one
      // place. A plain clip, never animated — the route slides it, the clip
      // rides along for free.
      //
      // Capped 8pt short of the room the route gives it, so a full-height
      // sheet leaves a sliver of the page showing under the island, and
      // wrapped in the host that lets a scrolled-to-top body pull it down.
      builder: (ctx) => SheetDragHost(
        enabled: enableDrag && isDismissible,
        child: LayoutBuilder(
          builder: (ctx, box) => ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: box.maxHeight.isFinite
                  ? (box.maxHeight - 8).clamp(0.0, double.infinity)
                  : double.infinity,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(sheetTopRadius(ThemeScope.of(ctx))),
              ),
              child: builder(ctx),
            ),
          ),
        ),
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
            child: SingleChildScrollView(
              child: builder(dialogContext),
            ),
          ),
        ),
      ),
    ),
    // A restrained scale + fade + rise, in the same voice as the message
    // action menu's own entrance animation — showDialog's default fade-only
    // transition read as too abrupt for a card this size.
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: theme.motionEntrance,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}
