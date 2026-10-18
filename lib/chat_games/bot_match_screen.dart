import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../games/how_to/chat_guides.dart';
import '../games/how_to/how_to_play.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../platform.dart';
import '../screens/games/game_scaffold.dart' show GameTool;
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/turn_board.dart';
import '../turn_games/bot.dart';
import '../turn_games/registry.dart';
import '../turn_games/turn_rules.dart';
import '../widgets/app_toast.dart';
import '../widgets/game_layout_shell.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';
import '../widgets/typing_indicator.dart';
import 'game_side_panel.dart';
import 'match_copy.dart';
import 'monkey_avatar.dart';
import 'move_history.dart';

/// A game against the app's own bot, entirely on the phone.
///
/// Nothing here touches the server: no row, no card, no push, and nothing
/// posted to the chat it was started from. The bot searches on a background
/// isolate ([pickBotMove]) and takes a short beat before answering even when
/// it has already decided, because a reply that lands the instant you lift
/// your finger reads as a machine rather than an opponent.
///
/// The player takes seat one in the first game and the seats alternate on
/// every "new game", so the bot does not always move second.
///
/// ## The table's rules
///
/// * **Takebacks** are counted per game by level ([botTakebacks]: easy 3,
///   medium 1, hard none). One takes back the player's last move and the
///   bot's reply to it, so the player is to move again in the same spot.
/// * **Resign** (the flag) ends the game as the bot's win, after a confirm.
/// * **Offer draw**, on the player's move: the bot takes it when it is not
///   ahead ([botAcceptsDraw]). Turned down, it can be offered again after two
///   more of the player's moves, so it is a question and not a slot machine.
/// * Earlier positions can be looked at at any time (the move list, ← →); the
///   board is read-only until it is back on the current move.
class BotMatchScreen extends StatefulWidget {
  const BotMatchScreen({super.key, required this.game, required this.level});

  final String game;
  final BotLevel level;

  @override
  State<BotMatchScreen> createState() => _BotMatchScreenState();
}

/// How a bot game ended when the board did not end it.
enum _Ending { resigned, drawAgreed }

class _BotMatchScreenState extends State<BotMatchScreen> {
  late final TurnGame<dynamic, dynamic> _rules = turnGameFor(widget.game)!;
  final _random = Random();

  /// Every move of this game, both sides, from the opening.
  final List<String> _moves = [];
  late String _state = _rules.initialEncoded(2);
  int _me = 0;

  /// The length of [_moves] before each of the player's moves: where a
  /// takeback returns to.
  final List<int> _myPlies = [];
  late int _takebacksLeft = botTakebacks(widget.level);
  _Ending? _ending;

  /// The player's draw offer is being weighed.
  bool _weighingDraw = false;

  /// [_moves]'s length when the bot last turned a draw down.
  int? _drawDeclinedAt;

  /// The position on the board while looking back; null for the current one.
  int? _viewPly;
  GameLine? _line;

  bool _thinking = false;
  int _epoch = 0;

  static const _minThink = Duration(milliseconds: 450);

  int get _bot => 1 - _me;

