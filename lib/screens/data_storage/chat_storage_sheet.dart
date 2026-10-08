import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../data/chat_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/storage/storage_kinds.dart';
import '../../media/storage/storage_service.dart';
import '../../theme/theme_scope.dart';
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
/// a clear button for exactly that chat, and under it everything that chat
/// keeps on the device, every photo, video and file selectable.
///
/// A sheet that opens as a glance and drags up to full height to go through
/// the rest ([ExpandingSheet]). It used to have an expand button that closed
/// the sheet and opened a page in its place, which was two screens for one
/// thing with a cut between them.
Future<void> showChatStorageSheet(
  BuildContext context, {
  required RoomUsage usage,
  required ChatRepository repo,
  required ChatApi api,
}) {
  HapticFeedback.lightImpact();
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => _ChatStorage(roomId: usage.roomId, repo: repo, api: api),
  );
}

class _ChatStorage extends StatefulWidget {
  const _ChatStorage({
    required this.roomId,
    required this.repo,
    required this.api,
  });

  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<_ChatStorage> createState() => _ChatStorageState();
}

class _ChatStorageState extends State<_ChatStorage> with StorageSelection {
  final _service = StorageService.instance;

  @override
  ChatApi get selectionApi => widget.api;

  @override
  ChatRepository get selectionRepo => widget.repo;

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
      title: _title(l10n),
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
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final tiles =
        MediaTileData.group([for (final i in items) if (i.isVisual) i]);
    final files = [
      for (final i in items)
        if (i.kind == StorageKind.files || i.kind == StorageKind.voice) i,
    ]..sort((a, b) => b.bytes.compareTo(a.bytes));
    final pickedBytes = items
        .where((i) => picked.contains(i.id))
        .fold<int>(0, (a, i) => a + i.bytes);

    Widget boxed(Widget child) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        );

    return ExpandingSheet(
      wrap: (scroll, body) =>
          dragRegion(tiles: tiles, scroll: scroll, child: body),
      // While picking, the one button clears exactly the picks; otherwise
      // the ticked kinds.
      footer: selecting
          ? SheetActionButton(
              label: l10n.storageClearSelectedButton(bytesLabel(pickedBytes)),
              busy: _busy,
              onTap: _clearPicked,
            )
          : SheetActionButton(
              label: _clearLabel(l10n),
              busy: _busy,
              onTap: _selected <= 0 ? null : _clearKinds,
            ),
      slivers: (context, _) => [
        boxed(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(l10n),
            SheetGroup(children: _categoryRows(l10n)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Text(l10n.storageClearFooter,
                  style: groupedFooterStyle(theme)),
            ),
            if (tiles.isNotEmpty) GroupedHeader(l10n.storageTabMedia),
          ],
        )),
        if (tiles.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: mediaGridSliver(tiles),
          ),
        if (files.isNotEmpty)
          boxed(Padding(
            padding: const EdgeInsets.only(top: 28),
            child: GroupedSection(
              header: l10n.storageTabFiles,
              children: [for (final f in files) fileRow(f)],
            ),
          )),
      ],
    );
  }
}
