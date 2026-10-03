import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/feed_store.dart';
import '../../data/games_store.dart';
import '../../games/game_play_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../models/game_record.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/game_celebration.dart';
import '../../widgets/game_layout_shell.dart';
import '../../widgets/game_records.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/sheet_kit.dart';

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
    this.onTellFriends,
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

  /// Pushes the result to the player's friends. Absent until the board is
  /// finished, and gone again once it has been used — unlike [onShare], which
  /// copies text and can be done all day, this one notifies other people and
  /// the server allows it once.
  final VoidCallback? onTellFriends;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    final header = <Widget>[
      _TopBar(controller: controller),
      const SizedBox(height: 10),
      Text(
        sentenceCaseOf(context, title),
        style: theme.displayLarge.copyWith(letterSpacing: 0.37),
      ),
      const SizedBox(height: 4),
      Text(
        sentenceCaseOf(context, rule),
        style: theme.bodySoft.copyWith(color: theme.inkMuted),
      ),
      const SizedBox(height: 6),
    ];

    final board_ = <Widget>[
      AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Rounded like the hub's tile of the same board, so opening a
            // game reads as that card growing to fill the screen.
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: board,
            ),
            // Fades rather than popping, so pausing reads as the board
            // being put away, not as a screen swap.
            IgnorePointer(
              ignoring: !controller.paused,
              child: AnimatedOpacity(
                opacity: controller.paused ? 1 : 0,
                duration: MotionScope.of(context).d(theme.motionFast),
                child: const _PauseCover(),
              ),
            ),
          ],
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
      // One row of equal tool buttons, the iOS bottom-toolbar shape; a board
      // with more tools than fit wraps onto a second row of the same width.
      if (!controller.finished)
        LayoutBuilder(
          builder: (context, box) {
            const gap = 8.0;
            final n = tools.length.clamp(1, 4);
            final w = (box.maxWidth - gap * (n - 1)) / n;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final t in tools) SizedBox(width: w, child: t),
              ],
            );
          },
        ),
      if (footer != null && !controller.finished) ...[
        const SizedBox(height: 14),
        footer!,
      ],
      if (controller.finished) ...[
        _ResultCard(
          controller: controller,
          viewerId: viewerId,
          onShare: onShare,
          onTellFriends: onTellFriends,
        ),
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

    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The clock, centred like a navigation title: it is the one thing
          // on this bar that is always worth reading.
          Semantics(
            label: l10n.gameElapsedSemantic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: controller.finished
                    ? theme.success.withValues(alpha: 0.16)
                    : theme.ink.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                // The finished time, not the clock, once the board is closed —
                // a stopwatch that keeps counting after you have solved it
                // reads as the solve not having registered.
                formatGameTime(
                  controller.finished
                      ? controller.durationMs ?? elapsed
                      : elapsed,
                ),
                style: theme.body.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: controller.finished ? theme.success : theme.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Semantics(
                label: l10n.gameBackToHub,
                child: const GlassBackButton(),
              ),
              const Spacer(),
              if (!controller.finished)
                GlassIconButton(
                  icon: controller.paused
                      ? CupertinoIcons.play_fill
                      : CupertinoIcons.pause_fill,
                  iconSize: 17,
                  semanticLabel: controller.paused
                      ? l10n.gameResume
                      : l10n.gamePause,
                  onTap: controller.paused
                      ? controller.resume
                      : controller.pause,
                ),
            ],
          ),
        ],
      ),
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
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.pause_fill, color: theme.accent, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            sentenceCaseOf(context, l10n.gamePausedTitle),
            style: theme.displaySmall,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              sentenceCaseOf(context, l10n.gamePausedBody),
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
    required this.onTellFriends,
  });

  final GamePlayController controller;
  final String viewerId;
  final VoidCallback? onShare;
  final VoidCallback? onTellFriends;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final standings = GamesStore.instance.standings;
    final rows = standings.boards[controller.game] ?? const [];
    final rank = standings.rankOf(controller.game, viewerId);

    final motion = MotionScope.of(context);
    final solved = controller.solved;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        children: [
          // A medal for a solve, a quiet flag for a give-up: the card says
          // which before a word is read.
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: solved
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFD86B), Color(0xFFF5A623)],
                    )
                  : null,
              color: solved ? null : theme.ink.withValues(alpha: 0.08),
            ),
            child: Icon(
              solved ? CupertinoIcons.star_fill : CupertinoIcons.flag_fill,
              size: 28,
              color: solved ? Colors.white : theme.inkMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            sentenceCaseOf(
              context,
              solved
                  ? l10n.gameSolvedTitle(formatGameTime(controller.durationMs))
                  : l10n.gameGaveUpTitle,
            ),
            textAlign: TextAlign.center,
            style: theme.displayMedium.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            // The standings rank the viewer against friends who have
            // finished. "first one in" rather than "#1 of 1", which reads as
            // a podium nobody else entered.
            sentenceCaseOf(
              context,
              rank == null || rows.length <= 1
                  ? l10n.gameFirstInToday
                  : l10n.gameRankLine('$rank', '${rows.length}'),
            ),
            textAlign: TextAlign.center,
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
              textAlign: TextAlign.center,
              style: theme.bodySoft.copyWith(
                fontSize: 13,
                color: theme.inkMuted,
              ),
            ),
          ],
          if (onShare != null || onTellFriends != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                if (onShare != null)
                  Expanded(
                    child: _CardAction(
                      icon: CupertinoIcons.doc_on_doc,
                      label: sentenceCaseOf(context, l10n.gameShare),
                      onTap: onShare,
                    ),
                  ),
                if (onShare != null && onTellFriends != null)
                  const SizedBox(width: 10),
                // Retired once used — the server allows one send per result,
                // so an action that stayed put would be a button whose only
                // remaining outcome is an error.
                if (onTellFriends != null)
                  Expanded(
                    child: controller.shared
                        ? _CardAction(
                            icon: CupertinoIcons.checkmark_alt,
                            label: sentenceCaseOf(context, l10n.gameToldFriends),
                            onTap: null,
                          )
                        : _CardAction(
                            icon: CupertinoIcons.bell_fill,
                            label: sentenceCaseOf(context, l10n.gameTellFriends),
                            onTap: onTellFriends,
                            prominent: true,
                          ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    // Lands on a spring, with a confetti burst for a solve — the reward beat
    // a daily puzzle exists for. A give-up gets the same card, quietly.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.86, end: 1),
          duration: motion.d(const Duration(milliseconds: 620)),
          curve: Curves.elasticOut,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: card,
        ),
        if (solved)
          const Positioned(
            left: -40,
            right: -40,
            top: -260,
            height: 520,
            child: GameCelebration(origin: Alignment(0, 0.1)),
          ),
      ],
    );
  }
}

