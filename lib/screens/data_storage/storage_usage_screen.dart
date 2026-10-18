import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../companions/companion.dart';
import '../../data/chat_repository.dart';
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/storage/media_ledger.dart';
import '../../media/storage/storage_kinds.dart';
import '../../media/storage/storage_service.dart';
import '../../theme/layout.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/donut_chart.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/pull_down_menu.dart';
import '../../widgets/sheet_kit.dart';
import '../../widgets/stepped_slider.dart';
import '../companions/companion_screens.dart';
import 'chat_storage_sheet.dart';
import 'storage_category_screen.dart';
import 'storage_labels.dart';
import 'usage_widgets.dart';

enum _Tab { chats, media, files }

/// Storage Usage: what the app keeps on this device, and the controls for it.
///
/// Telegram's screen, top to bottom: the ring and the total; the breakdown by
/// kind, every row a check that decides what the big button clears; how long
/// untouched media is kept, per kind of chat; the ceiling on the whole cache;
/// then everything again by chat, as a media grid and as a file list, each
/// selectable for a precise clear.
///
/// Two things it adds. A cleanup suggestion, when there is a meaningful amount
/// of media nobody has looked at in a month: one tap, and only the stale part
/// goes. And Saved Messages is exempt from auto-remove, said in the footer,
/// because that is where people keep things on purpose.
class StorageUsageScreen extends StatefulWidget {
  const StorageUsageScreen({super.key, required this.repo, required this.api});

  final ChatRepository repo;
  final ChatApi api;

  @override
  State<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends State<StorageUsageScreen>
    with StorageSelection {
  final _service = StorageService.instance;
  final _scroll = ScrollController();

  @override
  ChatApi get selectionApi => widget.api;

  @override
  ChatRepository get selectionRepo => widget.repo;

  /// Kinds the user unticked: kept out of the clear, out of the ring.
  final Set<StorageKind> _excluded = {};

  _Tab _tab = _Tab.chats;
  StorageKind? _focused;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
    unawaited(_service.scan());
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

  StorageReport get _r => _service.report;

  /// What the clear button would delete: every clearable kind not unticked.
  /// Companions are never in it.
  Set<StorageKind> get _included => {
        for (final k in _r.byKind.keys)
          if (k.isClearable && !_excluded.contains(k)) k,
      };

  int get _selectedBytes =>
      _included.fold(0, (a, k) => a + (_r.byKind[k] ?? 0));

  /// Everything the ring draws: what would be cleared, plus what never is
  /// (companions). The centre and every percentage share this one base, so
  /// the numbers always describe the picture.
  int get _ringBytes =>
      _selectedBytes +
      _r.byKind.entries
          .where((e) => !e.key.isClearable)
          .fold(0, (a, e) => a + e.value);

  // ─────────────────────────────── actions ───────────────────────────────

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showIosActionSheet<bool>(
      context,
      title: title,
      message: body,
      actions: [IosSheetAction(label: action, value: true, destructive: true)],
    );
    return ok ?? false;
  }

  Future<void> _clearCategories() async {
    final l10n = AppLocalizations.of(context);
    final kinds = _included;
    final bytes = _selectedBytes;
    if (kinds.isEmpty || bytes <= 0) return;
    final all = _excluded.isEmpty;
    final ok = await _confirm(
      all ? l10n.storageClearAllTitle : l10n.storageClearSelectedTitle,
      l10n.storageClearBody,
      l10n.storageClearConfirm(bytesLabel(bytes)),
    );
    if (!ok || !mounted) return;
    await _run(() => _service.clear(kinds));
  }

  Future<void> _clearPicked() async {
    final l10n = AppLocalizations.of(context);
    final items = _r.items.where((i) => picked.contains(i.id)).toList();
    final bytes = items.fold<int>(0, (a, i) => a + i.bytes);
    if (items.isEmpty) return;
    final ok = await _confirm(
      l10n.storageClearSelectedTitle,
      l10n.storageClearBody,
      l10n.storageClearConfirm(bytesLabel(bytes)),
    );
    if (!ok || !mounted) return;
    await _run(() => _service.deleteItems(items));
    if (mounted) clearPicks();
  }

  Future<void> _cleanStale(List<StoredItem> stale) async {
    await _run(() => _service.deleteItems(stale));
  }

