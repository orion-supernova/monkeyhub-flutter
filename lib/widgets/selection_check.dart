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
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({super.key, required this.picked, this.size = 20});

  final bool picked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedContainer(
      duration: theme.motionFast,
      curve: theme.motionEntrance,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: picked ? theme.accent : const Color(0x00000000),
        shape: BoxShape.circle,
        border: Border.all(
          color: picked ? theme.accent : theme.divider,
          width: 1.4,
        ),
      ),
      child: picked
          ? Icon(
              CupertinoIcons.check_mark,
              size: size * 0.65,
              color: theme.accentInk,
            )
          : null,
    );
  }
}
