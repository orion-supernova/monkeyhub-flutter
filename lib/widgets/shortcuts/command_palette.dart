import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/chat_repository.dart';
import '../../keyboard/app_shortcuts.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_room.dart';
import '../../screens/data_storage/usage_widgets.dart' show roomTitle;
import '../../theme/theme_scope.dart';
import '../chat_list_row.dart' show ChatRoomAvatar;
import '../glass_reveal.dart';
import '../glass_surface.dart';
import 'keycaps.dart';

/// ⌘K: jump to any chat, or run any command the screen beneath answers, by
/// typing a few letters. Spotlight / Raycast / Slack's switcher.
///
/// Everything it searches is already in memory (the chat list the repository
/// holds, the shortcut catalog), so a keystroke costs one pass over a list of
/// a few hundred names and no network at all.
///
/// Commands are snapshotted before the palette opens, for the reason
/// [showShortcutsPanel] gives, and run after it has closed.
Future<void> showCommandPalette(
  BuildContext context, {
  required ChatRepository repo,
  required void Function(String roomId) onOpenRoom,
  required List<String> sectionLabels,
}) async {
  final reg = AppShortcutRegistry.instance;
  final commands = [
    for (final d in AppShortcuts.all)
      if (!d.ambient &&
          d != AppShortcuts.commandPalette &&
          d.offeredHere &&
          reg.isBound(d))
        d,
  ];
  final theme = ThemeScope.of(context);
  final picked = await showGeneralDialog<_Item>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // Lighter than a sheet's dim: the palette is a quick question asked over
    // the screen, not a place, and the chat it might take you to should stay
    // readable behind it.
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, _, _) => _Palette(
      repo: repo,
      commands: commands,
      sectionLabels: sectionLabels,
    ),
    // Grown out of the top centre, never faded: see [GlassReveal].
    transitionBuilder: (_, animation, _, child) => AnimatedBuilder(
      animation: animation,
      builder: (_, child) => GlassReveal(
        t: theme.motionEntrance.transform(animation.value),
        from: 0.96,
        alignment: Alignment.topCenter,
        child: child!,
      ),
      child: child,
    ),
  );
  if (picked == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final room = picked.room;
    if (room != null) {
      onOpenRoom(room.id);
    } else {
      reg.invoke(picked.command!);
    }
  });
}

class _Item {
  const _Item.room(ChatRoom this.room, this.title) : command = null;
  const _Item.command(ShortcutDef this.command, this.title) : room = null;

  final ChatRoom? room;
  final ShortcutDef? command;
  final String title;
}

/// How well [title] answers [q]: higher is better, null is no match.
///
/// Ranked the way a switcher is expected to rank: the start of the name, then
/// the start of any word in it ("mu" finds "Family Murat"), then anywhere,
/// then the letters in order with gaps ("fmy" finds "Family"). Case and the
/// commonest accents ignored, so "sukru" finds "Şükrü".
int? paletteScore(String title, String q) {
  if (q.isEmpty) return 0;
  final t = _fold(title);
  final n = _fold(q);
  if (t.startsWith(n)) return 400 - t.length;
  final word = RegExp(r'[\s\-_.]').allMatches(t).any((m) => t.startsWith(n, m.end));
  if (word) return 300 - t.length;
  final at = t.indexOf(n);
  if (at >= 0) return 200 - at;
  var i = 0;
  for (final ch in n.runes) {
    i = t.indexOf(String.fromCharCode(ch), i);
    if (i < 0) return null;
    i++;
  }
  return 100 - t.length;
}

const _folds = {
  'ş': 's', 'ğ': 'g', 'ı': 'i', 'İ': 'i', 'ç': 'c', 'ö': 'o', 'ü': 'u',
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ñ': 'n',
};

String _fold(String s) {
  final lower = s.toLowerCase();
  if (lower.runes.every((r) => r < 128)) return lower;
  final b = StringBuffer();
  for (final r in lower.runes) {
    final ch = String.fromCharCode(r);
    b.write(_folds[ch] ?? ch);
  }
  return b.toString();
}

class _Palette extends StatefulWidget {
  const _Palette({
    required this.repo,
    required this.commands,
    required this.sectionLabels,
  });

  final ChatRepository repo;
  final List<ShortcutDef> commands;
  final List<String> sectionLabels;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  String _q = '';
  int _cursor = 0;

  /// Rows, as they were last built: what ↑/↓/Enter move over.
  List<_Item> _items = const [];

  static const _rowHeight = 44.0;
  static const _headerHeight = 28.0;
  static const _maxChats = 8;

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  (List<_Item>, List<_Item>) _results(AppLocalizations l10n) {
    final q = _q.trim();
    // Already the list's own order (pinned, then recent), which is the right
    // order for "nothing typed yet": the chats you were just in.
    final rooms = widget.repo.activeRooms;
    final List<_Item> chats;
    if (q.isEmpty) {
      chats = [
        for (final r in rooms.take(_maxChats))
          _Item.room(r, roomTitle(l10n, widget.repo, r)),
      ];
    } else {
      final scored = <(int, _Item)>[];
      for (final r in rooms) {
        final title = roomTitle(l10n, widget.repo, r);
        final s = paletteScore(title, q);
        if (s != null) scored.add((s, _Item.room(r, title)));
      }
      scored.sort((a, b) => b.$1.compareTo(a.$1));
      chats = [for (final s in scored.take(_maxChats)) s.$2];
    }
    final scoredCmds = <(int, _Item)>[];
    for (final d in widget.commands) {
      final title = AppShortcuts.label(l10n, d, sectionLabels: widget.sectionLabels);
      if (title.isEmpty) continue;
      final s = paletteScore(title, q);
      if (s != null) scoredCmds.add((s, _Item.command(d, title)));
    }
    if (q.isNotEmpty) scoredCmds.sort((a, b) => b.$1.compareTo(a.$1));
    return (chats, [for (final s in scoredCmds.take(q.isEmpty ? 6 : 8)) s.$2]);
  }

