import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../models/chat_room.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart';
import 'sheet_kit.dart';
import '../l10n/text_case.dart';

enum BlockChoice { cancel, blockOnly, blockAndDelete }

Future<BlockChoice> showBlockChoiceSheet(
  BuildContext context, {
  required String displayName,
  required bool isFriend,
  required List<ChatRoom> sharedGroupRooms,
  required bool hasDm,
  required ChatApi api,
}) async {
  final res = await showAdaptiveSheet<BlockChoice>(
    context,
    builder: (_) => _BlockChoiceSheet(
      displayName: displayName,
      isFriend: isFriend,
      sharedGroupRooms: sharedGroupRooms,
      hasDm: hasDm,
      api: api,
    ),
  );
  return res ?? BlockChoice.cancel;
}

class _BlockChoiceSheet extends StatefulWidget {
  const _BlockChoiceSheet({
    required this.displayName,
    required this.isFriend,
    required this.sharedGroupRooms,
    required this.hasDm,
    required this.api,
  });
  final String displayName;
  final bool isFriend;
  final List<ChatRoom> sharedGroupRooms;
  final bool hasDm;
  final ChatApi api;

  @override
  State<_BlockChoiceSheet> createState() => _BlockChoiceSheetState();
}

class _BlockChoiceSheetState extends State<_BlockChoiceSheet> {
  String _subtitle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final parts = <String>[l10n.bulkActionBarBlockSheetNotNotifiedNote];
    if (widget.isFriend) {
      parts.add(l10n.bulkActionBarBlockSheetFriendWarning);
    } else {
      parts.add(l10n.bulkActionBarBlockSheetStrangerWarning);
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final shared = widget.sharedGroupRooms;

    return SheetFrame(
      title: sentenceCaseOf(context, l10n.bulkActionBarBlockSheetHeaderLabel),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.bulkActionBarBlockSheetTitle(widget.displayName),
              textAlign: TextAlign.center,
              style: theme.displaySmall.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _subtitle(context),
              textAlign: TextAlign.center,
              style: theme.body.copyWith(
                fontSize: 15,
                height: 1.35,
                color: theme.inkMuted,
              ),
            ),

            // ─────────────────── Shared rooms warning ───────────────────
            if (shared.isNotEmpty) ...[
              const SizedBox(height: 14),
              SharedRoomsPanel(
                rooms: shared,
                api: widget.api,
                headline: l10n.bulkActionBarBlockSheetSharedRoomsHeadline(shared.length),
                note: l10n.bulkActionBarBlockSheetSharedRoomsNote,
              ),
            ],

            // ─────────────────── Choices ───────────────────
            const SizedBox(height: 16),
            ChoiceTile(
              color: theme.danger,
              icon: CupertinoIcons.hand_raised_fill,
              title: l10n.bulkActionBarBlockChoiceTileTitle,
              sub: widget.isFriend
                  ? l10n.bulkActionBarBlockChoiceTileFriendSub
                  : l10n.bulkActionBarBlockChoiceTileStrangerSub,
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.of(context).pop(BlockChoice.blockOnly);
              },
            ),
            if (widget.hasDm) ...[
              const SizedBox(height: 10),
              ChoiceTile(
                color: theme.danger,
                filled: true,
                icon: CupertinoIcons.trash_fill,
                title: l10n.bulkActionBarBlockDeleteDmTitle,
                sub: l10n.bulkActionBarBlockDeleteDmSub,
                onTap: () {
                  HapticFeedback.heavyImpact();
                  Navigator.of(context).pop(BlockChoice.blockAndDelete);
                },
              ),
            ],
            const SizedBox(height: 14),
            Center(
              // Autofocused so Enter on a freshly-opened sheet cancels rather
              // than blocking. Tab to reach the block options.
              child: FocusableTap(
                onTap: () => Navigator.of(context).pop(BlockChoice.cancel),
                autofocus: true,
                semanticLabel: l10n.bulkActionBarBlockSheetCancelSemanticLabel,
                radius: theme.radiusMd,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(BlockChoice.cancel),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                    child: Text(
                      sentenceCaseOf(context, l10n.bulkActionBarBlockSheetCancelLabel),
                      style: theme.body.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: theme.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
