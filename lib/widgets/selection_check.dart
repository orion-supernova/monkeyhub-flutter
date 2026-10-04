import 'package:flutter/cupertino.dart';

import '../theme/theme_scope.dart';

/// The circle that says whether one row is picked.
///
/// Drawn on every row of a surface in selection mode, not only the chosen ones:
/// an empty ring is what tells the reader the whole list is asking a question.
/// The media grid rings every tile for the same reason (`_SelectionVeil` in
/// `media_grid_tile.dart`), and this is the flat-surface half of that idea —
/// the grid's version has to survive on top of a photograph, so it keeps its
/// white ring and dark fill instead.
///
/// Shared by the forward-target sheet and the transcript's multi-select so the
/// two never drift apart; both are "pick some rows, then act on them".
///
/// THE selection circle — every pick-some list (forward, group-call members,
/// invite friends, linked accounts, child setup) draws this, never a private
/// `_Check`/`_SelectionDot`. [media] is the over-a-photo variant (white ring,
/// dark wash) for grids and viewers.
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({
    super.key,
    required this.picked,
    this.size = 22,
    this.media = false,
    this.enabled = true,
  });

  final bool picked;
  final double size;

  /// Over a photo: a white ring on a dark wash, legible on any picture.
  final bool media;

  /// False dims it — a row that cannot be picked (already a member).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final Color ring;
    final Color fill;
    if (picked) {
      ring = theme.accent;
      fill = theme.accent;
    } else if (media) {
      ring = const Color(0xE6FFFFFF);
      fill = const Color(0x33000000);
    } else {
      // The theme's ink, not its divider token: on several palettes the
      // divider is near-invisible, and an empty ring that cannot be seen
      // does not ask the question.
      ring = theme.ink.withValues(alpha: 0.30);
      fill = const Color(0x00000000);
    }
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: theme.motionEntrance,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: media ? 1.6 : 1.4),
        ),
        child: picked
            ? Icon(
                CupertinoIcons.checkmark_alt,
                size: size * 0.72,
                color: theme.accentInk,
              )
            : null,
      ),
    );
  }
}
