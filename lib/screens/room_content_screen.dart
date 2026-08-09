import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/room_content_controller.dart';
import '../data/room_content_selection.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/document_saver.dart';
import '../media/file_meta.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../models/message_preview.dart';
import '../models/room_content_item.dart';
import '../services/link_opener.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/audio_message.dart';
import '../widgets/bulk_action_bar.dart';
import '../widgets/destructive_sheet.dart' show showConfirmSheet;
import '../widgets/forward_target_sheet.dart';
import '../widgets/media_grid_tile.dart';
import '../widgets/message_stamp.dart' show formatClockTime;
import '../widgets/pill_nav.dart';
import '../widgets/remote_image.dart';
import 'fullscreen_video_viewer.dart';
import 'media_pager_screen.dart';
import 'room_content_actions.dart';
import 'room_items.dart' show humanDay;

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

  /// The tabs this room actually offers, resolved once.
  ///
  /// Only ever shorter than [RoomContentTab.values] by the SAVED tab, which is
  /// gated on `canSaveMessages` — the same capability that decides whether the
  /// bubble menu offers SAVE at all. A room where nothing can be saved must not
  /// offer a pill leading to a list that can never fill, and the room-info row
  /// above is gated on exactly the same thing.
  late final List<RoomContentTab> _tabsShown;

  Map<String, RoomContentCount> _counts = const {};

  RoomContentController get _c => _controllers[_tab]!;

  @override
  void initState() {
    super.initState();
    final room = widget.repo.roomById(widget.roomId);
    final canSave =
        room != null && widget.repo.capabilitiesFor(room).canSaveMessages;
    _tabsShown = [
      for (final t in RoomContentTab.values)
        if (t != RoomContentTab.saved || canSave) t,
    ];
    // Falls back rather than throwing if a caller ever asks for a tab this room
    // does not offer: the browser opening on MEDIA is a far better outcome than
    // a route that cannot build.
    _tab = _tabsShown.contains(widget.initialTab)
        ? widget.initialTab
        : RoomContentTab.media;
    for (final t in _tabsShown) {
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
    // A bookmark is a place in the conversation, not a file. The other tabs
    // route by type because a photo wants the pager and a document wants the
    // OS — but the reason to keep a message is the exchange around it, so
    // every saved row goes back to where it was said, whatever it is. That is
    // also what the block this replaced did on tap.
    if (_tab == RoomContentTab.saved) {
      _showInChat(m);
      return;
    }
    switch (m.type) {
      case MessageType.image:
        _openPager(m);
      case MessageType.video:
        _openVideo(m);
      case MessageType.file:
        _saveOne(m);
      case MessageType.audio:
        // Nothing. A voice row carries a real player, and that player's own
        // button is what starts it — routing the row's tap anywhere would
        // fight it. Reaching the transcript from a voice note is the IN CHAT
        // action, the same way it is for four selected photos.
        break;
      case MessageType.text:
      case MessageType.url:
      case MessageType.system:
        _showInChat(m);
    }
  }

  /// Straight to the player, the same as a tap on a video in the transcript.
  ///
  /// Deliberately not through the pager. A video tapped in this grid used to
  /// open the gallery, which then handed off to the OS player over the top of
  /// itself — so closing the player left you looking at a fullscreen still of
  /// the video you had just watched, and closing was two gestures instead of
  /// one. The gallery is still there for swiping between things; it is just no
  /// longer in the way of watching one. The poster flies out of the tile
  /// either way.
  void _openVideo(ChatMessage m) {
    final id = m.mediaStorageId;
    if (id == null) return;
    FullscreenVideoViewer.open(
      context,
      storageId: id,
      api: widget.api,
      posterStorageId: m.posterStorageId,
      heroTag: roomMediaHeroTag(m.id),
    );
  }

  Future<void> _openPager(ChatMessage m) async {
    final media = _c.items;
    final start = media.indexWhere((x) => x.id == m.id);
    if (start < 0) return;

    final landed = await MediaPagerScreen.open(
      context,
      items: media,
      initialIndex: start,
      api: widget.api,
      onShowInChat: (msg) {
        // Pop the pager (a root-navigator route) before handing the message
        // back, or the transcript would animate in behind it.
        Navigator.of(context, rootNavigator: true).pop();
        _showInChat(msg);
      },
    );
    if (!mounted || landed == null || landed == start) return;
    _revealInGrid(landed);
  }

  /// Scrolls the grid so tile [index] is on screen.
  ///
  /// Swiping several photos deep in the pager and closing should not land you
  /// looking at the one you opened. It also gives the closing hero somewhere to
  /// fly to: a tile scrolled outside the grid's build range has no widget for
  /// the flight to match, and Flutter degrades to a plain fade.
  void _revealInGrid(int index) {
    if (!_scroll.hasClients) return;
    final width = MediaQuery.sizeOf(context).width;
    final columns = _gridColumns(width);
    final rowExtent = width / columns + _gridSpacing;
    final target = (index ~/ columns) * rowExtent;

    // Only when it is genuinely off screen — jumping a tile that is already
    // visible moves the grid under the reader for no reason.
    final pos = _scroll.position;
    final viewportEnd = pos.pixels + pos.viewportDimension - rowExtent;
    if (target >= pos.pixels && target <= viewportEnd) return;

    _scroll.jumpTo(target.clamp(pos.minScrollExtent, pos.maxScrollExtent));
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
    final l10n = AppLocalizations.of(context);
    final name = m.fileName ?? l10n.roomContentScreenDefaultDocumentName;
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
        SnackBar(content: Text(l10n.roomContentScreenCouldntOpenFile)),
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
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _selection.clear();

    final ok = await shareMessages(api: widget.api, messages: picked);
    if (!mounted || ok) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.roomContentScreenCouldntShare)),
    );
  }

  Future<void> _copyLinks() async {
    final ids = _selection.ids;
    final urls = [
      for (final l in _c.links)
        if (ids.contains(l.message.id)) l.url,
    ];
    if (urls.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: urls.join('\n')));
    if (!mounted) return;
    _selection.clear();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.roomContentScreenLinksCopied(urls.length))),
    );
  }

  Future<void> _deleteSelected() async {
    final picked = _selected;
    if (picked.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showConfirmSheet(
      context,
      headline: l10n.roomContentScreenDeleteHeadline(picked.length),
      // Named plainly, because it is not "remove from my gallery": the rows go
      // for everyone in the room. They are all the caller's own — see
      // [_canDeleteAll] — so this asks about reach, not about ownership.
      body: l10n.roomContentScreenDeleteBody,
      confirmLabel: l10n.roomContentScreenDeleteForEveryone,
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

  /// DELETE only appears when every pick is yours, so the button never promises
  /// something the server will refuse.
  ///
  /// Your own messages, and only those — the same rule the transcript's
  /// selection bar applies. This is delete-for-everyone, so it is scoped to
  /// what you sent; owning the room does not extend it to other people's
  /// photos. The server enforces it too, and `deleteMany` reports what it
  /// skipped if the two ever disagree.
  bool _canDeleteAll(List<ChatMessage> picked) {
    if (picked.isEmpty) return false;
    final me = widget.repo.userId;
    if (me == null) return false;
    return picked.every((m) => m.senderId == me);
  }

  Widget _header(AppTheme theme) {
    return AnimatedBuilder(
      animation: _selection,
      builder: (_, _) {
        final l10n = AppLocalizations.of(context);
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
                tooltip: selecting
                    ? l10n.roomContentScreenCancelTooltip
                    : l10n.roomContentScreenBackTooltip,
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
                      selecting
                          ? l10n.roomContentScreenSelectingLabel
                          : l10n.roomContentScreenSharedContentLabel,
                      style: theme.monoTiny.copyWith(letterSpacing: 2.2),
                    ),
                    Text(
                      selecting
                          ? l10n.roomContentScreenSelectionCount(picked)
                          : _tab.headerLabel(context),
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
                label: selecting
                    ? l10n.roomContentScreenSelectAllActiveLabel
                    : l10n.roomContentScreenSelectAllLabel,
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
      // Rebuilt with the active controller, which listens to the repository —
      // so unsaving the last bookmark drops the SAVED badge on the same frame
      // the row leaves the list, rather than on the next screen open.
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => SingleChildScrollView(
          // Five labels plus badges overflow a narrow phone; scrolling is what
          // keeps the strip honest rather than shrinking the text.
          scrollDirection: Axis.horizontal,
          child: PillNav(
            items: [
              for (final t in _tabsShown)
                PillNavItem(
                  id: t.name,
                  label: t.label(context),
                  badge: (_countFor(t) ?? RoomContentCount.zero).badge,
                ),
            ],
            activeId: _tab.name,
            onChange: (id) => _switchTo(
              _tabsShown.firstWhere((t) => t.name == id),
            ),
          ),
        ),
      ),
    );
  }

  /// This tab's badge number, from the server counts or from the bookmark
  /// subscription — see [roomContentCountFor].
  RoomContentCount? _countFor(RoomContentTab tab) => roomContentCountFor(
        tab,
        serverCounts: _counts,
        savedCount: widget.repo.savedFor(widget.roomId).length,
      );

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
      RoomContentTab.saved => _savedList(theme, bottomPad),
      RoomContentTab.file || RoomContentTab.voice => _rowList(theme, bottomPad),
    };
  }

  Widget _mediaGrid(AppTheme theme, double bottomPad) {
    final items = _c.items;
    final width = MediaQuery.sizeOf(context).width;
    final columns = _gridColumns(width);
    final tileWidth = width / columns;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return GridView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(2, 6, 2, bottomPad),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: _gridSpacing,
        mainAxisSpacing: _gridSpacing,
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
              api: widget.api,
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

  /// This reader's own shelf for this room.
  ///
  /// No day headers, unlike [_rowList] and [_linkList]. Those group by
  /// `createdAt` and only read correctly because their lists descend by it;
  /// this one descends by `savedAt` instead — see [RoomContentController.items]
  /// — so a "yesterday" header could sit above a message from last March. The
  /// per-row timestamp carries the date question on its own here.
  ///
  /// No tail spinner either: `bookmarks.ts` caps the list at 50 and the whole
  /// of it is already in memory, so there is never another page coming.
  Widget _savedList(AppTheme theme, double bottomPad) {
    final items = _c.items;
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(14, 6, 14, bottomPad),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final m = items[i];
        return _SavedRow(
          theme: theme,
          message: m,
          api: widget.api,
          selected: _selection.contains(m.id),
          selecting: _selection.active,
          onTap: () => _openMessage(m),
          onLongPress: () {
            HapticFeedback.selectionClick();
            _selection.begin(m.id);
          },
          onUnsave: () => _unsave(m),
        );
      },
    );
  }

  /// Drops one bookmark. Nothing is removed locally: the subscription behind
  /// [ChatRepository.savedFor] is what this list reads, and it reconciles on
  /// its own — leading it here would fight it rather than lead it.
  Future<void> _unsave(ChatMessage m) async {
    HapticFeedback.selectionClick();
    await widget.repo.unsaveMessage(widget.roomId, m.id);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Hairline gap between tiles. Shared with [_revealInGrid], which has to
  /// reproduce the grid's row extent to scroll to one.
  static const double _gridSpacing = 2;

  /// Wider panes get more columns rather than bigger squares — a 200pt photo
  /// thumbnail is not more useful than a 110pt one, just heavier to decode.
  static int _gridColumns(double width) => width >= Breakpoints.expanded
      ? 6
      : width >= Breakpoints.medium
          ? 5
          : 3;
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
    final l10n = AppLocalizations.of(context);
    final what = switch (tab) {
      RoomContentTab.media => l10n.roomContentScreenEmptyMedia,
      RoomContentTab.file => l10n.roomContentScreenEmptyFiles,
      RoomContentTab.voice => l10n.roomContentScreenEmptyVoice,
      RoomContentTab.links => l10n.roomContentScreenEmptyLinks,
      // Three sentences where the other four get a phrase, and the extra two
      // are the point. This is the moment a reader is most likely to be asking
      // what the list even is, and the answer they must not guess wrong is that
      // it is theirs alone — a pin is room state everyone sees, a save is not.
      // Saying it here rather than only in a caption they scrolled past on
      // another screen is what keeps the distinction attached to the feature.
      RoomContentTab.saved => l10n.roomContentScreenEmptySaved,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          failed ? l10n.roomContentScreenLoadFailed : what,
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
    required this.api,
    required this.tab,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final AppTheme theme;
  final ChatMessage message;
  final ChatApi api;
  final RoomContentTab tab;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    if (tab == RoomContentTab.voice) return _voiceRow(context);

    final name = message.fileName ??
        AppLocalizations.of(context).roomContentScreenDefaultDocumentName;
    final sub = [
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
        child: Text(
          fileTypeBadge(name),
          style: theme.monoTiny.copyWith(color: theme.accent, fontSize: 9.5),
        ),
      ),
      title: name,
      subtitle: sub,
    );
  }

  /// A voice note, with a player that actually plays.
  ///
  /// [AudioMessage] rather than an icon and a duration: a voice note the user
  /// has to open a chat to hear is a list of things they cannot listen to.
  /// Mounting one per row is the same density the transcript already runs at —
  /// `ListView.builder` only builds the visible window — which is why this is
  /// safe where mounting `VideoMessage` per grid tile would not be.
  Widget _voiceRow(BuildContext context) {
    return _SelectableRow(
      theme: theme,
      selected: selected,
      selecting: selecting,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: AppLocalizations.of(context)
          .roomContentScreenVoiceMessageFrom(message.senderName),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.senderName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
          const SizedBox(height: 4),
          // Deaf to the pointer while selecting, so a tap anywhere on the row
          // picks it instead of starting playback the user did not ask for.
          IgnorePointer(
            ignoring: selecting,
            child: AudioMessage(
              api: api,
              storageId: message.mediaStorageId,
              // Always "theirs" here: this is a browser, not a transcript, and
              // there is no left/right side to take a colour from.
              isMine: false,
            ),
          ),
        ],
      ),
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

