import 'dart:async';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../family/family_service.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/discover_rows.dart';
import '../widgets/user_avatar.dart';
import 'friend_request_draft_screen.dart';
import 'profile_screen.dart';
import 'navigation/enter_public_room.dart';
import 'navigation/open_room.dart';

/// Which half of search this screen is.
///
/// Fixed for the life of the screen. Discover reaches each half through its own
/// door, so an in-place PEOPLE/ROOMS switcher here would re-mix the two worlds
/// that the doors exist to keep apart.
enum SearchMode { people, rooms }

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.repo,
    required this.api,
    required this.mode,
    this.heroTag,
    this.family,
  });
  final ChatRepository repo;
  final ChatApi api;
  final SearchMode mode;

  /// Tag of the collapsed bar this screen flies out of, when there is one.
  ///
  /// Null from Discover: its doors are two-line cards, and morphing one into a
  /// one-line search field made the flight interpolate toward a box shorter
  /// than the card's own text, overflowing on every frame. The route's
  /// fade-and-slide carries the transition instead.
  final String? heroTag;

  /// Optional so existing callers keep working; falls back to
  /// [FamilyService.maybeInstance]. Threaded through so the room results can
  /// run the same child approval gate Discover does.
  final FamilyService? family;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  String _query = '';
  Timer? _debounce;

  bool get _people => widget.mode == SearchMode.people;

  FamilyService? get _family => widget.family ?? FamilyService.maybeInstance;

  /// Rooms this child has already asked about in this session, so a second tap
  /// doesn't file a duplicate approval into their guardian's queue.
  Set<String> _awaiting = {};

  List<ChatUser> _users = [];
  List<ChatRoom> _rooms = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Without this, `repo.isJoined` is sampled once at build, so a room joined
    // from here (or on another device) keeps rendering as un-joined.
    widget.repo.addListener(_onRepoChange);
    _refresh();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChange);
    _q.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
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
        // Pass the viewer — the backend blanks this list for any child account
        // (rooms.ts listPublic). Omitting it here would route around the very
        // gate Discover relies on.
        final rs = await widget.api.listPublic(
          viewerUserId: widget.repo.userId,
        );
        _rooms = _query.isEmpty
            ? rs
            : rs
                  .where(
                    (r) => r.name.toLowerCase().contains(_query.toLowerCase()),
                  )
                  .toList();
      }
    } catch (_) {
    } finally {
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
                    hintText: _people
                        ? AppLocalizations.of(context).searchScreenHintPeople
                        : AppLocalizations.of(context).searchScreenHintRooms,
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
                          position:
                              Tween(
                                    begin: const Offset(0, 0.06),
                                    end: Offset.zero,
                                  )
                                  .chain(
                                    CurveTween(curve: theme.motionEntrance),
                                  )
                                  .animate(anim),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previousChildren, ?currentChild],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(widget.mode),
                        child: _loading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: theme.accent,
                                  strokeWidth: 2,
                                ),
                              )
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
                ? AppLocalizations.of(context).searchScreenPeoplePromptChild
                : AppLocalizations.of(
                    context,
                  ).searchScreenPeoplePromptDefault,
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
                ? AppLocalizations.of(context).searchScreenNoMatchChild
                : AppLocalizations.of(context).searchScreenNoMatchDefault,
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
      final msg = _query.isEmpty
          ? AppLocalizations.of(context).searchScreenNoRoomsYet
          : AppLocalizations.of(context).searchScreenNoRoomsMatch;
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
        family: _family,
        awaiting: _awaiting.contains(_rooms[i].id),
        onAsked: (id) {
          if (mounted) setState(() => _awaiting = {..._awaiting, id});
        },
      ),
    );
  }
}