/// One tappable action on the result card.
///
/// Extracted when the card grew a second one: the original was a `FocusableTap`
/// wrapping a `GestureDetector` wrapping a `Row`, and a second hand-rolled copy
/// of that is a second place for the keyboard affordance to be forgotten.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final String label;

  /// Null shows the action as done rather than hiding it.
  final VoidCallback? onTap;

  /// The filled one — the action the card is offering first.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final done = onTap == null;
    final fill = prominent
        ? theme.bubbleFill(isMine: true)
        : theme.ink.withValues(alpha: done ? 0.05 : 0.08);
    final ink = prominent
        ? theme.accentInk
        : (done ? theme.inkMuted : theme.ink);
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: ink),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.body.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
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

    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final shown = rows.length < max ? rows.length : max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  sentenceCaseOf(context, l10n.gameStandingsLabel),
                  style: theme.bodySoft.copyWith(
                    fontSize: 13,
                    color: theme.inkMuted,
                  ),
                ),
              ),
              // Today's times answer "who won today"; this is one tap from
              // "is that actually good?".
              AllTimeLink(game: RecordGame.of(game), viewerId: viewerId),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
          child: ColoredBox(
            color: groupedFill(theme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              sentenceCaseOf(context, l10n.gameStandingsEmpty),
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
            ),
          )
        else
          for (var i = 0; i < shown; i++)
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StandingRow(
                    rank: i + 1,
                    row: rows[i],
                    isViewer: rows[i].userId == viewerId,
                  ),
                  if (i < shown - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: Container(
                        height: hairline,
                        color: theme.ink.withValues(alpha: 0.10),
                      ),
                    ),
                ],
              ),
            ),
              ],
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

  /// Gold, silver, bronze for the podium; everyone after gets a plain number.
  static const _medals = [
    [Color(0xFFFFD86B), Color(0xFFF0A81E)],
    [Color(0xFFE4E7EC), Color(0xFFA9AFB8)],
    [Color(0xFFF2B48A), Color(0xFFC77A44)],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final medal = rank <= 3 && row.solved ? _medals[rank - 1] : null;
    return Container(
      color: isViewer ? theme.accent.withValues(alpha: 0.10) : null,
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: medal == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: medal,
                    ),
              color: medal == null ? theme.ink.withValues(alpha: 0.07) : null,
            ),
            child: Text(
              '$rank',
              style: theme.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: medal == null ? theme.inkMuted : const Color(0xFF3A2A00),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isViewer ? sentenceCaseOf(context, l10n.momentRailYouLabel) : row.name,
              style: isViewer
                  ? theme.bodyEmph.copyWith(color: theme.accent)
                  : theme.body.copyWith(color: theme.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (row.hintsUsed > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                CupertinoIcons.lightbulb,
                size: 14,
                color: theme.inkMuted,
              ),
            ),
          Text(
            row.solved
                ? formatGameTime(row.durationMs)
                : sentenceCaseOf(context, l10n.gameStatusGaveUp),
            style: theme.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: row.solved ? theme.ink : theme.inkMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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

    // A tile with the glyph over its name, the iOS toolbar-item shape:
    // even in width, so a row of four reads as one control rather than four
    // pills of whatever width their words happened to be.
    final fill = selected
        ? theme.accent
        : danger
        ? theme.danger.withValues(alpha: 0.12)
        : theme.ink.withValues(alpha: 0.07);
    return Opacity(
      opacity: on ? 1 : 0.4,
      child: SpringPress(
        onTap: onTap,
        semanticLabel: label,
        scale: 0.93,
        child: AnimatedContainer(
          duration: theme.motionFast,
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: ink),
              const SizedBox(height: 4),
              Text(
                sentenceCaseOf(context, label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ],
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
  final l10n = AppLocalizations.of(context);
  final ok = await showIosActionSheet<bool>(
    context,
    title: sentenceCaseOf(context, l10n.gameGiveUpTitle),
    message: sentenceCaseOf(context, l10n.gameGiveUpBody),
    actions: [
      IosSheetAction(
        label: sentenceCaseOf(context, l10n.gameGiveUpConfirm),
        value: true,
        destructive: true,
      ),
    ],
    cancelLabel: sentenceCaseOf(context, l10n.gameGiveUpCancel),
  );
  return ok ?? false;
}

/// Asks before notifying everybody.
///
/// Modelled on [confirmGiveUp] and irreversible for the same kind of reason,
/// one step further out: giving up ends the board for the day, and this rings
/// other people's phones. The server allows one send per result precisely so a
/// mistap cannot become two notifications — which also means a mistap is the
/// only send this result will ever get, and is why there is a dialog in front
/// of a button nobody presses by accident twice.
Future<bool> confirmTellFriends(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final ok = await showIosActionSheet<bool>(
    context,
    title: sentenceCaseOf(context, l10n.gameTellFriendsTitle),
    message: l10n.gameTellFriendsMessage,
    actions: [
      IosSheetAction(
        label: sentenceCaseOf(context, l10n.gameTellFriendsConfirm),
        value: true,
      ),
    ],
    cancelLabel: sentenceCaseOf(context, l10n.gameTellFriendsCancel),
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
  HapticFeedback.lightImpact();
  toast.show(
    l10n.gameShareCopied,
    tone: ToastTone.success,
  );
}

/// Asks first, then pushes one finished board's result to the player's friends.
///
/// The confirm is not ceremony. Every other action on this screen changes what
/// is on the player's own phone; this one lights up everybody else's, and it
/// cannot be taken back — the server allows one send per result precisely so
/// that a mistap cannot become two notifications, which also means a mistap is
/// the only send that result will ever get.
///
Future<void> tellFriendsAboutGame(
  BuildContext context, {
  required GamePlayController controller,
}) async {
  final l10n = AppLocalizations.of(context);
  final toast = AppToast.of(context);
  final ok = await confirmTellFriends(context);
  if (!ok || !context.mounted) return;

  final error = await controller.shareWithFriends();
  if (!context.mounted) return;
  if (error == null) {
    toast.show(l10n.gameTellFriendsSent, tone: ToastTone.success);
    return;
  }
  toast.show(
    switch (error) {
      // The one refusal with a fix the player owns, so it gets its own line
      // instead of the generic failure — the setting is three taps away and
      // nothing else would tell them it is the reason.
      'RESULT_PRIVATE' => l10n.gameTellFriendsPrivate,
      // Already sent, from another device or a tap this one did not see. Not
      // an error worth alarming anybody with: the friends were told.
      'ALREADY_SHARED' => l10n.gameToldFriends,
      _ => l10n.gameTellFriendsFailed,
    },
    tone: error == 'ALREADY_SHARED' ? ToastTone.neutral : ToastTone.danger,
  );
}
