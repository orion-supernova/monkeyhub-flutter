import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_folders.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart' show quietFill;
import 'pull_down_menu.dart';

/// What a long-press on a folder tab asked for.
enum FolderTabAction { edit, delete, editAll }

/// Telegram's folder tabs over the chat list: "All", then each folder with
/// its emoji and the number of its chats with something unread. Tap selects;
/// a long-press (or right-click) opens Edit / Delete for that folder, and
/// Edit Folders on "All".
///
/// Scrolls sideways when the folders outrun the width, and keeps the
/// selected tab in view when the selection changes from elsewhere (the Chats
/// tab's long-press menu).
class ChatFolderTabs extends StatefulWidget {
  const ChatFolderTabs({
    super.key,
    required this.folders,
    required this.activeId,
    required this.rooms,
    required this.onSelect,
    required this.onAction,
  });

  final List<ChatFolder> folders;

  /// Null for All.
  final String? activeId;

  /// Every room, archived included: a folder that keeps archived chats
  /// counts their unread too.
  final List<ChatRoom> rooms;
  final ValueChanged<String?> onSelect;
  final void Function(ChatFolder? folder, FolderTabAction action) onAction;

  @override
  State<ChatFolderTabs> createState() => _ChatFolderTabsState();
}

class _ChatFolderTabsState extends State<ChatFolderTabs> {
  final _keys = <String, GlobalKey>{};
  GlobalKey _key(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void didUpdateWidget(ChatFolderTabs old) {
    super.didUpdateWidget(old);
    if (old.activeId != widget.activeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _key(widget.activeId ?? '').currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.5,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _menu(ChatFolder? folder) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPullDownMenu<FolderTabAction>(
      context: context,
      anchorKey: _key(folder?.id ?? ''),
      items: folder == null
          ? [
              PullDownItem(
                value: FolderTabAction.editAll,
                label: l10n.chatFolderEditFolders,
                icon: CupertinoIcons.folder,
              ),
            ]
          : [
              PullDownItem(
                value: FolderTabAction.edit,
                label: l10n.chatFolderEdit,
                icon: CupertinoIcons.pencil,
              ),
              PullDownItem(
                value: FolderTabAction.editAll,
                label: l10n.chatFolderEditFolders,
                icon: CupertinoIcons.folder,
              ),
              PullDownItem(
                value: FolderTabAction.delete,
                label: l10n.chatFolderDelete,
                icon: CupertinoIcons.trash,
                destructive: true,
                startsGroup: true,
              ),
            ],
    );
    if (picked != null && mounted) widget.onAction(folder, picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rooms = widget.rooms;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Tab(
            key: _key(''),
            label: l10n.chatFolderTabAll,
            selected: widget.activeId == null,
            onTap: () => widget.onSelect(null),
            onLongPress: () => _menu(null),
          ),
          for (final f in widget.folders)
            _Tab(
              key: _key(f.id),
              label: f.name,
              emoji: f.emoji,
              unread: f.unreadCount(rooms),
              selected: widget.activeId == f.id,
              onTap: () => widget.onSelect(f.id),
              onLongPress: f.id.isEmpty ? null : () => _menu(f),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.emoji,
    this.unread = 0,
  });

  final String label;
  final String? emoji;
  final int unread;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = selected ? theme.accent : theme.inkSoft;
    void tap() {
      if (!selected) HapticFeedback.selectionClick();
      onTap();
    }

    void hold() {
      HapticFeedback.mediumImpact();
      onLongPress?.call();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FocusableTap(
        onTap: tap,
        semanticLabel: unread > 0 ? '$label, $unread' : label,
        radius: 18,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          onLongPress: onLongPress == null ? null : hold,
          onSecondaryTap: onLongPress == null ? null : hold,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? quietFill(theme) : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null && emoji!.isNotEmpty) ...[
                  Text(emoji!, style: const TextStyle(fontSize: 15, height: 1.1)),
                  const SizedBox(width: 5),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.body.copyWith(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.accent
                          : theme.ink.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: theme.body.copyWith(
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: selected ? theme.accentInk : Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
