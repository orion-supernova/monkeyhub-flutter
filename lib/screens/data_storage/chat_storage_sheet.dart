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
/// a clear button for exactly that chat, and a look at the media it holds.
Future<void> showChatStorageSheet(
  BuildContext context, {
  required RoomUsage usage,
  required ChatRepository repo,
  required ChatApi api,
}) {
  HapticFeedback.lightImpact();
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => _ChatStorageSheet(roomId: usage.roomId, repo: repo, api: api),
  );
}

class _ChatStorageSheet extends StatefulWidget {
  const _ChatStorageSheet({
    required this.roomId,
    required this.repo,
    required this.api,
  });

  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<_ChatStorageSheet> createState() => _ChatStorageSheetState();
}

class _ChatStorageSheetState extends State<_ChatStorageSheet> {
  final _service = StorageService.instance;
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

  int get _selected => _usage.byKind.entries
      .where((e) => !_excluded.contains(e.key))
      .fold(0, (a, e) => a + e.value);

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    final kinds = {
      for (final k in _usage.byKind.keys)
        if (!_excluded.contains(k)) k,
    };
    if (kinds.isEmpty) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      final freed = await _service.clear(kinds, roomId: widget.roomId);
      toast.show(l10n.storageFreed(bytesLabel(freed)),
          tone: ToastTone.success, icon: CupertinoIcons.checkmark_alt);
      if (mounted && _usage.total == 0) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final usage = _usage;
    final room = widget.repo.roomById(widget.roomId);
    final me = widget.repo.userId;
    final otherId =
        room == null || me == null ? null : room.otherParticipantId(me);
    final title =
        room == null ? l10n.storageChatUnknown : roomTitle(l10n, widget.repo, room);
    final cacheTotal = _service.report.total;
    final kinds = usage.byKind.keys.toList()
      ..sort((a, b) => usage.byKind[b]!.compareTo(usage.byKind[a]!));
    final selected = _selected;
    final tiles = MediaTileData.group([
      for (final i in _service.report.media)
        if (i.roomId == widget.roomId) i,
    ]);

    return SheetFrame(
      maxHeightFraction: 0.92,
      footer: SheetActionButton(
        label: _excluded.isEmpty
            ? l10n.storageClearChatButton(bytesLabel(selected))
            : l10n.storageClearSelectedButton(bytesLabel(selected)),
        busy: _busy,
        onTap: selected <= 0 ? null : _clear,
      ),
      child: SheetScrollBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UsageHero(
              segments: [
                for (final k in kinds)
                  DonutSegment(
                    id: k,
                    value: _excluded.contains(k)
                        ? 0
                        : usage.byKind[k]!.toDouble(),
                    color: storageColor(theme, k),
                  ),
              ],
              centerLabel: bytesLabel(selected),
              leading: room == null
                  ? null
                  : ChatRoomAvatar(
                      room: room,
                      size: 112,
                      dmUser:
                          otherId == null ? null : widget.repo.userById(otherId),
                      api: widget.api,
                    ),
              title: title,
              subtitle: cacheTotal <= 0
                  ? null
                  : l10n.storageChatShare(percentLabel(usage.total, cacheTotal)),
            ),
            SheetGroup(
              children: [
                for (final k in kinds)
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
              ],
            ),
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
                  // A look, not the whole archive: the Media tab has the rest.
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
}
