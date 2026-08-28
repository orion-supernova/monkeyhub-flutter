import 'package:flutter/widgets.dart';

/// Draws [child] through the padding its parent list put around it, so a row
/// inside a padded `ListView` can still reach the edges of the surface.
///
/// For the one kind of row that is a *rule* rather than an object: the unread
/// band in the transcript. Everything else in a chat list is a thing sitting in
/// a column and belongs inside the column's margins; a line that means
/// "everything below here is new" has to touch both sides or it reads as one
/// more object floating in the same margins.
///
/// `OverflowBox` is the obvious tool and the wrong one here, because this lives
/// in a scroll view: an `OverflowBox` is sized by its parent, and the parent
/// constraint a sliver hands a row is unbounded in the scroll direction — it
/// would take an infinite height. This keeps the ROW at the width the list gave
/// it and the height its child asks for, and lets only the child overflow,
/// sideways, into the padding. A viewport does not clip its own padding, so the
/// result paints.
///
/// Widths are physical ([EdgeInsets], not [EdgeInsetsDirectional]) because the
/// padding being undone is `ListView.padding`, which is physical too.
class EdgeBleed extends StatelessWidget {
  const EdgeBleed({super.key, required this.bleed, required this.child});

  /// How far past each edge to reach — normally the list's own padding, passed
  /// whole so the call site need not pick it apart. Only [EdgeInsets.left] and
  /// [EdgeInsets.right] are read.
  final EdgeInsets bleed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final row = constraints.maxWidth;
        final wider = row + bleed.left + bleed.right;
        // Degenerate box, or nothing to escape.
        if (row <= 0 || !row.isFinite || wider <= row) return child;
        return FractionallySizedBox(
          widthFactor: wider / row,
          // Where the overflow goes: `left / (left + right)` of it in front of
          // the row and the rest behind, which is plain centre for the
          // symmetric padding a transcript actually uses and still lands flush
          // on both sides if that ever stops being symmetric.
          alignment: Alignment(
            (2 * bleed.left / (bleed.left + bleed.right)) - 1,
            0,
          ),
          child: child,
        );
      },
    );
  }
}
