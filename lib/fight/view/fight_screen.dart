import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../ads/banana_sheet.dart';
import '../../ads/banana_wallet.dart';
import '../../ads/unlock_sheet.dart';
import '../../games/catalog.dart' show lookItemId;
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/glass_buttons.dart';
import '../../widgets/liquid_glass.dart' show GlassTone;
import '../../widgets/spring_press.dart';
import '../core/bot.dart' as fb;
import '../core/core.dart';
import '../core/fight_step.dart' as fight;
import 'art/fight_art.dart';
import 'art/stages/stages.dart';
import 'fight_audio.dart';
import 'fight_audio_toggles.dart';
import 'fight_controls.dart';
import 'fight_quality.dart';
import 'fight_renderer.dart';
import 'fight_stage_picker.dart' show fightStageResolveMine;
import '../../ui/foundation/caps.dart';

FightLook fightLookOf(String wire) => switch (wire) {
  'painted' => FightLook.painted,
  'pixel' => FightLook.pixel,
  _ => FightLook.cartoon,
};

String fightLookWire(FightLook l) => l.name;

/// A look being tried before it is owned: the pause menu's 10-second live
/// preview, or Training's free try. Never persisted; the setting stays what
/// the player owns.
class FightLookTrial extends ChangeNotifier {
  FightLookTrial._();
  static final FightLookTrial instance = FightLookTrial._();

  static const Duration previewLength = Duration(seconds: 10);

  FightLook? _look;
  Timer? _timer;

  /// The look on trial, or null.
  FightLook? get look => _look;

  /// Shows [look] now. With [limit] it snaps back after that long and calls
  /// [onEnd]; without, it stays until [clear] (Training).
  void start(FightLook look, {Duration? limit, VoidCallback? onEnd}) {
    _timer?.cancel();
    _timer = null;
    _look = look;
    if (limit != null) {
      _timer = Timer(limit, () {
        _timer = null;
        _look = null;
        notifyListeners();
        onEnd?.call();
      });
    }
    notifyListeners();
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    if (_look == null) return;
    _look = null;
    notifyListeners();
  }
}

/// The look a real fight is drawn in: a look on trial, else the setting, but
/// only if the player owns it (Cartoon otherwise; a refund or an old setting
/// never shows a locked look). Until the wallet has loaded the setting stands.
FightLook fightLookNow() {
  final trial = FightLookTrial.instance.look;
  if (trial != null) return trial;
  final l = fightLookOf(SettingsStore.instance.fightLook);
  final w = BananaWallet.instance;
  return !w.loaded || w.ownsLook(l) ? l : FightLook.cartoon;
}

FightHudText fightHudText(AppLocalizations l10n) => FightHudText(
  round: l10n.fightHudRound,
  fight: l10n.fightHudFight,
  ko: l10n.fightHudKo,
  time: l10n.fightHudTime,
  wins: l10n.fightHudWins,
  draw: l10n.fightHudDraw,
  hits: l10n.fightHudHits,
);

