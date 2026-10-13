import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../chat_games/play_style.dart';
import '../../games/how_to/chat_guides.dart';
import '../../games/how_to/how_to_play.dart';
import '../../backend/matches_api.dart';
import '../../chat_games/match_copy.dart';
import '../../chat_games/match_face.dart';
import '../../chat_games/move_notation.dart';
import '../../chat_games/turn_panel.dart';
import '../../data/matches_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
import '../../models/chat_match.dart';
import '../../party_games/party_table.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../turn_games/board/turn_board.dart';
import '../../turn_games/registry.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/game_board_skeleton.dart';
import '../../widgets/game_layout_shell.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/sheet_kit.dart';

/// Opens one in-chat game: its lobby, its board, or how it ended.
Future<void> openMatchScreen(
  BuildContext context, {
  required ChatMatch match,
  required String userId,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        MatchScreen(matchId: match.id, userId: userId, initial: match),
  ),
);

/// Opens a turn by turn game that does not exist yet ([TurnDraft]): the
/// opening board, the viewer to move. Sending the first move creates it;
/// backing out leaves nothing behind. [replace] swaps it in for the current
/// route (a rematch from a finished game's screen), so Send lands in the
/// chat rather than back on the old game.
Future<void> openTurnDraft(
  BuildContext context, {
  required TurnDraft draft,
  required String userId,
  bool replace = false,
}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => MatchScreen(matchId: '', userId: userId, draft: draft),
  );
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}

