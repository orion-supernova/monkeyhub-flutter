import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_folder_store.dart';
import '../data/chat_folders.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/chat_list_parts.dart' show chatListTitleOf;
import '../widgets/chat_list_row.dart' show ChatRoomAvatar;
import '../widgets/destructive_sheet.dart';
import '../widgets/ios_kit.dart';
import '../widgets/labeled_field.dart' show ThemedInput;
import '../widgets/search_field.dart';
import '../widgets/settings_pickers.dart' show GroupedFooter;

/// Settings > Chat Folders: the user's folders (tap to edit, drag to
/// reorder), "Create a Folder" up to [kMaxChatFolders], Telegram's suggested
/// folders, and the folder-tags switch. docs/design/chat-folders.md.
Future<void> openChatFolders(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => ChatFoldersScreen(repo: repo, api: api),
  ),
);

/// The folder editor. [folder] null makes a new one; [seed] prefills a new
/// one (a suggested folder, or "New Folder" from a chat row with that chat
/// already in it). Resolves to the saved folder's id, or null.
Future<String?> openChatFolderEditor(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
  ChatFolder? folder,
  ChatFolder? seed,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute<String>(
    builder: (_) =>
        ChatFolderEditScreen(repo: repo, api: api, folder: folder, seed: seed),
  ),
);

/// The suggested folder as a draft, named in the reader's language.
ChatFolder suggestedFolder(AppLocalizations l10n, SuggestedFolder s) =>
    switch (s) {
      SuggestedFolder.unread => ChatFolder(
        id: '',
        name: l10n.chatFolderSuggestUnread,
        emoji: '✅',
        dms: true,
        groups: true,
        excludeRead: true,
      ),
      SuggestedFolder.personal => ChatFolder(
        id: '',
        name: l10n.chatFolderSuggestPersonal,
        emoji: '👤',
        dms: true,
      ),
      SuggestedFolder.groups => ChatFolder(
        id: '',
        name: l10n.chatFolderSuggestGroups,
        emoji: '👥',
        groups: true,
      ),
    };

/// Whether the account already has a folder doing what [s] would.
bool _hasEquivalent(List<ChatFolder> folders, ChatFolder s) => folders.any(
  (f) =>
      f.dms == s.dms &&
      f.groups == s.groups &&
      f.excludeRead == s.excludeRead &&
      f.excludeMuted == s.excludeMuted &&
      f.include.isEmpty,
);

/// A folder's mark in rows and tabs: its emoji, else the folder glyph.
class FolderGlyph extends StatelessWidget {
  const FolderGlyph({super.key, required this.folder, this.size = 18});
  final ChatFolder folder;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emoji = folder.emoji;
    if (emoji != null && emoji.isNotEmpty) {
      return Text(emoji, style: TextStyle(fontSize: size, height: 1.1));
    }
    return Icon(
      CupertinoIcons.folder_fill,
      size: size,
      color: ThemeScope.of(context).inkSoft,
    );
  }
}

class ChatFoldersScreen extends StatefulWidget {
  const ChatFoldersScreen({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<ChatFoldersScreen> createState() => _ChatFoldersScreenState();
}

class _ChatFoldersScreenState extends State<ChatFoldersScreen> {
  ChatFolderStore get _store => ChatFolderStore.instance;

  Future<void> _addSuggested(ChatFolder draft) async {
    HapticFeedback.lightImpact();
    try {
      await _store.save(
        draft.copyWith(color: _ChatFolderEditScreenState._nextColor),
      );
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          AppLocalizations.of(context).chatFolderSaveFailed,
          tone: ToastTone.danger,
        );
      }
    }
  }

