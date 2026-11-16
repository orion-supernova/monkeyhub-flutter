import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/matches_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_match.dart';
import '../../push/device_identity.dart';
import '../../data/settings_store.dart';
import '../../widgets/glass_buttons.dart';
import '../../widgets/liquid_glass.dart' show GlassTone;
import '../../widgets/spring_press.dart';
import '../core/core.dart';
import '../net/fight_link.dart';
import '../net/rollback_session.dart';
import 'art/stages/stages.dart';
import 'fight_character_grid.dart';
import 'fight_screen.dart';
import 'fight_stage_picker.dart';
import 'fighter_portrait.dart';

/// Opens the online fight for a `fight` chat match (lobby, connect, fight,
/// result). The one door every chat entry point uses: the start sheet after
/// `matches.create`, the game bubble, the active-games banner, a push.
Future<void> openFightMatch(BuildContext context, {required ChatMatch match, required String userId}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => FightOnlineScreen(matchId: match.id, userId: userId, initial: match),
    ),
  );
}

/// The same door for a caller that has only the match id (a push tap, a bubble
/// whose match row has not loaded yet).
Future<void> openFightMatchById(BuildContext context, {required String matchId, required String userId}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => FightOnlineScreen(matchId: matchId, userId: userId),
    ),
  );
}

