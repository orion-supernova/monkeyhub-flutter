import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/moment.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/moment_rail.dart';
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

/// THE way into the points explainer, wherever points are: the Feed's
/// header, the full list's foot, the add-point sheet. One button so the
/// question "what is this?" looks and lands the same everywhere it is asked.
SectionAction pointsExplainerAction(BuildContext context) => SectionAction(
      icon: CupertinoIcons.question_circle,
      label: AppLocalizations.of(context).pointsExplainerOpen,
      onTap: () => showPointsExplainer(context),
    );

/// [pointsExplainerAction] drawn on its own, outside a header.
class PointsExplainerButton extends StatelessWidget {
  const PointsExplainerButton({super.key});

  @override
  Widget build(BuildContext context) =>
      SectionActionButton(pointsExplainerAction(context));
}

class PointsExplainerScreen extends StatelessWidget {
  const PointsExplainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    // The shared pushed page: back chevron top-leading (a plain
    // MaterialPageRoute goes back, it is not dismissed), the large title at
    // the same inset as every other page, and the bar pinned so the way out
    // is reachable from any scroll position.
    return IosPage(
      title: sentenceCaseOf(context, l10n.pointsExplainerTitle),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 22),
          child: Text(
            l10n.pointsExplainerIntro,
            style: theme.body.copyWith(color: theme.inkSoft),
          ),
        ),
        // One grouped block, a coloured tile per kind — the iOS Settings
        // list, which is the shape a reference card like this reads best in.
        // The example rides under the rule in quotes: it is the part that
        // makes it click. An abstract definition of "jinx" teaches nobody;
        // "washed the car, it rained at four" teaches everybody.
        GroupedSection(
          margin: const EdgeInsets.only(bottom: 24),
          children: [
            for (var i = 0; i < MomentTag.values.length; i++)
              GroupedRow(
                key: ValueKey(MomentTag.values[i].wire),
                icon: MomentTagChip.iconFor(MomentTag.values[i]),
                tone: MomentTagChip.toneFor(MomentTag.values[i]),
                title: sentenceCaseOf(
                  context,
                  MomentTagChip.labelFor(l10n, MomentTag.values[i]),
                ),
                subtitle:
                    '${sentenceCaseOf(context, MomentTagChip.hintFor(l10n, MomentTag.values[i]))}\n'
                    '“${MomentTagChip.exampleFor(l10n, MomentTag.values[i])}”',
                chevron: false,
              ),
          ],
        ),
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
          label: l10n.pointsExplainerGotIt,
          onTap: () => Navigator.of(context).maybePop(),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 12),
            child: Icon(icon, size: 20, color: theme.accent),
          ),
          Expanded(
            child: Text(
              sentenceCaseOf(context, text),
              style: groupedFooterStyle(theme).copyWith(color: theme.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
