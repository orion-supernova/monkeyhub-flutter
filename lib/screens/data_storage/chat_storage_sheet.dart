import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../data/chat_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/storage/storage_kinds.dart';
import '../../media/storage/storage_service.dart';
import '../../theme/layout.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/chat_list_row.dart' show ChatRoomAvatar;
import '../../widgets/donut_chart.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/sheet_kit.dart';
import 'storage_labels.dart';
import 'usage_widgets.dart';

/// One chat's share of the cache, opened from Storage Usage's Chats tab: its
/// face in the ring, the breakdown by kind with the same check-to-keep rows,
/// and a clear button for exactly that chat.
///
/// Opens as a sheet, a glance with a look at the chat's media. Its expand
/// button turns it into a full page with everything that chat keeps on the
/// device, every photo, video and file selectable, and a close button.
Future<void> showChatStorageSheet(
  BuildContext context, {
  required RoomUsage usage,
  required ChatRepository repo,
  required ChatApi api,
}) {
  HapticFeedback.lightImpact();
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => _ChatStorage(
      roomId: usage.roomId,
      repo: repo,
      api: api,
      full: false,
    ),
  );
}

/// The same chat as a full page, sliding up from the bottom the way the
/// sheet it grew out of did.
Future<void> openChatStoragePage(
  BuildContext context, {
  required String roomId,
  required ChatRepository repo,
  required ChatApi api,
}) =>
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          _ChatStorage(roomId: roomId, repo: repo, api: api, full: true),
    ));

class _ChatStorage extends StatefulWidget {
  const _ChatStorage({
    required this.roomId,
    required this.repo,
    required this.api,
    required this.full,
  });

  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

  /// The page rather than the sheet: every item, selectable, and a close
  /// button in place of the sheet's grab handle.
  final bool full;

  @override
  State<_ChatStorage> createState() => _ChatStorageState();
}

class _ChatStorageState extends State<_ChatStorage> with StorageSelection {
  final _service = StorageService.instance;
  final _scroll = ScrollController();

  @override
  ChatApi get selectionApi => widget.api;

  /// Kinds unticked in the breakdown.
  final Set<StorageKind> _excluded = {};

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  RoomUsage get _usage =>
      _service.report.byRoom[widget.roomId] ?? RoomUsage(widget.roomId);

  List<StoredItem> get _items => [
        for (final i in _service.report.items)
          if (i.roomId == widget.roomId) i,
      ];

  int get _selected => _usage.byKind.entries
      .where((e) => !_excluded.contains(e.key))
      .fold(0, (a, e) => a + e.value);

  List<StorageKind> get _kinds {
    final usage = _usage;
    return usage.byKind.keys.toList()
      ..sort((a, b) => usage.byKind[b]!.compareTo(usage.byKind[a]!));
  }

  /// Swaps the sheet for the page: the sheet closes and the page rises in
  /// its place, from the navigator underneath.
  void _expand() {
    HapticFeedback.lightImpact();
    final nav = Navigator.of(context);
    final below = nav.context;
    nav.pop();
    openChatStoragePage(below,
        roomId: widget.roomId, repo: widget.repo, api: widget.api);
  }

  Future<void> _run(Future<int> Function() job) async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final freed = await job();
      toast.show(l10n.storageFreed(bytesLabel(freed)),
          tone: ToastTone.success, icon: CupertinoIcons.checkmark_alt);
      if (!mounted) return;
      clearPicks();
      if (_usage.total == 0) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearKinds() async {
    final kinds = {
      for (final k in _usage.byKind.keys)
        if (!_excluded.contains(k)) k,
    };
    if (kinds.isEmpty) return;
    await _run(() => _service.clear(kinds, roomId: widget.roomId));
  }

  Future<void> _clearPicked() async {
    final items = _items.where((i) => picked.contains(i.id)).toList();
    if (items.isEmpty) return;
    await _run(() => _service.deleteItems(items));
  }

  // ─────────────────────────────── pieces ───────────────────────────────

  String _title(AppLocalizations l10n) {
    final room = widget.repo.roomById(widget.roomId);
    return room == null
        ? removedChatTitle(
            l10n, _service.report, widget.roomId, widget.repo.userId)
        : roomTitle(l10n, widget.repo, room);
  }