/// The fight's seed, the same on both phones without a word exchanged: a
/// hash of the match id (FNV-1a, 30 bits so it is a small int everywhere).
@visibleForTesting
int fightSeedFor(String matchId) {
  var h = 0x811c9dc5;
  for (final c in matchId.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x3fffffff;
}

/// What both phones report at the end, identical on two honest phones: the
/// outcome and the numbers that decided it, all frozen once the match is over.
@visibleForTesting
int fightResultChecksum(FightState s) {
  var h = 0x811c9dc5;
  void mix(int v) {
    h ^= v & 0xffff;
    h = (h * 0x01000193) & 0xffffffff;
    h ^= (v >> 16) & 0xffff;
    h = (h * 0x01000193) & 0xffffffff;
  }

  mix(s.matchWinner);
  mix(s.round);
  for (final p in s.p) {
    mix(p.wins);
    mix(p.health);
  }
  return h;
}

/// The online fight's driver: a [RollbackSession] over a [FightLink].
///
/// Start: seat 0 pings seat 1 a few times over the reliable channel, then
/// sends `go` and starts half a round trip later, so both phones begin their
/// frame 0 at about the same moment. The session's time sync absorbs the rest.
///
/// End: once the match is over on a CONFIRMED frame (no prediction left that
/// a late packet could undo), the result is reported through `partyAct`.
/// Silence from the peer for [lostAfter] before that counts as the peer
/// gone: this phone reports itself the winner, and if the other phone (whose
/// network was the one that failed) reports the same of itself later, the
/// server calls it a disputed draw.
class OnlineFightDriver implements FightDriver {
  OnlineFightDriver({
    required this.link,
    required this.localIndex,
    required int seed,
    required this.report,
    required this.lostText,
    required this.pingText,
    List<CharacterDef>? chars,
    Duration startDelay = Duration.zero,
  }) {
    final c = chars ?? [roster[0], roster[0]];
    session = RollbackSession(
      localIndex: localIndex,
      initial: FightState.initial(seed: seed, p1: c[0], p2: c[1]),
      send: link.sendInput,
      onDesync: (frame, mine, theirs) {
        debugPrint('OnlineFightDriver: desync at $frame ($mine vs $theirs)');
        _desynced = true;
      },
    );
    link.onInput = session.receive;
    link.onControl = _control;
    // Seat 0 starts the handshake once the VS reveal has played on both.
    if (localIndex == 0) unawaited(Future<void>.delayed(startDelay, _pingThenGo));
  }

  final FightPipe link;
  @override
  final int localIndex;
  final Future<bool> Function(String action) report;
  final String lostText;
  final String Function(int ms) pingText;
  late final RollbackSession session;

  static const Duration lostAfter = Duration(seconds: 6);
  static const Duration warnAfter = Duration(seconds: 2);

  bool _started = false, _reported = false, _lost = false, _desynced = false;
  DateTime? _startAt;
  int? _overFrame;
  final List<int> _rtts = [];
  final Map<int, DateTime> _pings = {};

  @override
  final ValueNotifier<String?> notice = ValueNotifier(null);

  @override
  FightState get state => session.state;
  @override
  bool get offline => false;
  @override
  bool get finished => _reported || _lost;
  bool get started => _started;

  @override
  void restart() {}

  Future<void> _pingThenGo() async {
    for (var i = 0; i < 6 && !_started; i++) {
      _pings[i] = DateTime.now();
      link.sendControl({'t': 'ping', 'i': i});
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _rtts.sort();
    final rtt = _rtts.isEmpty ? 100 : _rtts[_rtts.length ~/ 2];
    link.sendControl({'t': 'go', 'rtt': rtt});
    _showPing(rtt);
    _startAt = DateTime.now().add(Duration(milliseconds: rtt ~/ 2));
  }

  void _control(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'ping':
        link.sendControl({'t': 'pong', 'i': m['i']});
      case 'pong':
        final sent = _pings.remove(m['i']);
        if (sent != null) _rtts.add(DateTime.now().difference(sent).inMilliseconds);
      case 'go':
        _started = true;
        _showPing((m['rtt'] as num?)?.toInt() ?? 0);
      case 'bye':
        if (!finished) _peerGone();
    }
  }

  void _showPing(int ms) {
    final text = pingText(ms);
    notice.value = text;
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (notice.value == text) notice.value = null;
    });
  }

  void _peerGone() {
    if (_lost || _reported) return;
    _lost = true;
    notice.value = lostText;
    // The peer is gone before the end: claim the win. If they come back and
    // claim theirs, the server settles it as a disputed draw.
    unawaited(report('result:$localIndex:0'));
  }

  @override
  void step(int localInput) {
    if (finished) {
      // Keep our last inputs flowing so the peer can confirm the end too.
      session.pump();
      return;
    }
    if (!_started) {
      final at = _startAt;
      if (at == null || DateTime.now().isBefore(at)) return;
      _started = true;
    }
    session.tick(localInput);

    final silent = DateTime.now().difference(link.lastHeard);
    final linkDown = link.state.value == FightLinkState.failed || link.state.value == FightLinkState.closed;
    if (silent > lostAfter || linkDown) {
      _peerGone();
      return;
    }
    if (silent > warnAfter) {
      notice.value = lostText;
    } else if (notice.value == lostText) {
      notice.value = null;
    }

    final s = session.state;
    if (s.phase != Phase.over) {
      _overFrame = null; // a rollback can take an end back
      return;
    }
    _overFrame ??= s.frame;
    if (!_reported && session.confirmedFrame > _overFrame! + 1) {
      _reported = true;
      final w = s.matchWinner == 0 || s.matchWinner == 1 ? s.matchWinner : -1;
      // A desynced pair would report different checksums anyway; send 0 so
      // the server's disagreement path is certain.
      final cs = _desynced ? 0 : fightResultChecksum(s);
      unawaited(report('result:$w:$cs'));
    }
  }
}

enum _Phase { lobby, connecting, failed, fighting, over }

class FightOnlineScreen extends StatefulWidget {
  const FightOnlineScreen({super.key, required this.matchId, required this.userId, this.initial});

  final String matchId, userId;
  final ChatMatch? initial;

  @override
  State<FightOnlineScreen> createState() => _FightOnlineScreenState();
}

class _FightOnlineScreenState extends State<FightOnlineScreen> {
  late final MatchController _mc;
  FightLink? _link;
  OnlineFightDriver? _driver;
  bool _busy = false, _connectFailed = false;

  /// This player's fighter (from settings, changeable on their card in the
  /// lobby) and the opponent's, learned over the link when it opens. Picks
  /// are swapped phone to phone, never through the server, and both are
  /// revealed together on the VS screen.
  int _myPick = fightCharOf(SettingsStore.instance.fightChar);
  int? _peerPick;

  /// The place to fight in is the host's (seat 0) choice. The host picks in the
  /// lobby ([_stagePick], possibly Random) and sends the resolved id with its
  /// fighter pick; the guest takes whatever arrives, and a build from before
  /// stages (no `s` in the pick) plays the rooftop.
  int _stagePick = SettingsStore.instance.fightStage;
  int _stage = 0;
  Timer? _peerPickTimeout;
  DateTime? _revealUntil;
  static const Duration _reveal = Duration(milliseconds: 2400);

