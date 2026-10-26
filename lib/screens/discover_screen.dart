import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import 'navigation/scroll_memory.dart';
import '../data/ui_selection_store.dart';
import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/filter_capsule.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/discover_rows.dart';
import '../widgets/request_cards.dart';
import '../widgets/search_field.dart';
import '../widgets/tab_root_bar.dart';
import 'discover_lists.dart';
import 'navigation/destinations.dart';
import 'join_by_invite_screen.dart';
import 'navigation/open_room.dart';
import 'navigation/tab_reselect.dart';
import 'search_screen.dart';

import '../widgets/ios_kit.dart';
import '../widgets/sunlit_surface.dart' show SunlitBackdrop;
import '../l10n/text_case.dart';

/// How many friends and rooms Discover shows before handing off to a
/// full-list screen.
///
/// Both lists can run to dozens, and a page whose height depends on them means
/// scrolling past one world to find out the other exists. Three rather than
/// five because everything in the people world stacks up above the rooms one —
/// two rows saved here is ~130pt less to scroll past.
const int _previewCount = 3;

/// The page's vertical rhythm, as two steps rather than a scatter of one-off
/// gaps.
///
/// Sections used to be divided only by ad-hoc SizedBoxes of 12, 14, 16 and 18 —
/// so the space *between* two sections was barely larger than the space *inside*
/// one, and an empty section ran straight into the next heading with nothing to
/// say where one stopped. 32 between sections is the gap every tab root keeps
/// (Feed, Settings), so the three tabs scroll with one rhythm; the 10 from a
/// heading to its body is [PageSectionHeader]'s own. (A third, 44pt step
/// between the two worlds went with the worlds' band labels: the jump chips
/// name them now, and a section is a section.)
const double _withinSection = 12;
const double _betweenSections = 32;