  @override
  void initState() {
    super.initState();
    _maybeBot();
    // First game of this kind ever: the guide, before the first move.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showHowToPlayOnce(
          context,
          chatGuide(AppLocalizations.of(context), widget.game, practice: true),
        );
      }
    });
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }

  TurnOutcome? get _boardOutcome => _rules.outcomeEncoded(_state);

  bool get _over => _ending != null || _boardOutcome != null;

  bool get _myTurn =>
      !_over && !_thinking && _rules.toMoveEncoded(_state) == _me;

  GameLine get _gameLine => _line ??= GameLine.replay(
    l10n: AppLocalizations.of(context),
    game: widget.game,
    seats: 2,
    moves: _moves,
  );

  void _push(String move, String next) {
    _moves.add(move);
    _state = next;
    _line = null;
  }

  void _play(String move) {
    if (!_myTurn || _viewPly != null) return;
    final String next;
    try {
      next = _rules.applyEncoded(_state, move);
    } catch (_) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() {
      _myPlies.add(_moves.length);
      _push(move, next);
    });
    _afterMove();
  }

  void _afterMove() {
    if (_over) {
      HapticFeedback.mediumImpact();
      return;
    }
    _maybeBot();
  }

  /// Lets the bot move for as long as it is the bot's turn — Dots and Boxes
  /// hands the same player another move after a box.
  Future<void> _maybeBot() async {
    if (_over || _rules.toMoveEncoded(_state) != _bot) return;
    final epoch = ++_epoch;
    setState(() => _thinking = true);
    final started = DateTime.now();
    String move;
    try {
      move = await pickBotMove(
        gameId: widget.game,
        state: _state,
        level: widget.level,
        seed: _random.nextInt(1 << 31),
      );
    } catch (_) {
      if (!mounted || epoch != _epoch) return;
      setState(() => _thinking = false);
      return;
    }
    final spent = DateTime.now().difference(started);
    final jitter = Duration(milliseconds: _random.nextInt(300));
    final wait = _minThink + jitter - spent;
    if (!wait.isNegative) await Future<void>.delayed(wait);
    if (!mounted || epoch != _epoch) return;
    setState(() {
      _push(move, _rules.applyEncoded(_state, move));
      _thinking = false;
    });
    HapticFeedback.selectionClick();
    _afterMove();
  }

  /// A takeback is there when the player has a move to take back, has one
  /// left, and the game did not end by resignation or agreement (a board
  /// that ended in a loss can still be taken back: that is what it is for).
  bool get _canTakeBack =>
      _takebacksLeft > 0 && _myPlies.isNotEmpty && _ending == null;

  void _takeBack() {
    if (!_canTakeBack) return;
    _epoch++;
    setState(() {
      final to = _myPlies.removeLast();
      _moves.removeRange(to, _moves.length);
      _state = _moves.isEmpty
          ? _rules.initialEncoded(2)
          : _gameLine.stateAt(to);
      _line = null;
      _takebacksLeft--;
      _thinking = false;
      _viewPly = null;
      _drawDeclinedAt = null;
    });
    HapticFeedback.selectionClick();
  }

  bool get _canOfferDraw =>
      _myTurn &&
      !_weighingDraw &&
      _viewPly == null &&
      _moves.isNotEmpty &&
      (_drawDeclinedAt == null || _moves.length >= _drawDeclinedAt! + 4);

  Future<void> _offerDraw() async {
    final l10n = AppLocalizations.of(context);
    if (_drawDeclinedAt != null && _moves.length < _drawDeclinedAt! + 4) {
      AppToast.of(context).show(sentenceCaseOf(context, l10n.chatGameDrawTooSoon));
      return;
    }
    if (!_canOfferDraw) return;
    final epoch = _epoch;
    final at = _state;
    setState(() => _weighingDraw = true);
    bool yes;
    try {
      yes = await botAcceptsDraw(
        gameId: widget.game,
        state: at,
        level: widget.level,
        seed: _random.nextInt(1 << 31),
      );
    } catch (_) {
      yes = false;
    }
    // A beat, like a move: an instant answer reads as a button, not a bot.
    await Future<void>.delayed(_minThink);
    if (!mounted) return;
    setState(() => _weighingDraw = false);
    if (epoch != _epoch || at != _state) return;
    if (yes) {
      HapticFeedback.mediumImpact();
      setState(() => _ending = _Ending.drawAgreed);
    } else {
      HapticFeedback.lightImpact();
      setState(() => _drawDeclinedAt = _moves.length);
      AppToast.of(context).show(
        sentenceCaseOf(context, l10n.chatGameBotPlaysOn(l10n.chatGameBotName)),
      );
    }
  }

  Future<void> _resign() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showIosActionSheet<bool>(
      context,
      title: sentenceCaseOf(context, l10n.chatGameResignConfirm),
      message: sentenceCaseOf(context, l10n.chatGameResignBody),
      actions: [
        IosSheetAction(
          label: sentenceCaseOf(context, l10n.chatGameResign),
          value: true,
          destructive: true,
        ),
      ],
      cancelLabel: sentenceCaseOf(context, l10n.chatGameCancel),
    );
    if (ok != true || !mounted || _over) return;
    _epoch++;
    HapticFeedback.mediumImpact();
    setState(() {
      _ending = _Ending.resigned;
      _thinking = false;
      _viewPly = null;
    });
  }

  void _newGame() {
    _epoch++;
    setState(() {
      _me = 1 - _me;
      _moves.clear();
      _myPlies.clear();
      _line = null;
      _state = _rules.initialEncoded(2);
      _takebacksLeft = botTakebacks(widget.level);
      _ending = null;
      _drawDeclinedAt = null;
      _weighingDraw = false;
      _viewPly = null;
      _thinking = false;
    });
    _maybeBot();
  }

  void _view(int? ply) {
    if (ply == _viewPly) return;
    setState(() => _viewPly = ply);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final outcome = _boardOutcome;
    final level = switch (widget.level) {
      BotLevel.easy => l10n.gameTierEasy,
      BotLevel.medium => l10n.gameTierMedium,
      BotLevel.hard => l10n.gameTierHard,
    };
    final botName = '${l10n.chatGameBotName} · ${sentenceCaseOf(context, level)}';
    final you = sentenceCaseOf(context, l10n.momentRailYouLabel);
    final status = switch (_ending) {
      _Ending.resigned => l10n.chatGameYouResigned,
      _Ending.drawAgreed => l10n.chatGameDrawAgreed,
      null => outcome != null
          ? outcome.winner == null
                ? l10n.chatGameDraw
                : outcome.winner == _me
                ? l10n.chatGameYouWon
                : l10n.chatGameWonBy(l10n.chatGameBotName)
          : _myTurn
          ? l10n.chatGameYourMove
          : l10n.chatGameTurnOf(l10n.chatGameBotName),
    };
    final line = _gameLine;
    final shownState = _viewPly == null ? _state : line.stateAt(_viewPly!);
    final shownMove = _viewPly == null
        ? (_moves.isEmpty ? null : _moves.last)
        : line.moveAt(_viewPly!);
    final chess = widget.game == 'chess';
    final material = chess ? ChessMaterial.of(shownState) : null;

    final header = <Widget>[
      SizedBox(
        height: 44,
        child: Row(
          children: [
            const GlassBackButton(),
            const Spacer(),
            HowToPlayButton(
              onTap: () => showHowToPlay(
                context,
                chatGuide(l10n, widget.game, practice: true),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Text(
        sentenceCaseOf(context, chatGameName(l10n, widget.game)),
        style: theme.displayLarge.copyWith(letterSpacing: 0.37),
      ),
      const SizedBox(height: 4),
      Text(
        sentenceCaseOf(context, status),
        style: theme.bodySoft.copyWith(
          color: _myTurn ? theme.accent : theme.inkMuted,
          fontWeight: _myTurn ? FontWeight.w600 : null,
        ),
      ),
      const SizedBox(height: 10),
    ];

    final boardView = Stack(
      fit: StackFit.expand,
      children: [
        TurnBoard(
          gameId: widget.game,
          state: shownState,
          mySeat: _me,
          enabled: _myTurn && _viewPly == null,
          onMove: _play,
          lastMove: shownMove,
          seatLabels: _me == 0 ? [you[0], 'M'] : ['M', you[0]],
        ),
        if (_viewPly != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(child: BackToGamePill(onTap: () => _view(null))),
          ),
      ],
    );

    Widget plate({required bool bot}) {
      final seat = bot ? _bot : _me;
      return _BotPlate(
        name: bot ? botName : you,
        badge: bot ? l10n.chatGameBotBadge : null,
        thinking: bot && (_thinking || _weighingDraw),
        seatColor: seatFill(theme, seat, widget.game),
        trailing: material == null
            ? null
            : CapturedStrip(material: material, seat: seat),
      );
    }

    final footnote = _ending != null
        ? null
        : botTakebacks(widget.level) == 0
        ? l10n.chatGameNoTakebacksHard
        : l10n.chatGameTakebacksLeft(_takebacksLeft);
    final actions = TurnActions(
      onTakeback: _canTakeBack ? _takeBack : null,
      showTakeback: botTakebacks(widget.level) > 0,
      onDraw: _canOfferDraw ? _offerDraw : null,
      onResign: _over ? null : _resign,
      extra: GameTool(
        icon: CupertinoIcons.refresh,
        label: l10n.chatGameNewGame,
        onTap: _newGame,
      ),
      footnote: footnote,
    );
    final notRanked = Text(
      sentenceCaseOf(context, l10n.practiceNotRanked),
      style: groupedFooterStyle(theme),
    );

    final board = <Widget>[
      plate(bot: true),
      const SizedBox(height: 10),
      AspectRatio(
        aspectRatio: TurnBoard.aspectRatioOf(widget.game, _state),
        child: boardView,
      ),
      const SizedBox(height: 10),
      plate(bot: false),
      const SizedBox(height: 16),
      actions,
      const SizedBox(height: 24),
    ];

    final keyboard = isPhysicalKeyboardPlatform;
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        plate(bot: true),
        const SizedBox(height: 10),
        Expanded(
          child: widget.game == 'dots'
              ? const SizedBox.shrink()
              : MoveListCard(
                  line: line,
                  viewPly: _viewPly,
                  onView: _view,
                  keyboardHint: keyboard,
                ),
        ),
        const SizedBox(height: 10),
        plate(bot: false),
        const SizedBox(height: 14),
        actions,
        const SizedBox(height: 12),
        notRanked,
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: TurnKeys(
              game: widget.game,
              onStep: (by) => _view(stepPly(_viewPly, _moves.length, by)),
              onPlay: _play,
              onTakeback: _canTakeBack ? _takeBack : null,
              child: GameLayoutShell(
                header: header,
                board: board,
                boardWidth: 480,
                sidebar: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: notRanked,
                ),
                stage: GameStage(
                  board: boardView,
                  aspectRatio: TurnBoard.aspectRatioOf(widget.game, _state),
                  panel: panel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A seat's colour, through the shared palette the boards and plates use.
Color seatFill(AppTheme theme, int seat, String game) =>
    SeatPalette(theme, gameId: game).fill(seat);

class _BotPlate extends StatelessWidget {
  const _BotPlate({
    required this.name,
    required this.seatColor,
    this.badge,
    this.thinking = false,
    this.trailing,
  });

  final String name;
  final Color seatColor;
  final String? badge;
  final bool thinking;

  /// After the name: chess's captured pieces.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Row(
        children: [
          if (badge != null)
            const MonkeyAvatar(size: 32)
          else
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: seatColor.withValues(alpha: 0.2),
              ),
              child: Icon(CupertinoIcons.person_fill, size: 18, color: seatColor),
            ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: seatColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: groupedTitleStyle(theme).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (thinking) ...[
            const SizedBox(width: 8),
            TypingDots(color: theme.inkMuted),
          ],
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: quietFill(theme),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: groupedMetaStyle(theme).copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.inkSoft,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