  @override
  void initState() {
    super.initState();
    _mc = MatchController(matchId: widget.matchId, userId: widget.userId, initial: widget.initial);
    _mc.addListener(_onMatch);
    SettingsStore.instance.addListener(_onSettings);
    unawaited(_mc.start());
    WidgetsBinding.instance.addPostFrameCallback((_) => _onMatch());
  }

  ChatMatch? get _m => _mc.match;

  void _onSettings() {
    if (mounted) setState(() {});
  }

  int get _mySeat => _m?.seatOf(widget.userId) ?? -1;

  void _onMatch() {
    final m = _m;
    if (m == null || !mounted) return;
    final live = m.status == MatchStatus.active || m.status == MatchStatus.paused;
    if (live && _mySeat >= 0 && _link == null && !_connectFailed && m.seats.length == 2) {
      unawaited(_connect(m));
    }
    setState(() {});
  }

  Future<void> _connect(ChatMatch m) async {
    final seat = _mySeat;
    final peer = m.seats[1 - seat];
    final link = _link = FightLink(
      matchId: widget.matchId,
      userId: widget.userId,
      peerUserId: peer.userId,
      offerer: seat == 0,
      deviceId: await DeviceIdentity.ensure(),
    );
    if (!mounted) return;
    link.state.addListener(_onLink);
    await link.start();
  }

