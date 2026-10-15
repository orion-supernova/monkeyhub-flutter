import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../companions/companion.dart';
import '../companions/sebastian.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/image_raster.dart';
import '../media/upload_service.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../auth/auth_errors.dart';
import '../invites/room_admin_errors.dart';
import '../calls/call_models.dart';
import '../calls/call_service.dart';
import '../models/room_admin.dart';
import '../models/room_capabilities.dart';
import '../models/room_content_item.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart';
import '../widgets/app_toast.dart';
import '../widgets/chat_list_row.dart' show MonogramAvatar;
import '../widgets/companion_install_sheet.dart';
import '../widgets/editable_info_row.dart';
import '../widgets/ios_kit.dart';
import '../widgets/report_sheet.dart';
import '../widgets/sheet_kit.dart';
import '../widgets/mute_room_sheet.dart';
import '../widgets/password_field.dart';
import '../widgets/photo_chrome.dart';
import '../widgets/remote_image.dart';
import '../widgets/room_invite_friends_sheet.dart';
import '../widgets/room_invite_sheet.dart';
import '../widgets/skeleton_rows.dart';
import '../widgets/room_change_requests_sheet.dart';
import '../widgets/room_join_requests_sheet.dart';
import '../widgets/room_member_actions_sheet.dart';
import '../widgets/steady_hero.dart';
import '../theme/speaker_colors.dart';
import '../widgets/user_avatar.dart';
import 'room_colors_screen.dart';
import '../widgets/destructive_sheet.dart';
import 'fullscreen_image_viewer.dart';
import 'image_crop_screen.dart';
import 'navigation/open_room.dart';
import 'profile_screen.dart';
import 'room_content_screen.dart';
import '../l10n/text_case.dart';
import '../backend/server_limits.dart';

class RoomInfoScreen extends StatefulWidget {
  const RoomInfoScreen({
    super.key,
    required this.roomId,
    required this.repo,
    required this.api,
    this.openChangeRequests = false,
  });
  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

  /// Open the suggested-changes queue as soon as the screen has one to show.
  ///
  /// Set only by the notification tap (`app.dart` → `RoomScreen`), which is
  /// what makes "somebody suggested a new group photo" land on approve/reject
  /// rather than in the transcript with no sign of why. Ignored for anybody
  /// who cannot review — an old build, a demoted admin, or a member who
  /// somehow received the push — because a sheet that would refuse them is a
  /// worse landing than the room itself.
  final bool openChangeRequests;

  @override
  State<RoomInfoScreen> createState() => _RoomInfoScreenState();
}