  void _move(int by) {
    if (_items.isEmpty) return;
    setState(() => _cursor = (_cursor + by) % _items.length);
    _reveal();
  }

  /// Keeps the cursor row on screen. Row offsets are fixed-height arithmetic,
  /// so this needs no layout lookups.
  void _reveal() {
    if (!_scroll.hasClients) return;
    final chatsCount = _items.where((i) => i.room != null).length;
    final inCommands = _cursor >= chatsCount;
    var top = _cursor * _rowHeight + _headerHeight;
    if (inCommands && chatsCount > 0) top += _headerHeight;
    final view = _scroll.position.viewportDimension;
    final at = _scroll.offset;
    if (top < at + _headerHeight) {
      _scroll.jumpTo((top - _headerHeight * (inCommands ? 2 : 1)).clamp(0, _scroll.position.maxScrollExtent));
    } else if (top + _rowHeight > at + view) {
      _scroll.jumpTo((top + _rowHeight - view).clamp(0, _scroll.position.maxScrollExtent));
    }
  }

  void _pick(int i) {
    if (i < 0 || i >= _items.length) return;
    Navigator.of(context).pop(_items[i]);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    // The input method's own candidate list answers arrows and Enter.
    if (_field.value.composing.isValid) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (e is KeyDownEvent &&
        (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter)) {
      _pick(_cursor);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final (chats, cmds) = _results(l10n);
    _items = [...chats, ...cmds];
    if (_cursor >= _items.length) _cursor = 0;
    var index = 0;

    Widget header(String text) => SizedBox(
          height: _headerHeight,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 5),
              child: Text(
                text,
                style: theme.caption.copyWith(
                  color: theme.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );

    Widget row(_Item item) {
      final i = index++;
      return _PaletteRow(
        key: ValueKey(item.room?.id ?? item.command!.id),
        item: item,
        repo: widget.repo,
        selected: i == _cursor,
        height: _rowHeight,
        onHover: () {
          if (_cursor != i) setState(() => _cursor = i);
        },
        onTap: () => _pick(i),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: (size.height * 0.16).clamp(24, 160), left: 16, right: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: GlassSurface(
              radius: theme.radiusXl,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Focus(
                    onKeyEvent: _onKey,
                    skipTraversal: true,
                    canRequestFocus: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.search, size: 20, color: theme.inkMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _field,
                              focusNode: _focus,
                              autofocus: true,
                              cursorColor: theme.accent,
                              style: theme.body.copyWith(fontSize: 19, color: theme.ink),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                hintText: l10n.kbdPaletteHint,
                                hintStyle: theme.body.copyWith(fontSize: 19, color: theme.inkMuted),
                              ),
                              onChanged: (v) => setState(() {
                                _q = v;
                                _cursor = 0;
                                if (_scroll.hasClients) _scroll.jumpTo(0);
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(height: 0.5, color: theme.divider),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        l10n.kbdPaletteEmpty,
                        textAlign: TextAlign.center,
                        style: theme.bodySoft,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (size.height * 0.5).clamp(160, 440),
                      ),
                      child: ListView(
                        controller: _scroll,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        children: [
                          if (chats.isNotEmpty) header(l10n.kbdPaletteChats),
                          for (final c in chats) row(c),
                          if (cmds.isNotEmpty) header(l10n.kbdPaletteCommands),
                          for (final c in cmds) row(c),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  Container(height: 0.5, color: theme.divider),
                  _Footer(l10n: l10n),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    super.key,
    required this.item,
    required this.repo,
    required this.selected,
    required this.height,
    required this.onHover,
    required this.onTap,
  });

  final _Item item;
  final ChatRepository repo;
  final bool selected;
  final double height;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final room = item.room;
    final cmd = item.command;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      // onHover, not onEnter: a list that scrolls under a still pointer
      // must not steal the cursor from the keyboard.
      onHover: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? theme.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (room != null)
                ChatRoomAvatar(room: room, size: 28, dmUser: repo.otherUserFor(room))
              else
                SizedBox(
                  width: 28,
                  child: Icon(CupertinoIcons.command, size: 17, color: theme.inkSoft),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.body.copyWith(fontSize: 15, color: theme.ink),
                ),
              ),
              if (room != null && room.visibleUnreadCount > 0)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
                ),
              if (cmd != null) Keycaps.forDef(cmd, size: KeycapSize.small),
              if (selected) ...[
                const SizedBox(width: 10),
                Keycap(KeyCombo.keyCap(LogicalKeyboardKey.enter), size: KeycapSize.small),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final style = theme.caption.copyWith(color: theme.inkMuted);
    Widget hint(List<String> caps, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in caps) ...[
              Keycap(c, size: KeycapSize.small),
              const SizedBox(width: 3),
            ],
            const SizedBox(width: 3),
            Text(label, style: style),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        children: [
          hint(['↑', '↓'], l10n.kbdPaletteMove),
          hint([KeyCombo.keyCap(LogicalKeyboardKey.enter)], l10n.kbdPaletteOpen),
          hint(['Esc'], l10n.kbdPaletteClose),
        ],
      ),
    );
  }
}
