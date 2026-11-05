import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/spring_press.dart';
import '../core/core.dart';
import 'art/fight_art.dart';
import 'fight_character_grid.dart';
import 'fight_controls.dart';
import 'fight_renderer.dart';
import 'fight_screen.dart' show FightLookPicker, fightHudText, fightLookOf;
import 'fight_training_moves.dart';

/// Opens the training room for [charId] (default: the fighter picked in the
/// lobby).
Future<void> openFightTraining(BuildContext context, {int? charId}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => FightTrainingScreen(charId: charId)),
  );
}

const Color _bg = Color(0xff07060c);
const Color _panel = Color(0xff16121f);
const Color _line = Color(0xff2e2942);
const Color _gold = Color(0xffffd23a);

enum _Speed {
  full('1×', 1),
  half('½×', .5),
  quarter('¼×', .25);

  const _Speed(this.label, this.factor);
  final String label;
  final double factor;
}

/// A place to check every move of a fighter: pick a move, watch it land on a
/// dummy, slow it down, read its frame data, see the engine's boxes.
///
/// P1 is the chosen fighter, P2 the same fighter in its mirror outfit that
/// never acts. Nobody can die and P1 never runs out of meter. The simulation
/// is the real engine on the same fixed 60 Hz step as a fight; the view only
/// repaints when it has stepped.
class FightTrainingScreen extends StatefulWidget {
  const FightTrainingScreen({super.key, this.charId});

  final int? charId;

  @override
  State<FightTrainingScreen> createState() => _FightTrainingScreenState();
}

class _FightTrainingScreenState extends State<FightTrainingScreen> with SingleTickerProviderStateMixin {
  static const Duration _step = Duration(microseconds: 16667);

  final FightInput _input = FightInput();
  final FightRenderer _renderer = FightRenderer();
  final TrainingCameraHolder _cam = TrainingCameraHolder();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final ValueNotifier<String> _readout = ValueNotifier('');
  final FocusNode _focus = FocusNode(debugLabel: 'fight-training');
  final ValueNotifier<bool> _superReady = ValueNotifier(true);
  late final Ticker _ticker;
  Duration _last = Duration.zero, _acc = Duration.zero;

  late int _charId;
  late List<TrainMove> _moves;
  late FightState _s;
  TrainingScript? _script;
  int _sel = 0;
  int _since = 0; // sim frames since the last perform
  bool _paused = false, _loop = false, _boxes = false, _play = false;
  _Speed _speed = _Speed.full;

  CharacterDef get _char => roster[_charId];

