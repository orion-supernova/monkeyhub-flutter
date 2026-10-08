import 'dart:async';

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
import '../fullscreen_image_viewer.dart';
import '../fullscreen_video_viewer.dart';
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
/// The circle on a tile picks it; a tap on a photo or video opens it, a tap
/// on anything else picks it too. Picks gather in the floating clear bar.
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

class _StorageCategoryScreenState extends State<StorageCategoryScreen> {
  final _service = StorageService.instance;
  final Set<String> _picked = {};
  bool _clearing = false;

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

  void _toggle(Iterable<StoredItem> parts) {
    HapticFeedback.selectionClick();
    setState(() {
      final ids = parts.map((p) => p.id).toList();
      if (ids.every(_picked.contains)) {
        _picked.removeAll(ids);
      } else {
        _picked.addAll(ids);
      }
    });
  }

  void _toggleAll() {
    HapticFeedback.selectionClick();
    final all = _items.map((i) => i.id).toSet();
    setState(() {
      if (_picked.containsAll(all)) {
        _picked.clear();
      } else {
        _picked.addAll(all);
      }
    });
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    final items = _items.where((i) => _picked.contains(i.id)).toList();
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
      if (mounted) setState(_picked.clear);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  Future<void> _openTile(MediaTileData tile) async {
    // Anything with a storage id opens, whichever chat it came from or
    // whether it knows one at all: a video plays from the copy on disk. A
    // GIF or a link preview has no id to open by, so a tap picks it.
    final video = tile.video;
    final photo = tile.photoId;
    if (_picked.isNotEmpty || (video == null && photo == null)) {
      _toggle(tile.parts);
      return;
    }
    if (video != null) {
      await FullscreenVideoViewer.open(context,
          storageId: video.id, api: widget.api, posterStorageId: photo);
    } else {
      await FullscreenImageViewer.open(context,
          storageId: photo!, api: widget.api);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final total = items.fold<int>(0, (a, i) => a + i.bytes);
    final picking = _picked.isNotEmpty;
    final pickedBytes = items
        .where((i) => _picked.contains(i.id))
        .fold<int>(0, (a, i) => a + i.bytes);
    final allPicked = items.isNotEmpty &&
        items.every((i) => _picked.contains(i.id));

    return Stack(
      children: [
        IosPage(
          title: storageLabel(l10n, widget.kind),
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
            else
              ..._body(l10n, items),
            SliverToBoxAdapter(
              child: SizedBox(height: edgeToEdgeBottom(context, picking ? 96 : 40)),
            ),
          ],
        ),
        ClearSelectionBar(
          visible: picking,
          label: l10n.storageClearSelectedButton(bytesLabel(pickedBytes)),
          busy: _clearing,
          onTap: _clear,
        ),
      ],
    );
  }

  List<Widget> _body(AppLocalizations l10n, List<StoredItem> items) {
    Widget boxed(Widget child) => SliverToBoxAdapter(
          child: AdaptivePageBody(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
        );

    if (_visual) {
      final tiles = MediaTileData.group(items);
      return [
        SliverLayoutBuilder(
          builder: (context, c) {
            final side = context.isCompact
                ? 0.0
                : ((c.crossAxisExtent - ContentWidth.readable) / 2)
                    .clamp(0.0, double.infinity);
            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                ),
                itemCount: tiles.length,
                itemBuilder: (context, i) {
                  final t = tiles[i];
                  return StorageMediaTile(
                    tile: t,
                    api: widget.api,
                    selected: t.parts.every((p) => _picked.contains(p.id)),
                    onTap: () => _openTile(t),
                    onToggle: () => _toggle(t.parts),
                  );
                },
              ),
            );
          },
        ),
      ];
    }

    if (widget.kind == StorageKind.chatHistory) {
      final byRoom = <String, List<StoredItem>>{};
      for (final i in items) {
        byRoom.putIfAbsent(i.roomId ?? '', () => []).add(i);
      }
      final rooms = byRoom.entries.toList()
        ..sort((a, b) => b.value
            .fold<int>(0, (s, i) => s + i.bytes)
            .compareTo(a.value.fold<int>(0, (s, i) => s + i.bytes)));
      return [
        boxed(GroupedSection(
          footer: l10n.storageChatHistoryFooter,
          children: [
            for (final e in rooms)
              StorageChatRow(
                usage: RoomUsage(e.key)
                  ..byKind[StorageKind.chatHistory] =
                      e.value.fold<int>(0, (s, i) => s + i.bytes),
                repo: widget.repo,
                api: widget.api,
                selected: e.value.every((i) => _picked.contains(i.id)),
                onTap: () => _toggle(e.value),
              ),
          ],
        )),
      ];
    }

    return [
      boxed(GroupedSection(
        children: [
          for (final f in items)
            StorageFileRow(
              item: f,
              selected: _picked.contains(f.id),
              onToggle: () => _toggle([f]),
            ),
        ],
      )),
    ];
  }
}
