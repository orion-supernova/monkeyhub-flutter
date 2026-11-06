import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/room_filter.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/call_history.dart';
import '../models/chat_room.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/archive_hero.dart';
import '../widgets/chat_list_row.dart';
import '../widgets/chat_list_parts.dart' show chatListTitleOf;
import '../widgets/chat_row_action_menu.dart';
import '../widgets/chat_row_swipe.dart';
import '../widgets/ios_kit.dart';
import '../widgets/mute_room_sheet.dart';
import '../widgets/room_filter_bar.dart';
import '../widgets/search_field.dart';
import 'navigation/open_room.dart';

/// Every room the viewer has archived, as a page of its own.
///
/// Reached from the Archived chats folder, in the pull-down panel and, whenever
/// something archived has unread messages, on the chat list itself. It used to
/// be a sheet: no search, no filters, and the unread state of what was inside
/// invisible until a row was found by scrolling. A page can carry a pinned
/// search and the same filter facets the chat list has, put what is waiting
/// first, and let the rows leave with a motion of their own.
Future<void> openArchivedChats(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => ArchivedChatsScreen(repo: repo, api: api),
    ),
  );
}

class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key, required this.repo, required this.api});

  final ChatRepository repo;
  final ChatApi api;

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  final _searchCtrl = TextEditingController();

  /// Local to this page. The chat list's own filter is persisted and lives in
  /// [SettingsStore]; sharing it would mean narrowing the archive also
  /// narrowed the list behind it.
  RoomFilter _filter = RoomFilter.empty;
  String _query = '';

  /// Rooms whose unarchive is in flight: they collapse out of the list first,
  /// and the write goes out when they have gone.
  final Set<String> _leaving = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchesQuery(ChatRoom r) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final title = chatListTitleOf(context, r, widget.repo.otherUserFor(r));
    if (title.toLowerCase().contains(needle)) return true;
    final last = r.lastMessage ?? '';
    // A call's code is not text anybody can search for.
    if (CallEvent.isCallContent(last)) return false;
    return last.toLowerCase().contains(needle);
  }

  Future<void> _unarchive(ChatRoom room) async {
    if (!_leaving.add(room.id)) return;
    setState(() {});
    final calm = MotionScope.of(context).calm;
    if (!calm) await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await widget.repo.unarchiveRoom(room.id);
    } catch (_) {
      // The write failed: the row comes back rather than staying gone while
      // still archived.
      if (mounted) setState(() => _leaving.remove(room.id));
    }
  }

  void _open(ChatRoom room) {
    // The split shell fills a pane beside the list instead of pushing, so this
    // page would be left covering the room it just opened.
    if (context.usesSplitShell) Navigator.of(context).pop();
    openRoom(context, roomId: room.id, repo: widget.repo, api: widget.api);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    // Read through to the repository on every build, so unarchiving from here
    // (or from another device) and a message landing in an archived room both
    // update the page live.
    return AnimatedBuilder(
      animation: widget.repo,
      builder: (context, _) {
        final all = widget.repo.archivedRooms;
        _leaving.removeWhere((id) => !all.any((r) => r.id == id));
        final counts = RoomFacetCounts.projected(all, _filter);
        final shown = _filter.apply(all.where(_matchesQuery).toList());
        final unread = shown.where((r) => r.hasUnread).toList();
        final read = shown.where((r) => !r.hasUnread).toList();
        final unreadTotal = all.where((r) => r.hasUnread).length;
        final sectioned = unread.isNotEmpty && read.isNotEmpty;
        final refining = _query.trim().isNotEmpty || _filter.isNotEmpty;

        return IosPage(
          title: sentenceCaseOf(context, l10n.archivedChatsSheetTitle),
          slivers: [
            SliverToBoxAdapter(
              child: _Summary(
                total: all.length,
                unread: unreadTotal,
                open: shown.isNotEmpty,
              ),
            ),
            if (all.isNotEmpty)
              SliverPersistentHeader(
                pinned: true,
                delegate: _ToolbarDelegate(
                  extent: _ToolbarDelegate.extentFor(context),
                  background: theme.background,
                  child: _Toolbar(
                    controller: _searchCtrl,
                    hint: l10n.archivedChatsSearchHint,
                    onQuery: (q) => setState(() => _query = q),
                    filter: _filter,
                    counts: counts,
                    onFilter: (f) => setState(() => _filter = f),
                  ),
                ),
              ),
            if (shown.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
                  child: EmptyState(
                    icon: refining
                        ? CupertinoIcons.search
                        : CupertinoIcons.archivebox,
                    title: refining
                        ? l10n.archivedChatsNoMatch
                        : l10n.archivedChatsSheetEmptyMessage,
                    compact: true,
                  ),
                ),
              )
            else ...[
              if (sectioned)
                SliverToBoxAdapter(
                  child: _SectionLabel(
                    label: l10n.roomFacetLabelUnread,
                    count: unread.length,
                    hot: true,
                  ),
                ),
              _rows(unread, 0),
              if (sectioned)
                SliverToBoxAdapter(
                  child: _SectionLabel(
                    label: l10n.archivedChatsSectionRead,
                    count: read.length,
                  ),
                ),
              _rows(read, unread.length),
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _rows(List<ChatRoom> rooms, int offset) {
    if (rooms.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: rooms.length,
        itemBuilder: (context, i) {
          final room = rooms[i];
          return _ArchivedRow(
            // Identity, not position: a filter or a new message reorders the
            // list, and by-index matching would hand a row a different room's
            // avatar for a frame.
            key: ValueKey(room.id),
            room: room,
            index: offset + i,
            leaving: _leaving.contains(room.id),
            repo: widget.repo,
            api: widget.api,
            onOpen: () => _open(room),
            onUnarchive: () => _unarchive(room),
          );
        },
      ),
    );
  }
}

/// The count line next to the archive box.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.unread,
    required this.open,
  });

  final int total;
  final int unread;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          ArchiveHero(open: open, unread: unread > 0),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.archivedChatsSheetCount(total),
                  style: theme.displaySmall.copyWith(color: theme.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Crossfaded: the last unread chat being opened from here
                // turns the line from the badge's red to quiet.
                AnimatedSwitcher(
                  duration: theme.motionMed,
                  child: Text(
                    unread > 0
                        ? l10n.archivedChatsUnreadLine(unread)
                        : l10n.archivedChatsAllRead,
                    key: ValueKey(unread > 0),
                    style: theme.bodyEmph.copyWith(
                      fontSize: 15,
                      color: unread > 0 ? theme.badge : theme.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.count,
    this.hot = false,
  });

  final String label;
  final int count;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        children: [
          if (hot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: theme.badge,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            sentenceCaseOf(context, label),
            style: theme.caption.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hot ? theme.ink : theme.inkMuted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: theme.caption.copyWith(
              fontSize: 13,
              color: theme.inkMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Search and filter chips, the strip that stays under the bar while the list
/// scrolls.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.hint,
    required this.onQuery,
    required this.filter,
    required this.counts,
    required this.onFilter,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onQuery;
  final RoomFilter filter;
  final RoomFacetCounts counts;
  final ValueChanged<RoomFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SearchField(
            controller: controller,
            hintText: hint,
            onChanged: onQuery,
            onClear: () {
              controller.clear();
              onQuery('');
            },
            showCancel: false,
          ),
        ),
        const SizedBox(height: 8),
        RoomFilterBar(filter: filter, counts: counts, onChanged: onFilter),
      ],
    );
  }
}

class _ToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _ToolbarDelegate({
    required this.extent,
    required this.background,
    required this.child,
  });

  final double extent;
  final Color background;
  final Widget child;

  /// Search pill, the gap, the chip row at the reader's text scale, and a
  /// little air under it for the fade.
  static double extentFor(BuildContext context) {
    final chips = MediaQuery.textScalerOf(context).scale(32).clamp(32.0, 56.0);
    return 44 + 8 + chips + 10;
  }

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Opaque while it pins over rows, clear at rest: rows dissolve under it
    // rather than sliding behind a hard edge.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            background.withValues(alpha: overlapsContent ? 0.96 : 0),
            background.withValues(alpha: overlapsContent ? 0.96 : 0),
            background.withValues(alpha: 0),
          ],
          stops: const [0, 0.82, 1],
        ),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_ToolbarDelegate old) =>
      old.extent != extent ||
      old.background != background ||
      old.child != child;
}