  void _onLink() {
    final link = _link;
    if (link == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    switch (link.state.value) {
      case FightLinkState.open when _driver == null && _peerPickTimeout == null:
        HapticFeedback.mediumImpact();
        final host = _mySeat == 0;
        if (host) _stage = fightStageResolve(_stagePick);
        link.onControl = (m) {
          if (m['t'] == 'pick' && _peerPick == null) {
            _peerPick = fightCharOf((m['c'] as num?)?.toInt() ?? 0);
            if (!host) _stage = fightStageOf((m['s'] as num?)?.toInt() ?? 0);
            _beginFight(l10n);
          }
        };
        link.sendControl({'t': 'pick', 'c': _myPick, if (host) 's': _stage});
        // A build from before fighter picks never sends one: it plays KAI.
        _peerPickTimeout = Timer(const Duration(seconds: 3), () {
          if (_peerPick != null) return;
          _peerPick = 0;
          _beginFight(l10n);
        });
      case FightLinkState.failed when _driver == null:
        _connectFailed = true;
      default:
        break;
    }
    setState(() {});
  }

  void _beginFight(AppLocalizations l10n) {
    final link = _link, peer = _peerPick;
    if (link == null || peer == null || _driver != null || !mounted) return;
    _peerPickTimeout?.cancel();
    final seat = _mySeat;
    final picks = seat == 0 ? [_myPick, peer] : [peer, _myPick];
    _revealUntil = DateTime.now().add(_reveal);
    _driver = OnlineFightDriver(
      link: link,
      localIndex: seat,
      seed: fightSeedFor(widget.matchId),
      report: _mc.act,
      lostText: l10n.fightOnlineLost,
      pingText: l10n.fightOnlinePing,
      chars: [roster[picks[0]], roster[picks[1]]],
      startDelay: _reveal,
    );
    HapticFeedback.heavyImpact();
    Timer(_reveal, () {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  void _pickStage(int id) {
    setState(() => _stagePick = id);
    unawaited(SettingsStore.instance.setFightStage(id));
  }

  Future<void> _retry() async {
    final old = _link;
    _link = null;
    _driver = null;
    _peerPick = null;
    _stage = 0;
    _peerPickTimeout?.cancel();
    _peerPickTimeout = null;
    _revealUntil = null;
    old?.state.removeListener(_onLink);
    await old?.close();
    if (!mounted) return;
    setState(() => _connectFailed = false);
    _onMatch();
  }

  _Phase get _phase {
    final m = _m;
    if (_driver != null) return _Phase.fighting; // the VS reveal
    if (m == null || m.status == MatchStatus.lobby) return _Phase.lobby;
    if (!m.status.isOpen) return _Phase.over;
    if (_connectFailed) return _Phase.failed;
    return _Phase.connecting;
  }

  Future<void> _run(Future<void> Function() f) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      debugPrint('FightOnlineScreen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _join() => _run(() => MatchesStore.instance.api.join(widget.userId, widget.matchId));

  void _toggleReady(bool ready) => _run(() {
    HapticFeedback.selectionClick();
    return MatchesStore.instance.api.setReady(widget.userId, widget.matchId, ready);
  });

  /// Leaving: in the lobby it gives the seat back; mid-fight before a result
  /// it forfeits (the server's `leave`); after the result it just closes.
  Future<void> _leave() async {
    final m = _m;
    final d = _driver;
    final reported = d != null && d.finished;
    if (m != null && m.status.isOpen && _mySeat >= 0 && !reported) {
      try {
        await MatchesStore.instance.api.leave(widget.userId, widget.matchId);
      } catch (e) {
        debugPrint('FightOnlineScreen: leave failed: $e');
      }
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _mc.removeListener(_onMatch);
    SettingsStore.instance.removeListener(_onSettings);
    _link?.state.removeListener(_onLink);
    _peerPickTimeout?.cancel();
    unawaited(_link?.close());
    _mc.dispose();
    super.dispose();
  }

  List<String> get _names {
    final seats = _m?.seats ?? const <MatchSeat>[];
    return [
      for (var i = 0; i < 2; i++) i < seats.length ? seats[i].name.toUpperCase() : roster[0].name,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final d = _driver;
    final revealing = d != null && (_revealUntil?.isAfter(DateTime.now()) ?? false);
    if (d != null && !revealing) {
      return FightScreen.driven(driver: d, names: _names, onExit: _leave, stage: _stage);
    }
    final l10n = AppLocalizations.of(context);
    final m = _m;
    final pad = MediaQuery.paddingOf(context);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 15, decoration: TextDecoration.none),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff221338), Color(0xff110b1f), Color(0xff07060c)],
              stops: [0, 0.4, 1],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: pad.top, left: pad.left, right: pad.right),
            child: Column(
              children: [
                // Close top-left, the title centred on the same line.
                SizedBox(
                  height: 56,
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          l10n.fightTitle.toUpperCase(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xffffcf6e), letterSpacing: 1.5),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 12,
                        child: GlassCloseButton(tone: GlassTone.media, still: true, onTap: _leave, semanticLabel: l10n.fightQuit),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: m == null ? const Center(child: CupertinoActivityIndicator(color: Colors.white)) : _body(l10n, m, pad.bottom),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const TextStyle _sectionStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Color(0xb3ffffff));

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(left: 2, bottom: 6), child: Text(title.toUpperCase(), style: _sectionStyle)),
        child,
      ],
    ),
  );

  void _setPick(int id) {
    if (id == _myPick) return;
    setState(() => _myPick = id);
    unawaited(SettingsStore.instance.setFightChar(id));
  }

  Widget _body(AppLocalizations l10n, ChatMatch m, double bottomInset) {
    final seats = m.seats;
    final mine = _mySeat;
    final MatchSeat? opp = mine >= 0
        ? (seats.length == 2 ? seats[1 - mine] : null)
        : (seats.isNotEmpty ? seats[0] : null);
    final left = mine >= 0 ? seats[mine] : (seats.isNotEmpty ? seats[0] : null);
    final right = mine >= 0 ? opp : (seats.length > 1 ? seats[1] : null);

    Widget status;
    Widget? action;
    switch (_phase) {
      case _Phase.lobby:
        if (mine < 0 && seats.length < 2) {
          status = Text(l10n.fightOnlineReadyHint, textAlign: TextAlign.center);
          action = _BigButton(label: l10n.fightOnlineJoin, onTap: _busy ? null : _join);
        } else if (seats.length < 2) {
          status = Text(l10n.fightOnlineWaitingOpponent, textAlign: TextAlign.center);
        } else {
          final meReady = mine >= 0 && seats[mine].ready;
          final oppReady = opp?.ready ?? false;
          status = Text(
            meReady && !oppReady ? l10n.fightOnlineWaitingReady(opp?.name ?? '') : l10n.fightOnlineReadyHint,
            textAlign: TextAlign.center,
          );
          if (mine >= 0) {
            action = _BigButton(
              label: meReady ? l10n.fightOnlineReadyDone : l10n.fightOnlineReady,
              done: meReady,
              onTap: _busy ? null : () => _toggleReady(!meReady),
            );
          }
        }
      case _Phase.connecting:
        status = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(color: Colors.white),
            const SizedBox(height: 12),
            Text(l10n.fightOnlineConnecting(opp?.name ?? ''), textAlign: TextAlign.center),
          ],
        );
      case _Phase.failed:
        status = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.fightOnlineCouldNotConnect(opp?.name ?? ''), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l10n.fightOnlineUpdateHint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xb3ffffff))),
          ],
        );
        action = _BigButton(label: l10n.fightOnlineTryAgain, onTap: _retry);
      case _Phase.over:
        final won = mine >= 0 && m.winner == mine, lost = mine >= 0 && m.winner == 1 - mine;
        status = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              won ? l10n.fightYouWin : (lost ? l10n.fightYouLose : l10n.fightDrawResult),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: won ? const Color(0xffffd23a) : (lost ? const Color(0xffff4f6e) : Colors.white),
              ),
            ),
            if (m.reason == 'disputed') ...[
              const SizedBox(height: 8),
              Text(l10n.fightOnlineResultDisputed, textAlign: TextAlign.center),
            ] else if (m.reason == 'left' && won) ...[
              const SizedBox(height: 8),
              Text(l10n.fightOnlineResultLeft(opp?.name ?? ''), textAlign: TextAlign.center),
            ],
          ],
        );
        action = _BigButton(label: l10n.fightOnlineBackToChat, onTap: () => Navigator.of(context).maybePop());
      case _Phase.fighting:
        status = const SizedBox.shrink();
    }
    status = DefaultTextStyle.merge(style: const TextStyle(fontSize: 15, height: 1.35, color: Color(0xe6ffffff)), child: status);

    // A seated player in the lobby picks right here: fighter, look and (the
    // host) the stage, all on the page, with Ready pinned at the bottom.
    final picking = _phase == _Phase.lobby && mine >= 0;
    final look = fightLookOf(SettingsStore.instance.fightLook);

    Widget cards(double h) => Row(
      children: [
        Expanded(
          child: FightSeatCard(
            name: left?.name,
            ready: left?.ready ?? false,
            tone: 0,
            height: h,
            charId: mine >= 0 ? _myPick : null,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('VS', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, color: Colors.white)),
        ),
        Expanded(
          child: FightSeatCard(
            name: right?.name,
            ready: _phase == _Phase.fighting || (right?.ready ?? false),
            tone: 1,
            height: h,
            // Hidden until the reveal; a spectator never sees picks.
            charId: _phase == _Phase.fighting ? _peerPick : null,
            alt: _peerPick != null && _peerPick == _myPick,
            hint: right != null && _phase != _Phase.fighting ? l10n.fightOpponentHidden : null,
          ),
        ),
      ],
    );

    Widget bottom(Widget? a) => Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 16),
      child: a ?? const SizedBox.shrink(),
    );

    return LayoutBuilder(builder: (context, box) {
      if (picking) {
        final options = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(l10n.fightFighterTitle, FightCharacterGrid(selected: _myPick, look: look, onPick: _setPick)),
            _section(l10n.fightLookTitle, FightLookPicker(look: look)),
            _section(
              l10n.fightStageTitle,
              mine == 0
                  ? FightStagePicker(selected: _stagePick, onPick: _pickStage)
                  : Text(l10n.fightStageHostPicks, style: const TextStyle(fontSize: 14, color: Color(0xb3ffffff))),
            ),
            const SizedBox(height: 12),
          ],
        );
        final wide = box.maxWidth > box.maxHeight * 1.15 && box.maxWidth >= 600;
        if (wide) {
          // Landscape phone, tablet, desktop: the matchup and Ready on the
          // left, the choices scrolling on the right.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: (box.maxWidth * .4).clamp(280.0, 420.0),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 4, bottomInset + 16),
                      child: Column(
                        children: [
                          Expanded(child: LayoutBuilder(builder: (context, b) => Center(child: cards(b.maxHeight.clamp(96.0, 260.0))))),
                          const SizedBox(height: 10),
                          status,
                          const SizedBox(height: 12),
                          ?action,
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 16),
                      child: options,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final cardH = (box.maxHeight * .24).clamp(120.0, 210.0);
        return Column(
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 0), child: cards(cardH)),
            Padding(padding: const EdgeInsets.fromLTRB(28, 12, 28, 0), child: status),
            Expanded(
              child: ShaderMask(
                // Soft edges where the choices scroll under the matchup and Ready.
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xff000000), Color(0xff000000), Color(0x00000000)],
                  stops: [0, .04, .94, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 2, 20, 12), child: options),
              ),
            ),
            bottom(action),
          ],
        );
      }

      // Everyone else, and every other phase: the matchup centred.
      final cardH = (box.maxHeight * .42).clamp(96.0, 240.0);
      Widget? stageRow;
      if (mine == 1 && _phase == _Phase.lobby) {
        stageRow = Text(l10n.fightStageHostPicks, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xb3ffffff)));
      } else if (_phase == _Phase.fighting) {
        // The VS reveal: where the fight is.
        stageRow = FightStagePicker(selected: _stage, onPick: (_) {}, readOnly: true);
      }
      return Column(
        children: [
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: cards(cardH)),
          SizedBox(height: box.maxHeight < 360 ? 12 : 28),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 28), child: status),
          if (stageRow != null) ...[SizedBox(height: box.maxHeight < 360 ? 8 : 16), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: stageRow)],
          const Spacer(),
          bottom(action),
        ],
      );
    });
  }
}

