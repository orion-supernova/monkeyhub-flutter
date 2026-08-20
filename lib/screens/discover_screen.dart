import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import 'navigation/scroll_memory.dart';
import '../data/ui_selection_store.dart';
import '../family/family_service.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/discover_rows.dart';
import '../widgets/request_cards.dart';
import '../widgets/search_field.dart';
import 'discover_lists.dart';
import 'navigation/destinations.dart';
import 'join_by_invite_screen.dart';
import 'navigation/enter_public_room.dart';
import 'navigation/open_room.dart';
import 'navigation/route_return.dart';
import 'navigation/tab_reselect.dart';
import 'search_screen.dart';

/// How many friends and public rooms Discover shows before handing off to a
/// full-list screen.
///
/// Both lists can run to dozens, and a page whose height depends on them means
/// scrolling past one world to find out the other exists. Three rather than
/// five because everything in the people world stacks up above the rooms one —
/// two rows saved here is ~130pt less to scroll past.
const int _previewCount = 3;

/// The page's vertical rhythm, as three steps rather than a scatter of one-off
/// gaps.
///
/// Sections used to be divided only by ad-hoc SizedBoxes of 12, 14, 16 and 18 —
/// so the space *between* two sections was barely larger than the space *inside*
/// one, and an empty section ran straight into the next heading with nothing to
/// say where one stopped. Each step is roughly double the last, which is what
/// makes the grouping legible without drawing a single extra line.
const double _withinSection = 12;
const double _betweenSections = 30;
const double _betweenWorlds = 44;

/// Everything you go looking for, grouped into two worlds.
///
/// The page reads top to bottom as PEOPLE then ROOMS, and everything belonging
/// to a world sits inside it — search door, requests, and the list. An earlier
/// arrangement banded only the search doors and then let the content sections
/// alternate underneath, so the screen went people → rooms → people → rooms.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.repo,
    required this.api,
    required this.family,
  });
  final ChatRepository repo;
  final ChatApi api;
  final FamilyService family;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

/// Which half of the requests section is showing.
enum _RequestsTab { incoming, outgoing }