class _ArchivedRow extends StatefulWidget {
  const _ArchivedRow({
    super.key,
    required this.room,
    required this.index,
    required this.leaving,
    required this.repo,
    required this.api,
    required this.onOpen,
    required this.onUnarchive,
  });

  final ChatRoom room;
  final int index;
  final bool leaving;
  final ChatRepository repo;
  final ChatApi api;
  final VoidCallback onOpen;
  final VoidCallback onUnarchive;

  @override
  State<_ArchivedRow> createState() => _ArchivedRowState();
}

class _ArchivedRowState extends State<_ArchivedRow> {
  final _anchorKey = GlobalKey();

  Future<void> _showMenu() async {
    final repo = widget.repo;
    final room = widget.room;
    // The cheap, no-fetch slice the chat list's own menu takes — see
    // [ChatRowPreviewCard]. Archiving hides a room from the list, it doesn't
    // close a transcript this session already had open.
    final all = repo.messagesFor(room.id);
    final recent = all.length <= previewMaxMessages
        ? all
        : all.sublist(all.length - previewMaxMessages);
    final action = await showChatRowActionMenu(
      context: context,
      anchorKey: _anchorKey,
      previewBuilder: (context) => ChatRowPreviewCard(
        room: room,
        api: widget.api,
        dmUser: repo.otherUserFor(room),
        recentMessages: recent,
        currentUserId: repo.userId ?? '',
        typists: repo.typingIn(room.id),
      ),
      isPinned: room.isPinned,
      // Always true on this page; passed explicitly so the menu's own
      // "archived rooms only offer Unarchive" rule stays the single source.
      isArchived: true,
      isMuted: room.isMuted,
      canMute: repo.capabilitiesFor(room).canMute,
    );
    if (!mounted) return;
    switch (action) {
      case ChatRowAction.unarchive:
        widget.onUnarchive();
      case ChatRowAction.mute:
        await showMuteRoomSheet(context, repo: repo, room: room);
      case ChatRowAction.unmute:
        await repo.unmuteRoom(room.id);
      case ChatRowAction.open:
        widget.onOpen();
      // The menu never offers these on an archived room; listed so a future
      // action fails here rather than silently doing nothing on this page.
      case ChatRowAction.pin:
      case ChatRowAction.unpin:
      case ChatRowAction.archive:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final repo = widget.repo;
    final room = widget.room;
    final calm = MotionScope.of(context).calm;

    final row = ChatRowLongPress(
      key: _anchorKey,
      onLongPress: _showMenu,
      child: ChatRowSwipe(
        // Right: put it back. Fires on a full swipe, so the gesture that
        // files a chat away in the list is mirrored by the one that returns it.
        leading: [
          SwipeAction(
            label: l10n.chatSwipeUnarchive,
            icon: CupertinoIcons.tray_arrow_up_fill,
            color: const Color(0xFF34C759),
            onTap: widget.onUnarchive,
          ),
        ],
        trailing: [
          if (repo.capabilitiesFor(room).canMute)
            SwipeAction(
              label: room.isMuted ? l10n.chatSwipeUnmute : l10n.chatSwipeMute,
              icon: room.isMuted
                  ? CupertinoIcons.bell_fill
                  : CupertinoIcons.bell_slash_fill,
              color: const Color(0xFF5856D6),
              onTap: () => room.isMuted
                  ? repo.unmuteRoom(room.id)
                  : showMuteRoomSheet(context, repo: repo, room: room),
            ),
        ],
        child: ChatListRow(
          room: room,
          api: widget.api,
          dmUser: repo.otherUserFor(room),
          typists: repo.typingIn(room.id),
          showDivider: false,
          onTap: widget.onOpen,
        ),
      ),
    );

    if (calm) {
      return widget.leaving ? const SizedBox.shrink() : row;
    }

    // Two motions on one row: it settles in, staggered for what a screen shows
    // and together past that; and when it is unarchived it slides out toward
    // the side it was swiped to while the rows under it close the gap.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
          theme.motionMed +
          Duration(milliseconds: widget.index.clamp(0, 9) * 45),
      curve: theme.motionEntrance,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 16),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.leaving ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        builder: (context, out, child) {
          if (out == 0) return child!;
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 1 - out,
              child: Opacity(
                opacity: 1 - out,
                child: Transform.translate(
                  offset: Offset(out * 56, 0),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: row,
      ),
    );
  }
}