  bool get _touchFirst => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    FightRenderer.warmUp();
    _charId = fightCharOf(widget.charId ?? SettingsStore.instance.fightChar);
    _loadFighter();
    _ticker = createTicker(_tick)..start();
    SettingsStore.instance.addListener(_onSettings);
    _input.startGamepad();
  }

  void _loadFighter() {
    _moves = trainingMoves(_char);
    _sel = 0;
    _script = null;
    _since = 0;
    _s = trainingState(_char);
    _cam.cam = null;
    _renderer.resetCamera();
    _readout.value = '';
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- loop

  void _tick(Duration now) {
    var dt = now - _last;
    _last = now;
    if (_paused) return;
    if (dt > const Duration(milliseconds: 100)) dt = const Duration(milliseconds: 100);
    _acc += Duration(microseconds: (dt.inMicroseconds * _speed.factor).round());
    var stepped = false;
    while (_acc >= _step) {
      _acc -= _step;
      _stepOnce();
      stepped = true;
    }
    if (stepped) _publish();
  }

  void _stepOnce() {
    final sc = _script;
    var a = _input.mask, b = 0;
    if (sc != null) {
      a |= sc.p1(_s);
      b = sc.p2(_s);
    }
    step(_s, a, b);
    trainingKeepAlive(_s);
    _since++;
    if (_loop && sc != null) {
      final p = _s.p[0];
      final idle = p.state == St.idle || p.state == St.walk || p.state == St.crouch;
      if ((_since >= 90 && idle) || _since >= 300) _perform(_sel);
    }
  }

  void _publish() {
    final p = _s.p[0];
    var text = '';
    if (p.state == St.move && p.moveId >= 0) text = '${p.sf}/${_char.moves[p.moveId].total}f';
    _readout.value = text;
    _frame.value = _s.frame;
  }

  void _stepOneFrame() {
    if (!_paused) return;
    _stepOnce();
    _publish();
  }

  // ---------------------------------------------------------------- actions

  void _perform(int index) {
    final m = _moves[index];
    final script = trainingScript(_char, m);
    _sel = index;
    _script = script;
    _since = 0;
    _s = trainingState(_char, dist: script.dist, frame: _s.frame);
    _input.clear();
    _publish();
    if (mounted) setState(() {});
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _script = null;
    _since = 0;
    _s = trainingState(_char, frame: _s.frame);
    _publish();
    setState(() {});
  }

  Future<void> _changeFighter() async {
    final look = fightLookOf(SettingsStore.instance.fightLook);
    final id = await showFightCharacterPicker(context, current: _charId, look: look);
    if (!mounted) return;
    _focus.requestFocus();
    if (id == null || id == _charId) return;
    setState(() {
      _charId = id;
      _loadFighter();
    });
    _publish();
  }

  void _setPaused(bool p) {
    _input.clear();
    setState(() => _paused = p);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    _input.stopGamepad();
    _input.gamepadConnected.dispose();
    _ticker.dispose();
    _renderer.dispose();
    _frame.dispose();
    _readout.dispose();
    _superReady.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final look = fightLookOf(SettingsStore.instance.fightLook);
    final name = _char.name;
    final view = RepaintBoundary(
      child: CustomPaint(
        painter: FightTrainingPainter(
          renderer: _renderer,
          cam: _cam,
          state: () => _s,
          look: look,
          names: [name, name],
          text: fightHudText(l10n),
          boxes: _boxes,
          repaint: _frame,
        ),
        child: const SizedBox.expand(),
      ),
    );

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onFocusChange: (f) {
        if (!f) _input.clear();
      },
      onKeyEvent: (node, e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return _input.onKey(e);
      },
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 14, decoration: TextDecoration.none),
          child: ColoredBox(
            color: _bg,
            child: LayoutBuilder(
              builder: (context, box) {
                final portrait = box.maxHeight > box.maxWidth * 1.1;
                final pad = MediaQuery.paddingOf(context);
                final header = _header(l10n, pad);
                if (portrait) {
                  return Column(
                    children: [
                      header,
                      AspectRatio(aspectRatio: 1.6, child: view),
                      _controls(l10n, compact: false),
                      Expanded(child: Padding(padding: EdgeInsets.only(bottom: pad.bottom), child: _lower(l10n, withDeck: true))),
                    ],
                  );
                }
                final side = (box.maxWidth * .36).clamp(300.0, 430.0);
                return Column(
                  children: [
                    header,
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: pad.left),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: 1.6,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            view,
                                            if (_touchFirst && _play)
                                              Positioned.fill(child: _deck(overlay: true)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxHeight: box.maxHeight * .34),
                                    child: SingleChildScrollView(child: _controls(l10n, compact: true)),
                                  ),
                                  SizedBox(height: pad.bottom),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: side + pad.right,
                            child: Padding(
                              padding: EdgeInsets.only(right: pad.right, bottom: pad.bottom),
                              child: _lower(l10n, withDeck: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _deck({required bool overlay}) => FightTouchControls(
    input: _input,
    superReady: _superReady,
    overlay: overlay,
    onPress: HapticFeedback.selectionClick,
  );

  Widget _header(AppLocalizations l10n, EdgeInsets pad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12 + pad.left, pad.top + 8, 12 + pad.right, 8),
      child: Row(
        children: [
          _IconBtn(
            key: const ValueKey('training_close'),
            icon: CupertinoIcons.xmark,
            semantic: MaterialLocalizations.of(context).closeButtonTooltip,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.fightTrainingTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: .3),
            ),
          ),
          SpringPress(
            key: const ValueKey('training_change_fighter'),
            onTap: _changeFighter,
            semanticLabel: l10n.fightTrainingChangeFighter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
              decoration: BoxDecoration(color: const Color(0x1fffffff), borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.fightTrainingChangeFighter, style: const TextStyle(fontSize: 10, color: Color(0x99ffffff), fontWeight: FontWeight.w700)),
                      Text(_char.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(CupertinoIcons.chevron_down, size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(AppLocalizations l10n, {required bool compact}) {
    final look = fightLookOf(SettingsStore.instance.fightLook);
    const gap = SizedBox(width: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final sp in _Speed.values) ...[
                Expanded(
                  child: _Chip(
                    key: ValueKey('training_speed_${sp.name}'),
                    label: sp.label,
                    selected: _speed == sp,
                    onTap: () => setState(() => _speed = sp),
                  ),
                ),
                gap,
              ],
              _Chip(
                key: const ValueKey('training_pause'),
                icon: _paused ? CupertinoIcons.play_fill : CupertinoIcons.pause_fill,
                semantic: _paused ? l10n.fightTrainingPlay : l10n.fightTrainingPause,
                selected: _paused,
                onTap: () => _setPaused(!_paused),
              ),
              gap,
              _Chip(
                key: const ValueKey('training_step'),
                icon: CupertinoIcons.forward_end_fill,
                semantic: l10n.fightTrainingStep,
                enabled: _paused,
                onTap: _stepOneFrame,
              ),
              ValueListenableBuilder<String>(
                valueListenable: _readout,
                builder: (context, t, _) => SizedBox(
                  width: 62,
                  child: Text(
                    t,
                    key: const ValueKey('training_readout'),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xb3ffffff), fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Chip(
                  key: const ValueKey('training_loop'),
                  icon: CupertinoIcons.repeat,
                  label: l10n.fightTrainingLoop,
                  selected: _loop,
                  onTap: () => setState(() => _loop = !_loop),
                ),
              ),
              gap,
              Expanded(
                flex: 3,
                child: _Chip(
                  key: const ValueKey('training_hitboxes'),
                  icon: CupertinoIcons.square_on_square,
                  label: l10n.fightTrainingHitboxes,
                  selected: _boxes,
                  onTap: () {
                    setState(() => _boxes = !_boxes);
                    _frame.value++;
                  },
                ),
              ),
              gap,
              Expanded(
                child: _Chip(
                  key: const ValueKey('training_reset'),
                  icon: CupertinoIcons.arrow_counterclockwise,
                  label: l10n.fightTrainingReset,
                  onTap: _reset,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FightLookPicker(look: look),
        ],
      ),
    );
  }

  /// The frame-data panel and the move list, or (phones) the touch deck.
  Widget _lower(AppLocalizations l10n, {required bool withDeck}) {
    final showDeck = withDeck && _touchFirst && _play;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_touchFirst)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(child: _Chip(key: const ValueKey('training_tab_moves'), label: l10n.fightTrainingMoves, selected: !_play, onTap: () => setState(() => _play = false))),
                const SizedBox(width: 8),
                Expanded(child: _Chip(key: const ValueKey('training_tab_play'), label: l10n.fightTrainingFreePlay, selected: _play, onTap: () => setState(() => _play = true))),
              ],
            ),
          ),
        if (showDeck)
          Expanded(child: _deck(overlay: false))
        else ...[
          Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 6), child: _FrameDataPanel(char: _char, move: _moves[_sel], l10n: l10n, repaint: _frame, state: () => _s)),
          Expanded(child: _MoveList(moves: _moves, selected: _sel, l10n: l10n, onPick: _perform)),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------ painter

/// Holds the overlay's camera across painter rebuilds.
class TrainingCameraHolder {
  FightCamera? cam;
}

/// The fight view plus, on request, the engine's boxes over it.
///
/// The boxes use a [FightCamera] stepped exactly like the renderer's own (same
/// state, same size, same easing, once per paint), so they sit on the art.
class FightTrainingPainter extends CustomPainter {
  FightTrainingPainter({
    required this.renderer,
    required this.cam,
    required this.state,
    required this.look,
    required this.names,
    required this.text,
    required this.boxes,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final FightRenderer renderer;
  final TrainingCameraHolder cam;
  final FightState Function() state;
  final FightLook look;
  final List<String> names;
  final FightHudText text;
  final bool boxes;

  static final Paint _fill = Paint();
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = state();
    renderer.paint(canvas, size, s, look, names, text);
    final c = cam.cam = FightCamera.follow(s, size, cam.cam);
    if (!boxes) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    paintTrainingBoxes(canvas, c, s);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FightTrainingPainter o) => o.look != look || o.renderer != renderer || o.names != names || o.boxes != boxes;
}

Rect _screenRect(FightCamera cam, TrainRect r) =>
    Rect.fromPoints(cam.toScreen(r.l / unitsPerPx, r.t / unitsPerPx), cam.toScreen(r.r / unitsPerPx, r.b / unitsPerPx));

/// Hitboxes red, hurtboxes green (P1) / blue (dummy), pushboxes yellow,
/// projectiles red, traps orange. Exactly the rectangles the engine tests.
@visibleForTesting
void paintTrainingBoxes(Canvas canvas, FightCamera cam, FightState s) {
  void box(TrainRect r, Color color, {double fill = .2, double stroke = .9}) {
    final rect = _screenRect(cam, r);
    if (fill > 0) canvas.drawRect(rect, FightTrainingPainter._fill..color = color.withValues(alpha: fill));
    canvas.drawRect(rect, FightTrainingPainter._stroke..color = color.withValues(alpha: stroke));
  }

  const hit = Color(0xffff3b3b), mine = Color(0xff3bd16f), dummy = Color(0xff3b8bff), push = Color(0xffffd23a), trap = Color(0xffff9d5c);
  for (var i = 0; i < 2; i++) {
    final b = trainingBoxes(s, i);
    final push0 = _screenRect(cam, b.pushbox);
    canvas.drawRect(push0, FightTrainingPainter._stroke..color = push.withValues(alpha: .7));
    for (final h in b.hurt) {
      box(h, i == 0 ? mine : dummy, fill: .16);
    }
    for (final h in b.pendingHit) {
      box(h, hit, fill: 0, stroke: .4);
    }
    for (final h in b.activeHit) {
      box(h, hit, fill: .38, stroke: 1);
    }
  }
  for (final r in trainingProjectileRects(s)) {
    box(r, hit, fill: .38, stroke: 1);
  }
  for (final r in trainingTrapRects(s)) {
    box(r, trap, fill: .22);
  }
}

// ------------------------------------------------------------------ widgets

class _IconBtn extends StatelessWidget {
  const _IconBtn({super.key, required this.icon, required this.onTap, this.semantic});
  final IconData icon;
  final VoidCallback onTap;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onTap,
      semanticLabel: semantic,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: Color(0x33ffffff), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, this.label, this.icon, this.semantic, this.selected = false, this.enabled = true, required this.onTap});
  final String? label;
  final IconData? icon;
  final String? semantic;
  final bool selected, enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? const Color(0xff0b0a12) : Colors.white.withValues(alpha: enabled ? 1 : .35);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: SpringPress(
        onTap: enabled ? onTap : () {},
        semanticLabel: semantic ?? label,
        child: Container(
          height: 38,
          constraints: const BoxConstraints(minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? Colors.white : const Color(0x1fffffff), borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) Icon(icon, size: 16, color: fg),
              if (icon != null && label != null) const SizedBox(width: 6),
              if (label != null)
                Flexible(
                  child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: fg)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _normalLabel(AppLocalizations l, int n) => switch (n) {
  N.standLight => l.fightTrainingMoveStandLight,
  N.standLight2 => l.fightTrainingMoveStandLight2,
  N.standFinisher => l.fightTrainingMoveFinisher,
  N.standHeavy => l.fightTrainingMoveStandHeavy,
  N.crouchLight => l.fightTrainingMoveCrouchLight,
  N.crouchHeavy => l.fightTrainingMoveSweep,
  N.jumpLight => l.fightTrainingMoveJumpLight,
  N.jumpHeavy => l.fightTrainingMoveJumpHeavy,
  N.fwdHeavy => l.fightTrainingMoveFwdHeavy,
  _ => l.fightTrainingMoveThrow,
};

String _moveLabel(AppLocalizations l, TrainMove m) => m.normal != null ? _normalLabel(l, m.normal!) : (m.ex ? '${m.name} EX' : m.name);

class _MoveList extends StatelessWidget {
  const _MoveList({required this.moves, required this.selected, required this.l10n, required this.onPick});
  final List<TrainMove> moves;
  final int selected;
  final AppLocalizations l10n;
  final ValueChanged<int> onPick;

  String _title(TrainGroup g) => switch (g) {
    TrainGroup.normals => l10n.fightTrainingNormals,
    TrainGroup.specials => l10n.fightTrainingSpecials,
    TrainGroup.superMove => l10n.fightTrainingSuper,
    TrainGroup.counters => l10n.fightTrainingCounters,
  };

  @override
  Widget build(BuildContext context) {
    // Group headers interleaved with the rows.
    final items = <Object>[];
    TrainGroup? last;
    for (var i = 0; i < moves.length; i++) {
      if (moves[i].group != last) {
        last = moves[i].group;
        items.add(last);
      }
      items.add(i);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: items.length + 1,
      itemBuilder: (context, k) {
        if (k == items.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l10n.fightTrainingLegend, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0x80ffffff), height: 1.4)),
          );
        }
        final it = items[k];
        if (it is TrainGroup) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(it).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1, color: Color(0xb3ffffff))),
                if (it == TrainGroup.counters)
                  Text(l10n.fightTrainingCounterHint, style: const TextStyle(fontSize: 11.5, color: Color(0x80ffffff))),
              ],
            ),
          );
        }
        final i = it as int;
        final m = moves[i];
        final on = i == selected;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SpringPress(
            key: ValueKey('training_move_$i'),
            onTap: () => onPick(i),
            semanticLabel: _moveLabel(l10n, m),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: on ? const Color(0x26ffd23a) : const Color(0x14ffffff),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? _gold : Colors.transparent, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_moveLabel(l10n, m), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0x26ffffff), borderRadius: BorderRadius.circular(8)),
                    child: Text(m.glyph, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .5, color: Color(0xffd9d4ea))),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FrameDataPanel extends StatelessWidget {
  const _FrameDataPanel({required this.char, required this.move, required this.l10n, required this.repaint, required this.state});
  final CharacterDef char;
  final TrainMove move;
  final AppLocalizations l10n;
  final Listenable repaint;
  final FightState Function() state;

  String _height(BlockHeight h) => switch (h) {
    BlockHeight.high => l10n.fightTrainingHeightHigh,
    BlockHeight.mid => l10n.fightTrainingHeightMid,
    BlockHeight.low => l10n.fightTrainingHeightLow,
    BlockHeight.unblockable => l10n.fightTrainingHeightUnblockable,
  };

  String _flag(TrainFlag f) {
    final base = switch (f.kind) {
      TrainFlagKind.knockdown => l10n.fightTrainingFlagKnockdown,
      TrainFlagKind.launch => l10n.fightTrainingFlagLaunch,
      TrainFlagKind.wallBounce => l10n.fightTrainingFlagWallBounce,
      TrainFlagKind.groundBounce => l10n.fightTrainingFlagGroundBounce,
      TrainFlagKind.projectile => l10n.fightTrainingFlagProjectile,
      TrainFlagKind.grab => l10n.fightTrainingFlagGrab,
      TrainFlagKind.armor => l10n.fightTrainingFlagArmor,
      TrainFlagKind.invulnerable => l10n.fightTrainingFlagInvulnerable,
      TrainFlagKind.invStrike => l10n.fightTrainingFlagInvStrike,
      TrainFlagKind.invThrow => l10n.fightTrainingFlagInvThrow,
      TrainFlagKind.invProjectile => l10n.fightTrainingFlagInvProjectile,
      TrainFlagKind.counter => l10n.fightTrainingFlagCounter,
      TrainFlagKind.trap => l10n.fightTrainingFlagTrap,
    };
    return f.from >= 0 ? '$base ${f.from}–${f.to}' : base;
  }

  @override
  Widget build(BuildContext context) {
    final fd = trainingFrameData(char, move.move);
    String n(int v) => v > 0 ? '$v' : '–';
    final stats = <(String, String)>[
      (l10n.fightTrainingStartup, '${fd.startup}'),
      (l10n.fightTrainingActive, n(fd.active)),
      (l10n.fightTrainingRecovery, '${fd.recovery}'),
      (l10n.fightTrainingDamage, fd.hitsAnything ? '${fd.damage}' : '–'),
      (l10n.fightTrainingHits, fd.hitsAnything ? '${fd.hits}' : '–'),
      (l10n.fightTrainingBlock, fd.hitsAnything ? _height(fd.height) : '–'),
    ];
    return Container(
      key: const ValueKey('training_frame_data'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_moveLabel(l10n, move), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              Text(l10n.fightTrainingFrameData.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8, color: Color(0x80ffffff))),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 12,
            child: CustomPaint(painter: _FrameBarPainter(fd: fd, moveId: move.moveId, state: state, repaint: repaint)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (label, value) in stats)
                Expanded(
                  child: Column(
                    children: [
                      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 2),
                      FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 10.5, color: Color(0x99ffffff), fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
            ],
          ),
          if (fd.flags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in fd.flags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0x1fffffff), borderRadius: BorderRadius.circular(8)),
                    child: Text(_flag(f), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xe6ffffff))),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Startup / active / recovery as a bar, with a playhead while P1 plays it.
class _FrameBarPainter extends CustomPainter {
  _FrameBarPainter({required this.fd, required this.moveId, required this.state, required Listenable repaint}) : super(repaint: repaint);
  final TrainFrameData fd;
  final int moveId;
  final FightState Function() state;

  @override
  void paint(Canvas canvas, Size size) {
    final total = fd.total <= 0 ? 1 : fd.total;
    final segs = [
      (fd.startup, const Color(0xff3fd2c7)),
      (fd.active, const Color(0xffff4f6e)),
      (fd.recovery, const Color(0xff6d6786)),
    ];
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6));
    canvas.save();
    canvas.clipRRect(r);
    var x = 0.0;
    for (final (n, c) in segs) {
      if (n <= 0) continue;
      final w = size.width * n / total;
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), Paint()..color = c);
      x += w;
    }
    canvas.restore();
    final p = state().p[0];
    if (p.state == St.move && p.moveId == moveId) {
      final px = (size.width * p.sf / total).clamp(0.0, size.width - 2).toDouble();
      canvas.drawRect(Rect.fromLTWH(px, -2, 2.5, size.height + 4), Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_FrameBarPainter o) => o.fd != fd || o.moveId != moveId;
}
