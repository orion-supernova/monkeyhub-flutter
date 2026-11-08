import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../calls/call_models.dart';
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_user.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/glass_buttons.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/sunlit_surface.dart' show SunlitBackdrop;
import '../../widgets/tab_root_bar.dart';
import '../navigation/destinations.dart' show sectionBottomPadding;
import '../navigation/scroll_memory.dart';
import '../navigation/tab_reselect.dart';
import 'call_actions.dart';
import 'call_details_sheet.dart';
import 'call_log_models.dart';
import 'call_log_store.dart';
import 'add_favourite_sheet.dart';
import 'call_row_tile.dart';
import 'calls_directory.dart';
import 'calls_empty.dart';
import 'calls_fav_suggestion.dart';
import 'calls_favourites.dart';
import 'calls_format.dart';
import 'calls_live_strip.dart';
import 'calls_talk_time.dart';
import 'new_call_sheet.dart';
import '../../ui/native/native_cut.dart';

/// The Calls tab: live calls, favourites, this week's talk time, then the
/// history (All / Missed) grouped by day.
///
/// Scaffold, scroll and header follow the other tab roots (Feed, Discover): a
/// [TabRootBar] over a scroll view whose first content is the large title, the
/// scroll offset remembered across tab switches, a re-tap of the tab rewinding
/// it. Data comes from [CallLogStore] (one live subscription per filter) and
/// [LiveCallsStore]; rooms and people are resolved through [CallsDirectory] at
/// build time and never copied.
class CallsScreen extends StatefulWidget {
  const CallsScreen({
    super.key,
    required this.directory,
    this.api,
    this.store,
  });

  final CallsDirectory directory;

  /// For pictures, and for the new-call picker (hidden without it).
  final ChatApi? api;

  /// Defaults to the app-wide [CallLogStore].
  final CallLogStore? store;

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen>
    with TabReselectScroll<CallsScreen> {
  final _scroll = ScrollMemory.controller();

  @override
  HomeSection get reselectSection => HomeSection.calls;
  @override
  ScrollController get reselectScroll => _scroll;

  CallLogStore get _store => widget.store ?? CallLogStore.instance;

  String _filter = CallLogStore.all;

  Timer? _directoryDebounce;
  bool _summariesRequested = false;

  // Grouping is the only real work in a build, so it is redone only when the
  // entries list (identity) or the filter changes.
  List<CallLogEntry>? _groupedFrom;
  List<CallListItem> _grouped = const [];

  @override
  void initState() {
    super.initState();
    ScrollMemory.attach('calls', _scroll);
    _scroll.addListener(_maybeLoadMore);
    _store
      ..ensure(CallLogStore.all)
      ..ensure(CallLogStore.missed)
      ..ensureFavourites()
      ..addListener(_onStore);
    widget.directory.addListener(_onDirectory);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_summariesRequested) return;
    _summariesRequested = true;
    final now = callsClock();
    unawaited(
      _store.loadSummaries(
        weekSince: weekStart(context, now: now).millisecondsSinceEpoch,
        monthSince: now.subtract(const Duration(days: 30)).millisecondsSinceEpoch,
      ),
    );
  }

  @override
  void didUpdateWidget(CallsScreen old) {
    super.didUpdateWidget(old);
    if (old.directory != widget.directory) {
      old.directory.removeListener(_onDirectory);
      widget.directory.addListener(_onDirectory);
    }
  }

  @override
  void dispose() {
    _directoryDebounce?.cancel();
    _store.removeListener(_onStore);
    widget.directory.removeListener(_onDirectory);
    _scroll.dispose();
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    _markSeen();
    setState(() {});
  }

