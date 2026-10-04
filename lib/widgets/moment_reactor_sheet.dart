import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import '../theme/motion.dart';
import 'sheet_kit.dart';
import '../l10n/text_case.dart';

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

    final motion = MotionScope.of(context);
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.reactionDetailsSheetTitle),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The reaction itself lands with a pop — the one playful beat in a
          // sheet that is otherwise a plain list.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: motion.calm ? 1 : 0.4, end: 1),
            duration: motion.d(const Duration(milliseconds: 600)),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Text(
              emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 44),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.reactionDetailsSheetPeopleCount(names.length),
            textAlign: TextAlign.center,
            style: theme.bodySoft.copyWith(color: theme.inkMuted),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: SingleChildScrollView(
                child: SheetGroup(
                  children: [
                    for (var i = 0; i < names.length; i++)
                      SheetRise(
                        index: i.clamp(0, 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Text(
                            names[i],
                            style: theme.body.copyWith(
                              fontSize: 17,
                              color: theme.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