/// Request cards with [_withinSection] *between* them and none after the last.
/// The cards used to carry a 12pt bottom margin each, so the last one pushed
/// the next heading 44pt away instead of [_betweenSections].
List<Widget> _spaced(List<Widget> cards) => [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(height: _withinSection),
        cards[i],
      ],
    ];

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
    with TabReselectScroll<DiscoverScreen> {
  // Not a plain ScrollController: this section's State is destroyed on
  // every tab switch, and the framework's own PageStorage restore is what
  // produced the settle-bounce on return. See [ScrollMemory].
  final _scroll = ScrollMemory.controller();

  @override
  HomeSection get reselectSection => HomeSection.discover;
  @override
  ScrollController get reselectScroll => _scroll;

  _RequestsTab _requestsTab = _RequestsTab.incoming;

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
    // A friend-request notification tapped before this screen existed is still
    // waiting in the store — including on a cold start, where the tap lands
    // long before any widget mounts.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumePendingRequests(),
    );
    // …and the same request arriving while this screen is ALREADY on it. The
    // post-frame callback above only fires on mount, and steering the shell to
    // a section it is already showing remounts nothing — so a request tapped by
    // somebody who happened to be looking at Discover would have set the
    // one-shot and then had nobody left to consume it. See FeedScreen's
    // matching fix for the games nudge.
    UiSelectionStore.instance.addListener(_consumePendingRequests);
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onChange);
    widget.family.removeListener(_onChange);
    UiSelectionStore.instance.removeListener(_consumePendingRequests);
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
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

  /// Opens the search screen for [mode], flying the bar out of its door.
  ///
  /// Only the doors open it now (See all goes to the full lists), so the
  /// screen always has a pill on this route to fly out of.
  void _openSearch(SearchMode mode) {
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
          heroTag: searchFieldHeroTagFor(mode),
        ),
        // A fade, never a slide: the bar flies to its place on this route,
        // and a hero whose destination moves re-aims every frame, which
        // read as a shake on landing. The results bring their own rise.
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim.drive(CurveTween(curve: theme.motionEntrance)),
          child: child,
        ),
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

  // Every tile in the rooms world's own list is a room you're already in, so
  // opening one is never the join flow — just walk in.
  void _openMyRoom(ChatRoom room) =>
      openRoom(context, roomId: room.id, repo: widget.repo, api: widget.api);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final friends = widget.repo.friends;
    final incoming = widget.repo.incomingRequests;
    final outgoing = widget.repo.outgoingRequests;
    final groupInvites = widget.repo.roomInvitations;
    // Group chats you're already in — DMs don't count here, the way a DM
    // isn't a "friend request" either; they live in the chat list, not a
    // world you go looking for people or rooms in.
    final myRooms = widget.repo.activeRooms
        .where((r) => r.isGroupChat)
        .toList(growable: false);

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
    final showJump = showPeople && showRooms;

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

    // Search doors are the cards they were in 1.3.114 ("Find people",
    // "Search rooms"), not bare search bars: a search bar directly above
    // your friends or your rooms read as a filter for that list, when it
    // searches everyone.

    final peopleWorld = <Widget>[
      // One section, both directions named on a segmented control — the shape
      // the old Friends tab used.
      //
      // Two things had to hold at once: both directions visible even at zero
      // (they used to appear only when something was pending, so the feature
      // read as missing), and not much height, since all of this stacks above
      // the rooms world on a single-column page. A segment does both — the
      // counts are always on screen, but only one list is ever rendered.
      //
      // No count on the title: the counts live on the segments, where they
      // say which direction they belong to. This heading is also the People
      // chip's anchor — the world's band label is gone, and the first section
      // of the world is where "People" lands.
      KeyedSubtree(
        key: _peopleKey,
        child: PageSectionHeader(
          t.discoverScreenRequestsSectionLabel,
          key: _incomingKey,
        ),
      ),
      if (showOutgoing) ...[
        _RequestSegments(
          active: _requestsTab,
          incoming: incoming.length + groupInvites.length,
          outgoing: outgoing.length,
          onChange: (tab) => setState(() => _requestsTab = tab),
        ),
        const SizedBox(height: _withinSection),
      ],
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
              else
                ..._spaced([
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
                ])
            else if (outgoing.isEmpty)
              DiscoverEmptyLine(t.discoverScreenNothingPending)
            else
              ..._spaced([
                for (final r in outgoing)
                  OutgoingRequestCard(
                    key: ValueKey('out_${r.user.id}'),
                    req: r,
                    repo: widget.repo,
                    api: widget.api,
                  ),
              ]),
          ],
        ),
      ),

      const SizedBox(height: _betweenSections),
      // "See all ›" lives in the heading, the one place every tab puts it —
      // it used to be a centred row under the list here and a header action
      // on Feed, two answers to one question.
      PageSectionHeader(
        t.discoverScreenYourPeopleLabel,
        count: '${friends.length}',
        actionLabel: friends.length > _previewCount ? t.pageSectionSeeAll : null,
        actionSemanticLabel: t.discoverScreenSeeAllFriendsSemanticLabel,
        onAction: () =>
            _push(PeopleListScreen(repo: widget.repo, api: widget.api)),
      ),
      if (showPeople) ...[
        // A child finds people by exact username only, and the subtitle
        // says so before they type a half-name that will never match.
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
        const SizedBox(height: _withinSection),
      ],
      // The one empty state worth a sentence: it points at the way out, which
      // a bare `0` cannot.
      if (friends.isEmpty)
        DiscoverEmptyLine(
          showPeople
              ? t.discoverScreenNoFriendsYetWithHint
              : t.discoverScreenNoFriendsYet,
        )
      else
        // One grouped block, the iOS contacts list — not a floating card
        // per person.
        GroupedSection(
          margin: EdgeInsets.zero,
          children: [
            for (final f in friends.take(_previewCount))
              FriendRow(
                key: ValueKey(f.id),
                user: f,
                api: widget.api,
                onTap: () => _openDm(f),
              ),
          ],
        ),
    ];

    // Absent, not greyed out and not empty, when a guardian hasn't unlocked
    // public rooms. A locked door still tells a child there's a room behind
    // it — so this is `null`, not an empty list, when `!showRooms`.
    final roomsWorld = !showRooms
        ? null
        : <Widget>[
            // One heading for the world, not a "Rooms" band over a "Your
            // rooms" section — that said Rooms twice. It is also the Rooms
            // chip's anchor.
            PageSectionHeader(
              t.discoverScreenYourRoomsLabel,
              key: _roomsKey,
              count: '${myRooms.length}',
              actionLabel:
                  myRooms.length > _previewCount ? t.pageSectionSeeAll : null,
              actionSemanticLabel: t.discoverScreenSeeAllRoomsSemanticLabel,
              onAction: () =>
                  _push(RoomsListScreen(repo: widget.repo, api: widget.api)),
            ),
            // Says "search public rooms", not "browse". A row promising to
            // *browse* rooms directly above a list of them read as two
            // different sets — "are these my rooms or all of them?". The hint
            // names the set it searches, so the list below stays the only list.
            _DoorRow(
              heroTag: searchFieldHeroTagFor(SearchMode.rooms),
              circular: false,
              icon: CupertinoIcons.number,
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
            GroupedSection(
              margin: EdgeInsets.zero,
              children: [
                GroupedRow(
                  icon: CupertinoIcons.lock_open_fill,
                  tone: TileTone.indigo,
                  title: t.discoverScreenJoinByCodeTitle,
                  subtitle: t.discoverScreenJoinByCodeSubtitle,
                  onTap: () => _push(
                    JoinByInviteScreen(repo: widget.repo, api: widget.api),
                  ),
                ),
              ],
            ),
            const SizedBox(height: _withinSection),
            if (myRooms.isEmpty)
              DiscoverEmptyLine(t.discoverScreenNoRoomsYet)
            else
              GroupedSection(
                margin: EdgeInsets.zero,
                children: [
                  for (final r in myRooms.take(_previewCount))
                    PublicRoomTile(
                      key: ValueKey(r.id),
                      room: r,
                      api: widget.api,
                      joined: true,
                      onTap: () => _openMyRoom(r),
                    ),
                ],
              ),
          ];

    // The same large title the chat list wears, at the same height: the
    // list starts below the floating bar and the title sits 6pt under it.
    // The caption line that used to sit under it (an accent tick and a
    // mono "people · rooms · requests") restated the sections below; the
    // page now names itself and lets them speak.
    final header = <Widget>[
      const SizedBox(height: 6),
      Semantics(
        header: true,
        label: caption,
        child: Text(
          t.destinationsDiscoverLabel,
          style: theme.displayLarge.copyWith(letterSpacing: 0.37),
        ),
      ),
      // One tap to either world, on the single-column page only — a two-column
      // page has nowhere for either chip to jump TO that isn't already on
      // screen.
      if (showJump && !twoColumns) ...[
        const SizedBox(height: 12),
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
              TabRootBar.clearance(context),
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
                    const SizedBox(height: _betweenSections),
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
                TabRootBar.clearance(context),
                20,
                sectionBottomPadding(context),
              ),
              children: [
                ...header,
                const SizedBox(height: _betweenSections),
                ...peopleWorld,
                if (roomsWorld != null) ...[
                  const SizedBox(height: _betweenSections),
                  ...roomsWorld,
                ],
              ],
            ),
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const SunlitBackdrop(),
          // See home_screen: the default bottom inset leaves a dead strip of
          // background under the scroller. `sectionBottomPadding` clears the
          // pill and the indicator instead. Edge to edge: the bar clears the
          // status bar, and the top inset is spent so a nested shrink-wrapped
          // list does not pick it up again.
          MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: body,
          ),
          TabRootBar(
            title: t.destinationsDiscoverLabel,
            scroll: _scroll,
          ),
        ],
      ),
    );
  }
}