/// A [Hero] when there is something to fly from, and nothing at all when there
/// isn't. A Hero with no matching source doesn't animate, but it still installs
/// a flight-manager entry — so skipping it outright keeps the no-tag case
/// honest.
class _MaybeHero extends StatelessWidget {
  const _MaybeHero({required this.tag, required this.child});
  final String? tag;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      tag == null ? child : Hero(tag: tag!, child: child);
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
  final String? heroTag;
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
            child: _MaybeHero(
              tag: heroTag,
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  decoration: theme.inputDecoration(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
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
                            hintStyle: theme.body.copyWith(
                              color: theme.inkMuted,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          onChanged: onChanged,
                        ),
                      ),
                    ],
                  ),
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
  const _PersonRow({
    required this.user,
    required this.repo,
    required this.api,
    required this.onChanged,
  });
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
          nav.push(
            MaterialPageRoute(
              builder: (_) => FriendRequestDraftScreen(
                repo: widget.repo,
                api: widget.api,
                target: widget.user,
              ),
            ),
          );
          break;
        case FriendshipStatus.outgoingPending:
          await widget.repo.cancelDirectRequest(widget.user.id);
          break;
        case FriendshipStatus.incomingPending:
          final roomId = await widget.repo.approveDirectRequest(widget.user.id);
          if (!mounted) return;
          if (roomId != null) {
            openRoom(
              context,
              roomId: roomId,
              repo: widget.repo,
              api: widget.api,
            );
          }
          break;
        case FriendshipStatus.friend:
          final roomId = await widget.repo.openDmWith(widget.user);
          if (!mounted) return;
          openRoom(context, roomId: roomId, repo: widget.repo, api: widget.api);
          break;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onChanged();
      }
    }
  }

  String _actionLabel() {
    final l10n = AppLocalizations.of(context);
    switch (widget.user.friendshipStatus) {
      case FriendshipStatus.none:
        // A child's request goes to their grown-up first, so promising to
        // "send" it would be a lie.
        return FamilyService.maybeInstance?.isChild == true
            ? l10n.searchScreenActionAskToAdd
            : l10n.searchScreenActionSendRequest;
      case FriendshipStatus.outgoingPending:
        return l10n.searchScreenActionCancel;
      case FriendshipStatus.incomingPending:
        return l10n.searchScreenActionApprove;
      case FriendshipStatus.friend:
        return l10n.searchScreenActionOpenDm;
    }
  }

  bool get _filled =>
      widget.user.friendshipStatus != FriendshipStatus.outgoingPending;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            user: widget.user,
            repo: widget.repo,
            api: widget.api,
          ),
        ),
      ),
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
                  Text(
                    widget.user.displayName,
                    style: theme.displaySmall.copyWith(fontSize: 16),
                  ),
                  Text('@${widget.user.username}', style: theme.monoTiny),
                ],
              ),
            ),
            GestureDetector(
              onTap: _busy ? null : _act,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _filled
                      ? (_busy ? theme.accentSoft : theme.accent)
                      : Colors.transparent,
                  border: Border.all(
                    color: _filled ? theme.accent : theme.divider,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text(
                  _actionLabel(),
                  style: theme.label.copyWith(
                    color: _filled ? theme.accentInk : theme.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The full public-room list — this screen with an empty query — and Discover's
/// preview of it are the same rows, so they're the same widget. They were two
/// near-copies that had already drifted (this one printed the description in
/// `monoTiny`, showed no ephemeral pill, and had no member-count unit), and a
/// redesign of one would have left the other squashed.
class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.repo,
    required this.api,
    required this.family,
    required this.awaiting,
    required this.onAsked,
  });
  final ChatRoom room;
  final ChatRepository repo;
  final ChatApi api;
  final FamilyService? family;

  /// This child has already raised this room with a grown-up.
  final bool awaiting;
  final ValueChanged<String> onAsked;

  @override
  Widget build(BuildContext context) {
    return PublicRoomTile(
      room: room,
      api: api,
      awaiting: awaiting,
      // Same rule Discover tiles use.
      joined: repo.isJoined(room),
      // Goes through the shared flow rather than straight to the join sheet.
      // This row used to skip the child approval gate entirely: the server
      // still refused the join, but no approval was ever filed, so a child got
      // "couldn't join — try again" with no way to ask anyone.
      onTap: () => enterPublicRoom(
        context,
        room: room,
        repo: repo,
        api: api,
        family: family,
        alreadyAsked: awaiting,
        onAsked: onAsked,
      ),
    );
  }
}
