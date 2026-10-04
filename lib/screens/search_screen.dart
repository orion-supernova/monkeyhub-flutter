import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'dart:async';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../family/family_service.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/discover_rows.dart';
import '../widgets/search_field.dart';
import '../widgets/user_avatar.dart';
import 'friend_request_draft_screen.dart';
import 'profile_screen.dart';
import 'navigation/enter_public_room.dart';
import 'navigation/open_room.dart';

import '../widgets/ios_kit.dart';

/// Which half of search this screen is.
///
/// Fixed for the life of the screen. Discover reaches each half through its own
/// door, so an in-place PEOPLE/ROOMS switcher here would re-mix the two worlds
/// that the doors exist to keep apart.
enum SearchMode { people, rooms }

/// Ties this screen's search bar to the Discover door that opens it.
///
/// One tag per mode, because both doors are on Discover at the same time and a
/// tag shared between them would make each one a candidate destination for the
/// other's flight.
String searchFieldHeroTagFor(SearchMode mode) => 'search-door-${mode.name}';

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

  /// Tag of the door this screen flies out of, when there is one — normally
  /// [searchFieldHeroTagFor] of [mode].
  ///
  /// Null falls back to the route's own fade-and-slide, which is what every
  /// entry point that has no single box to fly from wants: Discover's SEE ALL
  /// row opens the same screen from somewhere that isn't a search door.
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

  /// Re-runs the current query.
  ///
  /// [silent] keeps the existing results on screen while the new ones are in
  /// flight. Every refresh that happens because the user came BACK from
  /// somewhere uses it: flipping `_loading` there would tear the whole list
  /// down to a spinner and rebuild it, which on a returning transition reads
  /// as the screen having lost its place.
  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
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

  /// Re-reads the results without a spinner, for a return from a pushed route.
  ///
  /// Rooms don't need it — a join already lands through `repo.addListener` —
  /// so it is a no-op there rather than a pointless `listPublic` round trip.
  void _refreshPeopleQuietly() {
    if (!_people || _query.isEmpty) return;
    _refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // See home_screen: the bottom inset leaves a dead strip of
          // background under the scroller, which reads as a solid bar. The
          // list clears the home indicator with its own padding instead.
          SafeArea(
            bottom: false,
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
                                child: CupertinoActivityIndicator(color: theme.inkMuted),
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
      padding: EdgeInsets.fromLTRB(20, 0, 20, edgeToEdgeBottom(context)),
      itemCount: _users.length,
      itemBuilder: (_, i) => _PersonRow(
        // Keyed by identity, not by position. These rows carry their own
        // `_busy` state and the list is rebuilt under them by every refresh;
        // without this, a re-ordered result set hands one person's row the
        // state of whoever used to sit at that index.
        key: ValueKey(_users[i].id),
        user: _users[i],
        repo: widget.repo,
        api: widget.api,
        onChanged: _refreshPeopleQuietly,
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
      padding: EdgeInsets.fromLTRB(20, 0, 20, edgeToEdgeBottom(context)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            // The shared bar, and the far end of the flight out of Discover's
            // door — both halves of Explore land here, so both get the same
            // clear button and the same shape.
            child: SearchField(
              controller: q,
              hintText: hintText,
              onChanged: onChanged,
              autofocus: true,
              heroTag: heroTag,
            ),
          ),
          const SizedBox(width: 10),
          // The iOS search bar's Cancel, in the accent — THE tertiary text
          // action, so it springs and takes keyboard focus like every other.
          TextLinkButton(
            label: MaterialLocalizations.of(context).cancelButtonLabel,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatefulWidget {
  const _PersonRow({
    super.key,
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

  /// True when a grown-up is still holding this request — the viewer's own
  /// grown-up, never the other side's. Nothing here is actionable while that
  /// is true, so the row states a fact instead of offering a button the
  /// backend would refuse.
  bool get _heldByGrownUp => widget.user.awaitingGuardian;

  Future<void> _act() async {
    if (_busy || _heldByGrownUp) return;
    setState(() => _busy = true);
    final nav = Navigator.of(context);
    try {
      switch (widget.user.friendshipStatus) {
        case FriendshipStatus.none:
          if (!mounted) return;
          // AWAITED. Without this the `finally` below fired the instant the
          // route was pushed — so the refresh ran against a request that had
          // not been sent yet, and coming back from the draft screen left the
          // row still saying SEND REQUEST for someone it had just been sent
          // to. The refresh has to happen when the pushed route POPS.
          await nav.push(
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
    // Beats every other state: whatever the row is, the answer right now is
    // "a grown-up has it".
    if (_heldByGrownUp) return l10n.searchScreenActionWithGrownUp;
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
      !_heldByGrownUp &&
      widget.user.friendshipStatus != FriendshipStatus.outgoingPending;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SpringPress(
      scale: 0.98,
      haptic: false,
      semanticLabel: widget.user.displayName,
      // Also awaited: a request sent from the profile screen has to land back
      // here, for the same reason the button's own push does.
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(
              user: widget.user,
              repo: widget.repo,
              api: widget.api,
            ),
          ),
        );
        widget.onChanged();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: discoverCardDecoration(theme),
        child: Row(
          children: [
            UserAvatar(user: widget.user, size: 44, api: widget.api),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.displayName,
                    style: theme.bodyEmph.copyWith(
                      color: theme.ink,
                      fontSize: 17,
                      fontStyle: FontStyle.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '@${widget.user.username}',
                    style: groupedSubtitleStyle(theme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // The App Store "Get" capsule — THE inline row pill: filled when
            // it does something new, quiet when it undoes something, greyed
            // when a grown-up holds it; its own spinner while it works.
            RowPillButton(
              label: _actionLabel(),
              filled: _filled,
              busy: _busy,
              onTap: _heldByGrownUp ? null : _act,
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
