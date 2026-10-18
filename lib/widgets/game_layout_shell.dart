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
    this.stage,
  });

  /// The desktop shape: when set and the space this shell is given is wide
  /// and tall enough ([GameStage.fits]), the page stops being a scrolling
  /// column. The board takes every pixel of height the header leaves, the
  /// [GameStage.panel] runs the full height beside it (players, clocks, move
  /// list, tools: whatever the game puts there), and nothing scrolls but the
  /// panel. Below that size, [header] / [board] / [sidebar] as before, so a
  /// phone never sees the stage.
  final GameStage? stage;

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
    final stage = this.stage;
    if (stage == null) return _column(context, physics);
    // Decided by the space this shell actually has, not by the window: in the
    // split shell a game opens in the chat pane, which is narrower than the
    // window it sits in.
    return LayoutBuilder(
      builder: (context, box) => stage.fits(box.biggest)
          ? _Stage(header: header, stage: stage)
          : _column(context, physics),
    );
  }

  Widget _column(BuildContext context, ScrollPhysics? physics) {
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

/// What a game screen hands [GameLayoutShell] for its wide shape: the board on
/// its own, at its aspect ratio, and the panel that sits beside it.
///
/// Laid out the way desktop chess sites do it (lichess, not a phone stretched
/// sideways): the board is as big as the window allows, height first, and the
/// panel beside it carries the players at its top and bottom edges with the
/// game's history between them, so nothing has to be measured to line up with
/// the board.
class GameStage {
  const GameStage({
    required this.board,
    required this.panel,
    this.aspectRatio = 1,
    this.leading,
    this.leadingWidth = 84,
    this.panelWidth = 340,
    this.maxBoard = 920,
    this.minWidth = 860,
    this.minHeight = 520,
  });

  /// The board alone: no plates, no tools. Sized by the stage.
  final Widget board;

  /// Width over height of [board].
  final double aspectRatio;

  /// Full height beside the board. It gets bounded constraints, so a
  /// `Column` with an `Expanded` list in it works, and so does a
  /// `SingleChildScrollView`.
  final Widget panel;

  /// An optional rail on the board's other side (a keypad).
  final Widget? leading;
  final double leadingWidth;
  final double panelWidth;

  /// The board's longest side never grows past this, however big the monitor.
  final double maxBoard;

  /// Below either, the shell keeps the phone column.
  final double minWidth;
  final double minHeight;

  bool fits(Size space) =>
      space.width >= minWidth && space.height >= minHeight;
}

class _Stage extends StatelessWidget {
  const _Stage({required this.header, required this.stage});

  final List<Widget> header;
  final GameStage stage;

  @override
  Widget build(BuildContext context) {
    final leading = stage.leading;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: stage.maxBoard +
                stage.panelWidth +
                32 +
                (leading == null ? 0 : stage.leadingWidth + 24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...header,
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leading != null) ...[
                      SizedBox(width: stage.leadingWidth, child: leading),
                      const SizedBox(width: 24),
                    ],
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: stage.aspectRatio >= 1
                                ? stage.maxBoard
                                : stage.maxBoard * stage.aspectRatio,
                            maxHeight: stage.aspectRatio >= 1
                                ? stage.maxBoard / stage.aspectRatio
                                : stage.maxBoard,
                          ),
                          child: AspectRatio(
                            aspectRatio: stage.aspectRatio,
                            child: stage.board,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    SizedBox(width: stage.panelWidth, child: stage.panel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
