import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/feed_store.dart';
import '../../data/games_store.dart';
import '../../games/game_play_controller.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/game_layout_shell.dart';

/// The chrome every daily game wears: the back arrow, the running clock, the
/// pause cover, the tool row, the result card and today's times.
///
/// One scaffold rather than four, because none of that is what makes Queens
/// different from Sudoku — the grid is. Four copies of a stopwatch and an
/// autosave is four places for the timer to leak, and it also guarantees the
/// four boards drift apart visually within a month of shipping.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.controller,
    required this.title,
    required this.rule,
    required this.board,
    required this.tools,
    required this.viewerId,
    this.footer,
    this.onShare,
  });

  final GamePlayController controller;

  /// The game's name and its rules in one line. Both localized by the caller —
  /// the scaffold never has to know which game it is wrapping.
  final String title;
  final String rule;

  /// The grid. Laid out square; the scaffold owns everything around it.
  final Widget board;

  /// Undo, hint, give up — whatever this board can offer.
  final List<Widget> tools;

  /// An extra strip under the tools. Sudoku's keypad lives here; the other
  /// three have nothing to put in it.
  final Widget? footer;

  final String viewerId;

  /// Copies the result to the clipboard. Absent until the board is finished.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    final header = <Widget>[
      _TopBar(controller: controller),
      const SizedBox(height: 6),
      Text(title, style: theme.displayMedium),
      const SizedBox(height: 8),
      Row(
        children: [
          Container(width: 18, height: 1, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(rule, style: theme.caption)),
        ],
      ),
    ];

    final board_ = <Widget>[
      AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [board, if (controller.paused) const _PauseCover()],
        ),
      ),
      if (controller.errorCode != null) ...[
        const SizedBox(height: 12),
        Text(
          switch (controller.errorCode) {
            'NOT_SOLVED' => l10n.gameErrorNotSolved,
            'ALREADY_FINISHED' => l10n.gameErrorAlreadyFinished,
            'NO_HINT' => l10n.gameErrorNoHint,
            _ => l10n.gameErrorGeneric,
          },
          style: theme.bodySoft.copyWith(color: theme.danger),
        ),
      ],
      const SizedBox(height: 16),
      if (!controller.finished)
        Wrap(spacing: 8, runSpacing: 8, children: tools),
      if (footer != null && !controller.finished) ...[
        const SizedBox(height: 14),
        footer!,
      ],
      if (controller.finished) ...[
        _ResultCard(controller: controller, viewerId: viewerId, onShare: onShare),
        const SizedBox(height: 24),
      ],
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // `bottom: false`, with the inset moved onto the shell's own
          // scroller — see [edgeToEdgeBottom].
          SafeArea(
            bottom: false,
            child: GameLayoutShell(
              header: header,
              board: board_,
              boardWidth: 480,
              sidebar: GameStandingsList(
                game: controller.game,
                viewerId: viewerId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back arrow, running clock, pause.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final GamePlayController controller;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final elapsed = controller.elapsed.inMilliseconds;

    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
          tooltip: l10n.gameBackToHub,
        ),
        const Spacer(),
        Semantics(
          label: l10n.gameElapsedSemantic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.surfaceSunken,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(color: theme.divider),
            ),
            child: Text(
              // The finished time, not the clock, once the board is closed —
              // a stopwatch that keeps counting after you have solved it reads
              // as the solve not having registered.
              formatGameTime(
                controller.finished ? controller.durationMs ?? elapsed : elapsed,
              ),
              style: theme.monoLarge.copyWith(fontSize: 16),
            ),
          ),
        ),
        if (!controller.finished) ...[
          const SizedBox(width: 6),
          IconButton(
            onPressed: controller.paused ? controller.resume : controller.pause,
            icon: Icon(
              controller.paused ? Icons.play_arrow : Icons.pause,
              color: theme.inkSoft,
              size: 18,
            ),
            tooltip: controller.paused ? l10n.gameResume : l10n.gamePause,
          ),
        ],
      ],
    );
  }
}

