import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/challenges_store.dart';
import '../../data/feed_store.dart';
import '../../data/games_store.dart';
import '../../games/game_play_controller.dart';
import '../../games/how_to/daily_guides.dart';
import '../../games/how_to/how_to_play.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../models/game_record.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/game_result_actions.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/forward_target_sheet.dart';
import '../../widgets/game_tile.dart' show StatusChip;
import '../../widgets/game_celebration.dart';
import '../../widgets/game_layout_shell.dart';
import '../../widgets/game_records.dart';
import '../../widgets/game_stat_line.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/score_row.dart';
import '../../widgets/sheet_kit.dart';
import '../../l10n/text_case.dart';
import 'result_sheet.dart';

/// The chrome every daily game wears: the back arrow, the running clock, the
/// pause cover, the tool row, the result card and today's times.
///
/// One scaffold rather than four, because none of that is what makes Queens
/// different from Sudoku — the grid is. Four copies of a stopwatch and an
/// autosave is four places for the timer to leak, and it also guarantees the
/// four boards drift apart visually within a month of shipping.
class GameScaffold extends StatefulWidget {
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
    this.hintBanner,
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

  /// The current hint's one-line reason, under the board — a `HintBanner`.
  /// It opens and closes itself, so it is always passed, hint or not.
  final Widget? hintBanner;

  @override
  State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  final _touch = _BoardTouch();

