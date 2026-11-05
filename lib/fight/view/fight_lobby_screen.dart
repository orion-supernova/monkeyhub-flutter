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
import 'fight_screen.dart';
import 'fighter_portrait.dart';

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
    _demo = FightState.initial(seed: _seed, p1: roster[0], p2: roster[0]);
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
    super.dispose();
  }

  void _fight() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FightScreen(player: roster[0], opponent: roster[0], level: widget.level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final look = fightLookOf(SettingsStore.instance.fightLook);
    final text = fightHudText(l10n);
    final names = [roster[0].name, roster[0].name];

    Widget view(FightRenderer r, FightLook l) => CustomPaint(
      painter: FightPainter(renderer: r, state: () => _demo, look: l, names: names, text: text, repaint: _frame),
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
        _FighterRow(comingSoon: l10n.fightComingSoon),
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
                  preview: RepaintBoundary(child: view(_previews[l]!, l)),
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

/// KAI is playable; the other starters show as "coming soon" until their art
/// exists (the engine already plays them).
class _FighterRow extends StatelessWidget {
  const _FighterRow({required this.comingSoon});
  final String comingSoon;

  static const _tones = [
    [Color(0xff1fb5a8), Color(0xff0c3d3a)],
    [Color(0xffc8642a), Color(0xff3d1a08)],
    [Color(0xff6b7a8f), Color(0xff1e2430)],
    [Color(0xff7b5cff), Color(0xff1d1240)],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        for (final (i, c) in roster.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Opacity(
              opacity: i == 0 ? 1 : 0.55,
              child: Container(
                height: 132,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _tones[i], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(groupedRadius(theme)),
                  border: Border.all(color: i == 0 ? const Color(0xffff8a3d) : Colors.transparent, width: 2),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(bottom: 18, child: FighterPortrait(charId: c.id, glow: _tones[i][0])),
                    Positioned(
                      left: 8,
                      right: 6,
                      top: 6,
                      child: i == 0
                          ? const SizedBox.shrink()
                          : Text(
                              comingSoon,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xe6ffffff)),
                            ),
                    ),
                    Positioned(
                      left: 8,
                      right: 6,
                      bottom: 6,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
