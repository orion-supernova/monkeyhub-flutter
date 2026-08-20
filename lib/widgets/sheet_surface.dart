import 'package:flutter/material.dart';

import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import 'glass_surface.dart';

/// The panel every group-administration sheet is drawn on.
///
/// **Frosted and floating, not a flat panel welded to the bottom edge.**
///
/// The first cut of this was `Container(color: theme.surface)` with a rounded
/// top — the stock Material bottom sheet. It read as generic Android in an app
/// whose entire chrome is glass: the message action menu, the call picker and
/// the camera controls all sit on [GlassSurface], and a settings sheet that
/// didn't was instantly the odd one out.
///
/// Three things do the work, and all three are the difference between "a sheet"
/// and "this app's sheet":
///
///  * **Blur, not opacity.** [GlassSurface] backdrop-filters what is behind it,
///    so the conversation stays faintly legible under the panel. That is the
///    single strongest cue that a surface is floating ABOVE something rather
///    than replacing it.
///  * **Inset on all four sides.** A sheet flush to the screen edges is a
///    Material sheet; one that floats clear of them, corners fully visible, is
///    the iOS idiom. Corners you can see are corners worth rounding.
///  * **A generous radius.** `radiusXl + 8` rather than `radiusLg`, matched to
///    the action menu, because a big soft corner is most of what reads as
///    "premium" at a glance.
///
/// **`showAdaptiveSheet` passes `backgroundColor: Colors.transparent`**, so the
/// surface is the CONTENT's job. A sheet that forgets renders as a floating
/// column of text over the chat list — no error, nothing wrong in a widget
/// test. That happened, which is why this is one shared widget and not four
/// hand-copied decorations.
class SheetSurface extends StatelessWidget {
  const SheetSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 18),
  });

  final Widget child;
  final EdgeInsets padding;

  /// How far the panel floats clear of the screen edges on a phone.
  static const double _inset = 10;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // On desktop `showAdaptiveSheet` already floats this in a centred,
    // width-capped dialog, so a second inset would be an odd double margin —
    // and there is no home indicator to clear.
    final compact = context.isCompact;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: compact
          ? EdgeInsets.fromLTRB(
              _inset,
              0,
              _inset,
              // Clear of the home indicator rather than tucked under it. The
              // indicator sitting on top of a rounded corner is the detail
              // that makes an otherwise good sheet look unfinished.
              _inset + bottomInset,
            )
          : EdgeInsets.zero,
      child: GlassSurface(
        radius: theme.radiusXl + 8,
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [const _Grabber(), child],
        ),
      ),
    );
  }
}

/// The drag handle, sized and dimmed for glass.
///
/// Not [SheetGrabber] from `destructive_sheet.dart`: that one is tuned for an
/// opaque panel, and at its alpha it disappears against a blurred backdrop.
/// Same gesture affordance, enough contrast to survive the frost.
class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    // Meaningless where dismiss-by-drag isn't a thing — the desktop popover
    // closes via barrier tap or Esc.
    if (!context.isCompact) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        width: 38,
        height: 5,
        decoration: BoxDecoration(
          color: theme.inkMuted.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
