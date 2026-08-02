import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/room_content_controller.dart';
import '../data/room_content_selection.dart';
import '../keyboard/focusable_tap.dart';
import '../media/document_saver.dart';
import '../media/file_meta.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../models/room_content_item.dart';
import '../services/link_opener.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/destructive_sheet.dart' show showConfirmSheet;
import '../widgets/forward_target_sheet.dart';
import '../widgets/media_grid_tile.dart';
import '../widgets/pill_nav.dart';
import 'media_pager_screen.dart';
import 'room_content_actions.dart';
import 'room_items.dart' show formatClockDuration, humanDay;

/// Everything a room has shared, by kind, with multi-select.
///
/// Pushed from `RoomInfoScreen`, and pops with a [ChatMessage] when the user
/// asks to see one in the transcript — `RoomInfoScreen` passes that straight
/// through to `RoomScreen`, which owns the travel machinery. A plain result
/// rather than a callback so nothing here holds a reference to a screen two
/// routes down that may have been disposed by the time it is used.
class RoomContentScreen extends StatefulWidget {
  const RoomContentScreen({
    super.key,
    required this.roomId,
    required this.repo,
    required this.api,
    this.initialTab = RoomContentTab.media,
  });

  final String roomId;
  final ChatRepository repo;
  final ChatApi api;
  final RoomContentTab initialTab;

  @override
  State<RoomContentScreen> createState() => _RoomContentScreenState();
}

class _RoomContentScreenState extends State<RoomContentScreen> {
  late RoomContentTab _tab;
  final _selection = RoomContentSelection();
  final _scroll = ScrollController();

  /// One controller per tab, kept alive across switches so going back to a tab
  /// doesn't re-fetch what it already had — and doesn't lose the user's scroll
  /// depth in a gallery they may have paged a long way into.
  final Map<RoomContentTab, RoomContentController> _controllers = {};

  Map<String, RoomContentCount> _counts = const {};

