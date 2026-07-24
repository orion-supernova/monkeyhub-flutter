import 'dart:async';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../family/family_service.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/join_room_sheet.dart';
import '../widgets/user_avatar.dart';
import '../widgets/visibility_badge.dart';
import 'friend_request_draft_screen.dart';
import 'profile_screen.dart';
import 'navigation/open_room.dart';

/// Which half of search this screen is. Rooms live under Discover, people
/// under Friends — the two are never mixed, so a child who may ask to add a
/// contact can reach people search without that also handing them Discover.
enum SearchMode { people, rooms }

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.repo,
    required this.api,
    required this.mode,
    required this.heroTag,
  });
  final ChatRepository repo;
  final ChatApi api;
  final SearchMode mode;

  /// Tag of the collapsed bar this screen flies out of. Each entry point
  /// passes its own — Discover's and Friends' bars can both be mounted for a
  /// frame mid tab-transition, and two live Heroes sharing a tag throws.
  final String heroTag;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  String _query = '';
  Timer? _debounce;

  bool get _people => widget.mode == SearchMode.people;

  List<ChatUser> _users = [];
  List<ChatRoom> _rooms = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _q.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    final hasQuery = v.isNotEmpty;
    setState(() {
      _query = v;
      _loading = hasQuery;
      if (!hasQuery) _users = const [];
    });
    if (hasQuery) {
      _debounce = Timer(const Duration(milliseconds: 250), _refresh);
    } else if (!_people) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final me = widget.repo.userId ?? '';
    try {
      if (_people) {
        _users = _query.isEmpty
            ? const []
            : await widget.api.searchUsers(query: _query, currentUserId: me);
      } else {
        // Pass the viewer — the backend blanks this list for a child without
        // `publicRoomsEnabled` (rooms.ts listPublic). Omitting it here would
        // route around the very gate Discover relies on.
        final rs = await widget.api.listPublic(
          viewerUserId: widget.repo.userId,
        );
        _rooms = _query.isEmpty
            ? rs
            : rs.where((r) => r.name.toLowerCase().contains(_query.toLowerCase())).toList();
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: Column(
              children: [
                _Header(
                  q: _q,
                  heroTag: widget.heroTag,
                  hintText: _people ? 'search people…' : 'search rooms…',
                  onChanged: _onChanged,
                  onClose: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: theme.motionMed,
                    switchInCurve: theme.motionEntrance,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                            .chain(CurveTween(curve: theme.motionEntrance))
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...previousChildren,
                        ?currentChild,
                      ],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(widget.mode),
                      child: _loading
                          ? Center(child: CircularProgressIndicator(color: theme.accent, strokeWidth: 2))
                          : (_people ? _peopleBody() : _roomsBody()),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _peopleBody() {
    final theme = ThemeScope.of(context);
    // A child only matches people they already have as they type; anyone else
    // needs the complete username. Say so up front and again when nothing
    // matched, otherwise the rule reads as the search being broken.
    final isChild = FamilyService.maybeInstance?.isChild == true;
    if (_query.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            isChild
                ? 'type a whole username to find someone new'
                : 'search by username or name',
            style: theme.bodySoft,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            isChild
                ? 'no one matches — new people need their\nwhole username, spelled exactly'
                : 'no one matches',
            style: theme.bodySoft,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: _users.length,
      itemBuilder: (_, i) => _PersonRow(
        user: _users[i],
        repo: widget.repo,
        api: widget.api,
        onChanged: _refresh,
      ),
    );
  }

  Widget _roomsBody() {
    final theme = ThemeScope.of(context);
    if (_rooms.isEmpty) {
      final msg = _query.isEmpty ? 'no public rooms yet' : 'no public rooms match';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(child: Text(msg, style: theme.bodySoft)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: _rooms.length,
      itemBuilder: (_, i) => _RoomRow(
        room: _rooms[i],
        repo: widget.repo,
        api: widget.api,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.q,
    required this.heroTag,
    required this.hintText,
    required this.onChanged,
    required this.onClose,
  });
  final TextEditingController q;
  final String heroTag;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Hero(
              tag: heroTag,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: theme.inputDecoration(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Icon(Icons.search, color: theme.inkMuted, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: q,
                        autofocus: true,
                        style: theme.body.copyWith(color: theme.ink),
                        cursorColor: theme.accent,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: hintText,
                          hintStyle: theme.body.copyWith(color: theme.inkMuted),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: onChanged,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Icon(Icons.close, color: theme.inkSoft, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatefulWidget {
  const _PersonRow({required this.user, required this.repo, required this.api, required this.onChanged});
  final ChatUser user;
  final ChatRepository repo;
  final ChatApi api;
  final VoidCallback onChanged;
  @override
  State<_PersonRow> createState() => _PersonRowState();
}

class _PersonRowState extends State<_PersonRow> {
  bool _busy = false;

  Future<void> _act() async {
    if (_busy) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      switch (widget.user.friendshipStatus) {
        case FriendshipStatus.none:
          if (!mounted) return;
          nav.push(MaterialPageRoute(
            builder: (_) => FriendRequestDraftScreen(
              repo: widget.repo,
              api: widget.api,
              target: widget.user,
            ),
          ));
          break;
        case FriendshipStatus.outgoingPending:
          await widget.repo.cancelDirectRequest(widget.user.id);
          break;
        case FriendshipStatus.incomingPending:
          final roomId = await widget.repo.approveDirectRequest(widget.user.id);
          if (!mounted) return;
          if (roomId != null) {
            openRoom(context, roomId: roomId, repo: widget.repo, api: widget.api);
          }
          break;
        case FriendshipStatus.friend:
          final roomId = await widget.repo.openDmWith(widget.user);
          if (!mounted) return;
          openRoom(context, roomId: roomId, repo: widget.repo, api: widget.api);
          break;
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onChanged();
      }
    }
  }

  String _actionLabel() {
    switch (widget.user.friendshipStatus) {
      case FriendshipStatus.none:
        // A child's request goes to their grown-up first, so promising to
        // "send" it would be a lie.
        return FamilyService.maybeInstance?.isChild == true
            ? 'ASK TO ADD'
            : 'SEND REQUEST';
      case FriendshipStatus.outgoingPending:
        return 'CANCEL';
      case FriendshipStatus.incomingPending:
        return 'APPROVE';
      case FriendshipStatus.friend:
        return 'OPEN DM';
    }
  }

  bool get _filled =>
      widget.user.friendshipStatus != FriendshipStatus.outgoingPending;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProfileScreen(
                user: widget.user,
                repo: widget.repo,
                api: widget.api,
              ))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: theme.roomCardDecoration(ephemeral: false, active: false),
        child: Row(
          children: [
            UserAvatar(user: widget.user, size: 40, api: widget.api),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.user.displayName, style: theme.displaySmall.copyWith(fontSize: 16)),
                  Text('@${widget.user.username}', style: theme.monoTiny),
                ],
              ),
            ),
            GestureDetector(
              onTap: _busy ? null : _act,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _filled
                      ? (_busy ? theme.accentSoft : theme.accent)
                      : Colors.transparent,
                  border: Border.all(
                      color: _filled ? theme.accent : theme.divider, width: 1.2),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text(_actionLabel(),
                    style: theme.label.copyWith(
                        color: _filled ? theme.accentInk : theme.ink)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({required this.room, required this.repo, required this.api});
  final ChatRoom room;
  final ChatRepository repo;
  final ChatApi api;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        // Preview + confirm before joining; a locked room's password field
        // lives inside this same sheet.
        final result = await showJoinRoomSheet(context, room, api);
        if (!context.mounted || result == null) return;
        try {
          await repo.joinRoom(roomId: room.id, password: result.password);
          if (!context.mounted) return;
          openRoom(context, roomId: room.id, repo: repo, api: api);
        } catch (e) {
          final msg = e.toString().contains('WRONG_PASSWORD')
              ? 'wrong password'
              : 'couldn\'t join — try again';
          messenger.showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.accentSoft,
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              child: room.isEphemeral
                  ? theme.hourglassIcon(size: 14, color: theme.accent)
                  : Icon(Icons.tag, size: 14, color: theme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name, style: theme.displaySmall.copyWith(fontSize: 16)),
                  if (room.description != null && room.description!.isNotEmpty)
                    Text(room.description!.toLowerCase(), style: theme.monoTiny,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            VisibilityBadge(isPublic: room.isPublic, dense: true),
            const SizedBox(width: 8),
            Text('${room.memberCount}', style: theme.monoLarge),
          ],
        ),
      ),
    );
  }
}
