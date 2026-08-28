import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/feed_api.dart';
import '../../data/feed_store.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/puzzle.dart';
import '../../theme/layout.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/game_layout_shell.dart';
import '../../widgets/puzzle_symbol.dart';

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
    showAppToast(
      context, l10n.puzzleShareCopied,
      tone: ToastTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final state = FeedStore.instance.puzzle;
    final attempt = state.mine;
    final done = attempt?.done ?? false;

    final header = <Widget>[
      Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(l10n.puzzleScreenTitle, style: theme.displayMedium),
      const SizedBox(height: 10),
      Row(
        children: [
          Container(width: 18, height: 1, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(l10n.puzzleScreenSubtitle, style: theme.caption),
          ),
        ],
      ),
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
        _Outcome(attempt: attempt!, onShare: () => _share(attempt))
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
          SafeArea(
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
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateX(revealed ? (1 - v) * 1.4 : 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: lit != null
                              ? lit.withValues(alpha: 0.22)
                              : theme.surfaceSunken,
                          borderRadius: BorderRadius.circular(theme.radiusMd),
                          border: Border.all(
                            color: lit ?? theme.divider,
                            width: lit != null ? 1.6 : 1,
                          ),
                          boxShadow: lit == null
                              ? null
                              : [
                                  BoxShadow(
                                    color: lit.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    spreadRadius: 0.5,
                                  ),
                                ],
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
                  Icons.backspace_outlined,
                  size: 16,
                  color: theme.inkSoft,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: FocusableTap(
                onTap: full && !busy ? onSubmit : null,
                semanticLabel: l10n.puzzleSubmit,
                radius: theme.radiusMd,
                child: GestureDetector(
                  onTap: full && !busy ? onSubmit : null,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: theme.motionFast,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: full ? theme.accent : theme.surfaceSunken,
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.puzzleSubmit,
                      style: theme.label.copyWith(
                        color: full ? theme.accentInk : theme.inkMuted,
                      ),
                    ),
                  ),
                ),
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
              Icons.backspace_outlined,
              size: 18,
              color: theme.inkSoft,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FocusableTap(
          onTap: full && !busy ? onSubmit : null,
          semanticLabel: l10n.puzzleSubmit,
          radius: theme.radiusMd,
          child: GestureDetector(
            onTap: full && !busy ? onSubmit : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: theme.motionFast,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: full ? theme.accent : theme.surfaceSunken,
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              alignment: Alignment.center,
              child: Text(
                l10n.puzzleSubmit,
                textAlign: TextAlign.center,
                style: theme.label.copyWith(
                  color: full ? theme.accentInk : theme.inkMuted,
                ),
              ),
            ),
          ),
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
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(color: theme.divider),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Shown once the player can no longer act.
class _Outcome extends StatelessWidget {
  const _Outcome({required this.attempt, required this.onShare});

  final PuzzleAttempt attempt;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: theme.roomCardDecoration(ephemeral: false, active: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attempt.solved
                ? l10n.puzzleSolvedTitle(attempt.guesses.length)
                : l10n.puzzleFailedTitle,
            style: theme.displaySmall,
          ),
          if (!attempt.solved && attempt.answer != null) ...[
            const SizedBox(height: 12),
            Text(l10n.puzzleAnswerWas, style: theme.monoTiny),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final s in attempt.answer!)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: PuzzleSymbol(
                      index: s,
                      size: 20,
                      accent: theme.accent,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          FocusableTap(
            onTap: onShare,
            semanticLabel: l10n.puzzleShare,
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
                    l10n.puzzleShare,
                    style: theme.label.copyWith(color: theme.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(l10n.puzzleScoreboardLabel, style: theme.label),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: theme.divider)),
          ],
        ),
        const SizedBox(height: 12),
        if (state.scores.isEmpty)
          Text(
            l10n.puzzleScoreboardEmpty,
            style: theme.bodySoft.copyWith(color: theme.inkMuted),
          )
        else
          for (var i = 0; i < state.scores.length; i++)
            Padding(
              key: ValueKey(state.scores[i].userId),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}', style: theme.monoTiny),
                  ),
                  Expanded(
                    child: Text(
                      state.scores[i].userId == viewerId
                          ? l10n.momentRailYouLabel
                          : state.scores[i].name,
                      style: state.scores[i].userId == viewerId
                          ? theme.bodyEmph.copyWith(color: theme.accent)
                          : theme.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    state.scores[i].solved
                        ? '${state.scores[i].guessCount}/$kPuzzleMaxGuesses'
                        : 'X/$kPuzzleMaxGuesses',
                    style: theme.monoLarge.copyWith(
                      fontSize: 14,
                      color: state.scores[i].solved
                          ? theme.ink
                          : theme.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