class _DiscoverScreenState extends State<DiscoverScreen>
    with TabReselectScroll<DiscoverScreen>, RefreshOnReturn<DiscoverScreen> {
  // Not a plain ScrollController: this section's State is destroyed on
  // every tab switch, and the framework's own PageStorage restore is what
  // produced the settle-bounce on return. See [ScrollMemory].
  final _scroll = ScrollMemory.controller();

  @override
  HomeSection get reselectSection => HomeSection.discover;
  @override
  ScrollController get reselectScroll => _scroll;

  /// Re-fetches the public list whenever a pushed route pops back to Discover.
  ///
  /// [_refresh] is a one-shot query, not a subscription, and it ran in
  /// `initState` only. Tapping a room pushes on top of this screen without
  /// disposing it, so everything the user did in there was invisible on the way
  /// back: set a room to private and Discover kept listing it publicly until
  /// the section was switched away and back, which is what made this look
  /// intermittent rather than broken.
  ///
  /// A room's own membership and privacy still arrive live through
  /// [ChatRepository]; it is the *public directory* that has no live query, by
  /// the same budget argument that keeps the Feed board down to one.
  @override
  void onReturnToScreen() => _refresh();

  /// The last public-room list Discover drew, and whose it was.
  ///
  /// Switching sections destroys this screen's [State] outright, so a return to
  /// Discover used to start with an empty list and paint one quiet "looking for
  /// rooms" line where five tiles had been — several hundred points shorter. The
  /// [ListView] restores its saved scroll offset into that shorter page, the
  /// offset is now past the end of it, and the scroll position glides back to
  /// the new bottom: open Discover while scrolled down and it scrolls itself
  /// upwards for no reason the user can see. Repainting the rooms we already had
  /// keeps the page the height its offset was measured against; the refresh
  /// still runs underneath and replaces them.
  ///
  /// Keyed by user because a public list is viewer-dependent — the backend
  /// blanks it for a child who isn't allowed public rooms — and an app instance
  /// can change hands without restarting.
  static List<ChatRoom> _lastRooms = const [];
  static String? _lastRoomsFor;

  late List<ChatRoom> _rooms = _lastRoomsFor == widget.repo.userId
      ? _lastRooms
      : const [];
  bool _loading = false;

  _RequestsTab _requestsTab = _RequestsTab.incoming;

  /// Rooms this child has already asked about, so their tiles read
  /// "waiting for a grown-up" instead of inviting a second request.
  Set<String> _awaiting = {};

  /// Last known value of [_roomsUnlocked], so a guardian unlocking public rooms
  /// mid-session can trigger the fetch that `initState` skipped.
  bool _wasUnlocked = false;

  /// Anchors the scroll a friend-request notification asks for.
  final _incomingKey = GlobalKey();

  /// Anchors for the world jump control.
  final _peopleKey = GlobalKey();
  final _roomsKey = GlobalKey();

  void _jumpTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: ThemeScope.of(context).motionMed,
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  /// Whether the public-rooms world may render.
  ///
  /// Gated on `hasContext` as well as the account type. [FamilyContext.empty]
  /// reads as an unrestricted adult until the family subscription lands, and
  /// Discover is off for every child — so without this a child gets a
  /// fully-composed ROOMS world on every cold start, which then vanishes. That
  /// flash is new: when Discover was a tab it simply never appeared for those
  /// accounts.
  bool get _roomsUnlocked =>
      widget.family.hasContext && widget.family.canSeePublicRooms;

  /// Whether people search may render. Left failing open, matching the rest of
  /// the app: it is the less sensitive capability, and gating it on context too
  /// would reflow the top of the screen on every launch.
  bool get _peopleUnlocked => widget.family.canRequestContacts;

  @override
  void initState() {
    super.initState();
    ScrollMemory.attach('discover', _scroll);
    widget.repo.addListener(_onChange);
    widget.family.addListener(_onChange);
    _wasUnlocked = _roomsUnlocked;
    // A friend-request notification tapped before this screen existed is still
    // waiting in the store — including on a cold start, where the tap lands
    // long before any widget mounts.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumePendingRequests(),
    );
    _refresh();
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onChange);
    widget.family.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    // Rising edge: the fetch is skipped while locked, so without this an
    // unlocked child would land on a fully-rendered rooms world reading
    // "nothing open right now" — a lie, at the one moment they are most likely
    // to look.
    final unlocked = _roomsUnlocked;
    if (unlocked && !_wasUnlocked && _rooms.isEmpty) _refresh();
    _wasUnlocked = unlocked;
    setState(() {});
  }

  /// The requests lists live on this page now, so a notification tap scrolls to
  /// them rather than pushing a screen on top of the one that already shows
  /// them.
  void _consumePendingRequests() {
    if (!mounted) return;
    if (!UiSelectionStore.instance.consumeRequestsView()) return;
    // A friend-request push is always about something arriving, so land on the
    // incoming half whatever was last selected.
    setState(() => _requestsTab = _RequestsTab.incoming);
    final ctx = _incomingKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: ThemeScope.of(context).motionMed,
      curve: Curves.easeOutCubic,
      alignment: 0.1,
    );
  }

  Future<void> _refresh() async {
    // Nothing to fetch while locked, and asking anyway would spend a round trip
    // on a response the backend blanks by design.
    if (!_roomsUnlocked) return;
    setState(() => _loading = true);
    try {
      // Passing the viewer lets the backend blank this list for a child who
      // isn't allowed public rooms — belt and braces with hiding the section.
      final rs = await widget.api.listPublic(viewerUserId: widget.repo.userId);
      _lastRooms = rs;
      _lastRoomsFor = widget.repo.userId;
      if (!mounted) return;
      setState(() => _rooms = rs);
      if (widget.family.isChild) await _refreshAwaiting();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAwaiting() async {
    final uid = widget.repo.userId;
    if (uid == null) return;
    try {
      final pending = await widget.api.listMyApprovals(uid);
      if (!mounted) return;
      setState(
        () => _awaiting = pending
            .where((p) => p.roomId != null)
            .map((p) => p.roomId!)
            .toSet(),
      );
    } catch (_) {
      /* tiles just won't show the pill */
    }
  }

  /// Opens the search screen for [mode].
  ///
  /// [fromDoor] is what tells the screen whether it has a box to fly out of.
  /// The doors do; SEE ALL — which opens the same screen from the bottom of the
  /// rooms list — does not, and letting it claim the door's tag anyway would
  /// fly the bar out of a card that is usually scrolled off the top by then.
  void _openSearch(SearchMode mode, {bool fromDoor = true}) {
    final theme = ThemeScope.of(context);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: theme.motionMed,
        reverseTransitionDuration: theme.motionMed,
        pageBuilder: (_, _, _) => SearchScreen(
          repo: widget.repo,
          api: widget.api,
          family: widget.family,
          mode: mode,
          heroTag: fromDoor ? searchFieldHeroTagFor(mode) : null,
        ),
        transitionsBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: theme.motionEntrance,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openDm(ChatUser user) async {
    try {
      final roomId = await widget.repo.openDmWith(user);
      if (!mounted) return;
      openRoom(context, roomId: roomId, repo: widget.repo, api: widget.api);
    } catch (_) {}
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _onTapRoom(ChatRoom room) {
    enterPublicRoom(
      context,
      room: room,
      repo: widget.repo,
      api: widget.api,
      family: widget.family,
      alreadyAsked: _awaiting.contains(room.id),
      onAsked: (id) {
        if (mounted) setState(() => _awaiting = {..._awaiting, id});
      },
      onChildGateRefused: _refreshAwaiting,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final friends = widget.repo.friends;
    final incoming = widget.repo.incomingRequests;
    final outgoing = widget.repo.outgoingRequests;
    final groupInvites = widget.repo.roomInvitations;

    final showPeople = _peopleUnlocked;
    final showRooms = _roomsUnlocked;
    // An outgoing section on an account that can never send one names a
    // capability it does not have. It stays for a child whose permission was
    // revoked with a request still in flight.
    final showOutgoing = _peopleUnlocked || outgoing.isNotEmpty;
    final t = AppLocalizations.of(context);
    // One derivation, read everywhere below. The caption used to be the literal
    // string 'people · rooms · requests' regardless of account, which told a
    // child with public rooms locked that public rooms exist.
    final caption = <String>[
      if (showPeople) t.discoverScreenCaptionPeople,
      if (showRooms) t.discoverScreenCaptionRooms,
      t.discoverScreenCaptionRequests,
    ].join(' · ');
    final showBands = showPeople && showRooms;

    // Expanded windows lay PEOPLE and ROOMS out as two side-by-side columns
    // instead of stacking them — the whole reason the single-column page needs
    // a jump control and a "PINNED... nope, PEOPLE... nope, ROOMS" scroll is
    // that a phone (or a phone-width column parked in the middle of a desktop
    // window) can't show both worlds at once. A wide window can, so on
    // `isExpanded` it does, and the jump chips (nothing left to jump to) and
    // the vertical gap between worlds (nothing left to separate) both drop
    // out. Single-world accounts (rooms locked) still get one full-width
    // column either way — there's no second world to put beside it.
    final twoColumns = context.isExpanded && showRooms;

    final peopleWorld = <Widget>[
      if (showBands) _BandLabel(t.discoverScreenPeopleBandLabel, key: _peopleKey),
      if (showPeople) ...[
        _DoorRow(
          heroTag: searchFieldHeroTagFor(SearchMode.people),
          circular: true,
          icon: CupertinoIcons.person_2,
          title: t.discoverScreenFindPeopleTitle,
          subtitle: widget.family.isChild
              ? t.discoverScreenFindPeopleSubtitleChild
              : t.discoverScreenFindPeopleSubtitleAdult,
          onTap: () => _openSearch(SearchMode.people),
        ),
        const SizedBox(height: _betweenSections),
      ],

      // One section, both directions named on a segmented control — the shape
      // the old Friends tab used.
      //
      // Two things had to hold at once: both directions visible even at zero
      // (they used to appear only when something was pending, so the feature
      // read as missing), and not much height, since all of this stacks above
      // the rooms world on a single-column page. A segment does both — the
      // counts are always on screen, but only one list is ever rendered.
      DiscoverSectionHeader(
        key: _incomingKey,
        label: t.discoverScreenRequestsSectionLabel,
        // The counts live on the segments, where they say which direction
        // they belong to.
        count: '',
      ),
      if (showOutgoing) ...[
        const SizedBox(height: 10),
        _RequestSegments(
          active: _requestsTab,
          incoming: incoming.length + groupInvites.length,
          outgoing: outgoing.length,
          onChange: (tab) => setState(() => _requestsTab = tab),
        ),
      ],
      const SizedBox(height: _withinSection),
      AnimatedSize(
        duration: theme.motionMed,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // With no outgoing half there is nothing to switch between, so
            // the incoming list stands alone.
            if (!showOutgoing || _requestsTab == _RequestsTab.incoming)
              // Group invites share the incoming list rather than getting a
              // section of their own. They are the same question — somebody is
              // proposing to connect you to something and you decide — and a
              // separate section would be a second inbox to remember to check.
              // Invites first: they expire in practice (an admin rotates the
              // link, the group fills up) where a friend request does not.
              if (incoming.isEmpty && groupInvites.isEmpty)
                DiscoverEmptyLine(t.discoverScreenInboxQuiet)
              else ...[
                for (final inv in groupInvites)
                  RoomInvitationCard(
                    key: ValueKey('roominv_${inv.invitationId}'),
                    invitation: inv,
                    repo: widget.repo,
                    api: widget.api,
                  ),
                for (final r in incoming)
                  IncomingRequestCard(
                    key: ValueKey('in_${r.user.id}'),
                    req: r,
                    repo: widget.repo,
                    api: widget.api,
                  ),
              ]
            else if (outgoing.isEmpty)
              DiscoverEmptyLine(t.discoverScreenNothingPending)
            else
              for (final r in outgoing)
                OutgoingRequestCard(
                  key: ValueKey('out_${r.user.id}'),
                  req: r,
                  repo: widget.repo,
                  api: widget.api,
                ),
          ],
        ),
      ),

      const SizedBox(height: _betweenSections),
      DiscoverSectionHeader(
        label: t.discoverScreenYourPeopleLabel,
        count: '${friends.length}',
      ),
      // The one empty state worth a sentence: it points at the way out, which
      // a bare `0` cannot.
      if (friends.isEmpty)
        DiscoverEmptyLine(
          showPeople
              ? t.discoverScreenNoFriendsYetWithHint
              : t.discoverScreenNoFriendsYet,
        )
      else ...[
        const SizedBox(height: _withinSection),
        for (final f in friends.take(_previewCount))
          FriendRow(
            key: ValueKey(f.id),
            user: f,
            api: widget.api,
            onTap: () => _openDm(f),
          ),
        if (friends.length > _previewCount)
          SeeAllRow(
            total: friends.length,
            onTap: () => _push(
              PeopleListScreen(repo: widget.repo, api: widget.api),
            ),
          ),
      ],
    ];

    // Absent, not greyed out and not empty, when a guardian hasn't unlocked
    // public rooms. A locked door still tells a child there's a room behind
    // it — so this is `null`, not an empty list, when `!showRooms`.
    final roomsWorld = !showRooms
        ? null
        : <Widget>[
            if (showBands)
              _BandLabel(t.discoverScreenRoomsBandLabel, key: _roomsKey),
            // Says "search", not "browse". Rooms are listable, so a row
            // promising to *browse* them sitting directly above a list of them
            // read as two different sets — the question it prompted was "are
            // these my rooms or all of them?". Naming the row for the one
            // thing it does (search) leaves the section below as the only
            // list, and mirrors the people door exactly: search entry, then
            // your own list.
            _DoorRow(
              heroTag: searchFieldHeroTagFor(SearchMode.rooms),
              circular: false,
              icon: Icons.tag,
              title: t.discoverScreenSearchRoomsTitle,
              subtitle: t.discoverScreenSearchRoomsSubtitle,
              onTap: () => _openSearch(SearchMode.rooms),
            ),
            const SizedBox(height: _withinSection),
            // The typed half of the invite token. Its other half is the link,
            // which arrives through the OS and never touches this screen — but
            // a code read off somebody's screen or over a call has to land
            // somewhere, and next to the room search is where a person looks
            // for a room they cannot find by searching. Private rooms are not
            // listed anywhere by design, so for those this row and a tapped
            // link are the only two doors that exist.
            _DoorRow(
              circular: false,
              icon: Icons.vpn_key_outlined,
              title: t.discoverScreenJoinByCodeTitle,
              subtitle: t.discoverScreenJoinByCodeSubtitle,
              onTap: () => _push(
                JoinByInviteScreen(repo: widget.repo, api: widget.api),
              ),
            ),
            const SizedBox(height: _betweenSections),
            DiscoverSectionHeader(
              label: t.discoverScreenPublicRoomsLabel,
              // Blank while the first fetch is in flight so a `0` only ever
              // means "looked, found nothing".
              count: _loading && _rooms.isEmpty ? '' : '${_rooms.length}',
            ),
            const SizedBox(height: _withinSection),
            if (_loading && _rooms.isEmpty)
              DiscoverEmptyLine(t.discoverScreenLoadingRooms)
            else if (_rooms.isEmpty)
              DiscoverEmptyLine(t.discoverScreenNoRoomsOpen)
            else
              // Rebuilds on every repo change so a tile flips to JOINED the
              // moment the rooms subscription delivers the new membership —
              // including when the join happened elsewhere entirely (a push
              // tap, another device).
              ListenableBuilder(
                listenable: widget.repo,
                builder: (context, _) => Column(
                  children: [
                    for (final r in _rooms.take(_previewCount))
                      PublicRoomTile(
                        key: ValueKey(r.id),
                        room: r,
                        api: widget.api,
                        awaiting: _awaiting.contains(r.id),
                        joined: widget.repo.isJoined(r),
                        onTap: () => _onTapRoom(r),
                      ),
                    if (_rooms.length > _previewCount)
                      SeeAllRow(
                        total: _rooms.length,
                        // The search screen with an empty query IS the full
                        // list, so there's no second full-rooms screen to
                        // maintain.
                        onTap: () =>
                            _openSearch(SearchMode.rooms, fromDoor: false),
                      ),
                  ],
                ),
              ),
          ];

    final header = <Widget>[
      Text(t.discoverScreenTitle, style: theme.displayMedium),
      const SizedBox(height: 10),
      Row(
        children: [
          Container(width: 18, height: 1, color: theme.accent),
          const SizedBox(width: 8),
          Text(caption, style: theme.caption),
        ],
      ),
      // One tap to either world, on the single-column page only — a two-column
      // page has nowhere for either chip to jump TO that isn't already on
      // screen.
      if (showBands && !twoColumns) ...[
        const SizedBox(height: 18),
        _WorldJump(
          onPeople: () => _jumpTo(_peopleKey),
          onRooms: () => _jumpTo(_roomsKey),
        ),
      ],
    ];

    final Widget body = twoColumns
        ? SingleChildScrollView(
            key: const PageStorageKey('discover_main_list_v3_wide'),
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              sectionBottomPadding(context),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ContentWidth.wide),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...header,
                    const SizedBox(height: 24),
                    // `Expanded`, not a fixed width centred as a pair — the
                    // header above spans the full column edge to edge, and a
                    // narrower, centred pair of lists left People starting
                    // well right of where PEOPLE·ROOMS·REQUESTS did, with a
                    // gutter neither the title nor anything else on the page
                    // has. People's left edge belongs under the title's;
                    // Rooms' right edge belongs at the column's.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: peopleWorld,
                          ),
                        ),
                        const SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: roomsWorld!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        : AdaptivePageBody(
            child: ListView(
              // Bumped whenever the section order changes; the old key would
              // restore a scroll offset measured against a different page.
              key: const PageStorageKey('discover_main_list_v3'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                sectionBottomPadding(context),
              ),
              children: [
                ...header,
                const SizedBox(height: 24),
                ...peopleWorld,
                if (roomsWorld != null) ...[
                  const SizedBox(height: _betweenWorlds),
                  ...roomsWorld,
                ],
              ],
            ),
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // See home_screen: the default bottom inset leaves a dead strip of
          // background under the scroller. `sectionBottomPadding` clears the
          // pill and the indicator instead.
          SafeArea(bottom: false, child: body),
        ],
      ),
    );
  }
}

