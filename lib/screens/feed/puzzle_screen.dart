import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/feed_api.dart';
import '../../data/feed_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/game_record.dart';
import '../../models/puzzle.dart';
import '../../theme/app_theme.dart';
import '../../theme/layout.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/app_toast.dart';
import '../games/game_scaffold.dart' show confirmTellFriends;
import '../../widgets/game_layout_shell.dart';
import '../../widgets/game_records.dart';
import '../../widgets/game_celebration.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/puzzle_symbol.dart';
import '../../widgets/sheet_kit.dart' show sentenceCaseOf;

/// Today's puzzle, full screen.
///
/// Guess a hidden five-symbol code in six tries. Each guess comes back with how
/// many symbols are exactly right and how many are right but in the wrong slot
/// — positionless, which is what makes it a puzzle rather than a lookup.
///
/// The code is never on the device while it can still be used: guesses are
/// scored on the server and only the feedback comes back.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({
    super.key,
    required this.feedApi,
    required this.userId,
  });

  final FeedApi feedApi;
  final String userId;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  /// The row being composed, shorter than [kPuzzleSlots] until it is full.
  final List<int> _draft = [];
  bool _busy = false;
  String? _errorCode;

  /// A send to friends in flight, so a second tap cannot race the first.
  bool _telling = false;

  @override
  void initState() {
    super.initState();
    FeedStore.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    FeedStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _push(int symbol) {
    if (_draft.length >= kPuzzleSlots || _busy) return;
    setState(() => _draft.add(symbol));
    HapticFeedback.selectionClick();
  }

  void _pop() {
    if (_draft.isEmpty || _busy) return;
    setState(() => _draft.removeLast());
    HapticFeedback.selectionClick();
  }

  Future<void> _submit() async {
    if (_draft.length != kPuzzleSlots || _busy) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      final attempt = await widget.feedApi.guess(
        userId: widget.userId,
        dayKey: FeedStore.instance.dayKey,
        guess: List<int>.from(_draft),
      );
      // Hand the server's own attempt to the store BEFORE clearing the draft.
      // This used to rely on the board subscription alone, and a board that had
      // gone quiet — the socket the OS suspended while you were away, most
      // often — swallowed the row whole: the draft vanished, the grid still
      // showed the guess before it, and the guess was gone from the screen
      // despite having been accepted. Nothing on the screen could recover, so
      // the only way back was to restart the app.
      //
      // Not `mounted`-gated: the write landed, and the store outlives this
      // screen. Bailing here on a screen popped mid-flight would drop a
      // confirmed guess on the floor for the Feed band too.
      FeedStore.instance.applyPuzzleAttempt(attempt);
      if (!mounted) return;
      setState(() {
        _draft.clear();
        _busy = false;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      setState(() {
        _busy = false;
        _errorCode = ['ALREADY_SOLVED', 'OUT_OF_GUESSES', 'BAD_GUESS']
            .firstWhere(s.contains, orElse: () => 'UNKNOWN');
      });
    }
  }

  Future<void> _share(PuzzleAttempt attempt) async {
    final l10n = AppLocalizations.of(context);
    final store = FeedStore.instance;
    final header = l10n.puzzleShareHeader(
      store.edition,
      attempt.solved ? '${attempt.guesses.length}' : 'X',
    );
    await Clipboard.setData(
      ClipboardData(text: '$header\n${attempt.shareGrid}'),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    showAppToast(
      context, l10n.puzzleShareCopied,
      tone: ToastTone.success,
    );
  }

  /// Tells the player's friends how today's code went — the same confirm,
  /// the same once-only rule and the same wording as the four timed boards,
  /// because from a friend's side it is the same thing: how you did today.
  Future<void> _tellFriends() async {
    if (_telling) return;
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    final ok = await confirmTellFriends(context);
    if (!ok || !mounted) return;
    setState(() => _telling = true);
    try {
      await widget.feedApi.sharePuzzleResult(
        userId: widget.userId,
        dayKey: FeedStore.instance.dayKey,
      );
      FeedStore.instance.markPuzzleShared();
      HapticFeedback.mediumImpact();
      toast.show(l10n.gameTellFriendsSent, tone: ToastTone.success);
    } catch (e) {
      final code = e.toString();
      if (code.contains('ALREADY_SHARED')) {
        // Sent already — from another device, or a tap this one never saw
        // answered. The friends were told; nothing to alarm anybody about.
        FeedStore.instance.markPuzzleShared();
        toast.show(l10n.gameToldFriends);
      } else {
        toast.show(
          code.contains('RESULT_PRIVATE')
              ? l10n.gameTellFriendsPrivate
              : l10n.gameTellFriendsFailed,
          tone: ToastTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _telling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final state = FeedStore.instance.puzzle;
    final attempt = state.mine;
    final done = attempt?.done ?? false;

    final header = <Widget>[
      if (Navigator.of(context).canPop())
        const Align(alignment: Alignment.centerLeft, child: GlassBackButton()),
      const SizedBox(height: 14),
      Text(
        sentenceCaseOf(context, l10n.gameCodeName),
        style: theme.displayLarge.copyWith(letterSpacing: 0.37),
      ),
      const SizedBox(height: 4),
      Text(
        sentenceCaseOf(context, l10n.puzzleScreenSubtitle),
        style: theme.bodySoft.copyWith(color: theme.inkMuted),
      ),
      const SizedBox(height: 6),
    ];

    // On a compact/medium window the keypad sits below the grid, in the
    // board column itself — the shape this screen has always had. On
    // expanded, [GameLayoutShell] instead offers it as `leading`, a rail of
    // full-size icon keys to the LEFT of the grid: there's finally room for
    // one, it reads as a proper desktop toolbar rather than a thumb keyboard
    // pinned under the board, and it's one more thing off the vertical stack
    // that used to force a scroll. `done` drops it either way — a finished
    // board has an outcome card to show, not keys to press.
    final game = <Widget>[
      _Grid(attempt: attempt, draft: _draft),
      if (_errorCode != null) ...[
        const SizedBox(height: 12),
        Text(
          switch (_errorCode) {
            'ALREADY_SOLVED' => l10n.puzzleErrorAlreadySolved,
            'OUT_OF_GUESSES' => l10n.puzzleErrorOutOfGuesses,
            _ => l10n.puzzleErrorGeneric,
          },
          style: theme.bodySoft.copyWith(color: theme.danger),
        ),
      ],
      const SizedBox(height: 20),
      if (done)
        _Outcome(
          attempt: attempt!,
          onShare: () => _share(attempt),
          onTellFriends: _telling ? null : _tellFriends,
        )
      else if (!context.isExpanded)
        _Keypad(
          draft: _draft,
          busy: _busy,
          onPush: _push,
          onPop: _pop,
          onSubmit: _submit,
        ),
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
              board: game,
              boardWidth: 440,
              leading: done
                  ? null
                  : _SideKeypad(
                      draft: _draft,
                      busy: _busy,
                      onPush: _push,
                      onPop: _pop,
                      onSubmit: _submit,
                    ),
              sidebar: _Scoreboard(state: state, viewerId: widget.userId),
            ),
          ),
        ],
      ),
    );
  }
}

/// Six rows of five slots: the guesses so far, the row being composed, then
/// empty outlines for what remains.
class _Grid extends StatelessWidget {
  const _Grid({required this.attempt, required this.draft});

  final PuzzleAttempt? attempt;
  final List<int> draft;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final played = attempt?.guesses ?? const <List<int>>[];
    final feedback = attempt?.feedback ?? const <PuzzlePegs>[];
    final draftRow = played.length;

    return Column(
      children: [
        for (var row = 0; row < kPuzzleMaxGuesses; row++)
          Padding(
            key: ValueKey('row_$row'),
            padding: const EdgeInsets.only(bottom: 8),
            child: _Row(
              symbols: row < played.length
                  ? played[row]
                  : (row == draftRow ? draft : const []),
              pegs: row < feedback.length ? feedback[row] : null,
              revealed: row < played.length,
              accent: theme.accent,
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.symbols,
    required this.pegs,
    required this.revealed,
    required this.accent,
  });

  final List<int> symbols;
  final PuzzlePegs? pegs;
  final bool revealed;
  final Color accent;

  /// This slot's status, once revealed. Green means exactly right, the
  /// accent-tinted "light" means the right symbol in the wrong place — the
  /// Wordle-style per-tile read `pegsForSlots` computes server-side, only for
  /// the player's own guesses (see the library doc on why).
  PuzzlePegSlot? _statusFor(int i) {
    if (!revealed || pegs == null || i >= pegs!.slots.length) return null;
    return pegs!.slots[i];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);

    return Row(
      children: [
        for (var i = 0; i < kPuzzleSlots; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: AspectRatio(
                aspectRatio: 1,
                child: TweenAnimationBuilder<double>(
                  // Sequential flip: each slot turns a beat after the one
                  // before it, so a submitted row reads as being checked
                  // left-to-right rather than resolving all at once.
                  key: ValueKey('cell_${i}_$revealed${symbols.length}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: revealed
                      ? motion.stagger(theme.motionMed, i, strideMs: 90)
                      : motion.d(theme.motionFast),
                  curve: motion.c(theme.motionEntrance),
                  builder: (context, v, child) {
                    final status = v > 0.5 ? _statusFor(i) : null;
                    final Color? lit = switch (status) {
                      PuzzlePegSlot.exact => theme.success,
                      PuzzlePegSlot.present => theme.accent,
                      _ => null,
                    };
                    // A symbol just typed lands with a little pop; a checked
                    // row flips cell by cell. Lit cells take a solid tint of
                    // their verdict instead of an outline and a glow.
                    final pop = !revealed && i == symbols.length - 1
                        ? 1 + 0.14 * math.sin(v * math.pi)
                        : 1.0;
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateX(revealed ? (1 - v) * 1.4 : 0)
                        ..scaleByDouble(pop, pop, 1, 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: lit != null
                              ? lit.withValues(alpha: 0.30)
                              : theme.ink.withValues(
                                  alpha: i < symbols.length ? 0.10 : 0.05,
                                ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: child,
                      ),
                    );
                  },
                  child: i < symbols.length
                      ? PuzzleSymbol(index: symbols[i], size: 22, accent: accent)
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The six symbols, a backspace and a submit.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.draft,
    required this.busy,
    required this.onPush,
    required this.onPop,
    required this.onSubmit,
  });

  final List<int> draft;
  final bool busy;
  final void Function(int) onPush;
  final VoidCallback onPop;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final full = draft.length == kPuzzleSlots;

    return Column(
      children: [
        Row(
          children: [
            for (var s = 0; s < kPuzzleSymbolCount; s++)
              Expanded(
                child: Padding(
                  key: ValueKey('key_$s'),
                  padding: const EdgeInsets.only(right: 6),
                  child: _Key(
                    onTap: busy ? null : () => onPush(s),
                    semanticLabel: l10n.puzzleSymbolSemanticLabel(s + 1),
                    child: PuzzleSymbol(
                      index: s,
                      size: 22,
                      accent: theme.accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Key(
                onTap: busy || draft.isEmpty ? null : onPop,
                semanticLabel: l10n.puzzleBackspace,
                child: Icon(
                  CupertinoIcons.delete_left,
                  size: 20,
                  color: theme.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _SubmitButton(
                enabled: full && !busy,
                label: sentenceCaseOf(context, l10n.puzzleSubmit),
                onTap: onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The same six symbols, backspace and submit as [_Keypad], reflowed into a
/// vertical rail — [GameLayoutShell]'s `leading` slot on expanded windows,
/// where there's room to the left of the grid for full-size icon keys instead
/// of a thumb-width row pinned under the board.
class _SideKeypad extends StatelessWidget {
  const _SideKeypad({
    required this.draft,
    required this.busy,
    required this.onPush,
    required this.onPop,
    required this.onSubmit,
  });

  final List<int> draft;
  final bool busy;
  final void Function(int) onPush;
  final VoidCallback onPop;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final full = draft.length == kPuzzleSlots;

    return Column(
      children: [
        for (var s = 0; s < kPuzzleSymbolCount; s++)
          Padding(
            key: ValueKey('side_key_$s'),
            padding: const EdgeInsets.only(bottom: 8),
            child: AspectRatio(
              aspectRatio: 1,
              child: _Key(
                onTap: busy ? null : () => onPush(s),
                semanticLabel: l10n.puzzleSymbolSemanticLabel(s + 1),
                child: PuzzleSymbol(index: s, size: 24, accent: theme.accent),
              ),
            ),
          ),
        AspectRatio(
          aspectRatio: 1,
          child: _Key(
            onTap: busy || draft.isEmpty ? null : onPop,
            semanticLabel: l10n.puzzleBackspace,
            child: Icon(
              CupertinoIcons.delete_left,
              size: 20,
              color: theme.ink,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SubmitButton(
          enabled: full && !busy,
          label: sentenceCaseOf(context, l10n.puzzleSubmit),
          onTap: onSubmit,
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final VoidCallback? onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // The iOS keyboard key: filled, borderless, dipping under the thumb.
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: SpringPress(
        onTap: onTap,
        semanticLabel: semanticLabel,
        scale: 0.9,
        haptic: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: theme.ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

/// The guess button: a capsule in the outgoing-bubble colour once the row is
/// full, a quiet one until then.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SpringPress(
      onTap: enabled ? onTap : null,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: theme.motionFast,
        height: 52,
        decoration: BoxDecoration(
          color: enabled
              ? theme.bubbleFill(isMine: true)
              : theme.ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.body.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: enabled ? theme.accentInk : theme.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// Shown once the player can no longer act.
class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.attempt,
    required this.onShare,
    required this.onTellFriends,
  });

  final PuzzleAttempt attempt;
  final VoidCallback onShare;

  /// Null while a send is in flight.
  final VoidCallback? onTellFriends;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    final solved = attempt.solved;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        children: [
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
              solved ? CupertinoIcons.star_fill : CupertinoIcons.lock_fill,
              size: 28,
              color: solved ? Colors.white : theme.inkMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            sentenceCaseOf(
              context,
              solved
                  ? l10n.puzzleSolvedTitle(attempt.guesses.length)
                  : l10n.puzzleFailedTitle,
            ),
            textAlign: TextAlign.center,
            style: theme.displayMedium,
          ),
          if (!solved && attempt.answer != null) ...[
            const SizedBox(height: 12),
            Text(
              sentenceCaseOf(context, l10n.puzzleAnswerWas),
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final sym in attempt.answer!)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PuzzleSymbol(
                      index: sym,
                      size: 24,
                      accent: theme.accent,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _OutcomeAction(
                  icon: CupertinoIcons.doc_on_doc,
                  label: sentenceCaseOf(context, l10n.puzzleShare),
                  onTap: onShare,
                ),
              ),
              const SizedBox(width: 10),
              // Retired once used: the server allows one send per result, so
              // a button that stayed would only ever answer with an error.
              Expanded(
                child: attempt.shared
                    ? _OutcomeAction(
                        icon: CupertinoIcons.checkmark_alt,
                        label: sentenceCaseOf(context, l10n.gameToldFriends),
                        onTap: null,
                      )
                    : _OutcomeAction(
                        icon: CupertinoIcons.bell_fill,
                        label: sentenceCaseOf(context, l10n.gameTellFriends),
                        onTap: onTellFriends,
                        prominent: true,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.86, end: 1),
          duration: MotionScope.of(context).d(const Duration(milliseconds: 620)),
          curve: Curves.elasticOut,
          builder: (context, sc, child) =>
              Transform.scale(scale: sc, child: child),
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

/// One tappable action on the outcome card.
class _OutcomeAction extends StatelessWidget {
  const _OutcomeAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final on = onTap != null;
    final fill = prominent && on
        ? theme.bubbleFill(isMine: true)
        : theme.ink.withValues(alpha: on ? 0.08 : 0.05);
    final ink = prominent && on
        ? theme.accentInk
        : (on ? theme.ink : theme.inkMuted);
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

/// Everyone who has finished today, best first.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.state, required this.viewerId});

  final PuzzleState state;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final scores = state.scores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sentenceCaseOf(context, l10n.puzzleScoreboardLabel),
                  style: theme.bodySoft.copyWith(
                    fontSize: 13,
                    color: theme.inkMuted,
                  ),
                ),
              ),
              AllTimeLink(game: RecordGame.code, viewerId: viewerId),
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
                if (scores.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      sentenceCaseOf(context, l10n.puzzleScoreboardEmpty),
                      style: theme.bodySoft.copyWith(color: theme.inkMuted),
                    ),
                  )
                else
                  for (var i = 0; i < scores.length; i++) ...[
                    Container(
                      key: ValueKey(scores[i].userId),
                      color: scores[i].userId == viewerId
                          ? theme.accent.withValues(alpha: 0.10)
                          : null,
                      padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.ink.withValues(alpha: 0.07),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: theme.body.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.inkMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              scores[i].userId == viewerId
                                  ? sentenceCaseOf(
                                      context,
                                      l10n.momentRailYouLabel,
                                    )
                                  : scores[i].name,
                              style: scores[i].userId == viewerId
                                  ? theme.bodyEmph.copyWith(color: theme.accent)
                                  : theme.body.copyWith(color: theme.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            scores[i].solved
                                ? '${scores[i].guessCount}/$kPuzzleMaxGuesses'
                                : 'X/$kPuzzleMaxGuesses',
                            style: theme.body.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: scores[i].solved
                                  ? theme.ink
                                  : theme.inkMuted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < scores.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 56),
                        child: Container(
                          height: hairline,
                          color: theme.ink.withValues(alpha: 0.10),
                        ),
                      ),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
