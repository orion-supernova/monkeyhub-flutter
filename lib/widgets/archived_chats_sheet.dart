import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'chat_row_action_menu.dart';
import 'destructive_sheet.dart' show SheetGrabber;
import 'mute_room_sheet.dart';
import 'room_card.dart';
import '../screens/navigation/open_room.dart';

/// Every room the viewer has archived. Reached by pulling down at the top of
/// the chat list and tapping the "Archived Chats (N)" folder row — see
/// `pull_reveal_panel.dart`.
Future<void> showArchivedChatsSheet(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => ArchivedChatsSheet(repo: repo, api: api),
  );
}

class ArchivedChatsSheet extends StatelessWidget {
  const ArchivedChatsSheet({super.key, required this.repo, required this.api});

  final ChatRepository repo;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Read through to the repository on every build, same as
    // pinned_list_sheet.dart, so unarchiving from inside this sheet (or from
    // another device) updates it live.
    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) => _body(context, theme),
    );
  }

  Widget _body(BuildContext context, AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final rooms = repo.archivedRooms;
    final maxH = MediaQuery.sizeOf(context).height * 0.7;

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
            rooms.isEmpty
                ? l10n.archivedChatsSheetTitle
                : l10n.archivedChatsSheetTitleCount(rooms.length),
            textAlign: TextAlign.center,
            style: theme.label.copyWith(letterSpacing: 2.4),
          ),
          const SizedBox(height: 14),
          if (rooms.isEmpty)
            // The last archived room was unarchived while this was open. Say
            // so and let the reader dismiss, rather than pop a sheet out from
            // under a finger.
            Text(
              l10n.archivedChatsSheetEmptyMessage,
              textAlign: TextAlign.center,
              style: theme.bodySoft,
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: rooms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (_, i) =>
                    _ArchivedChatRow(room: rooms[i], repo: repo, api: api),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchivedChatRow extends StatefulWidget {
  const _ArchivedChatRow({
    required this.room,
    required this.repo,
    required this.api,
  });

  final ChatRoom room;
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<_ArchivedChatRow> createState() => _ArchivedChatRowState();
}

class _ArchivedChatRowState extends State<_ArchivedChatRow> {
  final _anchorKey = GlobalKey();

  Future<void> _showMenu(BuildContext context) async {
    // Same cheap, no-fetch slice `home_screen.dart`'s `_showRowMenu` takes —
    // see [ChatRowPreviewCard]'s doc. An archived room is just as likely to
    // have a resident transcript tail as any other: archiving only hides it
    // from the main list, it doesn't close the room this session already had
    // open.
    final all = widget.repo.messagesFor(widget.room.id);
    final recentMessages =
        all.length <= previewMaxMessages ? all : all.sublist(all.length - previewMaxMessages);
    final action = await showChatRowActionMenu(
      context: context,
      anchorKey: _anchorKey,
      previewBuilder: (context) => ChatRowPreviewCard(
        room: widget.room,
        api: widget.api,
        dmUser: widget.repo.otherUserFor(widget.room),
        recentMessages: recentMessages,
        currentUserId: widget.repo.userId ?? '',
        typists: widget.repo.typingIn(widget.room.id),
      ),
      isPinned: widget.room.isPinned,
      // Always true here — this sheet only shows archived rooms — but passed
      // explicitly so the menu's own "archived rooms only offer Unarchive"
      // rule stays the single source of truth.
      isArchived: true,
      isMuted: widget.room.isMuted,
      canMute: widget.repo.capabilitiesFor(widget.room).canMute,
      // Same pop-then-open sequence RoomCard's own onTap runs below — called
      // directly by the overlay, not through `action` below. On
      // compact/medium it fires mid-flight once the grown panel already
      // covers the whole screen (sheet included), so popping the
      // still-visible sheet here happens invisibly instead of racing the
      // room's own entrance the way it used to. See `showChatRowActionMenu`'s
      // doc.
      onOpenRoom: () {
        Navigator.of(context).pop();
        openRoom(
          context,
          roomId: widget.room.id,
          repo: widget.repo,
          api: widget.api,
          instant: true,
        );
      },
    );
    if (!context.mounted) return;
    switch (action) {
      case ChatRowAction.unarchive:
        await widget.repo.unarchiveRoom(widget.room.id);
      case ChatRowAction.mute:
        await showMuteRoomSheet(
          context,
          repo: widget.repo,
          room: widget.room,
        );
      case ChatRowAction.unmute:
        await widget.repo.unmuteRoom(widget.room.id);
      case ChatRowAction.open:
        // Already handled by onOpenRoom above, called by the overlay itself
        // at the right moment in its own flight — nothing left to do here.
        break;
      // The menu never offers these on an archived room; listed so adding a
      // future action to the enum fails here rather than silently doing
      // nothing on this surface.
      case ChatRowAction.pin:
      case ChatRowAction.unpin:
      case ChatRowAction.archive:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChatRowLongPress(
      key: _anchorKey,
      onLongPress: () => _showMenu(context),
      child: RoomCard(
        room: widget.room,
        api: widget.api,
        dmUser: widget.repo.otherUserFor(widget.room),
        onTap: () {
          // Pop first — opening the room behind a still-visible sheet
          // animates the transcript in underneath it.
          Navigator.of(context).pop();
          openRoom(
            context,
            roomId: widget.room.id,
            repo: widget.repo,
            api: widget.api,
          );
        },
      ),
    );
  }
}