/// Names a world. Deliberately plainer than the page caption above it, which
/// carries the accent tick — two identical tick+mono rows 20pt apart would read
/// as one repeated element rather than two levels of hierarchy.
class _BandLabel extends StatelessWidget {
  const _BandLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(text, style: theme.label.copyWith(color: theme.inkMuted)),
    );
  }
}

/// Incoming / outgoing switch for the requests section.
///
/// Deliberately not [PillNav]. Its items draw `theme.label` — the same token
/// [DiscoverSectionHeader] uses for a title — so two filled, badged pills sat
/// under "REQUESTS" carrying more weight than the heading they belong to.
///
/// This sits a tier below instead: `monoTiny`, muted until selected, marked by
/// an accent underline rather than a fill, and left-aligned to the section's
/// own text column so it reads as part of the section rather than a control in
/// its own right. The underline is text-width via [IntrinsicWidth], so it
/// tracks the label at any text scale.
class _RequestSegments extends StatelessWidget {
  const _RequestSegments({
    required this.active,
    required this.incoming,
    required this.outgoing,
    required this.onChange,
  });
  final _RequestsTab active;
  final int incoming;
  final int outgoing;
  final ValueChanged<_RequestsTab> onChange;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        _Segment(
          label: t.discoverScreenIncomingLabel,
          displayLabel: t.discoverScreenIncomingLabelCaps,
          count: incoming,
          active: active == _RequestsTab.incoming,
          onTap: () => onChange(_RequestsTab.incoming),
        ),
        const SizedBox(width: 20),
        _Segment(
          label: t.discoverScreenOutgoingLabel,
          displayLabel: t.discoverScreenOutgoingLabelCaps,
          count: outgoing,
          active: active == _RequestsTab.outgoing,
          onTap: () => onChange(_RequestsTab.outgoing),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.displayLabel,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final String label;
  // Pre-cased for display rather than derived from [label] via
  // `.toUpperCase()` at build time: Dart's default case mapping is not
  // locale-aware, so it would turn a Turkish "giden" into "GIDEN" (dotless
  // I) instead of the correct "GİDEN" (dotted İ).
  final String displayLabel;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      // The count is spoken as well as drawn: "incoming, 0" is the answer to
      // "have I got any?", which is the whole reason both segments stay on
      // screen when nothing is pending.
      semanticLabel: '$label, $count',
      selected: active,
      radius: theme.radiusSm,
      inset: 4,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedDefaultTextStyle(
                duration: theme.motionFast,
                curve: Curves.easeOutCubic,
                style: theme.monoTiny.copyWith(
                  color: active ? theme.ink : theme.inkMuted,
                ),
                child: Text('$displayLabel · $count'),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: theme.motionFast,
                curve: Curves.easeOutCubic,
                height: 1.5,
                color: active ? theme.accent : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jumps straight to either world.
///
/// Not a tab bar — both worlds stay on one page and stay scrollable end to
/// end; this only saves you the swiping. Nothing is hidden behind it, so it
/// doesn't reintroduce the navigation layer this screen exists to remove.
class _WorldJump extends StatelessWidget {
  const _WorldJump({required this.onPeople, required this.onRooms});
  final VoidCallback onPeople;
  final VoidCallback onRooms;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        _JumpChip(
          label: t.discoverScreenJumpPeopleLabel,
          icon: CupertinoIcons.person_2,
          onTap: onPeople,
        ),
        const SizedBox(width: 8),
        _JumpChip(
          label: t.discoverScreenJumpRoomsLabel,
          icon: Icons.tag,
          onTap: onRooms,
        ),
      ],
    );
  }
}

