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
import '../../widgets/app_toast.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/sheet_kit.dart';
import 'storage_labels.dart';
import 'usage_widgets.dart';

/// One storage category, opened from its row in Storage Usage: every cached
/// file of that kind, actually on this device, to look at and clear one by
/// one. Telegram stops at the totals; this is the part where you see what
/// the 30 MB of "Other" really is.
///
/// Pictures and videos are a grid drawn straight from the files on disk, so
/// the page never spends data showing you what you already have. Files and
/// voice messages are a list with names and dates. Chat history is a list of
/// chats, each with the size of its offline copy.
///
/// Selection follows the room gallery's rules ([StorageSelection]): a tap
/// opens, a long press starts selecting, a drag picks a range.
class StorageCategoryScreen extends StatefulWidget {
  const StorageCategoryScreen({
    super.key,
    required this.kind,
    required this.repo,
    required this.api,
  });

  final StorageKind kind;
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<StorageCategoryScreen> createState() => _StorageCategoryScreenState();
}

class _StorageCategoryScreenState extends State<StorageCategoryScreen>
    with StorageSelection {
  final _service = StorageService.instance;
  final _scroll = ScrollController();
  bool _clearing = false;

  @override
  ChatApi get selectionApi => widget.api;

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

  List<StoredItem> get _items => _service.report.itemsOf(widget.kind);

  bool get _visual => switch (widget.kind) {
        StorageKind.photos ||
        StorageKind.videos ||
        StorageKind.videoMessages ||
        StorageKind.stickers ||
        StorageKind.other =>
          true,
        _ => false,
      };

  void _toggleAll() {
    HapticFeedback.selectionClick();
    final all = _items.map((i) => i.id).toSet();
    setState(() {
      if (picked.containsAll(all)) {
        picked.clear();
      } else {
        picked.addAll(all);
      }
    });
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    final items = _items.where((i) => picked.contains(i.id)).toList();
    if (items.isEmpty) return;
    final bytes = items.fold<int>(0, (a, i) => a + i.bytes);
    final ok = await showIosActionSheet<bool>(
      context,
      title: l10n.storageClearSelectedTitle,
      message: widget.kind == StorageKind.chatHistory
          ? l10n.storageChatHistoryFooter
          : l10n.storageClearBody,
      actions: [
        IosSheetAction(
          label: l10n.storageClearConfirm(bytesLabel(bytes)),
          value: true,
          destructive: true,
        ),
      ],
    );
    if (ok != true || !mounted) return;
    setState(() => _clearing = true);
    HapticFeedback.mediumImpact();
    try {
      final freed = await _service.deleteItems(items);
      toast.show(l10n.storageFreed(bytesLabel(freed)),
          tone: ToastTone.success, icon: CupertinoIcons.checkmark_alt);
      if (mounted) clearPicks();
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final total = items.fold<int>(0, (a, i) => a + i.bytes);
    final pickedBytes = items
        .where((i) => picked.contains(i.id))
        .fold<int>(0, (a, i) => a + i.bytes);
    final allPicked =
        items.isNotEmpty && items.every((i) => picked.contains(i.id));
    final tiles = _visual ? MediaTileData.group(items) : <MediaTileData>[];

    final page = IosPage(
      title: storageLabel(l10n, widget.kind),
      controller: _scroll,
      subtitle: items.isEmpty
          ? null
          : l10n.storageCategoryCount(items.length, bytesLabel(total)),
      actions: [
        if (items.isNotEmpty)
          GlassPillButton(
            label: allPicked ? l10n.storageDeselectAll : l10n.storageSelectAll,
            onTap: _toggleAll,
          ),
      ],
      slivers: [
        if (items.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
              child: Text(
                l10n.storageCategoryEmpty,
                textAlign: TextAlign.center,
                style: groupedFooterStyle(ThemeScope.of(context)),
              ),
            ),
          )
        else if (_visual)
          mediaGridSliver(tiles)
        else
          ..._lists(l10n, items),
        SliverToBoxAdapter(
          child:
              SizedBox(height: edgeToEdgeBottom(context, selecting ? 96 : 40)),
        ),
      ],
    );

    return Stack(
      children: [
        _visual
            ? dragRegion(tiles: tiles, scroll: _scroll, child: page)
            : page,
        ClearSelectionBar(
          visible: selecting,
          label: l10n.storageClearSelectedButton(bytesLabel(pickedBytes)),
          busy: _clearing,
          onTap: _clear,
        ),
      ],
    );
  }

  List<Widget> _lists(AppLocalizations l10n, List<StoredItem> items) {
    Widget boxed(Widget child) => SliverToBoxAdapter(
          child: AdaptivePageBody(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
        );

    if (widget.kind == StorageKind.chatHistory) {
      final byRoom = <String, List<StoredItem>>{};
      for (final i in items) {
        byRoom.putIfAbsent(i.roomId ?? '', () => []).add(i);
      }
      int size(List<StoredItem> l) => l.fold<int>(0, (s, i) => s + i.bytes);
      final rooms = byRoom.entries.toList()
        ..sort((a, b) => size(b.value).compareTo(size(a.value)));
      return [
        boxed(GroupedSection(
          footer: l10n.storageChatHistoryFooter,
          children: [
            for (final e in rooms)
              StorageChatRow(
                usage: RoomUsage(e.key)
                  ..byKind[StorageKind.chatHistory] = size(e.value),
                repo: widget.repo,
                api: widget.api,
                // A chat's history has nothing to open on its own, so a tap
                // picks it: the one thing to do with it here is clear it.
                selected: selecting
                    ? e.value.every((i) => picked.contains(i.id))
                    : null,
                onTap: () => togglePick(e.value),
              ),
          ],
        )),
      ];
    }

    return [
      boxed(GroupedSection(children: [for (final f in items) fileRow(f)])),
    ];
  }
}
