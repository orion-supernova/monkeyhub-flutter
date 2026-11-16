import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../data/chat_folder_store.dart';
import '../../data/chat_repository.dart';
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/pull_down_menu.dart';
import '../chat_folders_screen.dart';

/// One row of a tab's long-press menu. Plain data so the same menu can be
/// drawn by Flutter ([showPullDownMenu]) and by iOS (a `UIMenu` on the
/// native tab bar, see `ios/Runner/NativeChrome.swift`).
class TabMenuItem {
  const TabMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.symbol,
    this.checked = false,
    this.destructive = false,
    this.badge,
    this.startsGroup = false,
  });

  final String id;
  final String label;
  final IconData icon;

  /// SF Symbol for the native menu.
  final String symbol;
  final bool checked;
  final bool destructive;
  final String? badge;
  final bool startsGroup;

  Map<String, Object> toNative() => {
    'id': id,
    'title': label,
    'symbol': symbol,
    'checked': checked,
    'destructive': destructive,
    'subtitle': ?badge,
    'group': startsGroup,
  };
}

const String _kEditFolders = 'folders';
const String _kAllChats = 'all';
const String _kFolderPrefix = 'folder:';
const String _kHideCalls = 'hideCalls';

/// The long-press menu for [section]'s tab, empty when it has none.
///
/// Chats: Telegram's — Edit Folders (Add Folder with none yet), All Chats
/// when a folder is showing, then every folder with its unread chats.
/// Calls: Hide Calls Tab.
List<TabMenuItem> tabMenuFor(
  HomeSection section,
  AppLocalizations l10n,
  ChatRepository repo,
) {
  switch (section) {
    case HomeSection.chat:
      final store = ChatFolderStore.instance;
      final folders = [for (final f in store.folders) if (f.id.isNotEmpty) f];
      final active = store.active;
      final rooms = repo.rooms;
      return [
        TabMenuItem(
          id: _kEditFolders,
          label: folders.isEmpty
              ? l10n.chatFolderAddFolder
              : l10n.chatFolderEditFolders,
          icon: folders.isEmpty
              ? CupertinoIcons.folder_badge_plus
              : CupertinoIcons.folder,
          symbol: folders.isEmpty ? 'folder.badge.plus' : 'folder',
        ),
        if (folders.isNotEmpty) ...[
          TabMenuItem(
            id: _kAllChats,
            label: l10n.chatFolderAllChats,
            icon: CupertinoIcons.chat_bubble_2,
            symbol: 'bubble.left.and.bubble.right',
            checked: active == null,
            startsGroup: true,
          ),
          for (final f in folders)
            () {
              final unread = f.unreadCount(rooms);
              return TabMenuItem(
                id: '$_kFolderPrefix${f.id}',
                label: [f.emoji, f.name].whereType<String>().join(' '),
                icon: CupertinoIcons.folder,
                symbol: 'folder',
                checked: active?.id == f.id,
                badge: unread > 0 ? '$unread' : null,
              );
            }(),
        ],
      ];
    case HomeSection.calls:
      return [
        TabMenuItem(
          id: _kHideCalls,
          label: l10n.tabMenuHideCalls,
          icon: CupertinoIcons.eye_slash,
          symbol: 'eye.slash',
          destructive: true,
        ),
      ];
    case HomeSection.feed:
    case HomeSection.games:
    case HomeSection.settings:
      return const [];
  }
}

/// Carries out a picked [id] from [tabMenuFor]. [select] switches the shell
/// to a section (a folder pick also lands on Chats).
Future<void> runTabMenu(
  BuildContext context, {
  required String id,
  required ChatRepository repo,
  required ChatApi api,
  required ValueChanged<HomeSection> select,
}) async {
  final settings = SettingsStore.instance;
  if (id == _kEditFolders) {
    await openChatFolders(context, repo: repo, api: api);
  } else if (id == _kAllChats) {
    await settings.setActiveFolder(null);
    if (settings.section != HomeSection.chat) select(HomeSection.chat);
  } else if (id.startsWith(_kFolderPrefix)) {
    await settings.setActiveFolder(id.substring(_kFolderPrefix.length));
    if (settings.section != HomeSection.chat) select(HomeSection.chat);
  } else if (id == _kHideCalls) {
    final message = AppLocalizations.of(context).tabMenuCallsHiddenToast;
    await settings.setShowCallsTab(false);
    if (context.mounted) showAppToast(context, message);
  }
}

/// The Flutter-drawn bars' version: the menu as a pull-down anchored to the
/// pressed tab. Returns without drawing anything for a tab with no menu.
Future<void> showTabMenu(
  BuildContext context, {
  required HomeSection section,
  required Rect anchorRect,
  required ChatRepository repo,
  required ChatApi api,
  required ValueChanged<HomeSection> select,
}) async {
  final items = tabMenuFor(section, AppLocalizations.of(context), repo);
  if (items.isEmpty) return;
  final picked = await showPullDownMenu<String>(
    context: context,
    anchorRect: anchorRect,
    items: [
      for (final i in items)
        PullDownItem(
          value: i.id,
          label: i.label,
          icon: i.icon,
          checked: i.checked,
          destructive: i.destructive,
          startsGroup: i.startsGroup,
          badge: i.badge,
        ),
    ],
  );
  if (picked == null || !context.mounted) return;
  unawaited(
    runTabMenu(context, id: picked, repo: repo, api: api, select: select),
  );
}
