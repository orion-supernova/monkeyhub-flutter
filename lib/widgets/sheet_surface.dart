import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'sheet_kit.dart' show SheetHandle, SheetPanel, sheetRadius;

/// The panel every group-administration sheet is drawn on.
///
/// **Deliberately identical to the shell `destructive_sheet.dart` already
/// uses** — `theme.surface`, rounded on the top corners only, flush to the
/// bottom and both sides, [SheetHandle] on top. These four sheets sit
/// alongside the block sheet, the mute sheet and the confirm sheet, and a
/// bottom sheet shaped differently from its neighbours reads as a bug no
/// matter how nice it looks in isolation.
///
/// (Since the glass pass the route floats every compact sheet; the panel is
/// still top-rounded here and the route's clip rounds the bottom corners.)
///
/// It took two wrong turns to get here, and both are worth not repeating:
///
///  * **Glass.** `showAdaptiveSheet` presents these through
///    `showModalBottomSheet`, which SLIDES the panel up — so a `BackdropFilter`
///    inside is re-rasterized every frame of the transition, at full sheet
///    width, in an app whose chrome already stacks several of them.
///    The old call-kind picker (since retired for two plain buttons) named
///    it exactly: "the surface itself appears instantly to keep
///    BackdropFilter off the per-frame compositing path (animating a blur is
///    the main source of jank here)". The picker could do glass because it
///    did not animate its surface; a bottom sheet has no such option. It also
///    bought almost nothing — a modal sheet's `black54`
///    scrim has already painted out most of what a blur is there to reveal.
///  * **Floating.** Insetting the panel from all four edges is a real idiom,
///    but not THIS app's, and the gap it left underneath read as a mistake
///    rather than a choice. Consistency was the premium answer; novelty was
///    not.
///
/// The surface is still SOLID, but no longer flat: it is a `SheetPanel` (a soft
/// highlight at the top, a little shade at the foot), and the route draws the
/// rim and the shadow around it, so a light sheet has depth too.
///
/// What this widget is actually for is the thing that stayed true throughout:
/// **`showAdaptiveSheet` passes `backgroundColor: Colors.transparent`**, so
/// painting the surface is the CONTENT's job. All four sheets forgot, and
/// rendered as a floating column of text over the chat list — no error,
/// nothing wrong in a widget test. One shared widget is one place to get that
/// right, which is the same reason `sheet_buttons.dart` exists.
class SheetSurface extends StatelessWidget {
  const SheetSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
  });

  final Widget child;

  /// The bottom value is the inset ABOVE the home indicator, not the total —
  /// the safe-area padding is added to it. A sheet cannot read that inset from
  /// a `SafeArea` inside itself, because `ModalBottomSheetRoute` has already
  /// removed it.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final media = MediaQuery.of(context);
    // The panel is lit from above (see [SheetPanel]): the same solid fill, with
    // a soft highlight at the top and a little shade at the foot. Still no
    // blur — the route draws the rim and the shadow around it.
    return SheetPanel(
      radius: BorderRadius.vertical(top: Radius.circular(sheetRadius(theme))),
      child: Padding(
        // NO bottom inset on the panel itself — it runs to the screen edge.
        //
        // Adding the home-indicator inset here padded the SURFACE, which lifted
        // the whole sheet off the bottom of the screen and left a band of
        // scrim under it. A bottom sheet is supposed to be attached; the
        // indicator is cleared by padding the CONTENT instead, below, so the
        // panel touches the edge and the last row still sits above the
        // indicator.
        padding: padding.copyWith(bottom: 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The grabber stays put; only the content below it scrolls. A handle
            // that scrolls away is a handle you cannot reach to drag the sheet
            // shut.
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SheetHandle(),
            ),
            // Flexible, not Expanded: the sheet still shrink-wraps short content
            // (a four-row member menu should not become full height), and only
            // starts scrolling once it would otherwise run off the screen.
            //
            // The invite sheet is the one that forced this — QR, code, two rows
            // of limit chips, two switches and three buttons overflowed on a
            // phone, and because nothing scrolled the regenerate and revoke
            // actions at the bottom were simply unreachable.
            Flexible(
              child: SingleChildScrollView(
                // Always draggable, even when the content fits, so a pull
                // from anywhere on the panel closes it. Not bouncing: the
                // sheet's pull physics come from the host as this one's
                // parent, and a bounce never hands them the drag (see
                // sheet_drag.dart).
                physics: const AlwaysScrollableScrollPhysics(),
                // The breathing room lives HERE, inside the scroller: the
                // panel's own padding, the home indicator, and the keyboard when
                // one is up. `isScrollControlled` sheets are not moved by the
                // IME on their own, so without the last term a field scrolls
                // under the keyboard with no way to reach it.
                padding: EdgeInsets.only(
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
