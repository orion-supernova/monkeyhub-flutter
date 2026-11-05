import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../keyboard/focusable_tap.dart' show FocusRingShape;
import '../../widgets/spring_press.dart';
import '../core/bot.dart' as fb;
import '../core/core.dart';
import 'art/fight_art.dart';
import 'fight_controls.dart';
import 'fight_renderer.dart';

FightLook fightLookOf(String wire) => switch (wire) {
  'painted' => FightLook.painted,
  'pixel' => FightLook.pixel,
  _ => FightLook.cartoon,
};

String fightLookWire(FightLook l) => l.name;

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
    required Listenable repaint,
  }) : super(repaint: repaint);

  final FightRenderer renderer;
  final FightState Function() state;
  final FightLook look;
  final List<String> names;
  final FightHudText text;

  @override
  void paint(Canvas canvas, Size size) => renderer.paint(canvas, size, state(), look, names, text);

  @override
  bool shouldRepaint(FightPainter o) => o.look != look || o.renderer != renderer || o.names != names;
}

/// A fight against the bot: the 60 Hz loop, input, haptics, pause and result.
///
/// The simulation runs on a fixed step from a [Ticker]: frame time is
/// accumulated and the engine stepped once per 1/60 s, so the fight plays at
/// the same speed on a 60, 90 or 120 Hz screen (the painter simply redraws
/// the latest sim frame on every vsync).
class FightScreen extends StatefulWidget {
  const FightScreen({super.key, required this.player, required this.opponent, required this.level});

  final CharacterDef player, opponent;
  final fb.BotLevel level;

  @override
  State<FightScreen> createState() => _FightScreenState();
}