/// Covers the board while paused.
///
/// Covers it, rather than only stopping the clock. A paused stopwatch over a
/// readable grid is a free think, which turns "I had to answer the door" into
/// the fastest way to win.
class _PauseCover extends StatelessWidget {
  const _PauseCover();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.background.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(color: theme.divider),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_circle_outline, color: theme.accent, size: 34),
          const SizedBox(height: 10),
          Text(l10n.gamePausedTitle, style: theme.displaySmall),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              l10n.gamePausedBody,
              textAlign: TextAlign.center,
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown once the player can no longer act on today's board.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.controller,
    required this.viewerId,
    required this.onShare,
  });

  final GamePlayController controller;
  final String viewerId;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final standings = GamesStore.instance.standings;
    final rows = standings.boards[controller.game] ?? const [];
    final rank = standings.rankOf(controller.game, viewerId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theme.roomCardDecoration(ephemeral: false, active: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.solved
                ? l10n.gameSolvedTitle(
                    formatGameTime(controller.durationMs),
                  )
                : l10n.gameGaveUpTitle,
            style: theme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            // The standings rank the viewer against friends who have finished.
            // "first one in" rather than "#1 of 1", which reads as a podium
            // nobody else entered.
            rank == null || rows.length <= 1
                ? l10n.gameFirstInToday
                : l10n.gameRankLine('$rank', '${rows.length}'),
            style: theme.bodySoft.copyWith(color: theme.inkMuted),
          ),
          if (controller.hintsUsed > 0 || controller.mistakes > 0) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (controller.mistakes > 0)
                  l10n.gameMistakeCount(controller.mistakes),
                if (controller.hintsUsed > 0)
                  l10n.gameHintCount(controller.hintsUsed),
              ].join(' · '),
              style: theme.monoTiny.copyWith(color: theme.inkMuted),
            ),
          ],
          if (onShare != null) ...[
            const SizedBox(height: 14),
            FocusableTap(
              onTap: onShare,
              semanticLabel: l10n.gameShare,
              radius: theme.radiusMd,
              child: GestureDetector(
                onTap: onShare,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_outlined, size: 14, color: theme.accent),
                    const SizedBox(width: 6),
                    Text(
                      l10n.gameShare,
                      style: theme.label.copyWith(color: theme.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Everyone who has finished one game today, fastest first.
///
/// Unfinished boards are absent from the payload on purpose — knowing a friend
/// is nine minutes into Queens and still going leaks how hard today is, and a
/// live counter turns a quiet daily into a race.
class GameStandingsList extends StatelessWidget {
  const GameStandingsList({
    super.key,
    required this.game,
    required this.viewerId,
    this.max = 12,
  });

  final DailyGame game;
  final String viewerId;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final rows = GamesStore.instance.standings.boards[game] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(l10n.gameStandingsLabel, style: theme.label),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: theme.divider)),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Text(
            l10n.gameStandingsEmpty,
            style: theme.bodySoft.copyWith(color: theme.inkMuted),
          )
        else
          for (var i = 0; i < rows.length && i < max; i++)
            TweenAnimationBuilder<double>(
              // Identity, never index — this list reorders as people finish.
              key: ValueKey('${game.wire}_${rows[i].userId}'),
              tween: Tween(begin: 0, end: 1),
              duration: motion.stagger(theme.motionMed, i, strideMs: 45),
              curve: motion.c(theme.motionEntrance),
              builder: (context, v, child) => Transform.translate(
                offset: Offset(0, (1 - v) * 6),
                child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StandingRow(
                  rank: i + 1,
                  row: rows[i],
                  isViewer: rows[i].userId == viewerId,
                ),
              ),
            ),
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.row,
    required this.isViewer,
  });

  final int rank;
  final GameResult row;
  final bool isViewer;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        SizedBox(width: 22, child: Text('$rank', style: theme.monoTiny)),
        Expanded(
          child: Text(
            isViewer ? l10n.momentRailYouLabel : row.name,
            style: isViewer
                ? theme.bodyEmph.copyWith(color: theme.accent)
                : theme.body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (row.hintsUsed > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.lightbulb_outline,
              size: 12,
              color: theme.inkMuted,
            ),
          ),
        Text(
          row.solved ? formatGameTime(row.durationMs) : l10n.gameStatusGaveUp,
          style: theme.monoLarge.copyWith(
            fontSize: 14,
            color: row.solved ? theme.ink : theme.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// One button in a board's tool row.
class GameTool extends StatelessWidget {
  const GameTool({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;

  /// Null disables the tool — an undo with nothing to undo, a hint mid-flight.
  final VoidCallback? onTap;

  /// A toggle that is currently on. Queens' auto-cross and Sudoku's notes.
  final bool selected;

  /// Give up, which should not look like the others.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final on = onTap != null;
    final ink = danger
        ? theme.danger
        : selected
        ? theme.accentInk
        : theme.inkSoft;

    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: on ? 1 : 0.4,
          child: AnimatedContainer(
            duration: theme.motionFast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? theme.accent : theme.surface,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(
                color: selected ? theme.accent : theme.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: ink),
                const SizedBox(width: 7),
                Text(label, style: theme.label.copyWith(color: ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks before showing an answer, and reports what it costs.
///
/// A confirmation because giving up is irreversible for the day: the row is
/// closed the moment the answer is handed over, so a mis-tap on a board someone
/// has spent ten minutes on would otherwise end it outright.
Future<bool> confirmGiveUp(BuildContext context) async {
  final theme = ThemeScope.of(context);
  final l10n = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radiusLg),
      ),
      title: Text(l10n.gameGiveUpTitle, style: theme.displaySmall),
      content: Text(l10n.gameGiveUpBody, style: theme.bodySoft),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            l10n.gameGiveUpCancel,
            style: theme.label.copyWith(color: theme.inkSoft),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            l10n.gameGiveUpConfirm,
            style: theme.label.copyWith(color: theme.danger),
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Copies one finished board's result to the clipboard.
///
/// Text, not a screenshot: it pastes into any chat, it costs nothing to
/// produce, and — unlike a picture of the grid — it gives away nothing about
/// the board to a friend who has not played today yet.
Future<void> copyGameResult(
  BuildContext context, {
  required String name,
  required bool solved,
  required int? durationMs,
}) async {
  final l10n = AppLocalizations.of(context);
  final toast = AppToast.of(context);
  await Clipboard.setData(
    ClipboardData(
      text: l10n.gameShareLine(
        name,
        '${FeedStore.instance.edition}',
        solved ? formatGameTime(durationMs) : l10n.gameStatusGaveUp,
      ),
    ),
  );
  toast.show(
    l10n.gameShareCopied,
    tone: ToastTone.success,
  );
}