  RoomContentController get _c => _controllers[_tab]!;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    for (final t in RoomContentTab.values) {
      _controllers[t] = RoomContentController(
        repo: widget.repo,
        api: widget.api,
        roomId: widget.roomId,
        tab: t,
      );
    }
    _c.loadInitial();
    _scroll.addListener(_onScroll);
    _loadCounts();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _selection.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final me = widget.repo.userId;
    if (me == null) return;
    try {
      final counts = await widget.api.roomContentCounts(
        roomId: widget.roomId,
        userId: me,
      );
      if (mounted) setState(() => _counts = counts);
    } catch (_) {
      // Decoration. A tab with no badge is strictly better than a screen that
      // refuses to open because a count didn't arrive.
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels < pos.maxScrollExtent - 600) return;
    _c.loadMore();
  }

  void _switchTo(RoomContentTab tab) {
    if (tab == _tab) return;
    // A selection is scoped to the list it was made in: carrying three photos
    // into the LINKS tab would leave the action bar acting on rows that are
    // not on screen.
    _selection.clear();
    setState(() => _tab = tab);
    _c.loadInitial();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // ───────────────────────── actions ─────────────────────────

  /// The messages the action bar would act on, resolved against what is
  /// actually on screen right now — never the raw id count. See
  /// [RoomContentSelection.resolve].
  List<ChatMessage> get _selected => _selection.resolve(_c.items);

  void _openMessage(ChatMessage m) {
    if (_selection.active) {
      _selection.toggle(m.id);
      return;
    }
    switch (m.type) {
      case MessageType.image:
      case MessageType.video:
        final media = _c.items;
        MediaPagerScreen.open(
          context,
          items: media,
          initialIndex: media.indexWhere((x) => x.id == m.id).clamp(0, media.length - 1),
          api: widget.api,
          onShowInChat: (msg) {
            // Pop the pager (a root-navigator route) before handing the
            // message back, or the transcript would animate in behind it.
            Navigator.of(context, rootNavigator: true).pop();
            _showInChat(msg);
          },
        );
      case MessageType.file:
        _saveOne(m);
      case MessageType.audio:
      case MessageType.text:
      case MessageType.url:
      case MessageType.system:
        _showInChat(m);
    }
  }

  /// Hands [m] back up the stack. `RoomInfoScreen` forwards it to `RoomScreen`,
  /// which is the only place that knows how to travel to a message.
  void _showInChat(ChatMessage m) {
    if (!mounted) return;
    Navigator.of(context).pop(m);
  }

  Future<void> _saveOne(ChatMessage m) async {
    final id = m.mediaStorageId;
    if (id == null) return;
    final name = m.fileName ?? 'document';
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DocumentSaver.save(
        api: widget.api,
        storageId: id,
        fileName: name,
        mimeType: m.mimeType ?? mimeTypeForFileName(name),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("couldn't open that file")),
      );
    }
  }

  Future<void> _forward() async {
    final picked = _selected;
    if (picked.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    final targets = await showForwardTargetSheet(
      context,
      repo: widget.repo,
      messageCount: picked.length,
      excludeRoomId: widget.roomId,
    );
    if (targets == null || targets.isEmpty || !mounted) return;

    final result = await forwardMessages(
      api: widget.api,
      repo: widget.repo,
      sourceRoomId: widget.roomId,
      targets: [for (final t in targets) t.id],
      messages: picked,
    );
    if (!mounted) return;

    _selection.clear();
    messenger.showSnackBar(SnackBar(content: Text(result.summary)));
  }

  Future<void> _saveSelected() async {
    final picked = _selected;
    if (picked.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    _selection.clear();

    final result = await saveMessagesToDevice(api: widget.api, messages: picked);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(result.summary)));
  }

  Future<void> _shareSelected() async {
    final picked = _selected;
    if (picked.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    _selection.clear();

    final ok = await shareMessages(api: widget.api, messages: picked);
    if (!mounted || ok) return;
    messenger.showSnackBar(
      const SnackBar(content: Text("couldn't share those")),
    );
  }

  Future<void> _copyLinks() async {
    final ids = _selection.ids;
    final urls = [
      for (final l in _c.links)
        if (ids.contains(l.message.id)) l.url,
    ];
    if (urls.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: urls.join('\n')));
    if (!mounted) return;
    _selection.clear();
    messenger.showSnackBar(
      SnackBar(content: Text(urls.length == 1 ? 'copied' : 'copied ${urls.length} links')),
    );
  }

  Future<void> _deleteSelected() async {
    final picked = _selected;
    if (picked.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showConfirmSheet(
      context,
      headline: picked.length == 1 ? 'DELETE MESSAGE' : 'DELETE ${picked.length} MESSAGES',
      // Named plainly, because it is not "remove from my gallery": the rows go
      // for everyone in the room, and `roomMembers.role` is fixed at join time
      // so a DM's initiator can do this to the other person's messages.
      body: 'This removes them for everyone in this chat. It cannot be undone.',
      confirmLabel: 'DELETE FOR EVERYONE',
    );
    if (!confirmed || !mounted) return;

    final ids = [for (final m in picked) m.id];
    final result = await deleteMessages(
      api: widget.api,
      repo: widget.repo,
      messageIds: ids,
    );
    if (!mounted) return;

    _selection.clear();
    // Lead the subscription rather than waiting on it: the paged half is a
    // snapshot and would keep describing deleted rows until a refresh.
    _c.forget(ids.toSet());
    _loadCounts();
    messenger.showSnackBar(SnackBar(content: Text(result.summary)));
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(
        children: [
          Positioned.fill(child: theme.backgroundLayer(context)),
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              child: Column(
                children: [
                  _header(theme),
                  _tabs(theme),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_c, _selection]),
                      builder: (_, _) => _body(theme),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: Listenable.merge([_c, _selection]),
              builder: (_, _) => RoomContentActionBar(
                theme: theme,
                tab: _tab,
                selected: _selected,
                onForward: _forward,
                onSave: _saveSelected,
                onShare: _shareSelected,
                onCopy: _copyLinks,
                onDelete: _deleteSelected,
                canDelete: _canDeleteAll(_selected),
                onShowInChat: _selected.length == 1
                    ? () => _showInChat(_selected.single)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// DELETE only appears when every pick is deletable, so the button never
  /// promises something the server will refuse. The server still enforces it —
  /// this is the UX half, and `deleteMany` reports what it skipped.
  bool _canDeleteAll(List<ChatMessage> picked) {
    if (picked.isEmpty) return false;
    final me = widget.repo.userId;
    if (me == null) return false;
    if (picked.every((m) => m.senderId == me)) return true;
    // Room owners may delete anything. `roomMembers.role` is set at join time
    // and never changes, so this cannot go stale mid-session.
    return widget.repo.roomById(widget.roomId)?.createdBy == me;
  }

  Widget _header(AppTheme theme) {
    return AnimatedBuilder(
      animation: _selection,
      builder: (_, _) {
        final picked = _selected.length;
        final selecting = _selection.active;
        return Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.divider)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  selecting ? CupertinoIcons.xmark : CupertinoIcons.chevron_left,
                  color: theme.ink,
                  size: 20,
                ),
                tooltip: selecting ? 'Cancel' : 'Back',
                onPressed: () {
                  if (selecting) {
                    _selection.clear();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selecting ? 'SELECTING' : 'SHARED CONTENT',
                      style: theme.monoTiny.copyWith(letterSpacing: 2.2),
                    ),
                    Text(
                      selecting
                          ? (picked == 0 ? 'nothing picked' : '$picked selected')
                          : _tab.label.toLowerCase(),
                      style: theme.displayMedium.copyWith(fontSize: 21),
                    ),
                  ],
                ),
              ),
              // The primary way in on every platform. Long-press is a phone
              // shortcut on top of this, not the only door — desktop has no
              // long-press idiom and this app defines no right-click menu.
              _HeaderAction(
                theme: theme,
                label: selecting ? 'ALL' : 'SELECT',
                onTap: () {
                  if (!selecting) {
                    _selection.begin();
                    return;
                  }
                  _selection.selectAll(
                    _tab == RoomContentTab.links
                        ? {for (final l in _c.links) l.message.id}
                        : [for (final m in _c.items) m.id],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabs(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: SingleChildScrollView(
        // Four labels plus badges overflow a narrow phone; scrolling is what
        // keeps the strip honest rather than shrinking the text.
        scrollDirection: Axis.horizontal,
        child: PillNav(
          items: [
            for (final t in RoomContentTab.values)
              PillNavItem(
                id: t.name,
                label: t.label,
                badge: (_counts[t.countKey] ?? RoomContentCount.zero).badge,
              ),
          ],
          activeId: _tab.name,
          onChange: (id) => _switchTo(
            RoomContentTab.values.firstWhere((t) => t.name == id),
          ),
        ),
      ),
    );
  }

  Widget _body(AppTheme theme) {
    // Ids are pruned after the list settles so the header count and the actions
    // can never disagree about how much is picked.
    _selection.prune(_c.items);

    if (_c.isEmpty) {
      if (!_c.loadedOnce || _c.isLoading) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }
      return _EmptyState(theme: theme, tab: _tab, failed: _c.error != null);
    }

    // Bottom padding leaves room for the action bar to float over the tail of
    // the list instead of covering the last row.
    final bottomPad = 24 + MediaQuery.paddingOf(context).bottom +
        (_selection.active ? 78 : 0);

    return switch (_tab) {
      RoomContentTab.media => _mediaGrid(theme, bottomPad),
      RoomContentTab.links => _linkList(theme, bottomPad),
      RoomContentTab.file || RoomContentTab.voice => _rowList(theme, bottomPad),
    };
  }

  Widget _mediaGrid(AppTheme theme, double bottomPad) {
    final items = _c.items;
    // Wider panes get more columns rather than bigger squares — a 200pt photo
    // thumbnail is not more useful than a 110pt one, just heavier to decode.
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= Breakpoints.expanded
        ? 6
        : width >= Breakpoints.medium
            ? 5
            : 3;
    final tileWidth = width / columns;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return GridView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(2, 6, 2, bottomPad),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: items.length + (_c.hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= items.length) return const _TailSpinner();
        final m = items[i];
        return MediaGridTile(
          message: m,
          api: widget.api,
          selected: _selection.contains(m.id),
          selecting: _selection.active,
          decodeWidth: (tileWidth * dpr).round(),
          onTap: () => _openMessage(m),
          onLongPress: () {
            HapticFeedback.selectionClick();
            _selection.begin(m.id);
          },
        );
      },
    );
  }

  Widget _rowList(AppTheme theme, double bottomPad) {
    final items = _c.items;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(14, 6, 14, bottomPad),
      itemCount: items.length + (_c.hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= items.length) return const _TailSpinner();
        final m = items[i];
        final showDay = i == 0 || !_sameDay(items[i - 1].createdAt, m.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDay) _DayHeader(theme: theme, at: m.createdAt),
            _ContentRow(
              theme: theme,
              message: m,
              tab: _tab,
              selected: _selection.contains(m.id),
              selecting: _selection.active,
              onTap: () => _openMessage(m),
              onLongPress: () {
                HapticFeedback.selectionClick();
                _selection.begin(m.id);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _linkList(AppTheme theme, double bottomPad) {
    final links = _c.links;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(14, 6, 14, bottomPad),
      itemCount: links.length + (_c.hasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= links.length) return const _TailSpinner();
        final l = links[i];
        final showDay =
            i == 0 || !_sameDay(links[i - 1].createdAt, l.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDay) _DayHeader(theme: theme, at: l.createdAt),
            _LinkRow(
              theme: theme,
              link: l,
              selected: _selection.contains(l.message.id),
              selecting: _selection.active,
              onTap: () {
                if (_selection.active) {
                  _selection.toggle(l.message.id);
                } else {
                  LinkOpener.open(context, l.url);
                }
              },
              onLongPress: () {
                HapticFeedback.selectionClick();
                _selection.begin(l.message.id);
              },
            ),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.theme, required this.at});

  final AppTheme theme;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 6),
      child: Text(
        humanDay(DateTime(at.year, at.month, at.day)),
        style: theme.monoTiny.copyWith(letterSpacing: 1.8, color: theme.inkMuted),
      ),
    );
  }
}

class _TailSpinner extends StatelessWidget {
  const _TailSpinner();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.theme,
    required this.tab,
    required this.failed,
  });

  final AppTheme theme;
  final RoomContentTab tab;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final what = switch (tab) {
      RoomContentTab.media => 'no photos or videos yet',
      RoomContentTab.file => 'no files yet',
      RoomContentTab.voice => 'no voice notes yet',
      RoomContentTab.links => 'no links yet',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          failed ? "couldn't load that" : what,
          textAlign: TextAlign.center,
          style: theme.bodySoft,
        ),
      ),
    );
  }
}