/// Paints one fight: the shared view for the game and the lobby previews.
class FightPainter extends CustomPainter {
  FightPainter({
    required this.renderer,
    required this.state,
    required this.look,
    required this.names,
    required this.text,
    this.stage = 0,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final FightRenderer renderer;
  final FightState Function() state;
  final FightLook look;
  final List<String> names;
  final FightHudText text;

  /// The place the fight is in (stages/stages.dart).
  final int stage;

  @override
  void paint(Canvas canvas, Size size) => renderer.paint(canvas, size, state(), look, names, text, stage: stage);

  @override
  bool shouldRepaint(FightPainter o) => o.look != look || o.renderer != renderer || o.names != names || o.stage != stage;
}

/// A fight against the bot: the 60 Hz loop, input, haptics, pause and result.
///
/// The simulation runs on a fixed step from a [Ticker]: frame time is
/// accumulated and the engine stepped once per 1/60 s, so the fight plays at
/// the same speed on a 60, 90 or 120 Hz screen (the painter simply redraws
/// the latest sim frame on every vsync).
/// What moves the fight forward one fixed step: the bot locally, or the
/// rollback session online. The screen owns the clock, input, drawing and
/// overlays; the driver owns the simulation.
abstract class FightDriver {
  FightState get state;

  /// Which fighter this screen controls.
  int get localIndex;

  /// Bot fights pause and restart; online fights cannot.
  bool get offline;

  /// One 1/60 s step with the local player's input.
  void step(int localInput);

  /// A fresh match (offline only).
  void restart();

  /// True once the match is over for good (online: every input up to the
  /// end confirmed, the result reported). Drives the result overlay.
  bool get finished;

  /// Shown over the fight when set (e.g. a lost connection).
  ValueListenable<String?> get notice;
}

/// The bot opponent: plain [step] on a local state.
class BotFightDriver implements FightDriver {
  BotFightDriver({required this.player, required this.opponent, required this.level}) {
    restart();
  }

  final CharacterDef player, opponent;
  final fb.BotLevel level;
  late FightState _s;
  late fb.FightBot _bot;
  int _seed = DateTime.now().microsecondsSinceEpoch & 0x3fffffff;

  @override
  FightState get state => _s;
  @override
  int get localIndex => 0;
  @override
  bool get offline => true;
  @override
  final ValueNotifier<String?> notice = ValueNotifier(null);

  @override
  void step(int localInput) => fight.step(_s, localInput, _bot.decide(_s, 1));

  @override
  void restart() {
    _seed = (_seed * 1103515245 + 12345) & 0x3fffffff;
    _s = FightState.initial(seed: _seed, p1: player, p2: opponent);
    _bot = fb.FightBot(seed: _seed ^ 0x5bd1e995, level: level);
  }

  /// Gets the player back up after a loss ([FightState.continueAfterLoss]).
  bool continueAfterLoss() => _s.continueAfterLoss(localIndex);

  @override
  bool get finished => _s.phase == Phase.over;
}

class FightScreen extends StatefulWidget {
  FightScreen({super.key, required CharacterDef player, required CharacterDef opponent, required fb.BotLevel level, this.onExit, this.stage, this.userId})
    : driver = BotFightDriver(player: player, opponent: opponent, level: level),
      names = [player.name, opponent.name];

  /// An externally driven fight (online). [names] by fighter index.
  const FightScreen.driven({super.key, required this.driver, required this.names, this.onExit, this.stage = 0}) : userId = null;

  final FightDriver driver;
  final List<String> names;

  /// Leaving the fight (quit, back to chat). Defaults to popping the route.
  final VoidCallback? onExit;

  /// The place to fight in. Null (bot fights) = the player's setting, with
  /// Random re-rolled for every match; online the host's pick is passed in.
  final int? stage;

  /// The signed-in player, for spending a banana on a continue. Null hides it.
  final String? userId;

  @override
  State<FightScreen> createState() => _FightScreenState();
}

class _FightScreenState extends State<FightScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _step = Duration(microseconds: 16667);

  FightDriver get _d => widget.driver;
  FightState get _s => _d.state;
  final FightInput _input = FightInput();
  final FightRenderer _renderer = FightRenderer();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final ValueNotifier<bool> _superReady = ValueNotifier(false);
  final FocusNode _focus = FocusNode(debugLabel: 'fight');
  final FightQualityGovernor _governor = FightQualityGovernor();
  late final Ticker _ticker;
  Duration _last = Duration.zero, _acc = Duration.zero;
  bool _paused = false, _over = false;

  /// Continues bought this fight (a banana each); reset on Rematch.
  int _continues = 0;
  static const int _maxContinues = 3;
  // A controller is in use: the touch deck fades out until a finger returns.
  bool _padActive = false;
  int _seenEventFrame = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FightRenderer.warmUp();
    _newMatch();
    _ticker = createTicker(_tick)..start();
    _governor.start();
    final displays = WidgetsBinding.instance.platformDispatcher.displays;
    final hz = displays.isEmpty ? 60.0 : displays.first.refreshRate;
    if (hz > 0) _governor.setRefreshInterval(Duration(microseconds: (1e6 / hz).round()));
    SettingsStore.instance.addListener(_onSettings);
    FightLookTrial.instance.addListener(_onSettings);
    _input.startGamepad(onActivity: _onPadActivity, onStart: () => _setPaused(!_paused));
    unawaited(FightAudio.instance.open().then((_) => FightAudio.instance.startMusic()));
  }

