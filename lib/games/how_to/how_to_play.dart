/// How to play: a short, swipeable guide where every step comes with a little
/// animated board that actually plays the move.
///
/// ## API
///
/// ```dart
/// // 1. Describe the game: a few steps, each a punchy line + a demo.
/// final guide = HowToPlayGuide(
///   id: 'chat.connectFour',            // stable; keys the "seen" flag
///   title: l10n.gameConnectFourName,
///   steps: [
///     HowToStep(text: l10n.howToC4Drop, demo: const MyDropDemo()),
///     HowToStep(text: l10n.howToC4Tip, demo: const MyTipDemo(), tip: true),
///   ],
///   footnote: l10n.someScoringLine,    // optional quiet line at the bottom
/// );
///
/// // A step can wear a coloured chip ("Live", "Take turns") with
/// // `HowToStep(..., chip: HowToChip(label:, icon:, color: (theme) => ...))`.
///
/// // 2a. Always-available "?" button (e.g. in a game's top bar):
/// HowToPlayButton(onTap: () => showHowToPlay(context, guide));
///
/// // 2b. First time a player opens the game, show it once by itself:
/// showHowToPlayOnce(context, guide);
///
/// // 2c. As the way INTO a game (the main button plays):
/// if (await showHowToPlay(context, guide,
///     actionLabel: l10n.gameInfoPlay, actionIcon: CupertinoIcons.play_fill)) {
///   openGame();
/// }
/// ```
///
/// A demo is a [HowToDemo] (see `demo_kit.dart`): a pure function of loop
/// time that paints one frame, usually by driving the game's real board
/// painter plus [paintFinger] / [paintSparkles] / [paintSpotlight] on top.
/// The daily puzzles' demos live in `daily_demos.dart` and are good
/// templates.
///
/// Opening the sheet in any way marks the guide seen, so a player who read it
/// from the hub never gets it again unprompted when the game opens.
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/sheet_kit.dart';
import 'demo_kit.dart';

export 'demo_kit.dart';

/// Everything a guide says about one game.
class HowToPlayGuide {
  const HowToPlayGuide({
    required this.id,
    required this.title,
    required this.steps,
    this.footnote,
  });

  /// Stable identifier, used for the "already seen" flag.
  final String id;
  final String title;
  final List<HowToStep> steps;

  /// A quiet line under the steps: how you win, what counts.
  final String? footnote;
}

/// A coloured label above a step: what kind of page this is ("Live",
/// "Take turns"). [color] is resolved against the theme at build time.
class HowToChip {
  const HowToChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color Function(AppTheme theme) color;
}

/// One page of a guide.
class HowToStep {
  const HowToStep({
    required this.text,
    required this.demo,
    this.tip = false,
    this.chip,
  });

  /// One or two short sentences. Written like you'd text a friend.
  final String text;
  final HowToDemo demo;

  /// Wears a "Pro tip" chip: not a rule, just how good players do it.
  final bool tip;

  /// Wears this chip instead (a play mode's page, say).
  final HowToChip? chip;
}

/// Opens [guide]. Resolves true when the main button was pressed (as opposed
/// to the ×, a swipe down or a tap outside).
///
/// [actionLabel] defaults to "Got it".
Future<bool> showHowToPlay(
  BuildContext context,
  HowToPlayGuide guide, {
  String? actionLabel,
  IconData? actionIcon,
}) async {
  HowToPlaySeen.mark(guide.id);
  final go = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _HowToPlaySheet(
      guide: guide,
      actionLabel: actionLabel,
      actionIcon: actionIcon,
    ),
  );
  return go == true;
}

/// Shows [guide] if this device has never shown it. Resolves true when it
/// was shown.
Future<bool> showHowToPlayOnce(
  BuildContext context,
  HowToPlayGuide guide,
) async {
  if (await HowToPlaySeen.seen(guide.id)) return false;
  if (!context.mounted) return false;
  await showHowToPlay(context, guide);
  return true;
}