/// One bookmark, as the SAVED tab draws it.
///
/// Two tap targets, the same pair the room-info block this replaced had: the
/// body travels to where the message was said, the trailing glyph lets it go.
/// Keeping the release here rather than adding an UNSAVE button to the action
/// bar is deliberate — that bar can already show five buttons on a phone, and
/// dropping ONE bookmark is a per-row gesture rather than a bulk one.
///
/// The glyph is hidden while a selection is live, because the checkbox takes
/// that end of the row and a filled bookmark beside a checkbox reads as a
/// second thing to pick.
class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.theme,
    required this.message,
    required this.api,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    required this.onUnsave,
  });

  final AppTheme theme;
  final ChatMessage message;
  final ChatApi api;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = message;
    // View-once media has no storage id — the server withholds it — so there is
    // deliberately nothing to show for those beyond the words.
    final hasThumb = !m.viewOnce &&
        m.mediaStorageId != null &&
        (m.type == MessageType.image || m.type == MessageType.video);

    return _SelectableRow(
      theme: theme,
      selected: selected,
      selecting: selecting,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: l10n.roomContentScreenSavedJumpSemantic(m.senderName),
      leading: hasThumb
          ? ClipRRect(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              child: SizedBox(
                width: 40,
                height: 40,
                child: RemoteImage(
                  storageId: m.mediaStorageId!,
                  api: api,
                  fit: BoxFit.cover,
                ),
              ),
            )
          : Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                borderRadius: BorderRadius.circular(theme.radiusSm),
                border: Border.all(color: theme.divider, width: 0.8),
              ),
              // What KIND of message this is, not that it is saved. Every row
              // in this tab is saved, so a bookmark here would carry no
              // information — and would then be the second one in the row,
              // beside the trailing glyph that actually means something.
              child: Icon(_kindGlyph(m), size: 17, color: theme.accent),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  m.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyEmph.copyWith(color: theme.ink),
                ),
              ),
              const SizedBox(width: 6),
              // The message's own time, not `savedAt`. The list is already
              // ordered by when it was saved; what a reader needs here is where
              // in the conversation they are being sent.
              Text(
                formatClockTime(m.createdAt),
                style: theme.monoTiny.copyWith(color: theme.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            messagePreviewLine(m, hasThumbnail: hasThumb),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
        ],
      ),
      trailing: FocusableTap(
        onTap: onUnsave,
        radius: theme.radiusSm,
        semanticLabel: l10n.roomContentScreenUnsaveSemantic(m.senderName),
        child: GestureDetector(
          onTap: onUnsave,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            // Filled, and the only fill in the row: this is the mark the
            // bubble wears and the action menu fills in, so tapping it to make
            // the row leave reads as undoing that.
            child: Icon(CupertinoIcons.bookmark_fill,
                size: 18, color: theme.accent),
          ),
        ),
      ),
    );
  }

  /// Something to look at for a bookmark with no picture behind it. A saved
  /// list is the one place in this browser that mixes kinds, so the square
  /// answers "what is this" rather than repeating "this is saved".
  static IconData _kindGlyph(ChatMessage m) => switch (m.type) {
        MessageType.audio => CupertinoIcons.waveform,
        MessageType.file => CupertinoIcons.doc,
        MessageType.url => CupertinoIcons.link,
        // Includes image and video, which only reach here with no storage id —
        // a view-once photo, or one whose upload never landed. A picture glyph
        // would promise a picture that is not coming.
        _ => CupertinoIcons.quote_bubble,
      };
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
    this.leading,
    this.title,
    this.subtitle,
    this.body,
    this.trailing,
  });

  final AppTheme theme;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String semanticLabel;

  /// The square at the head of the row. Omitted by rows whose [body] is the
  /// whole content — a voice player has its own play disc and a second circle
  /// beside it reads as two buttons.
  final Widget? leading;

  final String? title;
  final String? subtitle;

  /// Replaces the [title]/[subtitle] pair entirely.
  final Widget? body;

  /// A second tap target at the tail of the row, drawn only while selection is
  /// OFF — the checkbox owns that end once it is on, and the row must be a
  /// single unambiguous pick target while a batch is being assembled.
  final Widget? trailing;

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
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 11),
              ],
              Expanded(
                child: body ??
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyEmph.copyWith(color: theme.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.caption.copyWith(color: theme.inkMuted),
                        ),
                      ],
                    ),
              ),
              if (!selecting && trailing != null) trailing!,
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
    final l10n = AppLocalizations.of(context);
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
              BulkActionButton(
                theme: theme,
                icon: CupertinoIcons.arrowshape_turn_up_right,
                label: l10n.roomContentScreenForwardAction,
                onTap: onForward,
              ),
              if (isLinks)
                BulkActionButton(
                  theme: theme,
                  icon: CupertinoIcons.doc_on_clipboard,
                  label: l10n.roomContentScreenCopyAction,
                  onTap: onCopy,
                )
              else ...[
                // `gal` has no web implementation — see the MissingPluginException
                // note in profile_screen.dart. Hidden rather than offered and
                // then failed.
                if (savable && !kIsWeb)
                  BulkActionButton(
                    theme: theme,
                    icon: CupertinoIcons.arrow_down_to_line,
                    label: l10n.roomContentScreenSaveAction,
                    onTap: onSave,
                  ),
                BulkActionButton(
                  theme: theme,
                  icon: CupertinoIcons.share,
                  label: l10n.roomContentScreenShareAction,
                  onTap: onShare,
                ),
              ],
              if (onShowInChat != null)
                BulkActionButton(
                  theme: theme,
                  icon: CupertinoIcons.chat_bubble,
                  label: l10n.roomContentScreenInChatAction,
                  onTap: onShowInChat!,
                ),
              if (canDelete)
                BulkActionButton(
                  theme: theme,
                  icon: CupertinoIcons.trash,
                  label: l10n.roomContentScreenDeleteAction,
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