  int _stage = 0;

  void _newMatch() {
    _stage = widget.stage != null ? fightStageOf(widget.stage!) : fightStageResolveMine(SettingsStore.instance.fightStage);
    _renderer.resetCamera();
    _seenEventFrame = -1;
    _over = false;
    _acc = Duration.zero;
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _tick(Duration now) {
    var dt = now - _last;
    _last = now;
    _governor.onTick(dt);
    if (_paused && _d.offline) return;
    if (dt > const Duration(milliseconds: 100)) dt = const Duration(milliseconds: 100); // after a stall, don't fast-forward
    _acc += dt;
    var stepped = false;
    while (_acc >= _step) {
      _acc -= _step;
      _d.step(_paused ? 0 : _input.mask);
      stepped = true;
    }
    if (!stepped) return;
    _feedback();
    FightAudio.instance.onFrame(_s, localPlayer: _d.localIndex);
    _superReady.value = _s.p[_d.localIndex].meter >= superCost;
    _frame.value = _s.frame;
    if (_d.finished && !_over) {
      _over = true;
      _input.clear();
      setState(() {});
    }
  }

  /// Haptics from the engine's event ring, each event once.
  void _feedback() {
    var newest = _seenEventFrame;
    for (final e in _s.events) {
      if (e.frame <= _seenEventFrame) continue;
      if (e.frame > newest) newest = e.frame;
      switch (e.kind) {
        case Ev.hit:
          HapticFeedback.lightImpact();
        case Ev.counterHit || Ev.throwHit || Ev.wallBounce || Ev.superFlash:
          HapticFeedback.mediumImpact();
        case Ev.ko:
          HapticFeedback.heavyImpact();
        case Ev.block || Ev.perfectBlock:
          HapticFeedback.selectionClick();
      }
    }
    _seenEventFrame = newest;
  }

  void _onPadActivity() {
    if (_padActive || !mounted) return;
    setState(() => _padActive = true);
  }

  void _setPaused(bool p) {
    if (_paused == p || _over) return;
    // Online the fight runs on regardless: the menu is a menu, not a pause.
    _input.clear();
    FightAudio.instance.ui(FightUiSound.tick);
    FightAudio.instance.duck(p);
    setState(() => _paused = p);
    if (!p) _focus.requestFocus();
  }

  void _exit() {
    final exit = widget.onExit;
    if (exit != null) {
      exit();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  bool get _canContinue {
    final d = _d;
    return d is BotFightDriver &&
        widget.userId != null &&
        _continues < _maxContinues &&
        _s.matchWinner == 1 - d.localIndex;
  }

  Future<void> _continue() async {
    final d = _d, userId = widget.userId;
    if (d is! BotFightDriver || userId == null || !_canContinue) return;
    final spent = await offerBananas(
      context,
      userId: userId,
      use: BananaUse.fightContinue,
      what: AppLocalizations.of(context).bananaForContinue,
    );
    if (!spent || !mounted || !d.continueAfterLoss()) return;
    _continues++;
    _over = false;
    _acc = Duration.zero;
    _input.clear();
    setState(() => _paused = false);
    _focus.requestFocus();
  }

  void _restart() {
    _continues = 0;
    _d.restart();
    _newMatch();
    setState(() => _paused = false);
    _focus.requestFocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _d.offline) _setPaused(true);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    FightLookTrial.instance.removeListener(_onSettings);
    FightLookTrial.instance.clear();
    _input.stopGamepad();
    _input.gamepadConnected.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _governor.stop();
    unawaited(FightAudio.instance.close());
    _renderer.dispose();
    _frame.dispose();
    _superReady.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The touch deck, hidden (but still live) while a controller is in use: any
  /// touch on it brings it back, since the finger is the player's new choice.
  Widget _deck({required bool overlay}) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (_padActive) setState(() => _padActive = false);
      },
      child: AnimatedOpacity(
        opacity: _padActive ? 0 : 1,
        duration: const Duration(milliseconds: 160),
        child: FightTouchControls(input: _input, superReady: _superReady, overlay: overlay, onPress: HapticFeedback.selectionClick),
      ),
    );
  }

