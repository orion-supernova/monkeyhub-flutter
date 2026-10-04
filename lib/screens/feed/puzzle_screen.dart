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
import '../../widgets/game_result_actions.dart';
import '../../widgets/app_toast.dart';
import '../games/game_scaffold.dart' show confirmTellFriends;
import '../../widgets/game_layout_shell.dart';
import '../../widgets/game_records.dart';
import '../../widgets/game_celebration.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/labeled_field.dart' show FormErrorBanner;
import '../../widgets/puzzle_symbol.dart';
import '../../l10n/text_case.dart';

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
    // On a phone the keypad is pinned to the bottom edge, outside the
    // scroller: in the board column it sat under the home indicator on an
    // iPhone 16 Pro, and Guess — the one action that matters — needed a
    // scroll to reach. The grid and the scores scroll above it.
    final pinnedKeypad = !done && !context.isExpanded;

    List<Widget> game(double? gridWidth) => [
      _Grid(attempt: attempt, draft: _draft, maxWidth: gridWidth),
      if (_errorCode != null) ...[
        const SizedBox(height: 12),
        FormErrorBanner(switch (_errorCode) {
          'ALREADY_SOLVED' => l10n.puzzleErrorAlreadySolved,
          'OUT_OF_GUESSES' => l10n.puzzleErrorOutOfGuesses,
          _ => l10n.puzzleErrorGeneric,
        }),
      ],
      if (done) ...[
        const SizedBox(height: 20),
        _Outcome(
          attempt: attempt!,
          onShare: () => _share(attempt),
          onTellFriends: _telling ? null : _tellFriends,
        ),
      ],
    ];

    Widget shell(double? gridWidth) => GameLayoutShell(
      header: header,
      board: game(gridWidth),
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
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // `bottom: false`, with the inset moved onto the shell's own
          // scroller — see [edgeToEdgeBottom].
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: pinnedKeypad
                      ? LayoutBuilder(
                          builder: (context, box) => _FadeAbovePinned(
                            child: shell(
                              _fitGridWidth(context, box.maxHeight, theme),
                            ),
                          ),
                        )
                      : shell(null),
                ),
                if (pinnedKeypad)
                  AdaptivePageBody(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        10,
                        20,
                        // Clears the home indicator, with a floor so a phone
                        // without one still gets breathing room.
                        math.max(MediaQuery.paddingOf(context).bottom, 16),
                      ),
                      child: _Keypad(
                        draft: _draft,
                        busy: _busy,
                        onPush: _push,
                        onPop: _pop,
                        onSubmit: _submit,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The grid width at which all six guess rows fit in [viewport] under the
/// header, so on a phone the last row isn't cut off by the pinned keypad.
/// Wordle does the same: the tiles shrink to the screen, the board never
/// scrolls. Estimated from the header's own type sizes through the text
/// scaler; [_FadeAbovePinned] covers whatever the estimate misses (a wrapped
/// subtitle in Turkish at large text, an error banner).
double _fitGridWidth(BuildContext context, double viewport, AppTheme theme) {
  final scaler = MediaQuery.textScalerOf(context);
  double line(TextStyle style) =>
      scaler.scale((style.fontSize ?? 17) * (style.height ?? 1.2));
  final header =
      8 + // the shell's top padding
      (Navigator.of(context).canPop() ? 40 : 0) +
      14 +
      line(theme.displayLarge) +
      4 +
      line(theme.bodySoft) +
      6 +
      20; // the shell's header-to-board gap
  // Air for the fade to land in: with the last row's own 8pt gap this clears
  // the 20pt mask, so the fade sits under the board, not across its last row.
  final rows = viewport - header - 16;
  final cell = (rows / kPuzzleMaxGuesses) - 8; // each row's bottom gap
  return (cell * kPuzzleSlots + 6 * (kPuzzleSlots - 1)).clamp(200.0, 440.0);
}

/// A short fade at the foot of the scroller, above the pinned keypad, so a
/// board that still runs on under it reads as "more below" instead of being
/// sliced by a hard edge. A mask, not a gradient in the background colour:
/// themes paint patterned backgrounds that a flat colour wouldn't match.
class _FadeAbovePinned extends StatelessWidget {
  const _FadeAbovePinned({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.white, Colors.white, Colors.transparent],
        stops: [0, 1 - 20 / math.max(bounds.height, 20), 1],
      ).createShader(bounds),
      child: child,
    );
  }
}