  Widget _hero(AppLocalizations l10n) {
    final theme = ThemeScope.of(context);
    final usage = _usage;
    final room = widget.repo.roomById(widget.roomId);
    final me = widget.repo.userId;
    final otherId =
        room == null || me == null ? null : room.otherParticipantId(me);
    final cacheTotal = _service.report.total;
    return UsageHero(
      segments: [
        for (final k in _kinds)
          DonutSegment(
            id: k,
            value: _excluded.contains(k) ? 0 : usage.byKind[k]!.toDouble(),
            color: storageColor(theme, k),
          ),
      ],
      centerLabel: '',
      centerBytes: _selected,
      leading: room == null
          ? null
          : ChatRoomAvatar(
              room: room,
              size: 112,
              dmUser: otherId == null ? null : widget.repo.userById(otherId),
              api: widget.api,
            ),
      // The page's large title already names the chat.
      title: widget.full ? null : _title(l10n),
      subtitle: cacheTotal <= 0
          ? null
          : l10n.storageChatShare(percentLabel(usage.total, cacheTotal)),
    );
  }

  List<Widget> _categoryRows(AppLocalizations l10n) {
    final theme = ThemeScope.of(context);
    final usage = _usage;
    final selected = _selected;
    return [
      for (final k in _kinds)
        UsageCategoryRow(
          title: storageLabel(l10n, k),
          bytes: usage.byKind[k]!,
          percent: _excluded.contains(k)
              ? null
              : percentLabel(usage.byKind[k]!, selected),
          color: storageColor(theme, k),
          checked: !_excluded.contains(k),
          onToggle: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (!_excluded.remove(k)) _excluded.add(k);
            });
          },
        ),
    ];
  }

  String _clearLabel(AppLocalizations l10n) => _excluded.isEmpty
      ? l10n.storageClearChatButton(bytesLabel(_selected))
      : l10n.storageClearSelectedButton(bytesLabel(_selected));

  @override
  Widget build(BuildContext context) =>
      widget.full ? _page(context) : _sheet(context);

  Widget _sheet(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final tiles =
        MediaTileData.group([for (final i in _items) if (i.isVisual) i]);
    return SheetFrame(
      maxHeightFraction: 0.92,
      expand: _expand,
      footer: SheetActionButton(
        label: _clearLabel(l10n),
        busy: _busy,
        onTap: _selected <= 0 ? null : _clearKinds,
      ),
      child: SheetScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(l10n),
            SheetGroup(children: _categoryRows(l10n)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Text(l10n.storageClearFooter,
                  style: groupedFooterStyle(theme)),
            ),
            if (tiles.isNotEmpty) ...[
              GroupedHeader(l10n.storageTabMedia),
              ClipRRect(
                borderRadius: BorderRadius.circular(groupedRadius(theme)),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  // A look, not the whole archive: the expanded page has it.
                  itemCount: tiles.length.clamp(0, 24),
                  itemBuilder: (context, i) =>
                      StorageMediaTile(tile: tiles[i], api: widget.api),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _page(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final tiles =
        MediaTileData.group([for (final i in items) if (i.isVisual) i]);
    final files = [
      for (final i in items)
        if (i.kind == StorageKind.files || i.kind == StorageKind.voice) i,
    ]..sort((a, b) => b.bytes.compareTo(a.bytes));
    final picking = selecting;
    final pickedBytes = items
        .where((i) => picked.contains(i.id))
        .fold<int>(0, (a, i) => a + i.bytes);

    Widget boxed(Widget child) => SliverToBoxAdapter(
          child: AdaptivePageBody(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
        );

    return Stack(
      children: [
        dragRegion(
          tiles: tiles,
          scroll: _scroll,
          child: IosPage(
            title: _title(l10n),
            controller: _scroll,
            // A page that rose from the bottom closes; it does not go back.
            leading: const GlassCloseButton(),
            slivers: [
              boxed(Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hero(l10n),
                  GroupedSection(
                    footer: l10n.storageClearFooter,
                    children: [
                      ..._categoryRows(l10n),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: SheetActionButton(
                          label: _clearLabel(l10n),
                          busy: _busy,
                          onTap: _selected <= 0 ? null : _clearKinds,
                        ),
                      ),
                    ],
                  ),
                  if (tiles.isNotEmpty) GroupedHeader(l10n.storageTabMedia),
                ],
              )),
              if (tiles.isNotEmpty) mediaGridSliver(tiles),
              if (files.isNotEmpty)
                boxed(Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: GroupedSection(
                    header: l10n.storageTabFiles,
                    children: [
                      for (final f in files) fileRow(f),
                    ],
                  ),
                )),
              SliverToBoxAdapter(
                child: SizedBox(
                    height: edgeToEdgeBottom(context, picking ? 96 : 40)),
              ),
            ],
          ),
        ),
        ClearSelectionBar(
          visible: picking,
          label: l10n.storageClearSelectedButton(bytesLabel(pickedBytes)),
          busy: _busy,
          onTap: _clearPicked,
        ),
      ],
    );
  }
}
