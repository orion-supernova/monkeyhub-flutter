import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../data/chat_repository.dart';
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
import '../widgets/adaptive_page_body.dart';
import '../widgets/editable_info_row.dart';
import '../widgets/labeled_field.dart';
import '../widgets/mute_room_sheet.dart';
import '../widgets/password_field.dart';
import '../widgets/photo_chrome.dart';
import '../widgets/remote_image.dart';
import '../widgets/room_invite_friends_sheet.dart';
import '../widgets/room_invite_sheet.dart';
import '../widgets/skeleton_rows.dart';
import '../widgets/room_join_requests_sheet.dart';
import '../widgets/room_member_actions_sheet.dart';
import '../widgets/steady_hero.dart';
import '../widgets/user_avatar.dart';
import '../widgets/destructive_sheet.dart';
import 'fullscreen_image_viewer.dart';
import 'image_crop_screen.dart';
import 'navigation/open_room.dart';
import 'profile_screen.dart';
import 'room_content_screen.dart';

class RoomInfoScreen extends StatefulWidget {
  const RoomInfoScreen({
    super.key,
    required this.roomId,
    required this.repo,
    required this.api,
  });
  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

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
  List<ChatUser> _members = const [];
  Subscription? _membersSub;
  String _membersSig = '';
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
          final wasAdmin = _perms.isAdmin;
          _permsSig = sig;
          setState(() => _perms = next);
          // Newly an admin (or newly not): the two queues below are gated on
          // that, so refresh them rather than leave a promoted admin looking
          // at an empty queue until they reopen the screen.
          if (next.isAdmin != wasAdmin) unawaited(_refreshAdminLists());
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
    try {
      final requests = _perms.canReviewJoinRequests
          ? await widget.repo.listJoinRequests(widget.roomId)
          : const <RoomJoinRequest>[];
      final invites = await widget.repo.pendingRoomInvites(widget.roomId);
      if (!mounted) return;
      setState(() {
        _joinRequests = requests;
        _pendingInvites = invites;
      });
    } catch (e) {
      debugPrint('room admin lists unavailable: $e');
    }
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
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    // Live subscription so presence (status/lastSeen) and any member-list
    // changes propagate without needing the screen to be re-opened.
    //
    // Convex re-fires this whenever any roomMembers row in the room is
    // written — including read-receipts (`markRoomRead` patches lastReadAt),
    // which can fire often during active chat. We don't render lastReadAt
    // here, so a content-signature dedup avoids gratuitous rebuilds. Without
    // it, rebuilds during overscroll fight the bounce physics and the
    // scroll view visibly jitters at top/bottom edges.
    try {
      _membersSub?.cancel();
      _membersSub = await widget.repo.cv.subscribe(
        'rooms:getMembers',
        {'roomId': widget.roomId, 'viewerUserId': ?widget.repo.userId},
        onData: (data) {
          if (!mounted) return;
          final list = (data as List?) ?? const [];
          final fresh = list
              .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
              .toList();
          final sig = _signatureFor(fresh);
          if (sig == _membersSig) return;
          _membersSig = sig;
          setState(() => _members = fresh);
        },
        onError: (err) => debugPrint('members sub error: $err'),
      );
    } catch (_) {/* offline — leave empty */}
  }

  /// Stable string fingerprint over the fields this screen actually renders.
  /// Order-insensitive so reorders from the server don't trigger a rebuild
  /// (the screen sorts members locally for display).
  String _signatureFor(List<ChatUser> users) {
    final parts = users
        .map((u) =>
            '${u.id}|${u.status ?? ''}|${u.lastSeen?.millisecondsSinceEpoch ?? 0}|${u.name}|${u.avatarStorageId ?? ''}|${u.role ?? ''}')
        .toList()
      ..sort();
    return parts.join(';');
  }

  @override
  void dispose() {
    _newPassword.removeListener(_onPasswordTyped);
    _membersSub?.cancel();
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
    void open() => setState(() => _passwordOpen = true);
    return FocusableTap(
      onTap: busy ? null : open,
      semanticLabel: l10n.roomInfoScreenPasswordLabel,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : open,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.roomInfoScreenPasswordLabel,
                  style: theme.label.copyWith(color: theme.inkMuted)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(
                  r.hasPassword ? Icons.lock_outline : Icons.lock_open_outlined,
                  size: 15,
                  color: r.hasPassword ? theme.accent : theme.inkMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.hasPassword
                        ? l10n.roomInfoScreenPasswordSetState
                        : l10n.roomInfoScreenPasswordUnsetState,
                    style: r.hasPassword
                        ? theme.body
                        : theme.body.copyWith(color: theme.inkMuted),
                  ),
                ),
                Icon(Icons.edit_outlined, size: 15, color: theme.inkMuted),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// One of the password block's two buttons. Shared so set and remove cannot
  /// end up different heights next to each other.
  Widget _pwAction(
    AppTheme theme, {
    required String label,
    required Color color,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return FocusableTap(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? (enabled ? color : theme.accentSoft)
                : Colors.transparent,
            border: filled
                ? null
                : Border.all(color: color.withValues(alpha: 0.55), width: 1),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style: theme.monoTiny.copyWith(
              color: filled
                  ? (enabled ? theme.accentInk : theme.inkMuted)
                  : color,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).roomInfoScreenPasswordSetSnackbar),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).roomInfoScreenPasswordClearedSnackbar)),
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
    final theme = ThemeScope.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(theme.radiusLg)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.displayMedium),
              const SizedBox(height: 8),
              Text(body, style: theme.bodySoft),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(AppLocalizations.of(ctx).roomInfoScreenConfirmCancelButton, style: theme.label.copyWith(color: theme.inkSoft)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: destructive ? theme.danger : theme.accent,
                        borderRadius: BorderRadius.circular(theme.radiusMd),
                      ),
                      child: Text(
                        confirm,
                        style: theme.label.copyWith(
                          color: destructive ? Colors.white : theme.accentInk,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return res ?? false;
  }

  String _humanize(BuildContext context, Object e) {
    final l10n = AppLocalizations.of(context);
    final s = e.toString();
    if (s.contains('ROOM_EXISTS')) return l10n.roomInfoScreenErrorRoomExists;
    if (s.contains('NOT_OWNER')) return l10n.roomInfoScreenErrorNotOwner;
    if (s.contains('NOT_AUTHORIZED')) return l10n.roomInfoScreenErrorNotAuthorized;
    if (s.contains('ROOM_NAME_REQUIRED')) return l10n.roomInfoScreenNameRequiredError;
    if (s.contains('ROOM_NOT_FOUND')) return l10n.roomInfoScreenErrorRoomNotFound;
    return s.replaceFirst('Exception: ', '');
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
    if (r.isGroupChat && !_perms.canEditRoom) {
      caps = caps.copyWith(canEditSettings: false, hasDescription: false);
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: Column(
              children: [
                _header(theme, r, title),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _avatarBlock(theme, r, peer),
                        const SizedBox(height: 26),
                        // Name/visibility don't apply to a 1:1 DM — the room is
                        // just the two people — nor to a room the app owns.
                        // Text, not a text field, until tapped. See
                        // [EditableInfoRow] — a screen made of empty input
                        // boxes reads as a form to fill in rather than a room
                        // to look at, and five of them pushed the roster and
                        // the media row off the first screenful.
                        if (caps.canEditSettings) ...[
                          EditableInfoRow(
                            label: AppLocalizations.of(context).roomInfoScreenNameLabel,
                            value: r.name,
                            saveLabel: AppLocalizations.of(context).roomInfoScreenEditSave,
                            cancelLabel:
                                AppLocalizations.of(context).roomInfoScreenEditCancel,
                            controller: _name,
                            placeholder:
                                AppLocalizations.of(context).roomInfoScreenNameHint,
                            enabled: _perms.canEditRoom || !r.isGroupChat,
                            onCommit: (v) => _pushRoom(name: v),
                          ),
                          const SizedBox(height: 14),
                        ],
                        // Nothing to describe about a chat with only yourself
                        // in it, one the app writes to you, or one with exactly
                        // one other person — see [RoomCapabilities.hasDescription].
                        if (caps.hasDescription) ...[
                          EditableInfoRow(
                            label: AppLocalizations.of(context)
                                .roomInfoScreenDescriptionLabel,
                            value: r.description ?? '',
                            saveLabel: AppLocalizations.of(context).roomInfoScreenEditSave,
                            cancelLabel:
                                AppLocalizations.of(context).roomInfoScreenEditCancel,
                            controller: _desc,
                            placeholder: AppLocalizations.of(context)
                                .roomInfoScreenDescriptionHint,
                            enabled: _perms.canEditRoom || !r.isGroupChat,
                            maxLines: 3,
                            onCommit: (v) => _pushRoom(description: v),
                          ),
                        ],
                        if (caps.canEditSettings) ...[
                          const SizedBox(height: 22),
                          FieldLabel(AppLocalizations.of(context).roomInfoScreenVisibilityLabel),
                          Row(children: [
                            Expanded(
                              child: _seg(
                                theme,
                                active: !_isPrivate,
                                onTap: () {
                                  setState(() => _isPrivate = false);
                                  unawaited(_pushRoom());
                                },
                                icon: theme.visibilityIcon(isPublic: true, size: 14),
                                title: AppLocalizations.of(context).roomInfoScreenPublicTitle,
                                sub: AppLocalizations.of(context).roomInfoScreenPublicSub,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _seg(
                                theme,
                                active: _isPrivate,
                                onTap: () {
                                  setState(() => _isPrivate = true);
                                  unawaited(_pushRoom());
                                },
                                icon: theme.visibilityIcon(isPublic: false, size: 14),
                                title: AppLocalizations.of(context).roomInfoScreenPrivateTitle,
                                sub: AppLocalizations.of(context).roomInfoScreenPrivateSub,
                              ),
                            ),
                          ]),
                        ],
                        if (r.isEphemeral) ...[
                          const SizedBox(height: 22),
                          Row(children: [
                            FieldLabel(AppLocalizations.of(context).roomInfoScreenMessageLifeLabel),
                            const Spacer(),
                            if (_ttl != null)
                              Text(_fmtTtl(context, _ttl!), style: theme.monoLarge.copyWith(color: theme.accent)),
                          ]),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final t in _ttlOptions)
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _ttl = t);
                                    unawaited(_pushRoom());
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    decoration: theme.chipDecoration(filled: _ttl == t),
                                    child: Text(
                                      _fmtTtl(context, t),
                                      style: theme.label.copyWith(
                                        color: _ttl == t ? theme.accentInk : theme.inkSoft,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        // Password, collapsed to a status line until tapped —
                        // the same disclosure the name and description use, and
                        // for a stronger reason: an always-visible password box
                        // on a screen you open to read the member list is an
                        // invitation to type a secret nobody asked for.
                        //
                        // Reveals the field AND its two actions together, so
                        // set and remove live in one place instead of one being
                        // permanently on screen.
                        if (_perms.canEditRoom && caps.canEditSettings) ...[
                          const SizedBox(height: 18),
                          if (!_passwordOpen)
                            _passwordSummary(theme, r, busy)
                          else ...[
                            FieldLabel(AppLocalizations.of(context)
                                .roomInfoScreenPasswordLabel),
                            const SizedBox(height: 6),
                            PasswordField(
                              controller: _newPassword,
                              hint: r.hasPassword
                                  ? AppLocalizations.of(context)
                                      .roomInfoScreenReplacePasswordHint
                                  : AppLocalizations.of(context)
                                      .roomInfoScreenSetPasswordHint,
                              onSubmitted: (_) => _applyPassword(),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              if (r.hasPassword)
                                Expanded(
                                  child: _pwAction(
                                    theme,
                                    label: AppLocalizations.of(context)
                                        .roomInfoScreenRemovePasswordButton,
                                    color: theme.danger,
                                    filled: false,
                                    onTap: busy ? null : _clearPassword,
                                  ),
                                ),
                              if (r.hasPassword) const SizedBox(width: 10),
                              Expanded(
                                child: _pwAction(
                                  theme,
                                  label: AppLocalizations.of(context)
                                      .roomInfoScreenSetPasswordButton,
                                  color: theme.accent,
                                  filled: true,
                                  // Dead until there is something to set —
                                  // the one commit on this screen, so it must
                                  // never fire on an empty field.
                                  onTap: (busy || !_passwordHasText)
                                      ? null
                                      : _applyPassword,
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FocusableTap(
                                onTap: _closePassword,
                                semanticLabel: AppLocalizations.of(context)
                                    .roomInfoScreenPasswordCancel,
                                radius: theme.radiusSm,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _closePassword,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    child: Text(
                                      AppLocalizations.of(context)
                                          .roomInfoScreenPasswordCancel,
                                      style: theme.monoTiny,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                        // No SAVE button: every control above applies itself.
                        // This slot is where a refused change speaks — a name
                        // already taken, a write that failed offline. It is
                        // deliberately the LAST thing in the settings block, so
                        // it appears under whatever was being edited rather
                        // than pushing the form around.
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!, style: theme.body.copyWith(color: theme.danger)),
                        ],
                        const SizedBox(height: 28),
                        FieldLabel(AppLocalizations.of(context).roomInfoScreenSharedContentLabel),
                        const SizedBox(height: 6),
                        _sharedContent(theme, caps),
                        // The caption the deleted SAVED MESSAGES block used to
                        // carry, kept because the row label cannot carry it.
                        // "SAVED" next to MEDIA and FILES reads as a fifth
                        // bucket of the room's stuff, which is exactly the
                        // wrong model — and the reader has no way to find out
                        // otherwise until they have already saved something in
                        // front of people. Under the group rather than in it:
                        // it is about one row but it is also the only sentence
                        // on this screen that says what a pin is, so it sits
                        // where a caption sits.
                        if (caps.canSaveMessages) ...[
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context).roomInfoScreenSharedContentSavedNote,
                            style: theme.bodySoft.copyWith(fontSize: 12),
                          ),
                        ],
                        // "Members (1): you" is not information — and neither
                        // is "Members (2): you and a bot", or "you and the
                        // person this screen is already titled after".
                        //
                        // The invite controls are the HEAD of this section, not
                        // a section of their own further up. Every mainstream
                        // group screen does it this way — WhatsApp, Signal and
                        // Telegram all make "add" the first row of the roster —
                        // and the version that had a separate GROUP block above
                        // ALSO had an add row inside the list, so the same
                        // action appeared twice on one screen.
                        if (caps.hasMembers) ...[
                          const SizedBox(height: 28),
                          FieldLabel(AppLocalizations.of(context).roomInfoScreenMembersLabel(_members.length)),
                          const SizedBox(height: 6),
                          if (r.isGroupChat &&
                              (_perms.canInvite || _perms.canManageLink)) ...[
                            _groupAdmin(theme),
                            const SizedBox(height: 6),
                            Divider(height: 1, thickness: 1, color: theme.divider),
                            const SizedBox(height: 6),
                          ],
                          _membersList(theme, r),
                        ],
                        // Last of the ordinary sections, above only the
                        // destructive pair. It is one row, it is set once and
                        // forgotten, and it is the only block here that changes
                        // nothing for anybody but the reader.
                        if (caps.canMute) ...[
                          const SizedBox(height: 28),
                          FieldLabel(AppLocalizations.of(context).roomInfoScreenMuteLabel),
                          const SizedBox(height: 6),
                          _muteRow(theme, r),
                        ],
                        const SizedBox(height: 28),
                        // A DM has no "leave" that makes sense — it's just the
                        // two people, and leaving alone silently strands you
                        // (you'd stop being a member but the room lives on,
                        // and re-opening the DM wouldn't re-add you). The only
                        // real action for a DM is ending it outright, which is
                        // available to either side, not just whoever created
                        // it — except Saved Messages and the system rooms,
                        // permanent fixtures with nothing to end or delete.
                        //
                        // `_isOwner` stays here rather than moving into the
                        // capability: whether a KIND of room can be deleted and
                        // whether THIS viewer may delete it are different
                        // questions, and only this screen knows the second.
                        Row(children: [
                          if (caps.canLeave) ...[
                            Expanded(
                              child: _dangerButton(
                                theme,
                                label: _leaving
                                    ? AppLocalizations.of(context).roomInfoScreenLeavingButton
                                    : AppLocalizations.of(context).roomInfoScreenLeaveRoomButton,
                                onTap: busy ? null : _leave,
                              ),
                            ),
                          ],
                          if (caps.canDelete && (_isOwner || r.isDm)) ...[
                            if (caps.canLeave) const SizedBox(width: 10),
                            Expanded(
                              child: _dangerButton(
                                theme,
                                label: _deleting
                                    ? (r.isDm
                                        ? AppLocalizations.of(context).roomInfoScreenEndingConversationButton
                                        : AppLocalizations.of(context).roomInfoScreenDeletingButton)
                                    : (r.isDm
                                        ? AppLocalizations.of(context).roomInfoScreenEndConversationButton
                                        : AppLocalizations.of(context).roomInfoScreenDeleteButtonLabel),
                                onTap: busy ? null : _delete,
                                filled: true,
                              ),
                            ),
                          ],
                        ]),
                      ],
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

  Widget _header(AppTheme theme, ChatRoom r, String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.isDm
                      ? AppLocalizations.of(context).roomInfoScreenHeaderConversation
                      : AppLocalizations.of(context).roomInfoScreenHeaderRoomSettings,
                  style: theme.monoTiny,
                ),
                const SizedBox(height: 2),
                Text(title, style: theme.displayMedium, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Diameter of the avatar at the top of this screen.
  static const _avatarSize = 92.0;

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
          decoration: BoxDecoration(color: theme.accentSoft, shape: BoxShape.circle),
          child: Icon(CupertinoIcons.bookmark_fill, size: size * 0.43, color: theme.accent),
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
                  color: theme.surfaceSunken,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.divider),
                ),
                child: Icon(Icons.person_outline, color: theme.inkMuted, size: 32),
              ),
            if (peer != null) ...[
              const SizedBox(height: 8),
              Text('@${peer.username}', style: theme.monoTiny),
            ],
          ],
        ),
      );
    }
    final hasAvatar = r.avatarStorageId != null && r.avatarStorageId!.isNotEmpty;
    final heroTag = 'room-info-avatar-${r.id}';
    final Widget picture = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        shape: BoxShape.circle,
        border: Border.all(color: theme.divider),
      ),
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
          : Center(
              child: Icon(Icons.tag, color: theme.inkMuted, size: 32),
            ),
    );
    return Center(
      // The picture is for looking at; editing lives on the badge. Tapping the
      // image itself used to open the picker, which meant a room's avatar was
      // the one picture in the app you could never actually see.
      child: SizedBox(
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
            // The edit badge, only for people who may actually change it.
            // `rooms.updateRoomAvatar` is admin-only for a group now, and
            // without this gate a member could pick a photo, sit through the
            // upload, and be refused at the very last step.
            if (!r.isGroupChat || _perms.canEditRoom)
            Positioned(
              right: 0,
              bottom: 0,
              child: FocusableTap(
                onTap: _working ? null : _changeAvatar,
                shape: FocusRingShape.circle,
                semanticLabel: hasAvatar
                    ? AppLocalizations.of(context).roomInfoScreenChangeRoomPictureSemantic
                    : AppLocalizations.of(context).roomInfoScreenAddRoomPictureSemantic,
                child: GestureDetector(
                  onTap: _working ? null : _changeAvatar,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.background, width: 2),
                    ),
                    child: Icon(Icons.camera_alt_outlined, size: 14, color: theme.accentInk),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _membersList(AppTheme theme, ChatRoom r) {
    if (_members.isEmpty) {
      // A skeleton, not "Loading members…". The string was one line where the
      // answer is many, so the section collapsed and then jumped to full
      // height the moment the roster landed — and on a slow connection it read
      // as an empty group rather than a pending one.
      //
      // Sized to the room's own member count where we have it: `memberCount`
      // is denormalized on the room row and arrives with the chat list, long
      // before the roster query resolves. So the placeholder is usually the
      // exact height of the answer and nothing moves at all when it lands.
      return SkeletonRows(count: r.memberCount.clamp(1, 8));
    }
    // Ranked, then alphabetical. Sorting on the ROLE rather than on
    // `rooms.createdBy` is what makes a promoted admin actually rise up the
    // list — the old comparator only ever knew about one privileged person and
    // pinned whoever happened to create the room, even after the room had been
    // handed to somebody else.
    final ordered = [..._members]..sort((a, b) {
      final ra = _rankOf(a);
      final rb = _rankOf(b);
      if (ra != rb) return ra - rb;
      return a.displayName.compareTo(b.displayName);
    });
    final me = widget.repo.userId;
    return Column(
      children: [
        for (final m in ordered) _memberRow(theme, r, m, me),
        // Outstanding invites, below the real roster and visibly apart from it.
        // These people are NOT members — they have been asked and have not
        // answered — and a list that mixed the two would be a roster nobody
        // could trust.
        if (_pendingInvites.isNotEmpty) ...[
          const SizedBox(height: 14),
          FieldLabel(AppLocalizations.of(context)
              .roomInfoScreenInvitedLabel(_pendingInvites.length)),
          const SizedBox(height: 4),
          for (final inv in _pendingInvites) _pendingInviteRow(theme, inv),
        ],
      ],
    );
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

    return GestureDetector(
      onTap: hasSheet ? open : null,
      // Long-press lands on the same sheet. Muscle memory from every other
      // chat app expects it, and a long-press that does nothing reads as the
      // row being broken rather than as the gesture being unsupported.
      onLongPress: hasSheet ? open : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            UserAvatar(user: m, size: 32, api: widget.api),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          m.displayName,
                          style: theme.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context).roomAdminYouSuffix,
                          style: theme.monoTiny,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '@${m.username}',
                    style: theme.monoTiny,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // The badge reads the ROLE. It used to read `id == r.createdBy`,
            // which is why a transferred room kept labelling the wrong person.
            // Shared with the sheet's header via [RoleChip] so one fact cannot
            // be styled two ways.
            if (role != RoomRole.member) RoleChip(role: role, dense: true),
            if (hasSheet) ...[
              const SizedBox(width: 6),
              Icon(Icons.more_horiz, size: 16, color: theme.inkMuted),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pendingInviteRow(AppTheme theme, PendingRoomInvite inv) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Opacity(
        // Dimmed rather than badged: the whole block is already labelled
        // "invited", and the row needs to read as provisional at a glance.
        opacity: 0.7,
        child: Row(
          children: [
            UserAvatar(user: inv.invitee, size: 28, api: widget.api),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv.invitee.displayName, style: theme.bodySoft),
                  Text(
                    // "Waiting on a parent" instead of nothing, because two
                    // days of silence from a supervised invitee otherwise
                    // reads as a snub rather than as a guardian who has not
                    // looked yet.
                    inv.awaitingGuardian
                        ? l10n.roomInfoScreenInviteAwaitingGuardian
                        : '@${inv.invitee.username}',
                    style: theme.monoTiny,
                  ),
                ],
              ),
            ),
            if (inv.canCancel)
              FocusableTap(
                onTap: () => _cancelInvite(inv),
                semanticLabel: l10n.roomInfoScreenInviteWithdraw,
                radius: theme.radiusSm,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _cancelInvite(inv),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      l10n.roomInfoScreenInviteWithdraw,
                      style: theme.monoTiny.copyWith(color: theme.danger),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeAuthError(e, l10n,
            fallback: l10n.roomAdminGenericError))),
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
        roomId: roomId,
        kind: kind,
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final str = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            str.contains('BUSY')
                ? l10n.callButtonErrorBusy
                : str.contains('NOT_A_MEMBER')
                    ? l10n.callButtonErrorNotMember
                    : l10n.callButtonErrorGeneric,
          ),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(humanizeAuthError(
            e,
            l10n,
            fallback: l10n.roomAdminGenericError,
            overrides: roomAdminErrorMessages(l10n),
          )),
        ),
      );
    }
  }

  /// The group-management block: the link, the friend picker, and the queue.
  ///
  /// Only drawn for a group the viewer can actually do something in, and each
  /// row appears on its own condition — a plain member in a room that still
  /// allows member invites gets the friend picker and nothing else, which is
  /// exactly the surface their permissions describe.
  Widget _groupAdmin(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final pendingRequests = _joinRequests.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_perms.canInvite)
          _adminRow(
            theme,
            icon: Icons.person_add_alt,
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
            icon: Icons.link,
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
            icon: Icons.how_to_reg_outlined,
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
      ],
    );
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
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              // A 32px circle, not a bare glyph. These rows are now the head of
              // the member list, sitting directly above avatars — the circle is
              // what puts them on the roster's rhythm instead of looking like
              // buttons that wandered into a list. Same treatment WhatsApp
              // gives "Add participants".
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: theme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: theme.body.copyWith(color: theme.accent),
                ),
              ),
              if (badge != null && badge > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                  ),
                  child: Text(
                    '$badge',
                    style: theme.monoTiny.copyWith(color: theme.accentInk),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dangerButton(
    AppTheme theme, {
    required String label,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? theme.danger : Colors.transparent,
          border: Border.all(color: theme.danger, width: 1.2),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Text(
          label,
          style: theme.label.copyWith(
            color: filled ? Colors.white : theme.danger,
            letterSpacing: 2,
          ),
        ),
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
    void open() => showMuteRoomSheet(context, repo: widget.repo, room: r);
    return FocusableTap(
      onTap: open,
      semanticLabel: summary,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: theme.surfaceSunken,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(color: theme.divider, width: 1.4),
          ),
          child: Row(
            children: [
              Icon(
                muted ? CupertinoIcons.bell_slash_fill : CupertinoIcons.bell,
                size: 18,
                color: muted ? theme.accent : theme.inkMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary, style: theme.body),
                    if (muted) ...[
                      const SizedBox(height: 4),
                      Text(
                        // `r.mute.until` is null for "always" as well as for
                        // no mute at all, and this branch has already ruled the
                        // second one out — so the sentence helper lands on
                        // "until you turn it back on" without this screen ever
                        // having to know what the sentinel is.
                        muteDeadlineSentence(context, until: r.mute.until),
                        style: theme.monoTiny.copyWith(color: theme.accent),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, size: 18, color: theme.inkMuted),
            ],
          ),
        ),
      ),
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
  Widget _sharedContent(AppTheme theme, RoomCapabilities caps) {
    final rows = <(RoomContentTab, IconData)>[
      (RoomContentTab.media, CupertinoIcons.photo),
      (RoomContentTab.file, CupertinoIcons.doc),
      (RoomContentTab.voice, CupertinoIcons.waveform),
      (RoomContentTab.links, CupertinoIcons.link),
      // The outline, where every other mark of a save in the app is the fill.
      // Deliberate: these five icons are doors, not states — a filled bookmark
      // in a column of line glyphs would read as "this one is on".
      if (caps.canSaveMessages) (RoomContentTab.saved, CupertinoIcons.bookmark),
    ];

    return AnimatedBuilder(
      animation: widget.repo,
      builder: (context, _) => Container(
        decoration: BoxDecoration(
          color: theme.surfaceSunken,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(color: theme.divider, width: 1.4),
        ),
        // Clipped so the first and last rows' press highlight cannot paint over
        // the rounded corners.
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                // Inset to the text column, so the dividers read as separating
                // rows rather than as a table grid.
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Divider(height: 1, thickness: 1, color: theme.divider),
                ),
              _SharedContentRow(
                theme: theme,
                tab: rows[i].$1,
                icon: rows[i].$2,
                count: roomContentCountFor(
                  rows[i].$1,
                  serverCounts: _contentCounts,
                  savedCount: widget.repo.savedFor(widget.roomId).length,
                ),
                onTap: () => _openContent(rows[i].$1),
              ),
            ],
          ],
        ),
      ),
    );
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

  Widget _seg(AppTheme theme, {
    required bool active,
    required VoidCallback onTap,
    required Widget icon,
    required String title,
    required String sub,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motionFast,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          // Active uses the accent color across border + faint fill so the
          // selected state reads clearly on every theme, independent of
          // surfaceRaised/surfaceSunken contrast.
          color: active ? theme.accent.withValues(alpha: 0.12) : theme.surfaceSunken,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          // Constant border width — switching width between states caused a
          // 0.8px layout shift on toggle.
          border: Border.all(
            color: active ? theme.accent : theme.divider,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: Center(child: icon)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.displaySmall.copyWith(
                      color: active ? theme.accent : theme.inkSoft,
                      fontSize: 16,
                    ),
                  ),
                  Text(sub, style: theme.monoTiny),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the SHARED CONTENT group: icon, name, how much, chevron.
///
/// Pressed state is drawn here rather than by an overlay because this row sits
/// inside a clipped, bordered container — an ink splash would have to be
/// clipped to the group's radius, and this app draws no ink anywhere regardless.
class _SharedContentRow extends StatefulWidget {
  const _SharedContentRow({
    required this.theme,
    required this.tab,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final AppTheme theme;
  final RoomContentTab tab;
  final IconData icon;

  /// Null until the counts query lands. Rendered as nothing rather than as a
  /// placeholder — see [_RoomInfoScreenState._sharedContent].
  final RoomContentCount? count;

  final VoidCallback onTap;

  @override
  State<_SharedContentRow> createState() => _SharedContentRowState();
}

class _SharedContentRowState extends State<_SharedContentRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final count = widget.count;
    final empty = count != null && count.count == 0;

    // `FocusableTap` registers no gesture recognizer of its own, so the bare
    // `GestureDetector` inside is what actually receives the pointer. Both
    // carry the handler; wrapping alone would render a row that does nothing.
    // Never an InkWell — this app draws no ink anywhere.
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: count?.badge == null
          ? widget.tab.label(context)
          : '${widget.tab.label(context)}, ${count!.badge}',
      radius: theme.radiusSm,
      inset: 1,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          color: _pressed ? theme.accent.withValues(alpha: 0.10) : null,
          padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Icon(widget.icon, size: 18, color: theme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.tab.label(context),
                  style: theme.body.copyWith(color: theme.ink),
                ),
              ),
              // An empty tab says so in words rather than showing a zero: "0"
              // next to a chevron reads as a number that failed to load, where
              // "none" reads as an answer. Nothing at all while the count is
              // still in flight.
              if (empty)
                Text(AppLocalizations.of(context).roomInfoScreenNoneCount, style: theme.caption.copyWith(color: theme.inkMuted))
              else if (count?.badge != null)
                Text(
                  count!.badge!,
                  style: theme.bodyEmph.copyWith(color: theme.accent),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
