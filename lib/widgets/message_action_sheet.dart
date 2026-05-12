import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme_scope.dart';

enum MessageAction { react, copy, delete }

Future<MessageAction?> showMessageActionSheet(
  BuildContext context, {
  required bool isMine,
  required bool canCopy,
}) {
  return showModalBottomSheet<MessageAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ActionSheet(isMine: isMine, canCopy: canCopy),
  );
}

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.isMine, required this.canCopy});
  final bool isMine;
  final bool canCopy;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final items = <(MessageAction, IconData, String, String, bool)>[
      (MessageAction.react, Icons.add_reaction_outlined, 'REACT', 'send an emoji', false),
      if (canCopy) (MessageAction.copy, Icons.copy_outlined, 'COPY', 'copy text to clipboard', false),
      if (isMine) (MessageAction.delete, Icons.delete_outline, 'DELETE', 'remove for everyone', true),
    ];
    return Container(
      decoration: theme.sheetDecoration(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.inkMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          for (final o in items)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(o.$1);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.surface,
                  border: Border.all(color: theme.divider),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: o.$5 ? theme.danger.withValues(alpha: 0.15) : theme.accentSoft,
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: Icon(o.$2, size: 18, color: o.$5 ? theme.danger : theme.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.$3,
                          style: theme.label.copyWith(color: o.$5 ? theme.danger : theme.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(o.$4, style: theme.monoTiny),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_outward, size: 14, color: theme.inkMuted),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