/// An in-chat game, for whoever opens it: a seated player, or a room member
/// watching.
///
/// Everything on it is driven by one [MatchController] — the game's live row,
/// the move in flight, and the heartbeat that keeps a live game unpaused. The
/// screen itself holds only what is purely visual: the 3-2-1 before a live
/// game starts, and a ticking clock while something is counting down.
///
/// Not ranked, and says so: chat games share nothing with the daily boards'
/// standings, streaks or records.
///
/// A party game (Liar's Dice, Imposter, Puzzle Race) shares the lobby, the
/// pause cover, the 3-2-1 and the result with the turn games; only the middle
/// differs, where its [PartyTable] stands in for the board and plates.
class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.matchId,
    required this.userId,
    this.initial,
    this.draft,
  });

  /// Empty for a [draft].
  final String matchId;
  final String userId;
  final ChatMatch? initial;

  /// A turn by turn game not created yet: see [openTurnDraft].
  final TurnDraft? draft;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late final MatchController _c = widget.draft != null
      ? MatchController.draft(draft: widget.draft!, userId: widget.userId)
      : MatchController(
          matchId: widget.matchId,
          userId: widget.userId,
          initial: widget.initial,
        );

  MatchesApi get _api => MatchesStore.instance.api;

  int _seenRejections = 0;
  MatchStatus? _lastStatus;

  /// The 3-2-1 before a live game starts, when this screen watched the lobby
  /// fill. Null when not counting.
  int? _countdown;
  Timer? _countdownTimer;

  /// Ticks once a second while something on screen is counting down (a
  /// pause's grace), so the number moves without the server re-sending.
  Timer? _clock;

  bool _busy = false;

  /// The staged move is on its way, and then landed: the Send button's two
  /// last faces before the screen closes back to the chat.
  bool _sendingMove = false;
  bool _moveSent = false;

  /// Whether this screen has already offered the first-play guide.
  bool _introTried = false;

  HowToPlayGuide _guideFor(ChatMatch m) => chatGuide(
    AppLocalizations.of(context),
    m.game,
    modes: [m.mode == MatchMode.async ? PlayStyle.turns : PlayStyle.live],
    group: m.watching > 0 || m.seats.length > 2,
    voice: m.options.voice,
  );

  void _openGuide() {
    final m = _c.match;
    if (m == null) return;
    showHowToPlay(context, _guideFor(m));
  }

  /// The first time someone sits down at a game they have never played here,
  /// the guide comes up by itself. Watchers are left alone.
  void _maybeIntro(ChatMatch m) {
    if (_introTried || !m.isSeated(widget.userId) || !m.status.isOpen) return;
    _introTried = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showHowToPlayOnce(context, _guideFor(m));
    });
  }

  @override
  void initState() {
    super.initState();
    _lastStatus = widget.initial?.status;
    _c.addListener(_onChange);
    _c.start();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _clock?.cancel();
    _c
      ..removeListener(_onChange)
      ..dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    final m = _c.serverMatch;
    if (m != null) {
      _maybeIntro(m);
      if (_lastStatus == MatchStatus.lobby && m.status == MatchStatus.active) {
        _startCountdown();
      }
      if (_lastStatus != null &&
          _lastStatus!.isOpen &&
          !m.status.isOpen &&
          m.isSeated(widget.userId)) {
        HapticFeedback.mediumImpact();
      }
      _lastStatus = m.status;
      final ticking = m.status == MatchStatus.paused;
      if (ticking && _clock == null) {
        _clock = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      } else if (!ticking) {
        _clock?.cancel();
        _clock = null;
      }
    }
    if (_c.rejectionCount != _seenRejections) {
      _seenRejections = _c.rejectionCount;
      _sayRejection(_c.lastRejection);
    }
    setState(() {});
  }

  void _startCountdown() {
    final calm = MotionScope.of(context).calm;
    if (calm) return;
    _countdownTimer?.cancel();
    setState(() => _countdown = 3);
    HapticFeedback.lightImpact();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 800), (t) {
      if (!mounted) return t.cancel();
      final next = (_countdown ?? 0) - 1;
      if (next < 0) {
        t.cancel();
        setState(() => _countdown = null);
        return;
      }
      next == 0
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.lightImpact();
      setState(() => _countdown = next);
    });
  }

  void _sayRejection(MoveRejection? why) {
    if (why == null) return;
    final l10n = AppLocalizations.of(context);
    HapticFeedback.heavyImpact();
    final toast = AppToast.of(context);
    switch (why) {
      case MoveRejection.stale:
        toast.show(sentenceCaseOf(context, l10n.chatGameStale));
      case MoveRejection.paused:
        toast.show(sentenceCaseOf(context, l10n.chatGameStatusPaused));
      case MoveRejection.tooLate:
        toast.show(sentenceCaseOf(context, l10n.chatGameErrTooLate));
      case MoveRejection.badClue:
        toast.error(sentenceCaseOf(context, l10n.chatGameErrBadClue));
      case MoveRejection.badGuess:
        toast.error(sentenceCaseOf(context, l10n.chatGameErrBadGuess));
      case MoveRejection.notSolved:
        toast.error(sentenceCaseOf(context, l10n.chatGameErrNotSolved));
      case MoveRejection.tooManyGames:
        toast.show(sentenceCaseOf(context, l10n.chatGameErrTooMany));
      case MoveRejection.ephemeral:
        toast.show(sentenceCaseOf(context, l10n.chatGameErrEphemeral));
      case MoveRejection.illegal:
      case MoveRejection.network:
        toast.error(sentenceCaseOf(context, l10n.chatGameMoveFailed));
    }
  }

  /// Runs one table action (join, ready, resign, …) with a busy guard and a
  /// toast for a refusal worth explaining.
  Future<void> _act(Future<void> Function() call) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await call();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final code = matchErrorCode(e);
      AppToast.of(context).show(
        sentenceCaseOf(
          context,
          switch (code) {
            'TOO_SOON' => l10n.chatGameNudged,
            'FULL' => l10n.chatGameErrGeneric,
            _ => l10n.chatGameErrGeneric,
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmResign() async {
    final l10n = AppLocalizations.of(context);
    // A party game goes on without whoever leaves, so it is "leave", not
    // "resign": nobody is conceding to anybody.
    final party = _c.match?.party ?? false;
    final ok = await showIosActionSheet<bool>(
      context,
      title: sentenceCaseOf(
        context,
        party ? l10n.chatGamePartyLeaveConfirm : l10n.chatGameResignConfirm,
      ),
      message: sentenceCaseOf(
        context,
        party ? l10n.chatGamePartyLeaveBody : l10n.chatGameResignBody,
      ),
      actions: [
        IosSheetAction(
          label: sentenceCaseOf(
            context,
            party ? l10n.chatGameLeave : l10n.chatGameResign,
          ),
          value: true,
          destructive: true,
        ),
      ],
      cancelLabel: sentenceCaseOf(context, l10n.chatGameCancel),
    );
    if (ok == true) {
      await _act(() => _api.resign(widget.userId, _c.matchId));
    }
  }

  Future<void> _askForSeat(ChatMatch m, int seat) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showIosActionSheet<bool>(
      context,
      title: m.seats[seat].name,
      actions: [
        IosSheetAction(
          label: sentenceCaseOf(context, l10n.chatGameAskSwap),
          value: true,
        ),
      ],
      cancelLabel: sentenceCaseOf(context, l10n.chatGameCancel),
    );
    if (ok == true) {
      HapticFeedback.selectionClick();
      await _act(() => _api.requestSeat(widget.userId, _c.matchId, seat));
    }
  }

  Future<void> _rematch(ChatMatch m) async {
    // Turn by turn: no card and no waiting game. The rematch opens as a draft
    // with the asker to move, and their first move creates it.
    if (m.mode == MatchMode.async && !m.party) {
      final mine = m.seatOf(widget.userId);
      if (mine < 0) return;
      final others = [
        for (final s in m.seats)
          if (s.userId != widget.userId) s,
      ];
      if (others.isEmpty) return;
      await openTurnDraft(
        context,
        userId: widget.userId,
        replace: true,
        draft: TurnDraft(
          roomId: m.roomId,
          game: m.game,
          seats: [
            MatchSeat(userId: widget.userId, name: m.seats[mine].name),
            MatchSeat(userId: others.first.userId, name: others.first.name),
          ],
          rematchOf: m.id,
        ),
      );
      return;
    }
    await _act(() async {
      await _api.rematch(
        userId: widget.userId,
        matchId: m.id,
        clientId: 'rm_${DateTime.now().microsecondsSinceEpoch}',
      );
      // The new card lands in the chat; back there is where it is.
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final m = _c.match;
    final me = widget.userId;

    final title = m == null
        ? ''
        : sentenceCaseOf(context, chatGameName(l10n, m.game));
    final header = <Widget>[
      _TopBar(
        match: m,
        viewerId: me,
        onHelp: m == null ? null : _openGuide,
        party: m?.party ?? false,
        onResign: m != null && !_c.isDraft && m.isSeated(me) &&
                m.status.isOpen && m.status != MatchStatus.lobby
            ? _confirmResign
            : null,
        onOfferDraw: m != null &&
                !_c.isDraft &&
                !m.party &&
                m.status == MatchStatus.active &&
                m.seats.length == 2 &&
                m.isSeated(me) &&
                m.drawOfferSeat == null
            ? () => _act(() => _api.offerDraw(me, _c.matchId))
            : null,
      ),
      const SizedBox(height: 10),
      Text(title, style: theme.displayLarge.copyWith(letterSpacing: 0.37)),
      const SizedBox(height: 4),
      if (m != null)
        Text(
          sentenceCaseOf(context, matchHeaderLine(l10n, m, me)),
          style: theme.bodySoft.copyWith(
            color: m.isTurnOf(me) ? theme.accent : theme.inkMuted,
            fontWeight: m.isTurnOf(me) ? FontWeight.w600 : null,
          ),
        ),
      const SizedBox(height: 10),
    ];

    final List<Widget> body;
    if (_c.gone) {
      body = [
        const SizedBox(height: 40),
        Text(
          sentenceCaseOf(context, l10n.chatGameGone),
          textAlign: TextAlign.center,
          style: theme.bodySoft.copyWith(color: theme.inkMuted),
        ),
      ];
    } else if (m == null) {
      body = [
        AspectRatio(
          aspectRatio: 1,
          child: GameBoardSkeleton(radius: theme.radiusMd),
        ),
      ];
    } else if (m.status == MatchStatus.lobby) {
      body = [
        _Lobby(
          match: m,
          viewerId: me,
          busy: _busy,
          onJoin: () => _act(() => _api.join(me, m.id)),
          onLeave: () => _act(() => _api.leave(me, m.id)),
          onReady: (ready) {
            HapticFeedback.selectionClick();
            _act(() => _api.setReady(me, m.id, ready));
          },
          onAskSeat: (seat) => _askForSeat(m, seat),
        ),
        ..._requestCards(m),
      ];
    } else if (m.party) {
      body = [
        _partyPlay(m),
        ..._requestCards(m),
        if (!m.status.isOpen) _Result(
          match: m,
          viewerId: me,
          busy: _busy,
          onRematch: m.isSeated(me) ? () => _rematch(m) : null,
        ),
        const SizedBox(height: 24),
      ];
    } else {
      body = [
        ..._play(m),
        ..._requestCards(m),
        if (!m.status.isOpen) _Result(
          match: m,
          viewerId: me,
          busy: _busy,
          onRematch: m.isSeated(me) ? () => _rematch(m) : null,
        ),
        const SizedBox(height: 24),
      ];
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: GameLayoutShell(
              header: header,
              board: body,
              boardWidth: 480,
              sidebar: _Sidebar(match: m, viewerId: me),
            ),
          ),
        ],
      ),
    );
  }

  /// Plates, the board and its covers, and the turn tools.
  List<Widget> _play(ChatMatch m) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final me = widget.userId;
    final mySeat = m.seatOf(me);
    final state = m.state;
    final scores = seatScores(m.game, state);
    // Two seats: the other player across the board, the viewer at the
    // bottom (a spectator sees seat one on top). More: one row above.
    final bottom = m.seats.length == 2 ? (mySeat >= 0 ? mySeat : 0) : -1;
    final tops = [
      for (var i = 0; i < m.seats.length; i++)
        if (i != bottom) i,
    ];
    Widget plate(int seat) => _Plate(
      match: m,
      seat: seat,
      viewerId: me,
      score: scores?[seat],
      onTap: !m.isSeated(me) &&
              m.mode == MatchMode.live &&
              m.status.isOpen &&
              !m.seats[seat].out
          ? () => _askForSeat(m, seat)
          : null,
    );
    // Turn by turn, seated: a move is staged on the board, then sent, and
    // the panel under the board says where things stand.
    final turns = m.mode == MatchMode.async &&
        m.status == MatchStatus.active &&
        mySeat >= 0;
    final staged = _c.stagedMove;
    final waiting = turns && staged == null && !m.isTurnOf(me);
    final now = DateTime.now();
    final canNudge = waiting &&
        m.lastMoveAt != null &&
        now.difference(m.lastMoveAt!) >= const Duration(hours: 12) &&
        (m.nudgedAt == null ||
            now.difference(m.nudgedAt!) >= const Duration(hours: 12));
    final timeLeft = m.mode == MatchMode.async && mySeat >= 0
        ? matchTimeLeft(l10n, m, now)
        : null;

    return [
      if (tops.length == 1)
        plate(tops.first)
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in tops)
              SizedBox(width: 220, child: plate(s)),
          ],
        ),
      const SizedBox(height: 10),
      AspectRatio(
        aspectRatio:
            state == null ? 1 : TurnBoard.aspectRatioOf(m.game, state),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (state != null)
              TurnBoard(
                gameId: m.game,
                state: state,
                mySeat: mySeat >= 0 ? mySeat : null,
                enabled: m.isTurnOf(me) && !_c.sending && _countdown == null,
                onMove: turns ? _stage : _c.play,
                lastMove: m.lastMove,
                seatLabels: [
                  for (final s in m.seats)
                    s.name.isEmpty ? '?' : s.name.characters.first.toUpperCase(),
                ],
              ),
            IgnorePointer(
              ignoring: m.status != MatchStatus.paused,
              child: AnimatedOpacity(
                opacity: m.status == MatchStatus.paused ? 1 : 0,
                duration: MotionScope.of(context).d(theme.motionFast),
                child: m.status == MatchStatus.paused
                    ? _PauseCover(
                        match: m,
                        viewerId: me,
                        onLeave: () => Navigator.of(context).maybePop(),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            if (_countdown != null)
              _Countdown(value: _countdown!, label: l10n.chatGameGo),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (bottom >= 0) plate(bottom),
      if (turns) ...[
        const SizedBox(height: 14),
        TurnPanel(
          match: m,
          viewerId: me,
          staged: staged != null,
          notation: staged == null ? null : moveNotation(l10n, m.game, staged),
          timeLeft: timeLeft,
          canNudge: canNudge,
          sending: _sendingMove,
          sent: _moveSent,
          onUndo: () {
            HapticFeedback.selectionClick();
            _c.unstage();
          },
          onSend: _sendStaged,
          onNudge: _busy
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  _act(() => _api.nudge(me, m.id));
                },
        ),
      ] else if (timeLeft != null) ...[
        const SizedBox(height: 8),
        Text(
          sentenceCaseOf(context, timeLeft),
          textAlign: TextAlign.center,
          style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
        ),
      ],
    ];
  }

  /// A turn by turn move, put on the board but not sent.
  void _stage(String move) {
    HapticFeedback.selectionClick();
    _c.stage(move);
  }

  /// Sends the staged move, which posts it into the chat as a bubble. Then,
  /// unless the move earned another turn or ended the game, back to the
  /// chat: the move is a message now, and the chat is where the answer will
  /// arrive.
  Future<void> _sendStaged() async {
    final m = _c.match;
    final state = m?.state;
    if (m == null || state == null || _sendingMove || _moveSent) return;
    final game = turnGameFor(m.game);
    final mySeat = m.seatOf(widget.userId);
    final again = game != null &&
        game.outcomeEncoded(state) == null &&
        game.toMoveEncoded(state) == mySeat;
    final over = game != null && game.outcomeEncoded(state) != null;
    HapticFeedback.mediumImpact();
    setState(() => _sendingMove = true);
    final ok = await _c.sendStaged();
    if (!mounted) return;
    if (!ok) {
      setState(() => _sendingMove = false);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    if (again || over) {
      setState(() => _sendingMove = false);
      if (again) {
        HapticFeedback.lightImpact();
        toast.show(sentenceCaseOf(context, l10n.chatGameMvAgain));
      }
      return;
    }
    setState(() => _moveSent = true);
    HapticFeedback.lightImpact();
    final calm = MotionScope.of(context).calm;
    final sentLine = sentenceCaseOf(context, l10n.chatGameMvSentToast);
    // A beat on the tick, so the send reads as done before the screen goes.
    await Future<void>.delayed(Duration(milliseconds: calm ? 0 : 420));
    if (!mounted) return;
    Navigator.of(context).maybePop();
    toast.show(sentLine);
  }

  /// A party game's table, under the same pause cover and 3-2-1 a turn
  /// game's board wears.
  Widget _partyPlay(ChatMatch m) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final paused = m.status == MatchStatus.paused;
    return Stack(
      children: [
        PartyTable(
          match: m,
          controller: _c,
          viewerId: widget.userId,
          enabled: _countdown == null && !paused,
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !paused,
            child: AnimatedOpacity(
              opacity: paused ? 1 : 0,
              duration: MotionScope.of(context).d(theme.motionFast),
              child: paused
                  ? _PauseCover(
                      match: m,
                      viewerId: widget.userId,
                      onLeave: () => Navigator.of(context).maybePop(),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        if (_countdown != null)
          Positioned.fill(
            child: _Countdown(value: _countdown!, label: l10n.chatGameGo),
          ),
      ],
    );
  }

  /// A seat request or a draw offer that the viewer has to answer, or one
  /// of their own that is pending.
  List<Widget> _requestCards(ChatMatch m) {
    final l10n = AppLocalizations.of(context);
    final me = widget.userId;
    final cards = <Widget>[];
    final req = m.seatRequest;
    if (req != null && m.status.isOpen) {
      final holder = req.seat < m.seats.length ? m.seats[req.seat] : null;
      if (holder?.userId == me) {
        cards.add(_AskCard(
          roomId: m.roomId,
          userId: req.userId,
          name: req.name,
          text: l10n.chatGameSwapRequest(req.name),
          decline: l10n.chatGameDecline,
          accept: l10n.chatGameSwap,
          onDecline: () =>
              _act(() => _api.answerSeatRequest(me, m.id, false)),
          onAccept: () {
            HapticFeedback.selectionClick();
            _act(() => _api.answerSeatRequest(me, m.id, true));
          },
        ));
      } else if (req.userId == me && holder != null) {
        cards.add(_AskCard(
          roomId: m.roomId,
          userId: holder.userId,
          name: holder.name,
          text: l10n.chatGameSwapAsked(holder.name),
          decline: l10n.chatGameCancel,
          onDecline: () => _act(() => _api.cancelSeatRequest(me, m.id)),
        ));
      }
    }
    if (m.drawOfferedTo(me)) {
      final from = m.seats[m.drawOfferSeat!];
      cards.add(_AskCard(
        roomId: m.roomId,
        userId: from.userId,
        name: from.name,
        text: l10n.chatGameDrawOfferFrom(from.name),
        decline: l10n.chatGameDecline,
        accept: l10n.chatGameAccept,
        onDecline: () => _act(() => _api.answerDraw(me, m.id, false)),
        onAccept: () => _act(() => _api.answerDraw(me, m.id, true)),
      ));
    } else if (m.drawOfferSeat != null &&
        m.drawOfferSeq == m.seq &&
        m.seatOf(me) == m.drawOfferSeat) {
      cards.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          sentenceCaseOf(context, l10n.chatGameDrawOffered),
          textAlign: TextAlign.center,
          style: groupedMetaStyle(ThemeScope.of(context)),
        ),
      ));
    }
    return [
      for (final c in cards) ...[const SizedBox(height: 12), SheetRise(child: c)],
    ];
  }
}

