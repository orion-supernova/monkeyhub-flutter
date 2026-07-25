import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../family/family_service.dart';
import '../models/chat_room.dart';
import '../models/family.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/approval_gate.dart';
import '../widgets/join_room_sheet.dart';
import '../widgets/visibility_badge.dart';
import 'navigation/open_room.dart';
import 'search_screen.dart';
// Discover panel doesn't open profile directly anymore — search screen does.

/// Discover is rooms-only; people search lives in Friends. Its own Hero tag,
/// distinct from the Friends bar, so a tab transition can't briefly mount two
/// Heroes under one tag.
const String _searchBarTag = 'discover-search-bar';

class DiscoverPanel extends StatefulWidget {
  const DiscoverPanel({
    super.key,
    required this.repo,
    required this.api,
    required this.family,
  });
  final ChatRepository repo;
  final ChatApi api;
  final FamilyService family;
  @override
  State<DiscoverPanel> createState() => _DiscoverPanelState();
}

class _DiscoverPanelState extends State<DiscoverPanel> {
  List<ChatRoom> _rooms = [];
  bool _loading = false;

  /// Rooms this child has already asked about, so their tiles read
  /// "waiting for a grown-up" instead of inviting a second request.
  Set<String> _awaiting = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      // Passing the viewer lets the backend blank this list for a child who
      // isn't allowed public rooms — belt and braces with hiding the tab.
      final rs = await widget.api.listPublic(
        viewerUserId: widget.repo.userId,
      );
      if (!mounted) return;
      setState(() => _rooms = rs);
      if (widget.family.isChild) await _refreshAwaiting();
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAwaiting() async {
    final uid = widget.repo.userId;
    if (uid == null) return;
    try {
      final pending = await widget.api.listMyApprovals(uid);
      if (!mounted) return;
      setState(() => _awaiting = pending
          .where((p) => p.roomId != null)
          .map((p) => p.roomId!)
          .toSet());
    } catch (_) {/* tiles just won't show the pill */}
  }

  /// Whether the viewer is already in [room], and can therefore just walk in.
  bool _joined(ChatRoom room) => widget.repo.isJoined(room);

  /// A child tapping a room they don't have raises the request with their
  /// guardians instead of failing. Returns true when the join should proceed.
  Future<bool> _clearedToJoin(ChatRoom room) async {
    if (!widget.family.isChild) return true;
    // A child already in the room needs no new grant — the guardian's decision
    // is what put them there. Asking again would queue a second approval for
    // access they demonstrably already have.
    if (_joined(room)) return true;
    final uid = widget.repo.userId;
    if (uid == null) return false;

    final alreadyAsked = _awaiting.contains(room.id);
    final wantsToAsk = await showApprovalGate(
      context,
      what: 'join ${room.name}',
      detail: room.description,
      alreadyAsked: alreadyAsked,
    );
    if (!wantsToAsk || alreadyAsked) return false;

    try {
      await widget.api.requestApproval(
        childId: uid,
        kind: 'joinRoom',
        targetRoomId: room.id,
      );
      if (mounted) setState(() => _awaiting = {..._awaiting, room.id});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('couldn\'t ask right now — try again')),
        );
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AdaptivePageBody(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: theme.motionMed,
              reverseTransitionDuration: theme.motionMed,
              pageBuilder: (_, _, _) => SearchScreen(
                repo: widget.repo,
                api: widget.api,
                mode: SearchMode.rooms,
                heroTag: _searchBarTag,
              ),
              transitionsBuilder: (_, anim, _, child) {
                final curved = CurvedAnimation(parent: anim, curve: theme.motionEntrance);
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                        .animate(curved),
                    child: child,
                  ),
                );
              },
            ),
          ),
          child: Hero(
            tag: _searchBarTag,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: theme.inputDecoration(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.search, color: theme.inkMuted, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'search rooms…',
                        style: theme.body.copyWith(color: theme.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('ROOMS · PUBLIC', style: theme.label),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: theme.divider)),
            const SizedBox(width: 8),
            Text('${_rooms.length}', style: theme.monoTiny),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading && _rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: theme.accent, strokeWidth: 2)),
          )
        else if (_rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('no public rooms', style: theme.bodySoft)),
          )
        else
          // Rebuilds on every repo change so a tile flips to JOINED the moment
          // the `rooms:listUserRooms` subscription delivers the new membership
          // — including when the join happened somewhere else entirely (a push
          // tap, another device). Without this the badge would be stale until
          // the next manual _refresh().
          ListenableBuilder(
            listenable: widget.repo,
            builder: (context, _) => Column(children: _tiles(context)),
          ),
      ],
    ),
    );
  }

  List<Widget> _tiles(BuildContext context) {
    return [
      for (final r in _rooms)
        _DiscoverRoomTile(
          key: ValueKey(r.id),
          room: r,
          awaiting: _awaiting.contains(r.id),
          joined: _joined(r),
          onTap: () => _onTapRoom(context, r),
        ),
    ];
  }

  Future<void> _onTapRoom(BuildContext context, ChatRoom r) async {
    final messenger = ScaffoldMessenger.of(context);
    // Already in it — just open it. Everything below is the flow for *getting*
    // into a room, and running any of it against a room you're already in is
    // the bug this guard exists to prevent: an approval gate for access you
    // have, then a JOIN sheet that re-asks for a password you've already
    // cleared, then a join the backend treats as a no-op.
    if (_joined(r)) {
      openRoom(context, roomId: r.id, repo: widget.repo, api: widget.api);
      return;
    }
    // Child gate first: no point previewing a room they can't enter yet.
    if (!await _clearedToJoin(r)) return;
    if (!context.mounted) return;
    // Preview + confirm before joining; a locked room's password field lives
    // inside this same sheet.
    final result = await showJoinRoomSheet(context, r, widget.api);
    if (!mounted || result == null) return;
    try {
      await widget.repo.joinRoom(roomId: r.id, password: result.password);
      if (!context.mounted) return;
      openRoom(context, roomId: r.id, repo: widget.repo, api: widget.api);
    } catch (e) {
      // A child can still trip the server-side gate if a grant was revoked
      // between listing and tapping.
      if (isChildGateError(e)) {
        await _refreshAwaiting();
        return;
      }
      final msg = e.toString().contains('WRONG_PASSWORD')
          ? 'wrong password'
          : 'couldn\'t join — try again';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _DiscoverRoomTile extends StatelessWidget {
  const _DiscoverRoomTile({
    super.key,
    required this.room,
    required this.onTap,
    this.awaiting = false,
    this.joined = false,
  });
  final ChatRoom room;
  final VoidCallback onTap;

  /// This child has already asked a grown-up about this room.
  final bool awaiting;

  /// The viewer is already a member, so tapping opens it rather than joining.
  final bool joined;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: theme.accentSoft,
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              alignment: Alignment.center,
              child: room.isEphemeral
                  ? theme.hourglassIcon(size: 14, color: theme.accent)
                  : Icon(Icons.tag, size: 14, color: theme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name, style: theme.displaySmall),
                  const SizedBox(height: 2),
                  if (room.description != null && room.description!.isNotEmpty)
                    Text(room.description!.toLowerCase(),
                        style: theme.bodySoft, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (joined)
              const JoinedBadge(dense: true)
            else if (awaiting)
              const WaitingPill(label: 'asked')
            else
              VisibilityBadge(isPublic: room.isPublic, dense: true),
            const SizedBox(width: 8),
            Text('${room.memberCount}', style: theme.monoLarge),
            const SizedBox(width: 4),
            Text('IN', style: theme.monoTiny),
          ],
        ),
      ),
    );
  }
}
