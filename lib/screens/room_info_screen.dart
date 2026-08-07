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
import '../models/room_content_item.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import '../widgets/photo_chrome.dart';
import '../widgets/remote_image.dart';
import '../widgets/steady_hero.dart';
import '../widgets/user_avatar.dart';
import 'fullscreen_image_viewer.dart';
import 'image_crop_screen.dart';
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
  bool _saving = false;
  /// Narrower than [_saving], which is also true while the form is being saved
  /// and drives the spinner inside the SAVE button. This one says specifically
  /// "a new picture is on its way", so the spinner can go where the user is
  /// looking — on the avatar itself.
  bool _changingAvatar = false;
  bool _leaving = false;
  bool _deleting = false;
  String? _error;
  List<ChatUser> _members = const [];
  Subscription? _membersSub;
  String _membersSig = '';
  ChatRoom? _lastObservedRoom;

  ChatRoom? get _room => widget.repo.roomById(widget.roomId);
  bool get _isOwner =>
      (widget.repo.userId ?? '') == (_room?.createdBy ?? '__none__');

  @override
  void initState() {
    super.initState();
    _hydrate();
    _loadContentCounts();
    widget.repo.addListener(_onRepo);
  }

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
    _membersSub?.cancel();
    widget.repo.removeListener(_onRepo);
    _name.dispose();
    _desc.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).roomInfoScreenNameRequiredError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateRoom(
        roomId: r.id,
        userId: me,
        name: n,
        description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        isPrivate: _isPrivate,
        messageLifetime: r.isEphemeral ? _ttl : null,
      );
      if (_isOwner && _newPassword.text.isNotEmpty) {
        await widget.api.updateRoomPassword(
          roomId: r.id,
          userId: me,
          password: _newPassword.text,
        );
        _newPassword.clear();
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).roomInfoScreenSavedSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _humanize(context, e);
      });
    }
  }

  Future<void> _clearPassword() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateRoomPassword(roomId: r.id, userId: me);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).roomInfoScreenPasswordClearedSnackbar)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
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
  /// is seconds of work happening after its sheet has dismissed, and the only
  /// spinner `_saving` drives lives inside the SAVE button at the far end of the
  /// form. So the whole pick-and-crop happened with nothing on this screen
  /// moving. Paying for the extra resets on the two cancel paths is the cheaper
  /// half of that trade.
  Future<void> _changeAvatar() async {
    final r = _room;
    final me = widget.repo.userId;
    if (r == null || me == null) return;
    setState(() {
      _saving = true;
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
          _saving = false;
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
    final ok = await _confirm(
      title: AppLocalizations.of(context).roomInfoScreenDeleteConfirmTitle,
      body: AppLocalizations.of(context).roomInfoScreenDeleteConfirmBody,
      confirm: AppLocalizations.of(context).roomInfoScreenDeleteConfirmButton,
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
    final busy = _saving || _leaving || _deleting;

    // A DM has no name/visibility/password of its own — it's just the two
    // people. Resolve the other person so we show their name and avatar
    // instead of the internal "dm:regular:<id>:<id>" key.
    final peer = r.isDm ? _dmPeer() : null;
    final title = peer?.displayName ?? r.name;

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
                        // just the two people.
                        if (!r.isDm) ...[
                          LabeledField(
                            label: AppLocalizations.of(context).roomInfoScreenNameLabel,
                            controller: _name,
                            hint: AppLocalizations.of(context).roomInfoScreenNameHint,
                          ),
                          const SizedBox(height: 18),
                        ],
                        LabeledField(
                          label: AppLocalizations.of(context).roomInfoScreenDescriptionLabel,
                          controller: _desc,
                          hint: AppLocalizations.of(context).roomInfoScreenDescriptionHint,
                        ),
                        if (!r.isDm) ...[
                          const SizedBox(height: 22),
                          FieldLabel(AppLocalizations.of(context).roomInfoScreenVisibilityLabel),
                          Row(children: [
                            Expanded(
                              child: _seg(
                                theme,
                                active: !_isPrivate,
                                onTap: () => setState(() => _isPrivate = false),
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
                                onTap: () => setState(() => _isPrivate = true),
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
                                  onTap: () => setState(() => _ttl = t),
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
                        if (_isOwner && !r.isDm) ...[
                          const SizedBox(height: 22),
                          Row(children: [
                            FieldLabel(AppLocalizations.of(context).roomInfoScreenPasswordLabel),
                            const Spacer(),
                            if (r.hasPassword)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.accent.withValues(alpha: 0.12),
                                  border: Border.all(color: theme.accent, width: 1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, size: 10, color: theme.accent),
                                    const SizedBox(width: 5),
                                    Text(AppLocalizations.of(context).roomInfoScreenLockedBadge, style: theme.monoTiny.copyWith(color: theme.accent)),
                                  ],
                                ),
                              )
                            else
                              Text(AppLocalizations.of(context).roomInfoScreenNoneBadge, style: theme.monoTiny.copyWith(color: theme.inkMuted)),
                          ]),
                          if (r.hasPassword) ...[
                            const SizedBox(height: 6),
                            Text(
                              AppLocalizations.of(context).roomInfoScreenPasswordProtectedNote,
                              style: theme.bodySoft.copyWith(fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                          ],
                          PasswordField(
                            controller: _newPassword,
                            hint: r.hasPassword
                                ? AppLocalizations.of(context).roomInfoScreenReplacePasswordHint
                                : AppLocalizations.of(context).roomInfoScreenSetPasswordHint,
                          ),
                          if (r.hasPassword) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: busy ? null : _clearPassword,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: theme.danger.withValues(alpha: 0.55), width: 1),
                                    borderRadius: BorderRadius.circular(theme.radiusMd),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context).roomInfoScreenRemovePasswordButton,
                                    style: theme.monoTiny.copyWith(color: theme.danger, letterSpacing: 1.4),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 28),
                        FieldLabel(AppLocalizations.of(context).roomInfoScreenSharedContentLabel),
                        const SizedBox(height: 6),
                        _sharedContent(theme),
                        const SizedBox(height: 28),
                        FieldLabel(AppLocalizations.of(context).roomInfoScreenMembersLabel(_members.length)),
                        const SizedBox(height: 6),
                        _membersList(theme, r),
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          Text(_error!, style: theme.body.copyWith(color: theme.danger)),
                          const SizedBox(height: 14),
                        ],
                        _saveButton(theme, busy),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: _dangerButton(
                              theme,
                              label: _leaving
                                  ? AppLocalizations.of(context).roomInfoScreenLeavingButton
                                  : AppLocalizations.of(context).roomInfoScreenLeaveRoomButton,
                              onTap: busy ? null : _leave,
                            ),
                          ),
                          if (_isOwner) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _dangerButton(
                                theme,
                                label: _deleting
                                    ? AppLocalizations.of(context).roomInfoScreenDeletingButton
                                    : AppLocalizations.of(context).roomInfoScreenDeleteButtonLabel,
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
            Positioned(
              right: 0,
              bottom: 0,
              child: FocusableTap(
                onTap: _saving ? null : _changeAvatar,
                shape: FocusRingShape.circle,
                semanticLabel: hasAvatar
                    ? AppLocalizations.of(context).roomInfoScreenChangeRoomPictureSemantic
                    : AppLocalizations.of(context).roomInfoScreenAddRoomPictureSemantic,
                child: GestureDetector(
                  onTap: _saving ? null : _changeAvatar,
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
      return Text(AppLocalizations.of(context).roomInfoScreenLoadingMembers, style: theme.bodySoft);
    }
    final ordered = [..._members]..sort((a, b) {
      final aOwner = a.id == r.createdBy ? 0 : 1;
      final bOwner = b.id == r.createdBy ? 0 : 1;
      if (aOwner != bOwner) return aOwner - bOwner;
      return a.displayName.compareTo(b.displayName);
    });
    final me = widget.repo.userId;
    return Column(
      children: [
        for (final m in ordered)
          GestureDetector(
            onTap: m.id == me
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          user: m,
                          repo: widget.repo,
                          api: widget.api,
                        ),
                      ),
                    ),
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
                        Text(m.displayName, style: theme.body),
                        Text('@${m.username}', style: theme.monoTiny),
                      ],
                    ),
                  ),
                  if (m.id == r.createdBy)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: theme.chipDecoration(filled: true),
                      child: Text(AppLocalizations.of(context).roomInfoScreenOwnerBadge, style: theme.monoTiny.copyWith(color: theme.accentInk)),
                    ),
                  if (m.id != me) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _saveButton(AppTheme theme, bool busy) {
    return GestureDetector(
      onTap: busy ? null : _save,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: busy ? theme.accentSoft : theme.accent,
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: _saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentInk),
              )
            : Text(
                AppLocalizations.of(context).roomInfoScreenSaveButton,
                style: theme.label.copyWith(color: theme.accentInk, letterSpacing: 2.2),
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

  /// The four ways into the shared-content browser.
  ///
  /// A grouped list rather than a row of tiles. Four tiles across a phone left
  /// each one about 64pt of content, which is narrower than the word `MEDIA`
  /// at this letter-spacing — so every label sat on the edge of truncating and
  /// the whole block read as cramped. Rows have the width to be legible, match
  /// the rhythm of the members section directly below, and stay right on a
  /// 720pt desktop pane where four tiles would instead stretch absurdly wide.
  ///
  /// Counts come from a separate query so this renders on the frame the screen
  /// opens rather than waiting on four index scans. A tab whose count has not
  /// arrived shows nothing at all — never a placeholder dash, which reads as
  /// "broken" rather than "pending" and is indistinguishable from genuinely
  /// empty. Once the count IS known, an empty tab says so in words.
  Widget _sharedContent(AppTheme theme) {
    const rows = <(RoomContentTab, IconData)>[
      (RoomContentTab.media, CupertinoIcons.photo),
      (RoomContentTab.file, CupertinoIcons.doc),
      (RoomContentTab.voice, CupertinoIcons.waveform),
      (RoomContentTab.links, CupertinoIcons.link),
    ];

    return Container(
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
              count: _contentCounts[rows[i].$1.countKey],
              onTap: () => _openContent(rows[i].$1),
            ),
          ],
        ],
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
