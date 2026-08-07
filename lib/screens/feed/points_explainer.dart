import 'package:flutter/material.dart';

import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/moment.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/glass_close_button.dart';
import '../../widgets/moment_rail.dart';

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
          SafeArea(
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
                            l10n.pointsExplainerTitle,
                            style: theme.displaySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.pointsExplainerIntro,
                            style: theme.body.copyWith(color: theme.inkSoft),
                          ),
                          const SizedBox(height: 22),
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
                              child: _TagExplainer(tag: MomentTag.values[i]),
                            ),
                          const SizedBox(height: 8),
                          Container(height: 1, color: theme.divider),
                          const SizedBox(height: 16),
                          _Rule(text: l10n.pointsExplainerRuleHonour),
                          const SizedBox(height: 10),
                          _Rule(text: l10n.pointsExplainerRuleToday),
                          const SizedBox(height: 10),
                          _Rule(text: l10n.pointsExplainerRuleCap),
                          const SizedBox(height: 20),
                          FocusableTap(
                            onTap: () => Navigator.of(context).maybePop(),
                            semanticLabel: l10n.pointsExplainerGotIt,
                            radius: theme.radiusMd,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).maybePop(),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.accent,
                                  borderRadius: BorderRadius.circular(
                                    theme.radiusMd,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  l10n.pointsExplainerGotIt,
                                  style: theme.label.copyWith(
                                    color: theme.accentInk,
                                  ),
                                ),
                              ),
                            ),
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

class _TagExplainer extends StatelessWidget {
  const _TagExplainer({required this.tag});

  final MomentTag tag;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.accentSoft,
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            alignment: Alignment.center,
            child: Icon(
              MomentTagChip.iconFor(tag),
              size: 15,
              color: theme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(MomentTagChip.labelFor(l10n, tag), style: theme.label),
                const SizedBox(height: 3),
                Text(MomentTagChip.hintFor(l10n, tag), style: theme.body),
                const SizedBox(height: 3),
                // The example is the part that makes it click. An abstract
                // definition of "jinx" teaches nobody; "washed the car, it
                // rained at four" teaches everybody.
                Text(
                  MomentTagChip.exampleFor(l10n, tag),
                  style: theme.monoTiny.copyWith(color: theme.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 10),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
            ),
          ),
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