  void _onReorder(int from, int to) {
    final ids = [for (final f in _store.folders) f.id];
    final id = ids.removeAt(from);
    ids.insert(to, id);
    HapticFeedback.selectionClick();
    unawaited(_store.reorder(ids).catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_store, widget.repo, SettingsStore.instance]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final folders = _store.folders;
        final rooms = widget.repo.rooms;
        final suggestions = [
          for (final s in SuggestedFolder.values)
            if (!_hasEquivalent(folders, suggestedFolder(l10n, s))) s,
        ];
        return IosPage(
          title: l10n.chatFoldersTitle,
          subtitle: l10n.chatFoldersIntro,
          children: [
            if (folders.isNotEmpty) ...[
              GroupedHeader(l10n.chatFoldersMine),
              GroupedCard(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  padding: EdgeInsets.zero,
                  itemCount: folders.length,
                  onReorderItem: _onReorder,
                  proxyDecorator: (child, _, _) => Material(
                    type: MaterialType.transparency,
                    child: child,
                  ),
                  itemBuilder: (context, i) {
                    final f = folders[i];
                    return _FolderRow(
                      key: ValueKey(f.id.isEmpty ? 'pending-$i' : f.id),
                      folder: f,
                      index: i,
                      divider: i < folders.length - 1,
                      count: f.apply(rooms).length,
                      onTap: f.id.isEmpty
                          ? null
                          : () => openChatFolderEditor(
                              context,
                              repo: widget.repo,
                              api: widget.api,
                              folder: f,
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            GroupedSection(
              margin: EdgeInsets.zero,
              children: [
                GroupedRow(
                  title: l10n.chatFoldersCreate,
                  icon: CupertinoIcons.folder_badge_plus,
                  tone: TileTone.accent,
                  chevron: false,
                  onTap: _store.atCap
                      ? null
                      : () => openChatFolderEditor(
                          context,
                          repo: widget.repo,
                          api: widget.api,
                        ),
                ),
              ],
            ),
            GroupedFooter(
              _store.atCap
                  ? l10n.chatFoldersCapReached(kMaxChatFolders)
                  : '${l10n.chatFoldersUsed(folders.length, kMaxChatFolders)}'
                        '${folders.length > 1 ? '\n${l10n.chatFoldersReorderHint}' : ''}',
            ),
            if (suggestions.isNotEmpty && !_store.atCap)
              GroupedSection(
                header: l10n.chatFoldersRecommended,
                children: [
                  for (final s in suggestions)
                    () {
                      final draft = suggestedFolder(l10n, s);
                      return GroupedRow(
                        title: draft.name,
                        subtitle: switch (s) {
                          SuggestedFolder.unread =>
                            l10n.chatFolderSuggestUnreadSub,
                          SuggestedFolder.personal =>
                            l10n.chatFolderSuggestPersonalSub,
                          SuggestedFolder.groups =>
                            l10n.chatFolderSuggestGroupsSub,
                        },
                        icon: switch (s) {
                          SuggestedFolder.unread =>
                            CupertinoIcons.chat_bubble_text_fill,
                          SuggestedFolder.personal =>
                            CupertinoIcons.person_fill,
                          SuggestedFolder.groups =>
                            CupertinoIcons.person_3_fill,
                        },
                        tone: switch (s) {
                          SuggestedFolder.unread => TileTone.blue,
                          SuggestedFolder.personal => TileTone.green,
                          SuggestedFolder.groups => TileTone.orange,
                        },
                        chevron: false,
                        trailing: RowPillButton(
                          label: l10n.chatFoldersAddSuggested,
                          filled: true,
                          onTap: () => _addSuggested(draft),
                        ),
                      );
                    }(),
                ],
              ),
            GroupedSection(
              children: [
                GroupedRow.toggle(
                  title: l10n.chatFoldersShowTags,
                  subtitle: l10n.chatFoldersShowTagsSub,
                  icon: CupertinoIcons.tag_fill,
                  tone: TileTone.purple,
                  value: SettingsStore.instance.showFolderTags,
                  onChanged: SettingsStore.instance.setShowFolderTags,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// One of my folders: its mark, name, how many chats it holds now, and a
/// drag handle. Its own row rather than a [GroupedRow] because a reorderable
/// list needs the handle and draws its own hairlines.
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    super.key,
    required this.folder,
    required this.index,
    required this.divider,
    required this.count,
    required this.onTap,
  });

  final ChatFolder folder;
  final int index;
  final bool divider;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final color = folder.color;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: folder.name,
      radius: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Center(child: FolderGlyph(folder: folder, size: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 58),
                  decoration: BoxDecoration(
                    border: divider
                        ? Border(
                            bottom: BorderSide(
                              color: theme.ink.withValues(alpha: 0.10),
                              width: 1 / MediaQuery.devicePixelRatioOf(context),
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.body.copyWith(fontSize: 17),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.chatFolderChatCount(count),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: groupedMetaStyle(theme),
                            ),
                          ],
                        ),
                      ),
                      if (color != null) ...[
                        _TagDot(index: color, size: 10),
                        const SizedBox(width: 10),
                      ],
                      Icon(
                        CupertinoIcons.chevron_forward,
                        size: 15,
                        color: theme.ink.withValues(alpha: 0.30),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                          child: Icon(
                            CupertinoIcons.line_horizontal_3,
                            size: 20,
                            color: theme.ink.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagDot extends StatelessWidget {
  const _TagDot({required this.index, this.size = 12});
  final int index;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: folderTagColor(index, dark: !ThemeScope.of(context).isLight),
    ),
  );
}

/// The small coloured name chip a chat row carries for each folder it is in
/// (Telegram's folder tags). Exported for the chat list.
class FolderTagChip extends StatelessWidget {
  const FolderTagChip({super.key, required this.name, required this.color});
  final String name;
  final int color;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final c = folderTagColor(color, dark: !theme.isLight);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: theme.isLight ? 0.13 : 0.22),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.body.copyWith(
          fontSize: 10.5,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: c,
        ),
      ),
    );
  }
}

/// Emoji a folder can wear, Telegram's folder-icon set in emoji form.
const List<String> _kFolderEmoji = [
  '📁', '💬', '👤', '👥', '❤️', '⭐', '💼', '🏠', '🎓', '🎮',
  '🎵', '✈️', '⚽', '🍔', '💰', '📚', '🎨', '🐵', '🔥', '✅',
];

class ChatFolderEditScreen extends StatefulWidget {
  const ChatFolderEditScreen({
    super.key,
    required this.repo,
    required this.api,
    this.folder,
    this.seed,
  });

  final ChatRepository repo;
  final ChatApi api;
  final ChatFolder? folder;
  final ChatFolder? seed;

  @override
  State<ChatFolderEditScreen> createState() => _ChatFolderEditScreenState();
}

class _ChatFolderEditScreenState extends State<ChatFolderEditScreen> {
  late ChatFolder _draft = widget.folder ?? _fresh(widget.seed);

  static ChatFolder _fresh(ChatFolder? seed) {
    final d = seed ?? const ChatFolder(id: '', name: '');
    return d.color != null ? d : d.copyWith(color: _nextColor);
  }
  late final _name = TextEditingController(text: _draft.name);
  bool _saving = false;
  bool _showAllIncluded = false;
  bool _showAllExcluded = false;

  bool get _isNew => widget.folder == null;

  /// New folders take the first tag colour no other folder wears, so a
  /// handful of folders come out distinct without anyone picking.
  static int _nextColor() {
    final used = {for (final f in ChatFolderStore.instance.folders) f.color};
    for (var i = 0; i < kFolderTagColors.length; i++) {
      if (!used.contains(i)) return i;
    }
    return ChatFolderStore.instance.folders.length % kFolderTagColors.length;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(ChatFolder next) => setState(() => _draft = next);

  ChatRoom? _room(String id) {
    for (final r in widget.repo.rooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<void> _pick({required bool include}) async {
    final res = await Navigator.of(context).push<ChatFolder>(
      MaterialPageRoute<ChatFolder>(
        builder: (_) => _ChatFolderPicker(
          repo: widget.repo,
          api: widget.api,
          draft: _draft,
          include: include,
        ),
      ),
    );
    if (res != null && mounted) _set(res);
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      return;
    }
    // Ids of rooms the account is no longer in go now (chatFolders.include
    // is a soft reference).
    final known = {for (final r in widget.repo.rooms) r.id};
    final folder = _draft.copyWith(
      name: name,
      include: [for (final id in _draft.include) if (known.contains(id)) id],
      exclude: [for (final id in _draft.exclude) if (known.contains(id)) id],
    );
    if (!folder.takesAnything) {
      HapticFeedback.heavyImpact();
      showAppToast(context, l10n.chatFolderNeedsChats, tone: ToastTone.danger);
      return;
    }
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      final id = await ChatFolderStore.instance.save(folder);
      HapticFeedback.lightImpact();
      if (mounted) nav.pop(id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, l10n.chatFolderSaveFailed, tone: ToastTone.danger);
    }
  }

  Future<void> _delete() async {
    final folder = widget.folder;
    if (folder == null) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmSheet(
      context,
      headline: l10n.chatFolderDeleteTitle(folder.name),
      body: l10n.chatFolderDeleteBody,
      confirmLabel: l10n.chatFolderDelete,
      icon: CupertinoIcons.folder_badge_minus,
    );
    if (!ok || !mounted) return;
    final nav = Navigator.of(context);
    unawaited(ChatFolderStore.instance.remove(folder.id).catchError((Object _) {
      if (mounted) {
        showAppToast(context, l10n.chatFolderSaveFailed, tone: ToastTone.danger);
      }
    }));
    nav.pop();
  }

  Widget _removable({
    required Widget row,
    required VoidCallback onRemove,
  }) => Row(
    children: [
      Expanded(child: row),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onRemove();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
          child: Icon(
            CupertinoIcons.minus_circle_fill,
            size: 22,
            color: ThemeScope.of(context).danger,
          ),
        ),
      ),
    ],
  );

  Widget _typeRow(String title, IconData icon, TileTone tone, VoidCallback remove) =>
      _removable(
        row: GroupedRow(title: title, icon: icon, tone: tone, chevron: false),
        onRemove: remove,
      );

  List<Widget> _roomRows(List<String> ids, bool showAll, VoidCallback more,
      void Function(String id) remove) {
    final l10n = AppLocalizations.of(context);
    final rooms = [for (final id in ids) ?_room(id)];
    final cut = !showAll && rooms.length >= 7;
    final shown = cut ? rooms.take(5) : rooms;
    return [
      for (final r in shown)
        _removable(
          row: PersonRow(
            avatar: ChatRoomAvatar(
              room: r,
              size: kPersonRowAvatar,
              dmUser: widget.repo.otherUserFor(r),
              api: widget.api,
            ),
            title: chatListTitleOf(context, r, widget.repo.otherUserFor(r)),
          ),
          onRemove: () => remove(r.id),
        ),
      if (cut)
        GroupedRow(
          title: l10n.chatFolderShowMore(rooms.length - 5),
          icon: CupertinoIcons.chevron_down,
          tone: TileTone.gray,
          chevron: false,
          onTap: more,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final d = _draft;
    return IosPage(
      title: _isNew ? l10n.chatFolderNew : l10n.chatFolderEdit,
      actions: [
        GlassIconButton(
          icon: CupertinoIcons.checkmark_alt,
          semanticLabel: l10n.chatFolderSave,
          tint: theme.accent,
          color: theme.accentInk,
          onTap: _saving ? null : _save,
        ),
      ],
      children: [
        GroupedHeader(l10n.chatFolderNameHeader),
        GroupedCard(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ThemedInput(
                controller: _name,
                hint: l10n.chatFolderNamePlaceholder,
                autofocus: _isNew && d.name.isEmpty,
                textInputAction: TextInputAction.done,
                onChanged: (v) {
                  if (v.length > kMaxFolderName) {
                    _name.value = TextEditingValue(
                      text: v.substring(0, kMaxFolderName),
                      selection: const TextSelection.collapsed(
                        offset: kMaxFolderName,
                      ),
                    );
                  }
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              _EmojiStrip(
                selected: d.emoji,
                noneLabel: l10n.chatFolderIconNone,
                onPick: (e) => _set(d.copyWith(emoji: () => e)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        GroupedSection(
          header: l10n.chatFolderIncluded,
          margin: EdgeInsets.zero,
          children: [
            GroupedRow(
              title: l10n.chatFolderAddChats,
              icon: CupertinoIcons.plus,
              tone: TileTone.accent,
              chevron: false,
              onTap: () => _pick(include: true),
            ),
            if (d.dms)
              _typeRow(l10n.chatFolderTypeDms, CupertinoIcons.person_fill,
                  TileTone.green, () => _set(d.copyWith(dms: false))),
            if (d.groups)
              _typeRow(l10n.chatFolderTypeGroups, CupertinoIcons.person_3_fill,
                  TileTone.orange, () => _set(d.copyWith(groups: false))),
            ..._roomRows(
              d.include,
              _showAllIncluded,
              () => setState(() => _showAllIncluded = true),
              (id) => _set(d.copyWith(include: [...d.include]..remove(id))),
            ),
          ],
        ),
        GroupedFooter(l10n.chatFolderIncludedFooter),
        GroupedSection(
          header: l10n.chatFolderExcluded,
          margin: EdgeInsets.zero,
          children: [
            GroupedRow(
              title: l10n.chatFolderExcludeChats,
              icon: CupertinoIcons.minus,
              tone: TileTone.red,
              chevron: false,
              onTap: () => _pick(include: false),
            ),
            if (d.excludeMuted)
              _typeRow(l10n.chatFolderTypeMuted, CupertinoIcons.bell_slash_fill,
                  TileTone.gray, () => _set(d.copyWith(excludeMuted: false))),
            if (d.excludeRead)
              _typeRow(l10n.chatFolderTypeRead, CupertinoIcons.checkmark_alt,
                  TileTone.blue, () => _set(d.copyWith(excludeRead: false))),
            if (d.excludeArchived)
              _typeRow(
                l10n.chatFolderTypeArchived,
                CupertinoIcons.archivebox_fill,
                TileTone.indigo,
                () => _set(d.copyWith(excludeArchived: false)),
              ),
            ..._roomRows(
              d.exclude,
              _showAllExcluded,
              () => setState(() => _showAllExcluded = true),
              (id) => _set(d.copyWith(exclude: [...d.exclude]..remove(id))),
            ),
          ],
        ),
        GroupedFooter(l10n.chatFolderExcludedFooter),
        GroupedHeader(
          l10n.chatFolderTagHeader,
          trailing: d.color == null || _name.text.trim().isEmpty
              ? null
              : FolderTagChip(name: _name.text.trim(), color: d.color!),
        ),
        GroupedCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: _ColorStrip(
            selected: d.color,
            noneLabel: l10n.chatFolderTagNone,
            onPick: (c) => _set(d.copyWith(color: () => c)),
          ),
        ),
        GroupedFooter(l10n.chatFolderTagFooter),
        if (!_isNew)
          GroupedSection(
            children: [
              GroupedRow(
                title: l10n.chatFolderDelete,
                destructive: true,
                chevron: false,
                onTap: _delete,
              ),
            ],
          ),
      ],
    );
  }
}

class _EmojiStrip extends StatelessWidget {
  const _EmojiStrip({
    required this.selected,
    required this.noneLabel,
    required this.onPick,
  });
  final String? selected;
  final String noneLabel;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    Widget cell(String? e) {
      final on = e == selected || (e == null && (selected ?? '').isEmpty);
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onPick(e);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: on ? theme.accent.withValues(alpha: 0.16) : null,
            border: Border.all(
              color: on ? theme.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: e == null
              ? Icon(
                  CupertinoIcons.nosign,
                  size: 18,
                  color: theme.inkSoft,
                  semanticLabel: noneLabel,
                )
              : Text(e, style: const TextStyle(fontSize: 21)),
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [cell(null), for (final e in _kFolderEmoji) cell(e)],
    );
  }
}

class _ColorStrip extends StatelessWidget {
  const _ColorStrip({
    required this.selected,
    required this.noneLabel,
    required this.onPick,
  });
  final int? selected;
  final String noneLabel;
  final ValueChanged<int?> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    Widget dot(int? i) {
      final on = i == selected;
      final fill = i == null
          ? theme.ink.withValues(alpha: 0.10)
          : folderTagColor(i, dark: !theme.isLight);
      return Semantics(
        button: true,
        selected: on,
        label: i == null ? noneLabel : null,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onPick(i);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: on ? fill : Colors.transparent,
                width: 2,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: i == null
                  ? Icon(CupertinoIcons.nosign, size: 15, color: theme.inkSoft)
                  : null,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        for (var i = 0; i < kFolderTagColors.length; i++) dot(i),
        dot(null),
      ],
    );
  }
}

/// Telegram's "Include Chats" / "Exclude Chats" picker: chat kinds on top,
/// then every chat with a check, a search field, and the hand-picked count
/// against [kMaxFolderRooms]. Pops with the edited draft.
class _ChatFolderPicker extends StatefulWidget {
  const _ChatFolderPicker({
    required this.repo,
    required this.api,
    required this.draft,
    required this.include,
  });

  final ChatRepository repo;
  final ChatApi api;
  final ChatFolder draft;
  final bool include;

  @override
  State<_ChatFolderPicker> createState() => _ChatFolderPickerState();
}

class _ChatFolderPickerState extends State<_ChatFolderPicker> {
  late ChatFolder _d = widget.draft;
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _ids => widget.include ? _d.include : _d.exclude;

  void _toggleRoom(String id) {
    final l10n = AppLocalizations.of(context);
    final mine = [..._ids];
    final other = [...(widget.include ? _d.exclude : _d.include)];
    if (mine.contains(id)) {
      mine.remove(id);
    } else {
      if (mine.length >= kMaxFolderRooms) {
        HapticFeedback.heavyImpact();
        showAppToast(context, l10n.chatFolderRoomsCap(kMaxFolderRooms));
        return;
      }
      mine.add(id);
      // A chat cannot be both kept in and kept out by hand.
      other.remove(id);
    }
    HapticFeedback.selectionClick();
    setState(() {
      _d = widget.include
          ? _d.copyWith(include: mine, exclude: other)
          : _d.copyWith(exclude: mine, include: other);
    });
  }

  Widget _typeToggle(
    String title,
    IconData icon,
    TileTone tone,
    bool on,
    ChatFolder Function(bool) set,
  ) => GroupedRow(
    title: title,
    icon: icon,
    tone: tone,
    chevron: false,
    onTap: () {
      HapticFeedback.selectionClick();
      setState(() => _d = set(!on));
    },
    trailing: SelectionCheck(picked: on),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final repo = widget.repo;
    final q = _q.trim().toLowerCase();
    final rooms = [
      for (final r in repo.rooms)
        if (q.isEmpty ||
            chatListTitleOf(context, r, repo.otherUserFor(r))
                .toLowerCase()
                .contains(q))
          r,
    ];
    final ids = _ids.toSet();
    return IosPage(
      title: widget.include
          ? l10n.chatFolderPickIncludeTitle
          : l10n.chatFolderPickExcludeTitle,
      actions: [
        GlassIconButton(
          icon: CupertinoIcons.checkmark_alt,
          semanticLabel: l10n.chatFolderPickDone,
          tint: theme.accent,
          color: theme.accentInk,
          onTap: () => Navigator.of(context).pop(_d),
        ),
      ],
      children: [
        GroupedSection(
          header: l10n.chatFolderPickTypes,
          children: widget.include
              ? [
                  _typeToggle(l10n.chatFolderTypeDms, CupertinoIcons.person_fill,
                      TileTone.green, _d.dms, (v) => _d.copyWith(dms: v)),
                  _typeToggle(
                    l10n.chatFolderTypeGroups,
                    CupertinoIcons.person_3_fill,
                    TileTone.orange,
                    _d.groups,
                    (v) => _d.copyWith(groups: v),
                  ),
                ]
              : [
                  _typeToggle(
                    l10n.chatFolderTypeMuted,
                    CupertinoIcons.bell_slash_fill,
                    TileTone.gray,
                    _d.excludeMuted,
                    (v) => _d.copyWith(excludeMuted: v),
                  ),
                  _typeToggle(
                    l10n.chatFolderTypeRead,
                    CupertinoIcons.checkmark_alt,
                    TileTone.blue,
                    _d.excludeRead,
                    (v) => _d.copyWith(excludeRead: v),
                  ),
                  _typeToggle(
                    l10n.chatFolderTypeArchived,
                    CupertinoIcons.archivebox_fill,
                    TileTone.indigo,
                    _d.excludeArchived,
                    (v) => _d.copyWith(excludeArchived: v),
                  ),
                ],
        ),
        SearchField(
          controller: _search,
          hintText: l10n.chatFolderPickSearch,
          showCancel: false,
          onChanged: (v) => setState(() => _q = v),
          onClear: () => setState(() => _q = ''),
        ),
        const SizedBox(height: 16),
        GroupedSection(
          header: l10n.chatFolderPickChats,
          margin: EdgeInsets.zero,
          children: [
            for (final r in rooms)
              PersonRow(
                key: ValueKey(r.id),
                avatar: ChatRoomAvatar(
                  room: r,
                  size: kPersonRowAvatar,
                  dmUser: repo.otherUserFor(r),
                  api: widget.api,
                ),
                title: chatListTitleOf(context, r, repo.otherUserFor(r)),
                trailing: SelectionCheck(picked: ids.contains(r.id)),
                onTap: () => _toggleRoom(r.id),
              ),
          ],
        ),
        GroupedFooter(l10n.chatFolderPickCount(ids.length, kMaxFolderRooms)),
      ],
    );
  }
}

/// Tag chips for the folders [room] is in, for a chat row in All Chats.
/// Empty when tags are off, or no folder that holds the room has a colour.
List<({String name, int color})> folderTagsFor(
  ChatRoom room,
  List<ChatFolder> folders,
) => [
  for (final f in folders)
    if (f.color != null && f.matches(room)) (name: f.name, color: f.color!),
];