/// Incoming / outgoing switch for the requests section — an iOS segmented
/// control, so it reads as a control and not as a heading. Both counts stay
/// on screen whichever side is selected.
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

  void _select(_RequestsTab tab) {
    if (tab != active) HapticFeedback.selectionClick();
    onChange(tab);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // The shared segmented control: both counts stay on screen so "have I
    // got any?" is answered without a tap.
    String seg(String label, int count) =>
        '${sentenceCaseOf(context, label)}  $count';
    return IosSegmentedControl<_RequestsTab>(
      value: active,
      onChanged: _select,
      segments: [
        IosSegment(
          value: _RequestsTab.incoming,
          label: seg(t.discoverScreenIncomingLabel, incoming),
          semanticLabel: '${t.discoverScreenIncomingLabel}, $incoming',
        ),
        IosSegment(
          value: _RequestsTab.outgoing,
          label: seg(t.discoverScreenOutgoingLabel, outgoing),
          semanticLabel: '${t.discoverScreenOutgoingLabel}, $outgoing',
        ),
      ],
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
        _jumpChip(
          context,
          label: t.discoverScreenJumpPeopleLabel,
          icon: CupertinoIcons.person_2,
          onTap: onPeople,
        ),
        const SizedBox(width: 8),
        _jumpChip(
          context,
          label: t.discoverScreenJumpRoomsLabel,
          icon: CupertinoIcons.number,
          onTap: onRooms,
        ),
      ],
    );
  }
}