  @override
  void initState() {
    super.initState();
    // The first time anyone opens this game, the guide comes up by itself,
    // before the first touch has started the clock.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.controller.finished) return;
      showHowToPlayOnce(
        context,
        dailyGuide(AppLocalizations.of(context), widget.controller.game),
      );
    });
  }

  /// Something pushed over the game (the call screen, a sheet, a dialog) takes
  /// the board out of reach, so the clock holds for as long as it is there.
  /// [ModalRoute.isCurrentOf] makes this run again each time that flips.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.setCovered(!(ModalRoute.isCurrentOf(context) ?? true));
  }

  /// The "?" in the top bar. A running clock is paused while it is open (the
  /// pause cover hides the board too), and picks up again after.
  Future<void> _openGuide() async {
    final controller = widget.controller;
    final hold =
        controller.started && !controller.finished && !controller.paused;
    if (hold) controller.pause();
    await showHowToPlay(
      context,
      dailyGuide(AppLocalizations.of(context), controller.game),
    );
    if (hold && mounted && controller.paused) controller.resume();
  }

  @override
  void dispose() {
    _touch.dispose();
    // A challenge is for one sitting at the board it named.
    if (ChallengesStore.instance.target?.game == widget.controller.game) {
      ChallengesStore.instance.target = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final GameScaffold(
      :controller,
      :title,
      :rule,
      :board,
      :tools,
      :footer,
      :viewerId,
      :onShare,
      :onTellFriends,
      :hintBanner,
    ) = widget;

    final target = challengeTargetFor(controller);
    final header = <Widget>[
      _TopBar(controller: controller, onHelp: _openGuide),
      if (target != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Center(
            child: _TargetChip(
              target: target,
              elapsedMs: controller.finished
                  ? controller.durationMs ?? controller.elapsed.inMilliseconds
                  : controller.elapsed.inMilliseconds,
            ),
          ),
        ),
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
              borderRadius: BorderRadius.circular(theme.radiusMd),
              // Sees every touch before the board's own recognizers do, and
              // never competes with them: the first touch starts the clock,
              // and any finger down holds the page still until it lifts.
              child: Listener(
                onPointerDown: (e) {
                  if (!controller.ready ||
                      controller.finished ||
                      controller.paused) {
                    return;
                  }
                  controller.startClock();
                  _touch.down(e.pointer);
                },
                onPointerUp: (e) => _touch.up(e.pointer),
                onPointerCancel: (e) => _touch.up(e.pointer),
                child: board,
              ),
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
      // A finished board waiting on the network. Not an error the player has
      // to act on — it resends by itself — but it must be said, or a board
      // that has gone inert with its clock stopped just looks frozen.
      if (controller.stalled) ...[
        const SizedBox(height: 12),
        FormErrorBanner(
          l10n.gameSubmitWaiting,
          icon: CupertinoIcons.wifi_slash,
          actionLabel: l10n.gamesRetry,
          onAction: controller.retryNow,
        ),
      ],
      if (controller.errorCode != null) ...[
        const SizedBox(height: 12),
        FormErrorBanner(switch (controller.errorCode) {
          'NOT_SOLVED' => l10n.gameErrorNotSolved,
          'ALREADY_FINISHED' => l10n.gameErrorAlreadyFinished,
          'NO_HINT' => l10n.gameErrorNoHint,
          _ => l10n.gameErrorGeneric,
        }),
      ],
      if (hintBanner != null && !controller.finished) hintBanner,
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
        footer,
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
              scrollLocked: _touch.locked,
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

/// Which fingers are on the board right now. The page stays locked until the
/// last of them lifts — a second finger landing and leaving mid-stroke must not
/// let the first one start scrolling.
class _BoardTouch {
  final locked = ValueNotifier<bool>(false);
  final _pointers = <int>{};

  void down(int pointer) {
    _pointers.add(pointer);
    locked.value = true;
  }

  void up(int pointer) {
    _pointers.remove(pointer);
    locked.value = _pointers.isNotEmpty;
  }

  void dispose() => locked.dispose();
}

/// Back arrow, running clock, pause.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.onHelp});

  final GamePlayController controller;
  final VoidCallback onHelp;

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
                  // Muted until the first touch, so a clock waiting on the
                  // player reads as waiting rather than stuck.
                  color: controller.finished
                      ? theme.success
                      : controller.started
                      ? theme.ink
                      : theme.inkMuted,
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
              HowToPlayButton(onTap: onHelp),
              if (!controller.finished) ...[
                const SizedBox(width: 8),
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
              color: quietFill(theme),
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
/// The challenge a board is being played against, when it is this board and
/// today's.
ChallengeTarget? challengeTargetFor(GamePlayController controller) {
  final t = ChallengesStore.instance.target;
  if (t == null || t.game != controller.game) return null;
  if (t.dayKey != FeedStore.instance.dayKey) return null;
  return t;
}

/// "Selin 2:41" under the clock, until the clock passes it — then "+0:07",
/// quietly. Passing it is not a failure worth red, just a fact; the one
/// light tap as it happens is the only fuss.
class _TargetChip extends StatefulWidget {
  const _TargetChip({required this.target, required this.elapsedMs});

  final ChallengeTarget target;
  final int elapsedMs;

  @override
  State<_TargetChip> createState() => _TargetChipState();
}

class _TargetChipState extends State<_TargetChip> {
  @override
  void didUpdateWidget(_TargetChip old) {
    super.didUpdateWidget(old);
    final t = widget.target.durationMs;
    if (old.elapsedMs <= t && widget.elapsedMs > t) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final over = widget.elapsedMs - widget.target.durationMs;
    return AnimatedSwitcher(
      duration: MotionScope.of(context).d(theme.motionFast),
      child: over > 0
          ? StatusChip(
              key: const ValueKey('over'),
              label: '+${formatGameTime(over)}',
              tone: theme.inkMuted,
              icon: CupertinoIcons.flag,
            )
          : StatusChip(
              key: const ValueKey('target'),
              label: l10n.challengeTarget(
                widget.target.name,
                formatGameTime(widget.target.durationMs),
              ),
              tone: theme.accent,
              icon: CupertinoIcons.flag_fill,
            ),
    );
  }
}

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

  /// "You beat Selin's 2:41" or "Selin keeps it, by 0:08", and whether it
  /// was a win — when this board was played against a challenge.
  (String, bool)? _challengeLine(BuildContext context) {
    final t = challengeTargetFor(controller);
    final mine = controller.durationMs;
    if (t == null || !controller.solved || mine == null) return null;
    final l10n = AppLocalizations.of(context);
    // Whole seconds, the clock's own precision: two times that read the same
    // are a tie, never a win on milliseconds nobody can see.
    final gap = mine ~/ 1000 - t.durationMs ~/ 1000;
    if (gap == 0) return (l10n.challengeTie, false);
    if (gap < 0) {
      return (l10n.challengeBeatName(t.name, formatGameTime(t.durationMs)), true);
    }
    return (l10n.challengeKept(t.name, formatGameTime(gap * 1000)), false);
  }

  /// Sends this result to chats the player picks, as a "Beat my time" card.
  Future<void> _challenge(BuildContext context) async {
    final repo = ChallengesStore.instance.repo;
    if (repo == null) return;
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    final sent = sentenceCaseOf(context, l10n.challengeSent);
    final failed = sentenceCaseOf(context, l10n.chatGameErrGeneric);
    final rooms = await showForwardTargetSheet(
      context,
      repo: repo,
      messageCount: 1,
      excludeRoomId: '',
    );
    if (rooms == null || rooms.isEmpty) return;
    try {
      await ChallengesStore.instance.send(
        userId: viewerId,
        roomIds: [for (final r in rooms) r.id],
        game: controller.game,
        dayKey: FeedStore.instance.dayKey,
      );
      HapticFeedback.lightImpact();
      toast.success(sent);
    } catch (_) {
      toast.error(failed);
    }
  }

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
            GameStatLine(
              mistakes: controller.mistakes,
              hints: controller.hintsUsed,
              textAlign: TextAlign.center,
            ),
          ],
          if (_challengeLine(context) case final line?) ...[
            const SizedBox(height: 6),
            Text(
              sentenceCaseOf(context, line.$1),
              textAlign: TextAlign.center,
              style: theme.bodySoft.copyWith(
                color: line.$2 ? theme.success : theme.inkMuted,
                fontWeight: line.$2 ? FontWeight.w600 : null,
              ),
            ),
          ],
          if (onShare != null || onTellFriends != null) ...[
            const SizedBox(height: 18),
            GameResultActions(
              actions: [
                if (solved && ChallengesStore.instance.repo != null)
                  GameResultAction(
                    icon: CupertinoIcons.paperplane,
                    label: sentenceCaseOf(context, l10n.challengeAction),
                    onTap: () => _challenge(context),
                  ),
                if (onShare != null)
                  GameResultAction(
                    icon: CupertinoIcons.doc_on_doc,
                    label: sentenceCaseOf(context, l10n.gameShare),
                    onTap: onShare,
                  ),
                // Retired once used — the server allows one send per result,
                // so an action that stayed put would be a button whose only
                // remaining outcome is an error.
                if (onTellFriends != null)
                  controller.shared
                      ? GameResultAction(
                          icon: CupertinoIcons.checkmark_alt,
                          label: sentenceCaseOf(context, l10n.gameToldFriends),
                          onTap: null,
                        )
                      : GameResultAction(
                          icon: CupertinoIcons.bell_fill,
                          label: sentenceCaseOf(context, l10n.gameTellFriends),
                          onTap: onTellFriends,
                          prominent: true,
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

  /// One finisher, as every scoreboard draws them ([ScoreRow]).
  Widget _standingRow(BuildContext context, int rank, GameResult row) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final score = row.solved
        ? formatGameTime(row.durationMs)
        : sentenceCaseOf(context, l10n.gameStatusGaveUp);
    return ScoreRow(
      rank: rank,
      medal: row.solved,
      userId: row.userId,
      name: row.name,
      isViewer: row.userId == viewerId,
      streak: row.solved
          ? GamesStore.instance.standings.streakOf(row.userId, game)
          : 0,
      semantics: score,
      onTap: () => showResultSheet(context, row: row, viewerId: viewerId),
      // Advisory, never ranked on: a hint was used.
      extra: row.hintsUsed > 0
          ? Icon(CupertinoIcons.lightbulb, size: 15, color: theme.inkMuted)
          : null,
      trailing: ScoreText(score, muted: !row.solved),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final rows = GamesStore.instance.standings.ranked(
      game,
      viewerId: viewerId,
      you: sentenceCaseOf(context, l10n.momentRailYouLabel),
    );

    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final shown = rows.length < max ? rows.length : max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The shared section header. Today's times answer "who won today";
        // the trailing link is one tap from "is that actually good?".
        GroupedHeader(
          l10n.gameStandingsLabel,
          trailing: AllTimeLink(game: RecordGame.of(game), viewerId: viewerId),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
          child: ColoredBox(
            color: groupedFill(theme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
        if (rows.isEmpty)
          EmptyLine(l10n.gameStandingsEmpty)
        else
          for (var i = 0; i < shown; i++)
            TweenAnimationBuilder<double>(
              // Identity, never index — this list reorders as people finish.
              key: ValueKey('${game.wire}_${rows[i].row.userId}'),
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
                  _standingRow(context, rows[i].place, rows[i].row),
                  if (i < shown - 1)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: kPersonRowTextInset + kPersonRowLead,
                      ),
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
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: ink),
              const SizedBox(height: 4),
              // Meta size, on the scale; shrinks to fit rather than cutting
              // a tool's name off ("Auto-cro…").
              FitLabel(
                sentenceCaseOf(context, label),
                maxLines: 1,
                style: theme.body.copyWith(
                  fontSize: 13,
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