class _JumpChip extends StatelessWidget {
  const _JumpChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: AppLocalizations.of(
        context,
      ).discoverScreenJumpToSemanticLabel(label),
      shape: FocusRingShape.capsule,
      radius: 999,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: theme.chipDecoration(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: theme.accent),
              const SizedBox(width: 7),
              Text(label, style: theme.label.copyWith(color: theme.accent)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A way into a world: glyph, title, one line of explanation, search icon.
///
/// The glyph is a circle for people and a rounded square for rooms — the same
/// distinction the app already draws between a round [UserAvatar] and a room
/// tile's chip, so the two worlds stay apart at a glance.
///
/// The card flies into the search screen's bar via [SearchFieldHero].
///
/// A plain [Hero] between the two was tried and reverted once, and the reason
/// is worth keeping: its default shuttle draws the *destination's* child at
/// every intermediate size, so this card's own two lines of text were being
/// asked to fit a box collapsing toward a one-line field, and overflowed on
/// every frame of the flight. [SearchFieldHero] flies the box and the
/// magnifier — the two things both ends actually have — and nothing that can
/// overflow.
class _DoorRow extends StatelessWidget {
  const _DoorRow({
    this.heroTag,
    required this.circular,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  /// The search field this door flies into, when it opens one.
  ///
  /// Null for a door that opens an ordinary screen instead — the join-by-code
  /// row. A Hero with no counterpart on the incoming route does not degrade
  /// gracefully; it animates into nothing, which reads as the row falling
  /// apart mid-transition.
  final Object? heroTag;
  final bool circular;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      radius: theme.radiusLg,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: _maybeHero(
          child: Container(
            decoration: theme.inputDecoration(),
            padding: const EdgeInsets.symmetric(
              horizontal: searchDoorHPadding,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.accentSoft,
                    shape: circular ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: circular
                        ? null
                        : BorderRadius.circular(theme.radiusMd),
                  ),
                  child: Icon(icon, size: 15, color: theme.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.displaySmall.copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.monoTiny,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // The one glyph the door and the bar share, and the one the
                // flight shuttle carries between them — same size at both ends
                // so it never resizes mid-air.
                // The door's trailing glyph. For a search door it is the one
                // the flight shuttle carries into the search bar — same size
                // at both ends so it never resizes mid-air. A door that opens
                // an ordinary screen gets a chevron instead, because a
                // magnifier there promises a search that is not coming.
                Icon(
                  heroTag == null ? Icons.chevron_right : Icons.search,
                  size: searchFieldIconSize,
                  color: theme.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _maybeHero({required Widget child}) {
    final tag = heroTag;
    if (tag == null) return child;
    return SearchFieldHero(tag: tag, child: child);
  }
}
