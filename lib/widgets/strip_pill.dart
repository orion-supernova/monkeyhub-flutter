import 'package:flutter/material.dart';

import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';

/// The gutter and corner of a frosted strip under the room header: the pinned
/// message, a suggestion waiting for review, the room's open games. One pair,
/// so the strips read as one family when they stack.
const double kStripGlassGutter = 16.0;
const double kStripGlassRadius = 22.0;

/// The action word at the end of a strip ("Review", "Play"), drawn as a pill.
///
/// RowPillButton's look, drawn static: the whole strip is the tap target, so
/// this is a label shaped like the action, not a second button. [prominent]
/// fills it with the accent for something asking for you now; otherwise it is
/// a quiet tint that names the action without shouting it.
class StripPill extends StatelessWidget {
  const StripPill({super.key, required this.label, this.prominent = true});

  final String label;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: prominent ? theme.accent : theme.ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Text(
          sentenceCaseOf(context, label),
          style: theme.bodySoft.copyWith(
            fontSize: 15,
            color: prominent ? theme.accentInk : theme.ink,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