/// One of [_WorldJump]'s two capsules: the shared [FilterCapsule], never
/// active — it scrolls, it doesn't filter — with the world's glyph leading.
Widget _jumpChip(
  BuildContext context, {
  required String label,
  required IconData icon,
  required VoidCallback onTap,
}) {
  final theme = ThemeScope.of(context);
  return FilterCapsule(
    label: sentenceCaseOf(context, label),
    active: false,
    leading: Icon(icon, size: 15, color: theme.inkSoft),
    semanticLabel: AppLocalizations.of(
      context,
    ).discoverScreenJumpToSemanticLabel(label),
    onTap: onTap,
  );
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
/// every frame of the flight. [SearchFieldHero] morphs the box from this
/// card's corners to the pill's, and fades the card out at its own size.
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
    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: PressSpec.scaleSmall,
      semanticLabel: '$title. $subtitle',
      focusRadius: groupedRadius(theme),
      child: _maybeHero(
          theme,
          // A grouped iOS row: a coloured tile, the title, one line of what
          // it finds, and the magnifier the search bar shares mid-flight.
          child: GroupedCard(
            padding: const EdgeInsets.symmetric(
              horizontal: searchDoorHPadding,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tileColor(
                      theme,
                      circular ? TileTone.blue : TileTone.indigo,
                    ),
                    shape: circular ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius:
                        circular ? null : BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sentenceCaseOf(context, title),
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
                        sentenceCaseOf(context, subtitle),
                        // Body face, never the theme's caption (tracked mono
                        // on the character themes).
                        style: groupedSubtitleStyle(theme),
                        // Two lines, like an iOS subtitle cell: "Open a group
                        // someone shared with you" truncated at one even in
                        // English at 1×.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // For a search door, the glyph the flight shuttle carries
                // into the search bar — same size at both ends. A door that
                // opens an ordinary screen gets a chevron instead.
                Icon(
                  heroTag == null
                      ? CupertinoIcons.chevron_forward
                      : CupertinoIcons.search,
                  size: searchFieldIconSize,
                  color: theme.inkMuted,
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _maybeHero(AppTheme theme, {required Widget child}) {
    final tag = heroTag;
    if (tag == null) return child;
    return SearchFieldHero(
      tag: tag,
      radius: groupedRadius(theme),
      child: child,
    );
  }
}