/// Six rows of five slots: the guesses so far, the row being composed, then
/// empty outlines for what remains.
class _Grid extends StatelessWidget {
  const _Grid({required this.attempt, required this.draft, this.maxWidth});

  final PuzzleAttempt? attempt;
  final List<int> draft;

  /// Caps the grid so all six rows fit above a pinned keypad — see
  /// [_fitGridWidth]. Null lets it fill the board column.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final played = attempt?.guesses ?? const <List<int>>[];
    final feedback = attempt?.feedback ?? const <PuzzlePegs>[];
    final draftRow = played.length;

    final grid = Column(
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
    if (maxWidth == null) return grid;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: grid,
      ),
    );
  }
}

/// The "right symbol, wrong spot" colour — the yellow the rules promise.
const Color kPuzzlePresentAmber = Color(0xFFF5B400);

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

  /// This slot's status, once revealed. Green means exactly right, amber
  /// means the right symbol in the wrong place — the
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
        for (var i = 0; i < kPuzzleSlots; i++) ...[
          // Gaps are their own boxes BETWEEN the cells, not padding inside
          // one: padding on all but the last made every `Expanded` the same
          // width but the last cell 6pt wider, and `AspectRatio` then made it
          // 6pt taller too, so the grid's right edge stepped out.
          if (i > 0) const SizedBox(width: 6),
          Expanded(
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
                    // Amber, fixed, on every theme — not the accent. The
                    // rules tell everyone "yellow means right symbol, wrong
                    // spot", and on Basic the accent is blue: the board was
                    // contradicting its own instructions.
                    final Color? lit = switch (status) {
                      PuzzlePegSlot.exact => theme.success,
                      PuzzlePegSlot.present => kPuzzlePresentAmber,
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
                          // Amber is lighter than green, so it takes a little
                          // more strength to read as the same weight of verdict.
                          color: lit != null
                              ? lit.withValues(
                                  alpha: status == PuzzlePegSlot.present
                                      ? 0.55
                                      : 0.30,
                                )
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
        ],
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
            for (var s = 0; s < kPuzzleSymbolCount; s++) ...[
              // Gaps between the keys, never inside one — see [_Row].
              if (s > 0) const SizedBox(width: 6),
              Expanded(
                key: ValueKey('key_$s'),
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
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              // A capsule like Guess beside it — two shapes side by side
              // read as two different kinds of control.
              child: _Key(
                onTap: busy || draft.isEmpty ? null : onPop,
                semanticLabel: l10n.puzzleBackspace,
                capsule: true,
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
              child: SheetActionButton(
                label: l10n.puzzleSubmit,
                haptic: false,
                onTap: full && !busy ? onSubmit : null,
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
        SheetActionButton(
          label: l10n.puzzleSubmit,
          haptic: false,
          onTap: full && !busy ? onSubmit : null,
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
    this.capsule = false,
  });

  final VoidCallback? onTap;
  final String semanticLabel;
  final Widget child;

  /// The backspace beside Guess takes the button's capsule shape.
  final bool capsule;

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
            borderRadius: BorderRadius.circular(capsule ? 999 : theme.radiusMd),
          ),
          alignment: Alignment.center,
          child: child,
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
          GameResultActions(
            actions: [
              GameResultAction(
                icon: CupertinoIcons.doc_on_doc,
                label: sentenceCaseOf(context, l10n.puzzleShare),
                onTap: onShare,
              ),
              // Retired once used: the server allows one send per result, so
              // a button that stayed would only ever answer with an error.
              attempt.shared
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
        GroupedHeader(
          l10n.puzzleScoreboardLabel,
          trailing: AllTimeLink(game: RecordGame.code, viewerId: viewerId),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
          child: ColoredBox(
            color: groupedFill(theme),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (scores.isEmpty)
                  EmptyLine(l10n.puzzleScoreboardEmpty)
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
                              fontSize: 17,
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
