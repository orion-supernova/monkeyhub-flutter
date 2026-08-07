import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;

/// Long-press a moment's reaction pill and this names the people behind it.
///
/// Text-first, matching [PointsBoard]'s own philosophy: no avatar fetch, no
/// profile navigation, just the names — they're already sitting on the
/// [Moment] the pill was built from, denormalized there for exactly this.
Future<void> showMomentReactorSheet(
  BuildContext context, {
  required String emoji,
  required List<String> names,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => _MomentReactorSheet(emoji: emoji, names: names),
  );
}

class _MomentReactorSheet extends StatelessWidget {
  const _MomentReactorSheet({required this.emoji, required this.names});

  final String emoji;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: theme.sheetDecoration(),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        22 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetGrabber(),
          Text(
            l10n.reactionDetailsSheetTitle,
            textAlign: TextAlign.center,
            style: theme.label.copyWith(letterSpacing: 2.4),
          ),
          const SizedBox(height: 10),
          Text(emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 4),
          Text(
            l10n.reactionDetailsSheetPeopleCount(names.length),
            textAlign: TextAlign.center,
            style: theme.monoTiny,
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: names.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    names[i],
                    style: theme.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
