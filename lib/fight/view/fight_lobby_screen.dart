import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/ios_kit.dart';
import '../core/bot.dart' as fb;
import '../core/core.dart';
import 'art/fight_art.dart';
import 'fight_renderer.dart';
import 'fight_character_grid.dart';
import 'fight_screen.dart';

/// Jungle Fist's setup page, opened from Play the bot: a live bot-vs-bot
/// demo up top, the fighter, and the three looks, each previewed live.
///
/// One demo fight drives every preview, so the three look cards show the
/// same moment drawn three ways, which is the whole point of the choice.
class FightLobbyScreen extends StatefulWidget {
  const FightLobbyScreen({super.key, required this.level});

  /// From the bot hub's level picker.
  final fb.BotLevel level;

  @override
  State<FightLobbyScreen> createState() => _FightLobbyScreenState();
}

class _FightLobbyScreenState extends State<FightLobbyScreen> with SingleTickerProviderStateMixin {
  static const Duration _step = Duration(microseconds: 16667);

  late FightState _demo;
  final fb.FightBot _b1 = fb.FightBot(seed: 11, level: fb.BotLevel.hard);
  final fb.FightBot _b2 = fb.FightBot(seed: 23, level: fb.BotLevel.hard);
  final ValueNotifier<int> _frame = ValueNotifier(0);

  /// The look cards are STILL frames of the demo, taken mid-fight and
  /// refreshed each bout: one live renderer (the hero) instead of four.
  FightState? _still;
  final ValueNotifier<int> _stillTick = ValueNotifier(0);
  final FightRenderer _hero = FightRenderer();
  final Map<FightLook, FightRenderer> _previews = {for (final l in FightLook.values) l: FightRenderer()};
  late final Ticker _ticker;
  Duration _last = Duration.zero, _acc = Duration.zero;
  int _seed = 7, _overFrames = 0;

  @override
  void initState() {
    super.initState();
    FightRenderer.warmUp();
    _resetDemo();
    _ticker = createTicker(_tick)..start();
    SettingsStore.instance.addListener(_onSettings);
  }

  void _resetDemo() {
    _seed = (_seed * 48271) % 2147483647;
    _still = null;
    // The demo shows your pick against a different fighter each bout.
    final me = fightCharOf(SettingsStore.instance.fightChar);
    var other = _seed % roster.length;
    if (other == me) other = (other + 1) % roster.length;
    _demo = FightState.initial(seed: _seed, p1: roster[me], p2: roster[other]);
    _b1.reset();
    _b2.reset();
    _hero.resetCamera();
    for (final r in _previews.values) {
      r.resetCamera();
    }
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _tick(Duration now) {
    var dt = now - _last;
    _last = now;
    if (dt > const Duration(milliseconds: 100)) dt = const Duration(milliseconds: 100);
    _acc += dt;
    var stepped = false;
    while (_acc >= _step) {
      _acc -= _step;
      step(_demo, _b1.decide(_demo, 0), _b2.decide(_demo, 1));
      stepped = true;
    }
    if (!stepped) return;
    // Hold the result for three seconds, then a fresh demo bout.
    _overFrames = _demo.phase == Phase.over ? _overFrames + 1 : 0;
    if (_overFrames > 180) _resetDemo();
    _frame.value = _demo.frame;
    // A moment with both fighters busy makes the best card.
    if (_still == null && _demo.phase == Phase.fight && _demo.frame >= 200) {
      _still = _demo.copy();
      _stillTick.value++;
      // Once more after the pixel palette (built asynchronously) is ready.
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _stillTick.value++;
      });
    }
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    _ticker.dispose();
    _hero.dispose();
    for (final r in _previews.values) {
      r.dispose();
    }
    _frame.dispose();
    _stillTick.dispose();
    super.dispose();
  }

  void _fight() {
    final me = fightCharOf(SettingsStore.instance.fightChar);
    // The bot takes a random fighter (never a mirror, unless there's one).
    var foe = DateTime.now().microsecondsSinceEpoch % roster.length;
    if (foe == me && roster.length > 1) foe = (foe + 1) % roster.length;
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FightScreen(player: roster[me], opponent: roster[foe], level: widget.level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final look = fightLookOf(SettingsStore.instance.fightLook);
    final text = fightHudText(l10n);
    final names = [_demo.chars[0].name, _demo.chars[1].name];

    Widget view(FightRenderer r, FightLook l, {bool still = false}) => CustomPaint(
      painter: FightPainter(
        renderer: r,
        state: still ? () => _still ?? _demo : () => _demo,
        look: l,
        names: names,
        text: text,
        repaint: still ? _stillTick : _frame,
      ),
      child: const SizedBox.expand(),
    );

    return IosPage(
      title: l10n.fightTitle,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(groupedRadius(theme) + 4),
          child: AspectRatio(aspectRatio: 16 / 10, child: RepaintBoundary(child: view(_hero, look))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Text(l10n.fightLobbyIntro, style: theme.body.copyWith(color: theme.inkSoft, height: 1.35)),
        ),
        const SizedBox(height: 24),
        GroupedHeader(sentenceCaseOf(context, l10n.fightFighterTitle)),
        FightCharacterGrid(
          selected: fightCharOf(SettingsStore.instance.fightChar),
          look: look,
          onPick: (id) {
            SettingsStore.instance.setFightChar(id);
            _resetDemo();
          },
        ),
        const SizedBox(height: 24),
        GroupedHeader(sentenceCaseOf(context, l10n.fightLookTitle)),
        Row(
          children: [
            for (final (i, l) in FightLook.values.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _LookCard(
                  key: ValueKey('fight_look_${l.name}'),
                  label: switch (l) {
                    FightLook.cartoon => l10n.fightLookCartoon,
                    FightLook.painted => l10n.fightLookPainted,
                    FightLook.pixel => l10n.fightLookPixel,
                  },
                  selected: l == look,
                  preview: RepaintBoundary(child: view(_previews[l]!, l, still: true)),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    SettingsStore.instance.setFightLook(fightLookWire(l));
                  },
                ),
              ),
            ],
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(sentenceCaseOf(context, l10n.fightLookFootnote), style: groupedFooterStyle(theme)),
        ),
        const SizedBox(height: 28),
        SpringPress(
          key: const ValueKey('fight_start'),
          onTap: _fight,
          semanticLabel: l10n.fightStart,
          child: Container(
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xffffcf6e), Color(0xffff8a3d), Color(0xffff4f6e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(groupedRadius(theme) + 4),
              boxShadow: const [BoxShadow(color: Color(0x55ff6a3d), blurRadius: 24, offset: Offset(0, 10))],
            ),
            child: Text(
              l10n.fightStart,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xff1b0d02), letterSpacing: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard({super.key, required this.label, required this.selected, required this.preview, required this.onTap});
  final String label;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final r = groupedRadius(theme) + 2;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SpringPress(
        onTap: onTap,
        haptic: false,
        scale: 0.95,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: groupedFill(theme),
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: selected ? const Color(0xffff8a3d) : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(r - 4),
                child: AspectRatio(aspectRatio: 16 / 10, child: preview),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyEmph.copyWith(fontSize: 14.5, color: selected ? theme.ink : theme.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