class FightSeatCard extends StatelessWidget {
  const FightSeatCard({
    super.key,
    required this.name,
    required this.ready,
    required this.tone,
    required this.height,
    this.charId,
    this.hint,
    this.onTap,
    this.alt = false,
  });
  final String? name;
  final bool ready;
  final int tone;
  final double height;

  /// The fighter shown, or null for a hidden pick (a big question mark).
  final int? charId;
  final String? hint;
  final VoidCallback? onTap;

  /// The mirror-match outfit (both players on the same fighter).
  final bool alt;

  @override
  Widget build(BuildContext context) {
    final colors = tone == 0 ? const [Color(0xff1fb5a8), Color(0xff0c3d3a)] : const [Color(0xffc8313b), Color(0xff3d0c14)];
    final look = fightLookOf(SettingsStore.instance.fightLook);
    final card = SizedBox(
      height: height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 12))],
        ),
        // The frame is drawn over the art, not around it: a border in the
        // background decoration insets the child, whose square corners then
        // cut into the rounded frame.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ready ? const Color(0xffffd23a) : const Color(0x33ffffff), width: 2.5),
        ),
        child: Stack(
          children: [
            // The fighter, alive; a hidden pick is a question mark.
            if (name != null && charId == null)
              const Positioned.fill(
                bottom: 44,
                child: Center(
                  child: Text('?', style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: Color(0x66ffffff))),
                ),
              ),
            if (name != null && charId != null)
              Positioned.fill(
                bottom: 44,
                child: FighterPortrait(
                  charId: charId!,
                  alt: alt,
                  facingLeft: tone == 1,
                  ready: ready,
                  look: look,
                  glow: tone == 0 ? const Color(0xff3fd2c7) : const Color(0xffff6a5c),
                ),
              ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x99000000)]),
                ),
              ),
            ),
            if (ready)
              const Positioned(top: 10, right: 10, child: Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xffffd23a), size: 24)),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (charId != null || hint != null)
                    Text(
                      charId != null ? roster[charId!].name : hint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xb3ffffff), letterSpacing: 1),
                    ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(name ?? '?', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final tap = onTap;
    return tap == null ? card : SpringPress(onTap: tap, scale: .96, semanticLabel: hint ?? name ?? '', child: card);
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onTap, this.done = false});
  final String label;
  final VoidCallback? onTap;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onTap ?? () {},
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: done ? null : const LinearGradient(colors: [Color(0xffffcf6e), Color(0xffff8a3d), Color(0xffff4f6e)]),
          color: done ? const Color(0x33ffffff) : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Text(label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: done ? Colors.white : const Color(0xff1b0d02))),
        ),
      ),
    );
  }
}
