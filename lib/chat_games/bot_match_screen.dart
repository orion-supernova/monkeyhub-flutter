import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../games/how_to/chat_guides.dart';
import '../games/how_to/how_to_play.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../screens/games/game_scaffold.dart' show GameTool;
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/turn_board.dart';
import '../turn_games/bot.dart';
import '../turn_games/registry.dart';
import '../widgets/game_layout_shell.dart';
import '../widgets/ios_kit.dart';
import '../widgets/typing_indicator.dart';
import 'match_copy.dart';
import 'monkey_avatar.dart';

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
class BotMatchScreen extends StatefulWidget {
  const BotMatchScreen({super.key, required this.game, required this.level});

  final String game;
  final BotLevel level;

  @override
  State<BotMatchScreen> createState() => _BotMatchScreenState();
}

class _BotMatchScreenState extends State<BotMatchScreen> {
  late final TurnGame<dynamic, dynamic> _rules = turnGameFor(widget.game)!;
  final _random = Random();

  late String _state = _rules.initialEncoded(2);
  int _me = 0;

  /// Positions before each of the player's moves, for undo.
  final List<String> _history = [];
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

  bool get _over => _rules.outcomeEncoded(_state) != null;

  bool get _myTurn => !_over && !_thinking && _rules.toMoveEncoded(_state) == _me;

  void _play(String move) {
    if (!_myTurn) return;
    final String next;
    try {
      next = _rules.applyEncoded(_state, move);
    } catch (_) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() {
      _history.add(_state);
      _state = next;
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
      _state = _rules.applyEncoded(_state, move);
      _thinking = false;
    });
    HapticFeedback.selectionClick();
    _afterMove();
  }

  void _undo() {
    if (_history.isEmpty) return;
    _epoch++;
    setState(() {
      _state = _history.removeLast();
      _thinking = false;
    });
    HapticFeedback.selectionClick();
  }

  void _newGame() {
    _epoch++;
    setState(() {
      _me = 1 - _me;
      _state = _rules.initialEncoded(2);
      _history.clear();
      _thinking = false;
    });
    _maybeBot();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final outcome = _rules.outcomeEncoded(_state);
    final level = switch (widget.level) {
      BotLevel.easy => l10n.gameTierEasy,
      BotLevel.medium => l10n.gameTierMedium,
      BotLevel.hard => l10n.gameTierHard,
    };
    final botName = '${l10n.chatGameBotName} · ${sentenceCaseOf(context, level)}';
    final you = sentenceCaseOf(context, l10n.momentRailYouLabel);
    final status = outcome != null
        ? outcome.winner == null
              ? l10n.chatGameDraw
              : outcome.winner == _me
              ? l10n.chatGameYouWon
              : l10n.chatGameWonBy(l10n.chatGameBotName)
        : _myTurn
        ? l10n.chatGameYourMove
        : l10n.chatGameTurnOf(l10n.chatGameBotName);

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

    final board = <Widget>[
      _BotPlate(
        name: botName,
        badge: l10n.chatGameBotBadge,
        thinking: _thinking,
        seatColor: seatFill(theme, _bot, widget.game),
      ),
      const SizedBox(height: 10),
      AspectRatio(
        aspectRatio: TurnBoard.aspectRatioOf(widget.game, _state),
        child: TurnBoard(
          gameId: widget.game,
          state: _state,
          mySeat: _me,
          enabled: _myTurn,
          onMove: _play,
          seatLabels: _me == 0 ? [you[0], 'M'] : ['M', you[0]],
        ),
      ),
      const SizedBox(height: 10),
      _BotPlate(name: you, seatColor: seatFill(theme, _me, widget.game)),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: GameTool(
              icon: CupertinoIcons.arrow_uturn_left,
              label: l10n.gameUndo,
              onTap: _history.isEmpty || outcome != null ? null : _undo,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GameTool(
              icon: CupertinoIcons.refresh,
              label: l10n.chatGameNewGame,
              onTap: _newGame,
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: GameLayoutShell(
              header: header,
              board: board,
              boardWidth: 480,
              sidebar: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  sentenceCaseOf(context, l10n.practiceNotRanked),
                  style: groupedFooterStyle(theme),
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
  });

  final String name;
  final Color seatColor;
  final String? badge;
  final bool thinking;

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
          if (thinking) TypingDots(color: theme.inkMuted),
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