/// A file or voice-note row.
class _ContentRow extends StatelessWidget {
  const _ContentRow({
    required this.theme,
    required this.message,
    required this.tab,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final AppTheme theme;
  final ChatMessage message;
  final RoomContentTab tab;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isVoice = tab == RoomContentTab.voice;
    final name = isVoice ? 'voice message' : (message.fileName ?? 'document');
    final ms = message.mediaDurationMs;
    final sub = isVoice
        ? (ms == null || ms <= 0
            ? message.senderName
            : '${formatClockDuration(Duration(milliseconds: ms))} · ${message.senderName}')
        : [
            if (message.fileSize != null && message.fileSize! > 0)
              formatFileSize(message.fileSize!),
            message.senderName,
          ].join(' · ');

    return _SelectableRow(
      theme: theme,
      selected: selected,
      selecting: selecting,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: name,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.surfaceSunken,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(color: theme.divider, width: 0.8),
        ),
        child: isVoice
            ? Icon(CupertinoIcons.waveform, size: 18, color: theme.accent)
            : Text(
                fileTypeBadge(name),
                style: theme.monoTiny.copyWith(color: theme.accent, fontSize: 9.5),
              ),
      ),
      title: name,
      subtitle: sub,
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.theme,
    required this.link,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final AppTheme theme;
  final RoomLink link;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(link.url)?.host ?? link.url;
    return _SelectableRow(
      theme: theme,
      selected: selected,
      selecting: selecting,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: link.url,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.surfaceSunken,
          borderRadius: BorderRadius.circular(theme.radiusSm),
          border: Border.all(color: theme.divider, width: 0.8),
        ),
        child: Icon(CupertinoIcons.link, size: 17, color: theme.accent),
      ),
      title: host,
      subtitle: link.url,
    );
  }
}

