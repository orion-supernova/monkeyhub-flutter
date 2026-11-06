import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';
import 'chat_list_parts.dart' show ChatUnreadBadge;
import 'teardown_safe.dart';

/// The Archived chats folder, shaped like a chat row: a grey disc where a face
/// would be, the title, a line under it, and what is waiting on the right.
///
/// One widget for both places that offer the folder — the pull-down panel,
/// which only shows it on request, and the chat list itself, where it stays
/// put whenever an archived room has something unread. The second is the
/// reason it exists as a shared piece: archived rooms are hidden from the list,
/// so a message landing in one used to reach the viewer as a bump on the tab
/// badge and nothing else.
///
/// The badge counts ROOMS with something unread, not archived rooms. How many
/// chats are filed away is not news; how many of them are asking for you is.
/// At rest (nothing unread) the row carries no badge at all, just the total in
/// its second line.
class ArchivedFolderRow extends StatelessWidget {
  const ArchivedFolderRow({
    super.key,
    required this.totalCount,
    required this.unreadRooms,
    required this.unreadTitles,
    required this.onTap,
  });

  /// Every archived room.
  final int totalCount;

  /// Archived rooms with something unread (badge-muted ones excluded, the way
  /// every other unread number in the app is).
  final int unreadRooms;

  /// Display names of those rooms, newest first. The row's second line when
  /// there are any: who is waiting, which is what the viewer wants to know
  /// before deciding whether to open the folder.
  final List<String> unreadTitles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final unread = unreadRooms > 0;
    return ChatFolderRow(
      icon: CupertinoIcons.archivebox_fill,
      disc: theme.inkMuted.withValues(alpha: 0.55),
      title: sentenceCaseOf(context, l10n.archivedChatsFolderTitle),
      subtitle: unread && unreadTitles.isNotEmpty
          ? unreadTitles.join(', ')
          : l10n.archivedChatsSheetCount(totalCount),
      badge: unreadRooms,
      semanticLabel: unread
          ? l10n.archivedChatsFolderLabelUnread(totalCount, unreadRooms)
          : l10n.archivedChatsFolderLabel(totalCount),
      onTap: onTap,
    );
  }
}

/// A folder in the chat list, shaped like a chat row: a coloured disc with a
/// glyph where a face would be, a title, a line under it, and a count on the
/// right while something in it is waiting. Archived chats and Requests both
/// use it, so the two read as the same kind of thing.
class ChatFolderRow extends StatefulWidget {
  const ChatFolderRow({
    super.key,
    required this.icon,
    required this.disc,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.semanticLabel,
    required this.onTap,
    this.subtitleLines = 1,
  });

  final IconData icon;

  /// A folder's line is a summary and stays on one; an invitation row (the
  /// "Find your friends" card) needs room for its sentence.
  final int subtitleLines;

  /// The disc's fill behind the white glyph.
  final Color disc;
  final String title;
  final String subtitle;

  /// Zero draws no badge and a regular-weight title.
  final int badge;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  State<ChatFolderRow> createState() => _ChatFolderRowState();
}

class _ChatFolderRowState extends State<ChatFolderRow>
    with TeardownSafe<ChatFolderRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final unread = widget.badge > 0;
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.semanticLabel,
      shape: FocusRingShape.rounded,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: _pressed ? Duration.zero : const Duration(milliseconds: 240),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _pressed ? theme.ink.withValues(alpha: 0.06) : null,
            borderRadius: BorderRadius.circular(theme.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.disc,
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: theme.bodyEmph.copyWith(
                        color: theme.ink,
                        fontStyle: FontStyle.normal,
                        fontWeight: unread ? FontWeight.w700 : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Not ink-strong when unread: the badge is the loud part,
                    // and a bold second line beside it would be two shouts.
                    Text(
                      widget.subtitle,
                      style: theme.caption.copyWith(
                        color: theme.inkMuted,
                        fontSize: 14,
                      ),
                      maxLines: widget.subtitleLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (unread) ...[
                ChatUnreadBadge(count: widget.badge),
                const SizedBox(width: 8),
              ],
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: theme.inkMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
