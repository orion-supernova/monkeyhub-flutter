import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart';

/// "2 mistakes · 1 hint", or null on a clean run.
///
/// The one spelling of a finished game's advisory stats, wherever they show:
/// the finish screen, the Feed's Activity, anything after. Advisory, never
/// ranked on: mistakes are counted on the player's phone, so they are shown
/// and never sorted by.
///
/// A clean run says nothing at all rather than "0 mistakes". Most runs are
/// clean, and a badge on the common case is noise; the absence is the mark.
String? gameStatText(
  AppLocalizations l10n, {
  required int mistakes,
  required int hints,
}) {
  final parts = [
    if (mistakes > 0) l10n.gameMistakeCount(mistakes),
    if (hints > 0) l10n.gameHintCount(hints),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// [gameStatText] as a line of meta text; nothing at all on a clean run.
class GameStatLine extends StatelessWidget {
  const GameStatLine({
    super.key,
    required this.mistakes,
    required this.hints,
    this.textAlign = TextAlign.start,
  });

  final int mistakes;
  final int hints;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final text = gameStatText(
      AppLocalizations.of(context),
      mistakes: mistakes,
      hints: hints,
    );
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      textAlign: textAlign,
      style: groupedMetaStyle(ThemeScope.of(context)),
    );
  }
}