class _RoomInfoScreenState extends State<RoomInfoScreen> {
  static const _ttlOptions = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(hours: 1),
  ];

  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _newPassword = TextEditingController();

  bool _isPrivate = true;
  Duration? _ttl;
  bool _loaded = false;

  /// Whether the password field currently holds anything, tracked so the SET
  /// button can enable without rebuilding on every keystroke.
  bool _passwordHasText = false;

  /// Whether the password block is expanded. Collapsed by default — see the
  /// note at its call site.
  bool _passwordOpen = false;

  /// A blocking write is in flight — a password change or an avatar upload.
  /// Latches the avatar tap and the destructive buttons so a second tap cannot
  /// race the first. Field edits do NOT set this: they apply in the background
  /// and must never freeze the form under the user's cursor.
  bool _working = false;

  /// Signature of the last values actually written, so an edit that lands back
  /// on what the server already has costs nothing.
  String _appliedSig = '';
  /// Says specifically "a new picture is on its way", so the spinner can go
  /// where the user is looking — on the avatar itself. The rest of this screen
  /// applies silently; an upload is the one edit slow enough to need saying.
  bool _changingAvatar = false;
  bool _leaving = false;
  bool _deleting = false;
  String? _error;

  /// The room's roster, read from the repository rather than subscribed to
  /// here.
  ///
  /// This screen used to hold its own `rooms:getMembers` — a second live query
  /// on exactly the rows the transcript behind it was already watching, both
  /// of them refiring on every read receipt in the room. There is one now, on
  /// the repository, and both screens read it. It also means this list is
  /// populated the moment the screen mounts (the room is open, so the roster
  /// is in hand) instead of after a round trip, so Room Info no longer opens
  /// on an empty member list.
  List<ChatUser> _members = const [];

  /// The exact list instance [_members] was last taken from — see
  /// `_RoomScreenState._rosterSource` for why identity is the whole test.
  List<ChatUser>? _rosterSource;

  /// Who speaks in which colour, settled the same way the transcript settles
  /// it — same roster, same pins, same pure function — so the roster below is a
  /// legend for the room rather than a second opinion about it.
  SpeakerSlots _speakerSlots = SpeakerSlots.none;
  String _speakerPinsSig = '';

  /// Same two inputs the transcript settles from — the roster and this
  /// reader's pins — so the ring beside a face here is the colour that face
  /// will actually speak in.
  void _rebuildSpeakerSlots() {
    _speakerSlots = SpeakerSlots.forMembers(
      [
        for (final u in _members)
          (id: u.id, joinedAt: u.joinedAt?.millisecondsSinceEpoch ?? 0)
      ],
      exclude: widget.repo.userId,
      pinned: widget.repo.speakerColorsFor(widget.roomId),
    );
  }

  /// Cheap identity for the pin map — empty, and so free, in every room nobody
  /// has opened the picker in.
  String _speakerPinsSignature() {
    final pins = widget.repo.speakerColorsFor(widget.roomId);
    if (pins.isEmpty) return '';
    final parts = [for (final e in pins.entries) '${e.key}:${e.value}']..sort();
    return parts.join(',');
  }

  /// Re-take the roster from the repository. True when it actually moved.
  bool _syncMembers() {
    final roster = widget.repo.membersFor(widget.roomId);
    if (identical(roster, _rosterSource)) return false;
    _rosterSource = roster;
    _members = roster;
    _rebuildSpeakerSlots();
    return true;
  }

  ChatRoom? _lastObservedRoom;

  // ── Group administration ────────────────────────────────────────────────
  //
  // ONE live subscription, and two one-shot reads. It was three subscriptions,
  // which was a real and measurable regression on a hot screen:
  //
  //   `myPermissions` reads the ROOM document, and `messages.send` patches
  //   `rooms.lastMessage` on every single message. The other two read
  //   `roomMembers` rows, which `markRoomRead` patches on every read receipt.
  //   So in an active conversation all three re-fired constantly, each calling
  //   `setState` and rebuilding this entire screen — the member sort, the
  //   shared-content counts, all of it.
  //
  // Permissions stay live because being demoted has to take effect while the
  // screen is open: someone who just lost the role should watch the controls
  // go, not tap one and be refused. But the fire is deduped by content
  // signature, exactly as `_loadMembers` above does and for exactly the same
  // reason — the query still re-runs, but an unchanged answer no longer costs
  // a rebuild.
  //
  // Starts at [RoomPermissions.none], which draws a plain member's view. The
  // first frame is wrong either way; wrong in this direction merely omits
  // controls for an instant, where the other direction flashes admin buttons at
  // people who do not have them.
  RoomPermissions _perms = RoomPermissions.none;
  Subscription? _permsSub;
  String _permsSig = '';

  /// Fetched, not subscribed. A queue that updates when you open the screen and
  /// after you act on it is worth far more than one that is live at the cost of
  /// a rebuild per read receipt — and an admin who is looking at the queue is,
  /// by definition, about to change it themselves.
  List<RoomJoinRequest> _joinRequests = const [];

  /// Invites this room has out and nobody has answered. Shown under the roster
  /// because "who is in this group" and "who is on their way" are the same
  /// question to the person reading it. Same one-shot reasoning as above.
  List<PendingRoomInvite> _pendingInvites = const [];

  /// Suggested changes to the group's name, description or picture, waiting on
  /// an admin — `roomChangeRequests.ts`. Admin-only; empty for everybody else,
  /// because the query returns [] for them rather than throwing.
  List<RoomChangeRequest> _changeRequests = const [];

  /// The SAME table read from the other end: what THIS viewer has suggested
  /// and nobody has answered. A member sees only this list; an admin never has
  /// one, because their own edits land directly.
  ///
  /// Two lists rather than one filtered, because they answer different
  /// questions and are gated on different permissions — an admin's queue is
  /// about other people, and reusing one list would mean every read had to
  /// remember which end it was looking at.
  List<RoomChangeRequest> _mySuggestions = const [];

  /// Which suggestion is mid-withdrawal, so a second tap cannot race the
  /// first and the row can say it is working.
  final _withdrawing = <String>{};

  ChatRoom? get _room => widget.repo.roomById(widget.roomId);

  /// May this viewer delete the room.
  ///
  /// For a group this is the OWNER ROLE, which is no longer the same thing as
  /// `rooms.createdBy` — ownership transfers, and an owner who deletes their
  /// account hands the room to an heir. A DM has no owner at all and either
  /// side may end it, which `caps.canDelete && r.isDm` covers at the call site.
  bool get _isOwner => _perms.isOwner;

  @override
  void initState() {
    super.initState();
    _hydrate();
    // The name and description controllers are deliberately UNWATCHED. They
    // used to drive a debounced write, which meant typing saved on its own —
    // so changing a name and then tapping cancel wrote the new name first and
    // reverted the field afterwards, leaving the room renamed. Text now
    // commits through the tick and nowhere else.
    //
    // The password field IS watched, but only to enable its button; it never
    // auto-commits either.
    _newPassword.addListener(_onPasswordTyped);
    _loadContentCounts();
    _loadAdminState();
    widget.repo.addListener(_onRepo);
  }

  /// The three administration subscriptions, opened together and torn down
  /// together in [dispose].
  ///
  /// All three are best-effort: offline, or on a room where the caller is not
  /// an admin, each simply stays at its empty value and the corresponding
  /// section does not draw. None of them is an authorization boundary — the
  /// mutations behind every control re-check server-side — so a failure here
  /// costs a button, never a permission.
  Future<void> _loadAdminState() async {
    final me = widget.repo.userId;
    if (me == null) return;
    try {
      _permsSub?.cancel();
      _permsSub = await widget.repo.cv.subscribe(
        'roomAdmin:myPermissions',
        {'roomId': widget.roomId, 'userId': me},
        onData: (data) {
          if (!mounted) return;
          final next = data == null
              ? RoomPermissions.none
              : RoomPermissions.fromJson((data as Map).cast<String, dynamic>());
          // Deduped, because this query re-fires on every message in the room:
          // it reads the room document, and `messages.send` patches
          // `rooms.lastMessage`. The ANSWER changes only when somebody's role
          // or the room's policy actually changes, which is rare — so without
          // this the screen rebuilt per message to be told nothing new.
          final sig = _permsSignature(next);
          if (sig == _permsSig) return;
          _permsSig = sig;
          setState(() => _perms = next);
          // ALWAYS refresh, not just when `isAdmin` flipped.
          //
          // Every list [_refreshAdminLists] loads is gated on a permission,
          // and the first answer from this subscription arrives AFTER the
          // one-shot load at the end of [_loadAdminState] — which therefore
          // ran while `_perms` was still `RoomPermissions.none` and fetched
          // nothing. The old `isAdmin != wasAdmin` gate then declined to fix
          // that for the one person it mattered to: a plain member, whose
          // `isAdmin` is false before and after, so their own pending
          // suggestions stayed empty until something else happened to
          // refresh. It looked like it worked because proposing refreshes
          // explicitly — and then vanished the moment they left the screen
          // and came back.
          //
          // Cheap despite the "always": the signature dedup above is the real
          // gate, and it only lets a genuine permission change through. This
          // query re-fires on every message in the room and almost all of
          // those return here.
          unawaited(_refreshAdminLists());
        },
        onError: (err) => debugPrint('permissions sub error: $err'),
      );
    } catch (e) {
      // Loud in debug, silent in release.
      //
      // This failing is indistinguishable, on screen, from "you are an ordinary
      // member": every control is gated on `_perms`, which stays at
      // `RoomPermissions.none`. That is the correct thing to RENDER — never
      // flash admin controls at someone who may not have them — but it cost an
      // hour once when the real cause was that the backend functions had not
      // been deployed yet, and the screen said nothing at all.
      //
      // Offline is a legitimate reason to land here, so this is not an error
      // the user is shown. It IS something the next person debugging an empty
      // member list should find in the console immediately.
      debugPrint(
        'room admin state unavailable for ${widget.roomId} — group controls '
        'will not render. Offline, or roomAdmin/roomInvites not deployed: $e',
      );
    }
    await _refreshAdminLists();
  }

  /// The two admin queues, read once.
  ///
  /// Called on open, whenever the caller's admin standing changes, and after
  /// any action that could alter either list. Deliberately NOT subscribed —
  /// see the note on the fields.
  Future<void> _refreshAdminLists() async {
    if (!mounted) return;
    // All four at once, each on its own failure boundary. They used to run one
    // after another inside a single try, so a failure in the first (or just a
    // slow first answer) withheld every list behind it — and the suggestion
    // queue was last in line. An admin whose join-request read failed simply
    // never saw a member's suggested photo.
    //
    // The two ends of the suggestion table are asked for only ever one per
    // viewer: an admin has a queue and no suggestions of their own, a member
    // the reverse. Conditional rather than both-and-filter, because the admin
    // query is the one that costs a roster scan.
    final requests = _readAdminList(
      _perms.canReviewJoinRequests,
      () => widget.repo.listJoinRequests(widget.roomId),
      _joinRequests,
    );
    final invites = _readAdminList(
      true,
      () => widget.repo.pendingRoomInvites(widget.roomId),
      _pendingInvites,
    );
    final changes = _readAdminList(
      _perms.canReviewChangeRequests,
      () => widget.repo.listRoomChangeRequests(widget.roomId),
      _changeRequests,
    );
    final mine = _readAdminList(
      _perms.canSuggestChanges,
      () => widget.repo.myRoomChangeRequests(widget.roomId),
      _mySuggestions,
    );
    final nextRequests = await requests;
    final nextInvites = await invites;
    final nextChanges = await changes;
    final nextMine = await mine;
    if (!mounted) return;
    setState(() {
      _joinRequests = nextRequests;
      _pendingInvites = nextInvites;
      _changeRequests = nextChanges;
      _mySuggestions = nextMine;
    });
    // The notification's last step. Deferred to HERE, the first moment both
    // the permission and the queue are actually known, rather than to
    // initState — opening from there would race the two queries and show an
    // empty sheet to an admin who has one waiting.
    if (widget.openChangeRequests && nextChanges.isNotEmpty) _autoOpenChanges();
  }

  /// One of [_refreshAdminLists]'s reads. Never throws: a list that cannot be
  /// read right now keeps what is already on screen rather than blanking, and
  /// never takes its neighbours down with it. A list the viewer may not see is
  /// empty without asking.
  Future<List<T>> _readAdminList<T>(
    bool allowed,
    Future<List<T>> Function() read,
    List<T> current,
  ) async {
    if (!allowed) return <T>[];
    try {
      return await read();
    } catch (e) {
      debugPrint('room admin list unavailable: $e');
      return current;
    }
  }

  /// Whether [RoomInfoScreen.openChangeRequests] has already been honoured.
  ///
  /// One-shot: [_refreshAdminLists] runs again after every action on this
  /// screen, and without the latch answering one suggestion would reopen the
  /// sheet on top of whatever the admin did next.
  bool _autoOpened = false;

  void _autoOpenChanges() {
    if (_autoOpened) return;
    _autoOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_openChangeRequests());
    });
  }

  /// Everything this screen actually renders from a [RoomPermissions].
  ///
  /// Not the whole object: it has no value equality, and comparing identity
  /// would defeat the dedup entirely since every fire builds a fresh instance.
  String _permsSignature(RoomPermissions p) => [
        p.role.wire,
        p.isGroup,
        p.canEditRoom,
        p.canRemoveMembers,
        p.canAssignAdmins,
        p.canManageLink,
        p.canReviewJoinRequests,
        p.canReviewChangeRequests,
        p.canSuggestChanges,
        p.canInvite,
        p.membersCanInvite,
        p.linkJoinPolicy.wire,
      ].join('|');

  /// How much each shared-content tab holds.
  ///
  /// Fetched once rather than subscribed: these are decoration on a screen the
  /// user reads and leaves, and four capped index scans per notify would be a
  /// real cost for a number that only says whether a tab is worth opening.
  ///
  /// Failure is silent, and so is the interval before it lands — a row with no
  /// count simply shows none, because a placeholder there reads as broken
  /// rather than pending. An empty tab is distinguished only once the answer
  /// is actually known.
  Map<String, RoomContentCount> _contentCounts = const {};

  Future<void> _loadContentCounts() async {
    final me = widget.repo.userId;
    if (me == null) return;
    try {
      final counts = await widget.api.roomContentCounts(
        roomId: widget.roomId,
        userId: me,
      );
      if (mounted) setState(() => _contentCounts = counts);
    } catch (_) {
      // Leaves the cards showing a dash, which is honest.
    }
  }

  void _onRepo() {
    if (!mounted) return;
    final r = _room;
    // The roster arrives through the repository now, so it has to survive the
    // same-fields early return below for the same reason the pins do: the room
    // ROW is unchanged when somebody joins, leaves or comes online, and the
    // member list on this screen is not. Identity-gated, so this is one
    // reference comparison on the notifications that carry no roster change.
    final rosterMoved = _syncMembers();
    // A colour pinned on this very screen comes back through the repository,
    // so it has to survive the same-fields early return below — the room row
    // has not changed at all, and the rings and the section value have.
    final pinsSig = _speakerPinsSignature();
    if (pinsSig != _speakerPinsSig) {
      _speakerPinsSig = pinsSig;
      _rebuildSpeakerSlots();
      setState(() {});
      _lastObservedRoom = r;
      return;
    }
    if (rosterMoved) {
      setState(() {});
      _lastObservedRoom = r;
      return;
    }
    // Repo fires for typing/messages/read-receipts which don't affect this
    // screen — naïvely rebuilding on every notify caused scroll stutter
    // because each frame during a drag triggered a full settings rebuild.
    // Only setState when fields actually rendered here change.
    if (_isSameRelevantFields(r, _lastObservedRoom)) {
      _lastObservedRoom = r;
      return;
    }
    _lastObservedRoom = r;
    setState(() {});
  }

  bool _isSameRelevantFields(ChatRoom? a, ChatRoom? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.id == b.id &&
        a.name == b.name &&
        a.description == b.description &&
        a.avatarStorageId == b.avatarStorageId &&
        a.isPrivate == b.isPrivate &&
        a.hasPassword == b.hasPassword &&
        a.messageLifetime == b.messageLifetime &&
        a.createdBy == b.createdBy &&
        a.memberCount == b.memberCount;
  }

  void _hydrate() {
    final r = _room;
    if (r == null) return;
    _name.text = r.name;
    _desc.text = r.description ?? '';
    _isPrivate = r.isPrivate;
    _ttl = r.messageLifetime;
    // Seeded so the first keystroke is measured against what the server has,
    // not against an empty string — otherwise opening the screen and touching
    // nothing would still write on the first debounce.
    // Trimmed to match how [_pushRoom] builds it, or a description stored with
    // stray whitespace would never compare equal and every toggle would write.
    _appliedSig =
        '${r.name.trim()}|${(r.description ?? '').trim()}|${r.isPrivate}|${r.isEphemeral ? r.messageLifetime : null}';
    _loaded = true;
    // The roster is already in hand — this screen is only ever pushed from the
    // room it describes, so the repository is holding that room's members by
    // the time we get here. Nothing to fetch and nothing to wait for; the live
    // updates arrive through [_onRepo] like everything else.
    _syncMembers();
  }

  @override
  void dispose() {
    _newPassword.removeListener(_onPasswordTyped);
    _permsSub?.cancel();
    widget.repo.removeListener(_onRepo);
    _name.dispose();
    _desc.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  /// Push the room's settings. There is no Save button.
  ///
  /// Two kinds of control feed this, and they commit differently on purpose:
  ///
  ///   discrete   the visibility segments and the disappearing-message chips
  ///              call straight in on tap. The tap IS the decision and there is
  ///              nothing to get wrong, so waiting would only make them feel
  ///              unresponsive.
  ///   text       the name and description commit ONLY through their tick.
  ///              They used to auto-save on a debounce, which made cancel a
  ///              lie: the write had already gone by the time you pressed it.
  ///
  /// Values come from the ROOM, overridden by whichever field is being
  /// changed. Reading the controllers for everything would let an edit to one
  /// field silently rewrite another with a stale value — the controllers are
  /// seeded once, so a rename by another admin would be undone by the next
  /// description edit.
  /// Where a committed name or description edit actually goes.
  ///
  /// The same row, the same gesture, two destinations. An admin's tick writes
  /// the room; a member's files a suggestion the admins answer. Routed here,
  /// once, rather than at the two call sites, so the pair can never drift —
  /// and routed on [RoomPermissions] rather than on which branch drew the row,
  /// because the permission is what the server will actually check.
  ///
  /// A DM keeps the admin path: it has no admins to ask, and `updateRoom` lets
  /// either participant through.
  Future<void> _commitText(RoomChangeField field, String value) {
    final r = _room;
    final direct = r == null || !r.isGroupChat || _perms.canEditRoom;
    if (direct) {
      return field == RoomChangeField.name
          ? _pushRoom(name: value)
          : _pushRoom(description: value);
    }
    return _suggest(field: field, value: value);
  }

  /// File a suggestion and say so.
  ///
  /// Errors land in [_error] like every other write on this screen rather than
  /// in a toast, because the row that produced them is still on screen and the
  /// message belongs beside it — a toast would float over the member list
  /// while the field it is about sat two hundred pixels up.
  Future<void> _suggest({
    required RoomChangeField field,
    String? value,
    String? storageId,
  }) async {
    final r = _room;
    if (r == null) return;
    if (mounted) setState(() => _error = null);
    try {
      final queued = await widget.repo.proposeRoomChange(
        roomId: r.id,
        field: field,
        value: value,
        storageId: storageId,
      );
      if (!mounted) return;
      // `queued` is false only when the caller turned out to be an admin after
      // all — promoted while they were picking. Saying "sent to the admins"
      // there would be a lie about a change that is already live.
      showAppToast(
        context,
        queued
            ? AppLocalizations.of(context).roomInfoScreenSuggestionSentToast
            : AppLocalizations.of(context).roomInfoScreenSuggestionAppliedToast,
        tone: ToastTone.success,
      );
      await _refreshAdminLists();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanize(context, e));
    }
  }

  /// Take one of your own suggestions back. Deletes it outright server-side —
  /// see `roomChangeRequests.withdraw` for why it is not kept as "withdrawn".
  Future<void> _withdrawSuggestion(RoomChangeRequest s) async {
    if (_withdrawing.contains(s.requestId)) return;
    setState(() => _withdrawing.add(s.requestId));
    try {
      await widget.repo.withdrawRoomChange(s.requestId);
      if (!mounted) return;
      setState(() {
        _withdrawing.remove(s.requestId);
        _mySuggestions =
            _mySuggestions.where((x) => x.requestId != s.requestId).toList();
      });
      showAppToast(
        context,
        AppLocalizations.of(context).roomInfoScreenSuggestionWithdrawnToast,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _withdrawing.remove(s.requestId);
        _error = _humanize(context, e);
      });
      // Usually means an admin answered it while this screen was open. Re-read
      // rather than leaving a row whose button will refuse again.
      await _refreshAdminLists();
    }
  }

  /// The admin's queue, and a refresh of everything it could have changed —
  /// an approval renames the room behind the sheet.
  Future<void> _openChangeRequests() async {
    await showRoomChangeRequestsSheet(
      context,
      repo: widget.repo,
      api: widget.api,
      roomId: widget.roomId,
    );
    await _refreshAdminLists();
  }

  Future<void> _pushRoom({String? name, String? description}) async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;

    final nextName = (name ?? r.name).trim();
    // An empty name is not a state to save, it is a state to be told about.
    // The server refuses it too (ROOM_NAME_REQUIRED); catching it here means
    // the message appears while the field is still empty rather than after a
    // round trip, and no write is attempted.
    if (nextName.isEmpty) {
      if (!mounted) return;
      setState(() => _error =
          AppLocalizations.of(context).roomInfoScreenNameRequiredError);
      return;
    }

    final nextDesc = (description ?? r.description ?? '').trim();
    final ttl = r.isEphemeral ? _ttl : null;
    // Skip a write that would change nothing — committing an edit that landed
    // back on the original value, or tapping the segment that is already
    // active. Every mutation on this row wakes every subscription watching it.
    final sig = '$nextName|$nextDesc|$_isPrivate|$ttl';
    if (sig == _appliedSig) {
      if (_error != null && mounted) setState(() => _error = null);
      return;
    }

    if (mounted) setState(() => _error = null);
    try {
      await widget.api.updateRoom(
        roomId: r.id,
        userId: me,
        name: nextName,
        description: nextDesc.isEmpty ? null : nextDesc,
        isPrivate: _isPrivate,
        messageLifetime: ttl,
      );
      _appliedSig = sig;
    } catch (e) {
      if (!mounted) return;
      // The local value stays as typed rather than snapping back. A rename
      // refused because the name is taken should leave the name on screen to
      // be edited, not silently revert and leave the reader wondering what
      // they did.
      setState(() => _error = _humanize(context, e));
    }
  }

  /// The collapsed password row: what the room's state is, and a way in.
  Widget _passwordSummary(AppTheme theme, ChatRoom r, bool busy) {
    final l10n = AppLocalizations.of(context);
    return GroupedRow(
      icon: r.hasPassword ? CupertinoIcons.lock_fill : CupertinoIcons.lock_open_fill,
      tone: r.hasPassword ? TileTone.orange : TileTone.gray,
      title: r.hasPassword
          ? l10n.roomInfoScreenPasswordSetState
          : l10n.roomInfoScreenPasswordUnsetState,
      onTap: busy ? null : () => setState(() => _passwordOpen = true),
    );
  }

  /// Close the password block, discarding anything typed. Discarding is the
  /// right default for the one field here that does not auto-apply: a password
  /// half-typed and abandoned should leave no trace.
  void _closePassword() {
    _newPassword.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _passwordOpen = false;
      _passwordHasText = false;
    });
  }

  /// Rebuild so the SET button appears or disappears with the field's content.
  /// Only when emptiness actually flips — a rebuild per keystroke is what this
  /// screen has spent the last day getting rid of.
  void _onPasswordTyped() {
    final has = _newPassword.text.isNotEmpty;
    if (has == _passwordHasText) return;
    setState(() => _passwordHasText = has);
  }

  /// Set the room password. The ONE control here that is not automatic.
  ///
  /// A password committed on a debounce is a password set to whatever was
  /// typed at the moment the user paused — a half-entered secret, locked in,
  /// with the real one never applied. Explicit for the same reason the remove
  /// action beside it is.
  Future<void> _applyPassword() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    final pw = _newPassword.text;
    if (pw.isEmpty) return;
    setState(() => _error = null);
    try {
      await widget.api.updateRoomPassword(roomId: r.id, userId: me, password: pw);
      if (!mounted) return;
      _newPassword.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _passwordOpen = false;
        _passwordHasText = false;
      });
      showAppToast(
        context,
        AppLocalizations.of(context).roomInfoScreenPasswordSetSnackbar,
        tone: ToastTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanize(context, e));
    }
  }

  Future<void> _clearPassword() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.api.updateRoomPassword(roomId: r.id, userId: me);
      if (!mounted) return;
      setState(() => _working = false);
      showAppToast(
        context,
        AppLocalizations.of(context).roomInfoScreenPasswordClearedSnackbar,
        tone: ToastTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _humanize(context, e);
      });
    }
  }

  /// Pick, crop and upload a new room picture.
  ///
  /// Marked in-flight BEFORE the picker rather than after the crop screen
  /// returns. The old order was defended as "cancelling here needs no state reset
  /// at all", which was true and beside the point: `pickerImageQuality` forces
  /// the plugin to decode and re-encode the chosen asset, which for a large photo
  /// is seconds of work happening after its sheet has dismissed. So the whole
  /// pick-and-crop happened with nothing on this screen moving. Paying for the
  /// extra resets on the two cancel paths is the cheaper half of that trade.
  Future<void> _changeAvatar() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    setState(() {
      _working = true;
      _changingAvatar = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: pickerImageQuality,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final cropped = await ImageCropScreen.open(
        context,
        source: bytes,
        shape: CropShape.circle,
      );
      if (cropped == null || !mounted) return;
      final uploader = UploadService(widget.api);
      final storageId = await uploader.uploadFile(
        bytes: cropped.bytes,
        contentType: cropped.contentType,
      );
      // Same two destinations as a committed name edit — see [_commitText].
      // The upload happens either way and is the slow part; who gets to say
      // whether it becomes the group's face is the only thing that differs.
      if (r.isGroupChat && !_perms.canEditRoom) {
        await _suggest(field: RoomChangeField.avatar, storageId: storageId);
        return;
      }
      await widget.api.updateRoomAvatar(
        roomId: r.id,
        userId: me,
        storageId: storageId,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanize(context, e));
    } finally {
      // One place that lowers both flags, for every path out — cancelled picker,
      // cancelled crop, failed upload, success. The old version spelled the
      // reset out three times and still missed the cancels.
      if (mounted) {
        setState(() {
          _working = false;
          _changingAvatar = false;
        });
      }
    }
  }

  Future<void> _leave() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    final ok = await _confirm(
      title: AppLocalizations.of(context).roomInfoScreenLeaveConfirmTitle,
      body: AppLocalizations.of(context).roomInfoScreenLeaveConfirmBody,
      confirm: AppLocalizations.of(context).roomInfoScreenLeaveConfirmButton,
    );
    if (!ok) return;
    setState(() {
      _leaving = true;
      _error = null;
    });
    try {
      await widget.api.leaveRoom(roomId: r.id, userId: me);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _leaving = false;
        _error = _humanize(context, e);
      });
    }
  }

  Future<void> _delete() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    final l10n = AppLocalizations.of(context);
    // A DM has no "owner" for either side to leave from — the only real
    // action is ending the conversation, and that takes it away from the
    // other person too. Say so plainly instead of the generic room copy.
    final ok = r.isDm
        ? await _confirm(
            title: l10n.roomInfoScreenEndConversationConfirmTitle,
            body: l10n.roomInfoScreenEndConversationConfirmBody(
              _dmPeer()?.displayName ?? l10n.roomInfoScreenEndConversationPeerFallback,
            ),
            confirm: l10n.roomInfoScreenEndConversationConfirmButton,
            destructive: true,
          )
        : await _confirm(
            title: l10n.roomInfoScreenDeleteConfirmTitle,
            body: l10n.roomInfoScreenDeleteConfirmBody,
            confirm: l10n.roomInfoScreenDeleteConfirmButton,
            destructive: true,
          );
    if (!ok) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.api.deleteRoom(roomId: r.id, userId: me);
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = _humanize(context, e);
      });
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirm,
    bool destructive = false,
  }) async {
    // The iOS action sheet, like every other confirmation in the app: the
    // question as a quiet title, what it means under it, the answer (red when
    // it destroys something) and Cancel on its own below.
    final res = await showIosActionSheet<bool>(
      context,
      title: title,
      message: body,
      actions: [
        IosSheetAction(
          label: sentenceCaseOf(context, confirm),
          value: true,
          destructive: destructive,
        ),
      ],
    );
    if (res == true) {
      if (destructive) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }
    return res ?? false;
  }

  String _humanize(BuildContext context, Object e) {
    final l10n = AppLocalizations.of(context);
    final s = e.toString();
    if (s.contains('ROOM_EXISTS')) return l10n.roomInfoScreenErrorRoomExists;
    if (s.contains('NAME_INAPPROPRIATE')) return l10n.nameInappropriate;
    if (s.contains('NOT_OWNER')) return l10n.roomInfoScreenErrorNotOwner;
    if (s.contains('NOT_AUTHORIZED')) return l10n.roomInfoScreenErrorNotAuthorized;
    if (s.contains('ROOM_NAME_REQUIRED')) return l10n.roomInfoScreenNameRequiredError;
    if (s.contains('ROOM_NOT_FOUND')) return l10n.roomInfoScreenErrorRoomNotFound;
    return friendlyServerError(e, l10n, s.replaceFirst('Exception: ', ''));
  }

  String _fmtTtl(BuildContext context, Duration d) {
    final l10n = AppLocalizations.of(context);
    if (d.inSeconds < 60) return l10n.roomInfoScreenTtlSeconds(d.inSeconds);
    if (d.inMinutes < 60) return l10n.roomInfoScreenTtlMinutes(d.inMinutes);
    return l10n.roomInfoScreenTtlHours(d.inHours);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final r = _room;
    if (r == null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(child: Text(AppLocalizations.of(context).roomInfoScreenRoomGone, style: theme.bodySoft)),
      );
    }
    if (!_loaded) _hydrate();
    final busy = _working || _leaving || _deleting;

    // A DM has no name/visibility/password of its own — it's just the two
    // people. Resolve the other person so we show their name and avatar
    // instead of the internal "dm:regular:<id>:<id>" key. Saved Messages is a
    // DM with no other person at all (_dmPeer() is null by construction), so
    // it needs its own substitution instead of the "dm:self:<id>" key.
    final peer = r.isDm ? _dmPeer() : null;
    final title = r.isSavedMessages ? AppLocalizations.of(context).savedMessagesTitle : (peer?.displayName ?? r.name);
    // Resolved from the live member list rather than the repo's friends cache,
    // so it is right on the first frame — `_dmPeer()` above already had to
    // solve that problem, and the peer is half the answer for a bot DM.
    var caps = roomCapabilitiesFor(r, peer: peer);
    // `roomCapabilitiesFor` answers what KIND of room this is — whether a room
    // like this one has a name, a description, a visibility. Whether THIS
    // viewer may change them is a second question it has never known the
    // answer to, and before the admin tier there was nothing to ask: every
    // member could edit every group.
    //
    // Folded into the capability rather than checked at each of the five call
    // sites below, so a field added later inherits the rule instead of quietly
    // staying editable by everyone.
    //
    // Tested against the ROOM's own shape, not against `_perms.isGroup`. The
    // permissions arrive one round trip late, and `RoomPermissions.none` — the
    // value they start at — reports `isGroup: false`, so keying the clamp off
    // it would leave the fields editable for exactly as long as the query takes
    // and then snatch them away. Reading the room means the conservative answer
    // is the one on screen first, and an admin gets the fields back a moment
    // later rather than a member losing them.
    // NOTE: the name and description rows are NOT clamped here any more.
    //
    // They used to be, and it made the top of this screen jump: permissions
    // arrive a round trip after the first frame, so the screen painted without
    // them, then grew two rows the moment `myPermissions` landed. Fast enough
    // to read as a glitch rather than as loading.
    //
    // They no longer need clamping. Since [EditableInfoRow] renders a VALUE and
    // only becomes a field when tapped, a member who cannot edit should still
    // see the room's name and description — that is the content of the screen.
    // Whether they can change it is `enabled:`, which flipping later costs a
    // pencil glyph rather than two rows of layout.
    //
    // The genuine CONTROLS below — visibility, disappearing messages, password
    // — are still permission-gated, because they have no read-only meaning.
    // Their arrival is eased rather than popped; see the AnimatedSize there.
    final l10n = AppLocalizations.of(context);
    final canEditFields = _perms.canEditRoom ||
        !r.isGroupChat ||
        _perms.canSuggestChanges;
    return HeroPage(
      title: title,
      hero: _hero(theme, r, peer, title, caps),
      children: [
        // Name/visibility don't apply to a 1:1 DM — the room is just the two
        // people — nor to a room the app owns. Text, not a text field, until
        // tapped: a page made of empty input boxes reads as a form to fill in
        // rather than a room to look at. See [EditableInfoRow].
        if (caps.canEditSettings || caps.hasDescription)
          InsetGroup(
            children: [
              if (caps.canEditSettings)
                EditableInfoRow(
                  label: l10n.riName,
                  value: r.name,
                  saveLabel: l10n.roomInfoScreenEditSave,
                  cancelLabel: l10n.roomInfoScreenEditCancel,
                  controller: _name,
                  placeholder: l10n.roomInfoScreenNameHint,
                  // A member who may SUGGEST gets the same editable row an
                  // admin gets, with a note saying where the edit goes —
                  // the ask exists so "can I fix the name" is not "no".
                  enabled: canEditFields,
                  note: _suggestNote(),
                  onCommit: (v) => _commitText(RoomChangeField.name, v),
                ),
              // Nothing to describe about a chat with only yourself in it, one
              // the app writes to you, or one with exactly one other person —
              // see [RoomCapabilities.hasDescription].
              if (caps.hasDescription)
                EditableInfoRow(
                  label: l10n.riDescription,
                  value: r.description ?? '',
                  saveLabel: l10n.roomInfoScreenEditSave,
                  cancelLabel: l10n.roomInfoScreenEditCancel,
                  controller: _desc,
                  placeholder: l10n.roomInfoScreenDescriptionHint,
                  enabled: canEditFields,
                  note: _suggestNote(),
                  maxLines: 3,
                  onCommit: (v) =>
                      _commitText(RoomChangeField.description, v),
                ),
            ],
          ),
        // Directly under the fields it is about; a member never sees the
        // admin-only controls below, so for them this reads as the next thing
        // after the description.
        _mySuggestionsBlock(theme),
        // Eased, not popped. These appear one round trip after the page does
        // (permissions), and a hard insert is the jump this screen was once
        // reported for.
        AnimatedSize(
          duration: theme.motionMed,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !(_perms.canEditRoom && caps.canEditSettings)
              ? const SizedBox(width: double.infinity)
              : GroupedSection(
                  header: l10n.riVisibility,
                  children: [
                    GroupedRow.choice(
                      icon: CupertinoIcons.globe,
                      tone: TileTone.blue,
                      title: l10n.riPublic,
                      subtitle: l10n.riPublicSub,
                      selected: !_isPrivate,
                      onTap: () {
                        setState(() => _isPrivate = false);
                        unawaited(_pushRoom());
                      },
                    ),
                    GroupedRow.choice(
                      icon: CupertinoIcons.lock_fill,
                      tone: TileTone.gray,
                      title: l10n.riPrivate,
                      subtitle: l10n.riPrivateSub,
                      selected: _isPrivate,
                      onTap: () {
                        setState(() => _isPrivate = true);
                        unawaited(_pushRoom());
                      },
                    ),
                  ],
                ),
        ),
        if (r.isEphemeral)
          InsetGroup(
            header: l10n.riMessageLife,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _ttlOptions)
                      SpringPress(
                        onTap: () {
                          setState(() => _ttl = t);
                          unawaited(_pushRoom());
                        },
                        child: AnimatedContainer(
                          duration: theme.motionFast,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _ttl == t
                                ? theme.accent
                                : theme.ink.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _fmtTtl(context, t),
                            style: theme.body.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: _ttl == t ? theme.accentInk : theme.ink,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        // Password, collapsed to a status row until tapped: an always-visible
        // password box on a page you open to read the member list invites a
        // secret nobody asked for. Opening reveals the field and both actions.
        if (_perms.canEditRoom && caps.canEditSettings)
          InsetGroup(
            header: l10n.riPassword,
            children: [
              if (!_passwordOpen)
                _passwordSummary(theme, r, busy)
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PasswordField(
                        controller: _newPassword,
                        hint: r.hasPassword
                            ? l10n.roomInfoScreenReplacePasswordHint
                            : l10n.roomInfoScreenSetPasswordHint,
                        onSubmitted: (_) => _applyPassword(),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        if (r.hasPassword) ...[
                          Expanded(
                            child: SheetButton(
                              label: l10n.riRemovePassword,
                              danger: true,
                              onTap: busy ? null : _clearPassword,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: SheetButton(
                            label: l10n.riSetPassword,
                            filled: true,
                            // Dead until there is something to set — the one
                            // commit on this page, so it must never fire on an
                            // empty field.
                            onTap: (busy || !_passwordHasText)
                                ? null
                                : _applyPassword,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FocusableTap(
                          onTap: _closePassword,
                          semanticLabel: l10n.roomInfoScreenPasswordCancel,
                          radius: theme.radiusSm,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _closePassword,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              child: Text(
                                l10n.roomInfoScreenPasswordCancel,
                                style: theme.body.copyWith(
                                  fontSize: 15,
                                  color: theme.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        // No Save button: every control above applies itself. This is where a
        // refused change speaks — a name already taken, a write that failed
        // offline — under whatever was being edited.
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Text(
              _error!,
              style: theme.body.copyWith(fontSize: 15, color: theme.danger),
            ),
          ),
        // Rebuilt on every repository notify: the SAVED count rides the
        // bookmark subscription, which the screen-wide filter ignores.
        AnimatedBuilder(
          animation: widget.repo,
          builder: (context, _) => GroupedSection(
          header: l10n.riSharedContent,
          // What a save is, said once under the group: SAVED next to MEDIA and
          // FILES otherwise reads as a fifth bucket of the room's stuff.
          footer: caps.canSaveMessages
              ? l10n.riSavedNote
              : null,
          children: _sharedContentRows(theme, caps),
        ),
        ),
        // "Members (1): you" is not information — nor is "you and a bot", or
        // "you and the person this page is already titled after". The invite
        // controls are the HEAD of the roster, the WhatsApp/Signal/Telegram
        // arrangement.
        if (caps.hasMembers)
          InsetGroup(
            header: l10n.riMembers(
              _members.isEmpty ? r.memberCount : _members.length,
            ),
            footer: _members.any(
                    (m) => RoomRoleWire.parse(m.role) == RoomRole.owner)
                ? l10n.riOwnerNote
                : null,
            dividerInset: 66,
            children: [
              if (r.isGroupChat && (_perms.canInvite || _perms.canManageLink))
                ..._groupAdminRows(theme),
              ..._memberRows(theme, r),
            ],
          ),
        // Outstanding invites, below the real roster and visibly apart from
        // it: these people have been asked and have not answered.
        if (caps.hasMembers && _pendingInvites.isNotEmpty)
          InsetGroup(
            header: l10n.riInvited(_pendingInvites.length),
            dividerInset: 66,
            children: [
              for (final inv in _pendingInvites) _pendingInviteRow(theme, inv),
            ],
          ),
        // Under the roster: the rings on the faces are the answer, and this is
        // the place to go to argue with one of them.
        if (caps.hasMembers)
          GroupedSection(
            header: l10n.riNameColours,
            children: [_speakerColorsRow(theme)],
          ),
        // The blocks that change nothing for anybody but the reader.
        if (caps.canMute)
          GroupedSection(
            header: l10n.riNotifications,
            children: [_muteRow(theme, r)],
          ),
        // Offered on every room kind — a note you left yourself in a language
        // you were practising is a real thing to want translated.
        GroupedSection(
          header: l10n.riTranslation,
          children: [_translateRow(theme, r)],
        ),
        // A DM has no "leave" that makes sense; its one real action is ending
        // it outright, available to either side. Saved Messages and the system
        // rooms have nothing to end. `_isOwner` stays here: whether a KIND of
        // room can be deleted and whether THIS viewer may are different
        // questions, and only this page knows the second.
        if (caps.canLeave || (caps.canDelete && (_isOwner || r.isDm)))
          GroupedSection(
            children: [
              if (caps.canLeave)
                GroupedRow(
                  icon: CupertinoIcons.arrow_right_square,
                  tone: TileTone.red,
                  title: _leaving ? l10n.riLeaving : l10n.riLeaveRoom,
                  destructive: true,
                  onTap: busy ? null : _leave,
                ),
              if (caps.canDelete && (_isOwner || r.isDm))
                GroupedRow(
                  icon: CupertinoIcons.trash_fill,
                  tone: TileTone.red,
                  title: _deleting
                      ? (r.isDm ? l10n.riEnding : l10n.riDeleting)
                      : (r.isDm ? l10n.riEndConversation : l10n.riDeleteRoom),
                  destructive: true,
                  onTap: busy ? null : _delete,
                ),
            ],
          ),
        // Report: the group itself, or the other person in a DM. Its own block
        // below the leave/delete pair because it ends nothing: the room stays
        // exactly as it is, and what leaves is a copy of its last messages for
        // the moderators. `caps.canReport` keeps it off Saved Messages and the
        // app's own rooms.
        if (caps.canReport && (!r.isDm || peer != null))
          GroupedSection(
            children: [
              GroupedRow(
                icon: CupertinoIcons.flag_fill,
                tone: TileTone.red,
                title: r.isDm ? l10n.riReportPerson : l10n.riReportGroup,
                destructive: true,
                onTap: busy ? null : () => _report(r, peer),
              ),
            ],
          ),
      ],
    );
  }

  /// Files a report on this room or, in a DM, on the other person. The sheet,
  /// the call and the confirmation are the shared flow in `report_sheet.dart`.
  Future<void> _report(ChatRoom r, ChatUser? peer) async {
    final me = widget.repo.userId;
    if (me == null) return;
    final isDm = r.isDm && peer != null;
    await fileReport(
      context,
      api: widget.api,
      reporterId: me,
      target: isDm ? ReportTarget.user : ReportTarget.room,
      targetId: isDm ? peer.id : r.id,
    );
  }

  /// The Contacts-style head: the face, the name, who or how many, and the
  /// things you can do from here as tiles.
  Widget _hero(
    AppTheme theme,
    ChatRoom r,
    ChatUser? peer,
    String title,
    RoomCapabilities caps,
  ) {
    final l10n = AppLocalizations.of(context);
    final String? subtitle = r.isDm
        ? (peer == null || r.isSavedMessages ? null : '@${peer.username}')
        : (caps.hasMembers
            ? l10n.riMembers(
                _members.isEmpty ? r.memberCount : _members.length,
              )
            : null);
    final callable = r.isDm &&
        !r.isSavedMessages &&
        caps.canCall &&
        peer != null &&
        !peer.isSystem;
    final tiles = <Widget>[
      if (callable) ...[
        ProfileActionTile(
          icon: CupertinoIcons.phone_fill,
          label: l10n.riActionCall,
          emphasis: true,
          onTap: () => _callMember(peer, CallMediaKind.audio),
        ),
        ProfileActionTile(
          icon: CupertinoIcons.video_camera_solid,
          label: l10n.riActionVideo,
          emphasis: true,
          onTap: () => _callMember(peer, CallMediaKind.video),
        ),
      ],
      if (r.isGroupChat && _perms.canInvite)
        ProfileActionTile(
          icon: CupertinoIcons.person_badge_plus_fill,
          label: l10n.riActionAdd,
          emphasis: true,
          onTap: () async {
            await showRoomInviteFriendsSheet(
              context,
              repo: widget.repo,
              api: widget.api,
              roomId: widget.roomId,
            );
            await _refreshAdminLists();
          },
        ),
      if (caps.canMute)
        ProfileActionTile(
          icon: r.isMuted
              ? CupertinoIcons.bell_fill
              : CupertinoIcons.bell_slash_fill,
          label: r.isMuted ? l10n.riActionUnmute : l10n.riActionMute,
          onTap: () =>
              showMuteRoomSheet(context, repo: widget.repo, room: r),
        ),
      ProfileActionTile(
        icon: CupertinoIcons.photo_on_rectangle,
        label: l10n.riActionMedia,
        onTap: () => _openContent(RoomContentTab.media),
      ),
    ];
    return Padding(
      padding: readableInset(context, top: 6, bottom: 24),
      child: Column(
        children: [
          AvatarPop(child: _avatarBlock(theme, r, peer)),
          const SizedBox(height: 14),
          RiseIn(
            index: 1,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.displayMedium,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            RiseIn(
              index: 2,
              child: Text(subtitle, style: groupedSubtitleStyle(theme)),
            ),
          ],
          const SizedBox(height: 20),
          RiseIn(index: 3, child: ProfileActionBar(tiles: tiles)),
        ],
      ),
    );
  }

  /// The other participant in a DM, resolved from the live member list (which
  /// is populated for any DM, unlike the friends-only cache). Null while members
  /// are still loading or for non-DM rooms.
  ChatUser? _dmPeer() {
    final me = widget.repo.userId;
    for (final m in _members) {
      if (m.id != me) return m;
    }
    final room = _room;
    return room == null ? null : widget.repo.otherUserFor(room);
  }

  /// Diameter of the avatar at the top of this screen.
  static const _avatarSize = 104.0;

  /// How far the camera badge hangs past the avatar's circle.
  static const _badgeOverhang = 2.0;

  void _openAvatarFullscreen({
    required String storageId,
    required Object heroTag,
  }) {
    FullscreenImageViewer.openAvatar(
      context,
      storageId: storageId,
      api: widget.api,
      heroTag: heroTag,
      sourceSize: _avatarSize,
    );
  }

  Widget _avatarBlock(AppTheme theme, ChatRoom r, ChatUser? peer) {
    const size = _avatarSize;
    if (r.isSavedMessages) {
      return Center(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(theme.accent, Colors.white, 0.18)!,
                theme.accent,
              ],
            ),
          ),
          child: Icon(CupertinoIcons.bookmark_fill, size: size * 0.40, color: theme.accentInk),
        ),
      );
    }
    // A DM shows the other person's avatar, and it isn't editable — you can't
    // rename or re-skin someone else.
    if (r.isDm) {
      final peerStorageId = peer?.avatarStorageId;
      // A gradient-initials placeholder isn't worth a fullscreen route, so the
      // tap only arms once there's a real picture behind it.
      final canViewPeer = peerStorageId != null && peerStorageId.isNotEmpty;
      return Center(
        child: Column(
          children: [
            if (peer != null)
              Builder(builder: (context) {
                final avatar = UserAvatar(user: peer, size: size, api: widget.api);
                if (!canViewPeer) return avatar;
                final heroTag = 'room-info-peer-avatar-${peer.id}';
                return FocusableTap(
                  onTap: () => _openAvatarFullscreen(
                    storageId: peerStorageId,
                    heroTag: heroTag,
                  ),
                  shape: FocusRingShape.circle,
                  semanticLabel: AppLocalizations.of(context).roomInfoScreenViewProfilePictureSemantic,
                  child: GestureDetector(
                    onTap: () => _openAvatarFullscreen(
                      storageId: peerStorageId,
                      heroTag: heroTag,
                    ),
                    child: SteadyHero(tag: heroTag, child: avatar),
                  ),
                );
              })
            else
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: theme.ink.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.person_fill,
                  color: theme.inkMuted,
                  size: size * 0.42,
                ),
              ),
          ],
        ),
      );
    }
    final hasAvatar = r.avatarStorageId != null && r.avatarStorageId!.isNotEmpty;
    final heroTag = 'room-info-avatar-${r.id}';
    final Widget picture = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? SteadyHero(
              tag: heroTag,
              child: RemoteImage(
                storageId: r.avatarStorageId!,
                api: widget.api,
                width: size,
                height: size,
                borderRadius: BorderRadius.circular(size),
              ),
            )
          : MonogramAvatar(label: r.name, seed: r.id, size: size),
    );
    // The badge means two different things now — "set this" for an admin,
    // "ask for this" for everybody else — and the badge itself cannot say
    // which. A camera glyph that quietly files a request would be the one
    // control on this screen that lies about what a tap does, so the caption
    // below says it out loud, before the tap rather than after it.
    final suggesting = r.isGroupChat &&
        !_perms.canEditRoom &&
        _perms.canSuggestChanges;
    return Center(
      // The picture is for looking at; editing lives on the badge. Tapping the
      // image itself used to open the picker, which meant a room's avatar was
      // the one picture in the app you could never actually see.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size + _badgeOverhang,
            height: size + _badgeOverhang,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: size,
                  height: size,
                  child: hasAvatar
                      ? FocusableTap(
                          onTap: () => _openAvatarFullscreen(
                            storageId: r.avatarStorageId!,
                            heroTag: heroTag,
                          ),
                          shape: FocusRingShape.circle,
                          semanticLabel: AppLocalizations.of(context).roomInfoScreenViewRoomPictureSemantic,
                          child: GestureDetector(
                            onTap: () => _openAvatarFullscreen(
                              storageId: r.avatarStorageId!,
                              heroTag: heroTag,
                            ),
                            child: picture,
                          ),
                        )
                      : picture,
                ),
                if (_changingAvatar)
                  Positioned(
                    left: 0,
                    top: 0,
                    width: size,
                    height: size,
                    // Must not swallow taps meant for the badge.
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                        child: Center(
                          child: PhotoSpinner(
                            size: 26,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                  ),
                // The badge, for people who may change the picture — and now also
                // for people who may ASK to. `rooms.updateRoomAvatar` stays
                // admin-only; a member's tap ends in `roomChangeRequests.propose`
                // instead (see [_changeAvatar]), which is why the gate widened
                // rather than the mutation loosening.
                //
                // Still gated: without it somebody who can do NEITHER would pick a
                // photo, sit through the upload, and be refused at the last step.
                if (!r.isGroupChat || _perms.canEditRoom || _perms.canSuggestChanges)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: FocusableTap(
                    onTap: _working ? null : _changeAvatar,
                    shape: FocusRingShape.circle,
                    semanticLabel: r.isGroupChat && !_perms.canEditRoom
                        ? AppLocalizations.of(context).roomInfoScreenSuggestRoomPictureSemantic
                        : hasAvatar
                            ? AppLocalizations.of(context).roomInfoScreenChangeRoomPictureSemantic
                            : AppLocalizations.of(context).roomInfoScreenAddRoomPictureSemantic,
                    child: GestureDetector(
                      onTap: _working ? null : _changeAvatar,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.background, width: 3),
                        ),
                        child: Icon(
                          CupertinoIcons.camera_fill,
                          size: 14,
                          color: theme.accentInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (suggesting) ...[
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).roomInfoScreenSuggestAvatarNote,
              style: groupedMetaStyle(theme),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// The line under a name or description row that says where a member's edit
  /// actually goes. Null for anybody whose tick writes the room directly — an
  /// admin does not need telling that their own edit is their own edit.
  String? _suggestNote() {
    final r = _room;
    if (r == null || !r.isGroupChat) return null;
    if (_perms.canEditRoom || !_perms.canSuggestChanges) return null;
    return AppLocalizations.of(context).roomInfoScreenSuggestNote;
  }

  /// What this viewer has asked for and nobody has answered.
  ///
  /// Only ever drawn for a member — an admin's edits land directly, so they
  /// can never have one. Zero height when there is nothing outstanding, which
  /// is the usual case, so it costs nothing to leave unconditional at the call
  /// site.
  Widget _mySuggestionsBlock(AppTheme theme) {
    if (_mySuggestions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return InsetGroup(
      header: l10n.riYouSuggested,
      dividerInset: 66,
      children: [
        for (final s in _mySuggestions) _suggestionRow(theme, s),
      ],
    );
  }

  Widget _suggestionRow(AppTheme theme, RoomChangeRequest s) {
    final l10n = AppLocalizations.of(context);
    final busy = _withdrawing.contains(s.requestId);
    // The row has to SHOW the suggestion, not merely report that one exists.
    // It used to say "A new group picture" beside a generic camera glyph,
    // which tells you nothing you did not already know — you are the person
    // who picked it — and left no way to check WHICH picture is pending
    // before deciding whether to take it back.
    final proposed = (s.value ?? '').trim();
    final what = switch (s.field) {
      // The thumbnail to the left IS the answer here, so the line beside it
      // stays a label rather than repeating it in words.
      RoomChangeField.avatar => l10n.roomInfoScreenSuggestionPhoto,
      RoomChangeField.name =>
        l10n.roomInfoScreenSuggestionName(s.value ?? ''),
      // An empty description proposal is a real one — "take it off" — and is
      // worded rather than rendered as a blank line, which reads as broken.
      RoomChangeField.description => l10n.roomInfoScreenSuggestionDescription(
          proposed.isEmpty ? l10n.roomChangeRequestsClearedValue : proposed,
        ),
      // A field a newer server grew. Named vaguely rather than hidden: the
      // row's whole job here is to make sure nothing of yours is pending
      // without you being able to see and cancel it.
      RoomChangeField.unknown => l10n.roomInfoScreenSuggestionOther,
    };
    final storageId = s.storageId;
    final hasThumb = s.field == RoomChangeField.avatar &&
        storageId != null &&
        storageId.isNotEmpty;
    return Padding(
      key: ValueKey('suggestion-${s.requestId}'),
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: quietFill(theme),
              shape: BoxShape.circle,
            ),
            clipBehavior: hasThumb ? Clip.antiAlias : Clip.none,
            child: hasThumb
                // The picture itself, through `RemoteImage` like every other
                // avatar on this screen — so it comes off the same on-disk
                // cache the upload just populated rather than being fetched
                // again.
                ? RemoteImage(
                    storageId: storageId,
                    api: widget.api,
                    width: 38,
                    height: 38,
                    borderRadius: BorderRadius.circular(38),
                  )
                : Icon(
                    s.field == RoomChangeField.avatar
                        ? CupertinoIcons.camera
                        : CupertinoIcons.pencil,
                    size: 16,
                    color: theme.accent,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  what,
                  style: theme.body.copyWith(color: theme.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l10n.roomInfoScreenSuggestionPending,
                  style: groupedSubtitleStyle(theme),
                ),
              ],
            ),
          ),
          if (busy)
            SizedBox(
              width: 16,
              height: 16,
              child: CupertinoActivityIndicator(
                radius: 8,
                color: theme.inkMuted,
              ),
            )
          else
            RowPillButton(
              label: l10n.riTakeBack,
              semanticLabel: l10n.roomInfoScreenSuggestionWithdraw,
              onTap: () => _withdrawSuggestion(s),
            ),
        ],
      ),
    );
  }

  /// The roster, as rows for the members group.
  List<Widget> _memberRows(AppTheme theme, ChatRoom r) {
    if (_members.isEmpty) {
      // A skeleton, not "Loading members…": one line where the answer is many
      // made the section jump when the roster landed. Sized to the room's own
      // denormalized member count, so usually nothing moves at all.
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SkeletonRows(count: r.memberCount.clamp(1, 8)),
        ),
      ];
    }
    // Ranked, then alphabetical. Sorting on the ROLE rather than on
    // `rooms.createdBy` is what makes a promoted admin rise up the list.
    final ordered = [..._members]..sort((a, b) {
      final ra = _rankOf(a);
      final rb = _rankOf(b);
      if (ra != rb) return ra - rb;
      return a.displayName.compareTo(b.displayName);
    });
    final me = widget.repo.userId;
    return [for (final m in ordered) _memberRow(theme, r, m, me)];
  }

  /// Owner first, then admins, then everyone else.
  int _rankOf(ChatUser u) => switch (RoomRoleWire.parse(u.role)) {
        RoomRole.owner => 0,
        RoomRole.admin => 1,
        RoomRole.member => 2,
      };

  Widget _memberRow(AppTheme theme, ChatRoom r, ChatUser m, String? me) {
    // Two members lead nowhere: yourself, and the app's own account. The second
    // is the same guard `RoomScreen._openProfile` makes, and for the same
    // reason — a bot's profile is a friend request `friends.ts` refuses above a
    // call `calls.ts` refuses. It matters HERE now that a system room can have
    // a member list at all: this is the only row in the app that would draw the
    // bot next to a chevron.
    final role = RoomRoleWire.parse(m.role);
    final isSelf = m.id == me;

    // EVERY row opens the sheet, not just an admin's. It used to jump straight
    // to the profile for anyone who could not moderate, which meant a plain
    // member tapping a face got a full-screen push and no way to simply
    // message them — the sheet's own first row. The sheet varies its contents
    // by permission; the gesture does not vary at all, which is what makes the
    // list feel consistent to tap.
    //
    // The app's own account is the one exception: there is nothing to message,
    // call or moderate there. Your own row still opens — it is the one place
    // that says, plainly, what your role in this group is.
    final hasSheet = !m.isSystem;

    void open() {
      if (hasSheet) _openMemberActions(m, role, isSelf: isSelf);
    }

    return PressRow(
      onTap: hasSheet ? open : null,
      // Long-press lands on the same sheet: muscle memory from every other
      // chat app expects it.
      onLongPress: hasSheet ? open : null,
      semanticLabel: m.displayName,
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      child: Row(
        children: [
          // Ringed in the colour this person speaks in, so the roster IS the
          // legend for the transcript.
          Builder(builder: (context) {
            final slot = _speakerSlots.slotOf(m.id);
            final ring = slot == null
                ? null
                : theme.speakerMark(slot, on: groupedFill(theme));
            return UserAvatar(
              user: m,
              size: 38,
              api: widget.api,
              ring: ring != null,
              ringColor: ring,
            );
          }),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        m.displayName,
                        style: theme.body.copyWith(color: theme.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context).roomAdminYouSuffix,
                        style: groupedSubtitleStyle(theme),
                      ),
                    ],
                  ],
                ),
                Text(
                  '@${m.username}',
                  style: groupedSubtitleStyle(theme),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // The badge reads the ROLE, shared with the sheet's header via
          // [RoleChip] so one fact cannot be styled two ways.
          if (role != RoomRole.member) RoleChip(role: role, dense: true),
          if (hasSheet) ...[
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 15,
              color: theme.inkMuted.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pendingInviteRow(AppTheme theme, PendingRoomInvite inv) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      child: Row(
        children: [
          // Dimmed rather than badged: the group is already headed "invited",
          // and the face should read as provisional at a glance.
          Opacity(
            opacity: 0.6,
            child: UserAvatar(user: inv.invitee, size: 38, api: widget.api),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.invitee.displayName,
                  style: theme.body.copyWith(color: theme.inkSoft),
                ),
                Text(
                  // "Waiting on a parent" rather than nothing: two days of
                  // silence from a supervised invitee otherwise reads as a
                  // snub rather than as a guardian who has not looked yet.
                  inv.awaitingGuardian
                      ? l10n.roomInfoScreenInviteAwaitingGuardian
                      : '@${inv.invitee.username}',
                  style: groupedSubtitleStyle(theme),
                ),
              ],
            ),
          ),
          if (inv.canCancel)
            RowPillButton(
              label: l10n.riWithdraw,
              destructive: true,
              onTap: () => _cancelInvite(inv),
            ),
        ],
      ),
    );
  }

  // ── Administration actions ──────────────────────────────────────────────
  //
  // Every one of these confirms nothing the server would not also refuse. The
  // confirmations exist because removing someone or handing a group away are
  // socially irreversible even when they are technically undoable, not because
  // the client is trusted to enforce anything.

  Future<void> _openMemberActions(
    ChatUser m,
    RoomRole role, {
    required bool isSelf,
  }) async {
    final action = await showRoomMemberActions(
      context,
      member: m,
      memberRole: role,
      permissions: _perms,
      api: widget.api,
      isSelf: isSelf,
    );
    if (action == null || !mounted) return;
    switch (action) {
      // The three everyday rows. They leave this screen rather than acting on
      // it, so none of them touches `_runAdmin` — there is no room mutation to
      // report the failure of.
      case RoomMemberAction.message:
        await _messageMember(m);
      case RoomMemberAction.voiceCall:
        await _callMember(m, CallMediaKind.audio);
      case RoomMemberAction.videoCall:
        await _callMember(m, CallMediaKind.video);
      case RoomMemberAction.openProfile:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ProfileScreen(user: m, repo: widget.repo, api: widget.api),
          ),
        );
      case RoomMemberAction.promote:
        await _runAdmin(() => widget.repo.setRoomAdmin(
              roomId: widget.roomId,
              targetUserId: m.id,
              makeAdmin: true,
            ));
      case RoomMemberAction.demote:
        await _runAdmin(() => widget.repo.setRoomAdmin(
              roomId: widget.roomId,
              targetUserId: m.id,
              makeAdmin: false,
            ));
      case RoomMemberAction.transferOwnership:
        await _confirmThen(
          headline: AppLocalizations.of(context)
              .roomAdminTransferConfirmHeadline(m.displayName),
          body: AppLocalizations.of(context).roomAdminTransferConfirmBody,
          confirmLabel: AppLocalizations.of(context).roomAdminTransferConfirmCta,
          run: () => widget.repo.transferRoomOwnership(
            roomId: widget.roomId,
            targetUserId: m.id,
          ),
        );
      case RoomMemberAction.remove:
        await _confirmThen(
          headline: AppLocalizations.of(context)
              .roomAdminRemoveConfirmHeadline(m.displayName),
          body: AppLocalizations.of(context).roomAdminRemoveConfirmBody,
          confirmLabel: AppLocalizations.of(context).roomAdminRemoveConfirmCta,
          run: () => widget.repo.removeRoomMember(
            roomId: widget.roomId,
            targetUserId: m.id,
          ),
        );
    }
  }

  /// Open (or create) the one-to-one chat with this member.
  ///
  /// Replaces nothing: the group's info screen stays underneath, so backing out
  /// of the DM returns you to the roster you were reading rather than dumping
  /// you at the chat list.
  Future<void> _messageMember(ChatUser m) async {
    try {
      final roomId = await widget.repo.openDmWith(m);
      if (!mounted) return;
      openRoom(context, roomId: roomId, repo: widget.repo, api: widget.api);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showAppToast(
        context,
        humanizeAuthError(e, l10n, fallback: l10n.roomAdminGenericError),
        tone: ToastTone.danger,
      );
    }
  }

  /// Ring this member one-to-one.
  ///
  /// Deliberately NOT a group call: the sheet is about one person, and the
  /// group's own call button is elsewhere. The DM room is resolved first
  /// because `CallService.initiate` rings INTO a room — calling from the group
  /// room would ring everybody in it.
  Future<void> _callMember(ChatUser m, CallMediaKind kind) async {
    final service = CallService.instance;
    if (service.inCall) return;
    try {
      final roomId = await widget.repo.openDmWith(m);
      await service.initiate(
        peerUserId: m.id,
        peerName: m.displayName,
        peerAvatarStorageId: m.avatarStorageId,
        roomId: roomId,
        kind: kind,
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final str = e.toString();
      showAppToast(context, str.contains('BUSY')
                ? l10n.callButtonErrorBusy
                : str.contains('NOT_A_MEMBER')
                    ? l10n.callButtonErrorNotMember
                    : friendlyServerError(e, l10n, l10n.callButtonErrorGeneric),
        tone: ToastTone.danger,
      );
    }
  }

  Future<void> _cancelInvite(PendingRoomInvite inv) async {
    await _runAdmin(() => widget.repo.cancelRoomInvitation(inv.invitationId));
    await _refreshAdminLists();
  }

  Future<void> _confirmThen({
    required String headline,
    required String body,
    required String confirmLabel,
    required Future<void> Function() run,
  }) async {
    final ok = await showConfirmSheet(
      context,
      headline: headline,
      body: body,
      confirmLabel: confirmLabel,
    );
    if (!ok || !mounted) return;
    await _runAdmin(run);
  }

  /// Run a mutation and put any refusal in front of the user.
  ///
  /// Nothing is applied optimistically: the member list is a live subscription,
  /// so the truthful result arrives on its own a moment later, and guessing at
  /// it first would mean a rejected promotion visibly un-happening.
  Future<void> _runAdmin(Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showAppToast(
        context,
        humanizeAuthError(
          e,
          l10n,
          fallback: l10n.roomAdminGenericError,
          overrides: roomAdminErrorMessages(l10n),
        ),
        tone: ToastTone.danger,
      );
    }
  }

  /// The group-management block: the link, the friend picker, and the queue.
  ///
  /// Only drawn for a group the viewer can actually do something in, and each
  /// row appears on its own condition — a plain member in a room that still
  /// allows member invites gets the friend picker and nothing else, which is
  /// exactly the surface their permissions describe.
  List<Widget> _groupAdminRows(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final pendingRequests = _joinRequests.length;
    final pendingChanges = _changeRequests.length;
    return [
        if (_perms.canInvite)
          _adminRow(
            theme,
            icon: CupertinoIcons.person_badge_plus,
            label: l10n.roomAdminAddFriendsRow,
            onTap: () async {
              await showRoomInviteFriendsSheet(
                context,
                repo: widget.repo,
                api: widget.api,
                roomId: widget.roomId,
              );
              await _refreshAdminLists();
            },
          ),
        if (_perms.canManageLink)
          _adminRow(
            theme,
            icon: CupertinoIcons.link,
            label: l10n.roomAdminInviteLinkRow,
            onTap: () => showRoomInviteSheet(
              context,
              repo: widget.repo,
              roomId: widget.roomId,
              permissions: _perms,
            ),
          ),
        // Only when there is something to review. An always-present row
        // reading "0 requests" is a permanent invitation to check a queue that
        // announces itself perfectly well by appearing.
        if (_perms.canReviewJoinRequests && pendingRequests > 0)
          _adminRow(
            theme,
            icon: CupertinoIcons.person_crop_circle_badge_checkmark,
            label: l10n.roomAdminJoinRequestsRow,
            badge: pendingRequests,
            onTap: () async {
              await showRoomJoinRequestsSheet(
                context,
                repo: widget.repo,
                api: widget.api,
                roomId: widget.roomId,
              );
              await _refreshAdminLists();
            },
          ),
        // Beside the join queue and on the same condition: only when there is
        // something to review. Two work queues that both announce themselves
        // by appearing, rather than two permanent rows reading "0".
        if (_perms.canReviewChangeRequests && pendingChanges > 0)
          _adminRow(
            theme,
            icon: CupertinoIcons.arrow_2_squarepath,
            label: l10n.roomAdminChangeRequestsRow,
            badge: pendingChanges,
            onTap: _openChangeRequests,
          ),
    ];
  }

  /// One row at the head of the member list: add, invite link, join requests.
  ///
  /// Single line by design — these sit directly above the roster and read as
  /// part of it. An earlier version carried an explanatory sub-line per row,
  /// which was right when this was a section of its own and became six lines of
  /// preamble once it moved into the list.
  Widget _adminRow(
    AppTheme theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? badge,
  }) {
    return PressRow(
      onTap: onTap,
      semanticLabel: label,
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
      child: Row(
        children: [
          // A circle the size of the avatars below, the WhatsApp "Add
          // participants" treatment: these rows head the roster and should
          // sit on its rhythm.
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: quietFill(theme),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: theme.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: theme.body.copyWith(color: theme.accent),
            ),
          ),
          if (badge != null && badge > 0) ...[
            RowBadge(count: badge),
            const SizedBox(width: 8),
          ],
          Icon(
            CupertinoIcons.chevron_forward,
            size: 15,
            color: theme.inkMuted.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  /// What is silenced about this room, and until when — in words, in the
  /// viewer's language, on the screen that exists to explain the room.
  ///
  /// States the current mute rather than offering its own controls. The two
  /// switches and the four durations live in one sheet
  /// (`widgets/mute_room_sheet.dart`) shared with the chat-list long-press, so
  /// there is one place that knows how to compose a mute and one set of
  /// sentences describing the result. A second, subtly different set of
  /// controls here is exactly how the two would end up disagreeing about what
  /// "muted" means.
  ///
  /// Reads [ChatRoom.isMuted] and its siblings, which resolve `mutedUntil`
  /// against the wall clock on every build — so a mute that lapses while this
  /// screen is open corrects itself on the next frame, with nothing having run
  /// at the deadline on either side of the wire.
  /// Opens the per-member colour picker.
  ///
  /// Only under a real roster — a DM hands out no speaker colours at all, and
  /// `caps.hasMembers` is already the flag for "a member list says something
  /// here", so this inherits that judgement rather than making a second one.
  Widget _speakerColorsRow(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final pinned = widget.repo.speakerColorsFor(widget.roomId);
    void open() => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoomColorsScreen(
              roomId: widget.roomId,
              repo: widget.repo,
              api: widget.api,
              members: _members,
            ),
          ),
        );
    final value = pinned.isEmpty
        ? l10n.roomInfoScreenSpeakerColorsAutomatic
        : l10n.roomInfoScreenSpeakerColorsCustom;
    return PressRow(
      onTap: open,
      semanticLabel: l10n.riNameColours,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tileColor(theme, TileTone.pink),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.paintbrush_fill,
              size: 17,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: theme.body.copyWith(fontSize: 17, color: theme.ink),
            ),
          ),
          // A strip of the room's own colours rather than a value: the row is
          // about colour, and three of them say where it leads.
          ..._speakerColorPreview(theme),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 15,
            color: theme.inkMuted.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  /// Up to four of the room's live speaker colours, in roster order.
  List<Widget> _speakerColorPreview(AppTheme theme) {
    final me = widget.repo.userId;
    final dots = <Widget>[];
    for (final m in _members) {
      if (m.id == me) continue;
      final slot = _speakerSlots.slotOf(m.id);
      if (slot == null) continue;
      dots.add(Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.speakerMark(slot, on: groupedFill(theme)),
          ),
        ),
      ));
      if (dots.length == 4) break;
    }
    return dots;
  }

  /// The room-wide translation switch.
  ///
  /// A plain row rather than a shared control: this screen's rows have their
  /// own chrome, and the only thing a second caller would share is the
  /// four-state logic, which lives in [Sebastian] where anyone can read it.
  /// There WAS a `RoomTranslateToggle` written for a flat action list that no
  /// longer exists; it sat unused for long enough to be deleted.
  Widget _translateRow(AppTheme theme, ChatRoom r) {
    final l10n = AppLocalizations.of(context);
    final sebastian = Sebastian.instance;
    final on = sebastian.isRoomTranslating(r.id);

    // Not supported here at all — say so and leave the row inert, the same
    // posture `caps.canOpenPeerProfile` takes in the header. A row that looks
    // live and does nothing is worse than one that explains itself.
    if (!sebastian.isAvailable) {
      return _translateRowShell(
        theme: theme,
        icon: CupertinoIcons.globe,
        title: l10n.roomTranslateTitle,
        detail: l10n.companionUnsupportedPlatform,
        active: false,
        onTap: null,
      );
    }

    return _translateRowShell(
      theme: theme,
      icon: CupertinoIcons.globe,
      title: on ? l10n.roomTranslateOnRow : l10n.roomTranslateTitle,
      detail: on
          ? sebastian.targetLanguage.autonym
          : (sebastian.isReady
              ? l10n.roomTranslateOffRow
              : l10n.roomTranslateNeedsSetUp),
      active: on,
      onTap: () async {
        if (on) {
          Sebastian.instance.stopRoom(r.id);
          if (mounted) setState(() {});
          return;
        }
        // Not ready is not a refusal — it is the install flow, reached from
        // here exactly as it is reached from a bubble's TRANSLATE row.
        if (!sebastian.isInstalled) {
          final installed = await showCompanionInstallSheet(
            context,
            companion: Companion.sebastian,
            brain: sebastian.brain,
          );
          if (!installed || !mounted) return;
        }
        if (!sebastian.isEnabled) {
          await SettingsStore.instance.setSebastianEnabled(true);
        }
        if (!mounted) return;
        Sebastian.instance
            .startRoom(r.id, widget.repo.messagesFor(widget.roomId));
        setState(() {});
      },
    );
  }

  Widget _translateRowShell({
    required AppTheme theme,
    required IconData icon,
    required String title,
    required String detail,
    required bool active,
    required VoidCallback? onTap,
  }) {
    return GroupedRow(
      icon: icon,
      tone: active ? TileTone.accent : TileTone.teal,
      title: title,
      subtitle: detail,
      onTap: onTap,
    );
  }

  Widget _muteRow(AppTheme theme, ChatRoom r) {
    final l10n = AppLocalizations.of(context);
    final muted = r.isMuted;
    final summary = !muted
        ? l10n.roomInfoScreenNotMutedRow
        : (r.notificationsMuted && r.badgesMuted)
            ? l10n.muteSummaryAll
            : r.badgesMuted
                ? l10n.muteSummaryBadgesOnly
                : l10n.muteSummaryNotificationsOnly;
    return GroupedRow(
      icon: muted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell_fill,
      tone: muted ? TileTone.indigo : TileTone.red,
      title: summary,
      // `r.mute.until` is null for "always" as well as for no mute at all,
      // and this branch has already ruled the second one out.
      subtitle: muted ? muteDeadlineSentence(context, until: r.mute.until) : null,
      onTap: () => showMuteRoomSheet(context, repo: widget.repo, room: r),
    );
  }

  /// The ways into the shared-content browser.
  ///
  /// A grouped list rather than a row of tiles. Four tiles across a phone left
  /// each one about 64pt of content, which is narrower than the word `MEDIA`
  /// at this letter-spacing — so every label sat on the edge of truncating and
  /// the whole block read as cramped. Rows have the width to be legible, match
  /// the rhythm of the members section directly below, and stay right on a
  /// 720pt desktop pane where four tiles would instead stretch absurdly wide.
  /// The fifth row costs nothing here that a fifth tile would have cost.
  ///
  /// Counts come from a separate query so this renders on the frame the screen
  /// opens rather than waiting on four index scans. A tab whose count has not
  /// arrived shows nothing at all — never a placeholder dash, which reads as
  /// "broken" rather than "pending" and is indistinguishable from genuinely
  /// empty. Once the count IS known, an empty tab says so in words.
  ///
  /// ── The fifth row is not like the other four ──
  ///
  /// SAVED lists what THIS reader bookmarked rather than what the room shared,
  /// which has two consequences visible right here. It is gated on
  /// [RoomCapabilities.canSaveMessages] — the capability, not an
  /// `isSavedMessages` check, per `room_capabilities.dart` — so a room where
  /// saving is meaningless offers no door to a list that can never fill. And
  /// its count comes off the bookmark subscription instead of
  /// `roomContent:counts`; see [roomContentCountFor] for why that is cheaper
  /// AND more current rather than a compromise.
  ///
  /// That subscription is also why the group rebuilds on every repository
  /// notify: `_onRepo` filters those down to room-field changes for the whole
  /// screen's sake, and a bookmark is not a room field. Five rows is a fraction
  /// of what the block this replaced rebuilt on the same signal.
  List<Widget> _sharedContentRows(AppTheme theme, RoomCapabilities caps) {
    final l10n = AppLocalizations.of(context);
    final rows = <(RoomContentTab, IconData, TileTone)>[
      (RoomContentTab.media, CupertinoIcons.photo_fill, TileTone.blue),
      (RoomContentTab.file, CupertinoIcons.doc_fill, TileTone.indigo),
      (RoomContentTab.voice, CupertinoIcons.waveform, TileTone.orange),
      (RoomContentTab.links, CupertinoIcons.link, TileTone.teal),
      if (caps.canSaveMessages)
        (RoomContentTab.saved, CupertinoIcons.bookmark_fill, TileTone.purple),
    ];
    return [
      for (final (tab, icon, tone) in rows)
        Builder(builder: (context) {
          final count = roomContentCountFor(
            tab,
            serverCounts: _contentCounts,
            savedCount: widget.repo.savedFor(widget.roomId).length,
          );
          // An empty tab says so in words — "0" beside a chevron reads as a
          // number that failed to load — and a count still in flight shows
          // nothing at all rather than a placeholder dash.
          final value = count == null
              ? null
              : (count.count == 0 ? l10n.riNone : count.badge);
          return GroupedRow(
            icon: icon,
            tone: tone,
            title: switch (tab) {
              RoomContentTab.media => l10n.riTabMedia,
              RoomContentTab.file => l10n.riTabFiles,
              RoomContentTab.voice => l10n.riTabVoice,
              RoomContentTab.links => l10n.riTabLinks,
              RoomContentTab.saved => l10n.riTabSaved,
            },
            value: value,
            onTap: () => _openContent(tab),
          );
        }),
    ];
  }

  /// Opens the browser, and passes any "show in chat" it returns straight
  /// through to whoever pushed this screen.
  ///
  /// A pure pass-through rather than travelling here: `RoomScreen` owns the
  /// jump machinery — the back-trail, the folded-thread fallback, and the
  /// `listAround` window fetch — and none of it is reachable from a route
  /// stacked on top of it.
  Future<void> _openContent(RoomContentTab tab) async {
    final jump = await Navigator.of(context).push<ChatMessage>(
      MaterialPageRoute(
        builder: (_) => RoomContentScreen(
          roomId: widget.roomId,
          repo: widget.repo,
          api: widget.api,
          initialTab: tab,
        ),
      ),
    );
    if (!mounted || jump == null) return;
    Navigator.of(context).pop(jump);
  }

}