/// Per-device "has this guide been shown" flags.
abstract final class HowToPlaySeen {
  static const _prefix = 'howToPlay.seen.';
  static final _memo = <String>{};

  static Future<bool> seen(String id) async {
    if (_memo.contains(id)) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hit = prefs.getBool('$_prefix$id') ?? false;
      if (hit) _memo.add(id);
      return hit;
    } catch (_) {
      // No storage, no nagging: better to skip a guide than to show it every
      // single time.
      return true;
    }
  }

  static void mark(String id) {
    if (!_memo.add(id)) return;
    SharedPreferences.getInstance()
        .then((p) => p.setBool('$_prefix$id', true))
        .ignore();
  }

  @visibleForTesting
  static void resetForTest() => _memo.clear();
}

/// The "?" that opens a guide from a game's top bar.
class HowToPlayButton extends StatelessWidget {
  const HowToPlayButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassIconButton(
    icon: CupertinoIcons.question,
    iconSize: 18,
    semanticLabel: AppLocalizations.of(context).gameInfoOpen,
    onTap: onTap,
  );
}

class _HowToPlaySheet extends StatefulWidget {
  const _HowToPlaySheet({
    required this.guide,
    required this.actionLabel,
    required this.actionIcon,
  });

  final HowToPlayGuide guide;
  final String? actionLabel;
  final IconData? actionIcon;

  @override
  State<_HowToPlaySheet> createState() => _HowToPlaySheetState();
}

