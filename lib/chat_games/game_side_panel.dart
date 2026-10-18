import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../screens/games/game_scaffold.dart' show GameTool;
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/chess_pieces.dart';
import '../turn_games/board/turn_board.dart';
import '../widgets/ios_kit.dart';
import 'move_history.dart';

/// The pieces built for both turn-game screens (a bot game on the phone, a
/// game in a chat): the move list, the captured-material strip, the row of
/// game actions and the keyboard. What differs between the two screens is
/// only where the answers come from: a local line and a local "undo", or the
/// server's history and a takeback the other player has to accept.

// ── Captured material ───────────────────────────────────────────────────────

/// The pieces [seat] has taken, small and overlapping, then "+3" when that
/// side is ahead. Empty when nothing has been taken.
class CapturedStrip extends StatelessWidget {
  const CapturedStrip({
    super.key,
    required this.material,
    required this.seat,
    this.size = 16,
  });

  final ChessMaterial material;
  final int seat;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final taken = material.taken[seat];
    final lead = seat == 0 ? material.advantage : -material.advantage;
    if (taken.isEmpty && lead <= 0) return const SizedBox.shrink();
    final dark = SeatPalette(theme, gameId: 'chess').dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (taken.isNotEmpty)
          ExcludeSemantics(
            child: CustomPaint(
              size: Size(size + (taken.length - 1) * size * 0.55, size),
              painter: _TakenPainter(
                taken,
                // The pieces taken are the OTHER side's colour.
                side: 1 - seat,
                style: ChessPieceStyle(darkTheme: dark),
              ),
            ),
          ),
        if (lead > 0) ...[
          const SizedBox(width: 4),
          Text(
            '+$lead',
            style: groupedMetaStyle(theme).copyWith(
              fontWeight: FontWeight.w600,
              color: theme.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _TakenPainter extends CustomPainter {
  _TakenPainter(this.taken, {required this.side, required this.style});

  final List<int> taken;
  final int side;
  final ChessPieceStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height;
    for (var i = 0; i < taken.length; i++) {
      canvas.save();
      canvas.translate(i * s * 0.55, 0);
      canvas.scale(s);
      style.paint(canvas, taken[i], side, shadow: false);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TakenPainter old) =>
      old.side != side ||
      old.taken.length != taken.length ||
      !_same(old.taken, taken);

  static bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ── The move list ───────────────────────────────────────────────────────────

/// Every move so far, newest at the bottom and kept in view. Chess reads as
/// numbered pairs ("12. Nf3 Bb4+"), every other game as one numbered row per
/// move with the mover's colour. A tap on a move shows the board as it stood
/// after it ([onSelect] with that ply); [viewPly] is the one shown, null for
/// the current position.
class MoveList extends StatefulWidget {
  const MoveList({
    super.key,
    required this.line,
    required this.onSelect,
    this.viewPly,
  });

  final GameLine line;
  final int? viewPly;
  final ValueChanged<int> onSelect;

  @override
  State<MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<MoveList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _toEnd();
  }

  @override
  void didUpdateWidget(MoveList old) {
    super.didUpdateWidget(old);
    if (widget.line.length > old.line.length && widget.viewPly == null) {
      _toEnd();
    }
  }

  /// The newest move in view: a game opened midway shows where it stands.
  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final line = widget.line;
    if (line.length == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          sentenceCaseOf(context, l10n.chatGameNoMovesYet),
          textAlign: TextAlign.center,
          style: groupedFooterStyle(theme),
        ),
      );
    }
    final shown = widget.viewPly ?? line.length;
    final chess = line.game == 'chess';
    final rows = chess ? (line.length + 1) ~/ 2 : line.length;
    final palette = SeatPalette(theme, gameId: line.game);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows,
      itemExtent: 30,
      itemBuilder: (context, i) {
        final number = SizedBox(
          width: 34,
          child: Text(
            '${i + 1}.',
            style: groupedMetaStyle(theme).copyWith(
              color: theme.inkMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
        if (chess) {
          final a = i * 2 + 1;
          final b = a + 1;
          return Row(
            children: [
              number,
              Expanded(child: _cell(theme, a, shown)),
              Expanded(
                child: b <= line.length
                    ? _cell(theme, b, shown)
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }
        final entry = line.entries[i];
        return Row(
          children: [
            number,
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.fill(entry.seat),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _cell(theme, i + 1, shown)),
          ],
        );
      },
    );
  }

  Widget _cell(AppTheme theme, int ply, int shown) {
    final entry = widget.line.entries[ply - 1];
    final on = ply == shown;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSelect(ply);
      },
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: on ? theme.accent.withValues(alpha: 0.18) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            entry.label.isEmpty ? '·' : entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: groupedTitleStyle(theme).copyWith(
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? theme.ink : theme.inkSoft,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// The move list in its card, with the step buttons and, while an earlier
/// position is on the board, the way back to the current one.
class MoveListCard extends StatelessWidget {
  const MoveListCard({
    super.key,
    required this.line,
    required this.viewPly,
    required this.onView,
    this.keyboardHint = false,
  });

  final GameLine line;

  /// The ply on the board; null for the current position.
  final int? viewPly;

  /// Shows the position after a ply; null goes back to the current one.
  final ValueChanged<int?> onView;

  /// Says that the arrow keys step through the game.
  final bool keyboardHint;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final shown = viewPly ?? line.length;
    void step(int to) {
      final ply = to.clamp(0, line.length);
      onView(ply >= line.length ? null : ply);
    }

    Widget arrow(IconData icon, String label, VoidCallback? onTap) => Expanded(
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: SpringPress(
          onTap: onTap,
          semanticLabel: label,
          scale: PressSpec.scaleSmall,
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: theme.inkSoft),
          ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            sentenceCaseOf(context, l10n.chatGameMoves),
            style: groupedMetaStyle(theme).copyWith(
              fontWeight: FontWeight.w600,
              color: theme.inkMuted,
            ),
          ),
          Expanded(
            child: MoveList(line: line, viewPly: viewPly, onSelect: step),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              arrow(
                CupertinoIcons.backward_end_fill,
                '0',
                shown > 0 ? () => step(0) : null,
              ),
              const SizedBox(width: 6),
              arrow(
                CupertinoIcons.chevron_left,
                '${shown - 1}',
                shown > 0 ? () => step(shown - 1) : null,
              ),
              const SizedBox(width: 6),
              arrow(
                CupertinoIcons.chevron_right,
                '${shown + 1}',
                viewPly != null ? () => step(shown + 1) : null,
              ),
              const SizedBox(width: 6),
              arrow(
                CupertinoIcons.forward_end_fill,
                l10n.chatGameBackToGame,
                viewPly != null ? () => onView(null) : null,
              ),
            ],
          ),
          if (keyboardHint) ...[
            const SizedBox(height: 8),
            Text(
              sentenceCaseOf(context, l10n.chatGameKeysReplay),
              textAlign: TextAlign.center,
              style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Over the board while an earlier position is shown: a quiet pill that
/// takes the board back to the current move. The board is read-only until
/// then, so nobody plays a move on a position that is not the game's.
class BackToGamePill extends StatelessWidget {
  const BackToGamePill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SpringPress(
      onTap: onTap,
      scale: PressSpec.scaleSmall,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.forward_end_fill, size: 14, color: theme.accentInk),
            const SizedBox(width: 6),
            Text(
              sentenceCaseOf(context, l10n.chatGameBackToGame),
              style: groupedMetaStyle(theme).copyWith(
                fontWeight: FontWeight.w600,
                color: theme.accentInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Game actions ────────────────────────────────────────────────────────────

/// Takeback, draw and resign, as tiles. A null callback dims a tile; an
/// absent one (e.g. no draws in a three-seat game) is left out. [extra]
/// rides at the end (New game against the bot).
class TurnActions extends StatelessWidget {
  const TurnActions({
    super.key,
    this.onTakeback,
    this.showTakeback = true,
    this.onDraw,
    this.showDraw = true,
    this.onResign,
    this.showResign = true,
    this.extra,
    this.footnote,
  });

  final VoidCallback? onTakeback;
  final bool showTakeback;
  final VoidCallback? onDraw;
  final bool showDraw;
  final VoidCallback? onResign;
  final bool showResign;
  final Widget? extra;

  /// One line under the tiles: how many takebacks are left.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final tiles = <Widget>[
      if (showTakeback)
        GameTool(
          icon: CupertinoIcons.arrow_uturn_left,
          label: l10n.chatGameTakeback,
          onTap: onTakeback,
        ),
      if (showDraw)
        GameTool(
          icon: CupertinoIcons.equal_circle,
          label: l10n.chatGameOfferDraw,
          onTap: onDraw,
        ),
      if (showResign)
        GameTool(
          icon: CupertinoIcons.flag_fill,
          label: l10n.chatGameResign,
          onTap: onResign,
          danger: onResign != null,
        ),
      ?extra,
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
        if (footnote != null) ...[
          const SizedBox(height: 8),
          Text(
            sentenceCaseOf(context, footnote!),
            textAlign: TextAlign.center,
            style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
          ),
        ],
      ],
    );
  }
}

// ── Keyboard ────────────────────────────────────────────────────────────────

/// The keys a board game answers on a desktop, in one place for both turn
/// screens: ← → Home End step through the game, a digit plays a column in
/// Connect Four or a cell in tic-tac-toe (1 is top left, as a phone keypad
/// reads), ⌘Z / Ctrl+Z asks for a takeback.
///
/// A plain [Focus] that takes focus when the screen opens. Esc and every
/// other key fall through to the app's own handlers (Esc closes the game).
class TurnKeys extends StatelessWidget {
  const TurnKeys({
    super.key,
    required this.game,
    required this.child,
    this.onStep,
    this.onPlay,
    this.onTakeback,
  });

  final String game;
  final Widget child;

  /// -1 / +1 for ← / →, `-1 << 20` for Home and `1 << 20` for End.
  final ValueChanged<int>? onStep;

  /// A move token typed on the keyboard. Only legal ones reach the game: the
  /// screen hands it to the same path a tap takes.
  final ValueChanged<String>? onPlay;
  final VoidCallback? onTakeback;

  static const home = -(1 << 20);
  static const end = 1 << 20;

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    final keys = HardwareKeyboard.instance;
    final meta = keys.isMetaPressed || keys.isControlPressed;
    if (meta && k == LogicalKeyboardKey.keyZ && e is KeyDownEvent) {
      if (onTakeback == null) return KeyEventResult.ignored;
      onTakeback!();
      return KeyEventResult.handled;
    }
    if (meta || keys.isAltPressed) return KeyEventResult.ignored;
    final step = onStep;
    if (step != null) {
      if (k == LogicalKeyboardKey.arrowLeft) {
        step(-1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowRight) {
        step(1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.home || k == LogicalKeyboardKey.arrowUp) {
        step(home);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.end || k == LogicalKeyboardKey.arrowDown) {
        step(end);
        return KeyEventResult.handled;
      }
    }
    final play = onPlay;
    if (play != null && e is KeyDownEvent) {
      final digit = _digit(k);
      if (digit != null && digit >= 1) {
        if (game == 'connectfour' && digit <= 7) {
          play('${digit - 1}');
          return KeyEventResult.handled;
        }
        if (game == 'tictactoe' && digit <= 9) {
          play('${digit - 1}');
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  static int? _digit(LogicalKeyboardKey k) {
    const top = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const pad = [
      LogicalKeyboardKey.numpad0,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final i = top.indexOf(k);
    if (i >= 0) return i;
    final j = pad.indexOf(k);
    return j >= 0 ? j : null;
  }

  @override
  Widget build(BuildContext context) =>
      Focus(autofocus: true, onKeyEvent: _key, child: child);
}

/// Moves a review cursor by a [TurnKeys.onStep] amount: null is the current
/// position, so stepping forward off the end returns there.
int? stepPly(int? view, int length, int by) {
  final from = view ?? length;
  final to = by == TurnKeys.home
      ? 0
      : by == TurnKeys.end
      ? length
      : (from + by).clamp(0, length);
  return to >= length ? null : to;
}
