import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/layout.dart';
import 'adaptive_page_body.dart';

/// The responsive shape every "one board, some tools, a scoreboard" game
/// screen wears — [GameScaffold] (Queens/Tango/Zip/Sudoku) and the code
/// puzzle's own screen both need it, even though their game STATE has nothing
/// in common (a running-clock `GamePlayController` vs `FeedStore`'s
/// guess-based `PuzzleState`). What they share is purely spatial: a header, a
/// board that should stop growing at some sane size instead of stretching
/// edge to edge, an optional strip of tools beside it, and a scoreboard.
/// Duplicating that Row/Column math per screen is how the two definitions of
/// "sidebar width" drift apart six months from now; this is the one place it
/// lives.
///
/// Compact and medium stay a single reading column, unchanged from how these
/// screens looked before any of this existed. Expanded gets [board] capped at
/// a fixed, comfortable width instead of stretching to fill the reading
/// column — a square board that wide is most of a browser window's height on
/// its own, which is what made a game screen need a scroll a phone never
/// would've — with [sidebar] (the scoreboard) beside it, and [leading] (e.g.
/// the puzzle's icon keypad), when there is one, beside THAT.
class GameLayoutShell extends StatelessWidget {
  const GameLayoutShell({
    super.key,
    required this.header,
    required this.board,
    required this.sidebar,
    this.leading,
    this.leadingWidth = 84,
    this.boardWidth = 440,
    this.sidebarWidth = 320,
    this.scrollLocked,
  });

  final List<Widget> header;
  final List<Widget> board;

  /// The scoreboard/standings — always to the right of [board] on expanded,
  /// always last on compact.
  final Widget sidebar;

  /// An optional rail to the LEFT of [board] on expanded only (the puzzle's
  /// vertical symbol keypad). Compact keeps its own in-flow tools instead —
  /// [board] is responsible for including those on compact, since what goes
  /// where the keys sit differs enough per game that this shell doesn't try
  /// to own it.
  final Widget? leading;
  final double leadingWidth;
  final double boardWidth;
  final double sidebarWidth;

  /// True while the page must hold still — a finger is on the board, and a
  /// scroll that started under it would move the grid out from under the
  /// stroke. Null for a screen with nothing to lock.
  final ValueListenable<bool>? scrollLocked;

  @override
  Widget build(BuildContext context) {
    final lock = scrollLocked;
    if (lock == null) return _build(context, null);
    return ValueListenableBuilder<bool>(
      valueListenable: lock,
      builder: (context, locked, _) => _build(
        context,
        // Swapping the physics, rather than winning a gesture arena, is what
        // makes this hold for every board: a tap board never enters the arena
        // against the page at all, and the page's drag is cancelled outright
        // the moment it can no longer scroll.
        locked ? const NeverScrollableScrollPhysics() : null,
      ),
    );
  }

  Widget _build(BuildContext context, ScrollPhysics? physics) {
    if (!context.isExpanded) {
      return AdaptivePageBody(
        child: ListView(
          physics: physics,
          // The device's bottom inset rides on the scroller rather than being
          // reserved by a `SafeArea` — see [edgeToEdgeBottom]. The board runs
          // to the bottom of the glass and the scoreboard scrolls past the home
          // indicator instead of stopping above a slab of background.
          padding: EdgeInsets.fromLTRB(20, 8, 20, edgeToEdgeBottom(context)),
          children: [
            ...header,
            const SizedBox(height: 20),
            ...board,
            const SizedBox(height: 24),
            sidebar,
          ],
        ),
      );
    }
    return SingleChildScrollView(
      physics: physics,
      padding: EdgeInsets.fromLTRB(20, 8, 20, edgeToEdgeBottom(context)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ContentWidth.wide),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...header,
              const SizedBox(height: 20),
              // [leading] docks flush against the header's own left edge and
              // [sidebar] flush against its right — the whole row spans the
              // column exactly like the header above it, rather than
              // clustering all three together in the middle of it. [board]
              // gets the `Expanded` remainder and centers within THAT, so it
              // still reads as the centrepiece between the two rails instead
              // of drifting to whichever side has the narrower neighbour.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    SizedBox(width: leadingWidth, child: leading),
                    const SizedBox(width: 24),
                  ],
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: boardWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: board,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  SizedBox(width: sidebarWidth, child: sidebar),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