  /// Names and pictures move rarely, but the repository notifies on every
  /// keystroke anywhere; coalesce so the list rebuilds at most a few times a
  /// second.
  void _onDirectory() {
    if (_directoryDebounce?.isActive ?? false) return;
    _directoryDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() {});
    });
  }

  /// Opening the tab clears its badge: everything missed up to now is seen.
  void _markSeen() {
    if (!mounted) return;
    var at = callsClock().millisecondsSinceEpoch;
    for (final e in _store.entries(CallLogStore.missed)) {
      if (e.startedAt > at) at = e.startedAt;
    }
    unawaited(SettingsStore.instance.markCallsSeen(at));
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.maxScrollExtent - p.pixels < 700) {
      unawaited(_store.loadMore(_filter));
    }
  }

  List<CallListItem> _items(List<CallLogEntry> entries) {
    if (!identical(entries, _groupedFrom)) {
      _groupedFrom = entries;
      _grouped = groupCallLog(entries);
    }
    return _grouped;
  }

  // ── actions ──

  void _onRowAction(CallRow row, CallRowAction action) {
    final e = row.first;
    switch (action) {
      case CallRowAction.voice:
        unawaited(callBack(context,
            directory: widget.directory, entry: e, kind: CallMediaKind.audio));
      case CallRowAction.video:
        unawaited(callBack(context,
            directory: widget.directory, entry: e, kind: CallMediaKind.video));
      case CallRowAction.chat:
        widget.directory.openChat(context, e.roomId);
      case CallRowAction.addFavourite:
        final id = e.peerId;
        if (id != null) unawaited(_addFavourite(id));
      case CallRowAction.removeFavourite:
        final id = e.peerId;
        if (id != null) unawaited(_removeFavourite(id));
      case CallRowAction.delete:
        unawaited(_store.remove([for (final x in row.entries) x.id]));
    }
  }

  // ── favourites ──

  /// Whether [e] is a call with one real person who can be pinned, and if so
  /// whether they are. Null: nothing to offer (group call, not a friend).
  bool? _favouriteOf(CallLogEntry e) {
    final id = e.peerId;
    if (e.kind != CallLogKind.direct || id == null) return null;
    final u = widget.directory.user(id);
    if (u == null || u.isSystem) return null;
    return _store.isFavourite(id);
  }

  Future<void> _addFavourite(String peerId) async {
    final ok = await _store.addFavourite(peerId);
    if (!ok && mounted) {
      showAppToast(context, AppLocalizations.of(context).callsTabFavAddFailed);
    }
  }

  Future<void> _removeFavourite(String peerId) async {
    final ok = await _store.removeFavourite(peerId);
    if (!ok && mounted) {
      showAppToast(context, AppLocalizations.of(context).callsTabFavRemoveFailed);
    }
  }

  void _notNow(ChatUser person) {
    final until =
        callsClock().add(kFavSuggestSnooze).millisecondsSinceEpoch;
    unawaited(SettingsStore.instance.snoozeCallsFavSuggestion(person.id, until));
    setState(() {});
  }

  void _pickFavourite() {
    final api = widget.api;
    if (api == null) return;
    unawaited(
      showAddFavouriteSheet(
        context,
        directory: widget.directory,
        api: api,
        pinned: _store.favouriteIds.toSet(),
        onPick: (p) => unawaited(_addFavourite(p.id)),
      ),
    );
  }

  void _openDetails(CallLogEntry e, {List<CallLogEntry> stack = const []}) {
    unawaited(
      showCallDetails(
        context,
        entry: e,
        stack: stack,
        directory: widget.directory,
        api: widget.api,
        onCall: (kind) {
          Navigator.of(context).pop();
          unawaited(callBack(context,
              directory: widget.directory, entry: e, kind: kind));
        },
        onMessage: () {
          Navigator.of(context).pop();
          widget.directory.openChat(context, e.roomId);
        },
        isFavourite: () => _favouriteOf(e),
        refresh: _store,
        onToggleFavourite: () {
          final id = e.peerId;
          if (id == null) return;
          unawaited(
            _store.isFavourite(id) ? _removeFavourite(id) : _addFavourite(id),
          );
        },
      ),
    );
  }

  Future<void> _callPerson(ChatUser person, CallMediaKind kind) async {
    try {
      final room = await widget.directory.dmRoomWith(person);
      if (!mounted) return;
      await startDirectCall(context, peer: person, roomId: room, kind: kind);
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, AppLocalizations.of(context).callButtonErrorGeneric);
    }
  }

  void _newCall() {
    final api = widget.api;
    if (api == null) return;
    unawaited(
      showNewCallSheet(
        context,
        directory: widget.directory,
        api: api,
        onStart: (p, k) => unawaited(_callPerson(p, k)),
      ),
    );
  }

  // ── build ──

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final entries = _store.entries(_filter);
    final loaded = _store.isLoaded(_filter);
    final items = _items(entries);
    final showEmpty = loaded && items.isEmpty;
    final missedCount = _store.badgeCount;
    final favIds = _store.favouriteIds;
    final settings = SettingsStore.instance;
    final suggestion = pickFavSuggestion(
      month: _store.month,
      favouriteIds: favIds,
      userOf: widget.directory.user,
      snoozedUntil: settings.callsFavSnoozedUntil,
      nowMs: callsClock().millisecondsSinceEpoch,
    );

    final head = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
        child: Semantics(
          header: true,
          child: Text(
            l10n.callsTabNavLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.displayLarge.copyWith(letterSpacing: 0.37),
          ),
        ),
      ),
      CallsLiveStrip(directory: widget.directory, api: widget.api),
      if (_store.favouritesLoaded)
        CallsFavourites(
          people: [
            for (final id in favIds) ?widget.directory.user(id),
          ],
          api: widget.api,
          onPick: (u, k) => unawaited(_callPerson(u, k)),
          onRemove: (u) => unawaited(_removeFavourite(u.id)),
          onAdd: widget.api == null ? null : _pickFavourite,
        ),
      if (_store.favouritesLoaded)
        CallsFavSuggestionSlot(
          suggestion: suggestion,
          api: widget.api,
          onAdd: (u) => unawaited(_addFavourite(u.id)),
          onNotNow: _notNow,
        ),
      CallsTalkTime(
        summary: _store.week,
        weekStart: weekStart(context),
        directory: widget.directory,
        api: widget.api,
        store: _store,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: IosSegmentedControl<String>(
          value: _filter,
          onChanged: (v) {
            if (v == _filter) return;
            setState(() => _filter = v);
            _store.ensure(v);
          },
          segments: [
            IosSegment(
              value: CallLogStore.all,
              label: l10n.callsTabFilterAll,
            ),
            IosSegment(
              value: CallLogStore.missed,
              label: l10n.callsTabFilterMissed,
              badge: missedCount > 0 && _filter != CallLogStore.missed,
              semanticLabel: l10n.callsTabFilterMissed,
            ),
          ],
        ),
      ),
    ];

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: head,
        ),
      ),
      if (showEmpty)
        SliverToBoxAdapter(
          child: CallsEmpty(
            key: ValueKey('empty_$_filter'),
            missedOnly: _filter == CallLogStore.missed,
            onNewCall: widget.api == null ? null : _newCall,
          ),
        )
      else if (_store.failed(_filter) && items.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                l10n.callsTabLoadFailed,
                style: theme.bodySoft.copyWith(color: theme.inkMuted),
              ),
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return switch (item) {
              CallDayHeader(:final day) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Text(
                    dayLabel(context, day),
                    style: theme.bodyEmph.copyWith(
                      fontSize: 13.5,
                      color: theme.inkMuted,
                    ),
                  ),
                ),
              CallRow() => CallRowTile(
                  key: ValueKey(item.first.id),
                  row: item,
                  favourite: _favouriteOf(item.first),
                  directory: widget.directory,
                  api: widget.api,
                  onOpenDetails: (row) =>
                      _openDetails(row.first, stack: row.entries),
                  onAction: _onRowAction,
                ),
            };
          },
        ),
      SliverToBoxAdapter(
        child: SizedBox(height: sectionBottomPadding(context)),
      ),
    ];

    return Stack(
      children: [
        const SunlitBackdrop(),
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: NativeCut(top: TabRootBar.clearance(context), child: AdaptivePageBody(
            child: CustomScrollView(
              controller: _scroll,
              key: const PageStorageKey('calls_list_v1'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(top: TabRootBar.clearance(context)),
                ),
                ...slivers,
              ],
            ),
          )),
        ),
        TabRootBar(
          title: l10n.callsTabNavLabel,
          scroll: _scroll,
          trailing: widget.api == null
              ? null
              : GlassIconButton(
                  icon: CupertinoIcons.phone_badge_plus,
                  semanticLabel: l10n.callsTabNewCall,
                  onTap: _newCall,
                ),
        ),
      ],
    );
  }
}