class _HowToPlaySheetState extends State<_HowToPlaySheet> {
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    final steps = widget.guide.steps.length;
    final to = page.clamp(0, steps - 1);
    final motion = MotionScope.of(context);
    if (motion.calm) {
      _pages.jumpToPage(to);
    } else {
      _pages.animateToPage(
        to,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final guide = widget.guide;
    final steps = guide.steps;
    final step = steps[_page];
    final last = _page == steps.length - 1;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _go(_page + (Directionality.of(context) == TextDirection.rtl
                ? -1
                : 1)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _go(_page + (Directionality.of(context) == TextDirection.rtl
                ? 1
                : -1)),
      },
      child: SheetFrame(
        title: sentenceCaseOf(context, guide.title),
        onClose: () => Navigator.of(context).maybePop(false),
        padding: EdgeInsets.zero,
        footer: SheetActionButton(
          label: widget.actionLabel ?? l10n.howToGotIt,
          icon: widget.actionIcon,
          autofocus: true,
          onTap: () => Navigator.of(context).maybePop(true),
        ),
        child: SheetScrollBody(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final side = box.maxWidth.clamp(180.0, 300.0);
                  return Center(
                    child: Container(
                      width: box.maxWidth,
                      height: side,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: sheetGroupFill(theme),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: steps.length,
                        onPageChanged: (i) {
                          HapticFeedback.selectionClick();
                          setState(() => _page = i);
                        },
                        itemBuilder: (_, i) => Semantics(
                          label: l10n.howToStepSemantic(i + 1, steps.length),
                          child: ExcludeSemantics(
                            child: _DemoStage(
                              demo: steps[i].demo,
                              active: i == _page,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              // Calm motion swaps the line in place: a zero-length
              // AnimatedSize re-dirties itself mid-layout.
              if (motion.calm)
                _StepText(key: ValueKey(_page), step: step, theme: theme)
              else
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(a),
                        child: child,
                      ),
                    ),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: _StepText(
                      key: ValueKey(_page),
                      step: step,
                      theme: theme,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Dots(count: steps.length, page: _page),
                  ),
                  if (steps.length > 1)
                    _NextPill(
                      label: last ? l10n.howToWatchAgain : l10n.howToNext,
                      icon: last
                          ? CupertinoIcons.arrow_counterclockwise
                          : CupertinoIcons.chevron_forward,
                      onTap: () => _go(last ? 0 : _page + 1),
                    ),
                ],
              ),
              if (guide.footnote != null) ...[
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        CupertinoIcons.rosette,
                        size: 15,
                        color: theme.accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        guide.footnote!,
                        style: groupedFooterStyle(theme),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText({super.key, required this.step, required this.theme});

  final HowToStep step;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (step.chip case final chip?) ...[
          Builder(
            builder: (context) {
              final c = chip.color(theme);
              return Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(c, Colors.white, 0.14)!, c],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chip.icon, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      chip.label,
                      style: groupedMetaStyle(theme).copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ] else if (step.tip) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC53D).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.lightbulb_fill,
                  size: 13,
                  color: Color(0xFFE0A100),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.howToProTip,
                  style: groupedMetaStyle(theme).copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB98500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        ConstrainedBox(
          // Two lines' worth, so one-liners don't make the row below hop.
          constraints: const BoxConstraints(minHeight: 50),
          child: Text(
            step.text,
            textAlign: TextAlign.center,
            style: theme.bodyEmph.copyWith(
              fontSize: 19,
              height: 1.3,
              color: theme.ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// Page dots: the current one stretches into a pill.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});

  final int count;
  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    if (count < 2) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: motion.d(const Duration(milliseconds: 300)),
            curve: Curves.easeOutBack,
            margin: const EdgeInsetsDirectional.only(end: 6),
            width: i == page ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == page
                  ? theme.accent
                  : theme.ink.withValues(alpha: i < page ? 0.32 : 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _NextPill extends StatelessWidget {
  const _NextPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      focusShape: FocusRingShape.capsule,
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: groupedMetaStyle(theme).copyWith(
                color: theme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 13, color: theme.accent),
          ],
        ),
      ),
    );
  }
}

/// One looping demo. Only the page on screen ticks; the others hold a still
/// frame, so swiping shows the next picture without running every demo in
/// the guide at once.
class _DemoStage extends StatefulWidget {
  const _DemoStage({required this.demo, required this.active});

  final HowToDemo demo;
  final bool active;

  @override
  State<_DemoStage> createState() => _DemoStageState();
}

class _DemoStageState extends State<_DemoStage>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: widget.demo.period,
  );
  var _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MotionScope.of(context).calm;
    _sync();
  }

  @override
  void didUpdateWidget(_DemoStage old) {
    super.didUpdateWidget(old);
    if (old.demo != widget.demo) _clock.duration = widget.demo.period;
    if (old.active != widget.active) _sync(restart: widget.active);
  }

  void _sync({bool restart = false}) {
    if (widget.active && !_calm) {
      if (restart) _clock.value = 0;
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final still = _calm || !widget.active;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _DemoPainter(
          demo: widget.demo,
          theme: theme,
          clock: _clock,
          still: still,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DemoPainter extends CustomPainter {
  _DemoPainter({
    required this.demo,
    required this.theme,
    required this.clock,
    required this.still,
  }) : super(repaint: still ? null : clock);

  final HowToDemo demo;
  final AppTheme theme;
  final Animation<double> clock;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? demo.still : clock.value;
    final frame = DemoFrame(
      theme: theme,
      size: size,
      t: t,
      periodMs: demo.period.inMilliseconds.toDouble(),
    );
    // The loop's seam: the finished board fades out and the empty one fades
    // in, rather than everything snapping back to the start.
    final fade = still
        ? 1.0
        : t > 0.94
        ? (1 - (t - 0.94) / 0.06)
        : t < 0.03
        ? t / 0.03
        : 1.0;
    if (fade < 1) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, fade.clamp(0.0, 1.0)),
      );
      demo.paint(canvas, frame);
      canvas.restore();
    } else {
      demo.paint(canvas, frame);
    }
  }

  @override
  bool shouldRepaint(_DemoPainter old) =>
      old.demo != demo ||
      old.theme != theme ||
      old.still != still ||
      old.clock != clock;
}