  Future<void> _run(Future<int> Function() job) async {
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _clearing = true);
    HapticFeedback.mediumImpact();
    try {
      final freed = await job();
      toast.show(l10n.storageFreed(bytesLabel(freed)),
          tone: ToastTone.success, icon: CupertinoIcons.checkmark_alt);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  /// Companion brains are managed on their own pages, not cleared here.
  Future<void> _openCompanions(GlobalKey anchor) async {
    final picked = await showPullDownMenu<Companion>(
      context: context,
      anchorKey: anchor,
      items: [
        // Only the ones whose bytes this row counts. Bartleby's are in
        // the voice transcripts row.
        for (final c in Companion.values)
          if (c.usesBrains)
            PullDownItem(
              value: c,
              label: c.displayName,
              icon: CupertinoIcons.chevron_forward,
            ),
      ],
    );
    if (picked == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => companionScreen(picked),
    ));
    // A brain removed there shrinks the total here.
    if (mounted) unawaited(_service.scan());
  }

  final _companionsAnchor = GlobalKey();

  Future<void> _openChat(RoomUsage usage) async {
    await showChatStorageSheet(
      context,
      usage: usage,
      repo: widget.repo,
      api: widget.api,
    );
  }

  // ─────────────────────────────── build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = _r;
    final picking = selecting;
    final pickedBytes = r.items
        .where((i) => picked.contains(i.id))
        .fold<int>(0, (a, i) => a + i.bytes);
    final tiles = _tab == _Tab.media
        ? MediaTileData.group(r.media)
        : const <MediaTileData>[];

    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) => Stack(
        children: [
          // Always wrapped, even on the tabs with no grid. Wrapping only on
          // Media changed the widget above the page, which remounted its
          // scroll view, and a fresh one starts at the top: every tap on a
          // segment threw the reader back to the ring.
          dragRegion(tiles: tiles, scroll: _scroll, child: IosPage(
            title: l10n.storageUsageTitle,
            controller: _scroll,
            slivers: [
              SliverToBoxAdapter(
                child: AdaptivePageBody(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hero(l10n, r),
                        ..._cleanup(l10n, r),
                        _categories(l10n, r),
                        _autoRemove(l10n),
                        _limit(l10n),
                      ],
                    ),
                  ),
                ),
              ),
              if (r.byRoom.isNotEmpty || r.items.isNotEmpty) ...[
                _TabsTop(_tabsTop),
                SliverToBoxAdapter(
                  child: AdaptivePageBody(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: IosSegmentedControl<_Tab>(
                        segments: [
                          IosSegment(value: _Tab.chats, label: l10n.storageTabChats),
                          IosSegment(value: _Tab.media, label: l10n.storageTabMedia),
                          IosSegment(value: _Tab.files, label: l10n.storageTabFiles),
                        ],
                        value: _tab,
                        onChanged: (t) => setState(() => _tab = t),
                      ),
                    ),
                  ),
                ),
                ..._tabBody(l10n, r, tiles),
              ],
              SliverToBoxAdapter(
                child: SizedBox(
                    height: edgeToEdgeBottom(context, picking ? 96 : 40)),
              ),
              // Last, so the bottom margin counts towards the screenful.
              if (r.byRoom.isNotEmpty || r.items.isNotEmpty)
                _TabsFloor(_tabsTop),
            ],
          )),
          // The clear bar for a picked set, floating over the grid the way
          // Telegram's does, so the selection stays in view while it grows.
          ClearSelectionBar(
            visible: picking,
            label: l10n.storageClearSelectedButton(bytesLabel(pickedBytes)),
            busy: _clearing,
            onTap: _clearPicked,
          ),
        ],
      ),
    );
  }

  /// Where the tabs start, written during layout and read a few slivers
  /// later by the floor under them. See [_TabsFloor].
  final _tabsTop = _TabsAnchor();

  Widget _hero(AppLocalizations l10n, StorageReport r) {
    final theme = ThemeScope.of(context);
    final total = r.total;
    final disk = r.disk;
    final focused = _focused;
    final segs = [
      for (final k in StorageKind.values)
        if ((r.byKind[k] ?? 0) > 0)
          DonutSegment(
            id: k,
            value: k.isClearable && _excluded.contains(k)
                ? 0
                : (r.byKind[k] ?? 0).toDouble(),
            color: storageColor(theme, k),
          ),
    ];
    final String? subtitle;
    if (_service.calculating) {
      subtitle = l10n.storageCalculating;
    } else if (disk != null && total > 0) {
      subtitle = l10n.storageShareOfFree(percentLabel(total, disk.free + total));
    } else {
      subtitle = total == 0 ? l10n.storageEmpty : null;
    }
    return UsageHero(
      segments: segs,
      calculating: _service.calculating,
      centerLabel: '',
      centerBytes: focused == null ? _ringBytes : (r.byKind[focused] ?? 0),
      centerCaption: focused == null ? null : storageLabel(l10n, focused),
      highlighted: focused,
      onSegmentTap: (id) =>
          setState(() => _focused = id == _focused ? null : id as StorageKind?),
      subtitle: subtitle,
      meter: disk == null || total == 0 ? null : total / (disk.free + total),
    );
  }

  /// "Free up 120 MB": media nobody has opened in a month, when there is
  /// enough of it to be worth a sentence.
  List<Widget> _cleanup(AppLocalizations l10n, StorageReport r) {
    final cutoff =
        DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final stale = [
      for (final i in r.items)
        if (i.roomId != null &&
            i.lastSeen < cutoff &&
            !(MediaLedger.instance.isKeptRoom?.call(i.roomId!) ?? false))
          i,
    ];
    final bytes = stale.fold<int>(0, (a, i) => a + i.bytes);
    if (bytes < 10 * 1024 * 1024) return const [];
    return [
      GroupedSection(
        footer: l10n.storageCleanupFooter,
        children: [
          GroupedRow(
            icon: CupertinoIcons.sparkles,
            tone: TileTone.purple,
            title: l10n.storageCleanupTitle(bytesLabel(bytes)),
            subtitle: l10n.storageCleanupSubtitle,
            onTap: _clearing ? null : () => _cleanStale(stale),
            trailing: Text(l10n.storageCleanupAction,
                style: groupedValueStyle(ThemeScope.of(context))
                    .copyWith(color: ThemeScope.of(context).accent)),
          ),
        ],
      ),
    ];
  }

  Widget _categories(AppLocalizations l10n, StorageReport r) {
    final theme = ThemeScope.of(context);
    final kinds = [
      for (final k in StorageKind.values)
        if ((r.byKind[k] ?? 0) > 0) k,
    ]..sort((a, b) => (r.byKind[b] ?? 0).compareTo(r.byKind[a] ?? 0));
    final selected = _selectedBytes;
    final ring = _ringBytes;
    if (kinds.isEmpty) return const SizedBox.shrink();
    return GroupedSection(
      footer: [
        l10n.storageCategoryHint,
        l10n.storageClearFooter,
        if (r.byKind.containsKey(StorageKind.companions))
          l10n.storageCompanionsNote,
      ].join(' '),
      children: [
        for (final k in kinds)
          if (!k.isClearable)
            UsageCategoryRow(
              key: _companionsAnchor,
              title: storageLabel(l10n, k),
              bytes: r.byKind[k] ?? 0,
              color: storageColor(theme, k),
              percent: percentLabel(r.byKind[k] ?? 0, ring),
              icon: CupertinoIcons.sparkles,
              tone: storageTone(k),
              navigates: true,
              onToggle: () => _openCompanions(_companionsAnchor),
            )
          else
          UsageCategoryRow(
            title: storageLabel(l10n, k),
            bytes: r.byKind[k] ?? 0,
            percent: _excluded.contains(k)
                ? null
                : percentLabel(r.byKind[k] ?? 0, ring),
            color: storageColor(theme, k),
            checked: !_excluded.contains(k),
            onOpen: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => StorageCategoryScreen(
                  kind: k, repo: widget.repo, api: widget.api),
            )),
            onToggle: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (!_excluded.remove(k)) _excluded.add(k);
                if (_focused == k) _focused = null;
              });
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SheetActionButton(
            label: _excluded.isEmpty
                ? l10n.storageClearAllButton(bytesLabel(selected))
                : l10n.storageClearSelectedButton(bytesLabel(selected)),
            busy: _clearing,
            onTap: selected <= 0 ? null : _clearCategories,
          ),
        ),
      ],
    );
  }

  Widget _autoRemove(AppLocalizations l10n) {
    final prefs = SettingsStore.instance.dataPrefs;
    return GroupedSection(
      header: l10n.storageAutoRemoveHeader,
      footer: l10n.storageAutoRemoveFooter,
      children: [
        for (final c in ChatClass.values)
          PullDownRow<KeepMedia>(
            icon: chatClassIcon(c),
            tone: chatClassTone(c),
            title: chatClassLabel(l10n, c),
            value: prefs.keepIn(c),
            options: KeepMedia.values,
            labelOf: (k) => keepLabel(l10n, k),
            onChanged: (k) async {
              final p = SettingsStore.instance.dataPrefs;
              await SettingsStore.instance.setDataPrefs(
                  p.copyWith(keepMedia: {...p.keepMedia, c: k}));
              unawaited(_service.enforcePolicy(force: true));
            },
          ),
      ],
    );
  }

  Widget _limit(AppLocalizations l10n) {
    final prefs = SettingsStore.instance.dataPrefs;
    return GroupedSection(
      header: l10n.storageLimitHeader,
      footer: l10n.storageLimitFooter,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: SteppedSlider(
            labels: [for (final c in CacheLimit.values) limitLabel(l10n, c)],
            index: prefs.cacheLimit.index,
            onChanged: (i) async {
              await SettingsStore.instance.setDataPrefs(SettingsStore
                  .instance.dataPrefs
                  .copyWith(cacheLimit: CacheLimit.values[i]));
              unawaited(_service.enforcePolicy(force: true));
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _tabBody(
      AppLocalizations l10n, StorageReport r, List<MediaTileData> tiles) {
    Widget boxed(Widget child) => SliverToBoxAdapter(
          child: AdaptivePageBody(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
        );
    Widget empty(String text) => boxed(Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Text(text,
              textAlign: TextAlign.center,
              style: groupedFooterStyle(ThemeScope.of(context))),
        ));

    switch (_tab) {
      case _Tab.chats:
        final rooms = r.rooms;
        if (rooms.isEmpty) return [empty(l10n.storageNoChats)];
        return [
          boxed(GroupedSection(
            margin: EdgeInsets.zero,
            children: [
              for (final u in rooms)
                StorageChatRow(
                  usage: u,
                  repo: widget.repo,
                  api: widget.api,
                  onTap: () => _openChat(u),
                ),
            ],
          )),
        ];
      case _Tab.media:
        if (tiles.isEmpty) return [empty(l10n.storageNoMedia)];
        // A real sliver grid, so a cache of thousands of tiles builds only
        // the rows on screen.
        return [mediaGridSliver(tiles)];
      case _Tab.files:
        final files = r.files;
        if (files.isEmpty) return [empty(l10n.storageNoFiles)];
        return [
          boxed(GroupedSection(
            margin: EdgeInsets.zero,
            children: [
              for (final f in files) fileRow(f),
            ],
          )),
        ];
    }
  }
}

/// The scroll offset at which the tabs start, measured during layout.
class _TabsAnchor {
  double offset = 0;
}

/// Records where the tabs start. Takes no space.
class _TabsTop extends LeafRenderObjectWidget {
  const _TabsTop(this.anchor);
  final _TabsAnchor anchor;

  @override
  RenderSliver createRenderObject(BuildContext context) =>
      _RenderTabsTop(anchor);

  @override
  void updateRenderObject(BuildContext context, _RenderTabsTop r) =>
      r.anchor = anchor;
}

class _RenderTabsTop extends RenderSliver {
  _RenderTabsTop(this.anchor);
  _TabsAnchor anchor;

  @override
  void performLayout() {
    anchor.offset = constraints.precedingScrollExtent;
    geometry = SliverGeometry.zero;
  }
}

/// Pads the bottom of the page so the tabs and whatever is under them are at
/// least a screen tall.
///
/// Without it, switching from a long tab to a short one shrank the page under
/// the reader: the scroll position no longer fitted, the view clamped, and the
/// segmented control they had just tapped flew down the screen. With it, the
/// tabs can always sit at the top, so a switch changes what is below the
/// control and never where the control is.
///
/// A render sliver rather than a layout builder because it is measured on
/// every layout of the page, scrolling included, and a builder would rebuild
/// on every frame of a scroll.
class _TabsFloor extends LeafRenderObjectWidget {
  const _TabsFloor(this.anchor);
  final _TabsAnchor anchor;

  @override
  RenderSliver createRenderObject(BuildContext context) =>
      _RenderTabsFloor(anchor);

  @override
  void updateRenderObject(BuildContext context, _RenderTabsFloor r) =>
      r.anchor = anchor;
}

class _RenderTabsFloor extends RenderSliver {
  _RenderTabsFloor(this.anchor);
  _TabsAnchor anchor;

  @override
  void performLayout() {
    final c = constraints;
    final used = c.precedingScrollExtent - anchor.offset;
    final extent = (c.viewportMainAxisExtent - used).clamp(0.0, double.infinity);
    final paint = calculatePaintOffset(c, from: 0, to: extent);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintExtent: paint,
      maxPaintExtent: extent,
    );
  }
}