class _FightScreenState extends State<FightScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _step = Duration(microseconds: 16667);

  late FightState _s;
  late fb.FightBot _bot;
  final FightInput _input = FightInput();
  final FightRenderer _renderer = FightRenderer();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final ValueNotifier<bool> _superReady = ValueNotifier(false);
  final FocusNode _focus = FocusNode(debugLabel: 'fight');
  late final Ticker _ticker;
  Duration _last = Duration.zero, _acc = Duration.zero;
  bool _paused = false, _over = false;
  int _seenEventFrame = -1;
  int _seed = DateTime.now().microsecondsSinceEpoch & 0x3fffffff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FightRenderer.warmUp();
    _newMatch();
    _ticker = createTicker(_tick)..start();
    SettingsStore.instance.addListener(_onSettings);
  }

  void _newMatch() {
    _seed = (_seed * 1103515245 + 12345) & 0x3fffffff;
    _s = FightState.initial(seed: _seed, p1: widget.player, p2: widget.opponent);
    _bot = fb.FightBot(seed: _seed ^ 0x5bd1e995, level: widget.level);
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
    if (_paused) return;
    if (dt > const Duration(milliseconds: 100)) dt = const Duration(milliseconds: 100); // after a stall, don't fast-forward
    _acc += dt;
    var stepped = false;
    while (_acc >= _step) {
      _acc -= _step;
      step(_s, _input.mask, _bot.decide(_s, 1));
      stepped = true;
    }
    if (!stepped) return;
    _feedback();
    _superReady.value = _s.p[0].meter >= superCost;
    _frame.value = _s.frame;
    if (_s.phase == Phase.over && !_over) {
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

  void _setPaused(bool p) {
    if (_paused == p || _over) return;
    _input.clear();
    setState(() => _paused = p);
    if (!p) _focus.requestFocus();
  }

  void _restart() {
    _newMatch();
    _bot.reset();
    setState(() => _paused = false);
    _focus.requestFocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _setPaused(true);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _renderer.dispose();
    _frame.dispose();
    _superReady.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _touchFirst => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final look = fightLookOf(SettingsStore.instance.fightLook);
    final view = CustomPaint(
      painter: FightPainter(
        renderer: _renderer,
        state: () => _s,
        look: look,
        names: [widget.player.name, widget.opponent.name],
        text: fightHudText(l10n),
        repaint: _frame,
      ),
      child: const SizedBox.expand(),
    );
    final controls = _touchFirst
        ? FightTouchControls(input: _input, superReady: _superReady, onPress: HapticFeedback.selectionClick)
        : null;

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
                Widget body;
                if (portrait) {
                  // The deck gets what thumbs need; the stage takes the rest
                  // (taller than 16:10 just shows more sky, the camera keeps
                  // the fighters framed on the ground line).
                  final deckMin = (box.maxHeight * 0.36).clamp(240.0, 330.0) + pad.bottom;
                  final stageH = (box.maxHeight - pad.top - 52 - deckMin).clamp(box.maxWidth * 0.62, box.maxWidth * 1.05);
                  body = Column(
                    children: [
                      SizedBox(height: pad.top + 52),
                      SizedBox(height: stageH, child: view),
                      Expanded(
                        child: controls == null
                            ? _KeyboardHint(text: l10n.fightKeyboardHint)
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
                          child: FightTouchControls(input: _input, superReady: _superReady, overlay: true, onPress: HapticFeedback.selectionClick),
                        )
                      else
                        Positioned(left: 0, right: 0, bottom: 14 + pad.bottom, child: _KeyboardHint(text: l10n.fightKeyboardHint, faded: true)),
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
                        child: _RoundIconButton(icon: CupertinoIcons.pause_fill, onTap: () => _setPaused(true)),
                      )
                    else
                      Positioned(
                        top: pad.top + box.maxHeight * 0.13,
                        left: 0,
                        right: 0,
                        child: Center(child: _RoundIconButton(icon: CupertinoIcons.pause_fill, onTap: () => _setPaused(true))),
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

  Widget _pauseMenu(AppLocalizations l10n, FightLook look) {
    return _Scrim(
      child: _Panel(
        title: l10n.fightPaused,
        children: [
          _LookPicker(look: look),
          const SizedBox(height: 16),
          _MenuButton(label: l10n.fightResume, primary: true, onTap: () => _setPaused(false)),
          const SizedBox(height: 10),
          _MenuButton(label: l10n.fightRestart, onTap: _restart),
          const SizedBox(height: 10),
          _MenuButton(label: l10n.fightQuit, onTap: () => Navigator.of(context).maybePop()),
        ],
      ),
    );
  }

  Widget _resultCard(AppLocalizations l10n) {
    final w = _s.matchWinner;
    final title = w == 0 ? l10n.fightYouWin : (w == 1 ? l10n.fightYouLose : l10n.fightDrawResult);
    return _Scrim(
      child: _Panel(
        title: title,
        accent: w == 0 ? const Color(0xffffd23a) : (w == 1 ? const Color(0xffff4f6e) : Colors.white),
        children: [
          _MenuButton(label: l10n.fightRematch, primary: true, onTap: _restart),
          const SizedBox(height: 10),
          _MenuButton(label: l10n.fightQuit, onTap: () => Navigator.of(context).maybePop()),
        ],
      ),
    );
  }
}

/// The three looks as chips; changing one restyles the fight live.
class _LookPicker extends StatelessWidget {
  const _LookPicker({required this.look});
  final FightLook look;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String name(FightLook l) => switch (l) {
      FightLook.cartoon => l10n.fightLookCartoon,
      FightLook.painted => l10n.fightLookPainted,
      FightLook.pixel => l10n.fightLookPixel,
    };
    return Row(
      children: [
        for (final (i, l) in FightLook.values.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: SpringPress(
              onTap: () => SettingsStore.instance.setFightLook(fightLookWire(l)),
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
                  name(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: l == look ? const Color(0xff0b0a12) : Colors.white),
                ),
              ),
            ),
          ),
        ],
      ],
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
      child: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onTap,
      focusShape: FocusRingShape.circle,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _KeyboardHint extends StatelessWidget {
  const _KeyboardHint({required this.text, this.faded = false});
  final String text;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: faded ? 0.55 : 0.75), fontSize: 13.5, height: 1.4),
        ),
      ),
    );
  }
}