/// The scores the plates show, where a game has one: discs on a Reversi
/// board, boxes in Dots and Boxes, pieces left in checkers. Read straight off
/// the encoded state, which is cheaper than decoding it on every rebuild.
List<int>? seatScores(String game, String? state) {
  if (state == null) return null;
  switch (game) {
    case 'reversi':
      final cells = state.split('/').first;
      return ['B'.allMatches(cells).length, 'W'.allMatches(cells).length];
    case 'checkers':
      final board = state.split('|').first;
      var dark = 0;
      var light = 0;
      for (final ch in board.split('')) {
        if (ch == 'b' || ch == 'B') dark++;
        if (ch == 'w' || ch == 'W') light++;
      }
      return [dark, light];
    case 'dots':
      final parts = state.split('|');
      if (parts.length < 5) return null;
      return [for (final s in parts.last.split(',')) int.tryParse(s) ?? 0];
    default:
      return null;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.match,
    required this.viewerId,
    this.party = false,
    this.onResign,
    this.onOfferDraw,
    this.onHelp,
  });

  final ChatMatch? match;
  final String viewerId;

  /// Opens the game's how-to-play guide.
  final VoidCallback? onHelp;

  /// A party game: the menu says "Leave game", not "Resign".
  final bool party;
  final VoidCallback? onResign;
  final VoidCallback? onOfferDraw;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final m = match;
    final mine = m != null && m.isTurnOf(viewerId);
    final pill = m == null
        ? null
        : switch (m.status) {
            MatchStatus.lobby => l10n.chatGameStatusWaiting,
            MatchStatus.paused => l10n.chatGameStatusPaused,
            MatchStatus.active => mine
                ? l10n.chatGameYourMove
                : !m.isSeated(viewerId)
                ? l10n.chatGameWatchingLabel
                : l10n.chatGameStatusPlaying,
            MatchStatus.finished => l10n.chatGameStatusFinished,
            MatchStatus.abandoned => l10n.chatGameStatusEnded,
          };
    final seat = m?.turnSeat;
    final wash = mine && seat != null
        ? SeatPalette(theme, gameId: m.game).wash(seat)
        : theme.ink.withValues(alpha: 0.07);
    final hasMenu = onResign != null || onOfferDraw != null;
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (pill != null)
            AnimatedContainer(
              duration: MotionScope.of(context).d(theme.motionFast),
              curve: theme.motionCurve,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: wash,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                sentenceCaseOf(context, pill),
                style: theme.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: mine ? theme.ink : theme.inkSoft,
                ),
              ),
            ),
          Row(
            children: [
              const GlassBackButton(),
              const Spacer(),
              if (onHelp != null) HowToPlayButton(onTap: onHelp!),
              if (onHelp != null && hasMenu) const SizedBox(width: 8),
              if (hasMenu)
                GlassIconButton(
                  icon: CupertinoIcons.ellipsis,
                  iconSize: 18,
                  semanticLabel: party ? l10n.chatGameLeave : l10n.chatGameResign,
                  onTap: () async {
                    final choice = await showIosActionSheet<String>(
                      context,
                      actions: [
                        if (onOfferDraw != null)
                          IosSheetAction(
                            label: sentenceCaseOf(context, l10n.chatGameOfferDraw),
                            value: 'draw',
                          ),
                        if (onResign != null)
                          IosSheetAction(
                            label: sentenceCaseOf(
                              context,
                              party ? l10n.chatGameLeave : l10n.chatGameResign,
                            ),
                            value: 'resign',
                            destructive: true,
                          ),
                      ],
                      cancelLabel: sentenceCaseOf(context, l10n.chatGameCancel),
                    );
                    if (choice == 'draw') onOfferDraw?.call();
                    if (choice == 'resign') onResign?.call();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One player at the table: face, name, score, and whose move it is.
class _Plate extends StatelessWidget {
  const _Plate({
    required this.match,
    required this.seat,
    required this.viewerId,
    this.score,
    this.onTap,
  });

  final ChatMatch match;
  final int seat;
  final String viewerId;
  final int? score;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final s = match.seats[seat];
    final palette = SeatPalette(theme, gameId: match.game);
    final turn = match.status == MatchStatus.active && match.turnSeat == seat;
    final name = seatName(l10n, match, seat, viewerId);
    final note = s.out
        ? l10n.chatGameReasonLeft(name)
        : s.away
        ? l10n.chatGameStatusPaused
        : turn
        ? (s.userId == viewerId ? l10n.chatGameYourMove : l10n.chatGameTurnOf(name))
        : null;
    final plate = AnimatedContainer(
      duration: MotionScope.of(context).d(theme.motionFast),
      curve: theme.motionCurve,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
        border: Border.all(
          color: turn ? palette.fill(seat) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: s.away || s.out ? 0.45 : 1,
            child: MatchFace(
              roomId: match.roomId,
              userId: s.userId,
              name: s.name,
              size: 34,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.fill(seat),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: groupedTitleStyle(theme).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (note != null)
                  Text(
                    sentenceCaseOf(context, note),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: groupedMetaStyle(theme).copyWith(
                      color: turn ? theme.accent : theme.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (score != null)
            Text(
              '$score',
              style: groupedTitleStyle(theme).copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
    final tap = onTap;
    return Semantics(
      label: [name, ?note, if (score != null) '$score'].join(', '),
      button: tap != null,
      child: ExcludeSemantics(
        child: tap == null
            ? plate
            : SpringPress(onTap: tap, scale: PressSpec.scaleSmall, child: plate),
      ),
    );
  }
}

class _PauseCover extends StatelessWidget {
  const _PauseCover({
    required this.match,
    required this.viewerId,
    required this.onLeave,
  });

  final ChatMatch match;
  final String viewerId;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final away = [
      for (var i = 0; i < match.seats.length; i++)
        if (match.seats[i].away && !match.seats[i].out) i,
    ];
    final iAmAway = away.any((i) => match.seats[i].userId == viewerId);
    final left = match.deadlineAt?.difference(DateTime.now());
    final secs = left?.inSeconds.clamp(0, 600);
    final clock = secs == null
        ? null
        : '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: groupedFill(theme).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (away.length == 1)
              Opacity(
                opacity: 0.6,
                child: MatchFace(
                  roomId: match.roomId,
                  userId: match.seats[away.first].userId,
                  name: match.seats[away.first].name,
                  size: 64,
                ),
              )
            else
              Icon(CupertinoIcons.pause_fill, color: theme.accent, size: 34),
            const SizedBox(height: 14),
            Text(
              sentenceCaseOf(context, matchStatusLine(l10n, match, viewerId)),
              textAlign: TextAlign.center,
              style: theme.displaySmall,
            ),
            const SizedBox(height: 6),
            Text(
              sentenceCaseOf(
                context,
                iAmAway ? l10n.chatGamePausedYou : l10n.chatGamePausedBody,
              ),
              textAlign: TextAlign.center,
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
            ),
            if (clock != null) ...[
              const SizedBox(height: 12),
              Text(
                clock,
                style: theme.displaySmall.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: theme.inkSoft,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextLinkButton(
              label: sentenceCaseOf(context, l10n.chatGameLeave),
              onTap: onLeave,
              muted: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: theme.background.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, a) => ScaleTransition(
            scale: Tween(begin: 1.4, end: 1.0).animate(
              CurvedAnimation(parent: a, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: a, child: child),
          ),
          child: Text(
            value == 0 ? label : '$value',
            key: ValueKey(value),
            style: theme.displayLarge.copyWith(
              fontSize: 72,
              fontWeight: FontWeight.w800,
              color: theme.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// The lobby: seats, ready, and the way to the table for anyone watching.
class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.match,
    required this.viewerId,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
    required this.onReady,
    required this.onAskSeat,
  });

  final ChatMatch match;
  final String viewerId;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final ValueChanged<bool> onReady;
  final ValueChanged<int> onAskSeat;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = SeatPalette(theme, gameId: match.game);
    final capacity = maxSeatsOf(match.game);
    final mySeat = match.seatOf(viewerId);
    final ready = mySeat >= 0 && match.seats[mySeat].ready;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedHeader(l10n.chatGameSeatsLabel),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < capacity; i++)
              SizedBox(
                width: capacity > 2 ? 104 : 150,
                child: i < match.seats.length
                    ? _SeatCard(
                        match: match,
                        seat: i,
                        viewerId: viewerId,
                        ring: palette.fill(i),
                        onTap: mySeat < 0 &&
                                match.seats.length >= capacity
                            ? () => onAskSeat(i)
                            : null,
                      )
                    : _EmptySeat(onTap: mySeat < 0 && !busy ? onJoin : null),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          sentenceCaseOf(context, matchStatusLine(l10n, match, viewerId)),
          textAlign: TextAlign.center,
          style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
        ),
        if (match.watching > 0) ...[
          const SizedBox(height: 4),
          Text(
            l10n.chatGameWatchingCount(match.watching),
            textAlign: TextAlign.center,
            style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
          ),
        ],
        const SizedBox(height: 18),
        if (mySeat >= 0) ...[
          SheetActionButton(
            label: sentenceCaseOf(
              context,
              ready ? l10n.chatGameUnready : l10n.chatGameImReady,
            ),
            tonal: ready,
            busy: busy,
            onTap: () => onReady(!ready),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextLinkButton(
              label: sentenceCaseOf(context, l10n.chatGameLeaveSeat),
              onTap: busy ? null : onLeave,
              muted: true,
            ),
          ),
        ] else if (match.seats.length < capacity)
          SheetActionButton(
            label: sentenceCaseOf(context, l10n.chatGameJoin),
            busy: busy,
            onTap: onJoin,
          ),
      ],
    );
  }
}

class _SeatCard extends StatelessWidget {
  const _SeatCard({
    required this.match,
    required this.seat,
    required this.viewerId,
    required this.ring,
    this.onTap,
  });

  final ChatMatch match;
  final int seat;
  final String viewerId;
  final Color ring;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final s = match.seats[seat];
    final name = seatName(l10n, match, seat, viewerId);
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 3),
            ),
            child: MatchFace(
              roomId: match.roomId,
              userId: s.userId,
              name: s.name,
              size: 60,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: groupedTitleStyle(theme).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          AnimatedSwitcher(
            duration: MotionScope.of(context).d(theme.motionFast),
            child: Text(
              sentenceCaseOf(
                context,
                s.ready ? l10n.chatGameReady : l10n.chatGameNotReady,
              ),
              key: ValueKey(s.ready),
              style: groupedMetaStyle(theme).copyWith(
                color: s.ready ? theme.success : theme.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    return tap == null
        ? card
        : SpringPress(onTap: tap, scale: PressSpec.scaleSmall, child: card);
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      decoration: BoxDecoration(
        color: groupedFill(theme).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.ink.withValues(alpha: 0.06),
            ),
            child: Icon(CupertinoIcons.plus, size: 26, color: theme.inkMuted),
          ),
          const SizedBox(height: 10),
          Text(
            sentenceCaseOf(context, l10n.chatGameOpenSeat),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: groupedTitleStyle(theme).copyWith(color: theme.inkMuted),
          ),
          const SizedBox(height: 2),
          Text(
            sentenceCaseOf(context, l10n.chatGameTakeSeat),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: groupedMetaStyle(theme).copyWith(
              color: onTap == null ? theme.inkMuted : theme.accent,
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    return tap == null
        ? card
        : SpringPress(onTap: tap, scale: PressSpec.scaleSmall, child: card);
  }
}

/// A question somebody put to the viewer — "can I have your seat", "draw?" —
/// or the viewer's own still standing.
class _AskCard extends StatelessWidget {
  const _AskCard({
    required this.roomId,
    required this.userId,
    required this.name,
    required this.text,
    required this.decline,
    required this.onDecline,
    this.accept,
    this.onAccept,
  });

  final String roomId;
  final String userId;
  final String name;
  final String text;
  final String decline;
  final VoidCallback onDecline;
  final String? accept;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Row(
        children: [
          MatchFace(roomId: roomId, userId: userId, name: name, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sentenceCaseOf(context, text),
              style: groupedTitleStyle(theme),
            ),
          ),
          const SizedBox(width: 8),
          RowPillButton(label: decline, onTap: onDecline),
          if (accept != null && onAccept != null) ...[
            const SizedBox(width: 8),
            RowPillButton(label: accept!, onTap: onAccept, filled: true),
          ],
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.match,
    required this.viewerId,
    required this.busy,
    this.onRematch,
  });

  final ChatMatch match;
  final String viewerId;
  final bool busy;
  final VoidCallback? onRematch;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final mySeat = match.seatOf(viewerId);
    final won = mySeat >= 0 && match.seatWon(mySeat);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SheetRise(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          decoration: BoxDecoration(
            color: groupedFill(theme),
            borderRadius: BorderRadius.circular(groupedRadius(theme)),
          ),
          child: Column(
            children: [
              Icon(
                match.draw
                    ? CupertinoIcons.equal_circle_fill
                    : won
                    ? CupertinoIcons.star_circle_fill
                    : CupertinoIcons.flag_circle_fill,
                size: 40,
                color: won ? theme.success : theme.inkSoft,
              ),
              const SizedBox(height: 10),
              Text(
                sentenceCaseOf(context, matchResultLine(l10n, match, viewerId)),
                textAlign: TextAlign.center,
                style: theme.displaySmall,
              ),
              const SizedBox(height: 6),
              Text(
                sentenceCaseOf(context, l10n.chatGameNotRanked),
                textAlign: TextAlign.center,
                style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
              ),
              if (onRematch != null) ...[
                const SizedBox(height: 14),
                SheetActionButton(
                  label: sentenceCaseOf(context, l10n.chatGameRematch),
                  busy: busy,
                  onTap: onRematch,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Beside the board on a wide window, under it on a phone: who is watching,
/// and the one line that says this is not a ranked game.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.match, required this.viewerId});

  final ChatMatch? match;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final m = match;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m != null && m.watching > 0 && m.status.isOpen) ...[
            Text(
              l10n.chatGameWatchingCount(m.watching),
              style: groupedMetaStyle(theme).copyWith(color: theme.inkMuted),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.info_circle,
                size: 14,
                color: theme.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sentenceCaseOf(context, l10n.chatGameNotRanked),
                  style: groupedFooterStyle(theme),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
