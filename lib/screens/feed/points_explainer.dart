import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/moment.dart';
import '../../theme/layout.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/moment_rail.dart';
import '../../widgets/sheet_kit.dart';
import '../../l10n/text_case.dart';

/// Explains what the points board actually is.
///
/// This exists because the concept is genuinely new. Nobody has met "kerizlik
/// points" before — it is a game a specific group of friends invented, and no
/// amount of tasteful iconography will convey "you washed the car and then it
/// rained, so that's a point against you" to someone seeing a tally for the
/// first time. Every category therefore gets its name, its one-line rule, and a
/// concrete example, because the example is the part that makes it click.
///
/// Reachable from the board's POINTS header and from the composer, which are
/// the two places the question occurs.
///
/// A full-screen route rather than a bottom sheet. As a sheet this had no
/// height cap, no safe area and no close button: five category explainers and
/// three rules ran up under the status bar, and the only way out was a "GOT IT"
/// you had to scroll past all of them to reach. The content is a page's worth,
/// so it gets a page.
///
/// Pushing from inside the composer's own sheet is safe — `showAdaptiveSheet`
/// uses `useRootNavigator: false`, so both live on the same navigator and
/// popping returns to the composer with its state intact.
Future<void> showPointsExplainer(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const PointsExplainerScreen()),
  );
}

class PointsExplainerScreen extends StatelessWidget {
  const PointsExplainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // See home_screen: the bottom inset leaves a dead strip of
          // background under the scroller, which reads as a solid bar. The
          // list clears the home indicator with its own padding instead.
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pinned, so the way out is reachable from any scroll
                  // position rather than only from the very bottom.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            sentenceCaseOf(context, l10n.pointsExplainerTitle),
                            style: theme.displayLarge.copyWith(
                              letterSpacing: 0.37,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // An X, not the archive's back arrow: this is a modal
                        // explainer you dismiss, not a place you navigated to.
                        GlassCloseButton(
                          onTap: () => Navigator.of(context).maybePop(),
                          semanticLabel: l10n.photoChromeCloseSemanticLabel,
                          size: 34,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        edgeToEdgeBottom(context, 40),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.pointsExplainerIntro,
                            style: theme.body.copyWith(color: theme.inkSoft),
                          ),
                          const SizedBox(height: 22),
                          // One grouped block, a coloured tile per kind —
                          // the iOS Settings list, which is the shape a
                          // reference card like this reads best in.
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              groupedRadius(theme),
                            ),
                            child: ColoredBox(
                              color: groupedFill(theme),
                              child: Column(
                                children: [
                          for (var i = 0; i < MomentTag.values.length; i++)
                            TweenAnimationBuilder<double>(
                              key: ValueKey(MomentTag.values[i].wire),
                              tween: Tween(begin: 0, end: 1),
                              duration: motion.stagger(
                                theme.motionMed,
                                i,
                                strideMs: 55,
                              ),
                              curve: motion.c(theme.motionEntrance),
                              builder: (context, v, child) =>
                                  Transform.translate(
                                    offset: Offset(0, (1 - v) * 10),
                                    child: Opacity(
                                      opacity: v.clamp(0.0, 1.0),
                                      child: child,
                                    ),
                                  ),
                              child: _TagExplainer(
                                tag: MomentTag.values[i],
                                tone: _tones[i % _tones.length],
                                last: i == MomentTag.values.length - 1,
                              ),
                            ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _Rule(
                            icon: CupertinoIcons.hand_thumbsup_fill,
                            text: l10n.pointsExplainerRuleHonour,
                          ),
                          const SizedBox(height: 12),
                          _Rule(
                            icon: CupertinoIcons.sunrise_fill,
                            text: l10n.pointsExplainerRuleToday,
                          ),
                          const SizedBox(height: 12),
                          _Rule(
                            icon: CupertinoIcons.number_circle_fill,
                            text: l10n.pointsExplainerRuleCap,
                          ),
                          const SizedBox(height: 28),
                          SheetActionButton(
                            label: sentenceCaseOf(
                              context,
                              l10n.pointsExplainerGotIt,
                            ),
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One tile colour per kind, in [MomentTag.values] order: fate, jinx, luck,
/// called it, NPC.
const _tones = [
  TileTone.purple,
  TileTone.orange,
  TileTone.green,
  TileTone.blue,
  TileTone.gray,
];

class _TagExplainer extends StatelessWidget {
  const _TagExplainer({
    required this.tag,
    required this.tone,
    required this.last,
  });

  final MomentTag tag;
  final TileTone tone;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tileColor(theme, tone),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  MomentTagChip.iconFor(tag),
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentenceCaseOf(context, MomentTagChip.labelFor(l10n, tag)),
                      style: theme.bodyEmph.copyWith(color: theme.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sentenceCaseOf(context, MomentTagChip.hintFor(l10n, tag)),
                      style: theme.body.copyWith(color: theme.inkSoft),
                    ),
                    const SizedBox(height: 4),
                    // The example is the part that makes it click. An
                    // abstract definition of "jinx" teaches nobody; "washed
                    // the car, it rained at four" teaches everybody.
                    Text(
                      '“${MomentTagChip.exampleFor(l10n, tag)}”',
                      style: theme.bodySoft.copyWith(
                        fontSize: 14,
                        color: theme.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Padding(
            padding: const EdgeInsets.only(left: 58),
            child: Container(
              height: 1 / MediaQuery.devicePixelRatioOf(context),
              color: theme.ink.withValues(alpha: 0.10),
            ),
          ),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, right: 12),
          child: Icon(icon, size: 20, color: theme.accent),
        ),
        Expanded(
          child: Text(
            text,
            style: theme.bodySoft.copyWith(color: theme.inkSoft),
          ),
        ),
      ],
    );
  }
}
