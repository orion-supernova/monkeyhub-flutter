import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/enums.dart';
import '../models/family.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart';
import 'sheet_kit.dart';
import 'ios_kit.dart' show groupedRadius;
import '../l10n/text_case.dart';

/// Confirms taking a person away from a child, spelling out what gets deleted.
///
/// Removing a contact wipes the conversation for BOTH of them — that's the
/// point (the child shouldn't keep the history of someone they're no longer
/// allowed to talk to) but it's destructive to the other person's data too,
/// so it never happens without this.
///
/// Callers skip this entirely when [preview] `isEmpty` — asking "are you sure?"
/// about nothing is just friction.
///
/// Returns true when the parent confirmed.
Future<bool> showRemoveContactSheet(
  BuildContext context, {
  required String contactName,
  required String childName,
  required ContactRemovalPreview preview,
  required ChatApi api,
}) async {
  final res = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _RemoveContactSheet(
      contactName: contactName,
      childName: childName,
      preview: preview,
      api: api,
    ),
  );
  return res ?? false;
}

class _RemoveContactSheet extends StatelessWidget {
  const _RemoveContactSheet({
    required this.contactName,
    required this.childName,
    required this.preview,
    required this.api,
  });

  final String contactName;
  final String childName;
  final ContactRemovalPreview preview;
  final ChatApi api;

  String _chatsPhrase(BuildContext context) {
    return AppLocalizations.of(
      context,
    ).incomingGroupCallScreenRemoveContactSheetChatsCount(preview.dmCount);
  }

  String _messagesPhrase(BuildContext context) {
    return AppLocalizations.of(
      context,
    ).incomingGroupCallScreenRemoveContactSheetMessagesCount(
      preview.messageCount,
    );
  }

  /// "last message 3 days ago" — makes "active" concrete, which is the whole
  /// reason a parent wants warning before this happens.
  String? _lastSeenPhrase(BuildContext context) {
    final at = preview.lastMessageAt;
    if (at == null) return null;
    final l10n = AppLocalizations.of(context);
    final ago = DateTime.now().difference(at);
    if (ago.inMinutes < 60) {
      return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageJustNow;
    }
    if (ago.inHours < 24) {
      return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
        ago.inHours,
      );
    }
    if (ago.inDays == 1) {
      return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageYesterday;
    }
    if (ago.inDays < 30) {
      return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
        ago.inDays,
      );
    }
    return l10n.incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    // RoomBrief carries only what the queue needs; SharedRoomsPanel renders
    // ChatRoom, so adapt rather than duplicating the row widget.
    final shared = preview.sharedGroupRooms
        .map(
          (r) => ChatRoom(
            id: r.id,
            name: r.name,
            createdBy: '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            isPrivate: false,
            memberCount: r.memberCount,
            avatarStorageId: r.avatarStorageId,
            type: RoomType.regular,
          ),
        )
        .toList();
    final hasChats = preview.dmCount > 0;
    final messagesPhrase = _messagesPhrase(context);
    final lastSeenPhrase = _lastSeenPhrase(context);

    return SheetFrame(
      title: sentenceCaseOf(
        context,
        l10n.incomingGroupCallScreenRemoveContactSheetTitleBadge,
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              // Positional args must follow alphabetical placeholder order
              // ("childName" < "contactName") — gen-l10n sorts undeclared
              // placeholders alphabetically for the generated signature.
              l10n.incomingGroupCallScreenRemoveContactSheetHeadline(
                childName,
                contactName,
              ),
              textAlign: TextAlign.center,
              style: theme.displaySmall.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasChats
                  ? l10n.incomingGroupCallScreenRemoveContactSheetBodyWithChats
                  : l10n.incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
                      contactName,
                    ),
              textAlign: TextAlign.center,
              style: theme.body.copyWith(
                fontSize: 15,
                height: 1.35,
                color: theme.inkMuted,
              ),
            ),

            // ─────────────────── What gets destroyed ───────────────────
            if (hasChats) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: theme.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(groupedRadius(theme)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.trash_fill,
                          size: 15,
                          color: theme.danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.incomingGroupCallScreenRemoveContactSheetDeletionSummary(
                              _chatsPhrase(context),
                              messagesPhrase,
                            ),
                            style: theme.bodyEmph.copyWith(
                              fontSize: 15,
                              fontStyle: FontStyle.normal,
                              color: theme.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.incomingGroupCallScreenRemoveContactSheetDeletionDetail,
                      style: theme.caption.copyWith(
                        fontSize: 13,
                        color: theme.inkMuted,
                      ),
                    ),
                    if (lastSeenPhrase != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        lastSeenPhrase,
                        style: theme.caption.copyWith(
                          fontSize: 13,
                          color: theme.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // ─────────────────── Rooms that survive ───────────────────
            if (shared.isNotEmpty) ...[
              const SizedBox(height: 12),
              SharedRoomsPanel(
                rooms: shared,
                api: api,
                headline: l10n
                    .incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
                      shared.length,
                    ),
                note: l10n
                    .incomingGroupCallScreenRemoveContactSheetSharedRoomsNote,
              ),
            ],

            const SizedBox(height: 16),
            ChoiceTile(
              color: theme.danger,
              filled: true,
              icon: CupertinoIcons.person_badge_minus_fill,
              title: hasChats
                  ? l10n.incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete
                  : l10n.incomingGroupCallScreenRemoveContactSheetTitleBadge,
              sub: hasChats
                  ? l10n.incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
                      contactName,
                      messagesPhrase,
                    )
                  : l10n.incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
                      contactName,
                    ),
              onTap: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 14),
            Center(
              // Autofocused so Enter cancels rather than removing. Tab to
              // reach the destructive option.
              child: FocusableTap(
                onTap: () => Navigator.of(context).pop(false),
                autofocus: true,
                semanticLabel: l10n
                    .incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel,
                radius: theme.radiusMd,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 18,
                    ),
                    child: Text(
                      sentenceCaseOf(
                        context,
                        l10n.incomingGroupCallScreenRemoveContactSheetCancelButton,
                      ),
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
