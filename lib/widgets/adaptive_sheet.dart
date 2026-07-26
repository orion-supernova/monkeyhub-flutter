import 'package:flutter/material.dart';

import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import 'glass_surface.dart';

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
Future<T?> showAdaptiveSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color backgroundColor = Colors.transparent,
  bool useRootNavigator = false,
  double maxWidth = 460,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  if (context.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: builder,
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