  bool get _touchFirst => Caps.touchFirst;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final look = fightLookNow();
    final view = CustomPaint(
      painter: FightPainter(
        renderer: _renderer,
        state: () => _s,
        look: look,
        names: widget.names,
        text: fightHudText(l10n),
        stage: _stage,
        repaint: _frame,
      ),
      child: const SizedBox.expand(),
    );
    final controls = _touchFirst ? _deck(overlay: false) : null;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onFocusChange: (f) {
        if (!f) _input.clear();
      },
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          _setPaused(!_paused);
          return KeyEventResult.handled;
        }
        return _paused ? KeyEventResult.ignored : _input.onKey(e);
      },
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 15, decoration: TextDecoration.none),
          child: ColoredBox(
            color: const Color(0xff07060c),
            child: LayoutBuilder(
              builder: (context, box) {
                final portrait = box.maxHeight > box.maxWidth * 1.1;
                final pad = MediaQuery.paddingOf(context);
                if (!_touchFirst) return _desktopLayout(context, box, view, l10n, look, pad);
                Widget body;
                if (portrait) {
                  // The deck gets what thumbs need and no more; the stage
                  // takes the rest. In portrait the camera's zoom is capped
                  // by the stage's HEIGHT (jump headroom), so every point
                  // given to the stage is bigger fighters. The deck's buttons
                  // fit at full size from ~3.1 units (~190 pt on a phone).
                  final deckMin = (box.maxHeight * 0.27).clamp(196.0, 260.0) + pad.bottom;
                  final stageH = (box.maxHeight - pad.top - 52 - deckMin).clamp(box.maxWidth * 0.62, box.maxWidth * 1.3);
                  body = Column(
                    children: [
                      SizedBox(height: pad.top + 52),
                      SizedBox(height: stageH, child: view),
                      Expanded(
                        child: controls == null
                            ? _KeyboardHint(input: _input, text: l10n.fightKeyboardHint, padText: l10n.fightGamepadHint)
                            : Padding(padding: EdgeInsets.only(bottom: pad.bottom), child: controls),
                      ),
                    ],
                  );
                } else {
                  body = Stack(
                    children: [
                      Positioned.fill(child: view),
                      if (controls != null)
                        Positioned(
                          left: pad.left,
                          right: pad.right,
                          bottom: pad.bottom,
                          height: box.maxHeight * 0.48,
                          child: _deck(overlay: true),
                        )
                      else
                        Positioned(left: 0, right: 0, bottom: 14 + pad.bottom, child: _KeyboardHint(input: _input, text: l10n.fightKeyboardHint, padText: l10n.fightGamepadHint, faded: true)),
                    ],
                  );
                }
                return Stack(
                  children: [
                    Positioned.fill(child: body),
                    // Portrait: top-left, above the stage. Landscape: the
                    // HUD's bars own the top corners, so it sits under the
                    // timer, where fighting games keep it.
                    if (portrait)
                      Positioned(
                        top: pad.top + 8,
                        left: pad.left + 12,
                        child: GlassIconButton(tone: GlassTone.media, still: true, icon: CupertinoIcons.pause_fill, iconSize: 18, onTap: () => _setPaused(true)),
                      )
                    else
                      Positioned(
                        top: pad.top + box.maxHeight * 0.13,
                        left: 0,
                        right: 0,
                        child: Center(child: GlassIconButton(tone: GlassTone.media, still: true, icon: CupertinoIcons.pause_fill, iconSize: 18, onTap: () => _setPaused(true))),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: pad.top + box.maxHeight * 0.32,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: _d.notice,
                          builder: (context, n, _) => n == null
                              ? const SizedBox.shrink()
                              : Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(color: const Color(0xcc000000), borderRadius: BorderRadius.circular(14)),
                                    child: Text(n, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (_paused) Positioned.fill(child: _pauseMenu(l10n, look)),
                    if (_over) Positioned.fill(child: _resultCard(l10n)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Desktop and web: no title chrome and no scrolling. A slim top bar (close
  /// top-left, pause top-right), the stage aspect-fit at 16:10 and centred on
  /// the plain background (letterboxed on ultra-wide or tall windows), and the
  /// key hint under it. The fight canvas sits in its own RepaintBoundary.
  Widget _desktopLayout(BuildContext context, BoxConstraints box, Widget view, AppLocalizations l10n, FightLook look, EdgeInsets pad) {
    const barH = 52.0, hintH = 40.0;
    final availW = (box.maxWidth - pad.horizontal).clamp(0.0, double.infinity);
    final availH = (box.maxHeight - pad.vertical - barH - hintH).clamp(0.0, double.infinity);
    var w = availW, h = w / 1.6;
    if (h > availH) {
      h = availH;
      w = h * 1.6;
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: pad,
            child: Column(
              children: [
                const SizedBox(height: barH),
                Expanded(
                  child: Center(
                    child: SizedBox(width: w, height: h, child: RepaintBoundary(child: view)),
                  ),
                ),
                SizedBox(height: hintH, child: _KeyboardHint(input: _input, text: l10n.fightKeyboardHint, padText: l10n.fightGamepadHint, faded: true)),
              ],
            ),
          ),
        ),
        Positioned(
          top: pad.top + 6,
          left: pad.left + 12,
          child: GlassCloseButton(tone: GlassTone.media, still: true, onTap: _d.offline ? _exit : () => _setPaused(true)),
        ),
        Positioned(
          top: pad.top + 6,
          right: pad.right + 12,
          child: GlassIconButton(tone: GlassTone.media, still: true, icon: CupertinoIcons.pause_fill, iconSize: 18, onTap: () => _setPaused(true)),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: pad.top + barH + h * 0.32,
          child: IgnorePointer(
            child: ValueListenableBuilder<String?>(
              valueListenable: _d.notice,
              builder: (context, n, _) => n == null
                  ? const SizedBox.shrink()
                  : Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xcc000000), borderRadius: BorderRadius.circular(14)),
                        child: Text(n, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
            ),
          ),
        ),
        if (_paused) Positioned.fill(child: _pauseMenu(l10n, look)),
        if (_over) Positioned.fill(child: _resultCard(l10n)),
      ],
    );
  }

  Widget _pauseMenu(AppLocalizations l10n, FightLook look) {
    return _Scrim(
      child: _Panel(
        // Online the fight keeps running behind the menu: it says so.
        title: _d.offline ? l10n.fightPaused : l10n.fightOnlineMenuTitle,
        children: [
          FightLookPicker(look: look),
          const SizedBox(height: 10),
          const FightAudioToggles(),
          const SizedBox(height: 16),
          _MenuButton(label: _d.offline ? l10n.fightResume : l10n.fightOnlineBackToFight, primary: true, onTap: () => _setPaused(false)),
          if (_d.offline) ...[
            const SizedBox(height: 10),
            _MenuButton(label: l10n.fightRestart, onTap: _restart),
          ],
          const SizedBox(height: 10),
          _MenuButton(label: _d.offline ? l10n.fightQuit : l10n.fightOnlineForfeit, onTap: _exit),
        ],
      ),
    );
  }

  Widget _resultCard(AppLocalizations l10n) {
    final w = _s.matchWinner, me = _d.localIndex;
    final won = w == me, lost = w == 1 - me;
    if (_canContinue && widget.userId != null) BananaWallet.instance.watchWarm(widget.userId!);
    final title = won ? l10n.fightYouWin : (lost ? l10n.fightYouLose : l10n.fightDrawResult);
    return _Scrim(
      child: _Panel(
        title: title,
        accent: won ? const Color(0xffffd23a) : (lost ? const Color(0xffff4f6e) : Colors.white),
        children: [
          if (_canContinue) ...[
            _MenuButton(label: '\u{1F34C} ${l10n.bananaForContinue}', primary: true, onTap: _continue),
            const SizedBox(height: 10),
          ],
          if (_d.offline) ...[
            _MenuButton(label: l10n.fightRematch, primary: true, onTap: _restart),
            const SizedBox(height: 10),
          ],
          _MenuButton(label: _d.offline ? l10n.fightQuit : l10n.fightOnlineBackToChat, primary: !_d.offline, onTap: _exit),
        ],
      ),
    );
  }
}

/// The three looks as chips; changing one restyles the fight live. A look the
/// player does not own is shown for 10 seconds, then snaps back to Cartoon and
/// offers the unlock sheet. In [training] every look is free to try (kept only
/// for as long as the room is open) and nothing locked is saved.
class FightLookPicker extends StatelessWidget {
  const FightLookPicker({super.key, required this.look, this.training = false, this.preview = true});
  final FightLook look;
  final bool training;

  /// False outside a running fight (a lobby): a locked look opens the unlock
  /// sheet at once, there being nothing to preview it on.
  final bool preview;

  /// Applies a tap on look [l]: set it when owned, otherwise try it (see the
  /// class doc). Public so Training's look chip behaves the same.
  static void pick(BuildContext context, FightLook l, {bool training = false, bool preview = true}) {
    final trial = FightLookTrial.instance;
    final w = BananaWallet.instance;
    if (w.ownsLook(l)) {
      trial.clear();
      SettingsStore.instance.setFightLook(fightLookWire(l));
    } else if (training) {
      trial.start(l);
    } else if (!preview) {
      showUnlockSheet(context, lookItemId(l), reason: AppLocalizations.of(context).bananasReasonLook).then((ok) {
        if (ok) SettingsStore.instance.setFightLook(fightLookWire(l));
      });
    } else {
      final reason = AppLocalizations.of(context).bananasReasonLook;
      trial.start(
        l,
        limit: FightLookTrial.previewLength,
        onEnd: () async {
          // Snapped back; offer the unlock only if the menu is still open.
          if (!context.mounted) return;
          if (await showUnlockSheet(context, lookItemId(l), reason: reason)) {
            SettingsStore.instance.setFightLook(fightLookWire(l));
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String name(FightLook l) => switch (l) {
      FightLook.cartoon => l10n.fightLookCartoon,
      FightLook.painted => l10n.fightLookPainted,
      FightLook.pixel => l10n.fightLookPixel,
    };
    return ListenableBuilder(
      listenable: BananaWallet.instance,
      builder: (context, _) => Row(
        children: [
          for (final (i, l) in FightLook.values.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: SpringPress(
                onTap: () => pick(context, l, training: training, preview: preview),
                semanticLabel: name(l),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: l == look ? Colors.white : const Color(0x1fffffff),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    !training && !BananaWallet.instance.ownsLook(l) ? '\u{1F512} ${name(l)}' : name(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: l == look ? const Color(0xff0b0a12) : Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A flat dim, not a blur: a BackdropFilter over a live 60 fps scene costs
    // a full-screen blur every frame.
    return ColoredBox(
      color: const Color(0xb3070510),
      // Scrolls rather than overflows: a landscape phone is under 400 pt tall.
      child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: child)),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children, this.accent = Colors.white});
  final String title;
  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xff16121f),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xff2e2942)),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 40, offset: Offset(0, 18))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: accent, letterSpacing: 0.5),
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.label, required this.onTap, this.primary = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary ? const LinearGradient(colors: [Color(0xffffcf6e), Color(0xffff8a3d)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
          color: primary ? null : const Color(0x1fffffff),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: primary ? const Color(0xff1b0d02) : Colors.white)),
      ),
    );
  }
}

class _KeyboardHint extends StatelessWidget {
  const _KeyboardHint({required this.input, required this.text, required this.padText, this.faded = false});
  final FightInput input;
  final String text, padText;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ValueListenableBuilder<bool>(
          valueListenable: input.gamepadConnected,
          builder: (context, connected, _) => Text(
            connected ? '$text\n$padText' : text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: faded ? 0.55 : 0.75), fontSize: 13.5, height: 1.4),
          ),
        ),
      ),
    );
  }
}