/// Shared chrome for every list row: a leading square, two lines, and the
/// selection ring that replaces nothing when selection is off.
class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.theme,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.semanticLabel,
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  final AppTheme theme;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String semanticLabel;
  final Widget leading;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // `FocusableTap` registers no gesture recognizer of its own, so the bare
    // `GestureDetector` inside is what actually receives the pointer. Both
    // carry the handler; wrapping alone would render a row that does nothing.
    // Never an InkWell — this app draws no ink anywhere.
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color:
                selected ? theme.accent.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(
              color: selected ? theme.accent : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyEmph.copyWith(color: theme.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.caption.copyWith(color: theme.inkMuted),
                    ),
                  ],
                ),
              ),
              if (selecting) ...[
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: theme.motionFast,
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? theme.accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? theme.accent : theme.divider,
                      width: 1.4,
                    ),
                  ),
                  child: selected
                      ? Icon(CupertinoIcons.check_mark,
                          size: 13, color: theme.accentInk)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  final AppTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: theme.chipDecoration(filled: false),
          child: Text(
            label,
            style: theme.monoTiny.copyWith(
              color: theme.accent,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating bar of bulk actions.
///
/// Zero-height when nothing is picked, so the list layout holds it
/// unconditionally — the same contract `PinnedMessageBanner` uses.
class RoomContentActionBar extends StatelessWidget {
  const RoomContentActionBar({
    super.key,
    required this.theme,
    required this.tab,
    required this.selected,
    required this.onForward,
    required this.onSave,
    required this.onShare,
    required this.onCopy,
    required this.onDelete,
    required this.canDelete,
    required this.onShowInChat,
  });

  final AppTheme theme;
  final RoomContentTab tab;
  final List<ChatMessage> selected;
  final VoidCallback onForward;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final bool canDelete;

  /// Single-selection only — "show in chat" has no meaning for four messages.
  final VoidCallback? onShowInChat;

  @override
  Widget build(BuildContext context) {
    if (selected.isEmpty) return const SizedBox.shrink();
    final isLinks = tab == RoomContentTab.links;
    // Photos and videos are the only things the OS photo library will take.
    final savable = selected.any(
      (m) => m.type == MessageType.image || m.type == MessageType.video,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: theme.sheetDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BarAction(
                theme: theme,
                icon: CupertinoIcons.arrowshape_turn_up_right,
                label: 'FORWARD',
                onTap: onForward,
              ),
              if (isLinks)
                _BarAction(
                  theme: theme,
                  icon: CupertinoIcons.doc_on_clipboard,
                  label: 'COPY',
                  onTap: onCopy,
                )
              else ...[
                // `gal` has no web implementation — see the MissingPluginException
                // note in profile_screen.dart. Hidden rather than offered and
                // then failed.
                if (savable && !kIsWeb)
                  _BarAction(
                    theme: theme,
                    icon: CupertinoIcons.arrow_down_to_line,
                    label: 'SAVE',
                    onTap: onSave,
                  ),
                _BarAction(
                  theme: theme,
                  icon: CupertinoIcons.share,
                  label: 'SHARE',
                  onTap: onShare,
                ),
              ],
              if (onShowInChat != null)
                _BarAction(
                  theme: theme,
                  icon: CupertinoIcons.chat_bubble,
                  label: 'IN CHAT',
                  onTap: onShowInChat!,
                ),
              if (canDelete)
                _BarAction(
                  theme: theme,
                  icon: CupertinoIcons.trash,
                  label: 'DELETE',
                  destructive: true,
                  onTap: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final AppTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ink = destructive ? theme.danger : theme.ink;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusSm,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: ink),
              const SizedBox(height: 5),
              Text(
                label,
                style: theme.monoTiny.copyWith(color: ink, letterSpacing: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
